# Sprint 003 — Registro de aceitação

**Feature**: [003-editar-remover-ferramentas](../../../specs/003-editar-remover-ferramentas/spec.md)
**Avaliado em**: 2026-08-10
**Papel**: Product Owner — Paulo Sergio Santos Junior
**Tipo**: `sro.product_owner_client` — quem demanda é quem decide, e a decisão é final

Cada critério foi percorrido contra evidência. A classificação é derivada disso,
nunca atribuída — `sro.rule03`.

## Resumo

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 3 |
| Aceitos | — a confirmar pelo papel |
| Não aceitos | — |
| Tarefas executadas com sucesso | — |
| Critérios avaliados | 21 |
| Critérios sem evidência | **0** |

## O que a avaliação encontrou antes de classificar

Percorrer os critérios um a um, em vez de conferir se o sprint "parecia
pronto", achou **três coisas que faltavam** — e as três foram feitas antes deste
registro, não anotadas como pendência:

| Achado | O que faltava | Onde estava a ilusão |
|---|---|---|
| **US2, AC4** | histórico não aparecia em tela nenhuma | `observation_history/2` existia e passava nos testes, sem nenhum consumidor |
| **SC-007** | nenhum teste de que a coleta **desmarca** | havia teste de que a retomada não desmarca. Metade da promessa verificada, e a outra metade parecendo verificada |
| **SC-010** | encerrar e retomar não tinham teste de isolamento | pessoas e equipes tinham; o ciclo de observação, não |

E antes deles, o achado que originou o trabalho: **retomar não tinha botão**.
Estava especificado, implementado e testado, e não havia como uma pessoa
executá-lo.

---

## D01 — A marca de ausência escopada por organização (L19)

**Produzido por**: F0 do sprint · correção de defeito da feature 001
**Materializa**: nenhuma user story — é correção de defeito (`osdef.defect`),
avaliada contra o comportamento que a feature 002 já exigia.

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| Coletar uma organização marca só os vínculos dela | funcional | **sim** | `sources_observation_test.exs` e `commands_test.exs`; removendo o escopo, **4 testes reprovam** |
| Nenhum vínculo de outra organização é tocado | funcional | **sim** | o teste diz o motivo por extenso: `coletar alfa marcou o vínculo de beta — é a L19 de volta` |
| A forma do teste cobre o que a suíte não cobria | não funcional | **sim** | duas organizações e duas coletas em sequência — forma ausente nos 151 testes anteriores |

**Fase derivada**: `sro.accepted_deliverable`.
**Fase da tarefa**: `sro.successfully_performed_scrum_development_task`.

**Ressalva registrada, e não é falha de critério**: o dado histórico marcado
errado **continua marcado**. Não foi desmarcado por decisão — não se sabe o que
a origem mostrava naquele instante, e desmarcar afirmaria observação que não
ocorreu, que é o próprio erro da L19. O reparo acontece na próxima coleta real
de cada organização.

---

## D02 — Encerrar a observação (US1)

**Produzido por**: F3 · T009 a T018
**Materializa**: US1 — Encerrar a observação de uma organização (atômica, P1)

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — impacto mostrado **antes** de confirmar | funcional | **sim** | tela em `localhost:4000/ferramentas`: 1 equipe, 5 vínculos, 4 pessoas só daqui, 1 permanece, 0 payloads apagados |
| AC2 — a ferramenta deixa de ser sincronizada | funcional | **sim** | `origem encerrada não é coletada`: `{:error, :observation_ended}`, com o Mox da borda HTTP sem expectativa nenhuma — qualquer chamada à origem derruba o teste |
| AC3 — registros seguem consultáveis, marcados, com data | funcional | **sim** | `a equipe da organização encerrada é marcada, não apagada` |
| AC4 — a credencial não existe mais | funcional | **sim** | `nenhuma linha remanescente, e nenhum texto cifrado` — consulta direta à tabela, não afirmação no código |
| AC5 — quem estava em duas mantém a outra | funcional | **sim** | `quem tem vínculo em outra organização NÃO é marcado`; `as organizações vigentes da pessoa passam de três para duas` |
| AC6 — a equipe derivada é marcada, não apagada | funcional | **sim** | mesmo teste de AC3, com equipe derivada no cenário |
| SC-001 — nada é apagado | não funcional | **sim** | banco real: 72 pessoas · 12 equipes · 82 vínculos · 472 payloads, **idênticos** antes e depois |
| SC-002 — 100% do exclusivo marcado, com data | não funcional | **sim** | `pessoa com vínculo apenas na organização encerrada perde vigência` |
| SC-003 — nada com proveniência vigente alhures é marcado | não funcional | **sim** | é o teste que importa: Paulo **não** é marcado ao encerrar `ifesserra-lab` |
| SC-004 — nenhuma credencial, nem cifrada | não funcional | **sim** | consulta direta; no banco real, credenciais restantes: 0 |
| SC-005 — a coleta não consulta a origem encerrada | não funcional | **sim** | ausência de expectativa no Mox é a prova |
| SC-008 — o vínculo encerrado permanece consultável | não funcional | **sim** | `o histórico mantém a organização encerrada` |
| SC-009 — os números da tela conferem com o que é marcado | não funcional | **sim** | `o número mostrado é o número que o encerramento marca` — o impacto é gravado no evento e lido de volta do banco |
| SC-010 — não atravessa tenant | não funcional | **sim** | **escrito nesta avaliação**: três testes, com a contraprova de que o dono continua alcançando |

