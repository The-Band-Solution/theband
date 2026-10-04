# Sprint Review 002 — Scope by organization {#sprint-review-002--escopo-por-organização}

**Period**: 2026-08-10 to 2026-08-16 (weekly cadence)
**Closed on**: 2026-08-10
**Backlog**: [sprint-backlog.md](sprint-backlog.md)

Separates what was delivered from what was not. Nothing here is marked as done without
evidence — command output, a number checked against the source, or a rendered screen.

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | **1** — US1 |
| Phases | 8 | 6 — F0, F1, F2, F3, F7, F8 |
| Tasks from `tasks.md` | 27 | **20** |
| Tests | — | 81 → **129** |

**The MVP declared in the backlog was F1, F2, F3, US1 and F7. All five shipped.** US2 and US3
did not, and they are in the section on what was not done.

## Outcome per user story {#resultado-por-user-story}

| # | User story | Deliverable | State |
|---|---|---|---|
| US1 | Know which organization each record came from | D01 — organization on each person and team, in the queries and on the screens | **accepted** on 2026-08-10, with two caveats |
| US2 | Query one organization at a time | — | **not done**; the filter by organization exists in the queries, the selection screen does not |
| US3 | See who crosses organizations | — | **not done**; the query answers, the signaling on the screen does not |

The column is **derived** from the [acceptance record](aceitacao.md), never filled in
directly: a sprint review without an acceptance record is an assertion without proof.

**Sprint deliverable**: composed of **D01**. The two caveats accompany the acceptance
and do not dilute it — slug collision guaranteed by the model and not observed in data, and
emptying of the derived team covered by a test and not by an occurrence.

**No task was performed unsuccessfully.** The four whose definition was wrong
had their *definition* corrected, not their deliverable refused, and the distinction is what the
rework measure computes.

## Evidence, check by check {#evidência-verificação-por-verificação}

Run against the development database with the three real organizations.

### V1 — the derivation now produces the column {#v1--a-derivação-passa-a-produzir-a-coluna}

Regression over the 11 ontologies, with a baseline rebuilt from `HEAD` plus the
determinism fix and nothing else:

```text
ontologias que mudaram com a regra nova:
  MUDOU: eo    ← só ela

diff de EO:
+ │    organization_id        uuid      NULL      → FK (association)
+ │    check: organization_id IS NOT NULL OR type <> 'organizational_team'
+ eo.organizational_team_belongs_to_organization: associação →
    eo_teams.organization_id anulável, obrigatória quando type='organizational_team'
```

### V2 — the schema matches the derived model {#v2--o-esquema-corresponde-ao-modelo-derivado}

```text
eo_teams.organization_id:              [["organization_id", "YES"]]   nullable
check:                                 eo_teams_organizational_team_has_organization
eo_people.organization_id existe?      0                              removida
```

And the constraint refuses what it should refuse:

```text
insert type='organizational_team' sem organization_id  → ERROR 23514 check_violation
insert type='project_team'        sem organization_id  → INSERT 0 1
```

### V3 — retrofit without querying the source {#v3--retrofito-sem-consultar-a-origem}

```text
equipes sem organização ANTES:  10
atribuídas:                     10
sem resolver:                    0
DEPOIS:                          0

leds-conectafapes: 8 · The-Band-Solution: 2
```

Zero calls to GitHub, and the guarantee is not by inspection: the five tests run
**with no expectation on the HTTP-edge Mox**, so any call brings them down.

### V4 and V5 — the derived team, never passing as observed {#v4-e-v5--a-equipe-derivada-e-nunca-passando-por-observada}

**All three cases of the rule occurred in real data**, which is different from being
covered by a fixture:

```text
The-Band-Solution    6 membros, todos em times   → nenhuma derivada (FR-007)
ifesserra-lab        5 membros, 0 times          → derivada com 5
leds-conectafapes   64 membros, 15 fora          → derivada com 15
```

And the provenance of each derived team:

```text
LEDS - ConectaFapes   source_system=the_band  derived:default_team:O_kgDOCqjXpg
  níveis de acesso dos 15 vínculos: [nil]

ifesserra-lab         source_system=the_band  derived:default_team:O_kgDODw6Ftw
  níveis de acesso dos 5 vínculos:  [nil]
```

`[nil]` is the result, not an omission: the source does not know these team memberships, so it
does not report a level. Recording `MEMBER` would make "observed as a regular member" and "the source
does not know about this team membership" indistinguishable.

### V6 — the counts that do not add up, and are right {#v6--as-contagens-que-não-fecham-e-estão-certas}

```text
leds-conectafapes  64
The-Band-Solution   6
ifesserra-lab       5
total de pessoas   72 · soma por organização  75
```

The sum is **greater** than the total, and that is correct: three people cross
organizations. The screen carries the note that explains this, because without it the first person to
add it up concludes there is a defect.

### V7 — filter by organization {#v7--filtrar-por-organização}

```text
ifesserra-lab: 5 pessoas, 1 equipe
```

The filter exists in the queries (`opts[:organization_id]`), and it is what US2 would use. **The
selection screen was not built** — see what was not delivered.

### V8 — who crosses organizations {#v8--quem-atravessa-organizações}

```text
2 pessoas em mais de uma organização
  EduardoNFraiz: leds-conectafapes, The-Band-Solution
  Paulo:         leds-conectafapes, The-Band-Solution, ifesserra-lab
```

The query answers. **The signaling on the people screen exists** — the "in N
organizations" badge — but the dedicated US3 screen was not built.

### V9 — no person is left without an organization {#v9--nenhuma-pessoa-fica-sem-organização}

**It is the proof that the path became complete, and the MVP's criterion SC-003a.**

