defmodule TheBand.MCP.Ferramentas.TeamOpenWork do
  @moduledoc """
  `team_open_work` — o que cada pessoa da equipe tem aberto agora, e há quanto tempo (feature
  062, T011).

  Responde à necessidade de informação `flow.work_in_progress`, pelo mesmo caminho do
  `open_by_person` da rota `GET /api/v1/teams/:id/measures`: `TeamWork.open_tasks_by_person/3`
  e `TeamWork.snapshot/4`.

  ## O que a resposta afirma

  - **Pessoa sem tarefa aberta não vira linha com zero.** Ela não aparece em `by_person`, e
    `totals.members` diz quantas pessoas a equipe tem. Somar as duas leituras responderia outra
    pergunta.
  - **`stale` é o corte da base**, `profile.thresholds.stale_open_work.stale_days`, o mesmo da
    tela: *parada* não tem dois sentidos na plataforma.
  - **`collected_at` é a coleta concluída mais recente do tenant**, e não o instante da
    pergunta: *aberta há 98 dias* é verdade na data da coleta.
  """

  alias TheBand.Ingestion
  alias TheBand.MCP.Composicao
  alias TheBand.MCP.Envelope
  alias TheBand.MCP.TextoDeTerceiro
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO.ItemPhase
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.TeamWork

  # O teto (N6 da revisão da implementação): sem ele, uma equipe grande devolveria tudo numa
  # resposta só. O corte é DITO, em `truncated`: uma lista de 200 de 900 é outra lista.
  @limite 200

  @doc "A resposta, com o envelope. A equipe chega carregada e já autorizada pelo registro."
  @spec responder(Tenant.t(), map()) :: map()
  def responder(%Tenant{} = tenant, equipe) do
    agora = DateTime.utc_now(:second)
    # O ESCOPO DO ROSTER, como `team_roster` e `/measures` — a correção da #987.
    escopo = EO.team_roster_scope(tenant, equipe.id)
    instantaneo = TeamWork.snapshot(tenant, equipe.id, agora, desde: agora, escopo: escopo)
    membros = EO.team_member_ids_at(tenant, equipe.id, agora, escopo: escopo)
    por_pessoa = TeamWork.open_tasks_by_person(tenant, equipe.id, agora, membros)
    # FR-033: em que quadro cada tarefa está. Uma consulta para todas, e não uma por tarefa.
    quadros = ItemPhase.quadros_das_issues(tenant, issue_ids(por_pessoa))

    [
      value: %{
        by_person: por_pessoa |> linhas(quadros) |> Enum.take(@limite),
        totals: %{members: instantaneo.membros, open: instantaneo.abertas},
        truncated: length(linhas(por_pessoa, quadros)) > @limite,
        limit: @limite
      },
      composition:
        Composicao.de(
          escopo,
          "Open work of the team's current members.",
          "Open work of the current members of the team and of its parts, each person and " <>
            "each task counted once."
        ),
      window: nil,
      origin: "observed",
      ressalvas: {:medida, "flow.wip.count"},
      collected_at: Ingestion.ultima_coleta_concluida(tenant)
    ]
    |> Envelope.montar()
    |> Map.put(:state, "checked")
  end

  defp issue_ids(por_pessoa), do: for({_, tarefas} <- por_pessoa, t <- tarefas, do: t.issue_id)

  # Pessoa sem tarefa aberta não vira linha com zero.
  defp linhas(por_pessoa, quadros) do
    for {person_id, tarefas} <- por_pessoa, tarefas != [] do
      %{person_id: person_id, tasks: Enum.map(tarefas, &tarefa(&1, quadros))}
    end
  end

  defp tarefa(t, quadros) do
    %{
      issue_id: t.issue_id,
      title: TextoDeTerceiro.marcar(t.titulo),
      concept: t.conceito,
      open_for_days: t.aberta_ha_dias,
      stale: t.parada?,
      boards: quadros |> Map.get(t.issue_id, []) |> Enum.map(&quadro/1)
    }
  end

  # Nome de quadro, de campo e de opção são escritos por pessoas na origem (FR-033).
  defp quadro(q) do
    %{
      board_id: q.quadro_id,
      board: TextoDeTerceiro.marcar(q.quadro),
      fields:
        Enum.map(q.campos, fn c ->
          %{
            field: TextoDeTerceiro.marcar(c.campo),
            value: TextoDeTerceiro.marcar(c.valor),
            phase: fase(c.fase)
          }
        end)
    }
  end

  # Observado e derivado nunca se misturam: a fase só existe se alguém declarou (066).
  defp fase(nil), do: %{state: "not_declared"}

  defp fase(%{conceito: c, declarada_em: em}),
    do: %{state: "declared", concept: c, declared_at: em}
end
