# Sprint 002 — Registro de aceitação

**Feature**: [002-escopo-por-organizacao](../../../specs/002-escopo-por-organizacao/spec.md)
**Avaliado em**: 2026-08-10
**Papel**: Product Owner — **a confirmar por Paulo Sérgio dos Santos Júnior**

**Tipo de Product Owner**: `sro.product_owner_client` — a pessoa mantenedora é também
quem demanda. A decisão de aceitação é final, não representativa.

> **Este documento propõe; não decide.** Cada critério foi percorrido contra
> evidência, e a classificação é derivada do que a evidência sustenta. A fase de cada
> entregável só passa a valer quando a pessoa alocada ao papel confirmar.

## Resumo proposto

| | Quantidade |
|---|---:|
| Entregáveis avaliados | 1 — D01 |
| Critérios funcionais percorridos | 5 |
| Critérios não funcionais percorridos | 6 |
| Aceitos | **1**, se confirmado |
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

**Fase derivada**: `sro.accepted_deliverable` — os cinco critérios funcionais e os
sete não funcionais conformes, com evidência.

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

| Composição proposta |
|---|
| **D01** — se confirmado |

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

A revisão passou de **impossível** a **pendente** neste sprint: a equipe `the-band`
recebeu acesso ao repositório, e o pedido de revisão é feito à equipe. Quem revisa é
`Adylla027` ou `EduardoNFraiz`.

**O resíduo do sprint 001 não se recupera**: #89, #90 e #91 foram mergeados sem
aprovação registrada, e não há como pedir revisão de PR mergeado.

## Decisões que aguardam o papel

1. **Confirmar ou alterar a classificação de D01** — proposto: aceito, com as duas
   ressalvas registradas.
2. **Destino de US2 e US3** — proposto: voltam ao product backlog. As alternativas
   são entrar no sprint 003 ou serem descartadas com motivo.
3. **A dívida dos 10 vínculos sem lastro** — hoje fechada por limitação declarada.
   Fechá-la de verdade exige declarar 10 relações em 5 ontologias, e isso é feature
   própria.
