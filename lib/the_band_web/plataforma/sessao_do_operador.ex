defmodule TheBandWeb.Plataforma.SessaoDoOperador do
  @moduledoc """
  O cookie da sessão do operador da plataforma — spec 070, T035. Contrato em
  `specs/070-operador-da-plataforma/contracts/sessao-do-operador.md`.

  É o **único** leitor e escritor de `_the_band_operator`, e nunca lê `"session_id"` nem
  `"session_secret"`, que são da sessão das organizações (`TheBandWeb.Sessao`). Os dois nunca se
  tocam (FR-011).

  ## Por que um cookie próprio, e não `Plug.Session`

  Na sessão do `Plug.Session`, a do operador chegaria a toda rota e a todo socket de domínio, e
  cairia junto com o `drop` da saída das organizações (research R3.2). Por isso: cifrado
  (`encrypt: true`), `http_only`, `Secure` em produção, `SameSite=Strict`, e só em `/platform`.
  """
  import Plug.Conn

  alias TheBand.Platform.{Operator, Sessions}
  alias TheBand.Segredo

  @cookie "_the_band_operator"
  @caminho "/platform"
  # A mesma validade da linha em `Platform.Sessions`: 8 horas.
  @max_age 8 * 3600

  @doc "Confere a sessão do cookie. O motivo da recusa é para o log; na resposta a recusa é uma só."
  @spec conferir(Plug.Conn.t()) ::
          {:ok, TheBand.Platform.OperatorSession.t(), Operator.t()}
          | {:error, atom(), Ecto.UUID.t() | nil}
  def conferir(conn) do
    conn = fetch_cookies(conn, encrypted: [@cookie])

    case conn.cookies[@cookie] do
      %{"id" => id, "secret" => segredo} when is_binary(id) and is_binary(segredo) ->
        case Sessions.conferir(id, Segredo.novo(segredo)) do
          {:ok, sessao, op} -> {:ok, sessao, op}
          {:error, motivo} -> {:error, motivo, nil}
        end

      _ ->
        {:error, :sem_sessao, nil}
    end
  end

  @doc "Abre uma sessão para o operador e a grava no cookie próprio."
  @spec abrir(Plug.Conn.t(), Operator.t()) :: Plug.Conn.t()
  def abrir(conn, %Operator{} = op) do
    {:ok, {sessao, segredo}} = Sessions.abrir(op)

    put_resp_cookie(conn, @cookie, %{"id" => sessao.id, "secret" => Segredo.expor(segredo)},
      encrypt: true,
      http_only: true,
      secure: Application.get_env(:the_band, :cookie_de_sessao_seguro, false),
      same_site: "Strict",
      path: @caminho,
      max_age: @max_age
    )
  end

  @doc "Tira a sessão do cookie. Quem precisa também encerrá-la no servidor chama `Sessions.encerrar/1`."
  @spec soltar(Plug.Conn.t()) :: Plug.Conn.t()
  def soltar(conn), do: delete_resp_cookie(conn, @cookie, path: @caminho)
end
