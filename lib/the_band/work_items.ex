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
    * `mark_issues_no_longer_observed/2` e
      `mark_decomposition_links_no_longer_observed/2` — sem escopo de repositório é a
      L19. A aridade 3 é a única que existe nas duas, e a obrigatoriedade está no tipo.
      No caso do vínculo, o repositório é o **do pai**: quem declara a decomposição é
      ele, e 57 vínculos têm a filha em outro repositório;
    * qualquer função que devolva `Ecto.Query` — vaza a fronteira e permite contornar o
      filtro de tenant.
  """

  alias TheBand.WorkItems.Axioms
  alias TheBand.WorkItems.Commands
  alias TheBand.WorkItems.PersonWork
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

  defdelegate mark_decomposition_links_no_longer_observed(
                tenant,
                parent_issue_ids,
                desde
              ),
              to: Commands

  # -------------------------------------------------------------------- leituras

  defdelegate count_collected(tenant, opts \\ []), to: Queries
  defdelegate count_collected_by_repository(tenant, repository_ids), to: Queries
  defdelegate repositories_with_absent_issues(tenant, repository_ids), to: Queries
  defdelegate count_assigned_to(tenant, person_id), to: Queries
  defdelegate count_authored_by(tenant, person_id), to: Queries
  defdelegate repositories_of_person(tenant, person_id), to: Queries

  # O painel da pessoa (feature 023). Módulo próprio porque responde outra pergunta: as
  # leituras acima descrevem a issue, estas descrevem o trabalho de alguém ao longo do tempo.
  defdelegate assigned_open_count(tenant, person_id), to: PersonWork
  defdelegate timeline_coverage(tenant, person_id), to: PersonWork
  defdelegate closed_by_month(tenant, person_id), to: PersonWork
  defdelegate open_age_buckets(tenant, person_id), to: PersonWork
  defdelegate lead_time(tenant, person_id), to: PersonWork
  defdelegate issues_assigned_to(tenant, person_id), to: PersonWork
  defdelegate list_issues(tenant, opts \\ []), to: Queries
  defdelegate count_by_promotion(tenant, opts \\ []), to: Queries
  defdelegate count_gaps_by_reason(tenant, opts \\ []), to: Queries
  defdelegate unknown_types(tenant, opts \\ []), to: Queries
  defdelegate list_divergences(tenant, opts \\ []), to: Queries
  defdelegate count_divergences_by_kind(tenant, opts \\ []), to: Queries
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
  defdelegate list_unnamed_relation_parts(tenant, collected_issue_id), to: Queries
  defdelegate fetch_parent(tenant, collected_issue_id), to: Queries
  defdelegate list_parents(tenant, issue_ids), to: Queries
  defdelegate rule07_violations(tenant, opts \\ []), to: Queries
  defdelegate list_refused_for(tenant, collected_issue_id), to: Queries

  # -------------------------------------------------------------------- decisão

  defdelegate decide(issue, opts \\ []), to: Routing

  # -------------------------------------------------------------------- axiomas

  defdelegate rule07(concept, parent_concept), to: Axioms
  defdelegate rule07_explanation(forma), to: Axioms, as: :explicacao
  defdelegate relation(concept, parent_concept), to: Axioms, as: :relacao
end
