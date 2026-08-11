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
| Sprint Backlog (skill) | [.claude/skills/sprint-backlog/SKILL.md](.claude/skills/sprint-backlog/SKILL.md) |

## Base de conhecimento

O modelo conceitual não vive no código: vive em `priv/knowledge_base/`, como YAML
versionado, validado e revisado — ver
[ADR 0002](docs/adr/0002-yaml-como-base-de-conhecimento.md).

```bash
mix gates                       # os nove, na ordem do CI, abortando no primeiro
mix gates --list                # os nomes, sem rodar
mix gates --from testes         # retoma de um gate, sem repetir o que passou
```

`mix gates` é a **única definição** dos gates: o CI chama a mesma task, então não
existe uma segunda lista para ficar desatualizada. Ela provisiona `.venv` na
primeira execução — sem ele o validador Python **não valida a forma** dos YAML,
avisa que pulou, e sai diferente de zero. Quem lê a saída com `| tail` vê o aviso
como nota de ambiente e conclui que passou. Foi o que aconteceu dez vezes até o CI
reprovar seis mapeamentos ([L23](docs/sprints/licoes-aprendidas.md)).

Para rodar o **workflow inteiro** na máquina, com o mesmo runner do GitHub — útil
para validar mudanças no `ci.yml` em si, já que os gates em si `mix gates` já cobre:

```bash
brew install act
docker stop the_band_postgres    # o serviço do workflow publica a 5432
act -j quality-gates             # configuração em .actrc, versionada
docker start the_band_postgres
```

O `docker stop` é necessário e não é detalhe: o workflow declara um serviço
PostgreSQL que publica a porta 5432, e o Postgres de desenvolvimento já a ocupa.
Sem liberar, o `act` falha em *Set up job* com `port is already allocated` — que
parece erro de workflow e é conflito de porta.

`act -n` (dry-run) **não funciona** neste workflow: a versão 0.2.89 tem um
`nil pointer dereference` ao inspecionar containers de serviço em modo dry-run.
Rode sem `-n`.

Os scripts avulsos continuam existindo para uso pontual:

```bash
.venv/bin/python scripts/validate_knowledge_base.py   # valida a base
.venv/bin/python scripts/generate_docs.py             # regenera docs/*
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

Antes de implementar, rode a skill `sprint-backlog`. Ela lê as lições dos sprints
anteriores, materializa o sprint como iteration no GitHub com as issues tipadas
como épico, user story e tarefa, e produz o backlog para aprovação. Ao encerrar,
registra o que foi e o que não foi entregue, e consolida as lições que alimentam
o sprint seguinte.

```
/sprint-backlog
```
