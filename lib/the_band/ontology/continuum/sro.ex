defmodule TheBand.Ontology.Continuum.SRO do
  @moduledoc """
  Scrum Reference Ontology — as caixas de tempo do processo.

  **Único ponto de entrada do módulo.** Nenhum outro alcança os schemas em `Schemas.*`, e
  nenhum chama `Repo` sobre `sro_*`. Este módulo contém apenas `defdelegate` (ADR 0003).

  ## A primeira fronteira SRO do repositório

  Nenhum conceito da Scrum Reference Ontology era materializado antes desta feature. O
  prefixo das tabelas, a forma do critério de identidade e o tratamento da ausência
  serão copiados pelas irmãs — sprint backlog, cerimônia, entregável.

  ## Todo campo de iteração é sprint

  Decisão da pessoa mantenedora em 2026-08-15: `Sprint`, `Iteration` e `Quarter` viram
  todos sprint. **O nome do campo fica gravado**, porque somar caixas de 14 e de 90 dias
  sem distingui-las produziria uma contagem que mistura granularidades.

  ## A ordem da coleta é obrigatória

  Primeiro as caixas, **depois** as issues dentro delas: o vínculo precisa do
  `sprint_id`, que só existe depois de a caixa estar gravada. Não é preferência de
  desenho — é dependência de dado.

  ## O que esta API não expõe, e por quê

    * `delete_sprint/2` — ausência marca, nunca apaga. Um sprint removido do quadro
      continua tendo existido, e as issues continuam tendo estado nele;
    * `create_sprint/2` — não há cadastro manual: caixa de tempo vem de observação, e
      criar sem proveniência produziria sprint que ninguém sabe de onde veio;
    * `velocity/2` — a origem **não fornece unidade de tamanho**, e contar issues por
      sprint mudaria de significado a cada decomposição mais fina. É a limitação que
      `flow.throughput.rate` já declara;
    * qualquer função que devolva `Ecto.Query` — vaza o schema e permite compor fora da
      fronteira, contornando o filtro de tenant.
  """

  alias TheBand.Ontology.Continuum.SRO.Commands
  alias TheBand.Ontology.Continuum.SRO.Queries

  # ------------------------------------------------------------------- escritas

  defdelegate record_sprint(tenant, attrs), to: Commands
  defdelegate place_issue_in_sprint(tenant, sprint_id, collected_issue_id), to: Commands

  defdelegate mark_issues_no_longer_in_sprint(tenant, sprint_id, observadas, desde),
    to: Commands

  # -------------------------------------------------------------------- leituras

  defdelegate list_sprints(tenant, opts \\ []), to: Queries
  defdelegate list_sprint_issues(tenant, sprint_id), to: Queries

  # Os dois backlogs são conceitos da SRO — sro.product_backlog e sro.sprint_backlog —
  # e a derivação vive na fronteira Projects, dona das tabelas de item e valor. A
  # delegação atravessa módulo, nunca Repo: é a composição derivada da atribuição de
  # iteração (FR-032b), exposta aqui com o nome do conceito.
  defdelegate product_backlog(tenant, observed_project_id), to: TheBand.Projects.Queries
  defdelegate sprint_backlog(tenant, sprint_id), to: TheBand.Projects.Queries
  defdelegate count_issues_outside_any_sprint(tenant, board_number), to: Queries
end
