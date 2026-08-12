defmodule TheBand.Mapping.Commands do
  @moduledoc "Escritas de Mapping. A fronteira é `TheBand.Mapping`."

  import Ecto.Query

  alias TheBand.Jobs.RecomputePromotions
  alias TheBand.Mapping.Catalog
  alias TheBand.Mapping.Decision
  alias TheBand.Mapping.PatternValidator
  alias TheBand.Mapping.Queries
  alias TheBand.Mapping.Schemas.MappingRule
  alias TheBand.Mapping.Schemas.UnmappedPatternDecision
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems

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
      |> enfileirar_recalculo(tenant_id, organization_id)
    end
  end

  # Gravar regra sem recalcular deixaria a tela mostrar a regra e o dado antigo — e quem
  # lesse concluiria que a regra não funciona. O recálculo é parte de gravar, não uma ação
  # separada que alguém pode esquecer.
  defp enfileirar_recalculo({:ok, registro} = resultado, tenant_id, organization_id) do
    {:ok, _job} = RecomputePromotions.enqueue(tenant_id, organization_id)
    _ = registro
    resultado
  end

  defp enfileirar_recalculo(erro, _tenant_id, _organization_id), do: erro

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
        |> enfileirar_recalculo(regra.tenant_id, regra.organization_id)
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
      |> enfileirar_recalculo(regra.tenant_id, regra.organization_id)
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
      |> enfileirar_recalculo(regra.tenant_id, regra.organization_id)
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

  @doc """
  Materializa uma proposta do catálogo como regra da organização.

  **A pessoa é a autora, nunca "sistema"** — é o que FR-041 exige, e é o motivo de o
  catálogo não ser copiado na conexão.

  `{:error, :unknown_entry}` quando a chave não existe mais no catálogo: uma entrada
  removida não pode ser ativada, e o silêncio criaria regra a partir de nada.
  """
  @spec activate_catalog_rule(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
          {:ok, MappingRule.t()} | {:error, :unknown_entry | Ecto.Changeset.t() | recusa()}
  def activate_catalog_rule(%Tenant{} = tenant, organization_id, catalog_key, actor_id) do
    case Catalog.fetch_entry(catalog_key) do
      :error ->
        {:error, :unknown_entry}

      {:ok, entrada} ->
        create_rule(
          tenant,
          organization_id,
          %{
            where: entrada.where,
            how: entrada.how,
            pattern: entrada.pattern,
            case_sensitive: entrada.case_sensitive,
            target_concept: entrada.target_concept,
            catalog_key: catalog_key
          },
          actor_id
        )
    end
  end

  @doc """
  Ativa todas as propostas ainda não decididas.

  Uma ação, uma autoria: todas as regras criadas registram o mesmo autor. As já ativadas
  ou editadas são **puladas** — reativar sobrescreveria a edição, e FR-043 proíbe.
  """
  @spec activate_all_proposals(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, [MappingRule.t()]}
  def activate_all_proposals(%Tenant{} = tenant, organization_id, actor_id) do
    criadas =
      tenant
      |> Catalog.list_proposals(organization_id)
      |> Enum.filter(&(&1.state == :proposed))
      |> Enum.flat_map(fn proposta ->
        case activate_catalog_rule(tenant, organization_id, proposta.catalog_key, actor_id) do
          {:ok, regra} -> [regra]
          # Proposta que a organização não pode ativar — conceito removido da base, por
          # exemplo — é pulada, e não interrompe as outras. Interromper deixaria metade
          # ativada sem ninguém saber qual metade.
          {:error, _} -> []
        end
      end)

    {:ok, criadas}
  end

  @doc """
  A prévia: quantas issues a regra casa, e quantas **mudariam de conceito**.

  Os dois números são diferentes, e mostrar só o primeiro esconderia o caso perigoso: uma
  regra que casa 1031 issues e muda 1031 é muito diferente de uma que casa 1031 e muda 3.

  Calculada sobre as issues **já coletadas**: nenhuma requisição à origem (FR-023). Os
  payloads estão preservados desde a feature 004, e a promoção é recalculável.

  A candidata entra na **posição** dela, e não no fim — ver `Decision.com_candidata/3`.
  """
  @spec preview(Tenant.t(), Ecto.UUID.t(), map()) ::
          {:ok, map()} | {:error, recusa()}
  def preview(%Tenant{} = tenant, organization_id, attrs) do
    attrs = normalizar(attrs)

    with :ok <- validar(tenant, organization_id, attrs) do
      candidata = candidata(tenant, organization_id, attrs)

      vigentes =
        Decision.decidir_lote(
          tenant,
          organization_id,
          Decision.com_candidata(tenant, organization_id, nil)
        )

      com_regra =
        Decision.decidir_lote(
          tenant,
          organization_id,
          Decision.com_candidata(tenant, organization_id, candidata)
        )

      atuais = promocoes_vigentes(tenant, organization_id)
      sem_a_regra = Map.new(vigentes, &{&1.issue.id, &1.decisao.derived})

      casadas =
        Enum.filter(com_regra, fn %{decisao: d} -> d.mapping_rule_id == candidata.id end)

      # O efeito **da regra**, e não do recálculo: comparar com o que está gravado
      # atribuiria à regra tudo o que a etapa estrutural decide, e ela decidiria de todo
      # modo. Quem lê a prévia quer saber o que ESTA regra muda.
      mudariam =
        Enum.filter(com_regra, fn %{issue: i, decisao: d} ->
          d.derived != Map.get(sem_a_regra, i.id)
        end)

      # As duas contagens vêm das **mesmas funções** que o recálculo usa. Uma comparação
      # própria aqui faria a prévia dizer um número e a gravação produzir outro — e é
      # exatamente o que o teste do SC-007 pegou na primeira versão: 1 contra 90.
      linhas =
        Enum.count(com_regra, fn %{issue: i, decisao: d} ->
          Decision.mudou_registro?(d, Map.get(atuais, i.id))
        end)

      {:ok,
       %{
         matched: length(casadas),
         would_change: length(mudariam),
         # O que a gravação produz, contra o que está gravado. Difere de `would_change`
         # porque o recálculo também aplica a etapa estrutural e preenche proveniência.
         rows_to_write: linhas,
         sample: Enum.map(Enum.take(mudariam, 10), & &1.issue.title),
         total: length(com_regra)
       }}
    end
  end

  # A candidata é uma struct **não gravada**: a prévia é o efeito de uma regra antes de
  # ela existir. `id` sintético para a comparação de "quem decidiu" funcionar.
  defp candidata(tenant, organization_id, attrs) do
    posicao =
      attrs[:position] || proxima_posicao_para(tenant, organization_id)

    %MappingRule{
      id: attrs[:id] || Ecto.UUID.generate(),
      organization_id: organization_id,
      where: attrs[:where],
      how: attrs[:how],
      pattern: attrs[:pattern],
      case_sensitive: attrs[:case_sensitive] || false,
      target_concept: attrs[:target_concept],
      position: posicao,
      active: true,
      version: 1
    }
  end

  defp proxima_posicao_para(%Tenant{id: tenant_id}, organization_id),
    do: proxima_posicao(tenant_id, organization_id)

  @doc """
  Recalcula a promoção das issues da organização — **append-only e idempotente**.

  Grava linha nova só quando a decisão **difere da vigente**. Sem essa comparação, cada
  execução dobraria o histórico e a tela mostraria dezenas de decisões idênticas.

  Devolve **dois números**, e eles são diferentes:

    * `concept_changed` — quantas issues mudaram de conceito em relação ao que está gravado;
    * `written` — quantas linhas foram gravadas. Inclui as que mantiveram o conceito e
      mudaram a **proveniência** — decididas pela regra da organização em vez da global.

  Executar duas vezes sobre o mesmo estado devolve zero nos dois — é o SC-009.
  """
  @spec recompute(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, %{written: non_neg_integer(), concept_changed: non_neg_integer()}}
  def recompute(%Tenant{} = tenant, organization_id) do
    regras = Decision.com_candidata(tenant, organization_id, nil)
    vigentes = promocoes_vigentes(tenant, organization_id)

    resultados = Decision.decidir_lote(tenant, organization_id, regras)

    escritas =
      Enum.count(resultados, fn %{issue: issue, decisao: decisao} ->
        gravar_se_mudou(tenant, issue, decisao, Map.get(vigentes, issue.id))
      end)

    conceito =
      Enum.count(resultados, fn %{issue: issue, decisao: decisao} ->
        Decision.mudou_conceito?(decisao, Map.get(vigentes, issue.id))
      end)

    {:ok, %{written: escritas, concept_changed: conceito}}
  end

  defp gravar_se_mudou(tenant, issue, decisao, vigente) do
    if Decision.mudou_registro?(decisao, vigente) do
      {:ok, _} =
        WorkItems.record_promotion(tenant, %{
          collected_issue_id: issue.id,
          declared_concept: decisao.declared,
          derived_concept: decisao.derived,
          divergence_reason: decisao.divergence,
          divergence_kind: decisao.divergence_kind,
          skip_reason: decisao.skip_reason,
          skip_detail: decisao.skip_detail,
          rule_id: decisao.rule_id,
          rule_version: decisao.rule_version,
          evidence_source: decisao.evidence_source,
          confidence: decisao.confidence,
          mapping_rule_id: decisao.mapping_rule_id
        })

      true
    else
      false
    end
  end

  defp promocoes_vigentes(%Tenant{} = tenant, organization_id) do
    ids = Enum.map(Queries.issues_for_decision(tenant, organization_id), & &1.id)

    Map.new(WorkItems.current_promotions(tenant, ids), &{&1.collected_issue_id, &1})
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