```text
ANTES da derivação:  18 pessoas sem organização alcançável
DEPOIS:               0
```

### V10 — isolation between client organizations {#v10--isolamento-entre-organizações-clientes}

```text
tenant novo vê: 0 pessoas, 0 equipes, 0 organizações
```

## Quality gates {#quality-gates}

| Gate | Outcome |
|---|---|
| `mix format --check-formatted` | passed |
| `mix compile --warnings-as-errors` | passed |
| `mix credo --strict` | passed — `found no issues` |
| `mix dialyzer` | passed — `done (passed successfully)` |
| `mix test` | passed — **129 tests** (there were 81) |
| `mix knowledge.validate` | passed |
| `mix knowledge.graph` | passed — 24 modules |
| `scripts/validate_knowledge_base.py` | passed — 86 artifacts |
| **reproducible derivation** (new gate) | passed — 4 ontologies, two identical runs |

## What was **not** delivered {#o-que-não-foi-entregue}

Declared explicitly. None of these is marked as done anywhere.

| Item | Tasks | Why |
|---|---|---|
| **US2 — query one organization at a time** | T013 to T017 | The filter by organization exists in the queries and is tested; the screen is missing: a selector with a count per organization, and the distinction between empty state and empty filter. Outside the MVP declared in the backlog |
| **US3 — see who crosses organizations** | T018, T019 | The query answers and the people screen already signals "in N organizations"; the dedicated screen and the contract's `list_people_in_several_organizations/2` are missing |
| **The derived-team constraint in the database** | — | The two invariants of T022 are application-level, not a `check_constraint`. Declaring the `derived:` pattern in SQL would require a constraint on the identifier's format, and that would set the pattern in stone in the schema. Declared debt, not oversight |
| **Real occurrence of the derived team being emptied** | T023 | Covered by two tests. It would require a person to join a real GitHub team between two collections — same class of limitation as "absence is not removal" in sprint 001 |
| **Independent review** | — | See the next section |

## The independent review, now possible {#a-revisão-independente-agora-possível}

It was **impossible** in this repository until 2026-08-10: a single collaborator, who is the author
of every PR, and no team with access. It was treated as a scheduling matter for a whole
sprint, and it was a permission matter — lesson
[L15](../licoes-aprendidas.md).

Unblocked with two API calls: `pull` granted to the `the-band` team, and the review
request made **to the team** instead of to a person. Requesting from the team is what produces the
independence: the request stays open to any member, and the author, being a member, cannot
fulfill it.

**The residue cannot be recovered**: PRs #89, #90 and #91 were merged without a recorded
approval. The code of feature 001 is on `main` without ever having gone through a recorded
review, and sprint 001's `aceitacao.md` keeps saying so.

## Defects found during the sprint {#defeitos-encontrados-durante-o-sprint}

All fixed. The first three only showed up because something was **run**, not
implemented.

| Defect | Where it showed up | Fix |
|---|---|---|
| **The derivation was not a function of the ontology** | the mandatory regression of T004 flagged 10 of the 11 ontologies as changed, and none had changed | `sorted` in four places; reproducibility gate in CI; [L17](../licoes-aprendidas.md) |
| **The derived team took in the whole tenant** | V9 on the real database: `ifesserra-lab`, with 5 members, received 72 people | "from an organization" came to mean **observed member**, read from the preserved payload |
| **My association rule generated a self-reference** | `eo_people.person_id`, from `eo.team_member_is_person` | a role materializes through a relator (ADR 0004 D5/D6), never through a column; two guards |
| **CI red because of an unregistered secret** | the PR ran the pipeline for the first time | a secret that is referenced and absent arrives as an empty string; [L13](../licoes-aprendidas.md) |
| **`gh` swallows the refused review request** | `--reviewer` exited with code zero and assigned nobody | mandatory check of `reviewRequests`; [L14](../licoes-aprendidas.md) |
| **`collect_team_members` went through every team in the tenant** | showed up when introducing the derived team, which has no members at the source | scoped to the collection's organization and to the observed teams |

## Tasks whose definition was wrong {#tarefas-cuja-definição-estava-errada}

Four, corrected in place instead of worked around. Each correction is written in the
task itself, in `tasks.md`.

| Task | What it said | What it was |
|---|---|---|
| T001 | check the relation in the output of `mix knowledge.graph` | the task prints **one line** about dependencies and never lists relations — unverifiable |
| T003 | "the current base keeps passing" | it did not: **12 unbacked links**, not one |
| T007 | create the column and the `check_constraint` together | impossible on a populated database; the constraint became its own migration, **after** the retrofit |
| T020 | the team mapping references the rule | `derivation.rule_id` there would mark **every observed team** as derived |

## Debt generated {#dívida-gerada}

| What | Why it was accepted |
|---|---|
| **Three backings for a mapping link**, and one of them is a declared limitation | Decision of the maintainer. The F6 check revealed 10 unbacked links outside the scope, in 5 ontologies the analysis excluded. Closing it for real requires declaring 10 relations, and that is a feature of its own |
| **`provenance` on a relation and `note` on the mapping's `relations`** | Two new fields in the knowledge base schema. Both with a reason written in the schema itself, and neither invents a concept |
| **The derived team's two invariants are application-level** | No corresponding `check_constraint`. A write path that does not go through the changeset can record a malformed derived team |
| **Elixir/Python parity remains open** | The Elixir validator has 4 checks, the Python one now has 12. The Python gate is the one that decides, and it runs in CI |

## Lessons from this sprint {#lições-deste-sprint}

Five went into the accumulated record: L13, L14, L15, L16 and L17. The three most costly
have the same shape — **the configuration looked right and the effect did not exist**, and only
running it revealed that.
