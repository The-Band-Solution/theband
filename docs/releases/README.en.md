# Release records

One file per published release: `vX.Y.Z.md`. It is the document that constitution
1.7.0 and FR-016 of 050 ask for — the Product Owner's decision about what went live,
when, and what was observed afterwards.

**Who writes it**: the Product Owner role, when opening the release PR
`development → main`. **When it closes**: after the merge (which is the deploy), with the
measures of the first access and the evidence of what the CD did.

The version lives in `mix.exs` — single source (pipeline contract). The CD reads it, publishes
`ghcr.io/the-band-solution/theband:vX.Y.Z`, creates the git tag and calls the
Dokploy webhook. Tag and image are BORN from the merge: nobody tags by hand.

## The gap: v0.4.0 and v0.5.0 shipped without a note

**There is no `v0.4.0.md` and no `v0.5.0.md`.** Both releases were published — the
tag exists, the image exists, the merge into `main` happened — and the record this
directory asks for **was not written**. The absence stays here instead of in an
invented file: writing now a note with what can be deduced from the history would produce a
Product Owner decision that nobody made, with the same appearance as the other
four.

What exists in its place, and is what can be asserted:

| Release | Tag | Date | Release PR | Also | Commits |
|---|---|---|---|---|---|
| **v0.4.0** | `v0.4.0` at `1b04c53` | 2026-09-03 | [#791](https://github.com/The-Band-Solution/theband/pull/791) — *"declared teams, the composite team screen, and 058 partial (055, 056, 057, 058)"*, merged by **squash** | back-merge [#793](https://github.com/The-Band-Solution/theband/pull/793) | 1 (the squash) |
| **v0.5.0** | `v0.5.0` at `dda6239` | 2026-09-03 | [#795](https://github.com/The-Band-Solution/theband/pull/795) (`development → main`) | the bump and the pending items in [#794](https://github.com/The-Band-Solution/theband/pull/794); back-merge [#796](https://github.com/The-Band-Solution/theband/pull/796) | 64 since `v0.4.0` |

What is **missing**, and is what the note would exist to say: the acceptance verdict
per user story, what was left out and why, the evidence of what the CD did, the
runbook §7 measures, and what was observed in the first hours in production.

Part of that can be recovered from the record of [v0.6.0](v0.6.0.md), which states that
v0.4.0 went up **without T014** with the issue already closed, and that v0.4.0 carried
feature 058 **partially**. Recoverable is not written: whoever picks this up decides whether
to write the two overdue notes, or to record that they will not be written.

## The bump lives on `development`, not on a release branch

**The commit that raises the version in `mix.exs` is made on `development`, before
opening the release PR.** The release PR is `development → main` (Gitflow 1.7.0):
with the bump already on `development`, both sides carry the same version and the
following back-merge has no content to reconcile.

An intermediate branch `release/vX.Y.Z → main` does the opposite, and that is what
happened in v0.2.0: the bump was born outside `development`, entered `main` by
squash, and **`development` kept saying `0.1.0` in `mix.exs` while
production served `0.2.0`**. It is not just cosmetic misalignment — it is the single source of the
version asserting something the environment contradicts, and any image built
from `development` would come out with the wrong tag.

Comparing the two releases of this project:

| Release | PR | Head | Did the bump reach `development`? |
|---|---|---|---|
| v0.1.0 | [#636](https://github.com/The-Band-Solution/theband/pull/636) | `development` | yes |
| v0.2.0 | [#641](https://github.com/The-Band-Solution/theband/pull/641) | `release/v0.2.0` | **no** — fixed by the back-merge |

The L83 back-merge remains mandatory after every release, because squash
diverges the histories even with identical contents. With the bump on `development`,
it becomes what it should be: history convergence, with no content
decision at all.

## Template — `vX.Y.Z.md`

```markdown
# vX.Y.Z — <o que esta release entrega, numa frase>

**Decidida por**: <papel de Product Owner> em <data>
**PR de release**: #NNN (`development → main`) · **Merge/deploy**: <data e hora>
**Aceitação que a sustenta**: docs/sprints/NNN/aceitacao.md

## O que embarca

Só entregáveis ACEITOS (recusado não embarca — o mesmo invariante do entregável de
sprint):

| User story | Issue | Sprint | PR |
|---|---|---|---|
| <título> | #NNN | NNN | #NNN |

## O que ficou de fora, e por quê

<US recusadas ou não terminadas, com o destino. Silenciar isto faria a release
parecer o sprint inteiro.>

## O que o CD fez

| Passo | Evidência |
|---|---|
| imagem | `ghcr.io/the-band-solution/theband:vX.Y.Z` — digest <sha256> |
| tag git | `vX.Y.Z` em <commit> |
| delivery | webhook aceito às <hora>; Dokploy reimplantou em <duração> |

## As medidas do release (runbook §7)

| Critério | Alvo | Observado |
|---|---|---|
| SC-001 | entrar e ver painel em <2min | |
| SC-002 | <15min de procedimento, <2min de indisponibilidade | |
| SC-004 | zero segredos em imagem e logs | |
| SC-005 | 100% das rotas de dados recusam sem sessão (27 rotas da 045) | |

## Ensaio de restauração (FR-008)

<Data do ensaio mais recente e os três números que bateram; ou a data agendada, se
esta release não carrega dado real ainda.>

## O que se observou depois

<Primeiras horas em produção: o que funcionou, o que surpreendeu, o que virou
issue. Release sem esta seção é release que ninguém olhou.>
```

## Rules that are not negotiable

- **No secrets here** — not a fragment, not an address with an embedded credential.
- **Rollback recorded**: if the release was rolled back, the file says to which
  version and why. A release reverted in silence erases the only proof that the
  problem existed.
- **One release, one file**: rewriting the record of a published version is
  rewriting history — corrections go in as a dated note at the end.
