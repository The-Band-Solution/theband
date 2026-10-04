# Sprint 024 — Acceptance record {#sprint-024--registro-de-aceitação}

**Evaluated on**: 2026-08-29, on `main` (PRs #593 and #594 merged), by the
product-owner role with executed evidence — 13 pieces of evidence (E1–E13), including an
independent probe outside the tree. **Confirmed by the maintainer on 2026-08-29**,
in the two decisions reserved to that role: STRICT reading of US1's AS1, and a
post-merge review requested (comments on #593/#594 mentioning the reviewers).

## Verdict per user story {#veredito-por-user-story}

| US | Issue | Verdict | Decisive criterion |
|---|---|---|---|
| 047/US1 — errors in the catalog | #573 | **NOT ACCEPTED** | Executable counterexample: refusals as literals through a rendered assign (`access_scopes_live/index.ex:87,90,105` → `:144`), outside the catalog AND outside `pendencias.md`. SC-001 holds to the letter (the rule only watches `put_flash`) and is false in substance — and the spec's qualification depended on the enumeration, which was missing |
| 047/US2 — system messages in the catalog | #574 | **NOT ACCEPTED** | "Escopo %{nivel} concedido." / "Escopo revogado." as literals (`:83`, `:102` → `:145`); the `pendencias.md` method (grep for notices) is blind to the assign+div class — the screen does not appear in the list. FR-007 remains unexercised (zero decision comments migrated) |
| 047/US3 — language | #575 | **ACCEPTED** with caveats | Switch through ONE config proven with a sentence coming only from the `.po`; gaps `en: 0`, `pt: 132` named. Caveats: the US body still says "português padrão" (default Portuguese) (correction R2 did not reach the paragraph); the report enumerates gaps IN the catalog — what never entered it is invisible there too |
| 048/US1 — the key button | #587 | **ACCEPTED** with caveats | 5 scenarios + SC-001..003 with evidence, including the common reader probe (E9) and the Oban queue empty on violation. Caveats: the spec's "Start run" corresponds to "Turn on"/"run now" on the screen (the second without its own assertion, covered by identity of condition); `rodada_test` changed vehicle with the reason recorded; the common reader test has its body inside an `if` — mitigated by the probe, fragile to a fixture change |

**Composition of the sprint deliverable**: #575 and #587
(`sro.sprint_deliverable_composed_of_accepted_deliverable`). Tasks 047/T001–T011
classify as `sro.non_successfully_performed_scrum_development_task` as far as
US1/US2 are concerned; those of 048, performed successfully.

## The rework, named and finite {#o-retrabalho-nomeado-e-finito}

Migrate or enumerate the **"rendered message assign"** class:
`access_scopes_live` (5 sentences), `projects_live/index.ex:349,353,356` (3),
`sync_live/mapping_rules.ex:49` (`humanizar/1`) — and widen the
checker's boundary to that class BY AST (never a broad regex), with `pendencias.md`
corrected. It goes **first** in the sprint 025 backlog (inheritance before new
scope), as new tasks linked to the same USs — never reopening the
executed ones. The effort already spent counts in `rework.not_accepted_deliverable_ratio`.

## Process violations recorded {#violações-de-processo-registradas}

1. **Review never requested, twice** (E10: zero `review_requested` events,
   zero reviews, merge by the author on both PRs). Maintainer's decision:
   **post-merge review** — requested on 2026-08-29 by comment on #593/#594 to
   Adylla027/EduardoNFraiz; the residue closes when the review exists on record.
2. **PRs outside Projects v2** (`projectItems: []`) — the board did not see the sprint;
   flow measures undercounted.
3. **Issues closed before this record** (14:51–14:52) — inverted order;
   kept closed so as not to erase history, the rework goes in as new
   tasks.

## The spec corrections — all legitimate {#as-correções-de-spec--todas-legítimas}

The sprint's five corrections (default language, 55→137, runtime default_locale, key
per tenant, defense born in 048) are corrections of premise against measured data,
recorded with date and reason — none weakens a criterion; the defense one
strengthens it. The only leftover: the US3 paragraph, already listed in the rework.
