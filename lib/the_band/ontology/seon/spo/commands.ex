defmodule TheBand.Ontology.SEON.SPO.Commands do
  @moduledoc """
  Escritas de SPO. Implementação; a fronteira é `TheBand.Ontology.SEON.SPO`.
  """

  alias TheBand.Ontology.SEON.SPO.Schemas.IntendedProjectProcess
  alias TheBand.Ontology.SEON.SPO.Schemas.PerformedProjectActivity, as: Activity
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  Registra uma ocorrência de atividade executada.

  **Nunca atualiza.** Se o critério de identidade já existe, devolve o registro com
  `outcome: :unchanged` sem tocar na linha — uma ocorrência não muda, ela aconteceu.
  É o que faz reprocessar a mesma origem produzir uma linha (FR-003).
  """
  @spec record_activity(Tenant.t(), map()) ::
          {:ok, Activity.t()} | {:error, Ecto.Changeset.t()}
  def record_activity(%Tenant{id: tenant_id}, attrs) do
    attrs =
      attrs
      |> normalizar()
      |> Map.put(:tenant_id, tenant_id)

    internal_id = Activity.internal_id(attrs)
    attrs = Map.put(attrs, :internal_id, internal_id)

    case Repo.get_by(Activity, tenant_id: tenant_id, internal_id: internal_id) do
      nil -> inserir(attrs)
      existente -> {:ok, %{existente | outcome: :unchanged}}
    end
  end

  # A corrida entre a checagem e o insert é real — duas coletas simultâneas da mesma
  # issue chegariam aqui juntas. O índice único a resolve, e o `:unchanged` no
  # tratamento da violação é a mesma resposta que o caminho sem corrida daria.
  defp inserir(attrs) do
    %Activity{}
    |> Activity.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, activity} -> {:ok, %{activity | outcome: :created}}
      {:error, changeset} -> resolver_colisao(attrs, changeset)
    end
  end

  # A violação do índice único só pode significar que outra escrita gravou a mesma
  # ocorrência entre a checagem e o insert. Devolver o registro dela é a mesma
  # resposta que o caminho sem corrida daria — e engolir qualquer outro erro aqui
  # seria fallback silencioso, então só esta violação é tratada.
  defp resolver_colisao(attrs, %Ecto.Changeset{errors: errors} = changeset) do
    if Keyword.has_key?(errors, :internal_id) do
      Activity
      |> Repo.get_by(tenant_id: attrs[:tenant_id], internal_id: attrs[:internal_id])
      |> case do
        nil -> {:error, changeset}
        existente -> {:ok, %{existente | outcome: :unchanged}}
      end
    else
      {:error, changeset}
    end
  end

  defp normalizar(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  @doc """
  Grava um processo pretendido — `spo.specific_intended_project_process`, FR-030.

  É a iteração futura do quadro: planejamento que não foi feito. Idempotente pela
  Application Reference; reobservar limpa a marca de ausência.
  """
  @spec record_intended_process(Tenant.t(), map()) ::
          {:ok, IntendedProjectProcess.t()} | {:error, Ecto.Changeset.t()}
  def record_intended_process(%Tenant{id: tenant_id}, attrs) do
    base =
      Repo.get_by(IntendedProjectProcess,
        tenant_id: tenant_id,
        source_system: attrs[:source_system],
        source_instance: attrs[:source_instance],
        source_external_id: attrs[:source_external_id]
      ) || %IntendedProjectProcess{}

    agora = DateTime.utc_now(:second)

    base
    |> IntendedProjectProcess.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:collected_at, base.collected_at || attrs[:collected_at] || agora)
      |> Map.put(:last_observed_at, agora)
      |> Map.put(:no_longer_observed_at, nil)
    )
    |> Repo.insert_or_update()
  end
end
