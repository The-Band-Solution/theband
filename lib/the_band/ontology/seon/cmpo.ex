defmodule TheBand.Ontology.SEON.CMPO do
  @moduledoc """
  Configuration Management Process Ontology — repositórios de código.

  **Único ponto de entrada do módulo.** Nenhum outro módulo alcança os schemas em
  `Schemas.*`, e nenhum outro chama `Repo` sobre `cmpo_*` nem sobre
  `sys_swo_loaded_software_system_copies`.

  Este módulo contém apenas `defdelegate` (ADR 0003).

  ## A referência que atravessa a fronteira

  `cmpo.source_repository` é `subkind` de `sys_swo.loaded_software_system_copy`, que
  vive em outra ontologia. Pela regra da fronteira — constituição IX —, isso
  materializa por **referência**: o repositório é um valor de discriminador na tabela
  do kind, com extensão em CMPO para os atributos próprios.

  A tabela do kind é criada **uma vez só**. A próxima ontologia que precisar de cópia
  carregada de sistema de software aponta para ela e acrescenta seu discriminador —
  nada do que já existe é alterado.

  ## O que esta API não expõe, e por quê

    * `delete_source_repository/2` — ausência marca, nunca apaga. Um repositório que
      saiu da origem continua respondendo o que ele foi;
    * `create_source_repository/2` — não há cadastro manual: repositório vem de
      observação, e criar sem proveniência produziria registro que ninguém sabe de onde
      veio;
    * qualquer função que devolva `Ecto.Query` — vaza o schema interno e permite compor
      fora da fronteira, contornando o filtro de tenant.
  """

  alias TheBand.Ontology.SEON.CMPO.Commands
  alias TheBand.Ontology.SEON.CMPO.Queries

  # ------------------------------------------------------------------- escritas

  defdelegate upsert_source_repository_from_source(tenant, attrs), to: Commands
  defdelegate observe_repository(tenant, connected_tool_id, source_repository_id), to: Commands
  defdelegate exclude_from_observation(tenant, observed_repository_id, user_id), to: Commands
  defdelegate include_in_observation(tenant, observed_repository_id), to: Commands
  defdelegate mark_inaccessible(tenant, observed_repository_id, reason), to: Commands
  defdelegate clear_inaccessible(tenant, observed_repository_id), to: Commands

  # -------------------------------------------------------------------- leituras

  defdelegate list_observed(tenant, opts \\ []), to: Queries
  defdelegate list_collectable(tenant, connected_tool_id), to: Queries
  defdelegate count_observed(tenant, opts \\ []), to: Queries
  defdelegate fetch_observed(tenant, id), to: Queries
end
