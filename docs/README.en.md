# Documentation — The Band

The Band is a platform for **semantic integration of Software Engineering data**.
It collects data from the tools used throughout development, harmonizes that data
against reference ontologies, preserves provenance, and answers information
needs with traceable and explainable data.

Scientific basis: doctoral thesis by Paulo Sérgio dos Santos Júnior (UFES, 2023),
*From Continuous Software Engineering Reference Ontologies to the Integration of Data
for Data-Driven Software Development*.

---

## Where to start

| If you want to… | Go to |
|---|---|
| Understand what the system is and how it is organized | [Architecture](architecture/overview.md) |
| Understand the tables and the schemas, and why they have this shape | [Data model](architecture/modelo-de-dados.md) |
| Get the application running, and configure the environment | [Deployment](deployment.md) |
| Understand the conceptual model | [Ontology network](ontology/README.md) |
| Find a specific concept | [Concept index](ontology/concept-index.md) |
| **Integrate with the public API** | [The public API, for integrators](api/README.md) |
| Learn how external data becomes concepts | [Semantic mappings](integrations/mappings.md) |
| Understand where a number comes from | [Information needs and measures](metrics/README.md) |
| Know why a decision was made | [ADRs](adr/README.md) |
| See what has not been decided yet | [RFCs](rfc/README.md) |
| Understand the extensions to the transformation method | [Research](research/extensions-to-one-table-per-kind.md) |
| Know what to build and in which order | [Backlog](backlog/README.md) |
| Start with the GitHub integration | [GitHub → SRO backlog](backlog/github-to-sro.md) |
| Understand how collected CI becomes a concept | [Continuous verification](integrations/verificacao-continua.md) |
| Read what the sprints taught | [Lessons learned](sprints/licoes-aprendidas.md) |
| Contribute code | [AGENTS.md](../AGENTS.md) at the root |
| Open or close a sprint | [sprint-backlog skill](../.claude/skills/sprint-backlog/SKILL.md) |

---

## Documentation map

```text
docs/
├── architecture/     visão da arquitetura, fronteiras internas e modelo de dados
├── ontology/         modelo conceitual — GERADO da base de conhecimento
├── api/              a API pública, para quem vai integrar
├── integrations/     fontes externas e mapeamentos — GERADO
├── metrics/          necessidades de informação e medidas — GERADO
├── processes/        processo de trabalho por feature
├── sprints/          backlogs, reviews e o registro acumulado de lições
├── backlog/          o que construir e em que ordem
├── rfc/              propostas abertas a comentário
├── research/         extensões ao método, com vistas a publicação
└── adr/              decisões arquiteturais registradas
```

### Generated pages

`docs/ontology/`, `docs/integrations/mappings.md` and `docs/metrics/README.md` are
**derived from `priv/knowledge_base/`** and must not be edited by hand — editing
them would make the documentation diverge from the model the system actually loads.

To regenerate them after changing the knowledge base:

```bash
python3 scripts/validate_knowledge_base.py   # a base precisa estar válida antes
python3 scripts/generate_docs.py
```

The equivalent Mix tasks already exist, and they are what the gates call — `mix knowledge.validate`
and `mix knowledge.graph`. The scripts are still useful for one-off use outside the Elixir
project.

**Regenerating is not optional.** Changing the knowledge base without regenerating leaves the
documentation asserting a model the system no longer loads — and that is what happened for nine
features: the page said 12 ontologies when the knowledge base already had 13.

---

## Current state

| Area | State |
|---|---|
| Knowledge base (UFO + SEON + Continuum) | 13 ontologies, 230 concepts, 167 relations, 73 competency questions |
| Semantic mappings | GitHub: 22 mappings (4 derived by issue type), status *proposed* |
| Information needs and measures | 6 and 5 |
| Phoenix application | in internal production — multitenant, 23 LiveView routes, 116 test files |
| Executable connectors | GitHub, declarative in GraphQL + YAML |

The full roadmap is in [AGENTS.md](../AGENTS.md), section 19.

## Interface

[design-system.md](design-system.md) — the grammar of evidence, the palette, the three typographic voices, WCAG 2.0 and mobile-first. **Normative**: it applies to every new screen.

---

## The site for this documentation

These pages are published at **<https://theband.dev/developers/>** by the workflow
[`docs.yml`](../.github/workflows/docs.yml), on every push to `main` that touches
`docs/`.

To preview locally before opening a PR:

```bash
pip install -r ../requirements-docs.txt
mkdocs serve            # http://127.0.0.1:8000
mkdocs build --strict   # o que a CI roda
```

**`--strict` turns a broken link into a build failure**, and it is not decorative
rigor: it is what found **118 broken links** nobody saw — most of them with one
`../` too few, pointing to `docs/specs/` instead of `specs/`.
They were broken on GitHub too, and no review caught them because a broken link
raises no error, it only returns a 404 to whoever clicks it.

### Two things not done here

**Never run `mkdocs gh-deploy`.** The `gh-pages` branch does **not** belong to this site: it
serves the `theband.dev` landing page and carries the `CNAME`. `gh-deploy` wipes the
whole branch, and would take the domain with it. Publishing writes only to
`docs/`, with a step that aborts if the root `CNAME` or `index.html`
disappear.

**Do not rewrite as absolute URLs** the links that point outside `docs/` —
`specs/`, `priv/`, `AGENTS.md`. They stay relative in the source, and the hook
[`scripts/mkdocs_hooks.py`](../scripts/mkdocs_hooks.py) converts them to
GitHub **at build time**. That way the documentation remains navigable in the
repository, offline and under `git grep`.
