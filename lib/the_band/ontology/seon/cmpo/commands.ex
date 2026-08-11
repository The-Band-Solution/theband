defmodule TheBand.Ontology.SEON.CMPO.Commands do
  @moduledoc """
  Escritas de CMPO. Implementação; a fronteira é `TheBand.Ontology.SEON.CMPO`.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.CMPO.Schemas.LoadedSoftwareSystemCopy, as: Copy
  alias TheBand.Ontology.SEON.CMPO.Schemas.ObservedRepository
  alias TheBand.Ontology.SEON.CMPO.Schemas.SourceRepository
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  Grava ou atualiza o repositório pela Application Reference.

  **Duas tabelas numa transação**: o kind guarda a identidade, a extensão guarda os
  atributos. A referência atravessa a fronteira de ontologia, e o repositório é um
  valor de discriminador na tabela do kind — nunca uma tabela solta em CMPO.
  """
  @spec upsert_source_repository_from_source(Tenant.t(), map()) ::
          {:ok, SourceRepository.t()} | {:error, term()}
  def upsert_source_repository_from_source(%Tenant{id: tenant_id}, attrs) do
    now = DateTime.utc_now(:second)

    Repo.transaction(fn ->
      copy = upsert_copy(tenant_id, attrs, now)

      extension =
        case Repo.get_by(SourceRepository, loaded_software_system_copy_id: copy.id) do
          nil -> %SourceRepository{}
          existing -> existing
        end
        |> SourceRepository.changeset(%{
          tenant_id: tenant_id,
          loaded_software_system_copy_id: copy.id,
          organization_id: attrs[:organization_id],
          name: attrs[:name],
          qualified_name: attrs[:qualified_name],
          url: attrs[:url],
          description: attrs[:description],
          primary_language: attrs[:primary_language],
          default_branch: attrs[:default_branch],
          archived_at: attrs[:archived_at],
          external_created_at: attrs[:external_created_at],
          last_pushed_at: attrs[:last_pushed_at]
        })
        |> Repo.insert_or_update()

      case extension do
        {:ok, repo} -> repo
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp upsert_copy(tenant_id, attrs, now) do
    chave = [
      tenant_id: tenant_id,
      source_system: attrs[:source_system],
      source_instance: attrs[:source_instance],
      external_id: attrs[:external_id]
    ]

    base =
      case Repo.get_by(Copy, chave) do
        nil -> %Copy{}
        existing -> existing
      end

    resultado =
      Copy.changeset(base, %{
        tenant_id: tenant_id,
        internal_id: attrs[:external_id],
        type: "source_repository",
        source_system: attrs[:source_system],
        source_instance: attrs[:source_instance],
        external_id: attrs[:external_id],
        collected_at: base.collected_at || now,
        last_observed_at: now,
        # Reobservar limpa a marca de ausência. A coleta é quem devolve vigência.
        no_longer_observed_at: nil
      })
      |> Repo.insert_or_update()

    case resultado do
      {:ok, copy} -> copy
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  @doc """
  Registra que uma ferramenta observa um repositório.

  Idempotente: a segunda chamada devolve a linha existente sem alterá-la, o que
  preserva `excluded_at` de uma exclusão decidida antes.
  """
  @spec observe_repository(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ObservedRepository.t()} | {:error, Ecto.Changeset.t()}
  def observe_repository(%Tenant{id: tenant_id}, connected_tool_id, source_repository_id) do
    case Repo.get_by(ObservedRepository,
           connected_tool_id: connected_tool_id,
           source_repository_id: source_repository_id
         ) do
      nil ->
        %ObservedRepository{}
        |> ObservedRepository.changeset(%{
          tenant_id: tenant_id,
          connected_tool_id: connected_tool_id,
          source_repository_id: source_repository_id
        })
        |> Repo.insert()

      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Exclui um repositório da observação — decisão do tenant, com autor.

  **Não marca ausência nas issues dele** (FR-005). A plataforma parou de olhar, e isso
  não é o mesmo que o dado ter sumido. Marcar aqui seria a L19 numa forma nova.
  """
  @spec exclude_from_observation(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ObservedRepository.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def exclude_from_observation(%Tenant{id: tenant_id}, observed_repository_id, user_id) do
    with {:ok, observed} <- fetch_observed(tenant_id, observed_repository_id) do
      observed
      |> ObservedRepository.changeset(%{
        excluded_at: DateTime.utc_now(:second),
        excluded_by_user_id: user_id
      })
      |> Repo.update()
    end
  end

  @doc "Desfaz a exclusão. A coleta seguinte volta a consultar o repositório."
  @spec include_in_observation(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, ObservedRepository.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def include_in_observation(%Tenant{id: tenant_id}, observed_repository_id) do
    with {:ok, observed} <- fetch_observed(tenant_id, observed_repository_id) do
      observed
      |> ObservedRepository.changeset(%{excluded_at: nil, excluded_by_user_id: nil})
      |> Repo.update()
    end
  end

  @doc """
  Marca o repositório como inacessível pela credencial.

  **Não marca ausência nas issues dele** (FR-006). Perder alcance não é o dado ter
  sumido, e a ferramenta passa a exigir atenção nomeando o repositório.
  """
  @spec mark_inaccessible(Tenant.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, ObservedRepository.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def mark_inaccessible(%Tenant{id: tenant_id}, observed_repository_id, reason) do
    with {:ok, observed} <- fetch_observed(tenant_id, observed_repository_id) do
      observed
      |> ObservedRepository.changeset(%{
        inaccessible_since: DateTime.utc_now(:second),
        inaccessible_reason: reason
      })
      |> Repo.update()
    end
  end

  defp fetch_observed(tenant_id, id) do
    case Repo.one(from o in ObservedRepository, where: o.tenant_id == ^tenant_id and o.id == ^id) do
      nil -> {:error, :not_found}
      observed -> {:ok, observed}
    end
  end
end
