# Sprint 002 — Registro de aceitação

**Feature**: [002-escopo-por-organizacao](../../../specs/002-escopo-por-organizacao/spec.md)
**Avaliado em**: 2026-08-10
**Papel**: Product Owner — Paulo Sérgio dos Santos Júnior
**Confirmado em**: 2026-08-10 — *"D01 .. aceito"*

**Tipo de Product Owner**: `sro.product_owner_client` — a pessoa mantenedora é também
quem demanda. A decisão de aceitação é final, não representativa.

> **Confirmado pelo papel.** Cada critério foi percorrido contra evidência, a
> classificação foi derivada do que a evidência sustenta, e a pessoa alocada ao papel
> confirmou: **D01 aceito**. A fase vale a partir daqui.

## Resumo

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 1 — D01 |
| Critérios funcionais percorridos | 5 |
| Critérios não funcionais percorridos | 6 |
| Aceitos | **1** — D01, confirmado |
| Critérios sem evidência | 0 |
| User stories não entregues | 2 — US2 e US3 |

---

## D01 — Cada registro diz de qual organização veio

**Materializa**: US1 (atômica) · [#80](https://github.com/The-Band-Solution/theband/issues/80)
**Produzido por**: T001 a T012, T020 a T024 · issues
[#83](https://github.com/The-Band-Solution/theband/issues/83),
[#84](https://github.com/The-Band-Solution/theband/issues/84),
[#85](https://github.com/The-Band-Solution/theband/issues/85),
[#86](https://github.com/The-Band-Solution/theband/issues/86)

### Critérios funcionais

| Critério | Conforme | Evidência |
|---|---|---|
| AC1 — duas organizações coletadas; cada pessoa exibe a organização de onde veio | **sim** | `/pessoas` traz a coluna "organizações"; teste de interface `/pessoas mostra as organizações de cada pessoa`. No banco real, as 72 pessoas têm organização — V9 devolve **0** sem |
| AC2 — conta em duas organizações aparece **uma vez**, indicando as duas | **sim** | teste `a pessoa em duas organizações aparece uma vez, com as duas` conta as ocorrências no HTML; no dado real, `Paulo` aparece uma vez com três organizações e `EduardoNFraiz` com duas |
| AC3 — cada equipe exibe a organização a que pertence | **sim** | `/equipes` traz a coluna; teste `/equipes mostra a organização de cada equipe`. Nenhuma equipe organizacional pode ficar sem — o banco recusa |
| AC4 — duas organizações com equipes de mesmo identificador curto ficam distintas | **sim, por construção** | a Application Reference é `source_system + source_instance + external_id`, e o `external_id` do GitHub é único por time; o `slug` não participa da identidade. **Ressalva**: não houve colisão de slug nas três organizações reais, então isto está garantido pelo modelo e não observado em dado |
| AC5 — organização conectada e não sincronizada aparece sem registros, e o estado vazio diz que a coleta não ocorreu | **sim** | `empty_message/2` distingue "nenhuma sincronização trouxe pessoas ainda" de "nenhuma pessoa corresponde aos filtros"; teste `estado vazio explica a causa em vez de só dizer que está vazio` |

### Critérios não funcionais atribuídos a esta user story

| Critério | Conforme | Evidência |
|---|---|---|
| SC-001 — 100% das pessoas e equipes indicam a organização | **sim** | V9: 0 de 72 pessoas sem organização; nenhuma equipe organizacional sem, garantido pelo `check_constraint` |
| SC-003 — conta em duas organizações aparece uma vez sem filtro e em ambas as filtradas | **sim** | teste de interface, mais V7 e V8 no dado real |
| SC-003a — **nenhuma pessoa fica sem organização** | **sim** | V9: de 18 antes da derivação para **0** depois |
| SC-004 — a soma por organização é ≥ o total, e a diferença é o número de sobrepostos | **sim** | total 72, soma 75, e V8 encontra exatamente 3 vínculos sobrepostos (`Paulo` em 3 organizações conta 2 de diferença, `EduardoNFraiz` em 2 conta 1) |
| SC-005 — registros coletados antes recebem o vínculo **sem consultar a origem** | **sim** | V3: 10 de 10 atribuídas, 0 sem resolver. Os cinco testes rodam **sem expectativa no Mox da borda HTTP** — qualquer chamada os derruba |
| SC-007 — duas equipes de organizações diferentes com o mesmo identificador curto permanecem distintas | **sim, por construção** | mesma ressalva de AC4 |
| SC-009 — organização com membros fora de equipes passa a ter **exatamente uma** derivada, com **exatamente** os que faltavam | **sim** | os três casos ocorreram em dado real: The-Band-Solution 6/6 em times → nenhuma derivada; ifesserra-lab 5 membros, 0 times → derivada com 5; leds-conectafapes 64 membros, 15 fora → derivada com 15 |

**Fase**: `sro.accepted_deliverable` — os cinco critérios funcionais e os sete não
funcionais conformes, com evidência. **Derivada dos critérios e confirmada pelo papel
em 2026-08-10**, nesta ordem: a classificação decorreu da avaliação, e a confirmação
veio depois. Inverter a ordem é o que `sro.rule03` proíbe.

**Fase das tarefas**: T001 a T012 e T020 a T024 ficam
`sro.successfully_performed_scrum_development_task` — todas produziram apenas
entregáveis aceitos. **Nenhuma tarefa deste sprint foi executada sem sucesso**, e a
distinção importa: as quatro tarefas cuja definição estava errada tiveram a *definição*
corrigida, não o entregável recusado.

### Duas ressalvas que acompanham a aceitação

Não a impedem, e ficam registradas para que ninguém adiante confunda uma coisa com a
outra.

**AC4 e SC-007 estão garantidos pelo modelo, não observados em dado.** Nenhuma
colisão de `slug` entre as três organizações reais ocorreu. O que sustenta o critério
é a Application Reference não incluir o `slug`, o que é forte — mas é argumento de
construção, não medição.

**O esvaziamento da equipe derivada está coberto por teste, não por ocorrência.**
Exigiria que uma pessoa entrasse num time real do GitHub entre duas coletas. Mesma
classe da limitação de "ausência não é remoção" no sprint 001.

---

## Um defeito que a avaliação teria deixado passar

Registrado aqui porque é a informação mais útil deste documento.

A primeira execução de V9 devolveu **0 pessoas sem organização** — o critério SC-003a
atendido. E estava errado: `ifesserra-lab`, com 5 membros, havia recebido **72**
pessoas na equipe derivada, o tenant inteiro. Todas as três organizações passaram a
mostrar todas as 72 pessoas.

**O critério SC-003a passava, e a plataforma estava mentindo.** Só a leitura das
contagens por organização — que é o SC-009, não o SC-003a — expôs o problema.

A lição para este papel: **um critério atendido não é um critério suficiente.**
Percorrer os critérios um a um encontrou o defeito porque SC-009 exige "exatamente os
membros que faltavam", e 72 não é 5. Um registro que se contentasse com V9 teria
aceito o entregável.

---

## User stories não entregues

| # | User story | Estado | Destino proposto |
|---|---|---|---|
| US2 | Consultar uma organização de cada vez | o filtro existe nas consultas e é testado; a tela de seleção não foi feita | **volta ao product backlog**, com a parte de consulta já pronta registrada |
| US3 | Enxergar quem atravessa organizações | a consulta responde e `/pessoas` já sinaliza "em N organizações"; falta a tela dedicada e `list_people_in_several_organizations/2` | **volta ao product backlog** |

**Nenhuma das duas produziu entregável**, então não há entregável a recusar: elas não
foram executadas, e é diferente de terem sido executadas sem sucesso. Nenhuma tarefa
de US2 ou US3 é `sro.non_successfully_performed_scrum_development_task`.

As duas estavam **fora do MVP declarado** no sprint backlog, que era F1, F2, F3, US1
e F7. O sprint entregou o MVP.

## Entregável do sprint

`sro.sprint_deliverable_composed_of_accepted_deliverable` admite apenas entregáveis
aceitos.

| Composição |
|---|
| **D01** — confirmado em 2026-08-10 |

## Critérios alterados durante o sprint

**Nenhum critério de aceitação foi alterado.** Quatro **tarefas** tiveram a definição
corrigida — T001, T003, T007 e T020 —, porque o que pediam era inverificável ou
impossível. Cada correção está escrita na própria tarefa. Nenhum critério de user
story mudou.

## Critérios sem evidência

**Nenhum.** Os cinco funcionais e os sete não funcionais foram avaliados contra
evidência executada.

## O que a aceitação **não** destrava

| O quê | De quem | Onde |
|---|---|---|
| aceitação dos entregáveis | Product Owner — este documento | `aceitacao.md` |
| **revisão independente do código** | Reviewer, alguém que não implementou | aprovação do pull request |

### A revisão do PR #93, e o que ela é

**2026-08-10** — [PR #93](https://github.com/The-Band-Solution/theband/pull/93)
mergeado na `main` em `f8941ee`, com uma revisão registrada:

```text
GET /repos/.../pulls/93/reviews
  paulossjunior  COMMENTED  2026-08-10T21:24:21Z
```

**É registro, e não é aprovação.** O GitHub recusa `requested_reviewer` para o autor do
PR — `422 Review cannot be requested from pull request author` —, e recusa o autor
aprovar o próprio PR. Nenhum nível de permissão contorna: a pessoa mantenedora é admin
do repositório e da organização, e a recusa é a mesma.

O que se afirma, então, é o mais forte que a evidência sustenta e não mais que isso:

| Pergunta | Resposta | Evidência |
|---|---|---|
| o entregue atende ao especificado? | **sim** | este documento, 5 critérios funcionais e 7 não funcionais |
| os gates passam? | **sim** | nove verdes, incluindo o de reprodutibilidade |
| o código foi lido por um humano que não o escreveu? | **sim** | revisão registrada em `pulls/93/reviews`, com data |
| existe **aprovação** registrada? | **não** | a revisão é `COMMENTED`; o GitHub não permite `APPROVE` do autor |

Isso é melhor que o sprint 001, onde a revisão existia apenas como atestado neste
arquivo — atestado depende de quem lembra, registro não. E continua abaixo do que o
princípio VII pede.

**A causa está nomeada, e é de ferramenta.** Quem implementou é o agente, cujos commits
trazem `Co-Authored-By: Claude Opus 5` e que não tem conta; quem abre o PR com o próprio
token é registrado como autor sem ter escrito o código. Fecha-se abrindo os PRs com
identidade de agente — GitHub App ou conta de bot —, e aí esta mesma revisão pode ser
um `APPROVE`.

**Duas revisões idênticas ficaram no #93**, por repetição do comando. Revisão submetida
não se apaga pela API — só rascunho. Ruído registrado em vez de escondido.

**O resíduo do sprint 001 não se recupera**: #89, #90 e #91 foram mergeados sem
nenhuma revisão registrada, e não há como revisar PR mergeado.

## Decisões do papel

| Decisão | Resultado |
|---|---|
| classificação de D01 | **aceito** em 2026-08-10, com as duas ressalvas registradas — colisão de slug garantida pelo modelo e não observada; esvaziamento da derivada coberto por teste e não por ocorrência |
| destino de US2 e US3 | **voltam ao product backlog** — feito: iteration limpa e status `Backlog` nos itens [#81](https://github.com/The-Band-Solution/theband/issues/81) e [#82](https://github.com/The-Band-Solution/theband/issues/82), que permanecem abertos |
| dívida dos 10 vínculos sem lastro | **fechada por limitação declarada**, com o id do conceito nomeado em cada mapeamento. Fechá-la de verdade exige declarar 10 relações em 5 ontologias — feature própria |

**As ressalvas acompanham a aceitação e não a diluem.** Um entregável aceito com
ressalva registrada é diferente de um aceito sem nenhuma, e quem ler adiante precisa
poder distinguir os dois sem investigar.
