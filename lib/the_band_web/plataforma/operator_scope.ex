defmodule TheBandWeb.Plataforma.OperatorScope do
  @moduledoc """
  Quem é o operador desta requisição — spec 070, T036 (FR-009, FR-011). Contrato em
  `specs/070-operador-da-plataforma/contracts/rotas-da-plataforma.md`.

  Depende de: nenhuma ontologia.

  É o par de `TheBandWeb.Plugs.CurrentScope` para `/platform`, e os dois **não se misturam**: este
  plug atribui `:current_operator` e `:current_operator_session`, ou nada, e nunca `:current_user`
  nem `:current_tenant`. O `Logger.metadata` recebe `operator_id`, e nunca `user_id` nem
  `tenant_id`: o log do operador não pode ser lido como se fosse de uma conta de organização.

  ## O `404`, e não o redirecionamento

  `require_operator/2` responde o **mesmo** `404` de um caminho que não existe (A12). Redirecionar a
  `/platform/sign-in` diria a quem varre que ali há uma área, e `require_admin` (que redireciona com
  flash) diria ainda que é uma área de quem administra. O anônimo e o admin de organização recebem a
  mesma página.
  """
  import Plug.Conn

  require Logger

  alias TheBandWeb.Plataforma.SessaoDoOperador

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case SessaoDoOperador.conferir(conn) do
      {:ok, sessao, op} ->
        Logger.metadata(operator_id: op.id)

        conn
        |> assign(:current_operator, op)
        |> assign(:current_operator_session, sessao)

      {:error, :sem_sessao, _} ->
        conn

      {:error, motivo, _} ->
        Logger.info("operador sessão recusada motivo=#{inspect(motivo)}")
        conn
    end
  end

  @doc "Sem operador, o `404` de caminho inexistente, e para."
  @spec require_operator(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def require_operator(%Plug.Conn{assigns: %{current_operator: _}} = conn, _opts), do: conn
  def require_operator(conn, _opts), do: nao_encontrado(conn)

  @doc """
  A resposta `404` da área do operador: `TheBandWeb.ErrorHTML`, `"404.html"`, o layout raiz que a
  pipeline já pôs. É a mesma para o curinga, para `require_operator/2` e para o slug que não
  existe — uma função só, para as três não divergirem.
  """
  @spec nao_encontrado(Plug.Conn.t()) :: Plug.Conn.t()
  def nao_encontrado(conn) do
    conn
    |> put_status(:not_found)
    |> Phoenix.Controller.put_view(html: TheBandWeb.ErrorHTML)
    |> Phoenix.Controller.render("404.html")
    |> halt()
  end

  @doc """
  `Cache-Control: no-store` em toda resposta de `/platform`: as páginas do cadastro carregam o
  segredo e os códigos, e a do histórico, o que só o operador lê. Nenhuma pode ficar no cache do
  navegador nem de um proxy.
  """
  @spec no_store(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def no_store(conn, _opts), do: put_resp_header(conn, "cache-control", "no-store")
end
