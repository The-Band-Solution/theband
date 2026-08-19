# The Band

Plataforma de **integração semântica de dados de Engenharia de Software**.

The Band coleta dados das ferramentas usadas ao longo do desenvolvimento — GitHub,
GitLab, Azure DevOps, Jira, Sonar, CI/CD, monitoramento —, harmoniza esses dados contra
ontologias de referência, preserva a proveniência de cada registro e entrega informação
rastreável para análise e tomada de decisão.

## De onde vem o nome

> Cada serviço da arquitetura é um **músico** que toca um **instrumento** — uma ontologia,
> com seus conceitos, relações e regras. Juntos, os músicos produzem **música** — informação —
> a partir de **notas** — os dados das aplicações — para satisfazer um **público**: a
> organização.
>
> — rodapé da tese, Paulo Sérgio dos Santos Júnior (UFES, 2023)

A metáfora não é decorativa: ela nomeia a diferença entre este sistema e um ETL. Notas não são
música. Os dados do GitHub, do Jira e do Sonar são notas — e só viram informação quando alguém
os toca segundo uma partitura comum, que aqui é a rede de ontologias.

E ela explica por que a plataforma insiste em distinguir **observado** de **derivado**: um
músico que improvisa não está errado, mas quem ouve precisa saber que aquilo não estava escrito.

| na metáfora | na plataforma |
|---|---|
| músico | serviço baseado em ontologia |
| instrumento | ontologia — conceitos, relações e regras |
| nota | dado da aplicação, como a origem o entregou |
| música | informação: o conceito, a medida, a resposta |
| público | a organização que decide com aquilo |

---

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

| Pergunta | Onde ela é respondida |
|---|---|
| Quais projetos apresentam maior retrabalho? Quais equipes têm maior cycle time? | `/process` · `/teams/:id` |
| Quais Pull Requests aguardam mais tempo por revisão? | `/work/changes` |
| Quais componentes concentram mais defeitos? | `/work/repositories/:id` |
| **O que** quebrou no CI — build, teste ou inspeção? | `/work/verifications` |
| Quem integrou código que entrou com verificação vermelha? | `/work/verifications/people` |
| De qual fonte um indicador foi derivado? Como a medida foi calculada? | toda tela, no rótulo de proveniência |

A quarta linha é a que distingue a plataforma de um painel de CI: "passou ou quebrou" é
o que qualquer ferramenta responde. **O que** passou ou quebrou exige o modelo — teste
vermelho tem resposta diferente de inspeção vermelha, porque um é código e o outro é
convenção.

E a quinta linha só existe porque a distinção entre *entrou sem verificação* e *não
medimos* está no esquema, em duas colunas separadas. Com uma coluna só, a organização
apareceria medida onde não é verificada — que é pior do que não ter o número, porque
ninguém procuraria o problema.

## O que The Band não é

Um dashboard. Um data lake sem semântica. Um conjunto de scripts de ETL. Uma cópia dos
modelos de dados das ferramentas. Um chatbot ligado direto ao banco.

---

## Estado do projeto

| Área | Estado |
|---|---|
| Base de conhecimento (UFO + SEON + Continuum) | **13 ontologias, 230 conceitos, 167 relações, 73 perguntas de competência** |
| Mapeamentos semânticos | GitHub: **22 mapeamentos**, status *proposed* |
| Necessidades de informação e medidas | 6 e 5 |
| Aplicação Phoenix | **em produção interna** — multitenant, 23 rotas LiveView, 116 arquivos de teste |
| Conectores executáveis | **GitHub**, declarativo em GraphQL + YAML |
| Documentação | arquitetura, ontologias, mapeamentos, métricas, ADRs, processo, sprints |

