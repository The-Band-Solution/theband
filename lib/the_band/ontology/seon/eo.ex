defmodule TheBand.Ontology.SEON.EO do
  @moduledoc """
  Enterprise Ontology — organizações, pessoas, equipes e papéis.

  **Único ponto de entrada do módulo.** Nenhum outro módulo alcança os schemas
  em `Schemas.*`, e nenhum outro módulo chama `Repo` sobre as tabelas `eo_*`.
  A violação é textual, e por isso pega em revisão: `Repo` ou `EO.Schemas.` fora
  de `lib/the_band/ontology/seon/eo/`.

  Este módulo contém apenas `defdelegate` (ADR 0003). A implementação vive em
  `Commands`, `Queries` e `Constraints`.

  ## O que esta API não expõe, e por quê

    * `create_person/2` e `create_team/2` — não há caso de uso de cadastro manual
      nesta feature, e expor a função convidaria a criar registro sem
      proveniência;
    * `delete_*` — ausência na origem marca `no_longer_observed_at`; a plataforma
      existe para preservar rastreabilidade histórica;
    * `create_team_membership/2` — exige papel organizacional, que nenhuma fonte
      desta feature fornece;
    * qualquer função que devolva `Ecto.Query` — devolver query vaza o schema
      interno e permite compor fora da fronteira, contornando o filtro de tenant.
  """

  alias TheBand.Ontology.SEON.EO.Commands
  alias TheBand.Ontology.SEON.EO.Constraints
  alias TheBand.Ontology.SEON.EO.Queries

  # ------------------------------------------------------------------- escritas

  defdelegate upsert_organization_from_source(tenant, attrs), to: Commands
  defdelegate upsert_person_from_source(tenant, attrs), to: Commands
  defdelegate upsert_team_from_source(tenant, attrs), to: Commands
  defdelegate record_team_membership_evidence(tenant, attrs), to: Commands
  defdelegate mark_evidence_no_longer_observed(tenant, collection_started_at), to: Commands

  # ------------------------------------------------------------------- leituras

  defdelegate list_people(tenant, opts \\ []), to: Queries
  defdelegate count_people(tenant, opts \\ []), to: Queries
  defdelegate list_teams(tenant, opts \\ []), to: Queries
  defdelegate count_teams(tenant, opts \\ []), to: Queries
  defdelegate list_team_members(tenant, team_id, opts \\ []), to: Queries
  defdelegate list_organizations(tenant, opts \\ []), to: Queries
  defdelegate count_evidence_pending_role(tenant, opts \\ []), to: Queries

  # ---------------------------------------------------------------- invariantes

  defdelegate check_evidence(attrs), to: Constraints
  defdelegate check_team(attrs), to: Constraints
  defdelegate countable_as_person?(attrs), to: Constraints
end
