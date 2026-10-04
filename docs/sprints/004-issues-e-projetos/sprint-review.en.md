# Sprint Review 004 — Issues and projects of the observed organizations {#sprint-review-004--issues-e-projetos-das-organizações-observadas}

**Period**: 2026-08-11 · **Closed on**: 2026-08-11
**Backlog**: [sprint-backlog.md](sprint-backlog.md) · **Acceptance**: [aceitacao.md](aceitacao.md)

Separates what was delivered from what was not. Nothing marked as done without evidence.

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| Phases | F0 to F3 (MVP) | **4** |
| Tasks | 29 | 29 |
| Tests | 177 → | **218** |
| New lessons | — | 2 — L25 and L26 |
| Requirements added during the sprint | — | 15 |

## What was done {#o-que-foi-feito}

### F0 — The referenced kind, in one concept {#f0--o-kind-referenciado-em-um-conceito}

`sys_swo.loaded_software_system_copy` got `ontouml_stereotype: kind`. **One** concept,
not eleven — the boundary rule of constitution IX reduced the requirement, and the other 10 of
SysSwO remain without a stereotype on purpose.

Five tests lock the declaration, and I proved they fail in both directions: switching
`source_repository` to `kind`, 4 of 5 pass; removing the kind's stereotype, 3 of 5.

### F1 — Semantics declared before the code {#f1--semântica-declarada-antes-do-código}

Tenant rule with the three types the organization uses, with identifiers checked
against the API. Nine tests, and two of them about the violation: mapping `Priority` to `importance`
fails naming the antipattern.

### F2 — Observed repository {#f2--repositório-observado}

135 repositories discovered from the organizations, none connected individually.
Own table with what **any Git hosting** provides — and three things left
out with the reason: `is_fork` (it is a relation, not a property), the list of languages (would require
its own concept), license and size on disk.

### F3 — Issues, promotion, refusal and screen {#f3--issues-promoção-recusa-e-tela}

4455 issues, 4455 promotions in force, 1614 decomposition links. The `/trabalho` screen
live, with menu, pagination, organization and repository.

**The test that matters passes**: issue `#3`, with nine sub-issues of type `Task`, is
**atomic**. A task serves, it does not compose.

### Design changes decided during the sprint {#mudanças-de-desenho-decididas-durante-o-sprint}

| Decision | What changed |
|---|---|
| **syncing brings everything** | the separate worker became a phase of the same sync; one record, one report |
| **mapping per organization** | scope moved from tenant to connected tool, configured when defining it |
| **repository becomes a table** | attributes declared in the ontology, and that is what makes the extension exist |
| **identifier on everything** | `source_external_id` mandatory; an issue type **has** an id, contrary to what I had written |
| **uniqueness scoped by type** | the same identifier can designate different artifacts |
| **a board is planning** | Projects v2 is not promoted to a project |

## Evidence {#evidência}

### The real data, in the development database {#o-dado-real-no-banco-de-desenvolvimento}

```text
135 repositórios observados       4455 issues coletadas
4455 promoções vigentes           5022 no histórico (append-only)
1614 vínculos                        4 recusados (todos out_of_scope)
4833 payloads de issue             163 payloads de repositório
   0 issues marcadas como ausentes
```

Checked against the API: `The-Band-Solution` has 14 repositories and 189 issues. The platform
collected **14 and 189**.

### The screen, live {#a-tela-no-ar}

```text
Trabalho
4455 issues coletadas · 135 repositórios observados

  PROMOVIDAS         1015     NÃO PROMOVIDAS       3440     DIVERGÊNCIAS   23
    épico              23       sem tipo na origem 3403
    user story atóm.  699       tipo desconhecido    37
    tarefa pretend.   110         Chore (17), Refactor (16), Hotfix (4)
    defeito           183

  organização        repositório        #   tipo    partes  promovida a
  leds-conectafapes  agentes-planning   2   Bug          0  defeito
  leds-conectafapes  agentes-planning   3   Chore        0  tipo desconhecido: Chore
  1–50 de 4455       página 1 de 90
```

### Gates {#gates}

Nine green, by `mix gates`, checked by exit code — not by reading the output.

| Gate | Result |
|---|---|
| format, compile, credo, dialyzer | passed |
| tests | **218** |
| knowledge.validate, knowledge.graph | passed |
| Python validator | passed, **with the form validation** |
| reproducible derivation | passed on all four ontologies |

## What was **not** done {#o-que-não-foi-feito}

| Item | Why |
|---|---|
| **F4 — boards, fields and iterations** | outside the declared MVP. A sprint without issues answers nothing, and the dependency runs in this direction |
| **F5 — boards screen** | same |
| **F6 — mapping screen** | stayed out, and the gap it addresses **grew**: 3440 issues without a concept. It became feature 005, already specified |
| **Sync counters** | `records_collected` counts only the EO phase. The screen shows "0 collected" next to "4266 issues in this collection" — declared contradiction, fix pending |
| **Iteration in Projects v2** | does not exist for sprints 003 and 004. Creating it touches the configuration that caused L11 |
| **Repair of the L19 data** | happens on the next real collection of each organization |

## Two defects found in the real data, and no test caught them {#dois-defeitos-encontrados-no-dado-real-e-nenhum-teste-os-pegava}

**The client's envelope (L26).** `Client.graphql/4` returns `{:ok, %{data: ...}}` and I matched
`{:ok, data}`. The job **completed successfully and collected zero** — no error, no payload,
and the plausible explanation was "the organization has no repositories".

**The number as a key (L25).** I linked the parts to the parent by `number`, which is unique **within**
the repository. With 135 repositories, parts of one were linked to the parent of another, and the screen
showed **2 epics** where there were 3.

**Both belong to the same family as L22 and L23: silent success.** In neither was there an error —
there was an absence of result read as a result. And both only showed up because someone looked at
a number that did not match the source.

## Debt generated and kept {#dívida-gerada-e-mantida}

| What | Status |
|---|---|
| `connected_tools.status` materializes a situation | **kept**, against D7. Not expanded: this feature did **not** create `sro_user_stories.status`, and the migration says so in full |
| Incomplete `sync` counters | **generated in this sprint**. The work phase does not add to `records_collected` |
| RSRO and SYS_SWO without a stereotype | 15 concepts remaining. It was 16; the boundary rule required **one** |
| Elixir/Python parity | kept: 4 checks against 12 |
| `refused_links` as a forecast | 4 rows in the real data, all `out_of_scope`. **None by cycle** — the plan's forecast remains unconfirmed, and the reversal criterion is still in force |
| Recorded review approval | blocked by tooling |

## Lessons from this sprint {#lições-deste-sprint}

**L25** — an issue number does not identify: it is unique within the repository. The table already
carried the rule in the unique index, and I wrote another key next to it.

**L26** — matching the wrong envelope returns an empty list instead of an error. Broad pattern
matching hides a change of shape.

And an observation that runs across both, and the two from the previous sprint: **four lessons
in a row about silent success.** L22 (a gate that compares two identical failures), L23 (a
skipped-verification warning), L25 (a key colliding silently), L26 (a job that completes without doing anything).

The pattern is always the same: **the absence of an error being read as the presence of a result.** And
what found all of them was checking a number against the source, not running the suite.
