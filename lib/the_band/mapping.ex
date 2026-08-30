defmodule TheBand.Mapping do
  @moduledoc """
  O que a organização declarou que cada texto da origem significa.

  **Camada de plataforma.** Aqui vive vocabulário do GitHub — nome de tipo e texto de
  título —, e o que sai daqui é o **conceito** para o qual a issue é promovida.

  Este módulo contém apenas `defdelegate` (ADR 0003).

  ## A distinção que decide o desenho

  | | Catálogo | Regra da organização |
  |---|---|---|
  | Onde | YAML versionado | tabela `issue_mapping_rules` |
  | Quem escreve | commit revisável | a tela |
  | Quando é lido | **uma vez, no boot**, para ETS | por consulta, a cada uso |
  | Efeito de mudar | exige reiniciar | **vale imediatamente** |

  Uma regra criada pela tela que vivesse no YAML não valeria sem restart — e pedir
  restart depois de cadastrar regra é inaceitável numa tela de configuração.

  ## O que esta API não expõe, e por quê

    * `create_rule/3` sem autor — mapeamento é decisão; regra sem autor não tem a quem
      perguntar por quê;
    * `delete_rule/2` — desativar preserva a proveniência das promoções que a regra
      produziu;
    * `infer_rules_automatically/2` — inferência sobre texto livre é decisão de pessoa,
      sempre. Automatizá-la é o antipadrão que o princípio I proíbe;
    * `promote_by_label/2` — rótulo não é tipo;
    * qualquer função sobre `tool_concept_mappings` — substituída por esta feature.
  """

  alias TheBand.Mapping.Catalog
  alias TheBand.Mapping.Commands
  alias TheBand.Mapping.Decision
  alias TheBand.Mapping.Notifications
  alias TheBand.Mapping.PatternValidator
  alias TheBand.Mapping.Queries

  # ------------------------------------------------------------------- escritas

  defdelegate create_rule(tenant, organization_id, attrs, actor_id), to: Commands
  defdelegate update_rule(tenant, rule_id, attrs, actor_id), to: Commands
  defdelegate deactivate_rule(tenant, rule_id, actor_id), to: Commands
  defdelegate reactivate_rule(tenant, rule_id), to: Commands

  defdelegate declare_not_a_type(tenant, organization_id, pattern, actor_id, note \\ nil),
    to: Commands

  defdelegate revert_not_a_type(tenant, decision_id, actor_id), to: Commands

  defdelegate activate_catalog_rule(tenant, organization_id, catalog_key, actor_id),
    to: Commands

  defdelegate activate_all_proposals(tenant, organization_id, actor_id), to: Commands
  defdelegate preview(tenant, organization_id, attrs), to: Commands
  defdelegate recompute(tenant, organization_id), to: Commands

  defdelegate subscribe(tenant), to: Notifications
  defdelegate broadcast(tenant_id, message), to: Notifications

  # ------------------------------------------------------------------- leituras

  defdelegate list_rules(tenant, organization_id, opts \\ []), to: Queries
  defdelegate active_rules(tenant, organization_id), to: Queries
  defdelegate fetch_rule(tenant, rule_id), to: Queries
  defdelegate list_not_a_type(tenant, organization_id), to: Queries
  defdelegate title_sample(tenant, organization_id), to: Queries
  defdelegate issues_for_decision(tenant, organization_id), to: Queries
  defdelegate list_proposals(tenant, organization_id), to: Catalog
  defdelegate not_type_patterns(tenant, organization_id), to: Catalog
  defdelegate not_type_reason(), to: Catalog
  defdelegate gap_summary(tenant, organization_id), to: Queries
  defdelegate decidir_lote(tenant, organization_id, regras), to: Decision

  # ------------------------------------------------------------------ validação

  defdelegate validate_pattern(how, pattern, sample), to: PatternValidator, as: :validate
end
