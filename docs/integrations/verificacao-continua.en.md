# Continuous verification — from GitHub to the ontology network

How a GitHub Actions run becomes a concept, and why the verification's state
lives in three different places.

This page is written by hand. The mapping tables in
[mappings.md](mappings.md) are generated from the knowledge base — here is the **why** that the table does not
carry.

---

## The two axes, and why to separate them

A CI dashboard answers "passed or broke". That does not need an ontology. The question
that does is **what** passed or broke — because a red test has a different answer
from a red inspection: one is code, the other is convention.

That is why the modeling has two independent axes, and a third one that comes from another API:

| Axis | Question | Comes from |
|---|---|---|
| **type** | which process this run materializes | the **jobs**, derived |
| **phase** | how that process ended | the run's `status` + `conclusion` |
| **trigger** | what fired it | the run's `event` |

Crossing them is what produces a measure. Collapsing them produces a number that looks reliable and is
not.

---

## Axis 1 — the type is derived from the jobs, never asserted by the run

Version 1 of the mapping asserted that every workflow run is an occurrence of a
continuous integration process. **The data proved it wrong.** Of the 1.051 runs collected on
2026-08-18, **399 are neither verification nor deployment**: `Sync to GitLab`,
`Sprint Rollover`, `Card de promoção`.

The rule that decides is in
[`priv/knowledge_base/rules/github_ci_job_routing.yaml`](../../priv/knowledge_base/rules/github_ci_job_routing.yaml),
with `confidence: low` **declared**, and the reason for the low confidence is written in it:
GitHub does not declare which component process a job executes, and the name is a convention of whoever
wrote the workflow.

| name or step matches | concept | ontology |
|---|---|---|
| `build` `compile` `assets` `docker` `image` | `ciro.continuous_build_process` | CIRO |
| `test` `spec` `coverage` `e2e` `pytest` `jest` | `ciro.continuous_test_process` | CIRO |
| `lint` `credo` `sobelow` `dialyzer` `gates` `sast` | `ciro.continuous_inspection_process` | CIRO |
| `deploy` `rollout` `helm` `kubectl` `argocd` | `cdro.deployment_activity` | **CDRO** |
| `release` `publish` `delivery` | `cdro.delivery_activity` | **CDRO** |

Three decisions in that table, and none of them is a detail.

### It returns all that match, not the first

A job that tests and inspects materializes **two** components. Choosing one and discarding the
others would make the platform assert that the job only tests when it also inspects.

When more than one matches, the job is reported as `ci.ap01.monolithic_job` — and the
grouping is a fact about the **script**, not about the run. That is why the screen names the
file, not the job name: two repositories with a job called `build` are not the same
row. The most frequent antipattern in the installation is this project's own —
`.github/workflows/ci.yml`, job `quality-gates`, 352 runs.

The cost of the grouping is precisely that this page's question has no answer: the
platform does not know what broke.

### Deploy leaves CIRO

`deploy` is not a continuous integration component. It is CDRO. Keeping both in the same
ontology would make the integration measure include deployment, and deployment has another
cycle, another person responsible and another risk.

### With no recognized component, the run has no type

The network has no concept for board automation. Forcing `Card de promoção` into a verification
concept would produce a wrong measure; leaving it **without a type** is a named absence, and the
screen never writes the two situations with the same sentence.

### The patterns are narrow on purpose

`artifact` matched `Upload Pages artifact` and produced **238 false deliveries**.
`package` matched `Install npm packages`. Both were removed.

The asymmetry is the reason: an unrecognized pattern someone fixes — it shows up on screen as a
gap and becomes an issue. A wrongly recognized pattern **becomes a measure**, and nobody looks for the
error in a number that already looks like an answer.

---

## Axis 2 — the phase comes from `status` plus `conclusion`

Implemented in
[`classification.ex`](../../lib/the_band/verification/classification.ex).

| GitHub | CIRO concept |
|---|---|
| `status` in `queued` `in_progress` `waiting` `pending` | in progress — **no phase** |
| `conclusion: success` | `ciro.successful_continuous_integration_process` |
| `conclusion: failure` | `ciro.unsuccessful_continuous_integration_process` |
| `conclusion: cancelled` | `ciro.interrupted_continuous_integration_process` |
| `conclusion: skipped` | `ciro.unperformed_continuous_integration_process` |
| `conclusion: timed_out` | `ciro.expired_continuous_integration_process` |

**`cancelled` and `skipped` are not failure.** Version 1 of the mapping said they were, and
the five distinct phases were the fix. A cancelled run says nothing about the
code; counting it as a failure makes the failure rate measure human interruption.

The model was validated at scale, and scale changed what it shows: in the first
repository there were 55 failures and 54 cancellations, and `unperformed` was **zero**. Across the 15.375
runs there are 2.633 failures, 248 cancellations — and `unperformed` only exists in volume.

A run in progress gets no phase, and does not get **success**. Absence of error is not a
result.

---

## Axis 3 — the state of what went in comes from another API

`workflow_run` covers one verification layer. GitHub has three:

