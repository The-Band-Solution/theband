defmodule TheBand.NetworkAnalysis.Schemas.Reading do
  @moduledoc """
  A leitura vigente da análise de rede de uma organização observada, numa rede e numa janela —
  feature 076, T009 (`data-model.md` §1).

  **Privado** a `TheBand.NetworkAnalysis` (§7.1): ninguém de fora lê nem grava esta tabela. A
  porta da leitura é `NetworkAnalysis.read/4`, que recorta pelo alcance; esta linha, inteira, é
  a rede sem recorte.

  Guarda ids de pessoa e nunca nome, login, percentil nem papel (R9, R17).

  Depende de: nenhuma ontologia diretamente; `organization_id` é de EO, por FK composta.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "network_analysis_readings" do
    field :tenant_id, :binary_id
    field :organization_id, :binary_id
    field :network, :string
    field :window_days, :integer
    field :window_start, :utc_datetime
    field :window_end, :utc_datetime
    field :computed_at, :utc_datetime
    field :checked_at, :utc_datetime
    field :source_computed_at, :utc_datetime
    field :fingerprint, :string
    field :edges, {:array, :map}
    field :exclusions, :map
    field :people_without_edges, :integer
    field :nodes, {:array, :map}
    field :communities, {:array, :map}
    field :measures, :map
    field :provenance, :map

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @obrigatorios [
    :tenant_id,
    :organization_id,
    :network,
    :window_days,
    :window_start,
    :window_end,
    :computed_at,
    :checked_at,
    :fingerprint,
    :edges,
    :exclusions,
    :nodes,
    :communities,
    :measures,
    :provenance
  ]

  # `people_without_edges` é nulo quando não há aresta nenhuma na janela: a ausência é da janela,
  # e não zero (data-model.md §1.1).
  @opcionais [:source_computed_at, :people_without_edges]

  @doc """
  O changeset de gravação. Só o cálculo grava, e só substituindo (FR-018).

  As constraints do banco são declaradas pelo nome: a recusa volta como erro do changeset, e
  `NetworkAnalysis.Commands` devolve só os nomes dos campos (A18). A rede **não** é conferida
  aqui contra a lista: quem confere é o banco, e o teste prova que ele recusa.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(leitura, attrs) do
    leitura
    |> cast(attrs, @obrigatorios ++ @opcionais)
    |> validate_required(@obrigatorios)
    |> foreign_key_constraint(:organization_id,
      name: :network_analysis_readings_organization_id_fkey
    )
    |> unique_constraint([:tenant_id, :organization_id, :network, :window_days],
      name: :network_analysis_readings_vigente_index
    )
    |> check_constraint(:network, name: :network_analysis_readings_network_allowed)
    |> check_constraint(:window_days, name: :network_analysis_readings_window_days_positive)
    |> check_constraint(:window_end, name: :network_analysis_readings_window_ordered)
    |> check_constraint(:checked_at, name: :network_analysis_readings_checked_after)
    |> check_constraint(:people_without_edges,
      name: :network_analysis_readings_counts_non_negative
    )
  end
end
