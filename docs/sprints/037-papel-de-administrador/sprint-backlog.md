# Sprint 037 — a marca de administrador

**Período**: 2026-10-03 a 2026-10-09, na iteration Sprint 035 do GitHub (`ee36a246`)
**Feature**: [072](../../../specs/072-papel-de-administrador/spec.md) · **Plano**: [plan.md](../../../specs/072-papel-de-administrador/plan.md)
**Issue de origem**: [#568](https://github.com/The-Band-Solution/theband/issues/568), a lacuna nomeada pela aceitação do sprint 023

## Objetivo do sprint

A organização passa a poder ter mais de um administrador, e nunca nenhum. Quem perde a marca deixa
de administrar na próxima ação.

## Lições aplicadas

| lição | como está sendo aplicada |
|---|---|
| L50 — o teste que compara precisa provar que mediu | a corrida de SC-001 afirma que os dez atos rodaram; a captura do `FOR UPDATE` afirma que mediu |
| L90 — contar só o vencedor da corrida não prova o perdedor | a corrida afirma o vencedor **e** a recusa de cada perdedor, pelo motivo |
| L108 — feature sem sprint backlog | este documento existe antes do código, e as US só fecham com aceitação |
| a tela exatamente a aprovada | o protótipo foi aprovado em 2026-10-03, e o T012 confere item a item |

## User stories

| # | user story | issue | Priority |
|---|---|---|---|
| US1 | Promover uma conta a administrador | [#1165](https://github.com/The-Band-Solution/theband/issues/1165) | P1 |
| US2 | Rebaixar um administrador, nunca o último | [#1166](https://github.com/The-Band-Solution/theband/issues/1166) | P1 |
| US3 | Os controles na tela de contas | [#1167](https://github.com/The-Band-Solution/theband/issues/1167) | P2 |

## Tarefas

| # | tarefa | atende | tipo | issue | estado |
|---|---|---|---|---|---|
| T001 | Restringir o papel a dois valores | — | Task | [#1168](https://github.com/The-Band-Solution/theband/issues/1168) | a fazer |
| T002 | Registrar as mudanças de papel no banco | — | Task | [#1169](https://github.com/The-Band-Solution/theband/issues/1169) | a fazer |
| T003 | O banco recusa papel sem episódio | — | Task | [#1170](https://github.com/The-Band-Solution/theband/issues/1170) | a fazer |
| T004 | O guarda único do papel | — | Task | [#1171](https://github.com/The-Band-Solution/theband/issues/1171) | a fazer |
| T005 | As frases do papel na base | — | Task | [#1172](https://github.com/The-Band-Solution/theband/issues/1172) | a fazer |
| T006 | Promover e rebaixar numa transação | US1 | Task | [#1173](https://github.com/The-Band-Solution/theband/issues/1173) | a fazer |
| T007 | A desativação pelo mesmo guarda | US2 | Task | [#1174](https://github.com/The-Band-Solution/theband/issues/1174) | a fazer |
| T008 | Os atos de administração conferem o ator relido | US2 | Task | [#1175](https://github.com/The-Band-Solution/theband/issues/1175) | a fazer |
| T009 | A tela aberta do rebaixado cai | US2 | Task | [#1176](https://github.com/The-Band-Solution/theband/issues/1176) | a fazer |
| T010 | Ler o registro das mudanças | US3 | Task | [#1177](https://github.com/The-Band-Solution/theband/issues/1177) | a fazer |
| T011 | A tela de contas do protótipo aprovado | US3 | Task | [#1178](https://github.com/The-Band-Solution/theband/issues/1178) | a fazer |
| T012 | Conferir a tela contra o protótipo | US3 | Task | [#1179](https://github.com/The-Band-Solution/theband/issues/1179) | a fazer |
| T013 | Escrever a nota de riscos e abrir o PR | — | Task | [#1180](https://github.com/The-Band-Solution/theband/issues/1180) | a fazer |

## Riscos

- **A FR-002a muda o comportamento de dez atos que já existem.** Cada um ganha teste com o ator que
  perdeu a marca.
- **Os triggers podem ser desligados pelo dono das tabelas**, até a 071 (#1131) entrar em vigor.
