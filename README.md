# The Band

Plataforma de **integração semântica de dados de Engenharia de Software**.

The Band coleta dados das ferramentas usadas ao longo do desenvolvimento — GitHub,
GitLab, Azure DevOps, Jira, Sonar, CI/CD, monitoramento —, harmoniza esses dados contra
ontologias de referência, preserva a proveniência de cada registro e entrega informação
rastreável para análise e tomada de decisão.

Base científica: tese de doutorado de **Paulo Sérgio dos Santos Júnior** (UFES, 2023),
*From Continuous Software Engineering Reference Ontologies to the Integration of Data
for Data-Driven Software Development*, orientada por Monalessa Perini Barcellos e
coorientada por João Paulo Andrade Almeida.

---

## O problema

Somar números vindos de ferramentas que discordam sobre o que estão contando produz
indicadores que parecem confiáveis e não são. Um Pull Request não é um merge. Uma issue
do Jira pode ser uma user story, um requisito ou um defeito. Um *code smell* não é um
defeito.

The Band trata isso pela semântica: cada dado externo é mapeado para um conceito de uma
ontologia de referência, com grau de equivalência, justificativa e limitações
declaradas — e mantém o vínculo com sua origem. Assim o sistema responde não só *"qual o
cycle time da equipe"*, mas *"de onde esse número veio, como foi calculado e quais dados
o sustentam"*.

## Perguntas que o sistema existe para responder

- Quais projetos apresentam maior retrabalho? Quais equipes têm maior cycle time?
- Quais Pull Requests aguardam mais tempo por revisão?
- Quais componentes concentram mais defeitos? Quais commits estão ligados a falhas de build?
- De qual fonte um indicador foi derivado? Como a medida foi calculada?

## O que The Band não é

Um dashboard. Um data lake sem semântica. Um conjunto de scripts de ETL. Uma cópia dos
modelos de dados das ferramentas. Um chatbot ligado direto ao banco.

---

## Estado do projeto

| Área | Estado |
|---|---|
| Base de conhecimento (UFO + SEON + Continuum) | **12 ontologias, 219 conceitos, 141 relações, 64 perguntas de competência** |
| Mapeamentos semânticos | GitHub: 13 mapeamentos, status *proposed* |
| Necessidades de informação e medidas | 3 e 3, como referência |
| Documentação | arquitetura, ontologias, mapeamentos, métricas, ADRs, processo |
| Aplicação Phoenix | **não iniciada** — feature `001 Fundação Phoenix e governança` |
| Conectores executáveis | **não iniciados** — feature `025 Motor declarativo GraphQL/YAML` |

O modelo conceitual está completo e validado. O código da aplicação ainda não começou —
por decisão de processo: o modelo vem antes.

---

## Estrutura

```text
AGENTS.md                instruções normativas para agentes de codificação
docs/                    documentação — comece por docs/README.md
priv/knowledge_base/     base de conhecimento em YAML (fonte da verdade do modelo)
scripts/                 validação da base e geração de docs
.specify/                GitHub Spec Kit
```

## Documentação

| | |
|---|---|
| Visão geral e mapa | [docs/README.md](docs/README.md) |
| Arquitetura | [docs/architecture/overview.md](docs/architecture/overview.md) |
| Rede de ontologias | [docs/ontology/README.md](docs/ontology/README.md) |
| Índice de conceitos | [docs/ontology/concept-index.md](docs/ontology/concept-index.md) |
| Mapeamentos semânticos | [docs/integrations/mappings.md](docs/integrations/mappings.md) |
| Necessidades de informação e medidas | [docs/metrics/README.md](docs/metrics/README.md) |
| Decisões arquiteturais | [docs/adr/README.md](docs/adr/README.md) |
| Processo por feature | [docs/processes/feature-workflow.md](docs/processes/feature-workflow.md) |

## Base de conhecimento

O modelo conceitual não vive no código: vive em `priv/knowledge_base/`, como YAML
versionado, validado e revisado — ver
[ADR 0002](docs/adr/0002-yaml-como-base-de-conhecimento.md).

```bash
python3 scripts/validate_knowledge_base.py   # valida a base
python3 scripts/generate_docs.py             # regenera docs/ontology, integrations, metrics
```

As páginas em `docs/ontology/`, `docs/integrations/mappings.md` e `docs/metrics/` são
**geradas** e não devem ser editadas à mão.

Quando a aplicação Elixir existir, esses scripts dão lugar a `mix knowledge.validate` e
`mix knowledge.docs`, com o mesmo contrato.

## Stack prevista

Elixir · Phoenix · LiveView · Ecto · PostgreSQL · Oban · Req · ExUnit · Mox · Credo ·
Dialyzer · Docker Compose · Phoenix Releases

Monólito modular multitenant. Sem microserviços, broker externo, banco de grafos ou
frontend separado na fundação — ver [ADR 0001](docs/adr/0001-monolito-modular-elixir.md).

## Contribuindo

Leia [AGENTS.md](AGENTS.md) antes de qualquer alteração. Toda mudança passa pelo ciclo
do GitHub Spec Kit, tem issue própria, branch própria e Pull Request revisado por
alguém que não a implementou.
