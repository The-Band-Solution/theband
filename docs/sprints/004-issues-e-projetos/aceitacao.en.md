# Sprint 004 — Acceptance record {#sprint-004--registro-de-aceitação}

**Feature**: [004-issues-e-projetos](../../../specs/004-issues-e-projetos/spec.md)
**Assessed on**: 2026-08-11
**Role**: Product Owner — Paulo Sergio Santos Junior
**Type**: `sro.product_owner_client` — whoever demands is whoever decides, and the decision is final

Each criterion walked through against evidence. The classification follows from that, it is never
assigned — `sro.rule03`.

## Summary {#resumo}

| | Count |
|---|---:|
| Deliverables assessed | 4 |
| Criteria assessed | 26 |
| Criteria without evidence | **0** |
| Non-conforming criteria | **0** |
| Accepted | — to be confirmed by the role |

## Final state of the real data {#estado-final-do-dado-real}

Measured in the development database on 2026-08-11, after the collection:

```text
135 repositórios observados       4455 issues coletadas
4455 promoções vigentes           5022 promoções no histórico (append-only)
1614 vínculos de decomposição        4 vínculos recusados
4833 payloads de issue preservados 163 payloads de repositório
   0 issues marcadas como ausentes
```

Checked against the API: `The-Band-Solution` has 14 repositories and 189 issues — and the
platform collected 14 and 189.

---

## D01 — The referenced kind, and the boundary rule (F0) {#d01--o-kind-referenciado-e-a-regra-da-fronteira-f0}

**Produced by**: T001, T002
**Materializes**: no user story — it is a structural prerequisite, assessed against
constitution IX.

| Criterion | Conforms | Evidence |
|---|---|---|
| One concept annotated, not the whole ontology | **yes** | `sys_swo.loaded_software_system_copy` got `kind`; the other 10 remain without a stereotype, and `derive --ontology sys_swo` still fails |
| The requirement of the CMPO derivation was zeroed | **yes** | `derive --ontology cmpo \| grep -c "sem ontouml_stereotype"` returns 0 |
| The reference is **one** table, not two | **yes** | `boundary_rule_test.exs`, 5 tests. Switching `source_repository` to `kind`, **4 of 5 pass** and the message says it would fragment |
| A removed annotation is detected | **yes** | removing the kind's stereotype, **3 of 5 pass** |

**Derived phase**: `sro.accepted_deliverable`.

---

## D02 — Semantics declared before the code (F1) {#d02--semântica-declarada-antes-do-código-f1}

**Produced by**: T003 to T006

| Criterion | Conforms | Evidence |
|---|---|---|
| Tenant rule with the types the organization uses | **yes** | `Feature`, `Task`, `Bug`, with identifiers checked against the API |
| `Priority` **not** mapped to `importance` | **yes** | `tenant_rules_test.exs` — mapping `importance`, **8 of 9 pass**, and the message names the antipattern |
| Every field and type carries an identifier | **yes** | two tests, and the symmetry: a type **in use** requires an identifier, an **absent** type cannot have one, because it would be invented |
| Queries accepted by the real API | **yes** | all three — repositories, issues, issue types — returned data from GitHub |
| Raw payload preserved | **yes** | 4833 issue payloads and 163 repository payloads, with `mapping_id` and `mapping_version` |

**Derived phase**: `sro.accepted_deliverable`.

---

## D03 — Observed repository (F2, US4 partial) {#d03--repositório-observado-f2-us4-parcial}

**Produced by**: T007 to T012

| Criterion | Conforms | Evidence |
|---|---|---|
| FR-001 — discovered from the organization | **yes** | 135 repositories, none connected individually |
| FR-002a — own table with what git provides | **yes** | `name`, `qualified_name`, `url`, `primary_language`, `default_branch`, `archived_at`, `last_pushed_at`. On screen: `Makefile`, `Astro`, `Vue`, `Elixir` |
| FR-003 — archived is a fact of the source, not absence | **yes** | `archived_at` and `no_longer_observed_at` are distinct columns, with the reason in the `@moduledoc` |
| FR-004, FR-005 — exclusion by the tenant, with author | **yes** | `check_constraint` refuses exclusion without an author; the collection does not query the excluded one and does **not** mark its issues |
| FR-006 — inaccessible does not mark absence | **yes** | `mark_inaccessible/3` records the reason on the tool; no issue gets a mark |
| Reversible migrations, none removes a column | **yes** | round trip on all three; 22 migrations in total |

**Derived phase**: `sro.accepted_deliverable`.

---

## D04 — Issues, promotion, refusal and screen (F3, US1) {#d04--issues-promoção-recusa-e-tela-f3-us1}

**Produced by**: T013 to T029
**Materializes**: US1 — Know which issues exist, and what they are (atomic, P0)

### Acceptance scenarios {#cenários-de-aceitação}

