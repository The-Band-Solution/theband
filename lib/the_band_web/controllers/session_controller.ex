defmodule TheBandWeb.SessionController do
  use TheBandWeb, :controller

  alias TheBand.Tenants

  def create(conn, %{"user_id" => user_id}) do
    case Tenants.fetch_user(user_id) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: ~p"/people")

      {:error, :not_found} ->
        conn |> put_flash(:error, "Usuário não encontrado.") |> redirect(to: ~p"/sign-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/sign-in")
  end
end
