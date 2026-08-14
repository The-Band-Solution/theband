defmodule TheBand.Ontology.SEON.SPO.Queries do
  @moduledoc """
  Leituras de SPO. Implementação; a fronteira é `TheBand.Ontology.SEON.SPO`.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity, as: Activity
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  As atividades de uma entidade, em ordem **crescente** de `occurred_at`.

  A ordem não é preferência: é a sequência do que aconteceu, e invertê-la faria a tela
  contar a história de trás para frente.
  """
  @spec list_activities(Tenant.t(), String.t(), Ecto.UUID.t()) :: [Activity.t()]
  def list_activities(%Tenant{id: tenant_id}, subject_type, subject_id) do
    Repo.all(
      from a in Activity,
        where:
          a.tenant_id == ^tenant_id and
            a.subject_type == ^subject_type and
            a.subject_id == ^subject_id,
        order_by: [asc: a.occurred_at, asc: a.id]
    )
  end

  @doc """
  Os tipos de atividade observados, com a frequência de cada um.

  **É o que permite a decisão da FR-007.** Quem vai declarar qual movimentação marca o
  início precisa saber quais tipos existem e com que frequência.

  Inclui os de `concept_id` nulo, e é o ponto: são eles que dizem o que a rede ainda
  não nomeia. Filtrá-los esconderia exatamente a informação que a lista existe para dar.
  """
  @spec count_activity_types(Tenant.t()) :: [
          %{type: String.t(), concept: String.t() | nil, count: pos_integer()}
        ]
  def count_activity_types(%Tenant{id: tenant_id}) do
    Repo.all(
      from a in Activity,
        where: a.tenant_id == ^tenant_id,
        group_by: [a.activity_type, a.concept_id],
        order_by: [desc: count(a.id), asc: a.activity_type],
        select: %{type: a.activity_type, concept: a.concept_id, count: count(a.id)}
    )
  end
end
