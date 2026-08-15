defmodule TheBand.Ontology.Continuum.SRO.Schemas.Sprint do
  @moduledoc """
  Uma caixa de tempo observada num quadro — `sro.sprint`.

  ## Todo campo de iteração é sprint, e o nome fica

  Decisão da pessoa mantenedora em 2026-08-15: `Sprint`, `Iteration` e `Quarter` viram
  todos sprint, qualquer que seja o nome. Escolher pelo nome erraria em quem usou
  `Iteration`; escolher pela duração inventaria um limiar que o dado desautoriza —
  medido, há `Sprint 10` com 3 dias e `Quarter 1` com 61.

  **Mas `field_name` é gravado.** Sem ele, uma contagem por sprint somaria caixas de 14
  e de 90 dias sem que ninguém percebesse.

  ## A identidade vem da origem, e é isso que a protege

  Diferente de `spo.performed_project_activity`, cujo critério é hash composto: a
  iteração **tem identificador próprio** no Projects v2.

  Isso importa porque `title`, `started_on` e `duration_days` são **editáveis**. Alguém
  renomeia `Sprint 38`, corrige a data. Com hash de atributos, cada correção trocaria a
  identidade e a coleta seguinte criaria uma caixa órfã ao lado da antiga.

  ## Aqui `:updated` existe

  Ao contrário de `record_activity/2` da feature 022, onde a ausência do terceiro
  resultado é deliberada: uma ocorrência aconteceu e não muda. Uma caixa de tempo muda —
  ela é renomeada, corrigida, e passa de em curso a concluída.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "sro_sprints" do
    field :tenant_id, :binary_id
    field :internal_id, :string
    field :connected_tool_id, :binary_id

    field :board_number, :integer
    field :board_title, :string

    field :field_name, :string
    field :title, :string

    field :started_on, :date
    field :duration_days, :integer
    field :ended_on, :date
    field :completed, :boolean, default: false

    field :source_system, :string
    field :source_instance, :string
    field :source_external_id, :string

    field :outcome, Ecto.Enum, values: [:created, :updated, :unchanged], virtual: true

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id internal_id connected_tool_id board_number board_title field_name
             title started_on duration_days ended_on completed
             source_system source_instance source_external_id)a

  @obrigatorios ~w(tenant_id internal_id connected_tool_id board_number field_name title
                   started_on duration_days ended_on
                   source_system source_instance source_external_id)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(sprint, attrs) do
    sprint
    |> cast(attrs, @campos)
    |> validate_required(@obrigatorios)
    |> validate_number(:duration_days, greater_than: 0)
    |> unique_constraint(:internal_id, name: :sro_sprints_identity_index)
  end

  @doc """
  A identidade, pela Application Reference declarada em `sro.sprint`.

  Os componentes são exatamente os quatro de `identity_criterion` — e nenhum deles é
  editável na origem, que é o ponto.
  """
  @spec internal_id(map()) :: String.t()
  def internal_id(attrs) do
    [
      attrs[:tenant_id],
      attrs[:source_system],
      attrs[:source_instance],
      attrs[:source_external_id]
    ]
    |> Enum.map_join("|", &to_string/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end

  @doc """
  O fim da caixa, derivado do início mais a duração.

  A origem **não fornece** a data de término: ela dá início e duração, e o resto é
  aritmética. Um dia é subtraído porque a duração inclui o dia de início — um sprint
  de 14 dias que começa numa segunda termina no domingo da semana seguinte, e não na
  segunda.
  """
  @spec ended_on(Date.t(), pos_integer()) :: Date.t()
  def ended_on(started_on, duration_days) when duration_days > 0 do
    Date.add(started_on, duration_days - 1)
  end
end
