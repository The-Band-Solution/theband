# Sprint Review 001 — Foundation and EO collection {#sprint-review-001--fundação-e-coleta-eo}

**Closed on**: 2026-08-09
**Backlog**: [sprint-backlog.md](sprint-backlog.md)

Separates what was delivered from what was not. Nothing here is marked as done without
evidence — command output, a number checked against the source, or a
rendered screen.

## Outcome per user story {#resultado-por-user-story}

The `Accepted` column is **derived** from the [acceptance record](aceitacao.md), never
filled in directly. A review without an acceptance record is a claim without proof.

| # | User story | Deliverable | Accepted | Where |
|---|---|---|---|---|
| US1 | Connect a tool with a protected credential | D01 | **yes**, on re-evaluation | [aceitacao.md](aceitacao.md) — not accepted in the first evaluation due to failing AC4; fixed by [#88](https://github.com/The-Band-Solution/theband/issues/88) |
| US2 | Know people and teams | D02 | yes | [aceitacao.md](aceitacao.md) — with two recorded caveats |
| US3 | Trace where each piece of information came from | D03 | yes | [aceitacao.md](aceitacao.md) |

**Sprint deliverable**: composed of D01, D02 and D03 — after the fix. In the
first evaluation it was composed only of D02 and D03, and the record keeps both
moments: a sprint that needed a fix to become complete is different from one
born complete.

**Tasks performed without success**: T033 and T038. They stay that way — they were
performed and did not produce an accepted deliverable, and that is what the measure
`rework.not_accepted_deliverable_ratio` computes. #88 is a new task, not a
reopening.

## Evidence of the real collection {#evidência-da-coleta-real}

Run against the `The-Band-Solution` organization through the same path the screen
triggers — `Ingestion.start_sync/2` enqueues, Oban executes.

```text
--- relatório da sincronização (FR-028) ---
  estado          completed
  coletados       16
  criados         9          (1 organização + 6 pessoas + 2 equipes)
  atualizados     0
  ignorados       0
  pendentes papel 7

--- checkpoints (FR-015, R5) ---
  github.organization           páginas=1 registros=1 cursor=nil
  github.team                   páginas=1 registros=2 cursor=nil
  github.team_member:the-band   páginas=1 registros=3 cursor=nil
  github.team_member:zeppelin   páginas=1 registros=4 cursor=nil
  github.user                   páginas=1 registros=6 cursor=nil

--- equipes e integrantes ---
  The Band (organizational_team) — 3 integrantes
      Adylla027       acesso=MEMBER      papel=pendente
      EduardoNFraiz   acesso=MEMBER      papel=pendente
      Paulo           acesso=MAINTAINER  papel=pendente
  Zeppelin (organizational_team) — 4 integrantes
      Felipe Becalli T.  acesso=MEMBER      papel=pendente
      Luma               acesso=MEMBER      papel=pendente
      Paulo              acesso=MAINTAINER  papel=pendente
      Sofia              acesso=MEMBER      papel=pendente
```

## Success criteria, one by one {#critérios-de-sucesso-um-a-um}

| # | Criterion | Status | Evidence |
|---|---|---|---|
| SC-001 | Connect and validate in under 2 minutes, without documentation | **met** | a single-screen form, with immediate validation and a message saying what was missing |
| SC-002 | 100% of the source's people and teams registered | **met** | 6 people and 2 teams, checked against the real organization |
| SC-003 | Second sync creates 0 and alters 0 | **met** | second run: `criados 0`, `atualizados 0`, counts unchanged |
| SC-004 | 100% of records show source, identifier and date | **met** | columns present in `/pessoas` and `/equipes` for every row |
| SC-005 | Credential not recoverable in usable form | **met** | token absent from the HTML of the 4 screens; the database returns `AES.GCM.V1$…`; `inspect/1` redacted |
| SC-006 | Resuming queries at most one extra page | **met** | resume test: with a checkpoint stored, the next run asks for the **next** page (`after: cursor-1`), not the first |
| SC-007 | A mapping fix applied without querying the source | **met** | `SemanticIntegration.reprocess_mappings/2` over 32 preserved payloads: 0 created, 0 updated, 32 unchanged. The test runs **with no expectation on the HTTP-edge Mox**, so any call to the source brings it down |
| SC-008 | A user of one organization does not see another's data | **met** | two populated tenants; a session of `outra-org` shows 0 people and 0 teams |
| SC-009 | An organization with 100 people and 20 teams completes without intervention | **partial** | behavior under rate limit is tested with a simulated window: the collection returns `{:snooze, n}`, preserves the cursor and does **not** fail. The volume of 100 people was not exercised — the available organization has 6 |
| SC-010 | Team memberships pending a role presented explicitly | **met** | `7` in the sync report and in the header of `/equipes` |

## Quality gates {#quality-gates}

| Gate | Result |
|---|---|
| `mix format --check-formatted` | passed |
| `mix compile --warnings-as-errors` | passed |
| `mix credo --strict` | passed — `found no issues` |
| `mix dialyzer` | passed — `Total errors: 0` |
| `mix test` | passed — **81 tests** |
| `mix knowledge.validate` | passed — 84 artifacts |
| `mix knowledge.graph` | passed — 24 modules, dependencies intact |
| `scripts/validate_knowledge_base.py` | passed — knowledge base valid |

## What was **not** delivered {#o-que-não-foi-entregue}

Declared explicitly. None of these is marked as done anywhere.

| Item | Tasks | Why |
|---|---|---|
| **Password authentication** | — | The session is opened by choosing a user, without a password. What is implemented is the **per-tenant scope**, which crosses every query and is tested with two tenants walking through the interface. Authentication is its own feature, and was not silently folded into this one |
| **SC-009 volume** | — | Behavior under rate limit is tested; the volume of 100 people and 20 teams would require an organization we do not have |
| **`mix knowledge.test`, `knowledge.docs`, `knowledge.information_model`** | — | They remain Python scripts, called by CI. Debt declared in plan.md |
| **`Estimate` on the issues** | — | No estimate was made with the team. Filling it with an invented number would produce a flow metric resting on fiction |
| **Independent PR review** | T073 | The constitution requires a reviewer different from whoever implemented. **This condition was not satisfied** and cannot be marked as fulfilled by whoever wrote the code. The PR was opened in sprint 002, which makes the review possible — it does not replace it |
| **Real occurrence of three checks** | — | Automation classified, pause due to the usage limit, and absence-is-not-removal are proven by test, not by occurrence. The last would require removing someone from a real team in the maintainer's organization, and that should not be done to validate software |

## Fix after `/speckit-analyze` {#correção-após-o-speckit-analyze}

The `/speckit-analyze` run at the end of the sprint found two CRITICAL and two HIGH.
Three were fixed still within this sprint; the fourth is procedural and remains
open.

| Finding | What it was | Resolution |
|---|---|---|
| **G1** — FR-017 without an implementation task | only the test existed (T060); `RawData.list_for_reprocessing/2` had no caller | contract [reprocessing.md](../../../specs/001-github-eo-ingestion/contracts/reprocessing.md) written **before** the code, T060a–T060c added, `TheBand.SemanticIntegration` + Oban worker + button in `/sincronizacoes` implemented, 8 tests |
| **C1** — divergent signature | the contract asked for a list of ids; the code receives a `DateTime` | contract corrected: the platform does not receive a removal event, it perceives absence by comparing collections — the caller would have no way to know which team memberships disappeared |
| **C2** — divergent `opts` | the contract promised `:order_by`, absent from the code; `:only_observed` existed without being in the contract | contract corrected with a table per option, and `:order_by` removed: parameterizable ordering would reintroduce the divergence between `list_*` and `count_*` that the rule exists to prevent |
| **G2** — independent review | not satisfied | **remains open**; no deliverable can be accepted without it |

A third contract fix appeared during implementation: the
reprocessing contract promised `{:error, {:unknown_mapping, id}}` **and** said that a
broken mapping does not bring down the batch. It contradicted itself. The second
rule prevailed — bringing down the batch over one record would make the fix hostage to the worst
data in the database, the opposite of what FR-017 exists to allow.

**Practice that now holds**: the API contract is written before the first
public function, and corrected in the same commit when the implementation shows it
was wrong. Recorded in `AGENTS.md` §12 and in the constitution, principle VI, by amendment
1.1.0.

## Second round of fixes {#segunda-rodada-de-correções}

After `/speckit-analyze`, the remaining pending items were closed.

| Item | Resolution |
|---|---|
| Master key rotation (FR-005b) | contract [credential-rotation.md](../../../specs/001-github-eo-ingestion/contracts/credential-rotation.md) written first, and `mix the_band.rotate_key` implemented. Verified end to end: the label of the encrypted value changed from one key label to another [redigido], secret intact with the new key |
| Resume test (SC-006) | with a checkpoint stored, the run asks for `after: cursor-1` — the next page, not the first |
| Rate limit test (SC-009) | a tight simulated window returns `{:snooze, n}`, preserves the cursor, does not fail |
| Interface tests | 9 LiveView tests, including the three that are **not** doable by unit test: secret absent from the HTML, isolation walking through the interface, and header agreeing with the listing |
| Knowledge base and the `email` field | the mapping declared an attribute the query had stopped requesting. It is now recorded as a limitation, with the reason — the field would require the `read:user` scope, broader than the collection needs |
| Wording of T005 and T019 | the tasks promised more than was delivered; corrected to describe what they actually cover |

### A serious defect found while testing the rotation {#um-defeito-sério-encontrado-ao-testar-a-rotação}

The rotation **did not work**, and would have failed silently. The two ciphers — the one for
the new key and the one for the old — used fixed labels, and Cloak chooses which key to use
by the label stored at the start of the encrypted value. With labels that did not identify
the key, it chose by configuration order and used the wrong one.

The symptom would be "I cannot decrypt this credential", without saying why, and only
at the moment of using it — in the middle of a collection.

The fix derives the label from **the key itself**, via eight characters of SHA-256:
each encrypted value now carries which key encrypted it, the two coexist without
ambiguity during the rotation, and after it new records already point to the
new one. Covered by `test/the_band/vault_test.exs`.

This only showed up because the rotation was **executed**, not just implemented.

## Defects found during the sprint {#defeitos-encontrados-durante-o-sprint}

All fixed, and each one became a lesson.

| Defect | Where it appeared | Fix |
|---|---|---|
| Generator overwrote `AGENTS.md` | `mix phx.new` in a populated directory | restored from git; became [L01](../licoes-aprendidas.md) |
| Collection run twice | script calling `perform/1` with the server up | script switched to the real path; [L02](../licoes-aprendidas.md) |
| Missing provenance brought down the query | `find_by_application_reference/3` comparing against `nil` | validation before the query; [L03](../licoes-aprendidas.md) |
| `INSUFFICIENT_SCOPES` due to an optional field | `email` in the GraphQL queries requires `read:user` | field removed; [L04](../licoes-aprendidas.md) |
| Real error swapped for a database error | `syncs.error_reason` as `varchar(255)` | column became `text`; [L05](../licoes-aprendidas.md) |
| Files written to the wrong directory | `cd` persisting between commands | absolute paths; [L06](../licoes-aprendidas.md) |
| Struct returned without `id` | `autogenerate: false` on a `binary_id` key | `autogenerate: true`; [L07](../licoes-aprendidas.md) |
| Validator rejected every mapping | provenance has two shapes in the knowledge base, and the code knew only one | `provenance_problems/1` per artifact type |
| Pre-existing YAML bug | `flow_wip_count.yaml` with an unquoted `: ` became a map | item quoted |

## Divergences between artifacts, resolved {#divergências-entre-artefatos-resolvidas}

| # | Divergence | Resolution |
|---|---|---|
| D-1 | research.md R7 called the table `eo_observed_team_links`; the knowledge base rule declares `team_membership_evidence` | the knowledge base prevailed: `eo_team_membership_evidence` |
| D-2 | R7 adds columns the rule does not name | the two add up; the evidence keeps internal keys **and** external identifiers |
| — | research.md R1 pinned PostgreSQL 16; the environment runs 17 | `compose.yaml` aligned to 17, with the reason written in the file itself |
| — | spec uses P1/P2/P3; the project offers P0/P1/P2 | order preserved, label remapped, recorded in the backlog |

## State of the issues {#estado-das-issues}

Updated on 2026-08-10, after the [acceptance record](aceitacao.md).

| Situation | Issues |
|---|---|
| closed, with accepted deliverable | #1 to #76 and #88 — 75 in total |
| closed as `not planned` | #2 — orphan duplicate of US1, created by a run of the materialization script that failed after the issue already existed |
| closed with declared limitation | #77 — quickstart evidence; V3, V4 and V8 proven by test and not by real occurrence |
| completed in sprint 002 | #78 — opening of the pull request, T073. [PR #89](https://github.com/The-Band-Solution/theband/pull/89). See the [inheritance](../002-escopo-por-organizacao/sprint-backlog.md) |

**Closing the issues does not replace independent review.** They are different
questions: the issue closes when the task was performed and the deliverable accepted; the
review asks whether the code is correct, secure and compliant, and principle VII
requires that whoever answers is not whoever implemented. The pull request exists and the
review remains **pending** — nothing from 001 enters `main` before it.
