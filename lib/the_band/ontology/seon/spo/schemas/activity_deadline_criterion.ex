defmodule TheBand.Ontology.SEON.SPO.Schemas.ActivityDeadlineCriterion do
  @moduledoc """
  De onde vem o prazo de uma atividade — issue #368.

  Não é conceito da SPO: é a **declaração** que decide quais datas a plataforma lê como
  prazo naquele alvo. O mesmo papel que `spo.activity_start_criterion` cumpre para o
  instante de início.

  ## Três origens, e elas não se excluem

  `board_field` nomeia um campo de data do quadro. `sprint` toma o fim da caixa de tempo em
  que a tarefa está. `milestone` toma o `dueOn` do marco. Uma tarefa dentro de um sprint e
  ligada a um marco tem **os dois prazos**, e a leitura devolve os dois.

  ## Revoga, e nunca apaga

  A pergunta *"desde quando o prazo vinha do marco"* só tem resposta se o encerramento
  preservar o começo.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @origens ~w(board_field sprint milestone)

  @type t :: %__MODULE__{}

  schema "spo_activity_deadline_criteria" do
    field :tenant_id, :binary_id

    # Exatamente um dos dois — a `CHECK` garante, e `validate_alvo_unico/1` traz o erro ao
    # formulário em vez de deixá-lo virar `Ecto.ConstraintError`.
    field :project_id, :binary_id
    field :observed_project_id, :binary_id

    field :source, :string
    field :field_name, :string

    field :declared_by_user_id, :binary_id
    field :declared_at, :utc_datetime
    field :revoked_by_user_id, :binary_id
    field :revoked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc "As origens que a tela oferece. Uma lista só — a tela lê daqui."
  @spec origens() :: [String.t()]
  def origens, do: @origens

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(criterio, attrs) do
    criterio
    |> cast(attrs, [
      :tenant_id,
      :project_id,
      :observed_project_id,
      :source,
      :field_name,
      :declared_by_user_id,
      :declared_at,
      :revoked_by_user_id,
      :revoked_at
    ])
    |> validate_required([:tenant_id, :source, :declared_at])
    |> validate_inclusion(:source, @origens)
    |> validate_alvo_unico()
    |> validate_campo_coerente()
    |> unique_constraint(:source, name: :spo_prazo_vigente_do_quadro_index)
    |> unique_constraint(:source, name: :spo_prazo_vigente_do_projeto_index)
  end

  # Sem alvo, o critério valeria para tudo sem ninguém ter dito isso; com os dois, não
  # haveria como saber qual prevalece.
  defp validate_alvo_unico(changeset) do
    projeto = get_field(changeset, :project_id)
    quadro = get_field(changeset, :observed_project_id)

    case {projeto, quadro} do
      {nil, nil} -> add_error(changeset, :observed_project_id, "declare o projeto ou o quadro")
      {p, q} when not is_nil(p) and not is_nil(q) -> add_error(changeset, :project_id, "só um")
      _ -> changeset
    end
  end

  # `sprint` e `milestone` não têm campo a nomear. Aceitar um `field_name` ali guardaria
  # dado que nenhuma leitura consulta, e que divergiria do declarado sem ninguém ver.
  defp validate_campo_coerente(changeset) do
    origem = get_field(changeset, :source)
    campo = get_field(changeset, :field_name)

    case {origem, campo} do
      {"board_field", nil} -> add_error(changeset, :field_name, "nomeie o campo do quadro")
      {"board_field", _} -> changeset
      {_, nil} -> changeset
      {_, _} -> add_error(changeset, :field_name, "esta origem não tem campo")
    end
  end
end
