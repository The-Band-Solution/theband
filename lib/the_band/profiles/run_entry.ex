defmodule TheBand.Profiles.RunEntry do
  @moduledoc """
  O desfecho de **uma pessoa** numa rodada — feature 027.

  É o checkpoint da rodada: a unicidade por `[rodada, pessoa]` é constraint de banco, e é ela
  que faz a retentativa do Oban retomar em vez de gerar um segundo texto sobre o mesmo
  material.

  ## Pular e falhar não são a mesma coisa

  Pular é a plataforma **decidindo** não escrever — sem material, sem trabalho novo, ou
  observação encerrada. Falhar é ela ter tentado e não conseguido. Por isso `failed` é
  `outcome`, e não um quarto motivo: a `FR-014` conta os dois separados.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @outcomes ~w(generated skipped failed)
  @reasons ~w(no_material no_new_work observation_ended)

  schema "profile_run_entries" do
    field :tenant_id, :binary_id
    field :profile_run_id, :binary_id
    field :person_id, :binary_id

    field :outcome, :string
    field :reason, :string
    field :failure_reason, :string

    field :person_profile_id, :binary_id
    field :input_tokens, :integer
    field :output_tokens, :integer

    timestamps(type: :utc_datetime)
  end

  @doc "Os três motivos de pulo. Lista fechada — não existe `other`."
  @spec reasons() :: [String.t()]
  def reasons, do: @reasons

  @spec outcomes() :: [String.t()]
  def outcomes, do: @outcomes

  @doc """
  O changeset do desfecho.

  As combinações inválidas — `skipped` sem motivo, `generated` com motivo, `failed` sem texto
  — são recusadas aqui **e** no banco. Changeset sozinho não é integridade; constraint
  sozinha devolve exceção onde deveria haver `{:error, changeset}`.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [
      :tenant_id,
      :profile_run_id,
      :person_id,
      :outcome,
      :reason,
      :failure_reason,
      :person_profile_id,
      :input_tokens,
      :output_tokens
    ])
    |> validate_required([:tenant_id, :profile_run_id, :person_id, :outcome])
    |> validate_inclusion(:outcome, @outcomes)
    |> validar_combinacao()
    |> unique_constraint([:profile_run_id, :person_id])
    |> check_constraint(:outcome, name: :profile_run_entry_outcome_valido)
    |> check_constraint(:reason, name: :profile_run_entry_reason_valido)
    |> check_constraint(:failure_reason, name: :profile_run_entry_falha_tem_motivo)
  end

  defp validar_combinacao(changeset) do
    case get_field(changeset, :outcome) do
      "skipped" ->
        changeset
        |> validate_required([:reason])
        |> validate_inclusion(:reason, @reasons)
        |> exigir_ausencia(:failure_reason)

      "failed" ->
        changeset
        |> validate_required([:failure_reason])
        |> exigir_ausencia(:reason)

      "generated" ->
        changeset
        |> exigir_ausencia(:reason)
        |> exigir_ausencia(:failure_reason)

      _ ->
        changeset
    end
  end

  defp exigir_ausencia(changeset, campo) do
    case get_field(changeset, campo) do
      nil -> changeset
      _ -> add_error(changeset, campo, "não se aplica a este desfecho")
    end
  end
end
