# Sprint 039 — a rede de revisão, o backend que não espera

**Período**: 2026-10-03 a 2026-10-09, na iteration corrente do GitHub (Sprint 035)
**Feature**: [073](../../../specs/073-rede-de-revisao/spec.md) · **Plano**: [plan.md](../../../specs/073-rede-de-revisao/plan.md) · **Tarefas**: [tasks.md](../../../specs/073-rede-de-revisao/tasks.md)
**Épico**: [#1182](https://github.com/The-Band-Solution/theband/issues/1182)

## Objetivo do sprint

O cálculo e o recorte da rede de revisão existem e estão provados, com cada cenário de ataque visto
reprovando, de modo que a US1 fique a uma base aprovada e a uma tela aprovada de ser entregue.

**Este sprint não entrega nada visível**, e é dito aqui para não parecer que entrega. A US1 só fecha
com a tela (T021); nenhum PR é aberto antes disso (memória *Vertical slice*).

**Atualizado em 2026-10-03**: o protótipo foi **aprovado** (v2, `prototipo/`), e as tarefas de tela não
esperam mais por ele. Esperam a fachada (T017), que espera os parâmetros da base (T013 ← T004 ←
T003, a revisão semântica). As decisões da pessoa mantenedora do mesmo dia (amostra de 10 revisões e
concentração ausente abaixo dela; grupos e exclusões pelo recorte; conta apagada como sem pessoa
ligada; grupo mínimo 3) já estão na spec, no contrato, nas tarefas e em `proposta-base/`.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), consideradas neste sprint:

| Lição | Como está sendo aplicada |
|---|---|
| L19 — marcar por tenant marca o que é de outra organização | a rede é por **organização observada**, buscada por id e tenant juntos (T006); A3 tem duas organizações no mesmo tenant |
| L38 — custo de tela pela diferença e pela constância | `read/5` com teto de consultas, medido com 5 e com 50 pessoas (T016) |
| L50 — teste que compara precisa provar que mediu | todo `refute` de isolamento vem depois de um `assert` de que a leitura tem arestas (A1, A2, A3) |
| L54 — átomo criado sob demanda | a janela nunca vira átomo; a lista fechada compara inteiros (A8) |
| L62 — somar contadores por lista à mão apaga a chave nova | o invariante *pares = rede + três exclusões* é teste, e uma classificação errada aparece como diferença (T014) |
| L67 — duas medidas do mesmo nome | uma só unidade, o par (revisor, solicitação), para o total, o peso e a concentração (research.md R2) |
| L69 — defeito dentro de `Logger.info` é invisível a teste | a prova do log (A16) eleva o nível do Logger de verdade; fica para T019, que espera a base |
| L102 — `git add -A` numa árvore compartilhada | dois agentes escrevem em `proposta-base/` e `prototipo/`; todo commit é `git commit -- <meus caminhos>` |
| L108 — feature sem sprint backlog | este documento existe antes do código |
| L109 — tarefa fechada sem código | só fecha a issue cuja evidência (comando, código de saída, defeito injetado) está nela |

## Sprint no GitHub

