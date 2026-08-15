defmodule TheBand.Ontology.Continuum.SRO.Queries do
  @moduledoc """
  Leituras de SRO. Implementação; a fronteira é `TheBand.Ontology.Continuum.SRO`.
  """

  import Ecto.Query

  alias TheBand.Ontology.Continuum.SRO.Schemas.Sprint
  alias TheBand.Ontology.Continuum.SRO.Schemas.SprintIssue
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems.Schemas.CollectedIssue

  @doc """
  As caixas de tempo observadas, da mais recente para a mais antiga.

  `opts[:board_number]` restringe a um quadro.
  """
  @spec list_sprints(Tenant.t(), keyword()) :: [Sprint.t()]
  def list_sprints(%Tenant{id: tenant_id}, opts \\ []) do
    Sprint
    |> where([s], s.tenant_id == ^tenant_id)
    |> entao(opts[:board_number], &where(&1, [s], s.board_number == ^&2))
    |> order_by([s], desc: s.started_on, asc: s.field_name)
    |> Repo.all()
  end

  @doc """
  As issues **vigentes** numa caixa de tempo.

  O vínculo encerrado não aparece, e a linha dele continua no banco: issue que saiu de
  um sprint continua tendo estado nele.
  """
  @spec list_sprint_issues(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_sprint_issues(%Tenant{id: tenant_id}, sprint_id) do
    Repo.all(
      from v in SprintIssue,
        join: i in CollectedIssue,
        on: i.id == v.collected_issue_id,
        where:
          v.tenant_id == ^tenant_id and v.sprint_id == ^sprint_id and
            is_nil(v.no_longer_observed_at),
        order_by: [asc: i.number],
        select: %{
          id: i.id,
          number: i.number,
          title: i.title,
          state: i.state,
          observed_at: v.observed_at
        }
    )
  end

  @doc """
  Quantas issues do quadro **não** estão em caixa de tempo alguma.

  Devolve `{:error, :board_has_no_iteration_field}` quando o quadro não usa caixas —
  e **isto não é zero**. As duas situações produzem o mesmo `0` na tela e afirmam
  coisas opostas: "o quadro não organiza por tempo" e "o quadro organiza, e tudo ficou
  de fora". É a **L57**, e a FR-010 existe por causa dela.

  Medido em 2026-08-15: 150 dos 677 itens do DevOps estão fora de qualquer sprint.
  """
  @spec count_issues_outside_any_sprint(Tenant.t(), integer()) ::
          {:ok, non_neg_integer()} | {:error, :board_has_no_iteration_field}
  def count_issues_outside_any_sprint(%Tenant{id: tenant_id} = tenant, board_number) do
    if list_sprints(tenant, board_number: board_number) == [] do
      {:error, :board_has_no_iteration_field}
    else
      vinculadas =
        from v in SprintIssue,
          join: s in Sprint,
          on: s.id == v.sprint_id,
          where:
            v.tenant_id == ^tenant_id and s.board_number == ^board_number and
              is_nil(v.no_longer_observed_at),
          select: v.collected_issue_id,
          distinct: true

      {:ok, Repo.aggregate(from(i in subquery(vinculadas)), :count)}
    end
  end

  defp entao(query, nil, _fun), do: query
  defp entao(query, valor, fun), do: fun.(query, valor)
end
