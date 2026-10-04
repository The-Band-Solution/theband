# Per-feature work process

Every change in The Band goes through the **GitHub Spec Kit** cycle. There is no alternative
path: code without a specification, plan, tasks and issue does not go in.

Spec Kit is already installed in this repository (`.specify/`, `.claude/skills/`),
version `0.15.1.dev0`, integration `claude`.

## Cycle

```text
Necessidade
→ Discovery
→ Feature Request
→ /speckit-specify        cria specs/<n>-<feature>/spec.md
→ /speckit-clarify        de-risca ambiguidades (opcional, antes do plan)
→ /speckit-checklist      valida completude dos requisitos (opcional)
→ APROVAÇÃO HUMANA
→ /speckit-plan           plano técnico, data model, contratos
→ revisão arquitetural
→ revisão semântica       (pode bloquear a feature)
→ /speckit-tasks          tasks.md ordenado por dependência
→ /speckit-taskstoissues  cria as GitHub Issues
→ /speckit-analyze        consistência entre spec, plan e tasks
→ SPRINT BACKLOG          obrigatório — ver abaixo
→ branch
→ /speckit-implement      execução das tarefas
→ testes e quality gates
→ /speckit-converge       verifica o que ficou faltando e reabre como tarefa
→ Pull Request
→ revisão independente
→ merge
```

> **Mind the names.** In this version the commands use a hyphen (`/speckit-specify`), not a
> dot. Check with `specify version` and the skills listing before assuming another
> format — and never invent a command that does not exist.

## Sprint Backlog — mandatory before implementing

Between `/speckit-analyze` and the first line of code there is a step that **is not
optional**: the `sprint-backlog` skill.

```
/sprint-backlog
```

It does three things Spec Kit does not do:

**It reads the lessons from previous sprints.** `docs/sprints/licoes-aprendidas.md` is
consulted before selecting scope, and the backlog records which lessons were
applied. Without this step the record becomes decorative and the same mistake repeats —
which is the most expensive mistake, because it was already known.

**It materializes the sprint on GitHub.** The sprint becomes a Projects v2 iteration; user
stories, epics and tasks become typed issues organized hierarchically through sub-issues,
following the same types that `priv/knowledge_base/rules/github_issue_type_routing.yaml`
expects. That makes the repository itself a source The Band can
ingest — the model comes to be validated against real data instead of synthetic data.

**It closes the cycle at the end.** `sprint-review.md` separates what was done from what was
not, and treats a refused deliverable as a category of its own — a completed task whose
result did not pass the criteria is not a completed task, and hiding it destroys the
rework measure the product exists to compute.

| Artifact | When | SRO concept |
|---|---|---|
| `docs/sprints/NNN/sprint-backlog.md` | on opening | `sro.sprint_backlog` |
| `docs/sprints/NNN/sprint-review.md` | on closing | performed tasks and deliverables |
| `docs/sprints/licoes-aprendidas.md` | cumulative | `sro.retrospective_meeting` |

> **Implementing without an open sprint backlog is a process violation.** If someone —
> a person or an agent — asks for direct implementation, the correct answer is to build the
> backlog first and present it for approval.

## What an ontological feature needs to identify

Before any code:

- main ontology and the ontologies it depends on;
- concepts added or changed;
- relations, cardinalities and constraints;
- affected competency questions;
- knowledge base YAMLs created or changed;
- external mappings involved;
- necessary migrations;
- planned conceptual tests;
- **semantic risks** — where the model may be being distorted to fit the data.

## Definition of Ready

A feature is ready for implementation when: Discovery done, Feature Request
existing, `spec.md` approved, clarify completed, checklist approved, `plan.md`
approved, ontologies and dependencies identified, YAMLs planned, mappings
reviewed, `tasks.md` approved, Issues created, risks identified, testing
strategy defined and analyze without critical inconsistencies.

## Definition of Done

A feature is done when: acceptance criteria met, tasks completed,
Issues updated, code implemented, YAMLs created or updated **and validated**,
competency questions tested, tests passing, Credo and Dialyzer approved,
migrations tested, semantic mapping reviewed, documentation updated, convergence
verified, PR approved **by another person or agent**, pipeline green, merge done
and Issues closed.

## Branches and commits

```text
feature/<issue>-<descricao>    fix/<issue>-<descricao>    refactor/<issue>-<descricao>
docs/<issue>-<descricao>       test/<issue>-<descricao>   chore/<issue>-<descricao>
```

Conventional Commits, with scope = ontology or subsystem:

```text
feat(sro): add user story knowledge definition
feat(github): add pull request connector definition
test(knowledge): validate semantic mappings
fix(cmpo): prevent duplicate commit ingestion
docs(ontology): document review semantics
```

## Quality gates before the PR

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test
mix knowledge.validate
mix knowledge.graph
mix knowledge.test
```

While the Elixir project does not exist, the knowledge base is validated by
`python3 scripts/validate_knowledge_base.py`, playing the same role of quality gate.

## What the Pull Request needs to state

Feature, specification, plan, issues, affected ontologies, changed concepts and relations,
changed YAMLs, table of semantic mappings
(source | ontology | concept | equivalence | limitation), migrations, tests,
quality gate results, validated competency questions, evidence and residual
risks.

## A non-negotiable rule

Whoever implements does not approve their own PR, and no agent declares success without evidence
— test output, log or capture. In the face of relevant semantic uncertainty, the work
stops and the alternatives are presented: a wrong mapping contaminates every
metric derived from it, and the error only shows up after someone has already decided based on it.
