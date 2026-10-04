defmodule TheBandWeb.Plugs.JornadaDeEntrada do
  @moduledoc """
  O correlator da jornada de entrar — spec 074, T013; FR-011; seguranca.md, S5.

  Depende de: nenhuma ontologia.

  Liga a abertura da tela de entrada à tentativa que vem depois, e a nada mais: é o que permite
  ao painel contar quem abriu e não tentou (`abandonou`, research R6).

  ## Onde ele mora, e quando morre

  - **nasce no servidor**, só no `GET /sign-in`, com 16 bytes aleatórios; o cliente não o
    escolhe. O LiveView não escreve cookie, e por isso o valor nasce aqui, num plug;
  - **mora na sessão do Phoenix**, que é assinada: o cliente não o forja. Campo oculto no
    formulário deixaria o cliente casar a própria tentativa com a abertura de outra pessoa;
  - é **substituído** a cada abertura, e nunca reaproveitado entre jornadas;
  - é **apagado** por `SessionController.create/2` depois da tentativa, com **qualquer**
    desfecho. A sessão é assinada e **não cifrada**: uma chave apagada num motivo e mantida
    noutro diria ao cliente qual dos dois aconteceu (S4).

  Não deriva do token de sessão, do id da sessão nem da conta. Não autentica nada; é um
  identificador de **visita**, e por isso morre na tentativa.
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: "GET"} = conn, _opts), do: put_session(conn, :jornada_id, novo())
  def call(conn, _opts), do: conn

  @doc "Um correlator novo: 16 bytes aleatórios, 22 caracteres base64url."
  @spec novo() :: String.t()
  def novo, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
end
