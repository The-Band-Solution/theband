defmodule TheBandWeb.Sessao do
  @moduledoc """
  O **único** leitor e escritor do cookie de sessão — feature 064, T013.

  O plug `TheBandWeb.Plugs.CurrentScope`, a hook `:current_scope` e o `SessionController`
  passam por aqui. Antes, cada um conferia o token do seu jeito, e a validade de 7 dias vivia só
  na hook: `POST /profile/password` aceitava sessão vencida (achado S6), e `set_password` tinha
  uma comparação própria, que era uma segunda porta (S3).

  ## O cookie

  Duas chaves: `"session_id"`, a chave primária da linha em `user_sessions`, e
  `"session_secret"`, o token bruto. O banco tem só o resumo do token. `"user_id"` saiu: a conta
  vem da linha, e um cookie que traga só `user_id` não abre nada (S4).

  O cookie continua **assinado, e não cifrado**, com o `SECRET_KEY_BASE`. A diferença é que quem
  tem a chave e um dump não tem mais o bruto.
  """

  import Plug.Conn

  alias TheBand.Segredo
  alias TheBand.Tenants.Schemas.UserSession
  alias TheBand.Tenants.Sessions
  alias TheBand.Tenants.User

  @id "session_id"
  @segredo "session_secret"

  # As chaves do cookie de antes da T013. São apagadas ao gravar, para um cookie antigo não
  # carregar para sempre o valor que o banco guardava em claro.
  @antigas ["user_id", "session_token"]

  @type motivo :: :sem_sessao | Sessions.motivo()

  @doc """
  Confere a sessão do cookie e devolve a sessão e a conta, ou o motivo da recusa com a dona da
  sessão, quando ela é conhecida. O motivo é para o log interno: na tela a recusa é uma só.

  Recebe o mapa da sessão, que o plug lê com `get_session/1` e a hook recebe pronto.
  """
  @spec conferir(map()) ::
          {:ok, UserSession.t(), User.t()}
          | {:error, motivo(), {Ecto.UUID.t(), Ecto.UUID.t()} | nil}
  def conferir(%{@id => id, @segredo => bruto}) when is_binary(id) and is_binary(bruto) do
    case Sessions.conferir(id, Segredo.novo(bruto)) do
      {:ok, sessao, user} -> {:ok, sessao, user}
      {:error, motivo} -> {:error, motivo, Sessions.dona(id)}
    end
  end

  def conferir(_sessao), do: {:error, :sem_sessao, nil}

  @doc """
  Abre uma sessão nova para a conta e a grava no cookie, renovando o id do cookie. O bruto sai
  do `Segredo` aqui, e só aqui, porque o cookie é onde ele precisa existir.
  """
  @spec abrir(Plug.Conn.t(), User.t()) :: Plug.Conn.t()
  def abrir(conn, %User{} = user) do
    {:ok, {sessao, segredo}} = Sessions.abrir(user)

    Enum.reduce(@antigas, configure_session(conn, renew: true), &delete_session(&2, &1))
    |> put_session(@id, sessao.id)
    |> put_session(@segredo, Segredo.expor(segredo))
  end

  @doc "Tira a sessão do cookie. Quem precisa também encerrá-la no servidor chama `encerrar/1`."
  @spec soltar(Plug.Conn.t()) :: Plug.Conn.t()
  def soltar(conn) do
    Enum.reduce([@id, @segredo | @antigas], conn, &delete_session(&2, &1))
  end
end
