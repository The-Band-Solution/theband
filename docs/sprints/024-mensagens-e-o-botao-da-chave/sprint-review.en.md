# Sprint 024 — Review {#sprint-024--review}

**Period**: 2026-08-28 to 2026-08-29 (two days)
**Features**: [047-mensagens-internacionalizadas](../../../specs/047-mensagens-internacionalizadas/spec.md) and
[048-botao-sem-chave-desabilitado](../../../specs/048-botao-sem-chave-desabilitado/spec.md)
**PRs**: [#593](https://github.com/The-Band-Solution/theband/pull/593) (047, squash) and
[#594](https://github.com/The-Band-Solution/theband/pull/594) (048, squash) — CI 2/2 green
on both; adversarial review on #594 with no real finding.

## Summary {#resumo}

| | Planned | Delivered |
|---|---:|---:|
| User stories | 4 | 4 |
| Tasks | 16 | 16 |
| Accepted deliverables | 4 | **2** (#575, #587) |

## What was done {#o-que-foi-feito}

| Task | Issue | Deliverable | Accepted |
|---|---|---|---|
| 047/T001–T004 | [#576](https://github.com/The-Band-Solution/theband/issues/576)–[#579](https://github.com/The-Band-Solution/theband/issues/579) | Catalog configured (en at runtime via `:gettext`), AST checker born from the violation, new gate — which was born red with 137 findings | see Acceptance |
| 047/T005–T007 | [#580](https://github.com/The-Band-Solution/theband/issues/580)–[#582](https://github.com/The-Band-Solution/theband/issues/582) | 139 messages migrated without changing a byte (97 errors + 40 system + 2 default); suite of 1447 green WITHOUT editing a test; 045's single refusal intact | see Acceptance |
| 047/T008–T011 | [#583](https://github.com/The-Band-Solution/theband/issues/583)–[#586](https://github.com/The-Band-Solution/theband/issues/586) | pendencias.md measured per screen; `mensagens.lacunas` (en 0, pt 128); 11 refusals in pt with the switch proven by test; 14 green gates | see Acceptance |
| 048/T001–T005 | [#588](https://github.com/The-Band-Solution/theband/issues/588)–[#592](https://github.com/The-Band-Solution/theband/issues/592) | `:sem_chave` guard in `request/3` from the violation; real `disabled` buttons with a sentence per reader; environment/tenant asymmetry stated on the screen; 27th query named in the guard; 14 green gates | see Acceptance |

**Acceptance** ([full record](aceitacao.md)): product-owner on 2026-08-29, 13
pieces of evidence executed, confirmed by the maintainer (strict reading; post-merge
review). **2/4 accepted**: #575 (language) and #587 (the key button), both with
caveats. **#573 and #574 NOT ACCEPTED** — real counterexample: messages as literals
through a rendered assign (`access_scopes_live`, `projects_live`, `humanizar/1`),
a class invisible to the checker (which watches `put_flash`) AND to `pendencias.md` (which
counted notices). The rework is finite (~9 sentences + widening the boundary by AST) and
goes first in sprint 025 — inheritance before new scope.

## What was not done / not accepted {#o-que-não-foi-feito--não-aceito}

The 16 tasks were executed and the issues closed by hand (PRs following the 1.6.0 standard do not
close them on their own) — but **047's US1 and US2 came back**: an executed deliverable whose
result did not meet the criterion is not delivered (the assign class was left out of the
catalog and of the enumeration). Destination: the first tasks of sprint 025.

**Process violations** (recorded in [aceitacao.md](aceitacao.md)): review never
requested on both PRs (decision: post-merge review, requested by comment); PRs outside the
board; issues closed before acceptance.

## Defects found and fixed along the way {#defeitos-encontrados-e-consertados-no-caminho}

- **The plan's grep undercounted**: 55 literals became **137** when the AST checker
  measured — multiline, concatenation and pipe form were invisible to grep. Corrected
  in tasks.md with the reason; it became the definitive argument for the AST checker.
- **The qualified form escaped**: `Phoenix.Controller.put_flash` has a different AST
  head and checker v1 did not see it — the PLUG's refusal was left out of the first
  sweep. What caught it was the language test (the sentence did not switch). Checker
  corrected with its own test for the qualified form.
- **The backend's `default_locale` is compile-time**: the contract foresaw the config in the
  backend; the language test failed and measurement showed that only the config of the
  `:gettext` app is read at runtime. Contract corrected in the same commit, with the reason.
- **`rodada_test` clicked the button that 048 disabled**: the test changed vehicle
  (event injected from outside the button) with the invariant intact — L71 applied.

## Evidence {#evidências}

- Local gates 14/14 with EXIT in the log (L60) on both branches; CI green 2/2 on both
  PRs; adversarial review posted on #594 (six fronts, no real finding).
- Full suite of 1447 green after migrating the 139 messages **without touching any
  test** — the proof that the msgid preserved every byte.
- `login_test.exs` with no diff during the whole sprint (047's SC-004).
- Capture of the monthly generation with a credential (buttons live, sentence absent — 048's
  scenario 3); the disabled states proven by 5 screen tests.

## Debt generated {#dívida-gerada}

- Checker v1 does not see HEEx — a boundary declared in the contract, with the backlog
  named in `pendencias.md` (15 notices on the person page, 8 on the work item, …).
- pt has 128 enumerated gaps — visible through the report, fillable by a translation
  PR without touching code.
- 048's gap sentence uses `@operacao_menu` as an approximation of "who operates" —
  if management of the admin mark (#568) changes the semantics, the sentence follows.

## Lessons from this sprint {#lições-deste-sprint}

In the [cumulative record](../licoes-aprendidas.md): **L76** (the measuring tool
needs the target's grammar — grep 55 vs AST 137), **L77** (a new checker is born
with an end-to-end test that does NOT go through it — it was the language test that caught the qualified
form), **L78** (config promised as "runtime switch" is proven with a test at
runtime before entering the contract), **L79** (an agent with a shared tree does not
switch branches — the PO left the tree on main and the files "disappeared"), **L80** (a
leftover measured with the instrument's grep inherits its blindness — it was because of it that
two USs came back), and **L72 refined** (a completed iteration keeps its id but the
items' values are lost, unrecoverable through the API — the record of membership is the
backlog in the repository).

And the post-sprint flake that #596's CI exposed — a test `put_env` without symmetric
restoration leaked the `API_KEY` and the verdict depended on the seed — was fixed at the root
in PR #607, with three fixed seeds as proof.
