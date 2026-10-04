# Sprint 029 — Review {#sprint-029--review}

**Period**: 2026-09-02 to 2026-09-09 · closed on 2026-09-03
**Feature**: [058 — the measures missing from the team screen](../../../specs/058-medidas-da-equipe/spec.md)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 3 | 3 |
| Tasks | 21 | 20 |
| Suite | — | **1,704 tests, green** |
| `mix gates` | — | **exit code 0** · 14 gates |

The three user stories are complete. The task not delivered is the same as always,
and it is stated below without beating around the bush.

## What was done {#o-que-foi-feito}

| User story | Issue | Tasks | What reached the screen |
|---|---|---|---|
| US2 — who worked on this project, and when | [#766](https://github.com/The-Band-Solution/theband/issues/766) | T004–T007 | the per-project section, with the teams through which each person arrived and the mark for a partially unknown period |
| US1 — the time to first review | [#765](https://github.com/The-Band-Solution/theband/issues/765) | T008–T011 | the team median, the ongoing wait counted alongside, and the same measure per person |
| US3 — the pipeline rate | [#767](https://github.com/The-Band-Solution/theband/issues/767) | T012–T016 | the rate with the path and the sample size, or the refusal naming the missing link |

T001–T005 came from PR [#789](https://github.com/The-Band-Solution/theband/pull/789),
before v0.4.0. T006–T019 are from this work.

## Scenario 0 — data coverage, measured {#o-cenário-0--a-cobertura-do-dado-medida}

T020 exists because the research **could not** measure it: the application would not start
with `:missing_master_key`, and a rate over an unknown sample does not support a
decision.

Now it started. The key is in the `.env` of the development environment, and the numbers,
measured on 2026-09-03 against `the_band_dev`:

```sql
select 'collected_verifications='||(select count(*) from collected_verifications)
    ||' spo_project_teams='||(select count(*) from spo_project_teams)
    ||' spo_project_repositories='||(select count(*) from spo_project_repositories);
```

| table | rows |
|---|---:|
| `collected_verifications` | **0** |
| `spo_project_teams` | **0** |
| `spo_project_repositories` | **0** |
| `collected_change_requests` | **0** |
| `eo_team_memberships` | **0** |

**What these numbers meant, and what they did not.** The development database
was **empty** — 12 MB, schema only. The measurement was not of coverage:
it was of the absence of local data.

### The real measurement, with collected data {#a-medição-de-verdade-com-dado-coletado}

On 2026-09-04 the maintainer registered the credential and the collection ran against the
real organization **`leds-conectafapes`**. It took **seven attempts** until one ended in
`completed` — the first six died, and each death became a fix (see below).

The numbers from the complete collection:

| table | rows |
|---|---:|
| `eo_people` | **80** |
| `eo_teams` | **9** |
| `eo_team_membership_evidence` | **90** |
| **`eo_team_memberships`** | **0** |
| `observed_repositories` | **125** |
| `collected_issues` | **4,971** |
| `collected_change_requests` | **5,466** |
| `collected_artifact_evaluations` | **4,634** |
| `collected_verifications` | **5,311** |
| **`spo_project_teams`** | **0** |
| **`spo_project_repositories`** | **0** |

### The conclusion about US3, now with real data on both sides {#a-conclusão-sobre-a-us3-agora-com-dado-real-dos-dois-lados}

**The pipeline rate has a numerator and no path.** There are 5,311 verification runs
collected — the data that was missing in the first measurement. And there are **zero** team ↔
project links and **zero** project ↔ repository links.

The path that US3 declares is `repositório → projeto → equipe`, and it is cut at
both links. The delivery against real data is **exactly the refusal branch** — `{:sem_projeto,
_}`, with the missing link named on the screen.

It is what T020 predicted, and now it is a **measured** result: CI data was not missing; what is missing is the
declaration that links repository to project and project to team. No line of code
solves this — it is work for whoever administers the organization.

**Zero team memberships promoted, with 90 pieces of evidence waiting.** The platform observes the team membership
and requires human confirmation of the role. As long as nobody confirms, every measure at the
`team` level has no basis, and all nine teams trigger
`structure.ap02.team_with_no_members` — the antipattern declared in this sprint, holding
against real data at first contact.

### Verification coverage, and what I cannot explain {#a-cobertura-das-verificações-e-o-que-não-sei-explicar}

**23 of the 125 repositories** have `verifications_collected_at`, and only **16** have runs in the
database — the other 7 were traversed and have no CI.

The remaining 102 have **no** explanation in the collection summary: `unreachable: 0`,
`without_ci: 0`, `rate_limited: 0`. None of the reasons the code knows how to record
shows up.

**Investigated on 2026-09-05, and explained**: 98 of the 102 failed with `{:rate_limited, _}`
— quota, not a problem with the repository. The summary said `rate_limited: 0` because the
`:sem_janela` state existed in the counter and **nothing produced it** — the reactive rate limit fell into the
general branch and became `:inalcancavel`. Fixed in PR #806, with the stage getting the
first tests it ever had.

And the runs recorded **without jobs** — 418 of 6,168 — have the same cause, and only that one: the
586 *"jobs não coletados"* (jobs not collected) records in the log are all `{:rate_limited, _}`. They are not
expired jobs nor a collection defect. With the `snooze` fixed, the next collection waits for the
window and fills them in; the checkpoint blocked on those repositories is doing exactly
what L29 prescribes.

The real coverage of the pipeline rate is still **16 repositories with data, out of 125
observed** — and now with the cause of the difference named, instead of declared as
unknown.

### The 37 inaccessible ones disappeared {#os-37-inacessíveis-sumiram}

In the first collection, 37 repositories were marked with *"the tool refused the credential"*.
In the complete collection there are **zero** — the platform cleared the mark when it reached them. This confirms that
the mark is about the **moment**, and not about the repository, which is what
`clear_inaccessible/2` exists to do.

### The defect the real collection found {#o-defeito-que-a-coleta-real-encontrou}

The first run ended in `failed` **after** recording 69 people, 936 issues and
598 change requests: the upsert of the derived team queried the Application Reference and
inserted, and between the two another collection fit in — the second insert hit the unique
index. The team membership stage never ran, and the screen would show nine empty teams without
anything saying why.

Fixed and closed as [#800](https://github.com/The-Band-Solution/theband/issues/800):
the Application Reference conflict became **recognition**, and not an error. It took
running against a real source to find it — 1,704 green tests did not catch it.

## Evidence {#evidências}

| What | Measure |
|---|---|
| `mix gates` | **exit code 0** · 14 gates |
| full suite | **1,704 tests**, 187 s |
| code and tests added | **2,577 lines** in 14 files (937 in `lib/`) |
| new tests | **37** — 13 for the screen, 8 for the wait, 8 for the rate, 7 for isolation, 1 for the ceiling |
| new test files | 2 |
| screen query ceiling | 17 → **19**, and the three sections add up to **6** with a project |

## What the tests found, and the code did not say {#o-que-os-testes-encontraram-e-o-código-não-dizia}

Four defects were born and died within the sprint. They are recorded because the
lesson is in **how** they were found, not in that they existed:

1. **`list_team_projects/2` erased the past.** The US2 section used the listing
   of the association, which filters `is_nil(unlinked_at)`. The project the team left
   disappeared from the screen **together with everyone who worked on it** — against FR-008.
   Found by the closed-interval test, and fixed with
   `team_projects_ever/2`;

2. **a query on a table returns `NaiveDateTime`.** Without `type/2` in the select, the
   day count of the ongoing wait broke with `FunctionClauseError`. Failing
   like that is luck: a wrong number would have passed;

3. **the query ceiling did its job three times.** Each new section
   failed it, and each increase is written down with its reason. The third led to
   sharing the team membership list between two sections, instead of raising the number;

4. **Credo was right about the complexity.** The cut query, in a single
   `from`, went past 12. Breaking it into `abertas_por_quem_pertencia/2` and
   `com_primeira_revisao_humana/1` was not obedience to the gate: the cut by the opening
   date **is** the rule of the measure, and it read better on its own.

## The independent review, and what it found {#a-revisão-independente-e-o-que-ela-achou}

**PR #798 was merged on 2026-09-04 at 02:58 with `reviews: []`.** Asked
whether anyone had read it, the maintainer answered that **there is no way to know** — and
that is why the record says **review not recorded**, and not *attested without a record*.
`reviews: []` proves absence of a record, not absence of reading; asserting the latter
would be inventing.

It was the third recurrence of L95. What changed this time came **after** the merge:
three independent reviews by agent, and all three found things the gates do not
catch.

### Security review (OWASP) — 7 findings {#revisão-de-segurança-owasp--7-achados}

| # | Finding | State |
|---|---|---|
| 1 | `project_repositories_with_period_many/2` without a test of the tenant filter | fixed |
| 2 | three joins did not tie `tenant_id` across the tables | fixed |
| 3 | **two cases of the isolation test compared `[] == []`** | fixed |
| 4 | `:vinculos` and `:nome` — guarantee living in the caller | **options removed** |
| 5 | Sobelow **does not see `raw/1` inside `~H`** | new gate |
| 6 | individual reading without an access verdict | FR-024 |
| 7 | cut at 200 change requests, silently | the screen says it cut |

Finding 5 was **measured, not deduced**: XSS injected into a section that shows a title
coming from GitHub, and the scan came out clean with code 0; a defect that Sobelow recognizes
was injected next, and then it failed. *"Clean Sobelow"* in this codebase means
"no known pattern **outside the templates**", and the whole rendering surface
is LiveView.

Finding 3 is the most uncomfortable: **with the tenant filter removed, the whole suite
passed — 1,711 tests.** The file whose name claims to prove SC-010 did not prove it.

### QA review — 8 findings {#revisão-de-qa--8-achados}

The five tests that support the core of the feature **fail when the code is wrong**,
proven by injection. But four assertions in the screen suite celebrated what they did not
measure — also proven by injection:

- `assert secao =~ "interrupted"` matched the table **header**, and passed with
  "0.0%" on the screen — the very defect the test claims to prevent;
- `assert html =~ "start date"` had **three sources** on the page;
- `assert secao =~ "run(s) that"` measured the caption, not the number it qualifies;
- the permission `refute` passed with the admin guard removed: the fixture did not
  let the form render **for anyone**.

And the section ceiling was an **estimate** (6); measured, it was 3. An estimate leaves slack, and
slack is where a new query gets in without anyone seeing.

### Product Owner decision — FR-024 and FR-025 {#decisão-do-product-owner--fr-024-e-fr-025}

Finding 6 was not a new decision: **the question "who sees someone's work" was
answered on 2026-08-26** (spec 023, FR-012), and the team screen reinstated by
omission the revoked regime. SC-011, as written, **required the leak** — an
account with no relation at all is also "a person without permission to administer teams".
The criterion came back amended, with SC-012 alongside.

The one-person team was decided by the maintainer on the same day: **it is an
anomaly, and an anomaly is identified** — neither accepted risk, nor a minimum number of people, which
would be vocabulary the knowledge base does not have.

## What was not done {#o-que-não-foi-feito}

| Task | Issue | Reason | Destination |
|---|---|---|---|
| T021 (part) | [#788](https://github.com/The-Band-Solution/theband/issues/788) | gates green ✅, PR opened ✅, **human review not recorded** | a mechanism, not another record |

**It is the third time in a row**, and L98 describes the pattern: a lesson that does not become a rule
recurs. A lesson that recurs three times does not need another record — it needs
a mechanism.

What this sprint added as a mechanism, and not as a promise: independent review
**by agent**, with defect injection as proof, found 15 problems
that 1,711 green tests and 14 gates did not catch. It does not replace human reading of the
design; it covers the part that human reading also tends to miss.

## What remains open in epic [#504](https://github.com/The-Band-Solution/theband/issues/504) {#o-que-continua-aberto-no-épico-504}

After this sprint, the epic **does not close**, for two reasons that are not about
implementation:

1. **the dashboard questions did not come** — a decision for whoever maintains, declared as
   pending in the epic itself since 2026-08-25;
2. **`flow.throughput` and `flow.wip.count` depend on feature 042** (start
   criterion), specified, with 24 issues and no code.

Writing the dashboard before the questions would produce the measure of what is easy to measure.

## Debt generated {#dívida-gerada}

**The partial-period mark remains pessimistic.** `Periodos.interseccao/1`
marks any null start, even when the overlap is certain from the other
periods — it has been documented in the module itself since 057, and this feature
**consumes** the behavior without fixing it. The consequence shows now that there is a
screen: a team whose team memberships have no `started_at` will see the mark on every line,
and the mark stops distinguishing anything.

Fixing it changes what the function returns for cases that already have a caller, and it is an open
decision — not an oversight.
