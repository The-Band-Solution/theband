defmodule TheBand.Tenants.AuthTest do
  @moduledoc """
  Autenticação — contrato `specs/045-autenticacao-e-acesso/contracts/auth.md`.

  ## As asserções que carregam este arquivo (violação primeiro — L03)

  1. **a recusa é uma só**: senha errada, e-mail inexistente, username ambíguo,
     elo revogado e conta sem senha devolvem o MESMO erro (FR-002/014/019);
  2. **username ambíguo entre tenants não identifica** — o e-mail resolve;
  3. **a espera cresce** depois das tentativas livres, e o sucesso zera;
  4. **trocar a senha gira o token de sessão** — é o que derruba as outras
     sessões (FR-015);
  5. **a temporária obriga troca** e nunca fica legível em lugar nenhum.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  @senha "senha-bem-comprida-123"

  setup do
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    %{tenant: tenant, admin: admin}
  end

  defp conta_com_senha(tenant, senha \\ @senha) do
    user = user_fixture(tenant, "member")
    {:ok, user} = Tenants.set_password(tenant, user.id, senha)
    user
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        Map.merge(source_attrs("U_#{login}_#{System.unique_integer([:positive])}"), %{
          name: login,
          login: login,
          account_type: "person"
        })
      )

    p
  end

  defp com_elo(tenant, admin, login) do
    user = conta_com_senha(tenant)
    p = pessoa(tenant, login)
    {:ok, ligada} = Tenants.declare_person(tenant, user.id, p.id, admin.id)
    ligada
  end

  describe "a recusa é uma só" do
    test "senha errada, e-mail inexistente, sem senha e elo revogado — mesmo erro", ctx do
      com_senha = conta_com_senha(ctx.tenant)
      sem_senha = user_fixture(ctx.tenant, "member")
      ligada = com_elo(ctx.tenant, ctx.admin, "fulana")
      {:ok, _} = Tenants.revoke_person(ctx.tenant, ligada.id, ctx.admin.id)

      recusas = [
        Tenants.authenticate(com_senha.email, "senha-errada-mas-longa"),
        Tenants.authenticate("ninguem@example.test", @senha),
        Tenants.authenticate(sem_senha.email, @senha),
        Tenants.authenticate("fulana", @senha)
      ]

      for recusa <- recusas do
        assert recusa == {:error, :invalid_credentials},
               "toda recusa é :invalid_credentials — vazou distinção: #{inspect(recusa)}"
      end
    end
  end

  describe "identificador" do
    test "e-mail entra, sem diferenciar caixa", ctx do
      user = conta_com_senha(ctx.tenant)
      assert {:ok, entrada} = Tenants.authenticate(String.upcase(user.email), @senha)
      assert entrada.id == user.id
      assert entrada.tenant.id == ctx.tenant.id, "o tenant sai da conta, nunca de escolha"
    end

    test "username do GitHub entra pelo elo vigente", ctx do
      ligada = com_elo(ctx.tenant, ctx.admin, "beltrana")
      assert {:ok, entrada} = Tenants.authenticate("beltrana", @senha)
      assert entrada.id == ligada.id
    end

    test "username ambíguo entre dois tenants não identifica; o e-mail resolve", ctx do
      ligada_a = com_elo(ctx.tenant, ctx.admin, "sicrana")

      outro = tenant_fixture()
      outro_admin = user_fixture(outro)
      _ligada_b = com_elo(outro, outro_admin, "sicrana")

      assert {:error, :invalid_credentials} = Tenants.authenticate("sicrana", @senha)
      assert {:ok, entrada} = Tenants.authenticate(ligada_a.email, @senha)
      assert entrada.tenant.id == ctx.tenant.id
    end
  end

  describe "espera crescente (FR-016)" do
    test "depois das tentativas livres vem {:throttled, s}; sucesso zera", ctx do
      user = conta_com_senha(ctx.tenant)

      for _ <- 1..3 do
        assert {:error, :invalid_credentials} =
                 Tenants.authenticate(user.email, "errada-e-comprida-1")
      end

      assert {:error, {:throttled, s}} = Tenants.authenticate(user.email, @senha)
      assert s > 0 and s <= 60

      # Janela vencida: recuar o último erro no banco (não se espera em teste).
      Repo.update_all(
        from(u in TheBand.Tenants.User, where: u.id == ^user.id),
        set: [last_failed_at: DateTime.add(DateTime.utc_now(:second), -120, :second)]
      )

      assert {:ok, entrada} = Tenants.authenticate(user.email, @senha)
      assert entrada.failed_attempts == 0
    end
  end

  describe "senha" do
    test "trocar exige a atual e gira o token de sessão (FR-015)", ctx do
      user = conta_com_senha(ctx.tenant)
      {:ok, entrada} = Tenants.authenticate(user.email, @senha)
      token_antigo = entrada.session_token

      assert {:error, :invalid_current} =
               Tenants.change_password(ctx.tenant, user.id, "atual-errada-longa", "nova-bem-comprida-1")

      assert {:ok, trocada} =
               Tenants.change_password(ctx.tenant, user.id, @senha, "nova-bem-comprida-1")

      assert trocada.session_token != token_antigo
      assert {:ok, _} = Tenants.authenticate(user.email, "nova-bem-comprida-1")
      assert {:error, :invalid_credentials} = Tenants.authenticate(user.email, @senha)
    end

    test "curta demais é changeset inválido, nunca gravada", ctx do
      user = user_fixture(ctx.tenant, "member")
      assert {:error, changeset} = Tenants.set_password(ctx.tenant, user.id, "curta")
      assert %{password: [_ | _]} = errors_on(changeset)
    end

    test "a temporária entra uma vez e obriga troca (FR-013)", ctx do
      user = conta_com_senha(ctx.tenant)

      assert {:ok, temporaria} = Tenants.reset_password(ctx.tenant, user.id, ctx.admin.id)
      assert {:ok, entrada} = Tenants.authenticate(user.email, temporaria)
      assert entrada.must_change_password

      # A temporária nunca fica legível: o hash não a contém.
      refute entrada.password_hash =~ temporaria

      {:ok, _} = Tenants.change_password(ctx.tenant, user.id, temporaria, "definitiva-comprida-1")
      {:ok, depois} = Tenants.authenticate(user.email, "definitiva-comprida-1")
      refute depois.must_change_password
    end

    test "conta de outro tenant não se alcança", ctx do
      outro = tenant_fixture()
      alheia = user_fixture(outro, "member")

      assert {:error, :not_found} = Tenants.set_password(ctx.tenant, alheia.id, @senha)
      assert {:error, :not_found} = Tenants.reset_password(ctx.tenant, alheia.id, ctx.admin.id)
    end
  end
end
