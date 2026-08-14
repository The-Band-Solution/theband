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
  alias TheBand.Ontology.SEON.SPO.Queries

  # ------------------------------------------------------------------- escritas

  defdelegate record_activity(tenant, attrs), to: Commands

  # -------------------------------------------------------------------- leituras

  defdelegate list_activities(tenant, subject_type, subject_id), to: Queries
  defdelegate count_activity_types(tenant), to: Queries
end
