defmodule TheBand.Tenants.SessionsTest do
  @moduledoc """
  `TheBand.Tenants.Sessions` — feature 064, T011. Contrato em
  `specs/064-segredo-em-repouso/contracts/sessoes.md`.

  Cada teste nomeia o achado de `seguranca-us2.md` que ele guarda. A guarda nasce provada: o
  defeito correspondente foi injetado e o teste foi visto reprovando.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Repo
  alias TheBand.Segredo
  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.UserSession
  alias TheBand.Tenants.Sessions
  alias TheBand.Tenants.User
  alias TheBandWeb.ConnCase

  setup do
    {tenant, admin} = ConnCase.tenant_with_admin()

    {:ok, alvo} =
      Tenants.create_user(tenant, %{
        "email" => "sessao-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{tenant: tenant, admin: admin, alvo: Repo.get!(User, alvo.id)}
  end

  defp envelhecer(sessao, dias) do
    Repo.update_all(
      from(s in UserSession, where: s.id == ^sessao.id),
      set: [inserted_at: DateTime.add(DateTime.utc_now(:second), -dias, :day)]
    )
  end

  describe "abrir/1" do
    test "o bruto não aparece em coluna nenhuma da tabela", %{alvo: alvo} do
      {:ok, {sessao, segredo}} = Sessions.abrir(alvo)
      bruto = Segredo.expor(segredo)

      %{rows: linhas} =
        Repo.query!("SELECT * FROM user_sessions WHERE id = $1", [dump_uuid(sessao.id)])

      for valor <- List.flatten(linhas), is_binary(valor) do
        refute valor == bruto
        refute String.contains?(valor, bruto)
      end

      assert sessao.token_hash == :crypto.hash(:sha256, bruto)
    end

    test "o bruto sai como Segredo, e o inspect do retorno não o mostra (S11)", %{alvo: alvo} do
      {:ok, {_sessao, segredo} = retorno} = Sessions.abrir(alvo)
      refute inspect(retorno) =~ Segredo.expor(segredo)
    end

    test "a sessão nasce com a época da struct recebida (S2)", %{alvo: alvo} do
      {:ok, {sessao, _}} = Sessions.abrir(%{alvo | password_epoch: 7})
      assert sessao.password_epoch == 7
    end
  end

  describe "conferir/2" do
    test "a sessão recém-aberta vale", %{alvo: alvo} do
      {:ok, {sessao, segredo}} = Sessions.abrir(alvo)
      assert {:ok, %UserSession{id: id}, %User{} = user} = Sessions.conferir(sessao.id, segredo)
      assert id == sessao.id
      assert user.id == alvo.id
      # O tenant vem pré-carregado: quem chama não busca a conta de novo.
      assert user.tenant.id == alvo.tenant_id
    end

    test "o resumo no lugar do bruto é recusado — é o que o dump entrega", %{alvo: alvo} do
      {:ok, {sessao, _segredo}} = Sessions.abrir(alvo)

      assert {:error, :resumo_errado} =
               Sessions.conferir(sessao.id, Segredo.novo(sessao.token_hash))

      assert {:error, :resumo_errado} =
               Sessions.conferir(sessao.id, Segredo.novo(Base.encode16(sessao.token_hash)))
    end

    test "o bruto de outra sessão é recusado", %{alvo: alvo} do
      {:ok, {sessao, _}} = Sessions.abrir(alvo)
      {:ok, {_outra, outro_segredo}} = Sessions.abrir(alvo)
      assert {:error, :resumo_errado} = Sessions.conferir(sessao.id, outro_segredo)
    end

    test "ausência é recusa, e nunca exceção (S4)", %{alvo: alvo} do
      {:ok, {sessao, segredo}} = Sessions.abrir(alvo)

      assert {:error, :malformado} = Sessions.conferir(nil, segredo)
      assert {:error, :malformado} = Sessions.conferir(sessao.id, nil)
      assert {:error, :malformado} = Sessions.conferir("nao-e-uuid", segredo)
      # O bruto como binário nu é recusado: a garantia pelo tipo não aceita atalho.
      assert {:error, :malformado} = Sessions.conferir(sessao.id, Segredo.expor(segredo))
      assert {:error, :inexistente} = Sessions.conferir(Ecto.UUID.generate(), segredo)
    end

    test "a sessão encerrada não vale", %{alvo: alvo} do
      {:ok, {sessao, segredo}} = Sessions.abrir(alvo)
      :ok = Sessions.encerrar(sessao)
      assert {:error, :encerrada} = Sessions.conferir(sessao.id, segredo)
    end

    test "vale por 7 dias a contar da abertura DESTA sessão (S6)", %{alvo: alvo} do
      {:ok, {velha, segredo_velho}} = Sessions.abrir(alvo)
      {:ok, {nova, segredo_novo}} = Sessions.abrir(alvo)

      envelhecer(velha, 8)
      envelhecer(nova, 6)

      assert {:error, :vencida} = Sessions.conferir(velha.id, segredo_velho)
      assert {:ok, _, _} = Sessions.conferir(nova.id, segredo_novo)

      # Um login novo na conta não estende a sessão velha: a validade não é por conta.
      Repo.update_all(from(u in User, where: u.id == ^alvo.id),
        set: [logged_in_at: DateTime.utc_now(:second)]
      )

      assert {:error, :vencida} = Sessions.conferir(velha.id, segredo_velho)
    end

    test "definir a senha depois da abertura derruba a sessão (S2)", %{alvo: alvo} do
      {:ok, {sessao, segredo}} = Sessions.abrir(alvo)

      {:ok, _} =
        alvo |> User.senha_changeset(%{password: "uma-senha-longa-o-bastante"}) |> Repo.update()

      assert {:error, :epoca_velha} = Sessions.conferir(sessao.id, segredo)
    end
  end

  describe "encerrar" do
    test "encerrar de novo não muda a data do primeiro encerramento", %{alvo: alvo} do
      {:ok, {sessao, _}} = Sessions.abrir(alvo)
      :ok = Sessions.encerrar(sessao)

      Repo.update_all(from(s in UserSession, where: s.id == ^sessao.id),
        set: [ended_at: ~U[2026-09-01 00:00:00Z]]
      )

      :ok = Sessions.encerrar(sessao)
      assert Repo.get!(UserSession, sessao.id).ended_at == ~U[2026-09-01 00:00:00Z]
    end

    test "encerrar_da_conta encerra só as da conta, e nunca apaga", ctx do
      {:ok, {a, _}} = Sessions.abrir(ctx.alvo)
      {:ok, {b, _}} = Sessions.abrir(ctx.alvo)
      {:ok, {do_admin, sa}} = Sessions.abrir(Repo.get!(User, ctx.admin.id))

      assert {:ok, 2} = Sessions.encerrar_da_conta(ctx.tenant.id, ctx.alvo.id)
      assert Repo.get!(UserSession, a.id).ended_at
      assert Repo.get!(UserSession, b.id).ended_at
      assert {:ok, _, _} = Sessions.conferir(do_admin.id, sa)
    end

    test "girar_todas encerra de todos os tenants", ctx do
      {outro_tenant, outro_admin} = ConnCase.tenant_with_admin()
      {:ok, {a, sa}} = Sessions.abrir(ctx.alvo)
      {:ok, {b, sb}} = Sessions.abrir(Repo.get!(User, outro_admin.id))

      {:ok, n} = Sessions.girar_todas()
      assert n >= 2
      assert {:error, :encerrada} = Sessions.conferir(a.id, sa)
      assert {:error, :encerrada} = Sessions.conferir(b.id, sb)
      _ = outro_tenant
    end
  end

  describe "a desativação da conta (S1)" do
    test "encerra as sessões, e reativar não as devolve", ctx do
      {:ok, {sessao, segredo}} = Sessions.abrir(ctx.alvo)

      {:ok, _} =
        Tenants.disable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, %{
          "reason" => "left_the_organisation"
        })

      {:ok, _} =
        Tenants.enable_user(ctx.tenant, ctx.alvo.id, ctx.admin.id, %{
          "reason" => "returned_to_the_organisation"
        })

      assert {:error, :encerrada} = Sessions.conferir(sessao.id, segredo)
    end
  end

  defp dump_uuid(id), do: Ecto.UUID.dump!(id)
end
