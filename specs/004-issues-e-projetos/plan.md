# Plano de implementação: issues e projetos das organizações observadas

**Feature**: [004-issues-e-projetos](spec.md) · **Branch**: `feature/004-issues-e-projetos`
**Criado**: 2026-08-11 · **Pesquisa**: [research.md](research.md)

## Summary

Coletar as issues dos repositórios de cada organização observada e os projetos
(Projects v2) da organização, promovendo o que a rede ontológica reconhece e
**deixando visível o que não foi promovido**.

A feature entrega três coisas que o produto não tem hoje: o **trabalho** (issues,
classificadas por estrutura e não por rótulo), o **recorte temporal** (sprint, a
partir de iterações já iniciadas) e a **ordem** (product backlog e sprint backlog,
derivados da atribuição de iteração).

O que a torna diferente das anteriores: pela primeira vez a plataforma **recusa
promover** dado que coletou, e a recusa é parte da entrega — não um efeito
colateral.

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2, OTP 29 |
| Web | Phoenix 1.8.9 + LiveView |
| Persistência | Ecto + PostgreSQL 17 |
| Jobs | Oban 2.23 |
| Fonte | GitHub GraphQL v4 — issues, sub-issues, ProjectV2 |
| Testes | ExUnit + Mox na borda HTTP |
| Base de conhecimento | 12 ontologias; **4** com `ontouml_stereotype` |

**Nada de novo na stack.** O runtime declarativo do conector já resolve paginação
por cursor, checkpoint, limite de consumo, retentativa e preservação de payload —
acrescentar entidade é declarar YAML mais arquivo `.graphql`, sem código por
entidade.

**Duas dependências de disponibilidade da API**, e as duas precisam ser detectadas
e declaradas, nunca descobertas por coleta vazia:

| Recurso | Se faltar |
|---|---|
| tipos de issue (`issueType`) | a regra de roteamento não decide, e o fallback `skip` vale para tudo |
| sub-issues | a distinção épico/atômica **não é feita**, e isso é declarado. Cair para heurística de lista em markdown seria hierarquia plausível e errada |

## Constitution Check

Constituição v1.2.0, os oito princípios, um a um.

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo entra na rede. Os seis alvos existem: `cmpo.source_repository`,
`sro.epic`, `sro.atomic_user_story`, `sro.intended_scrum_development_task`,
`osdef.defect`, `sro.sprint`, `sro.sprint_backlog`, `sro.product_backlog`.

A auditoria de conceitos (R7) confirmou que **issue não é conceito próprio** — é
promovida a `sro.user_story` e às rotas por tipo. As três correspondências foram
fixadas pela pessoa mantenedora em R8:

```
repository ──▶ cmpo.source_repository
issue      ──▶ sro.user_story  (+ rotas: Bug → osdef.defect, Task → intended task)
project    ──▶ spo.software_project
```

Sobre o projeto, minha leitura em R7 era outra — que um quadro do Project v2 não é
um projeto de software — e a decisão foi a correspondência direta. A imprecisão
que eu apontei fica como limitação declarada no mapeamento
(`semantics.equivalence: partial`): esta organização tem dois quadros, e a
plataforma contará dois projetos. A alternativa recusada era pior — exigir
declaração para toda promoção deixaria projeto não declarado invisível a todas as
consultas de escopo, e lacuna silenciosa é pior que imprecisão medida.

`sro.scrum_project` continua por declaração, porque **adotar Scrum não é
observável**: um projeto com iterações pode ser Kanban com recorte temporal.

**Uma lacuna a fechar antes do código**: `cmpo.source_repository` é `subkind` de
`sys_swo.loaded_software_system_copy`, e a SYS_SWO tem 11 conceitos sem
`ontouml_stereotype`. Sem anotá-los, o repositório não tem tabela para onde ser
elevado. É a primeira fase.

### II. Fonte externa não é domínio — **conforme, e é o eixo da feature**

A fronteira decide onde cada tabela mora:

| Camada de plataforma | Domínio |
|---|---|
| issue coletada, com o tipo declarado pelo GitHub | o conceito promovido |
| promoção, com regra, versão e divergência | — |
| projeto observado, itens, definições e valores de campo | sprint, sprint backlog, product backlog |
| repositório inacessível, repositório excluído | repositório observado |

**Uma issue não vira uma tabela de domínio.** Ela é preservada como payload e como
registro de coleta, e o que entra no domínio é o conceito para o qual foi promovida.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme**

