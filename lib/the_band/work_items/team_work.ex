defmodule TheBand.WorkItems.TeamWork do
  @moduledoc """
  O trabalho de uma **equipe**, recortado pelo período do vínculo — feature 057.

  ## O trabalho de uma equipe é o das suas pessoas, e só enquanto elas pertenceram

  Não existe vínculo direto entre item e equipe na origem. O que existe é o item
  atribuído a uma pessoa, e a pessoa vinculada a uma equipe com início e fim.

  A condição de pertencimento entra como **junção avaliada contra a data do
  evento** — `external_created_at` na série de abertas, `external_closed_at` na de
  fechadas. Uma lista de ids usaria **um** conjunto de membros para todas as
  semanas, que é exatamente o defeito que a feature 057 existe para corrigir: o
  número de um mês fechado mudaria hoje.

  ## `DISTINCT` na issue, e por que ele é o oposto da regra por pessoa

  Item atribuído a duas pessoas **da mesma equipe** conta **uma vez** para a
  equipe. Para a pessoa, conta uma vez para cada — de propósito.

  As duas contagens respondem perguntas diferentes, e é por isso que somar as
  linhas de subequipe está proibido: o total contaria a mesma pessoa e a mesma
  tarefa mais de uma vez, e ninguém conseguiria reconciliá-lo com a realidade.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  @parada_em_dias 90

  @doc """
  Issues criadas e concluídas por período, das pessoas que pertenciam à equipe
  **na data de cada evento**.

  Período sem movimento dentro da janela vem com zero nas duas; período fora da
  janela não aparece — a diferença entre "observamos e não houve" e "não
  observamos" é o que a tela precisa poder dizer.

  O formato usa o ano **ISO** (`IYYY`), e não o civil: a semana de 29/12 pertence
  ao ano ISO seguinte, e `YYYY` produziria dois rótulos iguais em dezembro.
  """
  @spec state_changes_by_period(Tenant.t(), Ecto.UUID.t(), atom(), keyword()) ::
          [%{periodo: String.t(), criadas: non_neg_integer(), fechadas: non_neg_integer()}]
  def state_changes_by_period(%Tenant{} = tenant, team_id, escala, opts \\ [])
      when escala in [:semana, :mes, :ano] do
    forma = formato(escala)
    desde = Keyword.fetch!(opts, :desde)
    ate = Keyword.fetch!(opts, :ate)

    criadas = por_evento(tenant, team_id, :external_created_at, forma, desde, ate)
    fechadas = por_evento(tenant, team_id, :external_closed_at, forma, desde, ate)

    juntar(criadas, fechadas, escala, desde, ate)
  end

  @doc """
  Quantos itens da equipe estavam **em aberto** naquele instante.

  Criados até a data, não fechados até a data, de quem pertencia **na data**.

  É a **linha de base** do burn. Sem ela o acumulado parte de zero na primeira
  semana da janela, e a distância entre as curvas mede apenas os itens nascidos
  dentro dela: uma equipe com quarenta itens abertos há meses e nenhuma abertura
  recente apareceria com distância zero.
  """
  @spec open_at(Tenant.t(), Ecto.UUID.t(), DateTime.t()) :: non_neg_integer()
  def open_at(%Tenant{id: tenant_id}, team_id, quando) do
    CollectedIssue
    |> join(:inner, [i], a in IssueAssignee, on: a.collected_issue_id == i.id)
    |> join(:inner, [i, a], m in TeamMembership, on: m.person_id == a.person_id)
    |> where([i, _a, m], i.tenant_id == ^tenant_id and m.team_id == type(^team_id, :binary_id))
    |> where([i], not is_nil(i.external_created_at) and i.external_created_at <= ^quando)
    |> where([i], is_nil(i.external_closed_at) or i.external_closed_at > ^quando)
    |> vigente_em(quando)
    |> select([i], count(i.id, :distinct))
    |> Repo.one()
  end

  @doc """
  Todas as tarefas abertas de cada pessoa da equipe, numa consulta.

  **Pessoa sem tarefa aberta aparece no mapa com `[]`**, e não é omitida: a tela
  precisa distinguir "não tem tarefa" de "não é da equipe". Chave ausente
  significa que a pessoa não pertence; lista vazia significa que pertence e não
  tem tarefa.

  `aberta_ha_dias` conta da **abertura do item**. A origem não registra quando a
  atribuição aconteceu — decisão em vigor desde 2026-08-27 —, e derivar essa data
  de qualquer outra coluna seria inventá-la e apresentá-la como observada.
  """
  @spec open_tasks_by_person(Tenant.t(), Ecto.UUID.t(), DateTime.t()) ::
          %{Ecto.UUID.t() => [map()]}
  def open_tasks_by_person(%Tenant{id: tenant_id} = tenant, team_id, quando) do
    ids = EO.team_member_ids_at(tenant, team_id, quando)
    vazio = Map.new(ids, &{&1, []})

    if ids == [] do
      vazio
    else
      CollectedIssue
      |> join(:inner, [i], a in IssueAssignee, on: a.collected_issue_id == i.id)
      |> where([i, a], i.tenant_id == ^tenant_id and a.person_id in ^ids)
      |> where([i], is_nil(i.external_closed_at) and not is_nil(i.external_created_at))
      |> order_by([i], asc: i.external_created_at)
      |> select([i, a], %{
        person_id: a.person_id,
        issue_id: i.id,
        external_id: i.external_id,
        titulo: i.title,
        aberta_desde: i.external_created_at
      })
      |> Repo.all()
      |> Enum.map(&tarefa(&1, quando))
      |> Enum.group_by(& &1.person_id, &Map.delete(&1, :person_id))
      |> then(&Map.merge(vazio, &1))
    end
  end

  @doc """
  A linha de indicadores de **uma** equipe — a unidade da tela composta.

  `sem_trabalho?` existe para separar **zero observado** de **ausência**: a tela
  usa o booleano, e não infere ausência de um zero. Preencher com zero o que não
  se sabe transforma lacuna em decisão.

  **Não devolve total.** Não há campo onde ele caberia, e isso é deliberado — é o
  que impede que a recusa a somar seja desfeita por engano numa mudança futura.
  """
  @spec snapshot(Tenant.t(), Ecto.UUID.t(), DateTime.t(), keyword()) :: map()
  def snapshot(%Tenant{} = tenant, team_id, quando, opts \\ []) do
    desde = Keyword.get_lazy(opts, :desde, fn -> DateTime.add(quando, -56, :day) end)
    membros = EO.team_member_ids_at(tenant, team_id, quando)
    tarefas = open_tasks_by_person(tenant, team_id, quando) |> Map.values() |> List.flatten()
    fechadas = fechadas_entre(tenant, team_id, desde, quando)
    abertas = length(Enum.uniq_by(tarefas, & &1.issue_id))

    %{
      team_id: team_id,
      membros: length(membros),
      abertas: abertas,
      fechadas_na_janela: fechadas,
      paradas: Enum.count(tarefas, & &1.parada?),
      sem_trabalho?: abertas == 0 and fechadas == 0
    }
  end

  # ------------------------------------------------------------------ privados

  defp tarefa(linha, quando) do
    dias = DateTime.diff(quando, linha.aberta_desde, :day)

    linha
    |> Map.drop([:aberta_desde])
    |> Map.merge(%{aberta_ha_dias: max(dias, 0), parada?: dias > @parada_em_dias})
  end

  defp fechadas_entre(%Tenant{id: tenant_id}, team_id, desde, ate) do
    CollectedIssue
    |> join(:inner, [i], a in IssueAssignee, on: a.collected_issue_id == i.id)
    |> join(:inner, [i, a], m in TeamMembership, on: m.person_id == a.person_id)
    |> where([i, _a, m], i.tenant_id == ^tenant_id and m.team_id == type(^team_id, :binary_id))
    |> where([i], i.external_closed_at >= ^desde and i.external_closed_at <= ^ate)
    |> where(
      [i, _a, m],
      is_nil(m.invalidated_at) and
        (is_nil(m.started_at) or m.started_at <= i.external_closed_at) and
        (is_nil(m.ended_at) or m.ended_at > i.external_closed_at)
    )
    |> select([i], count(i.id, :distinct))
    |> Repo.one()
  end

  # A vigência do vínculo avaliada contra a DATA DO EVENTO da issue, e não contra
  # hoje. É o que faz o SC-002 valer também aqui: registrar uma saída amanhã não
  # muda nenhuma linha cuja data de evento seja anterior à saída.
  #
  # `started_at` nulo é membro — nulo é desconhecido, nunca "nunca pertenceu".
  defp por_evento(%Tenant{id: tenant_id}, team_id, campo, forma, desde, ate) do
    CollectedIssue
    |> join(:inner, [i], a in IssueAssignee, on: a.collected_issue_id == i.id)
    |> join(:inner, [i, a], m in TeamMembership, on: m.person_id == a.person_id)
    |> where([i, _a, m], i.tenant_id == ^tenant_id and m.team_id == type(^team_id, :binary_id))
    |> where([i], not is_nil(field(i, ^campo)))
    |> where([i], field(i, ^campo) >= ^desde and field(i, ^campo) <= ^ate)
    |> where(
      [i, _a, m],
      is_nil(m.invalidated_at) and
        (is_nil(m.started_at) or m.started_at <= field(i, ^campo)) and
        (is_nil(m.ended_at) or m.ended_at > field(i, ^campo))
    )
    # `GROUP BY 1`, e não a expressão repetida: o Postgres compara as duas
    # estruturalmente, e `to_char(col, $1)` no select contra `to_char(col, $6)`
    # no group by não casam — os parâmetros ocupam posições diferentes. Mesma
    # decisão já registrada em `person_work.ex`.
    |> group_by([i], fragment("1"))
    |> select([i], {fragment("to_char(?, ?)", field(i, ^campo), ^forma), count(i.id, :distinct)})
    |> Repo.all()
    |> Map.new()
  end

  # Cada período da janela aparece, inclusive os vazios. Pular um período
  # comprimiria o tempo e faria a série mentir sobre o ritmo.
  defp juntar(criadas, fechadas, escala, desde, ate) do
    desde
    |> periodos_ate(ate, escala)
    |> Enum.map(
      &%{periodo: &1, criadas: Map.get(criadas, &1, 0), fechadas: Map.get(fechadas, &1, 0)}
    )
  end

  defp periodos_ate(desde, ate, escala) do
    passo = if escala == :semana, do: 7, else: 1

    Stream.iterate(DateTime.to_date(desde), &Date.add(&1, passo))
    |> Stream.take_while(&(Date.compare(&1, DateTime.to_date(ate)) != :gt))
    |> Enum.map(&rotulo(&1, escala))
    |> Enum.uniq()
  end

  defp rotulo(data, :semana) do
    {ano, semana} = :calendar.iso_week_number(Date.to_erl(data))
    "#{ano}-W#{String.pad_leading(to_string(semana), 2, "0")}"
  end

  defp rotulo(data, :mes), do: Calendar.strftime(data, "%Y-%m")
  defp rotulo(data, :ano), do: Calendar.strftime(data, "%Y")

  defp vigente_em(query, quando) do
    where(
      query,
      [_i, _a, m],
      is_nil(m.invalidated_at) and
        (is_nil(m.started_at) or m.started_at <= ^quando) and
        (is_nil(m.ended_at) or m.ended_at > ^quando)
    )
  end

  defp formato(:semana), do: ~S(IYYY-"W"IW)
  defp formato(:mes), do: "YYYY-MM"
  defp formato(:ano), do: "YYYY"
end
