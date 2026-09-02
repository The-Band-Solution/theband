defmodule TheBand.Ontology.SEON.EO.Schemas.Team do
  @moduledoc """
  `eo.team` — coletivo de pessoas que desempenham papéis organizacionais em
  conjunto.

  `type` é o discriminador dos dois subkinds, `eo.organizational_team` e
  `eo.project_team`, que não ganham tabela por serem `subkind`: rígidos e
  exclusivos, cabem num único valor (ADR 0004).

  FR-023 — o GitHub alimenta sempre `organizational_team`. Time do GitHub é
  agrupamento de permissão de acesso; que seus membros trabalhem juntos num
  projeto é suposição, não dado. A promoção a `project_team` exige vínculo
  efetivo com repositório ou projeto, ou declaração do tenant. Nomes coincidentes
  não bastam.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import TheBand.Provenance.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @types ~w(organizational_team project_team)

  schema "eo_teams" do
    field :tenant_id, :binary_id
    field :internal_id, :string
    field :record_version, :integer, default: 1

    field :type, :string, default: "organizational_team"
    field :name, :string
    field :slug, :string
    field :organization_id, :binary_id

    # A equipe declarada pela tela tem autor; a observada tem nil aqui — ausência real.
    field :declared_by_user_id, :binary_id

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime
    field :external_created_at, :utc_datetime

    # Resultado da última escrita — :created, :updated ou :unchanged.
    # Virtual porque descreve o que aconteceu na chamada, não o registro.
    field :outcome, Ecto.Enum, values: [:created, :updated, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def from_source_changeset(team, attrs) do
    team
    |> cast(attrs, [
      :tenant_id,
      :internal_id,
      :record_version,
      :type,
      :name,
      :slug,
      :organization_id,
      :declared_by_user_id,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at,
      :last_observed_at,
      :no_longer_observed_at,
      :external_created_at
    ])
    |> validate_required([:tenant_id, :internal_id, :name])
    |> validate_inclusion(:type, @types)
    |> validate_application_reference()
    |> unique_constraint([:tenant_id, :source_system, :source_instance, :external_id],
      name: :eo_teams_application_reference_index
    )
    # Feature 055: duas equipes DECLARADAS com o mesmo nome na mesma organização.
    # Sem esta linha o Ecto levanta em vez de devolver relator — e a tela veria
    # uma exceção onde deveria ver uma recusa com razão.
    |> unique_constraint([:tenant_id, :organization_id, :name],
      name: :eo_nome_unico_da_equipe_declarada_index
    )
    # A restrição vive no banco (T007), e esta declaração é o que transforma a
    # violação em changeset em vez de exceção. Sem ela, gravar equipe organizacional
    # sem organização derruba o processo com `Ecto.ConstraintError` — o
    # comportamento é o mesmo, a mensagem é que deixa de dizer o que fazer.
    |> check_constraint(:organization_id,
      name: :eo_teams_organizational_team_has_organization,
      message: "equipe organizacional precisa da organização a que pertence"
    )
  end
end