Application Reference em toda entidade coletada, e o identificador é o **global**,
nunca o número dentro do repositório (FR-008) — issue movida entre repositórios
muda de número e não de identidade.

A promoção carrega a regra e a versão que decidiram (FR-012). É o que permite
responder "por que esta issue foi classificada assim em março" depois de a regra
mudar — e ela vai mudar, tem `status: proposed`.

### IV. Semântica declarada em YAML versionado — **conforme**

Três artefatos de conhecimento, nenhum em código:

| Artefato | O que declara |
|---|---|
| `mappings/github/sro/*.yaml` | issue → conceito, iteração → sprint, itens → backlogs |
| `mappings/github/spo/project.yaml` | projeto → `spo.software_project`, com a equivalência parcial justificada |
| `rules/tenants/<tenant>.yaml` | nomes de tipo próprios do tenant, e o mapeamento campo → atributo |
| anotação da SYS_SWO | os 11 estereótipos que faltam |

O mapeamento campo→atributo **por tenant** é o que impede o antipadrão de
mapeamento por semelhança de nome: "Priority" não é `importance`.

### V. Monólito modular multitenant — **conforme**

`tenant_id` explícito em toda tabela nova. A coleta de issues é escopada pela
ferramenta conectada, que já é escopada por tenant e organização.

### VI. Spec Kit e sprint backlog antes do código — **conforme, com uma ressalva**

`spec.md` (43 FR, 14 SC), checklist 16 de 16, `research.md` com sete questões,
este plano. `tasks.md` vem em seguida.

**A ressalva**: no sprint 003 eu implementei antes de abrir sprint, o que a skill
`sprint-backlog` proíbe na primeira linha. Aqui o sprint é aberto antes da
primeira linha de código.

### VII. Quality gates e revisão independente — **conforme, com lacuna declarada**

Nove gates. Dois deles ganham peso nesta feature:

- **derivação reproduzível** — anotar a SYS_SWO muda a saída de duas ontologias; o
  gate é o que prova que a mudança é a pretendida;
- **validador Python** — mantém a paridade das verificações da base.

**Lacuna**: a aprovação de revisão registrada segue bloqueada por ferramenta. Com
uma identidade no repositório, o autor não aprova o próprio PR. Declarada, nunca
marcada como cumprida.

### VIII. Desenho que o problema justifica — **conforme**; ver a seção abaixo

## Registro dos padrões introduzidos (princípio VIII)

Três respostas para cada: qual problema concreto resolve, se o problema **existe
agora**, e o que fica pior.

### P1 — Tabela de promoção separada da issue coletada

| | |
|---|---|
| **Problema** | FR-013 exige registrar o conceito declarado, o conceito derivado e o motivo da divergência. Uma coluna `promoted_to` guardaria só o resultado |
| **Existe agora?** | **Sim, e é mensurável.** No projeto deste repositório existem issues tipadas `Feature` que são épicos por terem sub-issues, e a #98 é um épico declarado com partes. A divergência não é hipótese |
| **O que piora** | duas tabelas para responder "o que é esta issue", e toda consulta de escopo passa por um `join`. A tela de issues fica mais lenta que uma leitura de coluna |

### P2 — Tabela de vínculos **recusados**

| | |
|---|---|
| **Problema** | FR-017 manda nomear o caminho que fecha um ciclo. Um vínculo descartado em memória não tem como ser nomeado depois da coleta |
| **Existe agora?** | **É previsão.** Não observei ciclo de sub-issues em dado real. Mas `sro.rule04` o proíbe com `enforcement: test_and_db_constraint`, e o axioma diz explicitamente que constraint de banco não pega ciclo transitivo — a verificação tem de existir no comando, e o resultado dela precisa ir para algum lugar |
| **O que piora** | uma tabela que pode ficar vazia para sempre. Se depois de duas coletas reais ela continuar vazia em todos os tenants, o registro pode passar a ser uma contagem no relatório do `sync` em vez de tabela |

Declarado como previsão de propósito: o princípio VIII manda distinguir, e mentir
que o problema já existe seria a forma fácil de aprovar o padrão.

### P3 — Definição de campo e valor de campo em tabelas separadas

