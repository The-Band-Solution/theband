defmodule TheBand.Tenants.UltimoAdminAtivoTest do
  @moduledoc """
  A organização nunca fica sem administrador ativo — issue #1055.

  `disable_user/4` conferia só que ninguém desativa a si. Em sequência, isso bastava: o último
  administrador não pode se desativar. Em paralelo, não: dois administradores que desativam um
  ao outro ao mesmo tempo viam, cada um, o outro ativo, e a organização terminava sem nenhum.

  ## Por que dois testes para a mesma trava

  No sandbox do Ecto, as transações de processos diferentes já se enfileiram numa conexão só.
  O teste em paralelo prova o guarda e a releitura dentro da transação; o que prova a trava em
  si, que importa em produção, onde cada transação tem a sua conexão, é a captura do
  `FOR UPDATE` — o mesmo desenho da #1046.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Tenants
  alias TheBand.Tenants.User

  @razao %{"reason" => "left_the_organisation"}

  setup do
    {tenant, a} = tenant_with_admin()

    {:ok, b} =
      Tenants.create_user(tenant, %{
        "email" => "b-#{System.unique_integer([:positive])}@example.test",
        "role" => "admin"
      })

    %{tenant: tenant, a: a, b: b}
  end

  defp admins_ativos(tenant) do
    Repo.aggregate(
      from(u in User,
        where: u.tenant_id == ^tenant.id and u.role == "admin" and is_nil(u.disabled_at)
      ),
      :count
    )
  end

  # Desde a 072 (T007), a desativação passa pelo guarda de `PapelDeAdministrador`, que confere o
  # ator ANTES do último admin: um membro recebe `:nao_autorizado`. Pela desativação, o último
  # admin ativo só se alcança desativando a si, que tem recusa própria; a recusa
  # `:ultimo_admin_ativo` vive no rebaixamento, em `papel_de_administrador_test.exs`. O que este
  # caso continua provando é a invariante: a organização fica com um.
  test "desativar o último administrador ativo é recusado", ctx do
    {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.b.id, ctx.a.id, @razao)

    {:ok, c} =
      Tenants.create_user(ctx.tenant, %{
        "email" => "c-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    assert {:error, :nao_autorizado} = Tenants.disable_user(ctx.tenant, ctx.a.id, c.id, @razao)

    assert {:error, :nao_pode_desativar_a_si} =
             Tenants.disable_user(ctx.tenant, ctx.a.id, ctx.a.id, @razao)

    assert admins_ativos(ctx.tenant) == 1
  end

  test "duas desativações cruzadas em paralelo: uma passa, a outra é recusada, sobra um", ctx do
    resultados =
      [{ctx.b.id, ctx.a.id}, {ctx.a.id, ctx.b.id}]
      |> Task.async_stream(
        fn {alvo, autor} -> Tenants.disable_user(ctx.tenant, alvo, autor, @razao) end,
        max_concurrency: 2,
        ordered: false
      )
      |> Enum.map(fn {:ok, r} -> r end)

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    # A segunda transação relê o ator sob a trava: ele acabou de ser desativado (072/T007).
    assert Enum.count(resultados, &(&1 == {:error, :nao_autorizado})) == 1
    assert admins_ativos(ctx.tenant) == 1
  end

  test "as contas admin ativas são relidas com FOR UPDATE antes de desativar", ctx do
    ref = make_ref()
    eu = self()
    id = "ultimo-admin-#{inspect(ref)}"

    :telemetry.attach(
      id,
      [:the_band, :repo, :query],
      fn _e, _m, %{query: sql}, _ -> send(eu, {ref, sql}) end,
      nil
    )

    {:ok, _} = Tenants.disable_user(ctx.tenant, ctx.b.id, ctx.a.id, @razao)
    :telemetry.detach(id)

    consultas = coletar(ref, [])
    assert consultas != [], "a captura não mediu consulta nenhuma"
    assert Enum.any?(consultas, &(&1 =~ ~s(FROM "users") and &1 =~ "FOR UPDATE"))
  end

  defp coletar(ref, acc) do
    receive do
      {^ref, sql} -> coletar(ref, [sql | acc])
    after
      0 -> acc
    end
  end
end
