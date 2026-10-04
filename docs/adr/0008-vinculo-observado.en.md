# ADR 0008 — The observed team membership: the participation the tool shows counts as a member, and the role is what is declared

## Status

Accepted — 2026-09-06 (decision of the maintainer: "2 and 3").

Depends on: [ADR 0003](0003-organizacao-por-ontologias.md) — the concept belongs to EO and collection still goes through the module's public API
Amends: specs 055 (FR-013 to FR-018, SC-007 to SC-009) and 058 (FR-026, SC-013 and SC-014); rule `github.team_membership_evidence` v2
Reverts, in part: spec 043, FR-007 ("the platform does not promote on its own") — **participation** becomes automatic; the **role** remains human

## Context

### What the measurement showed, on 2026-09-06

Collection brought in the 8 GitHub teams of the `leds-conectafapes` organization with 59
pieces of team membership evidence (49 people) — a number checked against the source on
the same day: 3, 7, 19, 4, 7, 6, 8 and 5 members per team, exactly what the API returns.
Under the rule of feature 055, evidence was not a team membership until someone confirmed
it with a role. Nobody confirmed.

| what the screen said | measured |
|---|---|
| GitHub teams with any current team membership | **0 of 8** |
| evidence awaiting confirmation | 59 (49 people) |
| requests in the last 56 days from authors with only pending evidence | **838 of 1,077 — 78%** — outside every per-team measure |
| the only team with measures | the derived one, with 31 people who are not in any observed team |

For the PLATAFORMA team (19 people at the source) the screen showed "Team with no current
team membership", "19 participations awaiting confirmation" and all of feature 058's
measures empty. Consistent with the rule; useless for the question the screen exists to
answer.

### The rule that was in force, and why

Rule `github.team_membership_evidence` v1 said: `eo.team_membership` is the relator that
allocates a person to a role in a team; GitHub provides person and team and does not
provide a role; therefore the team membership is not materialized, and the participation
stays as evidence that is "queryable, countable and explicitly incomplete" until the tenant
declares the role. Spec 043 (FR-007) settled it: the platform does not promote on its own.

The reason was good — inventing a role from `MAINTAINER`/`MEMBER` would produce a false
catalog. The practical consequence was not measured beforehand: **the manual declaration
does not happen**, and without it no per-team measure exists.

## Decision

Three ways out were presented to the maintainer, with the example of a person in a GitHub
team:

1. **Confirm by hand** — 59 role choices now, and one for each new person. Rule intact.
2. **Collection creates the team membership** as *observed*, with the role declaredly
   absent; whoever administers declares the role later, on the same team membership.
3. **Only the measures use the evidence** when there is no declaration, with a label — two
   definitions of "member" in the system.

The decision was **2 as the rule and 3 as transparency**: a single definition of member
(the team membership), and the screen saying over how many observed and how many declared
members each measure was computed.

### What now applies

1. **The observed participation becomes a team membership at collection.**
   `eo.team_membership` with a null `organizational_role_id` ("role not declared"), a null
   `declared_by_user_id` and a null `started_at` (the source does not say since when — and
   it is never `observed_at`). The evidence still exists and points to the team membership.
2. **Declaring is completing the same team membership.** The screen's "confirm" action is
   renamed "declare role": it fills in role, author and, if given, start — on the observed
   team membership, and not on a second one. `allocate/2` does the same when called
   directly. Two current team memberships for the same person in the same team would double
   the member count, and the partial index `eo_team_memberships_observado_vigente_index`
   prevents the duplicate observed one.
3. **Absence at the source ends the observed one — and only that one.** When collection
   stops seeing the person in the team, the purely observed team membership (no role, no
   author) gets an `ended_at` at the instant of the absence. It is never deleted. A team
   membership with any declaration is not touched.
4. **Where the organization has already declared something, collection does not create a
   team membership.** If, for that person and team, there is a declared team membership —
   current, ended or invalidated as a mistake —, the evidence stays without a team
   membership and the screen shows the two statements side by side (055, FR-012).
   Observation only fills in where nobody said anything.
5. **Whoever left and came back gets a new team membership.** The old one stays ended; the
   period is preserved.
6. **The declaration still requires a role.** A team membership with an author and no role
   is refused by the changeset: it is the incomplete allocation the ontology refuses. The
   observed one is the named exception, and named is the word: the screen labels it.
7. **Data migration**: the 59 live pieces of evidence without a team membership become
   observed team memberships, with a deterministic `internal_id`
   (`observed_<evidence id>`). Evidence that has already ended stays as it is — no team
   membership is created to state that someone was there.
8. **The derived team** (`github.default_team`) follows the same path: its evidence also
   becomes an observed team membership.
9. **`memberships_pending_role`** starts counting current team memberships without a role
   — that is what "pending" means now.
