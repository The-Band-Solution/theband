# Sprint 021 — Review {#sprint-021--review}

**Period**: 2026-08-18 · **Feature**: 037 — collection of continuous verification
**Issue**: [#401](https://github.com/The-Band-Solution/theband/issues/401)
**PR**: [#435](https://github.com/The-Band-Solution/theband/pull/435)

> **Sprint opened without a backlog.** Feature 037 came straight out of the conversation that closed #434, and
> the `sprint-backlog` skill requires the document before implementing. Recording this here is the
> honest minimum: this review describes what happened, and the absence of the backlog is process
> debt, not an omission of the document.

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| Collection (runs and jobs) | 1 | 1 |
| Screens | 3 | 3 |
| New tests | — | 27 |

## What was done {#o-que-foi-feito}

| Deliverable | Accepted |
|---|---|
| `TheBand.Verification.Classification` — subtype, phase, components, derived type | yes |
| `TheBand.Ingestion.GithubVerifications` — a phase of the same sync | yes |
| `TheBand.Verification` — reading, with fixed cost proven by a test | yes |
| `/work/verifications` and `/work/verifications/:id` | yes |
| "What the checks said" section on the change page | yes |
| `GithubCommitFiles` finally wired into the sync | yes |

## The finding that reoriented the feature {#o-achado-que-reorientou-a-feature}

Of the 1,051 runs collected from the first repository:

| derived type | runs |
|---|---:|
| integration **and** deployment | 515 |
| **the network does not name it** | 399 |
| deployment only | 107 |
| integration only | 30 |

The first version would have called all 1,051 continuous integration. The 399 are mirroring
(`Sync to GitLab`) and board automation (`Sprint Rollover`) — calling them CI would poison
every verification measure with runs that verify nothing.

## Yesterday's decisions, measured {#as-decisões-de-ontem-medidas}

| phase | runs |
|---|---:|
| successful | 942 |
| unsuccessful | 55 |
| **interrupted** (cancelled) | 54 |

Counting the 54 as failures would take the breakage rate from **5.2% to 10.4%** — doubled by
human decisions. The maintainer's decision held up against the data.

## The anti-patterns, corrected by the data {#os-antipadrões-corrigidos-pelo-dado}

| maxim | before | after |
|---|---:|---:|
| `ci.ap02.unnamed_components` | 751 triggers | **0** |
| `ci.ap01.monolithic_job` | 0 triggers | **502** |

`ap02` fired on `sync`, `deploy`, `rollover` — these are not badly written jobs, they are
runs that verify nothing. `ap01` did not see the 502 `Deploy backoffice` jobs that have
`Build production bundle` and `Deploy to Vercel production` in the same job, because it only counted
CIRO processes.

## Two patterns went out for inventing {#dois-padrões-saíram-por-inventarem}

`artifact` matched the `Upload Pages artifact` step of a build job — **238 continuous
deliveries that do not exist**. `package` matched `Install npm packages`. A pattern that is too broad
does not collect more: it invents more.

## Debt generated {#dívida-gerada}

- **The collection did not finish.** 4 of 160 repositories traversed; 8,438 of 16,416 commits with
  files. The two compete for the same 5,000 req/h window and need to run one at a time.
- **Sprint without a backlog**, recorded above.
- **`ciro.continuous_feedback_activity` is not routed** — feedback in Actions is a notification,
  and the platform does not collect notifications. Declared limitation, not resolved.

## Evidence {#evidências}

- `mix gates` — 13 gates green
- collection run against real data: 1,051 runs, 1,530 jobs, 160 repositories visited
- screenshots of `/work/verifications`, of the detail and of the section on the change, on desktop and at 390px

## Lessons from this sprint {#lições-deste-sprint}

- **L61** — a limitation declared in the mapping does not become a restriction in the code by itself
- **L62** — summing counters through a hand-written list erases the new key in silence
