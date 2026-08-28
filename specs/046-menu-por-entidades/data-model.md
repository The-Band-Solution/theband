# Data Model — Menu por entidades (046)

**Nenhuma entidade nova, nenhuma migração.** Esta feature é navegação e uma tela de
leitura sobre o que já existe:

| Leitura | Fonte existente | Uso na feature |
|---|---|---|
| Organizações do tenant | `eo_organizations` (via `EO.list_organizations/2`) | tela Organization, nível 1 |
| Equipes por organização | `eo_teams` (via `EO.list_teams/2`, filtro por organização) | tela Organization, por org |
| Responsáveis por organização | `eo_role_visibility_grants` com escopo organização + vínculos vigentes | tela Organization, por org (research R4) |
| Projetos por organização | `observed_projects.source_instance` ↔ login da organização | tela Organization, por org, com grupo "sem organização identificada" (research R3) |
| Papel de plataforma | `users.role` (`User.admin?/1`) | gating da seção Operação no menu (research R5) |

Estado de navegação (área ativa, dropdown aberto) é efêmero de UI — não persiste.
