# The team screen

**Where**: `/teams/:id` · **Features**: [057](../../specs/057-tela-da-equipe-complexa/spec.md)
(the composite team) and [060](../../specs/060-tela-da-equipe/spec.md) (the screen as it is today),
on top of [055](../../specs/055-equipes-declaradas/spec.md) (the declared team membership) and
[058](../../specs/058-medidas-da-equipe/spec.md) (the measures).

**Yardstick for this page**: the implementation in
[`show.ex`](../../lib/the_band_web/live/teams_live/show.ex) and
[`problems_now.ex`](../../lib/the_band/teams/problems_now.ex). What is specified and is not yet
on the screen lives in the last section,
[*What is not on the screen yet*](#what-is-not-on-the-screen-yet) — and not in the middle of the text as
if it were.

---

## The two tabs, and the question of each

The screen answers **two** questions, and that is why there are two tabs — not two routes and not one
stacked page:

| Tab | The question | The address |
|---|---|---|
| **`Dashboard`** | *how is this team doing* | `/teams/:id` |
| **`Structure`** | *who is on it* | `/teams/:id?tab=structure` |

The chosen tab goes into the address, so **a link lands where it points** and reloading the page
keeps the tab. Switching tabs does not reload the screen. A nonexistent tab in the address does not raise an error:
it opens the Dashboard and says why — *"A team has no "…" tab. Showing the dashboard."*

**All writing lives in `Structure`. The `Dashboard` only reads.** Declaring a role, recording a
departure, marking a mistake, composing a sub-team, creating a role, linking the team to a project —
all in the `Structure` tab. That is what makes the Dashboard readable by any account of the tenant without
a button appearing and disappearing depending on who is looking.

The **header belongs to both tabs**, and its numbers count **people**, never team memberships:

> *N* people here · *N* left · *N* recorded by mistake · *N* with no organisational role

Whoever left and whoever was recorded by mistake appear **separately** from whoever is there. Adding them up
would answer *how many rows exist* to someone who asked *how many people are on the team*. And
a person with two current roles counts **once**: two roles are not two people.

---

## `Problems now` — the first section of the Dashboard

Eight cards, **before** any measure, each one counting **one fact**. The header says
what was counted over — *"counted over the whole team · window of 56 days where a window
applies"* — and the line below it says what the section is, and what it deliberately is **not**:

> *"Each card counts a **fact**, never an inference, and carries the threshold that decided
> the count. Nothing here is ordered by severity — counting is what the platform can do;
> deciding what is urgent is yours."*

Each card carries, in small print, **the threshold that decided the count** and **the rule that
declares it**. It is not decorative provenance: *"46 issues"* without *"for more than 30 days"* is a number
without a question.

| # | The card | The threshold written on it | The source |
|---|---|---|---|
| 1 | **`Issues open beyond the threshold`** | `open for more than 30 days` | `team.dashboard.thresholds · open_issue_age` |
| 2 | **`Code changes waiting for a first human review`** | `waiting for more than 7 days` | `team.dashboard.thresholds · review_wait` |
| 3 | **`Pipeline failing now on the default branch`** | `the latest completed check, per repository` | `spec 060 · FR-071` |
| 4 | **`Assigned tasks past the stop threshold`** | `open for more than 90 days` | `profile.thresholds · stale_open_work` |
| 5 | **`People with no open task`** | `no threshold — it is a count of people` | `spec 057 · FR-021` |
| 6 | **`Members with no declared role`** | `no threshold — it is a count of links` | `spec 055 · FR-018` |
| 7 | **`Work outside any declared project`** | `repository or board with no declared project of this team` | `spec 060 · FR-053` |
| 8 | **`Structure anomalies`** | `declared in structure_antipatterns.yaml` | `spec 058 · FR-025` |

A card with a number greater than zero carries **`see the list`** — the path to the list that produced
that number — when it exists on this screen or on the other tab. Cards 1, 4 and 5 show the
number **without** that link: the list that produced them does not have its own section yet.

### Zero is not the same as not checked

This is the distinction that carries the whole section, and the reason for eight counted cards
instead of a list of alerts. There are **three** states, and none of them is a mute zero:

| State | What the screen shows | What it asserts |
|---|---|---|
| counted, greater than zero | the number, in amber | *the platform looked, and found this many* |
| counted, **zero** | a grey `0` **followed by the words** **`checked, nothing found`** | *the platform looked there, and found nothing* |
| **not checked** | the dashed label **`not checked`**, **with no number**, and **what is missing** | *the platform could not look* |

**`0` asserts that the platform looked. Absence asserts that it did not look.** The two lead to
different decisions, and a mute zero makes one pass for the other. A card with zero does **not**
mean the team is fine — it means that fact was checked and was not there.

### Why two of the eight never have a number

Cards **3** (`Pipeline failing now on the default branch`) and **7** (`Work outside any
declared project`) say `not checked` **always** — not depending on the data, but by construction.
The reason is the same for both, and it is written on the card itself:

| Card | What is missing |
|---|---|
| **3 — pipeline failing now** | the inputs **are** collected — the default branch of each repository, and the branch of each check. But *failing now* is a different assertion from the success rate over a window: it is the **latest completed check** on the default branch. The screen says: *"the query does not exist yet — the inputs are collected (default branch and check branch), and the measure needs a name in the knowledge base before the card counts"* |
| **7 — work outside a declared project** | what is missing is the rule that **names** the fact: *"it needs the rule that names work in a repository or board with no declared project of this team"* |

**Why not omit the two cards, and why not show `0`.** Showing `0` would assert that
the whole pipeline is green and that all the work is inside a declared project — the two
most expensive things the section could get wrong. Omitting them would hide that the question
exists. A card without a measure is the only way to say *we do not know yet*, and the measure needs
a **name in the knowledge base** before the card counts.

Five of the eight are computed over data the page has already loaded. Only card 1 runs its own
query — and that is why the section does not cost eight queries.

---

## `Dashboard` tab — how the team is doing

### The composite team: one card per sub-team, and no total

When the team has **two or more** sub-teams with a current composition, the Dashboard carries the
**`Teams inside this one`** section — *the teams inside this one*: one card per sub-team,
**plus** one card for the team's **direct members**.

> *"One card per sub-team, plus this team's direct members. Click a card — or its chart — to
> open that team's dashboard."*

With a **single** sub-team, the team stays simple: comparing one row with nothing is not a
comparison.

Each sub-team card is a **door** — clicking it, or the chart inside it, opens that
sub-team's Dashboard. The direct members' card is **not** a door: we are already in it, and
a link to the screen the person is on is a click that leads nowhere; it leads to
*`see the N people →`*, the people section further down.

The cards and the rows are ordered by **stopped work**, from largest to smallest, and the screen
says so: *"Ordered by stopped work, so the row that needs a conversation comes first."*
Ordering **is not adding up** — each card keeps its own number.

#### Why there is never a total

The screen devotes a block to **explaining**, under the title `why these rows are not added up`, and not
just to asserting:

> *"The same person can belong to **two sub-teams**, and the same task can appear in both. A
> total would count each of them twice, and nobody could reconcile it with the work that
> exists. Each row is measured on its own."*

That is it: the sub-teams **do not form a partition**. The same person can be in two, and the same
task can appear in both. A total would count each of them twice, and nobody could
reconcile it with the work that exists.

The sentence is mandatory **because the section has a chart**. On a screen with curves, the absence of a
total looks like carelessness — and someone would add up the rows to "check", arrive at another number, and
conclude the chart is wrong. The refusal also lives in the domain layer, and not only in the
text: the function that builds the rows **returns no total**, because there is no field where it
would fit.

#### The card's two numbers

The sub-team's name sits on the left of the header and **`N members`** on the right. In the numeric slot,
**two** numbers — the ones that answer *how is the work going*:

| Label | What it is | When there is none |
|---|---|---|
| **`open items`** | open items with an assignee | — |
| **`median wait`** | median wait for the **first human review**, in hours | **`no review yet`** — and never `0 h`, which would assert an instantaneous review |

They are the **same** numbers as in the table below, with the **same** labels. Two presentations of the
same data need to say the same thing: whoever compares the card with the row and finds two numbers
does not know which one to follow.

**Why two, and not three.** It is a Design decision from 2026-09-09, recorded in
[`decisoes-do-cartao-de-subequipe.md`](../../specs/060-tela-da-equipe/decisoes-do-cartao-de-subequipe.md):

- **`members` moved up to the header** — it is not a measure of the work, it is a property of the sub-team.
  In the numeric slot it forced reading three labels to find the two about work;
- **`stopped` moved down to the table** — there is no room for the threshold in a slot that size, and the
  number without the threshold is not interpretable. In the table it has the threshold in the header, and that is where it
  needs to be, because it is what the rows are ordered by;
- **`pipeline` does not go in.** The reason is in the data: `spo_project_teams` **has no link for
  any** of the sub-teams of the reference composite team, so the rate would be *no project*
  on **every** card. The refusal already has its own place on the screen, with the reason attached.

They are **two slots, not three with an absence** — absence is the value that is missing, not the measure that
does not exist. And three cards with 3, 3 and 2 slots do not line up.

#### The small chart inside the card

It is the sub-team's burn, in the **same window and granularity** as the large charts, reduced to two
cumulative curves: no axis, no label, no band.

It answers **the shape** — did opening and closing move together, or did the gap grow? That is the question that
decides whether it is worth opening that sub-team's panel. It does **not** answer *how much*: the numbers
are on the card, in text and aligned.

When the window had no **movement**, there is no sparkline, and the card says what in fact did not
happen:

> *"Nothing opened or closed in this window — the items below are stock, not movement."*

The sentence is precise on purpose. Before, it said *"No work observed in this window — which is
not the same as zero"* on a card that showed, in the same box, open and stopped items: both
things were true and looked like a contradiction. **Stopped work is stock without movement**, and
it is precisely the gap between the two that matters.

#### The table, and why it has no chart

Below the cards, **`The same numbers, side by side`**:

| Column | |
|---|---|
| `team` | with a link to the sub-team's panel |
| `members` | |
| `open items` | the same number and the same label as the card |
| `closed · 8w` | |
| `median wait` | or `no review yet` |
| `stopped · open > 90 d` | **the threshold in the header**, and not in a footnote |

A sub-team with no work in the period has its row replaced by text — *"No work observed
in the period — which is not the same as zero."* — instead of four zeros.

**The table still has no chart**, and that is a decision, not a gap: it exists to **compare**, and
comparison is done with aligned numbers. Reading a value off a 40-pixel sparkline would be guessing.
Card and table live together in the same section answering different questions — **the shape** and **the
quantity**.

### The flow: burn, forecast and `Promised × Delivered`

The three charts cover the **whole team** — its own members **plus** all of those of the
sub-teams with a current composition — and the screen declares that the curve **is not the sum** of the
sub-teams' curves: the set is the **distinct union**, and the person in two sub-teams and the item with
two assignees count **once** here.

#### The granularity selector, and the window in the title

Each flow chart has the **`week` / `month` / `year`** selector in the header, and the **window
always in the title**. The screen's two selectors change the **same** address parameter: two
places, **one** single state.

Each granularity has **its own** default window — 8 weeks, 12 months, and **all the years
collected** (with five years as the fallback when there is no activity at all). Changing the granularity
regroups **the same items** without changing what is measured, and the screen says so: *"Changing the
grouping regroups the same items over that granularity's own default window — it does not
change what is measured."*

The window in the title was the **condition** for the selector to exist. The objection was the moving
denominator; the answer is to **state** the denominator.

#### `Burn-up and burn-down`

Two cumulative curves — `opened, cumulative` and `closed, cumulative`. The **hatched band**
between them is the work still open, and it is **derived** from the two series, not a third
line. The identity is written on the screen, so that the gap can be checked without
trusting the drawing:

```
open(t) = N + opened(t) − closed(t)
```

The X axis is a **timeline with dates**. `2026-W36` is an internal label, and nobody reads an ISO week
number without looking at a calendar. There is a value at each point, the axis ceiling written, and a
`see as a table` for whoever wants the numbers instead of the shape.

Below the chart, the gap and the horizon at the observed closing pace — *"The gap is
N items still open. At the closing pace observed in this window — X closed per week — half of
the simulated runs reach zero within N weeks."*

It is **a range with its confidence, never a date**. A date is read as a promise, and the platform
has no committed scope. Two caveats come with the sentence, always: **it assumes nothing new
comes in** — the optimistic bound — and **there is no committed scope**, so this does not answer whether a
deadline will be met.

And when more than 15 % of the runs do not reach zero within the horizon, the screen says there is
**no 85 % figure** instead of writing *"more than N weeks"*. Writing a number there
would invent the percentile that does not exist.

#### `Delivery forecast` — the histogram, and the two hypotheses

It is the Monte Carlo simulation, and what it produces is thousands of runs, each one drawing
a week of throughput from among the weeks **this team actually had**. No estimate. The
label says where it comes from: **`derived — simulated from this team's own history`**.

It is drawn as a **histogram**, and not as a range, because range and percentiles are three cuts
of the distribution — and three cuts do not recover the shape. Two simulations can have the **same**
50 % and 85 % with very different distributions: one concentrated in two weeks, another
spread over eight with two peaks. The first is a predictable pace; the second is a team that
alternates full and empty weeks — and the reader's decision changes. The percentiles are still
drawn **over** the histogram: the shape answers *how regularly*, the percentile
answers *by when*.

The **two hypotheses** are declared with the names the knowledge base gives them in
[`flow_completion_forecast.yaml`](../../priv/knowledge_base/measurements/flow_completion_forecast.yaml),
stacked and with the **same** X axis:

| Label on the screen | The hypothesis |
|---|---|
| **`if nothing new opened · frozen scope`** | **frozen** scope — nothing new comes in. It is the **optimistic** bound |
| **`if work keeps arriving as it has · live scope`** | **live** scope — new work keeps arriving at the observed pace |

The declared name goes along with the text for a practical reason: without it, the screen describes the
hypotheses and does not name them, and whoever looks for the measure in the knowledge base does not find what they are seeing.

They are two histograms, and not one overlaid: two distributions on the same pair of axes with
translucent bars produce a **third shape that does not exist**. Stacked, the horizontal
distance between the peaks is the **cost of the new work**.

The **hatched column, separated by a gap**, is the runs that **never** reached zero. It is not the
week after the last one: it is *never, within this horizon*, and drawing it flush against the others
would make it read as one more week. When **no** run completed, there is no bar
at all and the screen writes that in words — an axis with twelve zero-height bars would assert
that the simulation ran and found nothing, when what it found was *never* in every
run. In the summary table, a dash means **unknown**, never *far*.

**Below the floor, there is no forecast.** The screen says **`No forecast yet.`**, how many weeks of
history and how many closed items are required, how many the team has, and why it refuses:
*"Below that, the range would cover almost the whole horizon. Refusing says more than a number
nobody could act on."*

> **A real example, with provenance.** Measured in the development database and recorded in the
> [v0.6.0 record](../releases/v0.6.0.md): the *IA* team closes 22.1 items per week with
> 74 open, and **half of the runs reach zero in 4 weeks**. *PLATAFORMA* and *SQUAD GREEN*
> do **not** reach zero within the horizon — and the screen says so, instead of showing a range.

The reading that the knowledge base names as a misinterpretation is worth repeating here: **concluding
that the team needs to work more when the live-scope hypothesis does not converge**. If
inflow exceeds outflow, no amount of effort within the current rates closes the gap —
the decision is about **what comes in**.

#### `Promised × Delivered`

The operational definition sits **next to the title**, before the chart, and not in a footnote:

> **promised** = opened in the period · **delivered** = closed in the period.

And the caveat, in the same place: *"There is **no committed scope** in the platform, so this is not
a sprint commitment against a sprint result."*

**`promised` is a label for *opened in the period***, and cannot be read as a commitment: the
platform does not record committed scope. **`delivered` is the issue being closed at the source** —
an act of the tool, not a declared completion criterion.

It has the same `week` / `month` / `year` selector, the same window in the title, and a `see as a table`.
When none of the team's periods falls within the collected interval, the screen says there is **nothing to
compare** — *"which is not the same as opened zero and closed zero"*.

### `What each person is on` — what each person is doing

One entry per person in the set, with **all** the open tasks assigned to them
**now**. None is singled out as *the current one*: which of them is the current one is a judgement the data does not
make.

Each task carries its age in days, and the screen declares where it counts from:

> *"Every open task assigned, with how long it has been open. Time counts from when the item
> was opened — the source does not record when someone took it on."*

Past the stop threshold, the task gets the **`stopped · over 90 d`** mark — the threshold is
**in the label**, read from the knowledge base.

A person **without** an open task **does not vanish from the list**: they appear with *"No open task assigned"*.
Vanishing from the list would be the screen deciding they are not on the team.

Each person's list **is cut at eight items**, with *"… N more open items · open the person
→"*. It is not pagination: the section's question is *what each one is doing*, and eight items already
answer it. Without the cut, a person with 114 open items — it exists, in `SQUAD PINK` — pushes
the other four in the squad off the screen. Whoever needs the 114 needs the person's screen.

And at the foot of the section: *"A task with more than one person responsible **appears once for each**.
Summing these lines would overcount the team."*

#### The concept mark, and where it comes from

Before the title of each item comes the mark of what that item **is**:

| Mark | The concept | What the label says on mouse-over |
|---|---|---|
| **`EPIC`** | `sro.epic` | *epic — a user story with parts* |
| **`US`** | `sro.atomic_user_story` | *atomic user story — no parts* |
| **`TASK`** | `sro.intended_scrum_development_task` | *intended development task — declared, not necessarily executed* |
| **`BUG`** | `osdef.defect` | *defect* |
| **`—`** | none | *the mapping rule did not classify this item — no type at the source, and the structure does not decide* |

It takes the place where the source identifier used to be. `I_kwDON0TQIs6vA1ZX` is the
GitHub GraphQL `node_id`: it identifies the issue at the source and **says nothing** to whoever reads the
screen, taking the place of the information that matters before the title.

**The mark comes from the promotion, not from the type declared at the source.** The routing rule
`github.issue_type_routing` has **structure over declaration** precedence — and that is why
an issue of type `Feature` **with** parts that are user stories is an **epic**, and the same one **without**
parts is an **atomic user story**.

It is not an implementation detail. In this database the declared type is **null in 778 of the 1 154 open
items** (measured in the development database, recorded in
[`team_work.ex`](../../lib/the_band/work_items/team_work.ex)): a mark read from the declared type
would leave **two thirds** of the list blank.

The **`—`** is the case where the rule did not classify: no type at the source, and the structure does not
decide. It appears, and is not left blank — vanishing from the screen would be worse than appearing without
a translation. A new concept in the knowledge base appears with its own identifier, for the same reason.

---

## `Structure` tab — who is on the team

### One row per person

Each person appears **once**, even someone who has a direct team membership with the team *and* belongs to
a sub-team. The two team memberships sit **inside** the row, and each one says which team it comes from.

The role column says the declared role or, highlighted, **`not declared`** — *role not
declared*. Never blank: an empty cell reads as *did not load*, and what it needs to say
is that **nobody declared** the role.

A team with nobody on it does not show an empty table: it says *"Nobody has a link to this team yet — neither
declared nor observed."*

The four marks of a team membership appear **in text**, with the legend **before** the table:

| Mark | What it asserts |
|---|---|
| **`declared`** | someone declared this team membership on the platform |
| **`observed`** | the source tool shows the participation; nobody declared the role |
| **`left`** | the person left, with a date |
| **`mistake`** | the team membership **never** existed — and the `since` column says `never` |

Color alone is not a mark: the distinction survives without color, and that is why the legend is text.

**`MAINTAINER` does not appear anywhere on this screen.** It was a GitHub administration access level
shown next to a role column — and read as a role by whoever skimmed it. `MAINTAINER` was never a role in the organization.
The data is still stored; it left the screen.

### Roles: declare, add, change

The buttons, for whoever manages the structure:

| Button | Where | What it does |
|---|---|---|
| **`Declare role`** | on the row, where the person has **no** role at all | declaring over an *observed* team membership **completes the same team membership** — the record is not recreated |
| **`＋ Add role`** | on the row, where there is already a role | **adds** a second one: *Developer* and *Scrum Master* at the same time is common, and the first one stays valid |
| **`Change`** | **next to each role**, in the role column | **ends** that role and opens the new one; the others continue |

**Why `Change` is per role, and not one per row.** With a single button at the end of the row, whoever
had two current roles clicked without knowing which one they were changing — and the screen did not ask. The
button ended the first one by creation order. Next to each role, **the one that changes is the one the
person clicked**.

`Change` only appears on a role of **this** team that is **current**. Changing someone's role in a
sub-team is work on that sub-team's screen, where the verdict is its own; doing it from here would make
authority cross sideways.

In the form, **the `since` date comes empty**, with text saying what empty means:
*"empty date = unknown, never today"*. A pre-filled field is sent as it is, and today's
date would become the start date of someone who started last year.

**`＋ new role…`** opens the `name of the new role` field **without leaving the row**: it creates the role in the
team's organization and declares it in the same submission. The code comes from the name — *Tech Lead* becomes
`tech_lead` — and is editable; from the moment you type in the code, the suggestion stops
overwriting it.

After changing, the row carries **two** team memberships: the old one with its period closed, and the new one.
There is no role history table, and that is **not a gap** — the history *is* the ended
row. And changing to the role the person already has is **refused**, with nothing changing: the
transaction rolls back the ending.

For whoever has many observed team memberships without a role, there is **bulk** declaration —
*"N observed member(s) without a declared role"*, with **`Declare all roles`**, which skips the
rows with no role chosen and **says how many** it skipped.

### Departure and mistake are different things, and the screen says which

This is the most consequential distinction in the tab, because the two look alike and do the opposite of each
other:

|  | **`Left the team…`** — the departure | **`Mistake…`** — the mistake |
|---|---|---|
| what it asserts | the person **belonged**, and stopped belonging on date *D* | the team membership **never** existed |
| effect on the measures | closes a period that existed: numbers for periods **before *D*** do not change | leaves **every** measure, for **every** date |
| the field | `{nome} left on` — and it comes **empty** | **`why`** — mandatory, with an example: *e.g. wrong login picked when declaring* |
| the button | **`Record departure`** | **`Invalidate link`** |
| what the screen refuses | submitting without a date — *"A departure needs a date — the platform does not assume today."* — and a date in the future | an empty reason, and **nothing** is stored |

Nothing is deleted, in either case. The mistake is a **mark**, not a removal, and the screen says why:

> *"**This is not "left the team".** A mistake is a link that never was: it leaves every
> measure, for **every date**. The record stays — with the reason, who, and when — because the
> mistake itself is a fact."*

It applies equally to `declared` and `observed` team memberships. After recording, the message says
**how many team memberships** were reached: for a person with two roles, it says 2 — omitting the number
would hide that the action reached more than the clicked row.

And after either one, **the next collection does not recreate the team membership** while the source
keeps showing the person. The source's evidence stays alive, and the screen shows the **two
assertions side by side** in `Source and declaration disagree` — without choosing between them, not
even the most recent. Choosing would hide that the source was not updated, and that is information
about the **organization**, not noise.

### The `Roles` section

The four roles from the SRO catalogue and those created by the organization, with origin and code, and
**how many people** play each one: `people here` and `in the organisation`. The same person
with the same role in two teams counts **once** in the organization column.

A catalogue role does **not** have `Rename` or `Hide`: the name comes from the concept network, and changing it
here would make the platform disagree with the [ontology it publishes](../ontology/sro.md). Hiding
a role that has people is refused, saying **how many** team memberships prevent it — and hiding is a **mark**,
not a removal.

The role created here is the **same** one that appears at `/roles` — one door, one scope. If it
appeared in only one of the two places, there would be two catalogues diverging in silence.

### Whoever does not manage reads everything, and sees no action

The whole list, the roles, the sub-teams — everything is readable by whoever can reach the team. And
**no button**: in its place, the **named refusal**, which says what to do to be able to.

The protection **is not hiding the button**. The verdict is asked again on the server for each action, and
firing the event without going through the form is refused with a reason.

---

## The thresholds

A threshold decides **the number** that whoever manages sees. That is why it **does not live in a code
constant**: it is a decision about what the platform asserts, and changing it is a recorded decision. In a
constant, the threshold changes in a template diff and nobody notices the platform now
asserts something else.

| Threshold | Value | The rule that declares it | Where it appears |
|---|---|---|---|
| **open issue** | **30 days** since opening in the tool | `team.dashboard.thresholds`, rule `open_issue_age`, field `open_days` — [`team_dashboard_thresholds.yaml`](../../priv/knowledge_base/rules/team_dashboard_thresholds.yaml) | card 1 of `Problems now` |
| **review wait** | **7 days** without the first **human** review | `team.dashboard.thresholds`, rule `review_wait`, field `wait_days` — [same file](../../priv/knowledge_base/rules/team_dashboard_thresholds.yaml) | card 2 of `Problems now` |
| **stopped work** | **90 days** since the item was opened | `profile.thresholds`, rule `stale_open_work`, field `stale_days` — [`profile_thresholds.yaml`](../../priv/knowledge_base/rules/profile_thresholds.yaml) | card 4; the `stopped · over 90 d` mark; the `stopped · open > 90 d` column |

**`human`, in the review wait, is part of the definition** and not a detail: a bot review does not
replace someone's reading, and counting it would make the wait disappear exactly where it hurts.

**There is a single stop threshold on the platform.** The team screen's threshold is the **same** as
`profile.thresholds` — the panel and the person's profile read the same value. The alternative, a
second stop threshold, would be the same question with two numbers on different screens: the
platform disagreeing with itself. The reading *"14 days without a state change"* was **refused**
on 2026-09-07 for measuring something else — *silence in the record*, and not *age of the open work*.

And if the rule is missing from the knowledge base, the card says **`not checked`** instead of counting with an
invented threshold.

### A threshold **does not assert delay**

It applies to all three, and it is the caveat that needs to accompany every place where a threshold appears.

**The source does not record deadlines.** None of these numbers means someone took too long.
They mean the item crossed a line the organization chose, and that **someone needs to
look**. A 400-day item may be exactly where it should be; a 20-day one may be
lost.

It is what the knowledge base says, taking care to attribute the refusal to the **record** and never
to the person:

> *"The listing asserts neither delay nor blame: the source does not record deadlines. What can be said is
> that the item has been open for this long and needs a destination — finish it, hand it over, or cancel it
> with a reason."*
>
> — [`profile_thresholds.yaml`](../../priv/knowledge_base/rules/profile_thresholds.yaml),
> `stale_open_work`

The screen repeats the same idea in `What each person is on`: *"**Stale** … is an invitation to ask,
not a verdict."*

---

## Absence is stated. Never zero.

It is not a wording preference — it is the rule that decides what the screen can assert, and it reappears
in every section above:

| What happened | What the screen says | What it does **not** say |
|---|---|---|
| the input is not collected | **`not checked`**, **and what is missing** | `0` |
| it checked and found nothing | `0` **followed by** **`checked, nothing found`** | a mute zero |
| the window had no movement | *"Nothing opened or closed in this window — the items below are stock, not movement."*, and it **does not draw** a sparkline | a flat sparkline at zero |
| sub-team with no work in the period | *"No work observed in the period — which is not the same as zero."* | four zeros on the row |
| no review yet | **`no review yet`** | `0 h`, which would assert an instantaneous review |
| no period in the collected interval | *"nothing to compare — which is not the same as opened zero and closed zero"* | two zero-height bars |
| the team has no declared project | *"This is not a rate of zero: zero would say the pipeline failed."* | `0 %` |
| below the forecast floor | **`No forecast yet.`**, what is missing in numbers, and why refusing says more | a wide range with an 85 % label |
| no simulation run completed | in words | twelve zero-height bars |
| a percentile that does not exist | *"There is **no 85% figure**"* | *"more than N weeks"* |
| nobody declared the role | **`not declared`**, highlighted | a blank cell |
| team membership start unknown | *"empty date = unknown, never today"* | today's date |
| the person has no open task | *"No open task assigned"*, and the person **stays** on the list | the person leaves the list |
| the person has no competence profile | *"**That is a gap in the record**, never a statement about the person."* | "no skills" |
| the mapping rule did not classify | **`—`**, with the reason in the label | `TASK` by default |

The distinction that carries every row is a single one: **`0` asserts that the platform looked and did not
find. Absence asserts that it did not look.** The two lead to different decisions, and a mute
zero makes one pass for the other.

---

## What is not on the screen yet

This section exists because the alternative was to describe, in the present tense, things that whoever opens the screen
will not find.

**The two measures still to be named.** Cards 3 and 7 of `Problems now` say `not checked`
because the query does not exist and the measure has no name in the knowledge base — see
[above](#why-two-of-the-eight-never-have-a-number). The inputs for card 3 **are already collected**;
what is missing is the query and the name.

**Specified, with no planned task** — from feature 060:

| What | User story |
|---|---|
| the **profile of each member** within the team screen | US6 |
| the **tasks and problems per person** as their own section | US8 |
| the **four charts per member** — WIP, promised × delivered, throughput, Monte Carlo | US10 to US12, specified in [`spec-graficos-por-membro.md`](../../specs/060-tela-da-equipe/spec-graficos-por-membro.md) and **with no approved prototype** — and the house does not implement a screen without one |

**`MAINTAINER` does not appear on any screen.** The GitHub administration access level
is still stored in the database and has no visible consumer. It is a gap to be decided — show it where it
belongs, or declare that it is not shown — and it is recorded in the
[v0.6.0 record](../releases/v0.6.0.md).

**The interface is in English, and there are passages in Portuguese in it.** The texts of the knowledge base's
rules — the structure anomalies, the team competence sentences — are
rendered in the language the knowledge base writes them in, which is Portuguese, inside an English
screen. No knowledge base rule has a translation, and translating just one would leave the knowledge base inconsistent. It is
a backlog item in [`portugues-na-interface`](../backlog/portugues-na-interface.md).

The screen's backlog item is [`tela-da-equipe`](../backlog/tela-da-equipe.md), and the questions
the panel does not answer yet are in
[`perguntas-do-painel-da-equipe`](../backlog/perguntas-do-painel-da-equipe.md).

---

## Where to check

| What | Where |
|---|---|
| the requirements and the user stories | [`specs/060-tela-da-equipe/spec.md`](../../specs/060-tela-da-equipe/spec.md) |
| how to check each scenario by hand | [`specs/060-tela-da-equipe/quickstart.md`](../../specs/060-tela-da-equipe/quickstart.md) |
| the decisions about the sub-team card, with the data that decided them | [`decisoes-do-cartao-de-subequipe.md`](../../specs/060-tela-da-equipe/decisoes-do-cartao-de-subequipe.md) |
| the composite team | [`specs/057-tela-da-equipe-complexa/spec.md`](../../specs/057-tela-da-equipe-complexa/spec.md) |
| the acceptance verdict, user story by user story | [v0.6.0 record](../releases/v0.6.0.md) |
| the declared thresholds | [`team_dashboard_thresholds.yaml`](../../priv/knowledge_base/rules/team_dashboard_thresholds.yaml) and [`profile_thresholds.yaml`](../../priv/knowledge_base/rules/profile_thresholds.yaml) |
| the forecast, and what it does not assert | [`flow_completion_forecast.yaml`](../../priv/knowledge_base/measurements/flow_completion_forecast.yaml) |
| the implementation | [`show.ex`](../../lib/the_band_web/live/teams_live/show.ex) and [`problems_now.ex`](../../lib/the_band/teams/problems_now.ex) |
| the dependency model between the 060 user stories | [060 DSM](../modelos/dsm/060-tela-da-equipe.md) |
| the team membership life cycle | [state machine](../modelos/estados/vinculo-de-equipe.md) |
