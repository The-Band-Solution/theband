# Sprint 030 — Review

**Período**: 2026-09-07 a 2026-09-12 · **encerrado em 2026-09-13** (registro retroativo)
**Feature**: [060 — a tela da equipe](../../../specs/060-tela-da-equipe/spec.md) ·
**Herança**: 045 (D06), 055 (FR-003 e o ato de subequipe)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories da 060 | 6 (US1–US5, US9) | 6 executadas · **1 aceita** (US4) · **5 não aceitas** — 1 por defeito (US9), 3 por critério não medido (US2, US3, US5), 1 por teste prometido ausente (US1) |
| Tarefas da 060 | 29 | 29 · **18 com sucesso** · **9 sem sucesso** (T010–T012, T015, T019, T020, T022, T028, T029) · 2 não avaliadas (T023, T025) |
| Herança | 3 (D06, FR-003, subequipe) | 3 executadas · **1 aceito** (H3) · **2 não aceitos** (H1, H2) · o #860 **não avaliado** |
| Issues | — | **nenhuma** — a 060 nunca teve issue |
| `mix gates` | — | `exit 0` em cada PR (#853: 2 026 testes · #857: 2 028 · #863: 2 112 · #860: 2 085); CI verde em `development` |

**Tudo o que o `tasks.md` pedia foi executado, e este é o sprint com menos rastro dos
últimos vinte.** Sem backlog, sem issue, sem iteration, e com a aceitação feita só em
2026-09-13/14 — depois de a v0.8.0 já estar avaliada carregando estes entregáveis. O que a
aceitação achou está em [`aceitacao.md`](aceitacao.md), e o resumo abaixo.

## O que foi feito

| User story | Tarefas | PR | O que chegou à tela |
|---|---|---|---|
| US1 — quem está na equipe, e de onde veio cada afirmação | T009–T013 | #821 | as duas abas de `/teams/:id` com a aba na URL; a seção *Members* por vínculo, com a legenda observado/declarado, a discordância nomeada e *Where this team sits*; quem não gere lê tudo e não vê ação — e o evento é recusado com motivo; o teto de consultas medido |
| US2 — declarar o papel de quem a origem mostra, e alterá-lo | T018–T020 | #821 | *Declare role* / *Change role* na linha, *＋ new role…* sem sair dela, e o lote *Declare all roles* por vínculo |
| US3 — a pessoa saiu, e o que ela fez continua contando | T014–T015 | #821 | *Left the team…* na linha, com data obrigatória e a origem do fim dita; a saída grava quem e quando, alcança os dois papéis, e a coleta não recria |
| US4 — o vínculo que nunca foi | T016–T017 | #821 | *Mistake…* na linha, com razão obrigatória e o texto que separa de "saiu"; o equívoco alcança todos os vigentes do par |
| US5 — criar o papel da organização a partir da estrutura | T021–T022 | #821 | a seção *Roles*: catálogo e criados, criar com código sugerido, renomear, ocultar; quantas pessoas por papel, aqui e na organização |
| US9 — o fluxo da equipe inteira | T026–T029 | #821 | granulação e janela no endereço, *Prometido × Entregue* com a definição junto do título, os três gráficos na equipe composta, o gráfico pequeno no cartão da subequipe |
| fundação — a concessão *gerir estrutura da equipe* | T001–T008 | #817, #819, #821 | `/roles` concede e revoga *manages team structure*; `pode_gerir_estrutura/3` substitui `pode_declarar_estrutura/4` — **zero contas perderam escrita, medido** |

### A herança, e o que entrou sem tarefa

| Entregável | PR | O que mudou |
|---|---|---|
| **A aba *Flow per person*** — US10–US12 da extensão, **sem tarefa** | #860 (2026-09-12) | o burn por pessoa e a previsão que diz sua confiança; **três consultas para qualquer número de membros** (`flow_per_person_test.exs:113`). 25 testes, 3 defeitos reinjetados. O `tasks.md` dizia que não havia protótipo; havia, aprovado em 2026-09-08 — e os requisitos só estão sendo escritos agora (#913). **Não avaliado** pela aceitação: precisa de registro próprio |
| **D06 da v0.7.0 refeito** — a conta desativada como o protótipo pediu | #853 (2026-09-10) | razão de lista fechada mais nota, episódio com as duas pontas (`account_disablements`), a recusa que fica na tela, o vocabulário na base de conhecimento. Migração `20260910050000`, aditiva; backfill criou zero episódios porque havia zero contas desativadas |
| **FR-003 da 055 ganha tela** — vincular pessoa a equipe | #863 (2026-09-12) | o ato que era cláusula MUST desde 2026-09-06 e tinha função com 11 testes e zero chamadas em `lib/`. Seis vereditos de `vinculo_possivel.ex` calculados **antes do botão**; papel obrigatório, data opcional; 35 testes (21 domínio, 14 tela). **A tela veio antes do protótipo ser mergeado** — o protótipo está no #915, aberto |
| **Declarar equipe dentro de outra é um ato** | #857 (2026-09-11) | `Repo.transaction` cobrindo `declare_structural_team/4` e `compose_teams/4`; o teste isola o segundo passo (chave estrangeira `whole_team_id`) e prova que **nenhuma equipe fica** na organização. Reinjetado: desfeita a transação, o teste nomeou a invariante |

## O que a aceitação achou

A avaliação do papel de Product Owner, em 2026-09-14, com evidência executada — os detalhes em
[`aceitacao.md`](aceitacao.md):

1. **O cartão *Squads at a glance* não é o do protótipo.** Três números `open items / median
   wait / pipeline` em vez de `members / open / stopped`, sem a mistura de conceitos
   `TASK n · US n · BUG n · EPIC n`. É o único defeito de **comportamento** observado na 060, e
   derruba a US9. **O próprio `tasks.md` confessa** (T029, "Aberto ainda") e marca `[x]` assim
   mesmo;
2. **Três testes prometidos não existem** — `abas_da_equipe_test`, `estrutura_membros_test`,
   `estrutura_permissao_test` (T010–T012, marcadas `[x]`). O comportamento que guardariam está
   certo: a sonda do papel provou aba inválida → Dashboard com aviso, as sete marcas em texto,
   `MAINTAINER` ausente, o cabeçalho com as quatro contagens. Mas a sonda não vive no repositório
   e não guarda regressão — constituição XI;
3. **Quatro user stories recusadas por critério não medido, não por defeito**: SC-013 (tempo da
   saída, US3), AC2 (histórico na lista, US2), SC-005 e FR-081 (papel em outra equipe e a coluna
   de concessões, US5). Podem virar aceitas **no ato da confirmação**, se o papel medir;
4. **Herança H1 (#853)**: os cinco pontos que a v0.7.0 recusou no D06 **estão fechados com
   evidência executada** — 32 testes, `exit 0`. O que impede a aceitação: três cláusulas dos
   FR-025/027 sem teste (vocabulário ausente recusa; frase *"no note"*; `not recorded`), a
   invariante da transação sem teste de falha injetada, e a conferência do QA item a item não
   encontrada. Avaliação incompleta, não comportamento errado;
5. **Herança H2 (#863)**: o `README.md` do protótipo — nas duas cópias, `development` e o #915 —
   diz **"Aprovação: aguardando a pessoa mantenedora — três perguntas abertas, duas mudam o que a
   tela desenha"**; o `vinculo_possivel.ex` diz "aprovado em 2026-09-11". As duas não podem ser
   verdadeiras. A régua §3.1 item 2 e §3.4 não estão implementadas, a §3.7 não recusa data
   futura, e a recusa do domínio chega ao flash **em português, crua**, numa tela em inglês — o
   próprio teste asserta a palavra "papel". E o #915 traz **conteúdo idêntico** ao já mergeado:
   republicação, não protótipo novo;
6. **Herança H3 (#857)**: aceito — `Repo.transaction` com `Repo.rollback`, e o teste que injeta a
   falha do segundo passo prova que nenhuma equipe fica. 72 testes, `exit 0`;
7. **O #860 não é T026–T029.** O corpo do #821 é que cita T026–T029; o #860 é a aba *Flow per
   person*, US10–US12 da extensão, que o `tasks.md` dizia não ter tarefa nem protótipo. Entrou
   fora do plano e **não foi avaliado** — precisa de registro próprio.

## Evidências

| O quê | Medida |
|---|---|
| `mix gates` | `exit 0` em #853 (2 026 testes), #857 (2 028), #863 (2 112), #860 (2 085); #821 sem seção de evidência no corpo — **lacuna**; CI verde em `development` (run 34779226200 sobre `0ccf02b`) |
| defeitos reinjetados | #853: 4 injetados, 4 pegos · #857: 1, pego · #863: 4, pegos (3 pela busca deixando de calcular o veredito) · #860: 3, pegos |
| teto de consultas | T013 — as duas abas medidas; US9: **3** consultas para qualquer número de membros (`flow_per_person_test.exs:113`) |
| migração da herança | `20260910050000_episodio_de_desativacao.exs`: só `add`/`create table`/índices/`INSERT` de backfill; o `down` faz `drop table` — rollback perde episódios escritos depois |
| revisão | #816–#821: revisor pedido, `reviews` 0 · **#853, #857, #860, #863: revisor não pedido**, `reviews` 0. Nenhum PR do sprint tem revisão registrada |
| aceitação | testes nomeados por US: US1 **65** · US3+US4 **54** · US2+US5 **72** · US9 **41** · herança H1 **32**, H2+H3 **72** — todos `EXIT=0` sobre `0ccf02b`; sonda de tela do papel 3/3. Logs no scratchpad da sessão, fora do repositório |

## O que não foi feito

| O quê | Motivo | Destino |
|---|---|---|
| as **issues** da 060 | `/speckit-taskstoissues` não rodou; o sprint correu sem backlog | criação retroativa **depois** da confirmação da aceitação, como a 052 no sprint 026 — cada issue dizendo que nasceu depois do trabalho |
| **US6, US7, US8** | *PR 2* da spec, fora deste sprint por decisão do `tasks.md` | seguem no product backlog; FR-041 e FR-084 sem tarefa |
| **US10–US12** — os gráficos por membro | extensão de 2026-09-08 sem protótipo | atrás da US9; protótipo antes |
| as **seis perguntas do `plan.md`** | bloqueavam fechar T002, T014, T017 e T022 — e as tarefas fecharam sem resposta registrada | **dívida**: `started_at` de `eo_team_compositions` (FR-037), as cinco transições sem teste, `eo_organizational_units` sem leitor, tabela × cartões da subequipe (#820) |
| a **revisão independente** | nenhum dos sete PRs foi revisado; quatro nem pediram | resíduo irrecuperável para os mergeados; o atestado datado da pessoa mantenedora é o que se recupera |

## Entregáveis não aceitos

| Entregável | Por quê | Destino proposto |
|---|---|---|
| **US1** (D1) | teste prometido ausente (T010–T012) — constituição XI; FR-004 "composta de K" sem asserção | **nova tarefa**, próximo sprint, em primeiro: os três arquivos de teste — a sonda do papel é o esqueleto. O valor entregue fica |
| **US3** (D2) | SC-013 (< 1 min) não medido | **medir na confirmação** — o papel cronometra a saída em `?tab=structure`; conforme → aceita sem tarefa |
| **US2** (D4) | AC2 — "histórico acessível na lista" não medido; a tela diz "da data informada ou de hoje" | **decisão do papel**: se o vínculo encerrado na linha vale como histórico, aceita; senão, tarefa para a asserção e o texto da FR-017 |
| **US5** (D5) | SC-005 em **outra** equipe e FR-081 (coluna de concessões) não medidos | **medir** — sonda com duas equipes na mesma organização + leitura da seção *Roles* |
| **US9** (D6) | cartão *Squads at a glance* ≠ protótipo; SC-009 e FR-064 sem asserção | **nova tarefa via Design** — `median wait` por subequipe e a matiz são decisões abertas (T029, L67); depois o cartão conforme o protótipo, a asserção de SC-009 e a frase de FR-064 |
| **H1** — D06 refeito (#853) | 4 cláusulas sem teste; conferência do QA ausente; FR-025–029 **sem user story** na 045 | **nova tarefa** (nunca reabrir #853): quatro testes + conferência §3 com captura; e a 045 declara a US que falta |
| **H2** — FR-003 com tela (#863) | régua com aprovação **pendente**; §3.1/§3.4/§3.7 furadas; recusa em português; `declared_by_user_id` não asserido | **ordem obrigatória**: P1–P3 respondidas → *Decided* e republicação no mesmo endereço → (se P1 = A) `origin` e as três medidas em YAML → §3.4/§3.7 → recusas pelo catálogo → testes → QA. A #703 (055/US2, fechada em 2026-09-02 com a FR-003 sem tela) **não é reaberta** |

**Aceitos**: US4 (D3) — 10 de 10; H3 — 9 de 9. Com a ressalva comum a todos: revisão nunca
registrada, e a classificação (*atestada sem registro* × *não ocorreu*) é do papel.

## Dívida gerada

- **as seis perguntas do `plan.md` fecharam sem resposta** — a tarefa que dependia delas foi
  marcada feita assim mesmo. É a forma mais silenciosa de dívida: não aparece em teste nenhum;
- **`Periodos.interseccao/1` continua pessimista** (da 057/058) — a tela por vínculo herda a
  marca de período parcial em toda linha quando falta `started_at`;
- **o protótipo do vínculo declarado (#915) está aberto** e a tela do #863 já está em
  `development` — a ordem "protótipo antes do código" foi invertida, e o registro precisa dizer
  qual dos dois é a régua;
- **`#821` sem seção de evidência** no corpo — o maior PR do sprint (T005–T025) não diz o
  código de saída dos gates onde o template pede.

## Lições deste sprint

Para o [registro acumulado](../licoes-aprendidas.md):

- **L108** — três features sem sprint backlog; a 060 é a que ficou sem issue nenhuma;
- **L102** nasceu aqui (2026-09-09) e **L103/L104** também (2026-09-10) — estão no registro;
- **L95, reincidiu**: quatro PRs sem revisor pedido, nenhum revisado;
- **L109 vista também aqui** — T029 marcada `[x]` com o próprio texto confessando que o cartão
  diverge do protótipo, e T010–T012 marcadas `[x]` sem o teste prometido: marcação manual de
  "feito", que é o que `sro.rule03` proíbe para aceitação;
- **duas fontes divergindo sobre a mesma aprovação** (README "pendente" × código "aprovado em
  2026-09-11") — a mesma família da paridade compose–Dokploy (#911) e do `RETOMAR.md` duplicado:
  o registro que não é único mente por um dos lados;
- **uma extensão de spec ganhou tela sem tarefa** (#860) — a L108 não é só "sem backlog": é
  trabalho que entra sem plano nenhum, e a aceitação não o encontra.
