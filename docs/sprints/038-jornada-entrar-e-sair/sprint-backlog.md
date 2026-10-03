# Sprint 038 — a jornada de entrar e sair, vista por quem opera

**Período**: aberto em 2026-10-03, na iteration *Sprint 035* do GitHub (`ee36a246`)
**Feature**: [074](../../specs/074-jornada-entrar-e-sair/spec.md) · **Plano**: [plan.md](../../specs/074-jornada-entrar-e-sair/plan.md) · **Segurança**: [seguranca.md](../../specs/074-jornada-entrar-e-sair/seguranca.md)
**Épico**: [#802](https://github.com/The-Band-Solution/theband/issues/802) · **ADR**: [0005](../../docs/adr/0005-telemetria-da-jornada.md), aceita em 2026-10-03
**Branch dos documentos**: `feature/802-tracing-signoz`

*O número 038 é o próximo livre olhando também os branches abertos: `development` vai até 037
(papel de administrador), e `feature/1182-rede-de-revisao` tem outro 037 (rede de revisão), que
vai precisar de renumeração quando entrar.*

## Objetivo do sprint

Quem opera a plataforma passa a saber, no SigNoz, **quem não conseguiu entrar e por quê**, quando
sair falhou, e quando definir ou trocar a senha falhou — sem que nenhum segredo saia do processo.

## O código espera — leia antes de começar

**O código espera a #1227 mergeada; a #887 tem as tarefas entregues e espera aceitação.**

| pré-requisito | estado em 2026-10-03 | bloqueia |
|---|---|---|
| PR [#1227](https://github.com/The-Band-Solution/theband/issues/1227) ([#1222](https://github.com/The-Band-Solution/theband/issues/1222), o log das consultas redigido) | aberto | **toda tarefa que toca `lib/` ou `mix.exs`** (T003 em diante, exceto T006 e T007) — decisão D6, §14.0 item 2 |
| [#887](https://github.com/The-Band-Solution/theband/issues/887) (064/US3) | aberta só à espera da aceitação; as tarefas [#871](https://github.com/The-Band-Solution/theband/issues/871), [#872](https://github.com/The-Band-Solution/theband/issues/872) e [#873](https://github.com/The-Band-Solution/theband/issues/873) estão **fechadas** | **não bloqueia** |
| [#1162](https://github.com/The-Band-Solution/theband/issues/1162) (distribuição Erlang em `0.0.0.0`) | aberta | a implantação do SigNoz no mesmo VPS (T026) |
| os seis itens de S6 da avaliação | não verificados | a implantação do SigNoz (T026) |

T006 (o SigNoz local num profile) e T007 (a taxonomia em YAML) **não** tocam `lib/` nem `mix.exs`
e podem começar antes da #1227.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), lido em 2026-10-03:

| lição | como está sendo aplicada |
|---|---|
| L108 — feature sem sprint backlog | este documento existe antes do código; as issues foram criadas com tipo, hierarquia e iteration no mesmo passo |
| L100 — branch de documentação sem PR | a spec, o plano e as tarefas estão em `feature/802-tracing-signoz`, **sem PR**. Antes do primeiro branch de código: `git log origin/development..origin/feature/802-tracing-signoz` vazio, ou o PR dos documentos aberto primeiro |
| L69 — defeito dentro de `Logger.info` é invisível a teste | o passo é **relator**: o teste afirma sobre o span que chega ao exportador, e sobre o retorno de `Auth`, nunca sobre o log |
| L42 — mensagem atrasada de telemetria entra na contagem seguinte | os testes de span esvaziam a caixa antes de ligar o exportador de teste, e a contagem tem de repetir entre execuções |
| L50 — o teste que compara precisa provar que mediu | o teste das sentinelas (T018) afirma que chegaram spans dos quatro passos **antes** de qualquer `refute` |
| L77 — verificador novo nasce com teste que não passa por ele | o teste troca só o destino, e não o filtro (S15); a função de suporte recusa ligar sem o filtro (T008) |
| L56 — filtrar telemetria pela `source` não alcança SQL cru | é a razão da FR-012: a regra do #1227 é necessária e não suficiente para span de consulta; nesta fatia não há nenhum |
| L38 e L53 — o custo se mede pela diferença, e o teto vem da medida dos dois lados | SC-006 (T030) compara com e sem a telemetria no mesmo cenário; o limiar de T015 é diferença de medianas |
| L21 — função sem consumidor não é funcionalidade entregue | a US5 (painel versionado) é o consumidor visível; sem ela os spans são infraestrutura sozinha |
| L84 e L93 — o painel dizer `Done` não é aplicação no ar | a aceitação de produção é a T027: a própria entrada aparecendo no SigNoz, pelo túnel |

## User stories

| # | user story | issue | Priority | Estimate |
|---|---|---|---|---|
| US1 | Sei quem não conseguiu entrar, e por quê | [#1230](https://github.com/The-Band-Solution/theband/issues/1230) | P1 | — |
| US2 | Sei quando sair falhou | [#1231](https://github.com/The-Band-Solution/theband/issues/1231) | P1 | — |
| US3 | Nada disso vaza | [#1232](https://github.com/The-Band-Solution/theband/issues/1232) | P1 | — |
| US4 | Sei quando definir ou trocar a senha falhou | [#1233](https://github.com/The-Band-Solution/theband/issues/1233) | P2 | — |
| US5 | Quem opera encontra as respostas sem montar consulta | [#1234](https://github.com/The-Band-Solution/theband/issues/1234) | P2 | — |

`Priority` é a da spec; não foi gravada no campo do projeto nesta abertura. `Estimate` em branco é
**desconhecido**, não zero: ninguém estimou ainda.

## Tarefas

| # | tarefa | atende | tipo | issue | estado |
|---|---|---|---|---|---|
| T001 | 👤 Aceitar ou recusar a ADR 0005 | — | Task | [#1235](https://github.com/The-Band-Solution/theband/issues/1235) | feito — decisão de 2026-10-03 |
| T002 | 👤 Decidir D1 a D7 da avaliação de segurança | — | Task | [#1236](https://github.com/The-Band-Solution/theband/issues/1236) | feito — decisão de 2026-10-03 |
| T003 | Conferir que os pré-requisitos de segurança chegaram | — | Task | [#1237](https://github.com/The-Band-Solution/theband/issues/1237) | bloqueado — PR #1227 |
| T004 | Fixar as dependências do OpenTelemetry | — | Task | [#1238](https://github.com/The-Band-Solution/theband/issues/1238) | bloqueado — T003 |
| T005 | Configurar o SDK explicitamente, e desligado por padrão | — | Task | [#1239](https://github.com/The-Band-Solution/theband/issues/1239) | bloqueado — T003 |
| T006 | Subir o SigNoz local num profile próprio | — | Task | [#1240](https://github.com/The-Band-Solution/theband/issues/1240) | a fazer |
| T007 | Declarar a taxonomia da jornada | — | Task | [#1241](https://github.com/The-Band-Solution/theband/issues/1241) | a fazer |
| T008 | Suporte de teste para ler spans | — | Task | [#1242](https://github.com/The-Band-Solution/theband/issues/1242) | bloqueado — T003 |
| T009 | O exportador que só deixa sair o permitido | — | Task | [#1243](https://github.com/The-Band-Solution/theband/issues/1243) | bloqueado — T003 |
| T010 | O handler que traduz sem sumir | — | Task | [#1244](https://github.com/The-Band-Solution/theband/issues/1244) | bloqueado — T003 |
| T011 | A função única que emite o passo | — | Task | [#1245](https://github.com/The-Band-Solution/theband/issues/1245) | bloqueado — T003 |
| T012 | A entrada emite o passo depois da transação | US1 | Task | [#1246](https://github.com/The-Band-Solution/theband/issues/1246) | bloqueado — T003 |
| T013 | O correlator nasce no servidor e morre na tentativa | US1 | Task | [#1247](https://github.com/The-Band-Solution/theband/issues/1247) | bloqueado — T003 |
| T014 | A abertura da entrada conta uma vez | US1 | Task | [#1248](https://github.com/The-Band-Solution/theband/issues/1248) | bloqueado — T003 |
| T015 | O tempo e a sessão não distinguem os motivos | US1 | Task | [#1249](https://github.com/The-Band-Solution/theband/issues/1249) | bloqueado — T003 |
| T016 | Sair diz se encerrou alguma coisa | US2 | Task | [#1250](https://github.com/The-Band-Solution/theband/issues/1250) | bloqueado — T003 |
| T017 | A queda de sessão diz o motivo | US2 | Task | [#1251](https://github.com/The-Band-Solution/theband/issues/1251) | bloqueado — T003 |
| T018 | As sentinelas não saem, em nenhum dos quatro passos | US3 | Task | [#1252](https://github.com/The-Band-Solution/theband/issues/1252) | bloqueado — T003 |
| T019 | O gate da taxonomia | US3 | Task | [#1253](https://github.com/The-Band-Solution/theband/issues/1253) | bloqueado — T003 |
| T020 | Sem backend, entrar e sair seguem iguais | US3 | Task | [#1254](https://github.com/The-Band-Solution/theband/issues/1254) | bloqueado — T003 |
| T021 | Definir e trocar a senha emitem o desfecho | US4 | Task | [#1255](https://github.com/The-Band-Solution/theband/issues/1255) | bloqueado — T003 |
| T022 | O painel das três perguntas | US5 | Task | [#1256](https://github.com/The-Band-Solution/theband/issues/1256) | bloqueado — T003 |
| T023 | O alerta de enumeração de contas | US5 | Task | [#1257](https://github.com/The-Band-Solution/theband/issues/1257) | bloqueado — T003 |
| T024 | 👤 Medir o VPS antes de subir | — | Task | [#1258](https://github.com/The-Band-Solution/theband/issues/1258) | a fazer 👤 |
| T025 | 👤 Consertar a distribuição Erlang antes de juntar as redes | — | Task | [#1259](https://github.com/The-Band-Solution/theband/issues/1259) | a fazer 👤 |
| T026 | 👤 Subir o SigNoz no Dokploy, fechado | — | Task | [#1260](https://github.com/The-Band-Solution/theband/issues/1260) | a fazer 👤 |
| T027 | 👤 Ligar a aplicação ao coletor | — | Task | [#1261](https://github.com/The-Band-Solution/theband/issues/1261) | a fazer 👤 |
| T028 | 👤 Medir depois, e conferir a saída e a retenção | — | Task | [#1262](https://github.com/The-Band-Solution/theband/issues/1262) | a fazer 👤 |
| T029 | Atualizar o runbook | — | Task | [#1263](https://github.com/The-Band-Solution/theband/issues/1263) | bloqueado — T003 |
| T030 | Medir o custo da telemetria na entrada | — | Task | [#1264](https://github.com/The-Band-Solution/theband/issues/1264) | bloqueado — T003 |
| T031 | Rodar os gates e abrir o PR | — | Task | [#1265](https://github.com/The-Band-Solution/theband/issues/1265) | bloqueado — T003 |

Tarefas de fase (sem US) são filhas do épico [#802](https://github.com/The-Band-Solution/theband/issues/802); as de US são filhas da US. Tarefa não
recebe `Priority`.

## Escopo — **a confirmar pela pessoa mantenedora**

As 31 tarefas estão na iteration, porque a abertura foi pedida para a 074 inteira. A proposta,
seguindo a estratégia do `tasks.md`:

- **neste sprint**: Fases 0 a 5 (T001–T020), o **MVP** — US1, US2 e US3 juntas, porque a US3 é a
  condição de a US1 ir para produção;
- **se couber**: US4 (T021) e US5 (T022, T023), T029–T031;
- **fora, se a #1162 não fechar**: T024–T028, a implantação. O código pode ir para `development`
  com a telemetria **desligada** (FR-015), sem mudar nada para quem entra.

## Fora do escopo deste sprint

- a entrada do operador da plataforma (`/platform/sign-in`, com segundo fator) — próxima fatia
  do #802, com avaliação própria;
- J2 a J6, a US3 do épico (perceber o Oban parado) e qualquer instrumentador automático;
- o limite por IP em `POST /session` — [#1229](https://github.com/The-Band-Solution/theband/issues/1229) (D7).

## Riscos e dependências

- **o PR #1227** depende de revisão da equipe `the-band`; enquanto não mergear, só T006 e T007
  andam;
- **o processador em lote do SDK** pode não expor o descarte por fila cheia (research R13); a T020
  decide, e a lacuna, se existir, é declarada;
- **o Foundry** (`foundryctl forge`) é a instalação suportada do SigNoz e não foi testado nesta
  sessão; a medida usou o compose da v0.125.0. A T006 é a primeira a usá-lo;
- **o VPS** não foi medido; a T024 pode derrubar a hospedagem no mesmo VPS (D3).

## Definition of Done do sprint

- [ ] quality gates verdes, com o código de saída de `mix gates` lido
- [ ] `mix knowledge.validate` e o `taxonomia_test.exs` verdes
- [ ] cada guarda de segurança vista **reprovando** com o defeito injetado, com a evidência na issue
- [ ] issues encerradas ou repriorizadas com justificativa; US só fecham com aceitação
- [ ] `sprint-review.md` escrito, separando feito de não feito
- [ ] `licoes-aprendidas.md` atualizado