O modelo veio antes, e continua vindo: nenhum dado entra no domínio sem mapeamento
declarado. O que mudou é que agora há uma instalação real medindo três organizações — e
os números dela estão na [landing page](https://the-band-solution.github.io/theband/),
com a data em que foram conferidos.

### O que a plataforma já coleta e modela

| Dado do GitHub | Conceito da rede | Onde aparece |
|---|---|---|
| issues, com o tipo declarado e a estrutura de sub-issues | `sro.user_story` · `sro.epic` · `osdef.defect` | `/work/issues/:id` |
| sprints, e os planos que nunca viraram sprint | `sro.sprint` | `/process` |
| quadros, campos e valores do Projects v2 | `sro.sprint_backlog` | `/boards` |
| commits, com **todos** os autores de cada um | `cmpo.commit_artifact_copy` | `/people/:id/commits` |
| versões de arquivo por commit | `spo.artifact` | `/work/files` |
| pull requests, revisões e branches | `cmpo.change_request` · `qapo.artifact_evaluation` | `/work/changes` |
| execuções de CI, com a fase que o resultado decide | `ciro.*` · `cdro.*` | `/work/verifications` |
| pessoas, equipes e papéis | `eo.*` | `/people` · `/teams` · `/roles` |

Cada linha tem mapeamento em `priv/knowledge_base/mappings/github/`, com grau de
equivalência, justificativa e **limitações declaradas** — e é a limitação que costuma
virar a próxima feature.

---

## Estrutura

```text
AGENTS.md                instruções normativas para agentes de codificação
lib/the_band/            domínio — contextos, ingestão, promoção semântica, jobs
lib/the_band_web/        LiveViews, componentes, páginas de erro
priv/knowledge_base/     base de conhecimento em YAML (fonte da verdade do modelo)
priv/connectors/         consultas GraphQL e declarações YAML dos conectores
priv/repo/migrations/    esquema, com o porquê de cada coluna no @moduledoc
test/                    116 arquivos de teste
docs/                    documentação — comece por docs/README.md
docs/sprints/            backlogs, reviews e o registro acumulado de lições
scripts/                 validação da base e geração de docs
specs/                   32 features, no formato do GitHub Spec Kit
.specify/                GitHub Spec Kit
```

A migração carrega o **porquê** da coluna no `@moduledoc`, não só o `add`. Coluna cujo
motivo não está escrito em algum lugar volta como pergunta seis meses depois — e a
resposta já não está na cabeça de ninguém.

## Documentação

| | |
|---|---|
| Visão geral e mapa | [docs/README.md](docs/README.md) |
| Arquitetura | [docs/architecture/overview.md](docs/architecture/overview.md) |
| Rede de ontologias | [docs/ontology/README.md](docs/ontology/README.md) |
| Índice de conceitos | [docs/ontology/concept-index.md](docs/ontology/concept-index.md) |
| Mapeamentos semânticos | [docs/integrations/mappings.md](docs/integrations/mappings.md) |
| Como o CI coletado vira conceito | [docs/integrations/verificacao-continua.md](docs/integrations/verificacao-continua.md) |
| Necessidades de informação e medidas | [docs/metrics/README.md](docs/metrics/README.md) |
| Decisões arquiteturais | [docs/adr/README.md](docs/adr/README.md) |
| Processo por feature | [docs/processes/feature-workflow.md](docs/processes/feature-workflow.md) |
| Lições acumuladas dos sprints | [docs/sprints/licoes-aprendidas.md](docs/sprints/licoes-aprendidas.md) |
| Design system das telas | [docs/design-system.md](docs/design-system.md) |
| Sprint Backlog (skill) | [.claude/skills/sprint-backlog/SKILL.md](.claude/skills/sprint-backlog/SKILL.md) |

## Base de conhecimento

O modelo conceitual não vive no código: vive em `priv/knowledge_base/`, como YAML
versionado, validado e revisado — ver
[ADR 0002](docs/adr/0002-yaml-como-base-de-conhecimento.md).

```bash
mix gates                       # os treze, na ordem do CI, abortando no primeiro
mix gates --list                # os nomes, sem rodar
mix gates --from testes         # retoma de um gate, sem repetir o que passou
```

`mix gates` é a **única definição** dos gates: o CI chama a mesma task, então não
existe uma segunda lista para ficar desatualizada. **O veredicto é o código de saída**, e
nunca a última linha da saída — a forma correta de ler é

```bash
mix gates > /tmp/gates.log 2>&1; ec=$?; tail -30 /tmp/gates.log; exit $ec
```

porque `mix gates | tail` descarta o código de saída do `mix` e devolve o do `tail`, que
é sempre zero. Ela provisiona `.venv` na
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

As tasks Mix equivalentes já existem, e são o que os gates chamam:

```bash
mix knowledge.validate          # valida a base, com o mesmo contrato do script
mix knowledge.graph             # gera o grafo da rede
mix qa.reports                  # cobertura, Credo, Sobelow e auditoria de dependências
```

## Stack

Elixir · Phoenix · LiveView · Ecto · PostgreSQL · Oban · Req · ExUnit · Mox · Credo ·
Dialyzer · Sobelow · Docker Compose · Phoenix Releases

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
