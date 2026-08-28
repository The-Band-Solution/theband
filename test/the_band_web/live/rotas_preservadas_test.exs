defmodule TheBandWeb.RotasPreservadasTest do
  @moduledoc """
  FR-004 da spec 046: a reorganização do menu não muda rota nenhuma.

  As nove telas que saíram da barra continuam respondendo nas URLs de sempre —
  quem tem favorito, script ou link em issue não perde nada. O gating que já
  existia (Tools só para admin) também não muda: esta feature move itens de
  menu, não autorização.
  """

  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @rotas_movidas [
    "/roles",
    "/work",
    "/work/changes",
    "/work/files",
    "/work/verifications",
    "/boards",
    "/process",
    "/syncs"
  ]

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, member} =
      TheBand.Tenants.create_user(tenant, %{
        "email" => "member-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{conn: conn, tenant: tenant, admin: admin, member: member}
  end

  test "as telas movidas respondem nas URLs de sempre", %{conn: conn, admin: admin} do
    for rota <- @rotas_movidas do
      assert {:ok, _view, _html} = conn |> log_in(admin) |> live(rota),
             "#{rota} deveria montar como antes da feature 046"
    end
  end

  test "o gating de /tools continua o que era: admin entra", %{conn: conn, admin: admin} do
    assert {:ok, _view, _html} = conn |> log_in(admin) |> live("/tools")
  end

  test "o gating de /tools continua o que era: member é redirecionado", %{
    conn: conn,
    member: member
  } do
    assert {:error, {:redirect, %{to: "/people"}}} =
             conn |> log_in(member) |> live("/tools")
  end
end
