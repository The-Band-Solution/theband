defmodule TheBand.Telemetria.ReguaTest do
  @moduledoc """
  A régua de entrar e sair — spec 074, tabela *A régua*; SC-001; T012 (a parte da entrada).

  Cada linha da régua é um teste que faz o que a pessoa faz e lê o span **depois do filtro de
  produção** (`TheBand.Spans.ligar/0` troca só o destino). Cada teste afirma três coisas:

  1. o passo, o desfecho e o motivo certos;
  2. nada do que a pessoa digitou — senha, identificador, e-mail — está no span ou no recurso,
     em claro, Base64 ou `inspect` (FR-005);
  3. a conta só vai nos desfechos que pedem ação (FR-004, D1 de 2026-10-03).

  E o que o controller recebe continua o de sempre: `{:ok, user}`, `:invalid_credentials` ou
  `{:throttled, s}` — o motivo fica no passo, e nunca na resposta (seguranca.md, S4).
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Spans
  alias TheBand.Tenants

  @senha "SENTINELA-SENHA-regua-7c1e"
  @senha_errada "SENTINELA-ERRADA-regua-2b9d"

  setup do
    :ok = Spans.ligar()
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    {:ok, admin} = Tenants.set_password(tenant, admin.id, @senha)

    # O `setup` emite nada da jornada; esvaziar a caixa garante que cada teste lê só o seu passo.
    Spans.recebidos(0)
    %{tenant: tenant, admin: admin}
  end

  defp conta_com_senha(tenant) do
    {:ok, user} =
      Tenants.create_user(tenant, %{
        "email" => "regua-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, user} = Tenants.set_password(tenant, user.id, @senha)
    user
  end

  defp correlator, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

  # Entra, e devolve o retorno e os atributos do ÚNICO passo `entrar_com_senha` que saiu.
  # Um segundo passo, ou nenhum, reprova aqui: a régua é "um passo por tentativa".
  defp entrar(identificador, senha, opts \\ []) do
    resultado = Tenants.authenticate(identificador, senha, opts)
    spans = Spans.recebidos()

    assert [span] = Spans.do_passo(spans, :entrar_com_senha),
           "uma tentativa produz exatamente um passo entrar_com_senha"

    sentinelas = [@senha, @senha_errada, identificador]

    assert Spans.sentinelas_encontradas([spans, Spans.recursos()], sentinelas) == [],
           "o que a pessoa digitou saiu no traço"

    {resultado, Spans.atributos(span)}
  end

  defp assert_falhou(atributos, motivo) do
    assert atributos["journey.name"] == "entrar_e_sair"
    assert atributos["journey.step"] == "entrar_com_senha"
    assert atributos["outcome"] == "falhou"
    assert atributos["failure.reason"] == Atom.to_string(motivo)
  end

  describe "entrar_com_senha — concluiu (045/US1 #1 e #2)" do
    test "a entrada certa sai com a organização e SEM a conta", ctx do
      user = conta_com_senha(ctx.tenant)

      {resultado, atributos} = entrar(user.email, @senha)

      assert {:ok, %{id: id}} = resultado
      assert id == user.id
      assert atributos["outcome"] == "concluiu"
      refute Map.has_key?(atributos, "failure.reason")
      assert atributos["tenant.id"] == ctx.tenant.id

      refute Map.has_key?(atributos, "user.ref"),
             "o sucesso comum não é registro de presença (FR-004, D1)"
    end

    test "pelo usuário do GitHub, com elo vigente, também conclui sem a conta", ctx do
      user = conta_com_senha(ctx.tenant)

      {:ok, _} =
        Tenants.declare_person(
          ctx.tenant,
          user.id,
          pessoa(ctx.tenant, "regua-gh").id,
          ctx.admin.id
        )

      {resultado, atributos} = entrar("regua-gh", @senha)

      assert {:ok, _} = resultado
      assert atributos["outcome"] == "concluiu"
      refute Map.has_key?(atributos, "user.ref")
    end

    test "o sucesso que apagou tentativas falhas leva a conta — a campanha que deu certo", ctx do
      user = conta_com_senha(ctx.tenant)
      {{:error, :invalid_credentials}, _} = entrar(user.email, @senha_errada)

      {resultado, atributos} = entrar(user.email, @senha)

      assert {:ok, _} = resultado
      assert atributos["outcome"] == "concluiu"
      assert atributos["user.ref"] == user.id
    end

    test "o correlator da tentativa sai como journey.id", ctx do
      user = conta_com_senha(ctx.tenant)
      jornada_id = correlator()

      {_, atributos} = entrar(user.email, @senha, jornada_id: jornada_id)

      assert atributos["journey.id"] == jornada_id
    end
  end

  describe "entrar_com_senha — falhou, com conta conhecida (a conta vai: pede ação)" do
    test "senha errada (045/US1 #3)", ctx do
      user = conta_com_senha(ctx.tenant)

      {resultado, atributos} = entrar(user.email, @senha_errada)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :senha_errada)
      assert atributos["tenant.id"] == ctx.tenant.id
      assert atributos["user.ref"] == user.id
    end

    test "conta sem senha definida (045/US1 #8)", ctx do
      {:ok, sem_senha} =
        Tenants.create_user(ctx.tenant, %{
          "email" => "sem-senha-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      {resultado, atributos} = entrar(sem_senha.email, @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :conta_sem_senha)
      assert atributos["user.ref"] == sem_senha.id
    end

    test "conta desativada (achado H3, parte B)", ctx do
      user = conta_com_senha(ctx.tenant)

      {:ok, _} =
        Tenants.disable_user(ctx.tenant, user.id, ctx.admin.id, %{
          "reason" => "left_the_organisation"
        })

      {resultado, atributos} = entrar(user.email, @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :conta_desativada)
      assert atributos["user.ref"] == user.id
    end

    test "organização suspensa (achado H3, parte A)", ctx do
      user = conta_com_senha(ctx.tenant)

      # Por `update_all`: `:status` não é castável desde a 070, e o teste prova o efeito da
      # suspensão, não o ato (ver `organizacao_suspensa_test.exs`).
      {1, _} =
        Repo.update_all(from(t in Tenants.Tenant, where: t.id == ^ctx.tenant.id),
          set: [status: "suspended"]
        )

      {resultado, atributos} = entrar(user.email, @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :organizacao_suspensa)
      assert atributos["tenant.id"] == ctx.tenant.id
      assert atributos["user.ref"] == user.id
    end

    test "a espera crescente segurou a tentativa (045 FR-016)", ctx do
      user = conta_com_senha(ctx.tenant)

      for _ <- 1..3 do
        {{:error, :invalid_credentials}, _} = entrar(user.email, @senha_errada)
      end

      {resultado, atributos} = entrar(user.email, @senha)

      assert {:error, {:throttled, s}} = resultado
      assert is_integer(s) and s > 0
      assert_falhou(atributos, :em_espera)
      assert atributos["user.ref"] == user.id
    end
  end

  describe "entrar_com_senha — falhou, sem conta (nada do digitado sai)" do
    test "o identificador não identifica conta (045/US1 #4)" do
      digitado = "SENTINELA-IDENT-#{System.unique_integer([:positive])}@example.test"

      {resultado, atributos} = entrar(digitado, @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :identificador_nao_resolveu)
      refute Map.has_key?(atributos, "user.ref")
      refute Map.has_key?(atributos, "tenant.id")
    end

    test "o elo revogado deixa o usuário do GitHub sem resolver (045/US1 #5)", ctx do
      user = conta_com_senha(ctx.tenant)
      p = pessoa(ctx.tenant, "regua-revogada")
      {:ok, _} = Tenants.declare_person(ctx.tenant, user.id, p.id, ctx.admin.id)
      {:ok, _} = Tenants.revoke_person(ctx.tenant, user.id, ctx.admin.id)
      Spans.recebidos(0)

      {resultado, atributos} = entrar("regua-revogada", @senha)

      assert resultado == {:error, :invalid_credentials}
      assert_falhou(atributos, :identificador_nao_resolveu)
      refute Map.has_key?(atributos, "user.ref")
      refute Map.has_key?(atributos, "tenant.id")
    end
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
end
