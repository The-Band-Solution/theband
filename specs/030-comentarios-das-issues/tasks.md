# Feature 030 — Tarefas

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md)

## Phase 0: Ontologia e mapeamento (feito antes das tarefas — a decisão veio primeiro)

- [x] T000 CMO no continuum (ontologia + módulo + 4 CQs) e mapeamento
  `github.issue_comment.to.cmo.comment`, validados pela base — per decisão de 2026-08-17

## Phase 1: Nota (F1–F2)

- [ ] T001 Migração `collected_issue_comments` + `comments_collected_at` em
  `observed_repositories` per plan F1
- [ ] T002 Schema Ecto + upsert idempotente por external_id (marca, nunca apaga) per FR-002
- [ ] T003 Consulta `issue_comments.graphql` com rateLimit e totalCount per FR-001/FR-008
- [ ] T004 Ingestão `github_issue_comments.ex` — incremental, autor pela regra dos
  designados, sumiço marcado per FR-001/FR-002/FR-007
- [ ] T005 Fase na sincronização, depois das issues, com cobertura registrada per FR-008
- [ ] T006 Coleta real no tenant: totais por amostra contra a API per SC-001

## Phase 2: Música (F3)

- [ ] T007 `Communication.Discussions` — for_issue/2, participation_of/3,
  last_act_for_issues/2, número fixo de consultas per FR-005/SC-004

## Phase 3: Telas (F4–F6)

- [ ] T008 Detalhe da issue: seção Discussion com os dois vazios distintos per FR-003
- [ ] T009 Anti-padrão da parada com resolução tripla (silent/stale/active) per FR-004
- [ ] T010 Página da pessoa: "Discussions they took part in", derivada com hachura per FR-006
- [ ] T011 Verificação ao vivo: SC-002 (issue parada real rotulada) e SC-003
  (no_assignment com participação, ou o achado registrado)
