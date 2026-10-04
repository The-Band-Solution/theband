# Sprint 013 — Review {#sprint-013--review}

**Period**: 2026-08-13 · **Features**: [014](../../../specs/014-clicar-leva-a-pagina/spec.md) and [015](../../../specs/015-quem-escreveu-a-issue-tambem-e-observado/spec.md)
**PRs**: [#286](https://github.com/The-Band-Solution/theband/pull/286) and [#287](https://github.com/The-Band-Solution/theband/pull/287)

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| Features | 2 | 2 |
| Tasks | 12 | **11** — the 12th needs the master key |
| Functional requirements accepted | 23 | **23** |
| Success criteria accepted | 14 | **9** — five depend on collection |

## What was done {#o-que-foi-feito}

| Task | Deliverable | Accepted |
|---|---|---|
| 014-T001 to T005 | conditional linking in the issue and team detail; 7 tests | yes |
| 015-T001 | broadened query, with `__typename` and `id` | yes |
| 015-T002 | person born from the collection, with the context threaded across repositories | yes |
| 015-T003 | bot refused, by `Mapper.account_type/1` being called | yes |
| 015-T004 | idempotency, with `collected_at` preserved | yes |
| 015-T005 | team evidence intact — working is not belonging | yes |
| 015-T006 | `worked at` on the person page, with the evidence and without the word member | yes |

## What was not done {#o-que-não-foi-feito}

| Task | Reason | Destination |
|---|---|---|
| 015-T007 | requires a collection with the source responding, and the master key | maintainer |

## Evidence {#evidências}

```
mix gates → 10 gates verdes, código de saída 0
542 testes, 17 novos
39 → 38 consultas no detalhe da issue (a ligação não custa consulta)
```

## What the analysis found before the code {#o-que-a-análise-achou-antes-do-código}

| Finding | Consequence if it had gone through |
|---|---|
| `ctx.pessoas` built once | team membership in some repositories and not in others, in the same run, **with no error** |
| `gravar_issue` reads the map in the same pass | `author_person_id` null with the person existing |
| `replace_assignees` uses the same map | the defect would hit the assignee, and the spec only talked about the author |

## This sprint's process error, and it is mine {#o-erro-de-processo-deste-sprint-e-ele-é-meu}

**I pushed both features on the same branch**, and PR #284 was born with both diffs — against
`AGENTS.md` §17 and against what **my own backlog** said in its second section: *"two PRs, one
sprint"*.

Fixed without rewriting history: two new branches from `main`, by cherry-pick, and #284 closed
with an explanation. Nothing was lost.

**Why it happened**: 015 started as a continuation of the 014 conversation — the decision to create
the people came out of measuring 014 —, and the continuity of the conversation became continuity of
the branch.

## Debt generated {#dívida-gerada}

| Debt | Why |
|---|---|
| old issues only get an author on the **next** collection | the stored payload does not have the `id`; reprocessing does not invent what was not requested |
| `worked at` shows the organization, not the role | organizational role is #99/#100, and GitHub does not provide it |

## Lessons from this sprint {#lições-deste-sprint}

- **L52** — continuity of conversation is not continuity of branch;
- **L53** — the ceiling of a cost test comes from measuring both sides, never from a choice.
