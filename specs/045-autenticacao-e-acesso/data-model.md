# Data Model — Autenticação e papel de acesso (045)

## Alterações em `users` (migração 1)

| Coluna | Tipo | Regra |
|---|---|---|
| `password_hash` | string, NULL | NULL = conta sem senha (pré-feature): login recusa com mensagem única (FR-014). Nunca aparece em log/tela (FR-003). |
| `password_set_at` | utc_datetime, NULL | quando a senha vigente foi definida. |
| `must_change_password` | boolean, default false | true na senha temporária (FR-013): primeira entrada obriga troca antes de qualquer tela. |
| `session_token` | binary/string, NULL | versão da sessão (research R2). Girar = derrubar as outras sessões (FR-015). |
| `logged_in_at` | utc_datetime, NULL | última entrada; expiração em 7 dias de inatividade (assumption). |
| `failed_attempts` | integer, default 0 | espera crescente (FR-016, research R4). |
| `last_failed_at` | utc_datetime, NULL | idem. |

`role` (`admin`\|`member`) permanece: **marca de administrador** (FR-022 — gestão, não
visão). Semântica atualizada no moduledoc; sem migração de valores.

## Tabela nova `access_scope_grants` (migração 2)

| Coluna | Tipo | Regra |
|---|---|---|
| `tenant_id` | binary_id, NOT NULL | toda consulta filtra (V). |
| `user_id` | binary_id, NOT NULL | conta que recebe. |
| `level` | string, NOT NULL | `team` \| `project` \| `organization` (FR-006/007). |
| `target_id` | binary_id, NOT NULL | equipe (`eo_teams`), projeto declarado (`spo_projects`) ou organização (`eo_organizations`) — alvo obrigatório. |
| `granted_by_user_id` / `granted_at` | — | proveniência (FR-008). |
| `revoked_by_user_id` / `revoked_at` | — | revogação é marca, nunca delete (III). |

Índices: `[tenant_id, user_id]`; unicidade parcial `[tenant_id, user_id, level,
target_id] WHERE revoked_at IS NULL` (uma concessão vigente por alvo).

**Seed da migração** (research R9): para cada conta `admin`, uma concessão
`organization` por organização observada do tenant — a virada não rebaixa ninguém.

## O que NÃO se grava

- **Escopos derivados** — leitura das relações vigentes (elo → pessoa → vínculos →
  equipes → `spo_project_teams` → projetos): nascem e morrem com o fato (FR-020/021,
  research R5/R6).
- **Senha em claro, em qualquer coluna, log ou payload** (FR-003).

## Resolução de escopos (leitura, `Tenants.Access`)

```text
scopes(tenant, user) =
  piso person        se elo vigente (users.person_id, não revogado)
+ derived_team       ∀ equipe com vínculo vigente da pessoa
+ derived_project    ∀ projeto declarado ligado (vigente) a equipe com vínculo vigente
+ granted            ∀ concessão vigente em access_scope_grants
```

Cada escopo devolvido carrega `origem` (`:floor` | `:derived_team` |
`:derived_project` | `:granted`) — a tela pinta hachura pelo campo (derivado se
declara). Visão = união; recusa nomeia o motivo (FR-010/011).
