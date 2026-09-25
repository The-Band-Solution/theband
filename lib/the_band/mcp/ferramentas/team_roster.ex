defmodule TheBand.MCP.Ferramentas.TeamRoster do
  @moduledoc """
  `team_roster` — quem pertence a esta equipe, e por qual afirmação (feature 062, T010).

  Responde à `sro.cq15`, *"Quem são os membros de um time?"*, pelo mesmo caminho da rota
  `GET /api/v1/teams/:id/members`: `EO.team_roster_scope/2`, `EO.list_team_roster/3`,
  `EO.team_roster_totals/3` e `EO.team_parts/2`. O custo das duas portas tem de ser o mesmo
  (T028), e uma consulta a mais aqui faria trabalho que a outra provou desnecessário.

  ## O que a resposta afirma

  - **`origin` vive no vínculo, e não na pessoa.** Alguém pode ser observado numa equipe e
    declarado noutra, e as duas afirmações valem ao mesmo tempo. O `origin` do envelope é o do
    roster como um todo, `observed`, como no contrato.
  - **`current`, `left` e `mistakes` nunca se somam.** *Saiu* diz que o vínculo existiu e
    terminou; *equívoco* diz que ele nunca devia ter sido afirmado.
  - **A composição declara o alcance**: numa equipe composta, o roster é a equipe **mais** as
    partes com composição vigente.
  - **`truncated` diz se a lista foi cortada.** Um roster de 200 de 500 é outra lista com o
    mesmo nome.
  """

  alias TheBand.MCP.Envelope
  alias TheBand.MCP.TextoDeTerceiro
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants.Tenant

  @limite 200
  @nota_da_composicao "The roster of a composed team is the team PLUS its parts with a " <>
                        "current composition, the same reach the header counts."

  @doc "A resposta, com o envelope. A equipe chega carregada e já autorizada pelo registro."
  @spec responder(Tenant.t(), map()) :: map()
  def responder(%Tenant{} = tenant, equipe) do
    escopo = EO.team_roster_scope(tenant, equipe.id)
    partes = EO.team_parts(tenant, equipe.id)
    totais = EO.team_roster_totals(tenant, equipe.id, escopo: escopo)
    linhas = EO.list_team_roster(tenant, equipe.id, escopo: escopo, limit: @limite + 1)

    [
      value: %{
        people: linhas |> Enum.take(@limite) |> Enum.map(&pessoa/1),
        totals: %{current: totais.vigentes, left: totais.sairam, mistakes: totais.equivocos},
        truncated: length(linhas) > @limite,
        limit: @limite
      },
      composition: %{
        is_composed: partes != [],
        parts: Enum.map(partes, &TextoDeTerceiro.marcar(&1.name)),
        note: @nota_da_composicao
      },
      window: nil,
      origin: "observed",
      ressalvas: {:mapeamento, "github.team_member.to.eo.person"},
      collected_at: equipe.last_observed_at
    ]
    |> Envelope.montar()
    |> Map.put(:state, "checked")
  end

  defp pessoa(m) do
    %{
      person_id: m.person_id,
      name: TextoDeTerceiro.marcar(m.name),
      login: m.login,
      situation: situacao(m.situacao),
      direct: m.direta?,
      memberships: Enum.map(m.vinculos, &vinculo/1)
    }
  end

  # **Quem declarou não sai**: o campo é um e-mail, que é o dado que esta porta exclui, como a
  # API da 061 exclui.
  defp vinculo(v) do
    %{
      team_id: v.team_id,
      team_name: TextoDeTerceiro.marcar(v.team_name),
      origin: origem(v.origem),
      # O nome do papel é escrito por quem administra a organização, e não pela fonte. Ainda é
      # texto livre, escrito por alguém: vai marcado como o resto (na dúvida, AGENTS.md §14.0).
      role: v.role && %{code: v.role.code, name: TextoDeTerceiro.marcar(v.role.name)},
      current: v.vigente?,
      ended_at: v.fim,
      mistake: v.equivoco
    }
  end

  # Casadas uma a uma, como na API: átomo novo no domínio reprova aqui, em vez de sair cru.
  defp origem(:observado), do: "observed"
  defp origem(:declarado), do: "declared"

  defp situacao(:vigente), do: "current"
  defp situacao(:saiu), do: "left"
  defp situacao(:equivoco), do: "mistake"
end
