defmodule TheBandWeb.PageController do
  use TheBandWeb, :controller

  def home(conn, _params) do
    # A raiz leva direto para onde há o que ver: a lista de pessoas quando há
    # sessão, a entrada quando não há.
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/pessoas")
    else
      redirect(conn, to: ~p"/entrar")
    end
  end
end
