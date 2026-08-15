defmodule TheBand.Ontology.SEON.SPO.Schemas.Project do
  @moduledoc """
  Um projeto — `spo.project`.

  ## A fase não é campo

  `spo.simple_project` e `spo.complex_project` são **fases**, e a fase é consequência de
  ter partes: um projeto vira complexo ao ganhar a primeira, e volta a simples ao perder
  a última. Não há coluna de tipo, e o formulário não pergunta — antes das partes a
  pergunta não tem resposta.

  Kind não serviria: kind é rígido e dá identidade, então o projeto que perdesse a
  última parte teria de **deixar de existir** para virar simples, perdendo id e história.

  ## Projeto é declaração

  Não vem da origem. `declared_by_user_id` existe porque decisão tem autor, e nenhum
  caminho da coleta cria projeto.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "spo_projects" do
    field :tenant_id, :binary_id
    field :name, :string
    field :started_on, :date
    field :ended_on, :date
    field :declared_by_user_id, :binary_id
    field :parent_id, :binary_id

    # Derivada, e nunca gravada: sai de ter filhos. Virtual porque a tela precisa dela
    # junto do registro, e recalcular por linha seria consulta por item.
    field :phase, Ecto.Enum, values: [:simple, :complex], virtual: true, default: :simple

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:tenant_id, :name, :started_on, :ended_on, :declared_by_user_id, :parent_id])
    |> validate_required([:tenant_id, :name])
    |> validate_length(:name, min: 1, max: 200)
    # **O erro cai em `:name`**, e não em `:tenant_id`: ninguém digita o tenant, e a
    # mensagem precisa aparecer no campo que a pessoa preencheu.
    |> unique_constraint(:name, name: :spo_projects_name_index)
    |> validate_datas()
  end

  # Fim antes do início não é erro de digitação improvável: é o que acontece quando
  # alguém corrige o início e esquece o fim.
  defp validate_datas(changeset) do
    inicio = get_field(changeset, :started_on)
    fim = get_field(changeset, :ended_on)

    if inicio && fim && Date.compare(fim, inicio) == :lt do
      add_error(changeset, :ended_on, "o fim é anterior ao início")
    else
      changeset
    end
  end
end