**Fase derivada**: `sro.accepted_deliverable`.
**Fase da tarefa**: `sro.successfully_performed_scrum_development_task`.

---

## D03 — Retomar a observação (US2)

**Produzido por**: F4 · backend em T023 a T025; tela e histórico nesta avaliação
**Materializa**: US2 — Retomar uma observação encerrada (atômica, P2)

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — retoma a ferramenta existente, não cria segunda | funcional | **sim** | `reusa a ferramenta existente, não cria uma segunda` |
| AC2 — a coleta seguinte devolve vigência ao que reapareceu | funcional | **sim** | **escrito nesta avaliação**: reobserva um de dois vínculos e exige a distinção nos dois sentidos |
| AC3 — exige credencial nova | funcional | **sim** | `exige credencial nova, e ela passa a ser a ativa`; `credencial recusada não retoma` |
| AC4 — o histórico mostra encerramento e retomada | funcional | **sim** | **feito nesta avaliação**: `histórico de observação (2)` na tela, com as duas transições ao expandir |
| SC-006 — não duplica ferramenta, pessoa nem equipe | não funcional | **sim** | mesmo teste de AC1 |
| SC-007 — o que voltou fica vigente, o que não voltou segue marcado | não funcional | **sim** | **escrito nesta avaliação**; sem o segundo assert, desmarcar tudo passaria |
| SC-011 — nenhum segredo utilizável em tela | não funcional | **sim** | teste pela violação: procura `ghp_segredo_novo_12345` no HTML e exige não encontrar |

**Fase derivada**: `sro.accepted_deliverable`.
**Fase da tarefa**: `sro.successfully_performed_scrum_development_task`.

**Uma limitação declarada, e não é falha de critério**: o caminho feliz da
retomada **não foi exercitado contra o GitHub real**. Ele exige uma credencial
válida, e a chave mestra que decifra as credenciais do banco de desenvolvimento
é da pessoa mantenedora — não está no meu ambiente. O que foi verificado na
aplicação no ar é o botão, o formulário e o histórico; a retomada bem-sucedida
está provada em teste, com a borda HTTP simulada.

---

## Critérios alterados durante o sprint

Nenhum. Os 27 FR e os 11 SC estão como foram especificados e aprovados antes da
implementação.

## Critérios sem evidência

Nenhum. Os três que estavam sem evidência quando esta avaliação começou —
US2/AC4, SC-007 e SC-010 — foram cobertos antes deste registro, e a cobertura
está commitada.

---

## Fora do escopo avaliado

Não entram nesta avaliação porque **não entraram no sprint**, com destino
declarado no [backlog](sprint-backlog.md):

| Item | Destino |
|---|---|
| **US3 — renomear e remover credencial, limpar atenção** | product backlog, sem iteration |
| **Telas T019 a T022** | product backlog; a tela de encerramento existe e cobre o caminho principal |
| **Reparo do dado histórico da L19** | acontece na próxima coleta real de cada organização |
| **Janela da iteration do sprint 002** | decisão pendente — corrigir exige mexer em iterations, causa da L11 |

## Entregável do sprint

`sro.sprint_deliverable_composed_of_accepted_deliverable` admite apenas
entregáveis aceitos. Com D01, D02 e D03 derivados como aceitos, o entregável do
sprint 003 é composto pelos três — **sujeito à confirmação de quem desempenha o
papel**, que é ato humano e não decorre desta avaliação.

## Nota sobre a revisão independente

Continua **bloqueada por ferramenta**: com uma identidade no repositório, o
autor não aprova o próprio PR. A pessoa mantenedora revisou e concordou com os
PRs anteriores sem registrar comentário — o registro ausente não significa
revisão ausente, e é a ferramenta que não sabe representar isso. Fecha com bot
ou GitHub App.
