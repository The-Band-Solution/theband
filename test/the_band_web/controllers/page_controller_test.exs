defmodule TheBandWeb.PageControllerTest do
  use TheBandWeb.ConnCase, async: true

  test "a raiz leva para a entrada quando não há sessão", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/entrar"
  end

  test "a raiz leva para as pessoas quando há sessão", %{conn: conn} do
    {_tenant, user} = tenant_with_admin()

    conn = conn |> log_in(user) |> get(~p"/")

    assert redirected_to(conn) == ~p"/pessoas"
  end
end