| layer | API | who publishes |
|---|---|---|
| `workflow_run` | Actions | Actions itself, per workflow run |
| `check_run` | Checks | Actions per **job**, and third-party apps |
| `status` | Statuses (old) | an external service |

Collecting only the first leaves two invisible. And the question the `ci.ap03` maxim asks —
*who integrated code with red verification* — is about the **tip at the moment of the merge**,
not about any run on the branch.

### Why matching by `head_sha` does not work

A run's `head_sha` is the tip of the branch **at that instant**. That produces errors in
both directions, and the direction that matters is not the one it seems.

**It lets things through**: a branch that received more commits afterwards has runs pointing to
SHAs that are no longer the tip, and the matching finds no run for the tip.

**And it overcounts, which is the worst.** Any red run on *any* commit of the PR
makes the matching mark the request as integrated red — including the red one that
was fixed before the merge, which is the process working.

### `statusCheckRollup` is a commit field, and it aggregates the three layers

The query asks for `commits(last: 1)` of the pull request — the tip at merge. It is the one that
matters, because the `ci.ap03` maxim speaks of **integrated** with red, and what was
integrated is the tip.

Measured on 2026-08-20 over the **4.878 integrated requests, all measured** — none
pending, which matters because the previous version of this page compared against 763 still to be
measured:

| | red |
|---|---|
| matching by `head_sha` | 323 |
| `statusCheckRollup` of the tip | 261 |
| **in both** | **115** |
| union | 469 |

The overlap of 115 in 469 is the number that says it all: **they are not two measures of the same
phenomenon with different precisions — they are two phenomena.**

Of the 208 that only the matching finds, **198 are green at the tip**. Checked on `#13`: 33
commits, three red runs in the middle, a green tip with 2 contexts. The matching
called that a red integration.

Another 10 of those 208 **had no check at all** at the tip. The matching found red in the
middle and the tip went in with no verification — both things are true, and only the second describes
what was integrated.

Of the 146 that only the rollup finds, the cause is the layer: `check_run` and `status` do not appear in
`workflow_run`.

### Two columns, because null is not unknowing

Declared in
[`20260819070000_add_merged_check_state.exs`](../../priv/repo/migrations/20260819070000_add_merged_check_state.exs):

```text
merged_check_state = nil  E  merged_check_contexts = 0    →  nenhum check rodou
merged_check_contexts = nil                              →  não medimos ainda
```

With a single column, *"we did not collect"* and *"there was nothing to collect"* would get the same
null — which is exactly the confusion this house fights the most.

And the distinction is not academic: **2.024** of the 4.878 integrated requests went in with no check
at all — 41%. By the old path they showed up as "cannot tell". They are the opposite thing —
**a finding about the process**, not our gap. The organization would appear measured where it is not
verified, which is worse than not having the number, because nobody would look for the problem.

The values stay **raw**: `SUCCESS`, `FAILURE`, `PENDING`, `ERROR`, `EXPECTED`. The
translation into a CIRO phase happens on reading, never in place of what the source said.

---

## What the screen does with this

| Screen | What it answers |
|---|---|
| `/work/verifications` | phases, components, coverage by the tip, monolithic jobs per file |
| `/work/verifications/:id` | one run, its jobs and the concepts of each one |
| `/work/verifications/people` | who proposed and who integrated red, by participation |

### Red on the proposal branch does not count

It is the process **working**: verification caught the problem before integrating, which is what
it exists for. Counting it would produce the measure backwards — whoever pushes early and uses
CI as a safety net would accumulate reds, and whoever develops locally and pushes once would appear
flawless.

### The two participations do not add up

Submitting (`cmpo.stakeholder_submitted_change_request`) and integrating
(`cmpo.stakeholder_performed_checkin`) are distinct acts, and the screen forces choosing one.
Whoever proposed may have opened the red request on purpose, to ask for help. **Whoever
integrated decided it would go in that way** — and the definition of `cmpo.change_request` already said that
the PR "is not the merge, nor the approval decision".

### A small base gets no rate

Below ten verifiable requests the screen shows the count and **not** the percentage.
Three out of four is 75% and means nothing — and the cut is **declared on the screen**, because
a hidden cut makes the reader think it is a property of the data.

---

## Open limitations

- **The type's confidence is low, and stays low.** It depends on the name someone gave the
  job. There is no way to raise it without GitHub declaring the process — and declaring high confidence
  where it does not exist would be worse than the gap.
- **CIRO does not declare a relation** between `ciro.continuous_integration_process` and
  `cmpo.source_repository`. The run points to the repository and nothing materializes the
  link in the network.
- **`updated_at` approximates the end**, but it is not the exact instant it ended.
- **Real deployment is not observed yet.** `cdro.deployment_activity` is derived from the
  job name, and the deployment process lives in ArgoCD — which is not collected (issue
  #442).
- **Co-authorship has no single attribution.** 1.203 of 16.416 commits have more than one author
  through the `Co-Authored-By` trailer, and the network declares one participation for each.

Numbers checked on the installation of three organizations on 2026-08-19.
