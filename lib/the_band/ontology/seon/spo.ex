defmodule TheBand.Ontology.SEON.SPO do
  @moduledoc """
  Software Process Ontology — as ocorrências de atividade executada.

  **Único ponto de entrada do módulo.** Nenhum outro módulo alcança os schemas em
  `Schemas.*`, e nenhum outro chama `Repo` sobre `spo_*`.

  Este módulo contém apenas `defdelegate` (ADR 0003).

  ## A tabela é do conceito, e não da origem

  `spo.performed_project_activity` é o *kind* de todas as ocorrências de atividade da
  rede. A ontologia declara que commits, execuções de teste, cerimônias, implantações e
  inspeções são especializações dele e *"compartilham o mesmo princípio de identidade"*.

  A timeline do GitHub é a **primeira** origem a chegar aqui, e não a única prevista —
  por isso a ligação com a entidade é `subject_type` + `subject_id`, e não uma chave
  estrangeira para issue. O custo está nomeado no plano da feature 022: uma junção a
  mais para achar as atividades de uma issue.

  ## O que esta API não expõe, e por quê

    * `update_activity/2` — uma ocorrência não muda; ela aconteceu. Reprocessar devolve
      `:unchanged`, e é por isso que o campo virtual aqui não tem `:updated`;
    * `delete_activity/2` — ausência marca, nunca apaga, e uma atividade removida
      apagaria o rastro que ela existe para guardar;
    * qualquer função que devolva `Ecto.Query` — vaza o schema interno e permite compor
      fora da fronteira, contornando o filtro de tenant.
  """

  alias TheBand.Ontology.SEON.SPO.Commands
  alias TheBand.Ontology.SEON.SPO.Projects
  alias TheBand.Ontology.SEON.SPO.Queries

  # ------------------------------------------------------------------- escritas

  defdelegate record_activity(tenant, attrs), to: Commands
  defdelegate record_intended_process(tenant, attrs), to: Commands

  # -------------------------------------------------------------------- leituras

  defdelegate list_activities(tenant, subject_type, subject_id), to: Queries
  defdelegate list_activities_by_subject(tenant, subject_type, subject_ids), to: Queries
  defdelegate count_activity_types(tenant), to: Queries
  defdelegate count_board_states(tenant), to: Queries
  defdelegate andamento?(estado), to: Queries
  # Uma função, duas entradas: `(tenant, issue_id)` consulta, e
  # `(atividades, estados_do_quadro)` responde sobre o que já foi carregado. A segunda
  # existe porque a tela precisa das duas listas no mesmo render — sem ela o render
  # subia de 36 para 48 consultas.
  defdelegate cycle_time(tenant_ou_atividades, issue_id_ou_estados), to: Queries

  # ------------------------------------------------------ o projeto (feature 025)
  #
  # Projeto é **declaração**, e não observação — por isso `create_project/3` exige autor
  # e não existe caminho de coleta que o crie.

  defdelegate create_project(tenant, attrs, actor_id), to: Projects
  defdelegate set_parent(tenant, project_id, parent_id), to: Projects
  defdelegate clear_parent(tenant, project_id), to: Projects
  defdelegate link_repository(tenant, project_id, observed_repository_id, actor_id), to: Projects
  defdelegate unlink_repository(tenant, vinculo_id, actor_id), to: Projects

  defdelegate list_projects(tenant), to: Projects
  defdelegate fetch_project(tenant, id), to: Projects
  defdelegate list_project_repositories(tenant, project_id), to: Projects
  defdelegate list_project_issues(tenant, project_id, opts \\ []), to: Projects
  defdelegate count_project_issues(tenant, project_id), to: Projects
end
