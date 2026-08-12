defmodule TheBand.WorkItems do
  @moduledoc """
  As issues como a origem as devolveu, e a decisão da plataforma sobre cada uma.

  **Camada de plataforma, não domínio.** Aqui vive o vocabulário do GitHub: `issue_type`
  com o nome que a organização deu, o número dentro do repositório, o estado. O que entra
  no domínio é o **conceito para o qual a issue foi promovida** — e é por isso que não
  existe conceito "issue" em nenhuma das doze ontologias da rede.

  Este módulo contém apenas `defdelegate` (ADR 0003).

  ## O que esta API não expõe, e por quê

    * `create_issue/2` — não há cadastro manual; expor convidaria a criar registro sem
      proveniência;
    * `delete_issue/2` — ausência marca, nunca apaga;
    * `set_classification/3` — a classificação é derivada das partes. Uma função para
      gravá-la é a porta para materializar situação, contra a ADR 0004 D7;
    * `mark_issues_no_longer_observed/2` — sem escopo de repositório é a L19. A aridade
      3 é a única que existe, e a obrigatoriedade está no tipo;
    * qualquer função que devolva `Ecto.Query` — vaza a fronteira e permite contornar o
      filtro de tenant.
  """

  alias TheBand.WorkItems.Axioms
  alias TheBand.WorkItems.Commands
  alias TheBand.WorkItems.Queries
  alias TheBand.WorkItems.Routing

  # ------------------------------------------------------------------- escritas

  defdelegate record_collected_issue(tenant, attrs), to: Commands
  defdelegate record_promotion(tenant, attrs), to: Commands
  defdelegate record_decomposition_link(tenant, attrs), to: Commands
  defdelegate recusar(tenant, attrs), to: Commands
  defdelegate replace_assignees(tenant, collected_issue_id, designados), to: Commands
  defdelegate replace_labels(tenant, collected_issue_id, rotulos), to: Commands

  defdelegate mark_issues_no_longer_observed(tenant, observed_repository_id, desde),
    to: Commands

  # -------------------------------------------------------------------- leituras

  defdelegate count_collected(tenant, opts \\ []), to: Queries
  defdelegate list_issues(tenant, opts \\ []), to: Queries
  defdelegate count_by_promotion(tenant, opts \\ []), to: Queries
  defdelegate count_gaps_by_reason(tenant, opts \\ []), to: Queries
  defdelegate unknown_types(tenant, opts \\ []), to: Queries
  defdelegate list_divergences(tenant, opts \\ []), to: Queries
  defdelegate classification(tenant, collected_issue_id), to: Queries
  defdelegate list_links(tenant), to: Queries
  defdelegate list_by_external_id(tenant), to: Queries
  defdelegate count_refused(tenant, opts \\ []), to: Queries
  defdelegate fetch_issue(tenant, id), to: Queries
  defdelegate promotion_history(tenant, collected_issue_id), to: Queries
  defdelegate current_promotions(tenant, issue_ids), to: Queries
  defdelegate list_composition(tenant, collected_issue_id), to: Queries
  defdelegate list_attendance(tenant, collected_issue_id), to: Queries
  defdelegate list_unpromoted_parts(tenant, collected_issue_id), to: Queries
  defdelegate fetch_parent(tenant, collected_issue_id), to: Queries
  defdelegate rule07_violations(tenant, opts \\ []), to: Queries
  defdelegate list_refused_for(tenant, collected_issue_id), to: Queries

  # -------------------------------------------------------------------- decisão

  defdelegate decide(issue, opts \\ []), to: Routing

  # -------------------------------------------------------------------- axiomas

  defdelegate rule07(concept, parent_concept), to: Axioms
  defdelegate rule07_explanation(forma), to: Axioms, as: :explicacao
end
