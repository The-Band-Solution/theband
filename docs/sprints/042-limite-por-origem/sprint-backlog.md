# Sprint 042 — o limite de tentativas por origem nas duas entradas

**Período**: a partir de 2026-10-05, na iteration corrente do GitHub (Sprint 035, `ee36a246`)
**Feature**: [077](../../../specs/077-limite-por-origem/spec.md) · **Plano**: [plan.md](../../../specs/077-limite-por-origem/plan.md) · **Tarefas**: [tasks.md](../../../specs/077-limite-por-origem/tasks.md) · **Segurança**: [seguranca.md](../../../specs/077-limite-por-origem/seguranca.md)
**Épico**: [#1393](https://github.com/The-Band-Solution/theband/issues/1393)

**Número**: 042. O maior em `docs/sprints/` era 041; conferido em 2026-10-05 com
`git log --all -- 'docs/sprints/042*'` vazio.

## Objetivo do sprint

Corrigir o defeito de segurança #1229 e entregar o mecanismo da #1106 (070/T043): quem tenta
adivinhar credenciais de uma mesma origem recebe a mesma recusa de sempre a partir da décima
primeira falha, nas cinco portas que verificam segredo sem sessão. Em produção, até a medição
#1063, o limite **observa** e não recusa (decisão 2 da 070; `seguranca.md`, L1).

## Escopo

**Pedido pela pessoa mantenedora em 2026-10-05**: as duas issues, #1229 e #1106, ponta a ponta até o
PR, sem merge. Por §14.0, defeito de segurança conhecido vem antes de feature nova na mesma
superfície. Entram T002–T011; T001 (#1063) e T012 são 👤 e ficam abertas.

| US | issue | prioridade | tarefas |
|---|---|---|---|
| US1 — a entrada das contas | [#1394](https://github.com/The-Band-Solution/theband/issues/1394) | P1 | T002 #1397, T003 #1398, T006 #1401, T007 #1402, T008 #1403 |
| US2 — as quatro portas do operador | [#1395](https://github.com/The-Band-Solution/theband/issues/1395) | P1 | T009 #1404 |
| US3 — o estado da origem | [#1396](https://github.com/The-Band-Solution/theband/issues/1396) | P1 | T004 #1399, T005 #1400, T010 #1405, T011 #1406, T012 👤 #1407 |
| — | [#1063](https://github.com/The-Band-Solution/theband/issues/1063) | — | T001 👤, a medição (070/T004) |

## Lições aplicadas

- **L109** — tarefa fechada "sem código" com o critério intacto: a #1229 e a #1106 **não** fecham
  com este PR, porque em produção o limite só observa até a T012.
- **L101** — issue fechada na integração afirma sobre a produção: pelo mesmo motivo, o PR fecha
  só as tarefas de código, e cada uma diz que o efeito em produção espera a #1063.
- **L102** — `git add -A` em árvore compartilhada: commits por caminho, e `git status` antes do PR.
- **L106** — a verificação que ninguém leu: `GATES_EXIT` lido do log, e não do fim do comando.

## Fora do sprint

- [#1409](https://github.com/The-Band-Solution/theband/issues/1409) — a troca de senha sem espera
  (L14), aberta por este sprint.
