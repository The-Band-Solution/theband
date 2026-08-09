defmodule TheBand.Ontology.SEON.EO.Schemas.TeamMembershipEvidence do
  @moduledoc """
  Vínculo observado de pessoa a equipe, **pendente de papel organizacional**.

  Materializa `observed_link` da regra `github.team_membership_evidence`. Não é
  `eo.team_membership`: o relator exige pessoa, equipe **e** papel, e o GitHub
  fornece dois dos três.

  `platform_access_level` guarda `MAINTAINER` ou `MEMBER`, que são níveis de
  administração do time na plataforma. Dizem quem pode gerir membros e
  permissões; não dizem se a pessoa é programadora, testadora, designer ou
  gerente. Promovê-los a `eo.organizational_role` produziria um catálogo de
  papéis que não corresponde a nenhuma função real, e faria CQ12, CQ14 e CQ16
  devolverem resposta falsa em vez de nenhuma.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @access_levels ~w(MAINTAINER MEMBER)

  schema "eo_team_membership_evidence" do
    field :tenant_id, :binary_id
    field :person_id, :binary_id
    field :team_id, :binary_id

    field :person_external_id, :string
    field :team_external_id, :string
    field :platform_access_level, :string

    field :source_system, :string
    field :source_instance, :string
    field :observed_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    field :promoted_membership_id, :binary_id

    # Resultado da última escrita — :created, :updated ou :unchanged.
    # Virtual porque descreve o que aconteceu na chamada, não o registro.
    field :outcome, Ecto.Enum, values: [:created, :updated, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(evidence, attrs) do
    evidence
    |> cast(attrs, [
      :tenant_id,
      :person_id,
      :team_id,
      :person_external_id,
      :team_external_id,
      :platform_access_level,
      :source_system,
      :source_instance,
      :observed_at,
      :last_observed_at,
      :no_longer_observed_at,
      :promoted_membership_id
    ])
    |> validate_required([
      :tenant_id,
      :person_id,
      :team_id,
      :person_external_id,
      :team_external_id,
      :platform_access_level,
      :source_system,
      :source_instance,
      :observed_at,
      :last_observed_at
    ])
    |> validate_inclusion(:platform_access_level, @access_levels,
      message: "é nível de acesso na plataforma; só MAINTAINER ou MEMBER existem na origem"
    )
    |> unique_constraint(
      [:tenant_id, :source_system, :source_instance, :person_external_id, :team_external_id],
      name: :eo_team_membership_evidence_application_reference_index
    )
  end

  @doc "FR-021 — vínculo ainda sem papel organizacional atribuído."
  @spec pending_role?(t()) :: boolean()
  def pending_role?(%__MODULE__{promoted_membership_id: nil}), do: true
  def pending_role?(_), do: false
end
