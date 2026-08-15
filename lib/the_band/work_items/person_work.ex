defmodule TheBand.WorkItems.PersonWork do
  @moduledoc """
  O trabalho de uma pessoa — o que está com ela, o que ela concluiu, e **o quanto disso a
  plataforma observou**.

  ## A cobertura não é rodapé, é o requisito

  Medido em 2026-08-15: 53 repositórios têm issues coletadas e **5** têm timeline. As 152
  issues abertas de uma pessoa podiam estar todas em repositório sem timeline — e uma tela
  que mostrasse `0 atividades` ali estaria dizendo que ela não trabalhou, quando a mesma
  pessoa concluiu 199 issues no histórico.

  Por isso `timeline_coverage/2` existe e vem antes de qualquer número derivado: sem ela,
  todo zero da tela é ambíguo, e a ambiguidade recai sobre uma pessoa.

  ## Estas medidas não dependem da timeline

  `closed_by_month/2` e `open_age_buckets/2` saem das datas da própria issue —
  `external_closed_at` e `external_created_at` —, que têm cobertura completa. É o que torna
  o painel útil mesmo onde a timeline não chegou.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity, as: Activity
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  # Ordem fixa, e as vazias vêm junto: faixa ausente faria o eixo mudar por pessoa, e
  # comparar duas pessoas viraria ilusão.
  @faixas ["até 7d", "7–30d", "30–90d", "90–180d", "mais de 180d"]

  @doc """
  Quantas issues estão designadas à pessoa e **ainda abertas**.

  Designação encerrada não conta: a pergunta é "o que está com ela agora".
  """
  @spec assigned_open_count(Tenant.t(), Ecto.UUID.t()) :: non_neg_integer()
  def assigned_open_count(%Tenant{id: tenant_id}, person_id) do
    Repo.aggregate(abertas(tenant_id, person_id), :count)
  end

  @doc """
  Quantas das issues abertas da pessoa estão em repositório **cuja timeline foi coletada**.

  A pergunta é por repositório, e não por issue: a timeline vem junto da issue, então um
  repositório percorrido depois da feature 022 tem timeline de todas as dele.

  Devolve `{observadas, total}` — e quem chama precisa dos dois: `0 de 152` e `0 de 0`
  dizem coisas diferentes.
  """
  @spec timeline_coverage(Tenant.t(), Ecto.UUID.t()) :: {non_neg_integer(), non_neg_integer()}
  def timeline_coverage(%Tenant{id: tenant_id} = tenant, person_id) do
    com_timeline =
      from i in CollectedIssue,
        join: a in Activity,
        on: a.subject_id == i.id,
        where: i.tenant_id == ^tenant_id,
        select: i.observed_repository_id,
        distinct: true

    # **Uma consulta, dois números.** Contar as observadas e depois o total seriam duas idas
    # ao banco para responder uma pergunta só, e o teste-guarda de custo da página da pessoa
    # conta consultas por render.
    _ = tenant

    %{observadas: observadas, total: total} =
      from(i in abertas(tenant_id, person_id),
        select: %{
          observadas: filter(count(i.id), i.observed_repository_id in subquery(com_timeline)),
          total: count(i.id)
        }
      )
      |> Repo.one()

    {observadas, total}
  end

  @doc """
  Issues concluídas por mês, em ordem cronológica.

  **Meses sem fechamento aparecem com zero**, e não são omitidos: pular um mês comprimiria
  o tempo e faria a série mentir sobre o ritmo.

  Sai de `external_closed_at`, e por isso **não depende da timeline**.
  """
  @spec closed_by_month(Tenant.t(), Ecto.UUID.t()) :: [%{month: String.t(), count: integer()}]
  def closed_by_month(%Tenant{id: tenant_id}, person_id) do
    from(i in CollectedIssue,
      join: a in IssueAssignee,
      on: a.collected_issue_id == i.id,
      where:
        i.tenant_id == ^tenant_id and a.person_id == ^person_id and
          not is_nil(i.external_closed_at),
      group_by: fragment("to_char(?, 'YYYY-MM')", i.external_closed_at),
      order_by: fragment("to_char(?, 'YYYY-MM')", i.external_closed_at),
      select: %{
        month: fragment("to_char(?, 'YYYY-MM')", i.external_closed_at),
        count: count(i.id)
      }
    )
    |> Repo.all()
    |> preencher_meses_vazios()
  end

  @doc """
  Quantas issues abertas estão em cada faixa de idade, desde a criação.

  As faixas vêm em ordem **fixa**, e as vazias vêm junto: uma faixa ausente da lista faria a
  tela desenhar um eixo diferente por pessoa, e comparar duas pessoas viraria ilusão.

  É a única medida prospectiva do painel — as outras contam o passado, esta mostra o que
  está parado agora.
  """
  @spec open_age_buckets(Tenant.t(), Ecto.UUID.t()) :: [%{label: String.t(), count: integer()}]
  def open_age_buckets(%Tenant{id: tenant_id}, person_id) do
    contagem =
      from(i in abertas(tenant_id, person_id),
        group_by: fragment("1"),
        select: {
          fragment(
            """
            case
              when now() - ? < interval '7 days'   then 'até 7d'
              when now() - ? < interval '30 days'  then '7–30d'
              when now() - ? < interval '90 days'  then '30–90d'
              when now() - ? < interval '180 days' then '90–180d'
              else 'mais de 180d'
            end
            """,
            i.external_created_at,
            i.external_created_at,
            i.external_created_at,
            i.external_created_at
          ),
          count(i.id)
        }
      )
      |> Repo.all()
      |> Map.new()

    for faixa <- @faixas, do: %{label: faixa, count: Map.get(contagem, faixa, 0)}
  end

  @doc """
  O tempo entre a criação e o fechamento das issues concluídas.

  **Isto é lead time, e não cycle time.** Inclui o tempo em que ninguém tocou na issue, e
  trocar um pelo outro faria alguém decidir sobre um número que responde outra pergunta.

  Mediana e p85, **nunca média**: uma issue parada por 422 dias move a média e não move a
  mediana. Devolve `nil` quando não há issue concluída — e `nil` não é zero dias.
  """
  @spec lead_time(Tenant.t(), Ecto.UUID.t()) ::
          %{median: integer(), p85: integer(), count: integer()} | nil
  def lead_time(%Tenant{id: tenant_id}, person_id) do
    resultado =
      from(i in CollectedIssue,
        join: a in IssueAssignee,
        on: a.collected_issue_id == i.id,
        where:
          i.tenant_id == ^tenant_id and a.person_id == ^person_id and
            not is_nil(i.external_closed_at),
        select: %{
          median:
            fragment(
              "percentile_disc(0.5) within group (order by extract(day from ? - ?))",
              i.external_closed_at,
              i.external_created_at
            ),
          p85:
            fragment(
              "percentile_disc(0.85) within group (order by extract(day from ? - ?))",
              i.external_closed_at,
              i.external_created_at
            ),
          count: count(i.id)
        }
      )
      |> Repo.one()

    case resultado do
      %{count: 0} -> nil
      nil -> nil
      %{median: m, p85: p, count: c} -> %{median: dias(m), p85: dias(p), count: c}
    end
  end

  # `percentile_disc` devolve `Decimal`, como `sum/1` — e um `Decimal` chegando na tela
  # compararia struct com número sem ninguém perceber. Já mordeu neste repositório.
  defp dias(nil), do: 0
  defp dias(%Decimal{} = d), do: Decimal.to_integer(Decimal.round(d, 0))
  defp dias(n) when is_number(n), do: trunc(n)

  @doc """
  As issues designadas à pessoa, com os designados vigentes de cada uma.

  Os designados vêm junto porque a avaliação de antipadrão precisa deles, e buscá-los por
  issue seria a segunda metade do N+1 que `detect_for_person/2` existe para evitar.
  """
  @spec issues_assigned_to(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def issues_assigned_to(%Tenant{id: tenant_id}, person_id) do
    issues =
      Repo.all(
        from i in CollectedIssue,
          join: a in IssueAssignee,
          on: a.collected_issue_id == i.id,
          where:
            i.tenant_id == ^tenant_id and a.person_id == ^person_id and
              is_nil(a.no_longer_observed_at) and is_nil(i.no_longer_observed_at),
          select: %{id: i.id, number: i.number, external_closed_at: i.external_closed_at}
      )

    designados =
      Repo.all(
        from a in IssueAssignee,
          where:
            a.tenant_id == ^tenant_id and is_nil(a.no_longer_observed_at) and
              a.collected_issue_id in ^Enum.map(issues, & &1.id),
          select: {a.collected_issue_id, %{login: a.login, person_id: a.person_id}}
      )
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    Enum.map(issues, &Map.put(&1, :assignees, Map.get(designados, &1.id, [])))
  end

  # ------------------------------------------------------------------------ privadas

  defp abertas(tenant_id, person_id) do
    from i in CollectedIssue,
      join: a in IssueAssignee,
      on: a.collected_issue_id == i.id,
      where:
        i.tenant_id == ^tenant_id and a.person_id == ^person_id and
          is_nil(a.no_longer_observed_at) and is_nil(i.no_longer_observed_at) and
          is_nil(i.external_closed_at)
  end

  # O mês sem fechamento é um zero real, e precisa existir na série. Sem ele, quatro meses
  # parados viram um salto visual de um mês para o outro.
  defp preencher_meses_vazios([]), do: []
  defp preencher_meses_vazios([_unico] = serie), do: serie

  defp preencher_meses_vazios(serie) do
    por_mes = Map.new(serie, &{&1.month, &1.count})
    primeiro = List.first(serie).month
    ultimo = List.last(serie).month

    primeiro
    |> meses_ate(ultimo)
    |> Enum.map(&%{month: &1, count: Map.get(por_mes, &1, 0)})
  end

  defp meses_ate(de, ate) do
    Stream.iterate(de, &proximo_mes/1)
    |> Enum.take_while(&(&1 <= ate))
  end

  defp proximo_mes(<<ano::binary-4, "-", mes::binary-2>>) do
    {a, m} = {String.to_integer(ano), String.to_integer(mes)}
    if m == 12, do: "#{a + 1}-01", else: "#{a}-#{String.pad_leading("#{m + 1}", 2, "0")}"
  end
end
