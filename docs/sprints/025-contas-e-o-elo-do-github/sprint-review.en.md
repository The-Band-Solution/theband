# Sprint 025 — Review {#sprint-025--review}

**Period**: 2026-08-29 (one day)
**Inheritance**: rework of US 047/US1–US2 · **Feature**: [051](../../../specs/051-cadastro-por-github/spec.md)
**PRs**: [#611](https://github.com/The-Band-Solution/theband/pull/611) (rework, squash) and
[#612](https://github.com/The-Band-Solution/theband/pull/612) (051, squash) — CI green,
review requested on opening for both, both on the board.

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 4 (2 inherited + 2 new) | 4 evaluated |
| Tasks | 10 (2 inheritance + 8 from 051) | 10 executed |
| Accepted deliverables | 4 | **2** (D2 leftovers, D3 registration) |

**Acceptance** ([full record](aceitacao.md)): confirmed by the maintainer
on 2026-08-29. **#574 and #597 ACCEPTED** with caveats; **#573 NOT ACCEPTED for the second
time** (the rework closed the counterexample and left its sibling: sentences born in an
ORIGIN FUNCTION — `PatternValidator.explicar/1` in the domain and `primeira_mensagem/1`
— outside the catalog and outside the leftovers); **#598 NOT ACCEPTED** (two edge
criteria written in spec/contract/tasks and not delivered: organization in the search for
namesakes and ended observation stated — aggravated by the comment in the code
contradicting the contract without a recorded correction).

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Success |
|---|---|---|---|
| 047/T012 | [#609](https://github.com/The-Band-Solution/theband/issues/609) | Checker v2 (assign class, 13 migrated by AST) | **no** — the origin-function class was left out, and US1 fell again |
| 047/T013 | [#610](https://github.com/The-Band-Solution/theband/issues/610) | Leftovers with sampling (L80), US3 aligned | yes |
| 051/T001–T002, T004 | [#599](https://github.com/The-Band-Solution/theband/issues/599), [#600](https://github.com/The-Band-Solution/theband/issues/600), [#602](https://github.com/The-Band-Solution/theband/issues/602) | Transactional registration with a temporary password on the spot | yes |
| 051/T003, T005–T008 | [#601](https://github.com/The-Band-Solution/theband/issues/601), [#603](https://github.com/The-Band-Solution/theband/issues/603)–[#606](https://github.com/The-Band-Solution/theband/issues/606) | The link in the area (search, named conflict, revocation) | **no** — two of the spec's edge cases not delivered |

## What was not accepted, and its destination {#o-que-não-foi-aceito-e-o-destino}

Named and finite rework, **first in the sprint 026 queue** (new tasks,
never reopening):

1. **#573**: the edge translates the reason — PatternValidator returns tuples,
   `humanizar/1` complete, `primeira_mensagem/1` and `motivo/1` through the catalog (the
   Ecto msgids already exist in errors.po). 5 sentences + 2 helpers.
2. **#598**: organization in the search result + ended-observation mark.

## Defects and corrections along the way (outside the sprint's scope, in the session) {#defeitos-e-correções-no-caminho-fora-do-escopo-do-sprint-na-sessão}

- The `API_KEY` flake (asymmetric restoration of env in a test) decided CI by seed —
  fixed at the root (#607) with three fixed seeds as proof.
- Gitflow adopted (constitution 1.7.0): `development` integrates, **a merge into `main` is a
  deploy**; PRs retargeted, default branch switched.
- The impeccable hook turned on for `.ex`/`.heex` (#615): the design detector runs on
  every page edit.

## Evidence {#evidências}

- Gates 14/14 with EXIT in the log on both branches; CI green; `mix mensagens.verificar`
  EXIT=0 with the assign class inside; 13+6 new tests green; the
  link→revoke→login cycle proven end to end; capture of the list with both
  states live, looked at.
- Acceptance executed the evidence again, independently — and it was what
  found the two cases the gates do not see.

## Debt generated {#dívida-gerada}

- Status labels (`origem_rotulo/1`) — HEEx-leftover class by the role's
  decision, named in the leftovers.
- Two tests promised in 051's contract and not written (query count
  L38 and temporary passwords issued) — behavior checked by reading.
- [redigido] (diverges from the moduledoc).
- Recorded review: zero for the third family of PRs — the request exists, the review
  does not; the structural way out (PR by agent identity) remains undecided.

## Lessons from this sprint {#lições-deste-sprint}

In the [cumulative record](../licoes-aprendidas.md): **L81** (closing the counterexample
does not close the class — hunt the siblings by the pattern before delivering rework) and
**L82** (a comment that contradicts the contract is the violation documenting itself —
diverging requires a correction recorded in the same commit, and the checker for that is
acceptance).
