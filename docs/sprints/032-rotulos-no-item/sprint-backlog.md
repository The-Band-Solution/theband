# Sprint 032 — O rótulo como campo do item de trabalho

**Período**: 2026-09-13 (um dia) · **fechado em 2026-09-13**
**Feature**: [065 — rótulos no item](../../../specs/065-rotulos-no-item/spec.md)
**Plano**: [plan.md](../../../specs/065-rotulos-no-item/plan.md) ·
**Pesquisa**: [research.md](../../../specs/065-rotulos-no-item/research.md) ·
**Modelo**: [data-model.md](../../../specs/065-rotulos-no-item/data-model.md)

> **Escrito depois do sprint, no mesmo dia.** Spec (`b6f945c`), plano, tarefas, issues (#890–#906),
> implementação (#907, 16:59Z) e correção de escopo (#908, 19:56Z) aconteceram em 2026-09-13 sem
> este documento. A intenção abaixo é a do `tasks.md` de 2026-09-13 — que, ao contrário da 060,
> **tem** issues, criadas antes da implementação. O que faltou foi a leitura das lições e a
> seleção de escopo como decisão humana: o sprint pegou as 14 tarefas inteiras.

## Objetivo do sprint

**Quem abre a lista de itens vê, em cada linha, os rótulos que o time escreveu** — os do campo
do GitHub (observado) e os do prefixo entre colchetes do título (derivado) —, sem que nenhum
rótulo altere a classificação que a plataforma deriva.

## De onde este sprint veio

Do pedido da pessoa mantenedora em 2026-09-13: a caracterização que o time dá aos itens
(`backend`, `[Devops]`, `prioridade:alta`) existia só no detalhe, onde menos ajuda a comparar. A
spec fixou a regra que nenhuma tarefa pode quebrar — **o rótulo é preservado e não promovido: um
rótulo `bug` não faz a issue um defeito** — e três protótipos foram aprovados no mesmo dia
(conceito, listagem, detalhe; links no corpo da #903).

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md). Registradas depois — o que a evidência mostra:

| Lição | Origem | Como aparece na evidência |
|---|---|---|
| **L30** — conferir contra a origem | 003 | os números das issues foram **conferidos contra o GitHub depois de criar**, "e não os que eu supus ter criado" (`tasks.md`, *As issues*). **Não aplicada ao SC-002**: o 1 519 da spec nunca foi medido, e a aceitação mediu **1 489** |
| **L98** — lição que não vira regra reincide | 028 | o template do PR passou a exigir as issues que o PR fecha, com a closing keyword em inglês (`40cc15b`) |
| **L38 / L53** — custo de tela pela diferença | 009, 013 | T003: 100 itens custam o mesmo que 10, por contagem de consultas; T009 manteve o detalhe em **46** consultas (a primeira versão subiu para 50 e foi pega) |
| **L60** — o veredito é o código de saída | 019 | T014 (#903): CI run 34779226200, `mix gates` `success` |
| **L102** — `git add -A` | 030 | a auditoria "começa por `git status`" entrou no `AGENTS.md` neste sprint (`b7200bf`) |
| **L103** — o protótipo não é o produto | 030 | o detector de design ignora `prototipo/` |
| **vertical slice** | constituição VIII | a T005 é a primeira tela e vem logo depois de T001–T004 |
| **L95** — pedir revisor não é obter revisão | 027 | **não aplicada**: #907 e #908 sem revisor pedido e fora do projeto |
| **L99** — conferir issue por issue | 028 | #908 nasceu de conferir: T009/T010 descreviam a listagem, e o defeito era no detalhe |

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
**Iteration**: *Sprint 025 — Contas e o elo do GitHub* · 2026-09-12 a 2026-09-19

**As 17 issues existiam desde 2026-09-13** com labels (`task`, `us`) e **sem tipo, sem hierarquia
e fora do projeto**. Materializadas em 2026-09-13 ao escrever este documento — resultado em
`github.md` desta pasta. As três US ficam **sem tipo** (`User Story` não existe na organização;
decisão do sprint 029). **Não há épico.** Quatro tarefas ficam sem user story porque o
`tasks.md` não as prendeu a nenhuma: T009, T010 (FR-016, FR-017), T013 e T014.

## User stories selecionadas

| # | User story | Priority | Issue | Tarefas | Critérios |
|---|---|---|---|---|---|
| US1 | Ver, na lista, como o time chamou cada item | P1 | [#904](https://github.com/The-Band-Solution/theband/issues/904) | T001, T002, T003, T005, T006, T007 | AS 1–4, FR-001 a FR-006, FR-010, FR-012, FR-013, SC-001 a SC-003, SC-005 a SC-007 |
| US3 | O rótulo nunca vira conceito | P1 | [#906](https://github.com/The-Band-Solution/theband/issues/906) | T004, T008 | AS 1–3, FR-007 a FR-009, SC-004 |
| US2 | Ver a alegação ao lado do veredito | P2 | [#905](https://github.com/The-Band-Solution/theband/issues/905) | T011, T012 | AS 1–3, FR-014, SC-008 |

**US3 entra na mesma fase da US1, e não depois** — é a regra que a US1 pode quebrar. `Estimate`
não preenchida.

## Tarefas

| # | Tarefa | Atende | Issue | Estado |
|---|---|---|---|---|
| T001 | Ler a lista de prefixos declarada | US1 | [#890](https://github.com/The-Band-Solution/theband/issues/890) | feito · #907 |
| T002 | Trazer os rótulos do campo para a listagem | US1 | [#891](https://github.com/The-Band-Solution/theband/issues/891) | feito · #907 |
| T003 | Provar que a listagem não cresce em consultas | US1 | [#892](https://github.com/The-Band-Solution/theband/issues/892) | feito · #907 |
| T004 | Impedir que o rótulo vire conceito | US3 | [#893](https://github.com/The-Band-Solution/theband/issues/893) | feito · #907 |
| T005 | Mostrar os rótulos na tela, com a origem | US1 | [#894](https://github.com/The-Band-Solution/theband/issues/894) | feito · #907 |
| T006 | Derivar o rótulo do prefixo do título | US1 | [#895](https://github.com/The-Band-Solution/theband/issues/895) | feito · #907 |
| T007 | Mostrar as duas origens sem juntá-las | US1 | [#896](https://github.com/The-Band-Solution/theband/issues/896) | feito · #907 |
| T008 | Recusar interpretar o conteúdo do rótulo | US3 | [#897](https://github.com/The-Band-Solution/theband/issues/897) | feito · #907 |
| T009 | Trazer o repositório para as sub-listas do detalhe | — (FR-016) | [#898](https://github.com/The-Band-Solution/theband/issues/898) | feito · #907, escopo reescrito no #908 |
| T010 | Dizer quando a parte vem de outro repositório | — (FR-016, FR-017, SC-009) | [#899](https://github.com/The-Band-Solution/theband/issues/899) | feito · #907 |
| T011 | Trazer os rótulos para as divergências | US2 | [#900](https://github.com/The-Band-Solution/theband/issues/900) | fechada **sem código** — ver a review |
| T012 | Mostrar os dois lados e dizer qual venceu | US2 | [#901](https://github.com/The-Band-Solution/theband/issues/901) | fechada **sem código** — ver a review |
| T013 | Conferir a tela contra o protótipo aprovado | — (FR-015) | [#902](https://github.com/The-Band-Solution/theband/issues/902) | feito — **lendo código, por quem implementou** |
| T014 | Fechar os gates | — | [#903](https://github.com/The-Band-Solution/theband/issues/903) | feito · CI run 34779226200 |

## Fora do escopo deste sprint

Nada do `tasks.md` ficou de fora. O que ficou de fora está na **spec**, não nas tarefas: FR-011,
FR-015, FR-016, FR-017, FR-018, SC-009 e SC-010 não estão presos a nenhuma user story, e por
isso **nenhum entregável os avalia** — a aceitação os mediu de passagem.

## Riscos e dependências

- **A regra que não pode quebrar** (US3) é a razão de a US3 ser P1 junto com a US1;
- **O protótipo não está registrado como o papel exige** — não há `prototipo/PROMPT.md` nem item
  em `docs/backlog/`; os três links vivem só no corpo da #903;
- **"Rótulo" e "label" são homônimos** dentro da plataforma — a spec fala do label do GitHub; o
  mecanismo de divergência (`ConceptLabel`) chama "label" o tipo declarado. Não foi visto como
  risco ao escrever; a aceitação o achou (L110).

## Definition of Done do sprint

- [x] quality gates verdes — CI run 34779226200 sobre `0ccf02b`, `mix gates` `success`
- [x] base de conhecimento válida — parte dos gates
- [x] issues de tarefa encerradas — #890–#903, à mão depois do merge (base não é o branch padrão)
- [ ] issues de user story encerradas ou com destino — **#904–#906 abertas**, com veredito proposto e destino escrito na aceitação; a confirmação é do papel
- [x] `sprint-review.md` escrito
- [x] `aceitacao.md` escrito — proposta do papel, 2026-09-13
- [x] `licoes-aprendidas.md` atualizado — L109, L110
