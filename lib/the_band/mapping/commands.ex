defmodule TheBand.Mapping.Commands do
  @moduledoc "Escritas de Mapping. A fronteira é `TheBand.Mapping`."

  import Ecto.Query

  alias TheBand.Mapping.PatternValidator
  alias TheBand.Mapping.Queries
  alias TheBand.Mapping.Schemas.MappingRule
  alias TheBand.Mapping.Schemas.UnmappedPatternDecision
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @typedoc "Por que a gravação foi recusada antes de tocar o banco."
  @type recusa ::
          {:invalid_pattern, PatternValidator.motivo()}
          | {:unknown_concept, String.t()}

  @doc """
  Grava a regra **depois** de validar o padrão e o conceito.

  `actor` é parâmetro da assinatura, e **não existe versão sem ele**: mapeamento é
  decisão, e uma regra sem autor não tem a quem perguntar por que aquele texto designa
  aquele conceito.

  Duas recusas antes de qualquer escrita:

    * `{:invalid_pattern, motivo}` — não compila, casa vazio, ou lenta demais;
    * `{:unknown_concept, id}` — o conceito não existe na base de conhecimento. Uma regra
      apontando para conceito inexistente promoveria issues para lugar nenhum, e o erro só
      apareceria na próxima coleta.

  A posição é a próxima livre da organização, e o índice único a garante determinística.
  """
  @spec create_rule(Tenant.t(), Ecto.UUID.t(), map(), Ecto.UUID.t()) ::
          {:ok, MappingRule.t()} | {:error, Ecto.Changeset.t() | recusa()}
  def create_rule(%Tenant{id: tenant_id} = tenant, organization_id, attrs, actor_id) do
    attrs = normalizar(attrs)

    with :ok <- validar(tenant, organization_id, attrs) do
      %MappingRule{}
      |> MappingRule.changeset(
        attrs
        |> Map.put(:tenant_id, tenant_id)
        |> Map.put(:organization_id, organization_id)
        |> Map.put(:created_by_id, actor_id)
        |> Map.put_new_lazy(:position, fn -> proxima_posicao(tenant_id, organization_id) end)
      )
      |> Repo.insert()
    end
  end

  @doc """
  Altera a regra, **criando versão**. Revalida o padrão: alterar sem revalidar deixaria
  entrar por edição o que a criação recusa.

  Regra vinda do catálogo passa a ter versão da organização — e o catálogo em YAML
  permanece como está para as outras organizações (FR-042).
  """
  @spec update_rule(Tenant.t(), Ecto.UUID.t(), map(), Ecto.UUID.t()) ::
          {:ok, MappingRule.t()} | {:error, :not_found | Ecto.Changeset.t() | recusa()}
  def update_rule(%Tenant{} = tenant, rule_id, attrs, _actor_id) do
    with {:ok, regra} <- Queries.fetch_rule(tenant, rule_id) do
      attrs = normalizar(Map.merge(atuais(regra), attrs))

      with :ok <- validar(tenant, regra.organization_id, attrs) do
        regra
        |> MappingRule.changeset(Map.put(attrs, :version, regra.version + 1))
        |> Repo.update()
      end
    end
  end

  @doc """
  Desativa a regra — **nunca apaga**.

  As promoções que ela produziu apontam para ela; apagá-la tornaria a proveniência
  ilegível. Não existe `delete_rule/2`, e a ausência é deliberada.
  """
  @spec deactivate_rule(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, MappingRule.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def deactivate_rule(%Tenant{} = tenant, rule_id, actor_id) do
    with {:ok, regra} <- Queries.fetch_rule(tenant, rule_id) do
      regra
      |> MappingRule.changeset(%{
        active: false,
        deactivated_at: DateTime.utc_now(:second),
        deactivated_by_id: actor_id
      })
      |> Repo.update()
    end
  end

  @doc "Reativa uma regra desativada, limpando quem e quando a desativou."
  @spec reactivate_rule(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, MappingRule.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def reactivate_rule(%Tenant{} = tenant, rule_id) do
    with {:ok, regra} <- Queries.fetch_rule(tenant, rule_id) do
      regra
      |> MappingRule.changeset(%{active: true, deactivated_at: nil, deactivated_by_id: nil})
      |> Repo.update()
    end
  end

  @doc """
  Registra que o padrão **não** designa tipo.

  Transforma pendência em ausência declarada: `[Devops]` com 340 issues sai da lista de
  pendências sem que nenhuma issue seja promovida.

  Idempotente: declarar duas vezes o mesmo padrão atualiza o registro em vez de falhar —
  e reverter e declarar de novo limpa a reversão.
  """
  @spec declare_not_a_type(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t(), String.t() | nil) ::
          {:ok, UnmappedPatternDecision.t()} | {:error, Ecto.Changeset.t()}
  def declare_not_a_type(
        %Tenant{id: tenant_id},
        organization_id,
        pattern,
        actor_id,
        note \\ nil
      ) do
    base =
      Repo.get_by(UnmappedPatternDecision,
        organization_id: organization_id,
        pattern: pattern
      ) || %UnmappedPatternDecision{}

    base
    |> UnmappedPatternDecision.changeset(%{
      tenant_id: tenant_id,
      organization_id: organization_id,
      pattern: pattern,
      decided_by_id: actor_id,
      decided_at: DateTime.utc_now(:second),
      reverted_at: nil,
      reverted_by_id: nil,
      note: note
    })
    |> Repo.insert_or_update()
  end

  @doc """
  Devolve o padrão à lista de pendências.

  A reversão é **fato novo**, não apagamento: quem decidiu o quê permanece registrado.
  """
  @spec revert_not_a_type(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, UnmappedPatternDecision.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def revert_not_a_type(%Tenant{id: tenant_id}, decision_id, actor_id) do
    case Repo.get_by(UnmappedPatternDecision, id: decision_id, tenant_id: tenant_id) do
      nil ->
        {:error, :not_found}

      decisao ->
        decisao
        |> UnmappedPatternDecision.changeset(%{
          reverted_at: DateTime.utc_now(:second),
          reverted_by_id: actor_id
        })
        |> Repo.update()
    end
  end

  # ------------------------------------------------------------------- privados

  defp validar(tenant, organization_id, attrs) do
    with :ok <- validar_conceito(attrs[:target_concept]) do
      validar_padrao(tenant, organization_id, attrs)
    end
  end

  defp validar_conceito(conceito) do
    if KnowledgeBase.concept?(conceito),
      do: :ok,
      else: {:error, {:unknown_concept, conceito}}
  end

  # A amostra são títulos reais da organização: uma expressão rápida em `"abc"` pode ser
  # lenta no título de 200 caracteres que o time escreve.
  defp validar_padrao(tenant, organization_id, attrs) do
    amostra = Queries.title_sample(tenant, organization_id)

    case PatternValidator.validate(attrs[:how], attrs[:pattern], amostra) do
      :ok -> :ok
      {:error, motivo} -> {:error, {:invalid_pattern, motivo}}
    end
  end

  defp normalizar(attrs) do
    Map.new(attrs, fn {k, v} -> {if(is_binary(k), do: String.to_existing_atom(k), else: k), v} end)
  end

  defp atuais(regra) do
    Map.take(regra, [:where, :how, :pattern, :case_sensitive, :target_concept, :position, :active])
  end

  defp proxima_posicao(tenant_id, organization_id) do
    ultima =
      Repo.one(
        from r in MappingRule,
          where: r.tenant_id == ^tenant_id and r.organization_id == ^organization_id,
          select: max(r.position)
      )

    (ultima || 0) + 1
  end
end