| | |
|---|---|
| **Problema** | FR-023 pede o valor de cada campo em cada item, e FR-027 exige que renomear o campo não crie campo novo. Um `jsonb` na linha do item perde as duas coisas: a chave seria o nome, e "quais itens têm valor neste campo" varreria todos os itens |
| **Existe agora?** | **Sim.** O projeto deste repositório tem 17 campos, e um deles — `Priority` — já mudaria de nome se alguém traduzisse o quadro |
| **O que piora** | três tabelas para ler o que a API devolve como um objeto só, e o custo de escrita por item cresce com o número de campos configurados |

### P4 — Não materializar a classificação épico/atômica

Não é padrão novo: é a aplicação de D7, já justificada em `AGENTS.md` §7.7. Mas o
**uso fora do problema que a motivou** exige as três respostas.

| | |
|---|---|
| **Problema** | gravar a classificação a faria divergir da estrutura no instante em que uma sub-issue fosse criada ou removida |
| **Existe agora?** | **Sim.** A issue #98 deste repositório nasceu sem partes e ganhou duas no mesmo dia. Uma classificação gravada na primeira coleta estaria errada na segunda |
| **O que piora** | consultar "todos os épicos" exige `EXISTS` sobre os vínculos, e não um `WHERE status = 'epic'`. Com muitas issues, isso precisa de índice — e um dia pode precisar de vista materializada, que é dívida a declarar quando acontecer |

### Padrões que **não** serão introduzidos

| Recusado | Por quê |
|---|---|
| abstração "fonte de trabalho" cobrindo GitHub, Jira e Azure | uma implementação só. Abstrair no primeiro caso é abstrair sem saber o que varia |
| cache de definições de campo em ETS | não há medição que mostre a leitura como problema. Otimização sem medida é padrão sem problema |
| máquina de estados para o item de projeto | exigiria o histórico de itens, que está fora de escopo por custo de consumo |
| coluna `is_epic` booleana | é o antipadrão "booleano no lugar do relator", nomeado em `AGENTS.md` §7.7 |

## Project Structure

### Documentação desta feature

```
specs/004-issues-e-projetos/
├── spec.md                    43 FR, 14 SC, 3 US, 12 edge cases
├── checklists/requirements.md  16 de 16
├── research.md                R1 a R7
├── plan.md                    este arquivo
├── data-model.md              tabelas, e o que NÃO é materializado
├── quickstart.md              V1 a V12, contra dado real
└── contracts/
    ├── issue-ingestion.md     API pública da coleta e da promoção
    ├── project-ingestion.md   API pública de projeto, campos e iterações
    └── screens.md             o que cada tela mostra, e o que não mostra
```

### Código

```
priv/knowledge_base/
├── ontology/seon/sys_swo/modules/*.yaml       + 11 estereótipos
├── mappings/github/spo/project.yaml           novo
├── mappings/github/cmpo/repository.yaml        novo
├── mappings/github/sro/
│   ├── issue_to_user_story.yaml               novo
│   ├── issue_to_development_task.yaml         novo
│   ├── issue_to_defect.yaml                   novo
│   ├── iteration_to_sprint.yaml               novo
│   └── project_items_to_backlogs.yaml         novo
└── rules/tenants/the_band_solution.yaml       novo — campos e tipos próprios

priv/connectors/github/
├── queries/{repositories,issues,sub_issues,projects_v2,project_items}.graphql
└── definitions/sro_ingestion.yaml             novo conector declarativo

lib/the_band/
├── ontology/seon/cmpo.ex                      módulo raiz novo (repositório)
├── ontology/continuum/sro.ex                  módulo raiz novo
├── ontology/continuum/sro/{commands,queries,constraints}.ex
├── ontology/continuum/sro/schemas/*.ex        privados
├── work_items/                                camada de plataforma: issue coletada,
│                                              promoção, vínculos, recusas
├── projects/                                  projeto observado, campos, itens
└── jobs/sync_github_sro.ex

lib/the_band_web/live/
├── work_item_live/index.ex                    issues, promoções e lacunas
└── project_live/index.ex                      projetos, campos e backlogs

priv/repo/migrations/                          derivadas, nunca escritas à mão
```

## Fases, e por que esta ordem

A ordem não é preferência. Cada fase existe porque a seguinte não funciona sem
ela.

### F0 — Anotar a SYS_SWO

Onze conceitos ganham `ontouml_stereotype`. **Bloqueia tudo**: sem a tabela base de
`sys_swo.loaded_software_system_copy`, `cmpo.source_repository` não tem para onde
ser elevado, e sem repositório não existe o escopo da marca de ausência.

