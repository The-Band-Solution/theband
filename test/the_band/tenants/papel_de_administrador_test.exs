defmodule TheBand.Tenants.PapelDeAdministradorTest do
  @moduledoc """
  A marca de administrador — spec 072: o guarda único (T004), promover e rebaixar (T006), a
  desativação pelo mesmo guarda (T007) e a leitura do registro (T010).

  ## Por que a trava se prova por captura, e a corrida por sequência forçada

  No sandbox do Ecto, transações de processos diferentes se enfileiram numa conexão só, então o
  teste em paralelo prova o guarda e a releitura, e a captura do SQL prova o `FOR UPDATE` — o
  desenho de `ultimo_admin_ativo_test.exs`. O caso de S3 precisa de uma struct velha **no meio**
  do ato, e a ordem é forçada por um handler de telemetria que roda no próprio processo, logo
  depois da leitura do alvo: é a janela que o achado descreve, sem depender de sorte.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Tenants
  alias TheBand.Tenants.PapelDeAdministrador
  alias TheBand.Tenants.Schemas.AccountRoleChange
  alias TheBand.Tenants.User

  @razao %{"reason" => "left_the_organisation"}

  setup do
    {tenant, a} = tenant_with_admin()
    b = conta(tenant, "admin")
    m = conta(tenant, "member")
    %{tenant: tenant, a: a, b: b, m: m}
  end

  defp conta(tenant, papel) do
    {:ok, u} =
      Tenants.create_user(tenant, %{
        "email" => "c-#{System.unique_integer([:positive])}@example.test",
        "role" => papel
      })

    u
  end

  defp admins_ativos(tenant) do
    Repo.aggregate(
      from(u in User,
        where: u.tenant_id == ^tenant.id and u.role == "admin" and is_nil(u.disabled_at)
      ),
      :count
    )
  end

  defp papel(user), do: Repo.get!(User, user.id).role

  defp episodios(tenant),
    do: Repo.aggregate(where(AccountRoleChange, tenant_id: ^tenant.id), :count)

  defp no_guarda(fun) do
    {:ok, r} = Repo.transaction(fn -> fun.() end)
    r
  end

  describe "o guarda (T004)" do
    test "o ator que não é admin ativo da organização não passa", ctx do
      assert no_guarda(fn -> PapelDeAdministrador.travar(ctx.tenant.id, ctx.m.id, ctx.b.id) end) ==
               {:error, :nao_autorizado}

      {outro, admin_de_fora} = tenant_with_admin()
      _ = outro

      assert no_guarda(fn ->
               PapelDeAdministrador.travar(ctx.tenant.id, admin_de_fora.id, ctx.b.id)
             end) == {:error, :nao_autorizado}
    end

    test "o alvo de outra organização é não encontrado", ctx do
      {_outro, de_fora} = tenant_with_admin()

      assert no_guarda(fn -> PapelDeAdministrador.travar(ctx.tenant.id, ctx.a.id, de_fora.id) end) ==
               {:error, :not_found}
    end

    test "o alvo devolvido é o relido no banco, e não a struct que a tela tinha", ctx do
      velha = ctx.m
      {:ok, _} = Tenants.promote_user(ctx.tenant, velha.id, ctx.a)

      {:ok, %{alvo: alvo, admins_ativos: admins}} =
        no_guarda(fn -> PapelDeAdministrador.travar(ctx.tenant.id, ctx.a.id, velha.id) end)

      assert velha.role == "member"
      assert alvo.role == "admin"
      assert velha.id in admins
    end

    test "ultimo_admin_ativo? decide pelo conjunto travado", ctx do
      {:ok, _} = Tenants.demote_user(ctx.tenant, ctx.b.id, ctx.a)

      {:ok, travado} =
        no_guarda(fn -> PapelDeAdministrador.travar(ctx.tenant.id, ctx.a.id, ctx.a.id) end)

      assert PapelDeAdministrador.ultimo_admin_ativo?(travado)

      {:ok, travado} =
        no_guarda(fn -> PapelDeAdministrador.travar(ctx.tenant.id, ctx.a.id, ctx.m.id) end)

      refute PapelDeAdministrador.ultimo_admin_ativo?(travado)
    end

    test "exigir_ator relê o ator no banco", ctx do
      assert PapelDeAdministrador.exigir_ator(ctx.tenant.id, ctx.b.id) == :ok
      {:ok, _} = Tenants.demote_user(ctx.tenant, ctx.b.id, ctx.a)

      assert PapelDeAdministrador.exigir_ator(ctx.tenant.id, ctx.b.id) ==
               {:error, :nao_autorizado}

      assert PapelDeAdministrador.exigir_ator(ctx.tenant.id, ctx.m.id) ==
               {:error, :nao_autorizado}

      assert PapelDeAdministrador.exigir_ator(ctx.tenant.id, nil) == {:error, :nao_autorizado}
    end

    test "as contas admin ativas e o alvo são lidos com FOR UPDATE", ctx do
      consultas = capturar(fn -> Tenants.promote_user(ctx.tenant, ctx.m.id, ctx.a) end)
      assert consultas != [], "a captura não mediu consulta nenhuma"
      travas = Enum.filter(consultas, &(&1 =~ ~s(FROM "users") and &1 =~ "FOR UPDATE"))
      assert length(travas) >= 2, inspect(consultas)
    end
  end

  describe "promover e rebaixar (T006)" do
    test "promover grava o papel e o episódio de quem, de e para", ctx do
      assert {:ok, ep} =
               Tenants.promote_user(ctx.tenant, ctx.m.id, ctx.a, note: "  lidera o time ")

      assert papel(ctx.m) == "admin"

      assert %{from_role: "member", to_role: "admin", note: "lidera o time"} = ep
      assert ep.changed_by_user_id == ctx.a.id and ep.user_id == ctx.m.id
    end

    test "rebaixar grava o papel e o episódio, e a nota em branco vira ausência", ctx do
      assert {:ok, ep} = Tenants.demote_user(ctx.tenant, ctx.b.id, ctx.a, note: "   ")
      assert papel(ctx.b) == "member"
      assert %{from_role: "admin", to_role: "member", note: nil} = ep
    end

    test "cada motivo do contrato, e nada muda na recusa", ctx do
      {_outro, de_fora} = tenant_with_admin()
      antes = {episodios(ctx.tenant), papel(ctx.a), papel(ctx.b), papel(ctx.m)}

      assert Tenants.promote_user(ctx.tenant, ctx.b.id, ctx.m) == {:error, :nao_autorizado}
      assert Tenants.promote_user(ctx.tenant, de_fora.id, ctx.a) == {:error, :not_found}
      assert Tenants.promote_user(ctx.tenant, ctx.b.id, ctx.a) == {:error, {:estado_mudou, nil}}
      assert Tenants.demote_user(ctx.tenant, ctx.m.id, ctx.a) == {:error, {:estado_mudou, nil}}

      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.m.id, ctx.a.id, @razao)
      assert Tenants.promote_user(ctx.tenant, ctx.m.id, ctx.a) == {:error, :conta_desativada}

      assert antes == {episodios(ctx.tenant), papel(ctx.a), papel(ctx.b), papel(ctx.m)}

      {:ok, _} = Tenants.demote_user(ctx.tenant, ctx.b.id, ctx.a)
      assert Tenants.demote_user(ctx.tenant, ctx.a.id, ctx.a) == {:error, :ultimo_admin_ativo}
      assert papel(ctx.a) == "admin"
    end

    test "quem chega atrasado recebe o episódio de quem mudou antes", ctx do
      {:ok, primeiro} = Tenants.demote_user(ctx.tenant, ctx.b.id, ctx.a)

      assert {:error, {:estado_mudou, %AccountRoleChange{id: id}}} =
               Tenants.demote_user(ctx.tenant, ctx.b.id, ctx.a)

      assert id == primeiro.id
    end

    test "S2: o rebaixado com a struct de antes não se promove de volta", ctx do
      velha_de_b = ctx.b
      {:ok, _} = Tenants.demote_user(ctx.tenant, ctx.b.id, ctx.a)

      assert Tenants.promote_user(ctx.tenant, velha_de_b.id, velha_de_b) ==
               {:error, :nao_autorizado}

      assert papel(ctx.b) == "member"
    end

    test "Q1: o administrador desativado pode ser rebaixado, e não conta para o guarda", ctx do
      {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.b.id, ctx.a.id, @razao)
      assert {:ok, %{to_role: "member"}} = Tenants.demote_user(ctx.tenant, ctx.b.id, ctx.a)
      assert admins_ativos(ctx.tenant) == 1
    end

    test "SC-001: dez rebaixamentos cruzados concorrentes deixam um administrador, em 10 de 10" do
      for _ <- 1..10 do
        {tenant, x} = tenant_with_admin()
        y = conta(tenant, "admin")

        resultados =
          [{y.id, x}, {x.id, y}]
          |> Task.async_stream(fn {alvo, ator} -> Tenants.demote_user(tenant, alvo, ator) end,
            max_concurrency: 2,
            ordered: false
          )
          |> Enum.map(fn {:ok, r} -> r end)

        assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
        assert admins_ativos(tenant) == 1
      end
    end
  end

  describe "a desativação pelo mesmo guarda (T007)" do
    # S3, os passos 1 a 5 do achado: A é o único admin e C é membro. A abre a desativação de C, e
    # entre a leitura de C e a transação, A promove C e C rebaixa A.
    test "S3: a struct velha de um membro promovido no meio não deixa a organização sem admin" do
      {tenant, a} = tenant_with_admin()
      c = conta(tenant, "member")

      na_janela(fn ->
        {:ok, _} = Tenants.promote_user(tenant, c.id, a)
        {:ok, _} = Tenants.demote_user(tenant, a.id, c)
      end)

      assert Tenants.disable_user(tenant, c.id, a.id, @razao) == {:error, :nao_autorizado}
      assert Process.get(:janela) == :aberta, "a janela de S3 não foi aberta"
      assert admins_ativos(tenant) == 1
    end

    # A releitura do alvo, isolada: o ator continua admin, e só o alvo mudou na janela. Com a
    # struct lida antes, a desativação abriria um segundo episódio sobre uma conta já desativada.
    test "a conta desativada por outro admin na janela é recusada como já desativada", ctx do
      na_janela(fn -> {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.m.id, ctx.b.id, @razao) end)

      assert Tenants.disable_user(ctx.tenant, ctx.m.id, ctx.a.id, @razao) ==
               {:error, :ja_desativada}

      assert Process.get(:janela) == :aberta, "a janela não foi aberta"
    end
  end

  describe "role_changes (T010)" do
    test "do mais novo ao mais antigo, só da organização, com a contagem", ctx do
      {outro, x} = tenant_with_admin()
      {:ok, _} = Tenants.promote_user(outro, conta(outro, "member").id, x)

      {:ok, e1} = Tenants.promote_user(ctx.tenant, ctx.m.id, ctx.a)
      {:ok, e2} = Tenants.demote_user(ctx.tenant, ctx.b.id, ctx.a)
      {:ok, e3} = Tenants.demote_user(ctx.tenant, ctx.m.id, ctx.a)

      assert %{mudancas: mudancas, total: 3} = Tenants.role_changes(ctx.tenant)
      assert Enum.map(mudancas, & &1.id) == [e3.id, e2.id, e1.id]
      assert hd(mudancas).changed_by_user.email == ctx.a.email
      assert hd(mudancas).user.email == ctx.m.email

      assert %{mudancas: [um], total: 3} = Tenants.role_changes(ctx.tenant, limit: 1)
      assert um.id == e3.id
    end
  end

  # Roda `atos` no próprio processo, logo depois da primeira leitura de `users` sem trava — a que
  # `disable_user/4` faz antes da transação. Uma vez só, e desligado ao fim do teste.
  defp na_janela(atos) do
    eu = self()
    id = "janela-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      id,
      [:the_band, :repo, :query],
      fn _e, _m, %{query: sql}, _ ->
        if self() == eu and sql =~ ~s(FROM "users") and not (sql =~ "FOR UPDATE") and
             Process.get(:janela) == nil do
          Process.put(:janela, :aberta)
          atos.()
        end
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(id) end)
  end

  defp capturar(fun) do
    ref = make_ref()
    eu = self()
    id = "papel-#{inspect(ref)}"

    :telemetry.attach(
      id,
      [:the_band, :repo, :query],
      fn _e, _m, %{query: sql}, _ -> send(eu, {ref, sql}) end,
      nil
    )

    fun.()
    :telemetry.detach(id)
    coletar(ref, [])
  end

  defp coletar(ref, acc) do
    receive do
      {^ref, sql} -> coletar(ref, [sql | acc])
    after
      0 -> acc
    end
  end
end
