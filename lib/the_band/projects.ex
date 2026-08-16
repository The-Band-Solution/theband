defmodule TheBand.Projects do
  @moduledoc """
  Os quadros como a origem os devolve — entidade, campos, itens e valores. Feature 004 F7.

  Fronteira: nenhum módulo alcança os schemas daqui, e nenhum chama `Repo` sobre
  `observed_projects`, `project_field_definitions`, `project_items`, `item_field_values`
  ou `project_iterations`. Este módulo contém apenas `defdelegate` (ADR 0003).

  ## O que esta API não expõe, e por quê

  | Ausente | Por quê |
  |---|---|
  | `promote_project_to_software_project/2` | quadro é planejamento; empreendimento vem de cadastro declarado |
  | `promote_project_to_scrum_project/2` | adotar Scrum não é observável — quadro com iterações pode ser Kanban |
  | `set_product_backlog/3` | a composição é derivada da atribuição de iteração (FR-032b) |
  | `record_item_history/2` | o histórico de itens está fora de escopo por custo de consumo (FR-028) |
  | `interpret_field_by_name/2` | mapeamento por semelhança de nome é antipadrão declarado (FR-024) |

  Contrato: `specs/004-issues-e-projetos/contracts/project-ingestion.md`.
  """

  alias TheBand.Projects.{Commands, Queries}

  defdelegate record_observed_project(tenant, attrs), to: Commands
  defdelegate record_field_definition(tenant, attrs), to: Commands
  defdelegate record_item(tenant, attrs), to: Commands
  defdelegate record_item_field_value(tenant, attrs), to: Commands
  defdelegate record_iteration(tenant, attrs), to: Commands
  defdelegate record_iteration_absent(tenant, iteration_id, desde), to: Commands

  defdelegate list_projects(tenant), to: Queries
  defdelegate get_project(tenant, id), to: Queries
  defdelegate list_field_definitions(tenant, observed_project_id), to: Queries
  defdelegate list_items(tenant, observed_project_id), to: Queries
  defdelegate item_values(tenant, observed_project_id), to: Queries
  defdelegate list_iterations(tenant, observed_project_id), to: Queries
  defdelegate count_items(tenant, observed_project_id), to: Queries
  defdelegate importance_source(tenant, observed_project_id), to: Queries
  defdelegate field_mappings(tenant), to: Queries
  defdelegate interpretation_for(mapeamentos, field_external_id, data_type), to: Queries
  defdelegate product_backlog(tenant, observed_project_id), to: Queries
  defdelegate sprint_backlog(tenant, sprint_id), to: Queries
end
