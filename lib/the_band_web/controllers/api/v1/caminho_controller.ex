defmodule TheBandWeb.Api.V1.CaminhoController do
  @moduledoc """
  O caminho que não existe sob `/api/v1` — issue #943, FR-020.

  Sem isto, um caminho inexistente não casava rota nenhuma, a pipeline do escopo nunca rodava,
  e o `Phoenix.Router.NoRouteError` respondia com a **página HTML do site**. Quem integra
  recebia um erro de parse de JSON, sem `code` e sem `request_id`.

  Responde `404 not_found`, no formato único, e não `405`: o recurso não existe, e dizer
  "método não permitido" mandaria quem integra procurar outro método para uma URL errada. O
  contrato é `specs/061-api-publica/contracts/erro.md`.

  Não entra na descrição OpenAPI: não é rota, é a ausência delas.
  """
  use TheBandWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TheBandWeb.Api.V1.Erro

  operation(:nao_encontrado, false)

  @doc "O `404` no formato único, com o `request_id` que liga a resposta ao log."
  def nao_encontrado(conn, _params) do
    id = Logger.metadata()[:request_id] || "sem-id"

    conn
    |> put_status(Erro.status(:not_found))
    |> json(Erro.corpo(:not_found, id))
  end
end
