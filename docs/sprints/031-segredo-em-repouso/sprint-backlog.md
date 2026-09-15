# Sprint 031 — Segredo em repouso

**Período**: 2026-09-12 a 2026-09-19 (cadência de uma semana) · **aberto**
**Feature**: [064 — segredo em repouso](../../../specs/064-segredo-em-repouso/spec.md)
**Plano**: [plan.md](../../../specs/064-segredo-em-repouso/plan.md) ·
**Pesquisa**: [research.md](../../../specs/064-segredo-em-repouso/research.md) ·
**Modelo**: [data-model.md](../../../specs/064-segredo-em-repouso/data-model.md) ·
**Contratos**: [contracts/](../../../specs/064-segredo-em-repouso/contracts/)

> **Escrito em 2026-09-13, um dia depois de o trabalho começar.** A spec (#864), o plano (#865)
> e as issues (#889) entraram entre 2026-09-12 e 2026-09-13 sem este documento. Nenhuma das 19
> tarefas foi executada ainda, então a intenção registrada aqui **é** anterior à execução — o
> que este atraso custou foi o `TheBand.Segredo` (FR-006) ter sido entregue no PR da spec,
> antes de haver backlog. Está dito em *De onde este sprint veio*.

## Objetivo do sprint

**Nenhum segredo em claro chega a um backup**: a varredura repetível, com controle positivo,
roda antes da primeira cópia para o segundo host; o token de sessão deixa de ser legível no
banco; e um segredo, perguntado por sua forma textual, responde com uma marca.

## De onde este sprint veio

Da **L105**. Em 2026-09-12 um token de acesso do GitHub apareceu em texto claro dentro de
`oban_jobs.errors`, onde estava desde 2026-09-04 — oito dias. Nenhuma linha de código o
registrou: o valor chegou ao texto pelo caminho do erro, que nenhuma revisão que procure
chamadas de log encontraria. A resposta certa não era proibir o registro, era o **tipo**: um
segredo que não sabe virar texto.

**O que já foi feito antes deste backlog**, no PR da spec (#864, 2026-09-13): o tipo
`TheBand.Segredo` (recusa `inspect`, interpolação e serialização — FR-006), a redação da linha
#697, uma varredura **manual** do banco de desenvolvimento (259 colunas, zero), e o ensaio do
dump — 260 MB varridos por dentro e restaurados com 0 erros. **Nada disso fecha tarefa**: a T002
pede a varredura como tarefa repetível, a T005 pede a execução registrada por ela, a T006 pede o
tipo fechando o caminho do provedor de modelos. O que existe é fundação sem consumidor
declarado, e o backlog o nomeia.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), lidas em 2026-09-13:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L105** — o segredo chegou ao texto sem ninguém o registrar | 030 (2026-09-12) | é a origem da feature; FR-006 e a T006 |
| **L104** — aviso silenciado vira atestado | 030 (2026-09-10) | a varredura carrega **controle positivo** (T003): ela precisa provar que enxerga antes de dizer zero |
| **L23** — aviso de verificação pulada é reprovação | 002 | T004: a varredura que encontra recusa **imprimir** o valor, e falha nomeando a coluna |
| **L30** — conferir contra a origem, item a item | 003 | o ensaio do dump foi contra cópia do banco real; a T005 registra a varredura sobre o banco real, não sobre fixture |
| **L60** — o veredito é o código de saída | 019 | na DoD e no template de PR |
| **L100** — branch de documentação sem PR | 029 | spec, plano e issues vieram por PR (#864, #865, #889) |
| **L102** — `git add -A` numa árvore compartilhada | 030 | o #889 registra "a auditoria que achou um erro meu": caminhos explícitos e `git status` antes de abrir PR (constituição 1.8.0) |
| **L95** — pedir revisor não é obter revisão | 027 | **não aplicada nos três PRs de preparação**: #864, #865 e #889 sem revisor pedido (`reviewRequests` 0). A partir deste backlog, todo PR da 064 pede a equipe `the-band` ao abrir e confere |
| **L108** — o passo sem dono some | 032 | este documento existe **antes** da T001 |

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2) ·
**Iteration**: *Sprint 025 — Contas e o elo do GitHub* · 2026-09-12 a 2026-09-19 · 7 dias
(a numeração das iterations do projeto está atrás da destas pastas; é a ativa no período)

**Materializado em 2026-09-13**, ao escrever este backlog — as 23 issues existiam desde o
#889 com labels (`task`, `us`, `epic`, `security`) e **sem tipo, sem hierarquia e fora do
projeto**. O que foi feito, e o que não foi:

| passo | resultado |
|---|---|
| tipo `Task` nas 19 tarefas | ver `docs/sprints/031-segredo-em-repouso/github.md` |
| tipo nas 3 US e no épico | **não** — `User Story` e `Epic` não existem na organização; tipá-las como `Feature` faria a regra de roteamento classificar errado. Sem tipo é ausência; com o tipo errado é afirmação falsa (decisão do sprint 029, mantida) |
| tarefa → sub-issue da US | T002–T005 → #885 · T006–T008 → #887 · T009–T014 → #886 |
| US → sub-issue do épico #888 | #885, #886, #887 |
| item no projeto + iteration + Status | as 23 |

**Seis tarefas ficam sem user story**, e isso é do `tasks.md`, não da materialização: T001
(fundação), T015 e T016 (o que fica escrito) e T017–T019 (a idade da credencial, FR-016 a FR-019,
requisito acrescentado pelo #889 sem user story própria). Ficam filhas do épico? **Não** —
tarefa é filha de user story, e ligá-las ao épico faria a regra de roteamento contar tarefa como
composição. Ficam soltas, e a lacuna está aqui.

## User stories selecionadas

**As três.** A ordem das fases **não** segue a prioridade da spec, e o `tasks.md` diz por quê:
a US3 (P3) é antecipada porque o tipo `Segredo` já existe e fechar o caminho do provedor é
pequeno; a US2 (P2) é a maior e vem por último.

| # | User story | Priority | Épico | Issue | Tarefas | Critérios |
|---|---|---|---|---|---|---|
| US1 | Nenhum segredo em claro chega a um backup 🎯 | P1 | [#888](https://github.com/The-Band-Solution/theband/issues/888) | [#885](https://github.com/The-Band-Solution/theband/issues/885) | T002–T005 | FR-001 a FR-005 |
| US2 | O token de sessão deixa de ser legível no banco | P2 | #888 | [#886](https://github.com/The-Band-Solution/theband/issues/886) | T009–T014 | FR-010 a FR-015 |
| US3 | Segredo nunca chega a log, erro ou campo de diagnóstico | P3 | #888 | [#887](https://github.com/The-Band-Solution/theband/issues/887) | T006–T008 | FR-006 a FR-009 |

`Estimate` (a *complexity*) **não foi preenchida** — desconhecida, não zero. `Priority` vem da
spec.

## Tarefas

| # | Tarefa | Atende | Issue | Estado |
|---|---|---|---|---|
| T001 | Declarar os padrões de segredo em um lugar só | fundação | [#866](https://github.com/The-Band-Solution/theband/issues/866) | a fazer |
| T002 | Criar a tarefa de varredura | US1 | [#867](https://github.com/The-Band-Solution/theband/issues/867) | a fazer |
| T003 | Embutir o controle positivo na varredura | US1 | [#868](https://github.com/The-Band-Solution/theband/issues/868) | a fazer |
| T004 | Recusar imprimir o valor encontrado | US1 | [#869](https://github.com/The-Band-Solution/theband/issues/869) | a fazer |
| T005 | Varrer o banco de desenvolvimento e registrar | US1 | [#870](https://github.com/The-Band-Solution/theband/issues/870) | a fazer — a varredura manual de 2026-09-12 **não** a fecha |
| T006 | Fechar o segredo no caminho do provedor de modelos | US3 | [#871](https://github.com/The-Band-Solution/theband/issues/871) | a fazer — o tipo existe (#864); falta o consumidor |
| T007 | Preencher as datas de encerramento ausentes | US3 | [#872](https://github.com/The-Band-Solution/theband/issues/872) | a fazer · `bug` |
| T008 | Verificar registro terminado sem data | US3 | [#873](https://github.com/The-Band-Solution/theband/issues/873) | a fazer |
| T009 | Criar a tabela de sessões | US2 | [#874](https://github.com/The-Band-Solution/theband/issues/874) | a fazer |
| T010 | Acrescentar a época de senha | US2 | [#875](https://github.com/The-Band-Solution/theband/issues/875) | a fazer |
| T011 | Abrir, conferir e encerrar sessão | US2 | [#876](https://github.com/The-Band-Solution/theband/issues/876) | a fazer |
| T012 | Migrar as sessões vivas sem derrubar ninguém | US2 | [#877](https://github.com/The-Band-Solution/theband/issues/877) | a fazer |
| T013 | Ler a sessão pela nova tabela | US2 | [#878](https://github.com/The-Band-Solution/theband/issues/878) | a fazer |
| T014 | Remover a coluna antiga | US2 | [#879](https://github.com/The-Band-Solution/theband/issues/879) | a fazer — **destrutiva**; última, de propósito |
| T015 | Documentar o efeito de uma restauração sobre as sessões | — | [#880](https://github.com/The-Band-Solution/theband/issues/880) | a fazer · `documentation` |
| T016 | Escrever o procedimento de girar todas as sessões | — | [#881](https://github.com/The-Band-Solution/theband/issues/881) | a fazer · `documentation` |
| T017 | Saber a idade de cada credencial | — (FR-016, FR-019) | [#882](https://github.com/The-Band-Solution/theband/issues/882) | a fazer |
| T018 | Pedir a troca na tela que administra | — (FR-017) | [#883](https://github.com/The-Band-Solution/theband/issues/883) | a fazer — **tela**: protótipo antes do código |
| T019 | Registrar a data da troca | — (FR-018) | [#884](https://github.com/The-Band-Solution/theband/issues/884) | a fazer |

Tarefa não recebe `Priority`: herda a da user story que atende.

## Escopo mínimo

**T001 a T005 — a US1 inteira.** Entrega sozinha o que o tempo torna impossível depois: varrer um
dump **antes** da primeira cópia para o segundo host, com a prova de que a varredura enxerga.
A decisão do MinIO como destino de produção está no PR #914, aberto — a varredura precisa
existir antes de ele ser mergeado.

## Fora do escopo deste sprint

Do `tasks.md`, seção *O que estas tarefas não cobrem*:

- **a rotação do token do GitHub** (`…omAX`) — ato operacional, adiado pela pessoa mantenedora
  para **2026-10-12**. Ele esteve legível de 2026-09-04 a 2026-09-12, e a janela de risco vai até
  a rotação. **Redigir a linha não a fechou** — só a rotação invalida um valor que esteve legível
  (L105);
- **rodar a varredura em produção** — a T002 a torna possível; executar é de quem opera;
- **o caminho até o MinIO** — `pg_dump → varredura → restauração` está coberto;
  `→ destino remoto →` foi exercitado em 2026-09-13 fora desta feature
  (`docs/seguranca/2026-09-13-o-caminho-completo-do-backup.md`), e **o objeto no balde tem o
  banco de desenvolvimento inteiro com dois tokens de sessão em claro**;
- **de onde vieram os quatro registros cancelados sem data** — incógnita declarada em R6.

## Riscos e dependências

- **A T014 remove coluna** — é a única tarefa destrutiva, e por isso a última. Rollback depois
  dela perde as sessões que a nova tabela guardar; a T015 documenta o que uma restauração faz
  com as sessões **antes** da T014;
- **A T012 migra sessões vivas** — falhar derruba quem está logado, inclusive quem administra.
  Ensaio contra cópia do banco real antes de produção;
- **A T018 é tela** e passa pelo papel de Design antes do código;
- **H9** (`ssl: true` comentado) é vizinho: segredo em repouso no banco e segredo em trânsito
  até o banco são dois problemas, e este sprint só trata o primeiro.

## Definition of Done do sprint

- [ ] quality gates verdes — `mix gates` com código de saída 0
- [ ] base de conhecimento válida
- [ ] `gh issue list --state open --search "064/"` vazio, ou cada aberta com destino escrito
- [ ] todo PR com revisor `the-band` pedido e conferido, e no projeto (L95, `AGENTS.md`)
- [ ] `sprint-review.md` escrito
- [ ] `aceitacao.md` escrito pelo papel, critério a critério
- [ ] `licoes-aprendidas.md` atualizado
