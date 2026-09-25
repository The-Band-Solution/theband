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
  alias TheBand.MCP.Envelope
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.TeamWork

  @doc "A resposta, com o envelope. A equipe chega carregada e já autorizada pelo registro."
  @spec responder(Tenant.t(), map()) :: map()
  def responder(%Tenant{} = tenant, equipe) do
    agora = DateTime.utc_now(:second)
    instantaneo = TeamWork.snapshot(tenant, equipe.id, agora, desde: agora)
    por_pessoa = TeamWork.open_tasks_by_person(tenant, equipe.id, agora)

    [
      value: %{
        by_person:
          for {person_id, tarefas} <- por_pessoa, tarefas != [] do
            %{person_id: person_id, tasks: Enum.map(tarefas, &tarefa/1)}
          end,
        totals: %{members: instantaneo.membros, open: instantaneo.abertas}
      },
      composition: %{is_composed: false, note: "Open work of the team's current members."},
      window: nil,
      origin: "observed",
      ressalvas: {:medida, "flow.wip.count"},
      collected_at: Ingestion.ultima_coleta_concluida(tenant)
    ]
    |> Envelope.montar()
    |> Map.put(:state, "checked")
  end

  defp tarefa(t) do
    %{
      issue_id: t.issue_id,
      title: t.titulo,
      concept: t.conceito,
      open_for_days: t.aberta_ha_dias,
      stale: t.parada?
    }
  end
end