10. **Transparency (part 3):** the team screen says, next to each measure, *measured over N
    members — X observed in the tool without a declared role, Y with a declared role*. One
    definition of member; the transparency is about where each one comes from.

### What this does to the ontology

`eo.membership_to_play_role` has cardinality `one` in SEON EO: every team membership has a
role. The platform starts materializing the relator with the role **declaredly absent**. It
is a deviation from the reference ontology, and it is recorded as such: the column allows
null, rule v2 says why, and CQ14/CQ16 (questions about role) remain unanswered for the
observed team membership — the limitation belongs to the source, and the screen presents
it. What the decision refuses is the alternative that would "respect" the cardinality by
inventing a role: it would be false data that looks like data.

## Alternatives considered

**Confirm in bulk on the screen (way out 1).** It changes neither rule nor code. Rejected
by practice: 59 choices now and one per new person forever; meanwhile, no measure exists.
The measurement showed that confirmation does not happen.

**Measures over evidence when there is no declaration (way out 3 alone).** Less code, but
two definitions of member — one for the structure, another for the measures — that can
disagree. It was the kind of double definition that 055 spent a sprint eliminating. Only
the transparency remained.

**A generic catalog role for the observed one** ("participant"). It would respect the
cardinality with a role that answers no question about role — the false catalog that rule
v1 refused. The declared null was preferred.

**An observed team membership that also prevails over declarations.** Rejected: creating
"is in the team" on top of "left" or "never was" would make collection win over the
organization, and 055 decided the opposite (FR-012).

## Consequences

- The 8 teams stop triggering `structure.ap02.team_with_no_members`; the median wait, the
  participation in projects and the pipeline rate start existing for them. **To be measured
  after the migration** — it is SC-008 of the 055 amendment, and not a presumption.
- `count_evidence_pending_role/2` (evidence without a team membership) becomes almost
  always zero; whoever needs "pending role" uses `count_memberships_pending_role/2`.
- Spec 043 FR-007 is reverted for participation. The role is still not inferred.
- Spec 057 (FR-005, "evidence that has not been promoted does not go into the counts")
  becomes vacuous by construction — true, with no instances. It was not edited.
- Old tests that encoded "the team has zero members until confirmed" were adjusted to "the
  team has N observed members and N pending a role". The screen's query ceiling went up
  from 22 to 23, declared: the composition costs one query.

## Verification

1. New evidence → one current team membership without a role; the person counts in
   `count_team_members_at`.
2. Re-observing does not duplicate; declaring completes the same team membership (same
   `id`).
3. Absence ends the observed one; a count at an earlier date does not change (SC-002 of
   055).
4. A declared team membership survives absence; a declaration of departure or mistake does
   not get an observed team membership on top of it, and the disagreement shows.
5. **Real measurement, after the migration in development:** the 8 teams without `ap02`,
   and the count of requests from authors with no team membership at all — 838 today —
   measured again.

## Amendment of 2026-09-08 — rule v3, and item 5 extended

**Item 5** of this decision says: *whoever left and came back gets a new team membership*.
Feature 060 extended it to the **declared departure** and to the **mistake**, and the rule
`github_team_membership_evidence.yaml` went up to **version 3**.

What was missing was a gap this ADR created without seeing it. The collection's guard
recognized a declaration by three signals — role, declaration author and mistake. In a
**declared departure on an observed team membership** none of the three is present: there
is no role, no declaration author, only the author of the departure. The next collection
saw no declaration at all and created another team membership — **undoing the departure**.
Whoever declared it saw the person come back to the team on their own.

`ended_by_user_id` went into the guard. And since a permanent guard would prevent a return
from ever existing, there is a single exception and it is this ADR's, extended: a **new
observation after an established absence** is a return, and a new team membership is born;
the old one remains with its end. The absence mark is read **before** the update that
erases it.

A detail measured on 2026-09-08: the same commit discovered that `count_team_members_at/3`
counted **team memberships** where it promised people. With the observed team membership
living alongside the declared one, and FR-018 allowing two roles, whoever plays two was
counted twice. Fixed to `count(distinct person_id)` — and `team_size/2` already counted
distinct, which shows what the intent was from the start.

## References

- Specs 055 and 058 (amendments of 2026-09-06), 043 (FR-007), 057 (FR-005), **060 (FR-026,
  FR-027)**.
- `priv/knowledge_base/rules/github_team_membership_evidence.yaml` **v3** (2026-09-07);
  `docs/backlog/vinculo-observado-sem-papel.md` (the note for the base).
- Measurement of 2026-09-06: `sonda_times` against the source;
  `eo_team_membership_evidence` and `eo_team_memberships` in the development database;
  requests from the last 56 days.
