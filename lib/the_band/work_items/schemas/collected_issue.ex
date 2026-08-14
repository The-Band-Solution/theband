defmodule TheBand.WorkItems.Schemas.CollectedIssue do
  @moduledoc """
  A issue como a origem a devolveu — camada de plataforma.

  `issue_type` fica **cru**. Normalizar destruiria o dado que a lacuna precisa mostrar:
  a tela exibe o nome do tipo encontrado, e "tipo desconhecido" sem o nome não diz onde
  a regra precisa mudar.

  `number` é para exibir e localizar, **nunca para identificar**: mover a issue entre
  repositórios cria outro número no destino.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "collected_issues" do
    field :tenant_id, :binary_id
    field :observed_repository_id, :binary_id

    field :number, :integer
    field :title, :string
    field :state, :string

    # O corpo fica **cru**, pelo mesmo motivo de `issue_type`: é a evidência que a
    # promoção por padrão de título usa, e normalizar destruiria o que sustenta a
    # decisão. A renderização segura é responsabilidade da tela.
    field :body, :string
    # `COMPLETED` e `NOT_PLANNED` são fechamentos diferentes. Traduzir na gravação
    # perderia a distinção que só a origem tem.
    field :state_reason, :string

    field :author_login, :string
    field :author_person_id, :binary_id
    field :milestone_title, :string
    field :project_titles, {:array, :string}, default: []
    field :comment_count, :integer, default: 0
    field :reaction_count, :integer, default: 0

    field :issue_type, :string
    field :issue_type_external_id, :string

    field :external_parent_id, :string
    field :sub_issue_count, :integer, default: 0

    field :source_system, :string
    field :source_instance, :string
    field :external_id, :string
    field :external_created_at, :utc_datetime
    field :external_updated_at, :utc_datetime
    field :external_closed_at, :utc_datetime
    field :collected_at, :utc_datetime
    field :last_observed_at, :utc_datetime
    field :no_longer_observed_at, :utc_datetime

    # O que a escrita **fez** — criou, atualizou, ou não mexeu.
    #
    # Virtual, e no mesmo formato que `EO.Schemas.Person` já usa: quem grava sabe o que
    # aconteceu, e sem este campo a informação morria na linha seguinte. Era o que fazia
    # `records_created` e `records_updated` ficarem zerados nas 38 execuções do banco.
    field :outcome, Ecto.Enum, values: [:created, :updated, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  # `cast/4` descarta string vazia por padrão — `empty_values` é `[""]`. Para quase todo
  # campo isso é o certo: `""` e ausente significam a mesma coisa.
  #
  # **Para `body`, não.** A origem devolve `""` quando a issue não tem descrição, e `nil`
  # só existe onde a plataforma nunca pediu o corpo. Deixar o `cast` padrão apagar o `""`
  # colapsa os dois casos, e a tela passa a dizer "corpo não coletado" sobre 480 issues
  # que foram coletadas e estão genuinamente vazias.
  #
  # Foi medido contra a origem: `bodyText` da issue `#1` de `Integrador SIGFAPES` devolve
  # `""` com comprimento zero, e o banco tinha `NULL`. É a L13 de novo — a suíte estava
  # verde, e o número só apareceu ao conferir com a API.
  @campos_com_vazio_significativo [:body]

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(issue, attrs) do
    issue
    |> cast(attrs, @campos_com_vazio_significativo, empty_values: [])
    |> cast(attrs, [
      :tenant_id,
      :observed_repository_id,
      :number,
      :title,
      :state,
      :state_reason,
      :author_login,
      :author_person_id,
      :milestone_title,
      :project_titles,
      :comment_count,
      :reaction_count,
      :issue_type,
      :issue_type_external_id,
      :external_parent_id,
      :sub_issue_count,
      :source_system,
      :source_instance,
      :external_id,
      :external_created_at,
      :external_updated_at,
      :external_closed_at,
      :collected_at,
      :last_observed_at,
      :no_longer_observed_at
    ])
    |> validate_required([
      :tenant_id,
      :observed_repository_id,
      :number,
      :title,
      :state,
      :source_system,
      :source_instance,
      :external_id,
      :collected_at
    ])
    |> unique_constraint([:tenant_id, :source_system, :source_instance, :external_id],
      name: :collected_issues_application_reference_index
    )
  end
end
