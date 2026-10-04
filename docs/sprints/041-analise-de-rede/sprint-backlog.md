# Sprint 041 — a análise de rede, do menu ao primeiro grafo

**Período**: a partir de 2026-10-04, na iteration corrente do GitHub (Sprint 035)
**Feature**: [076](../../../specs/076-analise-de-rede/spec.md) · **Plano**: [plan.md](../../../specs/076-analise-de-rede/plan.md) · **Tarefas**: [tasks.md](../../../specs/076-analise-de-rede/tasks.md)
**Épico**: [#1309](https://github.com/The-Band-Solution/theband/issues/1309)

**Número**: 041. Os números 038, 039 e 040 já existem (`development` e branches abertos; 040 é o
site de desenvolvedores, em `origin/feature/1267-site-de-desenvolvedores`). Conferido em 2026-10-04 com
`git log --all -- 'docs/sprints/04*'`.

## Objetivo do sprint

Quem coordena abre **Network analysis** no menu, encontra a rede de revisão da 073 dentro da área, e
lê a rede de **designação** de uma organização — contagens, exclusões por motivo e o grafo ponderado
—, com quem está fora do alcance agrupado e sem nome. A fundação de cálculo (fila, gerador, recorte,
leitura) fica provada para as outras sete análises.

## Escopo confirmado (2026-10-04)

A pessoa mantenedora confirmou o escopo do sprint, **Fundação + US1–US3** (T002, #1326), e as
decisões A7, R10 item 8 e R21 com a opção padrão do plano. US4–US9 e o acabamento ficam para o
sprint seguinte.

**Andamento em 2026-10-04**: a Fundação (T002, T004–T017) está feita na branch
`feature/1309-fundacao`, num PR próprio para `development` (#1381). T003 (medida de produção)
continua com a pessoa mantenedora. A US1 (T018–T020) está feita na branch `feature/1309-us1`,
empilhada sobre a fundação, num PR com merge commit. US2 e US3 (T021–T034) seguem, empilhadas.

## Escopo proposto, e o que espera confirmação

**Proposto para este sprint**: Fases 1 e 2 (T001–T017), US1 (T018–T020), US2 (T021–T029) e US3
(T030–T034) — 34 tarefas, o MVP mais o primeiro grafo pedido. Todas as 55 tarefas e as 9 US estão na
iteration, como pedido; **a seleção é decisão humana** (skill, passo 5), e US4–US9 e o acabamento
ficam marcados *não iniciado* até a pessoa mantenedora confirmar se entram neste sprint ou no
seguinte. A iteration tem 7 dias; 55 tarefas não cabem nela.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), lido antes deste documento:

| Lição | Como está sendo aplicada |
|---|---|
| L19 — marcar por tenant marca o que é de outra organização | a designação chega à organização pelo repositório observado; A2 com duas organizações no mesmo tenant (T023) |
| L38 — custo de tela pela constância | `read/4` com teto de consultas, 5 e 50 pessoas (T017) |
| L50 — teste que compara precisa provar que mediu | todo `refute` de isolamento vem depois de `assert` de arestas > 0 (regra geral do `tasks.md`) |
| L53 — o teto de um teste de custo vem da medida dos dois lados | T034 e T050 medem antes de fixar teto |
| L54 — átomo criado sob demanda | rede, vista e janela por texto exato; A12 conta átomos (T017) |
| L60 — o pipe devolve o código do `tail` | toda evidência com `> log; echo EXIT=$?` |
| L62 — somar contadores por lista à mão | invariante pares = arestas + exclusões na designação (T024) |
| L69 — defeito dentro de `Logger.info` | o job registra a partir do relator; A19 com `capture_log` em `:debug` (T014) |
| L73 — a prova de tela é a imagem | T053 confere contra o protótipo com capturas |
| L102 — `git add -A` numa árvore compartilhada | commits por caminho explícito |
| L105 — o segredo chega ao texto pela pilha | `Repo.insert!` da 073 sai antes de tudo (T004, A18); nenhum `{:ok, _} =` sobre a leitura |
| L106 — a verificação que ninguém lê | scripts de injeção com `set -e` e conferência da restauração |
| L108 — feature sem sprint backlog | este documento existe antes do código |
| L109 — tarefa fechada sem código | só fecha a issue com evidência do critério como escrito |
| L110 — exemplo da spec sem olhar o dado | A3 medida no dado antes de virar tarefa: 3 issues de autor `Bot` sem sufixo (research.md R13) |

## Sprint no GitHub

**Iteration**: Sprint 035 — O operador da plataforma (`ee36a246`), a partir de 2026-10-03, no
projeto [The Band](https://github.com/orgs/The-Band-Solution/projects/2). Todas as issues da 076
estão na iteration, com `Status = Backlog`.

**Hierarquia**: as 9 US são sub-issues do épico #1309; as tarefas de US são sub-issues da US; as de
Setup, Fundação e Acabamento, do épico. Tarefas com tipo `Task` e label `task`; US com label `us`
(a organização não tem tipo `User Story`); `security` nas que vêm de achado.

**Limitações**: `Estimate` não foi preenchido (ausência, e não zero). `Priority` só tem P0–P2: as US
P3 ficam sem prioridade, como na 073.

## User stories

| # | User story | Issue | Priority | Labels |
|---|---|---|---|---|
| US1 | A área "Network analysis" no menu, com a rede de revisão como primeira página | [#1316](https://github.com/The-Band-Solution/theband/issues/1316) | P1 | security, us |
| US2 | A rede de designação: quem abre issue para quem é responsável | [#1317](https://github.com/The-Band-Solution/theband/issues/1317) | P1 | security, us |
| US3 | O grafo ponderado | [#1318](https://github.com/The-Band-Solution/theband/issues/1318) | P1 | security, us |
| US4 | As comunidades | [#1319](https://github.com/The-Band-Solution/theband/issues/1319) | P2 | security, us |
| US5 | Os hubs | [#1320](https://github.com/The-Band-Solution/theband/issues/1320) | P2 | security, us |
| US6 | Distância e eficiência | [#1321](https://github.com/The-Band-Solution/theband/issues/1321) | — (P3 não existe no campo) | us |
| US7 | Mundo pequeno | [#1322](https://github.com/The-Band-Solution/theband/issues/1322) | — (P3 não existe no campo) | us |
| US8 | O papel de cada pessoa | [#1323](https://github.com/The-Band-Solution/theband/issues/1323) | — (P3 não existe no campo) | security, us |
| US9 | O perfil individual | [#1324](https://github.com/The-Band-Solution/theband/issues/1324) | — (P3 não existe no campo) | security, us |

## Tarefas

| # | Tarefa | Atende | Issue | security | Estado |
|---|---|---|---|---|---|
| T001 | Integrar `development` na branch do plano | épico | [#1325](https://github.com/The-Band-Solution/theband/issues/1325) |  | feito |
| T002 | 👤 Decidir se a marca de conta da organização vale para a revisão (A7) | épico | [#1326](https://github.com/The-Band-Solution/theband/issues/1326) |  | feito (fundação, 2026-10-04) |
| T003 | 👤 Medir a rede de designação em produção | épico | [#1327](https://github.com/The-Band-Solution/theband/issues/1327) | sim | a fazer |
| T004 | Gravar a leitura da 073 sem exceção que carrega pares | épico | [#1328](https://github.com/The-Band-Solution/theband/issues/1328) | sim | feito (fundação, 2026-10-04) |
| T005 | Corrigir a frase do recorte da verificação (#1185) | épico | [#1329](https://github.com/The-Band-Solution/theband/issues/1329) | sim | feito (fundação, 2026-10-04) |
| T006 | Emendar a proposta da base com as decisões do plano | épico | [#1330](https://github.com/The-Band-Solution/theband/issues/1330) |  | feito (fundação, 2026-10-04) |
| T007 | Levar a base aceita para a base de conhecimento | épico | [#1331](https://github.com/The-Band-Solution/theband/issues/1331) |  | feito (fundação, 2026-10-04) |
| T008 | Ler os parâmetros da análise da base | épico | [#1332](https://github.com/The-Band-Solution/theband/issues/1332) |  | feito (fundação, 2026-10-04) |
| T009 | Criar a tabela das leituras da análise | épico | [#1333](https://github.com/The-Band-Solution/theband/issues/1333) |  | feito (fundação, 2026-10-04) |
| T010 | Configurar a fila própria da análise | épico | [#1334](https://github.com/The-Band-Solution/theband/issues/1334) |  | feito (fundação, 2026-10-04) |
| T011 | Sortear de forma reproduzível | épico | [#1335](https://github.com/The-Band-Solution/theband/issues/1335) |  | feito (fundação, 2026-10-04) |
| T012 | Projetar sem direção e contar componentes e graus | épico | [#1336](https://github.com/The-Band-Solution/theband/issues/1336) |  | feito (fundação, 2026-10-04) |
| T013 | Conferir antes de calcular, e encadear depois da 073 | épico | [#1337](https://github.com/The-Band-Solution/theband/issues/1337) | sim | feito (fundação, 2026-10-04) |
| T014 | Calcular e substituir só a mesma rede e janela | épico | [#1338](https://github.com/The-Band-Solution/theband/issues/1338) | sim | feito (fundação, 2026-10-04) |
| T015 | Alcançar por concessão (DS1) | épico | [#1339](https://github.com/The-Band-Solution/theband/issues/1339) | sim | feito (fundação, 2026-10-04) |
| T016 | Recortar a leitura pelo alcance (FR-015) | épico | [#1340](https://github.com/The-Band-Solution/theband/issues/1340) | sim | feito (fundação, 2026-10-04) |
| T017 | Ler pelo alcance, a cada chamada | épico | [#1341](https://github.com/The-Band-Solution/theband/issues/1341) | sim | feito (fundação, 2026-10-04) |
| T018 | Pôr Network analysis no menu principal | US1 | [#1342](https://github.com/The-Band-Solution/theband/issues/1342) |  | feito (US1, 2026-10-04) |
| T019 | Abrir a área e escolher a organização | US1 | [#1343](https://github.com/The-Band-Solution/theband/issues/1343) |  | feito (US1, 2026-10-04) |
| T020 | Montar a rede de revisão na área, e o endereço antigo | US1 | [#1344](https://github.com/The-Band-Solution/theband/issues/1344) | sim | feito (US1, 2026-10-04) |
| T021 | Gravar o tipo da conta na coleta de issues (A3) | US2 | [#1345](https://github.com/The-Band-Solution/theband/issues/1345) | sim | a fazer |
| T022 | Preencher o tipo da conta das issues já coletadas | US2 | [#1346](https://github.com/The-Band-Solution/theband/issues/1346) |  | a fazer |
| T023 | Ler os pares de designação com seis filtros de tenant | US2 | [#1347](https://github.com/The-Band-Solution/theband/issues/1347) | sim | a fazer |
| T024 | Classificar cada designação em exatamente um destino | US2 | [#1348](https://github.com/The-Band-Solution/theband/issues/1348) |  | a fazer |
| T025 | Declarar e revogar a conta da organização | US2 | [#1349](https://github.com/The-Band-Solution/theband/issues/1349) | sim | a fazer |
| T026 | Declarar a conta da organização na tela de pessoas | US2 | [#1351](https://github.com/The-Band-Solution/theband/issues/1351) | sim | a fazer |
| T027 | Excluir a conta da organização também na revisão (A7) | US2 | [#1352](https://github.com/The-Band-Solution/theband/issues/1352) | sim | a fazer |
| T028 | Calcular as duas redes nas três janelas | US2 | [#1353](https://github.com/The-Band-Solution/theband/issues/1353) |  | a fazer |
| T029 | Mostrar as contagens da rede de designação | US2 | [#1354](https://github.com/The-Band-Solution/theband/issues/1354) |  | a fazer |
| T030 | Calcular a intermediação por Brandes | US3 | [#1355](https://github.com/The-Band-Solution/theband/issues/1355) |  | a fazer |
| T031 | Posicionar os nós no servidor, com semente | US3 | [#1356](https://github.com/The-Band-Solution/theband/issues/1356) |  | a fazer |
| T032 | Desenhar o grafo em SVG, sem dado no navegador | US3 | [#1357](https://github.com/The-Band-Solution/theband/issues/1357) | sim | a fazer |
| T033 | Mostrar o grafo ponderado com o recorte | US3 | [#1358](https://github.com/The-Band-Solution/theband/issues/1358) | sim | a fazer |
| T034 | Medir o layout da visão parcial na leitura | US3 | [#1359](https://github.com/The-Band-Solution/theband/issues/1359) |  | a fazer |
| T035 | Detectar comunidades pelo guloso com peso | US4 | [#1360](https://github.com/The-Band-Solution/theband/issues/1360) |  | não iniciado (escopo a confirmar) |
| T036 | Comparar a modularidade com a dos aleatórios, com peso (A5) | US4 | [#1361](https://github.com/The-Band-Solution/theband/issues/1361) |  | não iniciado (escopo a confirmar) |
| T037 | Mostrar as comunidades com o recorte | US4 | [#1362](https://github.com/The-Band-Solution/theband/issues/1362) | sim | não iniciado (escopo a confirmar) |
| T038 | Calcular distâncias de cada pessoa e a proximidade | US5 | [#1363](https://github.com/The-Band-Solution/theband/issues/1363) |  | não iniciado (escopo a confirmar) |
| T039 | Calcular o autovetor por componente | US5 | [#1364](https://github.com/The-Band-Solution/theband/issues/1364) |  | não iniciado (escopo a confirmar) |
| T040 | Mostrar os hubs só entre alcançados | US5 | [#1365](https://github.com/The-Band-Solution/theband/issues/1365) | sim | não iniciado (escopo a confirmar) |
| T041 | Calcular distância média, diâmetro e eficiência, e as dos aleatórios | US6 | [#1366](https://github.com/The-Band-Solution/theband/issues/1366) |  | não iniciado (escopo a confirmar) |
| T042 | Mostrar distância, diâmetro e eficiência | US6 | [#1367](https://github.com/The-Band-Solution/theband/issues/1367) |  | não iniciado (escopo a confirmar) |
| T043 | Calcular o clustering e o σ | US7 | [#1368](https://github.com/The-Band-Solution/theband/issues/1368) |  | não iniciado (escopo a confirmar) |
| T044 | Mostrar o mundo pequeno como critério | US7 | [#1369](https://github.com/The-Band-Solution/theband/issues/1369) |  | não iniciado (escopo a confirmar) |
| T045 | Derivar percentil e papel na leitura | US8 | [#1370](https://github.com/The-Band-Solution/theband/issues/1370) |  | não iniciado (escopo a confirmar) |
| T046 | Mostrar as posições por nome, com o critério | US8 | [#1371](https://github.com/The-Band-Solution/theband/issues/1371) | sim | não iniciado (escopo a confirmar) |
| T047 | Abrir o perfil só de quem se alcança | US9 | [#1372](https://github.com/The-Band-Solution/theband/issues/1372) | sim | não iniciado (escopo a confirmar) |
| T048 | Mostrar o perfil | US9 | [#1373](https://github.com/The-Band-Solution/theband/issues/1373) |  | não iniciado (escopo a confirmar) |
| T049 | Provar as cinco redes conhecidas e a reprodutibilidade | épico | [#1374](https://github.com/The-Band-Solution/theband/issues/1374) |  | não iniciado (escopo a confirmar) |
| T050 | Medir o teto e o tempo do job | épico | [#1375](https://github.com/The-Band-Solution/theband/issues/1375) |  | não iniciado (escopo a confirmar) |
| T051 | Guardar a análise fora da API, do MCP e do perfil | épico | [#1376](https://github.com/The-Band-Solution/theband/issues/1376) | sim | não iniciado (escopo a confirmar) |
| T052 | Apagar as leituras ao encerrar a observação | épico | [#1377](https://github.com/The-Band-Solution/theband/issues/1377) | sim | não iniciado (escopo a confirmar) |
| T053 | Conferir a tela contra o protótipo aprovado — QA e Design | épico | [#1378](https://github.com/The-Band-Solution/theband/issues/1378) |  | não iniciado (escopo a confirmar) |
| T054 | 👤 Aceitar contra a origem (SC-001, SC-006) | épico | [#1379](https://github.com/The-Band-Solution/theband/issues/1379) |  | não iniciado (escopo a confirmar) |
| T055 | Rodar os gates e abrir o PR | épico | [#1380](https://github.com/The-Band-Solution/theband/issues/1380) |  | não iniciado (escopo a confirmar) |

## Riscos e dependências

- **A7 (T002)**: se a pessoa mantenedora disser *não*, T027 sai, e a área diz que a marca não se
  aplica à revisão;
- **produção não medida** (#1190, T003): o teto de 300 pessoas / 3 000 arestas é provisório;
- **revisão semântica das emendas da base** (T006): bloqueia T007 e tudo que lê parâmetros;
- **US3 depende de US2** (a página Graph nasce em T029);
- **a A7 muda a 073**, que está no ar: a coluna nova é anulável e a página diz *"not evaluated"* nas
  leituras antigas.

## Decisões a confirmar (do plano)

A7; os *"três mais centrais"* seguindo a DS1; comunidade por letra ou número; o teto provisório.
Nenhuma bloqueia o início.

## Definition of Done do sprint

- [ ] `mix gates` com `EXIT=0`, lido sem pipe
- [ ] `mix knowledge.validate`, `graph`, `test` com `EXIT=0`
- [ ] cada guarda vista reprovando com o defeito injetado, evidência na issue
- [ ] issues encerradas com evidência ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito; `licoes-aprendidas.md` atualizado
