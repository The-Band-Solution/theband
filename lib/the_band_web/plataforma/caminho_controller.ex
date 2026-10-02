defmodule TheBandWeb.Plataforma.CaminhoController do
  @moduledoc """
  O caminho de `/platform` que não existe — spec 070, T036 (A12).

  Depende de: nenhuma ontologia.

  Responde o mesmo `404` de `OperatorScope.require_operator/2`, pela mesma função: o curinga e a
  rota de operador sem operador não podem dar respostas distinguíveis, ou a diferença diria a quem
  varre quais caminhos são de verdade.

  Até T039 e T040, as rotas do contrato também apontam para cá.
  """
  use TheBandWeb, :controller

  alias TheBandWeb.Plataforma.OperatorScope

  @doc "O `404` da área do operador."
  @spec nao_encontrado(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def nao_encontrado(conn, _params), do: OperatorScope.nao_encontrado(conn)
end
