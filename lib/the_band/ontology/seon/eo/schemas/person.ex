defmodule TheBand.Ontology.SEON.EO.Schemas.Person do
  @moduledoc """
  `eo.person` — agente humano. É o conceito de identidade das pessoas em toda a
  rede: SRO, CIRO e CDRO referenciam pessoas apenas por meio de papéis.

  `eo.team_member` **não** aparece aqui como coluna. É `role`, e papel é
  relacional: materializa pelo relator `eo_team_memberships`, que guarda equipe,
  papel e período. Uma coluna `team_id` aqui impossibilitaria a pessoa em várias
  equipes e apagaria a temporalidade (ADR 0004, D5/D6).

  `account_type` existe porque conta de automação não é pessoa (FR-022). É
  classificação persistida, não filtro de exibição: descartar a conta perderia o
  vínculo com a equipe onde ela aparece.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import TheBand.Provenance.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @account_types ~w(person bot app)

  schema "eo_people" do
    field :tenant_id, :binary_id
    field :internal_id, :string
    field :record_version, :integer, default: 1

    field :name, :string
    field :email, :string
    field :login, :string
    field :account_type, :string, default: "person"

    # Não há `organization_id` aqui, e é decisão, não omissão. A mesma conta aparece
    # em mais de uma organização, e a pessoa é uma linha só porque a identidade é a
    # Application Reference — uma coluna simples alternaria de valor a cada coleta, e
    # a última organização sincronizada apagaria a anterior.
    #
    # EO também não define relação direta pessoa↔organização: o vínculo passaria por
    # papel organizacional, que o GitHub não fornece. O caminho é
    # pessoa → equipe → organização, declarado em `eo.cq02`.

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    # Resultado da última escrita — :created, :updated ou :unchanged.
    # Virtual porque descreve o que aconteceu na chamada, não o registro.
    field :outcome, Ecto.Enum, values: [:created, :updated, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def from_source_changeset(person, attrs) do
    person
    |> cast(attrs, [
      :tenant_id,
      :internal_id,
      :record_version,
      :name,
      :email,
      :login,
      :account_type,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at,
      :last_observed_at,
      :no_longer_observed_at
    ])
    |> validate_required([:tenant_id, :internal_id, :name])
    |> validate_inclusion(:account_type, @account_types)
    |> validate_application_reference()
    |> unique_constraint([:tenant_id, :source_system, :source_instance, :external_id],
      name: :eo_people_application_reference_index
    )
  end

  @doc "Contas de automação não contam como pessoa (FR-022)."
  @spec person?(t()) :: boolean()
  def person?(%__MODULE__{account_type: "person"}), do: true
  def person?(_), do: false
end
