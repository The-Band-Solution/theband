defmodule TheBandWeb.Api.V1.TeamController do
  @moduledoc """
  `GET /api/v1/teams` — a primeira rota da API pública (feature 061, US2).

  ## O recorte é o da tela, e isso fica dito

  As equipes são as **do tenant do token**. A tela `/teams` recorta por tenant e **não filtra
  por `Access`** — chama `EO.list_teams(tenant, ...)` e mais nada. Esta rota espelha a tela,
  que é o requisito (FR-026).

  **Não é frouxidão da API**: é a mesma resposta que a pessoa vê logada. Se a tela passar a
  filtrar, esta rota muda junto, e o teste de contrato apanha a divergência.

  ## Cursor, e não deslocamento

  Deslocamento pula ou repete linha quando a coleção muda entre páginas. O cursor é o último
  identificador visto, e a ordem é estável por ele.

  ## A escrita não responde

  Só `GET` e `HEAD`. Nenhum método de escrita tem autor honesto para a proveniência — FR-017.
  """
  use TheBandWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.Api.V1.Erro
  alias TheBandWeb.Schemas

  require Logger

  @padrao 50
  @teto 200

  tags(["teams"])

  operation(:index,
    summary: "Teams of the token's tenant",
    description: """
    Every team the owner account sees on screen, with the mark of where it came from.

    The collection carries **no total** — it carries *has next page*, and says it carries no
    total. An estimated total is worse than an absent one.
    """,
    parameters: [
      page_size: [
        in: :query,
        type: :integer,
        description:
          "Default 50, maximum 200. A larger value is reduced to the maximum, not refused.",
        required: false
      ],
      after: [
        in: :query,
        type: :string,
        description: "Opaque cursor from the previous page's `next_cursor`.",
        required: false
      ]
    ],
    responses: [
      ok: {"The teams", "application/json", Schemas.Teams},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro}
    ]
  )

  def index(conn, params) do
    tenant = conn.assigns.current_tenant
    tamanho = tamanho_da_pagina(params)

    # Pede UM a mais que a página para saber se há próxima sem contar a coleção — que é o
    # que torna possível não devolver total sem mentir sobre a existência da página seguinte.
    # `:inicio` e não `nil`: nulo significaria "sem cursor", e a listagem voltaria à ordem
    # por nome da tela — a primeira página numa ordem e as seguintes noutra.
    cursor = params["after"] || :inicio
    equipes = EO.list_teams(tenant, limit: tamanho + 1, after: cursor)
    {pagina, tem_proxima?} = cortar(equipes, tamanho)

    json(conn, %{
      data: Enum.map(pagina, &serializar/1),
      page: %{
        has_next: tem_proxima?,
        next_cursor: if(tem_proxima?, do: List.last(pagina).id),
        total: nil,
        total_note:
          "This API does not count collections. An estimated total is worse than an absent one."
      }
    })
  end

  # FORA da descrição, de propósito: `operation false` diz ao gerador para ignorar esta
  # ação. Ela não é um endpoint — é a recusa dos métodos que o endpoint não tem, e
  # documentá-la como operação faria o Swagger oferecer `POST /teams` para ser experimentado.
  operation(:nao_permitido, false)

  @doc """
  A recusa de escrita — FR-017, e ela é do desenho, não da falta de implementação.

  **Não há autor honesto para a proveniência de uma escrita feita por token.** A plataforma
  registra quem declarou cada coisa, e um token é credencial de integração: atrás dele pode
  estar um painel, um script noturno ou um agente. Gravar "declarado por" com o nome da
  conta dona afirmaria algo que ninguém fez.
  """
  def nao_permitido(conn, _params) do
    id = Logger.metadata()[:request_id] || "sem-id"

    conn
    |> put_status(Erro.status(:method_not_allowed))
    |> put_resp_header("allow", "GET, HEAD")
    |> json(Erro.corpo(:method_not_allowed, id))
  end

  # Pedido acima do teto é REDUZIDO ao teto, e não recusado: quem pede 1 000 quer o máximo
  # que puder ter, e recusar vira erro de parâmetro sem informação nova.
  defp tamanho_da_pagina(params) do
    case Integer.parse(to_string(params["page_size"] || "")) do
      {n, _} when n > 0 -> min(n, @teto)
      _ -> @padrao
    end
  end

  defp cortar(equipes, tamanho) do
    if length(equipes) > tamanho,
      do: {Enum.take(equipes, tamanho), true},
      else: {equipes, false}
  end

  # A MARCA DE ORIGEM viaja com cada equipe. A plataforma inteira existe para separar o que
  # foi observado do que foi declarado, e entregar sem a marca destruiria a distinção
  # exatamente no ponto de entrega — com o agravante de o consumidor previsto ser um modelo,
  # que afirmaria o dado sem ela.
  defp serializar(equipe) do
    observada? = not is_nil(equipe.source_system)

    %{
      id: equipe.id,
      name: equipe.name,
      slug: equipe.slug,
      origin: if(observada?, do: "observed", else: "declared"),
      source_system: equipe.source_system,
      collected_at: equipe.collected_at
    }
  end
end