| Scenario | Conforms | Evidence |
|---|---|---|
| 1 — repositories registered with the organization | **yes** | 135, with `organization_id` |
| 2 — `Bug` becomes a defect, with the rule recorded | **yes** | 183 defects; `rule_id` and `rule_version` on every promotion |
| 3 — `Feature` without sub-issues becomes atomic | **yes** | `routing_test.exs` |
| 4 — `Feature` with parts that are user stories becomes an epic | **yes** | 23 epics; `#1`, `#79`, `#98` in our own organization |
| 5 — `Epic` without parts becomes atomic, with a divergence | **yes** | `routing_test.exs`, and the message cites `sro.rule05` |
| 6 — **parts that are tasks do NOT make it an epic** | **yes** | `#3` with nine `Task` sub-issues → `:atomic_user_story`. It is the test that cannot pass by accident |
| 7 — unknown type does not promote, and keeps the name | **yes** | on screen: `Chore (17), Refactor (16), Hotfix (4)` |
| 8 — the screen shows total, promoted, gaps and divergences | **yes** | 4455 = 1015 + 3440 |

### Non-functional criteria {#critérios-não-funcionais}

| Criterion | Conforms | Evidence |
|---|---|---|
| SC-001 — the sum closes | **yes** | 1015 + 3440 = 4455, and the screen shows the deviation in red if it does not close |
| SC-002 — idempotence | **yes** | second collection: 4455 issues, no duplicates; 4455 promotions in force over 5022 in the history |
| SC-003 — absence scoped by repository | **yes** | **0 issues marked** after collecting 135 repositories in sequence. With scope by tenant, 134 would be marked |
| SC-004 — 100% with rule and version | **yes** | `rule_version` is `NOT NULL` in the database |
| SC-005 — unknown type not promoted | **yes** | 37 counted in the gap, none with `derived_concept` |
| SC-006 — no epic without parts | **yes** | derived from `classification/2`, a single path |
| SC-007 — cycle refused with the path | **yes** | `decomposition_test.exs`; 4 links refused in the real data, all `out_of_scope` |
| SC-010 — empty distinguishable from not collected | **yes** | `.github` appears as **observed with 0 issues**, distinct from not collected |
| SC-011 — resuming does not recollect | **yes** | checkpoint per repository |
| SC-012 — isolation between tenants | **yes** | `isolation_test.exs`, three assertions with counter-proof |

**Derived phase**: `sro.accepted_deliverable`.
**Task phase**: `sro.successfully_performed_scrum_development_task`.

---

## Two defects found in the assessment, and fixed before this record {#dois-defeitos-encontrados-na-avaliação-e-corrigidos-antes-deste-registro}

Walking through the criteria against the **real data** — and not against the suite — found two defects
that no test caught.

**The client's envelope.** `Client.graphql/4` returns `{:ok, %{data: ...}}`, and I matched
`{:ok, data}`. The job **completed successfully and collected zero**: no error, no payload.
The plausible explanation was "the organization has no repositories". It became
[L26](../licoes-aprendidas.md).

**The number as a key.** I linked the parts to the parent by `number`, which is unique **within** the
repository. With 135 repositories, parts of one were linked to the parent of another. The screen
showed **2 epics** where there were 3. It became [L25](../licoes-aprendidas.md).

Both belong to the same family as L22 and L23: **silent success**. In neither was there an error —
there was an absence of result read as a result.

---

## Criteria changed during the sprint {#critérios-alterados-durante-o-sprint}

None of the 59 requirements of the original spec. **15 were added**, by decision of the
maintainer during execution:

| Decision | Requirements |
|---|---|
| mapping per organization, configured when defining the tool | FR-041 to FR-041c, FR-049 |
| repository with a table and git attributes | FR-002a |
| identifier on every mapped entity | FR-027, FR-027a |
| uniqueness scoped by type | FR-008a, SC-016 |
| a board is planning, not a project | FR-020, FR-020a |
| syncing brings everything | — design change, no new requirement |

An addition during the sprint is recorded, not silenced. None of them invalidated a criterion already
assessed.

## Criteria without evidence {#critérios-sem-evidência}

None of those assessed. **Those of F4, F5 and F6 were not assessed because they did not enter the
sprint** — boards, iterations, backlogs and the mapping screen. They are in the product backlog.

## Sprint deliverable {#entregável-do-sprint}

`sro.sprint_deliverable_composed_of_accepted_deliverable` admits only accepted
deliverables. With D01 to D04 derived as accepted, the deliverable of sprint 004 is composed of the
four — **subject to confirmation by whoever performs the role**, which is a human act and does not
follow from this assessment.

## Note on the independent review {#nota-sobre-a-revisão-independente}

Still **blocked by tooling**: with one identity in the repository, the author does not approve
their own PR. Declared, never marked as fulfilled.