Prova: `derive_information_model.py --ontology cmpo` passa a imprimir a tabela do
repositório, e a derivação continua reprodutível nas quatro ontologias.

### F1 — Semântica declarada: mapeamentos e regra do tenant

Antes do código, como na 002 e na 003. Cinco mapeamentos e a regra do tenant com
os nomes de tipo e o mapeamento campo→atributo.

Prova: `mix knowledge.validate` e o validador Python aceitam; e a regra do tenant
declara **explicitamente** que o projeto não tem campo numérico de importância.

### F2 — Repositório observado

Descoberta a partir da organização, com exclusão pelo tenant e marca de arquivado.
**Bloqueia F3**: a issue pertence a um repositório, e o escopo da ausência é ele.

Prova: excluir um repositório e conferir que a coleta seguinte não o consulta **e
não marca as issues dele** — os dois lados, como a L18 exige.

### F3 — Issues, promoção e recusa

O núcleo. Coleta, promoção pela regra, divergência registrada, lacuna contada, e
os vínculos de decomposição com a verificação de ciclo no comando.

Prova: o teste que importa é a violação — issue `Epic` sem sub-issues **não**
aparece como épico, e issue `User Story` com sub-issues do tipo `Task` **não** vira
épico.

### F4 — Projetos, campos e iterações

Projeto promovido a `spo.software_project`, campos por identificador, iteração
promovida só depois de iniciada, e os dois backlogs derivados da atribuição. A
promoção adicional a `sro.scrum_project` fica atrás da declaração do tenant.

Prova: `SC-009b` — a soma dos itens no product backlog e nos sprint backlogs é
igual ao total de itens do projeto.

### F5 — Telas

Issues com promoções, lacunas e divergências; projetos com campos e backlogs.

Prova: repositório coletado e vazio distinguível de repositório não coletado; e a
tela mostra a ausência do campo de importância em vez de inventar ordem.

**MVP**: F0, F1, F2 e F3. Issues classificadas, com a lacuna visível, e uma tela
que as mostra. Projetos ficam para depois porque um sprint sem issues não
responde nada — a dependência é nessa direção.

## Riscos

| Risco | Mitigação |
|---|---|
| **Anotar a SYS_SWO muda a derivação de outras ontologias** | o gate de reprodutibilidade roda antes e depois; qualquer mudança fora de CMPO é examinada, não aceita |
| **A regra de roteamento está errada** — tem `status: proposed` | a feature a **mede**: a lacuna por motivo é a métrica que diz onde ela erra. Corrigir é consequência, não pré-requisito |
| **Volume de issues estoura o limite de consumo** | checkpoint por repositório, não por organização: retomar não recomeça o repositório inteiro |
| **Sub-issues indisponíveis na instância do tenant** | detectar no início da coleta e **declarar** que a distinção épico/atômica não é feita. Nunca cair para heurística de markdown |
| **A tabela de vínculos recusados nascer e ficar vazia** | declarado em P2 como previsão, com o critério de reversão escrito |
| **Repetir a L19 em volume maior** | FR-010 exige escopo por repositório, e SC-003 verifica pela violação. O teste tem dois repositórios e duas coletas em sequência |

## Complexity Tracking

| O que | Por quê é essencial |
|---|---|
| 4 tabelas de plataforma para issue (coletada, promoção, vínculo, recusa) | cada uma responde uma pergunta que as outras não respondem; ver P1 e P2 |
| 3 tabelas para campo de projeto | FR-023 e FR-027; ver P3 |
| classificação derivada em vez de coluna | D7; ver P4 |
| 11 anotações fora do escopo da feature | sem elas o conceito central não tem tabela |

**O que ficaria mais simples e foi recusado**: gravar `is_epic` e `promoted_to`
como colunas na issue. Duas tabelas em vez de quatro, uma consulta em vez de um
`join` — e a plataforma perderia a divergência, que é o dado que a feature existe
para mostrar.

## Reavaliação da constituição, pós-desenho

Nenhuma violação. Duas coisas declaradas:

**A anotação da SYS_SWO é trabalho de ontologia dentro de uma feature de
ingestão.** Está aqui porque o conceito central da feature depende dela, não por
oportunidade. Se fosse maior — como os 43 da SRO — seria trabalho próprio.

**A data do sprint vem do planejamento, não da observação.** Declarado em R6: um
sprint que começou atrasado terá a data que o projeto dizia. Este repositório já
produziu essa divergência duas vezes. A data observada exigiria o histórico de
itens, fora de escopo por custo.
