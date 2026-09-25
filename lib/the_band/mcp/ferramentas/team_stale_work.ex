defmodule TheBand.MCP.Ferramentas.TeamStaleWork do
  @moduledoc """
  `team_stale_work` — o que está parado na equipe, e há quanto tempo, segundo o limiar
  declarado (feature 062, T013).

  Responde à `cmo.cq03`, *"Um artefato parado tem discussão recente?"*. As paradas vêm de
  `TeamWork.open_tasks_by_person/3`, e a conversa de `Profiles.conversa_das_issues/2`: a mesma
  classificação da tela e da API da pessoa, e não uma segunda cópia.

  ## O que a resposta afirma

  - **`stale_after_days` viaja junto.** *Parada* não é adjetivo: é um corte em dias, lido da
    regra `profile.thresholds` (versão no envelope), e sem ele o número não diz nada;
  - **`conversation` separa quatro casos**: `not_collected` (o repositório não teve comentário
    coletado, que é **lacuna da coleta**), `silence` (foi coletado, e ninguém falou), `recent` e
    `old`. Sem os dois primeiros separados, lacuna da coleta leria como silêncio da equipe, e
    alguém cobraria uma pessoa por uma conversa que a plataforma nunca olhou;
  - **uma tarefa compartilhada aparece uma vez**, e não uma por pessoa.
  """

  alias TheBand.Ingestion
  alias TheBand.MCP.Envelope
  alias TheBand.Profiles
  alias TheBand.Profiles.Material
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.TeamWork

  @doc "A resposta, com o envelope. A equipe chega carregada e já autorizada pelo registro."
  @spec responder(Tenant.t(), map()) :: map()
  def responder(%Tenant{} = tenant, equipe) do
    agora = DateTime.utc_now(:second)

    abertas =
      tenant
      |> TeamWork.open_tasks_by_person(equipe.id, agora)
      |> Enum.flat_map(fn {_pessoa, tarefas} -> tarefas end)
      |> Enum.uniq_by(& &1.issue_id)

    paradas = abertas |> Enum.filter(& &1.parada?) |> Enum.sort_by(& &1.aberta_ha_dias, :desc)
    conversas = Profiles.conversa_das_issues(tenant, Enum.map(paradas, & &1.issue_id))

    [
      value: %{
        stale: length(paradas),
        open: length(abertas),
        stale_after_days: Material.stale_days(),
        items: Enum.map(paradas, &item(&1, conversas[&1.issue_id]))
      },
      composition: %{is_composed: false, note: "Open work of the team's current members."},
      window: nil,
      origin: "derived",
      regra: "profile.thresholds",
      ressalvas: {:medida, "flow.wip.count"},
      collected_at: Ingestion.ultima_coleta_concluida(tenant)
    ]
    |> Envelope.montar()
    |> Map.put(:state, "checked")
  end

  defp item(t, conversa) do
    %{
      issue_id: t.issue_id,
      title: t.titulo,
      open_for_days: t.aberta_ha_dias,
      conversation: conversa_em_ingles(conversa.conversa),
      acts: conversa.atos
    }
  end

  # Casadas uma a uma: átomo novo no domínio reprova aqui, em vez de sair cru.
  defp conversa_em_ingles(:nao_coletada), do: "not_collected"
  defp conversa_em_ingles(:silencio), do: "silence"
  defp conversa_em_ingles(:recente), do: "recent"
  defp conversa_em_ingles(:antiga), do: "old"
end
