defmodule TheBand.Profiles.Run do
  @moduledoc """
  Uma execução da geração de perfis num tenant — feature 027.

  `finished_at` nulo significa **em execução**, e é o que a `FR-003` consulta para recusar a
  segunda rodada. Não existe estado `cancelada`: nenhuma linha do código a produziria, e um
  estado que não acontece é um estado que quem lê precisa considerar à toa.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @triggers ~w(cron manual)
  @outcomes ~w(completed ended_early)

  schema "profile_runs" do
    field :tenant_id, :binary_id
    field :trigger, :string
    field :requested_by_user_id, :binary_id

    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :outcome, :string
    field :ended_reason, :string

    field :credential_last_four, :string

    timestamps(type: :utc_datetime)
  end

  @spec triggers() :: [String.t()]
  def triggers, do: @triggers

  @doc "O changeset de abertura da rodada."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :tenant_id,
      :trigger,
      :requested_by_user_id,
      :started_at,
      :finished_at,
      :outcome,
      :ended_reason,
      :credential_last_four
    ])
    |> validate_required([:tenant_id, :trigger, :started_at, :credential_last_four])
    |> validate_inclusion(:trigger, @triggers)
    |> validate_inclusion(:outcome, @outcomes)
    |> exigir_quem_pediu()
    |> unique_constraint(:tenant_id, name: :profile_runs_uma_aberta_por_tenant)
    |> check_constraint(:trigger, name: :profile_run_trigger_valido)
    |> check_constraint(:outcome, name: :profile_run_outcome_valido)
  end

  # Rodada pedida a mão tem quem a pediu; rodada automática não tem, porque ninguém a pediu.
  # Nulo aqui é ausência **real** — e aceitar `manual` sem autor apagaria a única diferença
  # entre um ato de alguém e um efeito do relógio.
  defp exigir_quem_pediu(changeset) do
    case get_field(changeset, :trigger) do
      "manual" -> validate_required(changeset, [:requested_by_user_id])
      _ -> changeset
    end
  end

  @doc "Se a rodada ainda está executando."
  @spec aberta?(t()) :: boolean()
  def aberta?(%__MODULE__{finished_at: nil}), do: true
  def aberta?(%__MODULE__{}), do: false
end