**Iteration**: Sprint 035 — O operador da plataforma (`ee36a246`) · 2026-10-03 · 7 dias, no projeto
[The Band](https://github.com/orgs/The-Band-Solution/projects/2). As user stories e as tarefas do
escopo estão na iteration com `Status`.

**Limitação**: a organização não tem tipo `User Story` (só `Task`, `Bug`, `Feature`). As US levam o
label `us`, sem tipo, como as das specs 070–072. `Estimate` não foi preenchido: ausência, e não zero.

## User stories

| # | User story | Issue | Priority | Critérios |
|---|---|---|---|---|
| US1 | Ver se a revisão está concentrada | [#1186](https://github.com/The-Band-Solution/theband/issues/1186) | P1 | 3 cenários; SC-001, SC-002, SC-004, SC-005 |
| US2 | Ver quem revisa quem | [#1187](https://github.com/The-Band-Solution/theband/issues/1187) | P2 | 3 cenários |
| US3 | Ver a forma da rede | [#1188](https://github.com/The-Band-Solution/theband/issues/1188) | — (P3 não existe no campo) | 2 cenários |

Nenhuma fecha neste sprint: todas dependem da tela.

## Tarefas do escopo

| # | Tarefa | Atende | Issue | Estado |
|---|---|---|---|---|
| T001 | Integrar `development`, com a #1181 | US1 | [#1189](https://github.com/The-Band-Solution/theband/issues/1189) | feito |
| T005 | Criar a tabela da leitura vigente | US1 | [#1193](https://github.com/The-Band-Solution/theband/issues/1193) | feito |
| T006 | Dar a EO as três leituras que a rede pede | US1 | [#1194](https://github.com/The-Band-Solution/theband/issues/1194) | feito |
| T007 | Filtrar os repositórios observados por organização | US1 | [#1195](https://github.com/The-Band-Solution/theband/issues/1195) | feito |
| T008 | Ler os pares revisor–solicitação, com tenant nas duas pontas | US1 | [#1196](https://github.com/The-Band-Solution/theband/issues/1196) | feito |
| T009 | Ler quem abriu solicitação na janela | US1 | [#1197](https://github.com/The-Band-Solution/theband/issues/1197) | feito |
| T010 | Remover o ranking de revisores sem alcance | US1 | [#1198](https://github.com/The-Band-Solution/theband/issues/1198) | feito |
| T011 | Classificar cada par num destino só | US1 | [#1199](https://github.com/The-Band-Solution/theband/issues/1199) | feito |
| T012 | Calcular arestas, totais, grupos e concentração em Elixir puro | US1 | [#1200](https://github.com/The-Band-Solution/theband/issues/1200) | feito |
| T014 | Substituir as três leituras da organização numa transação | US1 | [#1202](https://github.com/The-Band-Solution/theband/issues/1202) | feito |
| T015 | Recortar a concentração e as exclusões pelo alcance | US1 | [#1203](https://github.com/The-Band-Solution/theband/issues/1203) | feito |
| T016 | Ler a rede com o alcance recalculado a cada leitura | US1 | [#1204](https://github.com/The-Band-Solution/theband/issues/1204) | feito |
| T018 | Conferir tenant e organização antes de calcular, e cancelar sem gravar | US1 | [#1206](https://github.com/The-Band-Solution/theband/issues/1206) | feito |
| T023 | Montar a lista por pessoa, ordenada por nome | US2 | [#1211](https://github.com/The-Band-Solution/theband/issues/1211) | feito |
| T025 | Contar os grupos, escondendo o tamanho dos pequenos | US3 | [#1213](https://github.com/The-Band-Solution/theband/issues/1213) | feito |
| T027 | Provar que a rede não sai pela API nem pela MCP | US1 | [#1215](https://github.com/The-Band-Solution/theband/issues/1215) | feito |
| T028 | Abrir a issue do aviso de recorte que promete mais do que aplica | US1 | [#1216](https://github.com/The-Band-Solution/theband/issues/1216) | feito |
| T030 | Contar a conta apagada como sem pessoa ligada, e não como bot, na coleta | US1 | [#1219](https://github.com/The-Band-Solution/theband/issues/1219) | feito |

Tarefa não recebe `Priority`: herda a da user story.

## Acréscimo de 2026-10-03, depois da revisão semântica e do protótipo aprovado

Com a base aceita (T003, T004) e o protótipo aprovado, o escopo do sprint passou a ser a feature
inteira até o PR. Entraram e foram feitas: T003, T004, T013, T017, T019, T020, T021, T024, T026 e
T029. Ficam abertas T002 e T022, da pessoa mantenedora, e as US #1186–#1188, que só fecham com
aceitação.

## Fora do escopo deste sprint (a lista de antes do acréscimo)

| Tarefa | Issue | Por quê |
|---|---|---|
| T002 medir produção 👤 | [#1190](https://github.com/The-Band-Solution/theband/issues/1190) | acesso à produção; antes do merge da US1 |
| T003 revisão semântica | [#1191](https://github.com/The-Band-Solution/theband/issues/1191) | é do agente de ontologia e integração semântica, e não de quem escreveu a proposta; os estados que contam estão em texto livre na proposta e precisam virar lista legível |
| T004 YAMLs na base | [#1192](https://github.com/The-Band-Solution/theband/issues/1192) | espera T003 |
| T013 parâmetros da base | [#1201](https://github.com/The-Band-Solution/theband/issues/1201) | espera T004; **nenhum valor escrito no código para não esperar** |
| T017 a fachada com os parâmetros | [#1205](https://github.com/The-Band-Solution/theband/issues/1205) | espera T013 |
| T019 caminho feliz do job, log e aviso | [#1207](https://github.com/The-Band-Solution/theband/issues/1207) | espera T017 |
| T020 o gatilho na sincronização | [#1208](https://github.com/The-Band-Solution/theband/issues/1208) | espera T019: disparar antes enfileiraria um job que só levanta |
| T021, T024, T026 as telas | [#1209](https://github.com/The-Band-Solution/theband/issues/1209), [#1212](https://github.com/The-Band-Solution/theband/issues/1212), [#1214](https://github.com/The-Band-Solution/theband/issues/1214) | o protótipo foi aprovado; esperam T017, T019 e T020 |
| T022 aceitação 👤 | [#1210](https://github.com/The-Band-Solution/theband/issues/1210) | espera a tela e a release |
| T029 gates, PR | [#1217](https://github.com/The-Band-Solution/theband/issues/1217) | fecha a feature; o PR espera T021 |

## Riscos e dependências

- **A base pode mudar o nome das chaves**: o código recebe os parâmetros como argumento
  (`contracts/review-network.md`, *Os parâmetros entram pela fachada*), e só `Parameters` muda;
- **a revisão semântica pode trocar a unidade** (R2): muda `Graph.concentration/2` e o teste dela, e
  não a tabela;
- **árvore compartilhada com dois agentes**: commits só dos meus caminhos.

## Definition of Done do sprint

- [ ] cada tarefa do escopo com a evidência na issue: comando, código de saída, defeito injetado e o
      código de saída com ele
- [ ] `mix gates` com `MIX_TEST_PARTITION=73`, código de saída lido sem pipe
- [ ] `sprint-review.md` separando feito de não feito
- [ ] `licoes-aprendidas.md` atualizado
