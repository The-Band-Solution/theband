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
  alias TheBand.Ontology.SEON.EO.Profiles
  alias TheBand.Ontology.SEON.EO.Queries
  alias TheBand.Ontology.SEON.EO.Visibility

  # ------------------------------------------------------------------- escritas

  defdelegate upsert_organization_from_source(tenant, attrs), to: Commands
  defdelegate upsert_person_from_source(tenant, attrs), to: Commands
  defdelegate upsert_team_from_source(tenant, attrs), to: Commands
  defdelegate create_declared_team(tenant, name, actor_id), to: Commands

  # Feature 055 — a organização declara suas equipes.
  defdelegate declare_structural_team(tenant, organization_id, name, actor_id), to: Commands
  defdelegate compose_teams(tenant, part_id, whole_id, actor_id), to: Commands
  defdelegate decompose_teams(tenant, part_id, whole_id, actor_id), to: Commands
  defdelegate declare_team_membership(tenant, team_id, person_id, attrs, actor_id), to: Commands
  defdelegate record_team_departure(tenant, team_id, person_id, quando, actor_id), to: Commands

  defdelegate record_team_membership_mistake(tenant, team_id, person_id, razao, actor_id),
    to: Commands

  defdelegate count_team_members_at(tenant, team_id, quando), to: Queries
  defdelegate team_members_at(tenant, team_id, quando), to: Queries
  defdelegate team_member_ids_at(tenant, team_id, quando), to: Queries
  defdelegate team_member_ids_ever(tenant, team_id), to: Queries
  defdelegate team_parts(tenant, team_id), to: Queries
  defdelegate team_wholes(tenant, team_id), to: Queries
  defdelegate record_team_membership_evidence(tenant, attrs), to: Commands

  defdelegate mark_evidence_no_longer_observed(tenant, organization_id, collection_started_at),
    to: Commands

  # ------------------------------------------------------------------- leituras

  defdelegate fetch_person(tenant, person_id), to: Queries
  defdelegate person_logins(tenant, person_ids), to: Queries
  defdelegate observed_org_logins_of_people(tenant, person_ids), to: Queries
  defdelegate list_person_teams(tenant, person_id), to: Queries
  defdelegate person_active_teams(tenant, person_id), to: Queries
  defdelegate person_observed_organization_ids(tenant, person_id), to: Queries
  defdelegate teams_by_ids(tenant, ids), to: Queries
  defdelegate count_roles(tenant), to: Queries

  # ------------------------------------------------------- papéis e alocação (feature 021)

  defdelegate list_roles(tenant, opts \\ []), to: Queries

  # Issue #317 — os papéis DESTA organização, compostos com o catálogo da rede. Nome próprio
  # porque `list_roles/2` é do tenant inteiro, e o escopo precisa estar no nome.
  defdelegate list_organization_roles(tenant, organization_id), to: Queries
  defdelegate role_by_concept(tenant, organization_id, concept_id), to: Queries
  defdelegate team_size(tenant, team_id), to: Queries
  defdelegate pending_evidence(tenant, team_id), to: Queries
  defdelegate membership_disagreements(tenant, team_id), to: Queries
  defdelegate fetch_evidence(tenant, evidence_id), to: Queries
  defdelegate fetch_team(tenant, team_id), to: Queries
  defdelegate fetch_role(tenant, role_id), to: Queries
  defdelegate suggested_roles(), to: Queries
  defdelegate count_memberships(tenant), to: Queries
  defdelegate count_memberships_of_role(tenant, role_id), to: Queries
  defdelegate fetch_membership(tenant, membership_id), to: Queries
  defdelegate list_person_roles(tenant, person_id), to: Queries

  # Issue #369: quem vê o painel de quem. A concessão é DECLARADA por papel — `Tech Leader`
  # parece liderança e `Coordenador` também, e conceder visibilidade por padrão de nome erra
  # para o lado que ninguém reclama.
  defdelegate pode_ver(tenant, user, person_id), to: Visibility
  defdelegate grants_by_role(tenant), to: Visibility
  defdelegate grant_coverage(tenant), to: Visibility
  defdelegate declare_grant(tenant, role_id, scope, actor_id), to: Visibility
  defdelegate revoke_grant(tenant, role_id, scope, actor_id), to: Visibility

  defdelegate create_role(tenant, organization_id, attrs, actor_id), to: Commands
  defdelegate rename_role(tenant, role_id, name, actor_id \\ nil), to: Commands
  defdelegate delete_role(tenant, role_id), to: Commands

  # Materializa um papel do catálogo nesta organização — a linha nasce no primeiro uso.
  defdelegate materialize_catalog_role(tenant, organization_id, concept_id), to: Commands

  # Ocultar MARCA, e nunca apaga. Papel do catálogo não é apagável: a rede continua nomeando-o.
  defdelegate hide_role(tenant, role_id, actor_id), to: Commands
  defdelegate unhide_role(tenant, role_id, actor_id), to: Commands

  # Promover é ato de UMA PESSOA, com autor gravado. A plataforma não promove sozinha.
  defdelegate promote_evidence(tenant, evidence_id, papel, actor_id, opts \\ []), to: Commands
  defdelegate allocate(tenant, attrs), to: Commands
  defdelegate end_allocation(tenant, membership_id, quando), to: Commands
  defdelegate list_people(tenant, opts \\ []), to: Queries
  defdelegate count_people(tenant, opts \\ []), to: Queries
  defdelegate person_ids_by_login(tenant), to: Queries
  defdelegate people_names(tenant, ids), to: Queries
  defdelegate list_teams(tenant, opts \\ []), to: Queries
  defdelegate count_teams(tenant, opts \\ []), to: Queries
  defdelegate list_team_members(tenant, team_id, opts \\ []), to: Queries
  defdelegate count_team_members(tenant, team_id, opts \\ []), to: Queries
  defdelegate list_organizations(tenant, opts \\ []), to: Queries
  defdelegate organization_overview(tenant), to: Queries
  defdelegate list_person_organizations(tenant, person_id, opts \\ []), to: Queries
  defdelegate fetch_organization_by_login(tenant_id, login), to: Queries
  defdelegate organizations_by_person(tenant, person_ids), to: Queries
  defdelegate fetch_organization!(tenant, organization_id), to: Queries
  defdelegate list_people_without_team(tenant, organization_id), to: Queries
  defdelegate fetch_derived_team(tenant, organization_id), to: Queries
  defdelegate observation_impact(tenant, organization_login), to: Queries
  defdelegate shared_people_names(tenant, organization_login), to: Queries
  defdelegate mark_organization_no_longer_observed(tenant, organization_login), to: Commands
  defdelegate assign_team_organization(tenant, team, organization_id), to: Commands
  defdelegate upsert_derived_team(tenant, organization, attrs \\ %{}), to: Commands
  defdelegate record_derived_team_membership(tenant, attrs), to: Commands
  defdelegate retire_derived_team(tenant, team), to: Commands
  defdelegate derived_team?(team), to: Commands
  defdelegate derived_prefix(), to: Commands
  defdelegate derived_source(), to: Commands
  defdelegate count_evidence_pending_role(tenant, opts \\ []), to: Queries

  # ---------------------------------------------------------------- invariantes

  defdelegate check_evidence(attrs), to: Constraints
  defdelegate check_team(attrs), to: Constraints
  defdelegate derived_team_declares_itself(attrs), to: Constraints
  defdelegate derived_link_has_no_access_level(attrs), to: Constraints
  defdelegate countable_as_person?(attrs), to: Constraints

  # -- perfis derivados — feature 026 -------------------------------------------
  #
  # O perfil **não é afirmação de competência**: é um texto sobre a pessoa, com quem o
  # escreveu e sobre qual recorte. Ver research.md R1 da feature 026.

  defdelegate record_profile(tenant, attrs), to: Profiles, as: :record
  defdelegate current_profile(tenant, person_id), to: Profiles, as: :current
  defdelegate list_profiles(tenant, person_id), to: Profiles, as: :list
end
