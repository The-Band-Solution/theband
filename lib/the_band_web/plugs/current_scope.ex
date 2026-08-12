defmodule TheBandWeb.Plugs.CurrentScope do
  @moduledoc """
  Resolve o tenant e a pessoa usuária da sessão.

  Toda consulta a dado coletado recebe o tenant daqui, e nenhuma o busca do
  dicionário de processo (FR-027, constituição princípio V).

  > **Lacuna declarada.** A autenticação desta entrega é seleção de usuário em
  > sessão, sem senha. O que está implementado de verdade é o **escopo**: o
  > tenant atravessa toda consulta e é testado com dois tenants povoados. A
  > autenticação propriamente dita é feature própria, e está registrada como não
  > entregue no `sprint-review.md` — não como pronta.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias TheBand.Tenants
  alias TheBand.Tenants.User

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        assign(conn, :current_user, nil) |> assign(:current_tenant, nil)

      user_id ->
        case Tenants.fetch_user(user_id) do
          {:ok, user} ->
            conn
            |> assign(:current_user, user)
            |> assign(:current_tenant, user.tenant)

          {:error, :not_found} ->
            conn
            |> delete_session(:user_id)
            |> assign(:current_user, nil)
            |> assign(:current_tenant, nil)
        end
    end
  end

  @doc "Exige sessão iniciada."
  def require_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn |> redirect(to: "/sign-in") |> halt()
    end
  end

  @doc """
  Exige perfil administrador.

  Só `admin` conecta ferramenta e gerencia credencial (Assumptions da spec).
  """
  def require_admin(conn, _opts) do
    if conn.assigns[:current_user] && User.admin?(conn.assigns.current_user) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(
        :error,
        "Only organisation administrators can do that."
      )
      |> redirect(to: "/people")
      |> halt()
    end
  end
end
