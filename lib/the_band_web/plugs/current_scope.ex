defmodule TheBandWeb.Plugs.CurrentScope do
  @moduledoc """
  Resolve o tenant e a pessoa usuária da sessão.

  Toda consulta a dado coletado recebe o tenant daqui, e nenhuma o busca do
  dicionário de processo (FR-027, constituição princípio V).

  A lacuna declarada da fundação — sessão por escolha, sem senha — fechou na
  feature 045: a sessão nasce em `POST /session` com identificador e senha, e
  carrega o `session_token` da conta. Token divergente aqui é senha trocada em
  outro navegador (FR-015): a sessão cai como se não existisse.
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
            if user.session_token == get_session(conn, :session_token) do
              conn
              |> assign(:current_user, user)
              |> assign(:current_tenant, user.tenant)
            else
              sem_sessao(conn)
            end

          {:error, :not_found} ->
            sem_sessao(conn)
        end
    end
  end

  defp sem_sessao(conn) do
    conn
    |> delete_session(:user_id)
    |> delete_session(:session_token)
    |> assign(:current_user, nil)
    |> assign(:current_tenant, nil)
  end

  @doc "Exige sessão iniciada — e guarda o destino para depois da entrada (FR-005)."
  def require_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> salvar_destino()
      |> redirect(to: "/sign-in")
      |> halt()
    end
  end

  # Só GET carrega destino: repetir um POST depois do login seria repetir uma
  # ação que a pessoa não confirmou.
  defp salvar_destino(%Plug.Conn{method: "GET"} = conn),
    do: put_session(conn, :redirect_to, conn.request_path)

  defp salvar_destino(conn), do: conn

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

  @doc """
  Exige alcance operacional — FR-023 da feature 045.

  Syncs e Tools existem para administrador (tenant inteiro) ou para quem tem
  concessão organization vigente — e aí com recorte, que fica em
  `conn.assigns.operacao` para a tela filtrar pelo que pertence às organizações
  concedidas. A recusa nomeia o motivo.
  """
  def require_operacao(conn, _opts) do
    with user when not is_nil(user) <- conn.assigns[:current_user],
         {true, recorte} <- Tenants.operacional?(conn.assigns.current_tenant, user) do
      assign(conn, :operacao, recorte)
    else
      _ ->
        conn
        |> Phoenix.Controller.put_flash(
          :error,
          "Syncs e Tools pedem administração ou escopo organization — o seu acesso não os alcança."
        )
        |> redirect(to: "/people")
        |> halt()
    end
  end
end
