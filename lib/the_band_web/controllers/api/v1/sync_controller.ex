defmodule TheBandWeb.Api.V1.SyncController do
  @moduledoc """
  `GET /api/v1/syncs` — as coletas, e o que cada uma NÃO alcançou (feature 061, FR-021).

  ## Esta rota existe para responder *"o dado está atualizado?"*

  É a pergunta que toda integração faz antes de confiar em qualquer número das outras rotas.
  Uma contagem de issues lida sem saber quando a coleta rodou é um número sem data.

  ## `completed` não quer dizer *completo*, e é por isso que há um bloco de lacunas

  Uma coleta pode terminar com status `completed` e **não ter alcançado** repositórios — por
  limite de cota, por permissão, por indisponibilidade da origem.

  Quem lê só o `status` conclui que o dado está inteiro. `repositories_unreachable` e
  `repositories_skipped` são o que impede essa leitura, e por isso viajam **no mesmo objeto**
  — não atrás de uma segunda chamada que ninguém faria.

  É a mesma regra que esta plataforma aplica a si mesma: ausência escrita, nunca zero
  silencioso.

  ## Os quatro contadores de registro não se somam

  `collected` é o que a origem devolveu; `created`, `updated` e `skipped` são o que se fez com
  cada um, e um registro coletado cai em exatamente um dos três. Somar os quatro contaria a
  coleta duas vezes.
  """
  use TheBandWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TheBand.Ingestion
  alias TheBandWeb.Api.V1.Erro
  alias TheBandWeb.Schemas

  require Logger

  @padrao 20
  @teto 100

  @nota_dos_registros "Four readings of the same run, never summed: a record collected may " <>
                        "be created, updated or skipped — it falls into exactly one."

  @nota_das_lacunas "A run that finished is not a run that reached everything. These are " <>
                      "what it did not reach, and they are here so that `completed` is " <>
                      "never read as *complete*."

  tags(["syncs"])

  operation(:index,
    summary: "Collection runs, and what each one did not reach",
    description: """
    Answers *"is the data current?"* — which every integration asks before trusting any
    number from the other routes.

    **`completed` does not mean complete.** A run can finish and still not have reached
    repositories — quota, permission, or the source being unavailable. `gaps` travels in the
    same object so that the status is never read alone.

    Neither the credential nor who interrupted a run is returned: the route says **which
    tool**, never which key, and `interrupted_by_person` answers the question without naming
    anyone.

    Note that `interrupted_by_person` is **not** the same as `status: "interrupted"`: a run
    can be interrupted with nobody behind it, when the reconciler closes one whose process no
    longer exists.
    """,
    parameters: [
      page_size: [
        in: :query,
        type: :integer,
        description: "Default 20, maximum 100. Most recent first.",
        required: false
      ]
    ],
    responses: [
      ok: {"The runs", "application/json", Schemas.Syncs},
      unauthorized: {"Credential not usable", "application/json", Schemas.Erro}
    ]
  )

  def index(conn, params) do
    tamanho = tamanho_da_pagina(params)

    # Uma a mais que o pedido, para saber se há próxima sem contar a coleção inteira.
    coletas = Ingestion.list_syncs(conn.assigns.current_tenant, limit: tamanho + 1)
    {pagina, tem_proxima?} = cortar(coletas, tamanho)

    json(conn, %{
      data: Enum.map(pagina, &serializar/1),
      page: %{
        has_next: tem_proxima?,
        next_cursor: nil,
        total: nil,
        total_note:
          "This API does not count collections. An estimated total is worse than an absent one."
      }
    })
  end

  operation(:nao_permitido, false)

  @doc "A recusa de escrita — FR-017. Ver `TeamController.nao_permitido/2`."
  def nao_permitido(conn, _params) do
    id = Logger.metadata()[:request_id] || "sem-id"

    conn
    |> put_status(Erro.status(:method_not_allowed))
    |> put_resp_header("allow", "GET, HEAD")
    |> json(Erro.corpo(:method_not_allowed, id))
  end

  defp tamanho_da_pagina(params) do
    case Integer.parse(to_string(params["page_size"] || "")) do
      {n, _} when n > 0 -> min(n, @teto)
      _ -> @padrao
    end
  end

  defp cortar(lista, tamanho) do
    if length(lista) > tamanho,
      do: {Enum.take(lista, tamanho), true},
      else: {lista, false}
  end

  # **`credential_id` e `interrupted_by_user_id` NÃO saem.** O primeiro é o elo para a
  # credencial, e a API que lista credencial é a API que a vaza. O segundo identifica pessoa
  # por id interno numa rota que não tem por que fazê-lo — `interrupted` responde a pergunta.
  defp serializar(s) do
    %{
      id: s.id,
      status: s.status,
      started_at: s.started_at,
      finished_at: s.finished_at,
      records: %{
        collected: s.records_collected,
        created: s.records_created,
        updated: s.records_updated,
        skipped: s.records_skipped,
        note: @nota_dos_registros
      },
      gaps: %{
        repositories_skipped: s.repositories_skipped,
        repositories_unreachable: s.repositories_unreachable,
        skip_reasons: s.skip_reasons,
        memberships_pending_role: s.memberships_pending_role,
        note: @nota_das_lacunas
      },
      error_reason: s.error_reason,
      # **`interrupted_by_person`, e não `interrupted`.** Medido em 2026-09-22: existe coleta
      # com `status: "interrupted"` e nenhuma pessoa por trás — o reconciliador a encerrou
      # porque *"o processo que a executava não existe mais"*. Um campo chamado `interrupted`
      # devolvendo `false` nessa linha contradiria o `status` ao lado, e quem integra teria de
      # escolher em qual acreditar.
      interrupted_by_person: not is_nil(s.interrupted_by_user_id)
    }
  end
end
