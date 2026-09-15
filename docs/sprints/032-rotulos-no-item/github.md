# Sprint 032 — o que foi materializado no GitHub

**Executado em**: 2026-09-13, **depois** do sprint — as 17 issues existiam desde a manhã com
labels (`task`, `us`) e **sem tipo, sem hierarquia, fora do projeto**. O que está aqui foi
**lido de volta** da API depois de gravar.

| passo | issues | resultado |
|---|---|---|
| tipo `Task` | #890–#903 (14) | **14 gravados**, lidos de volta como `type=Task` |
| tipo nas US | #904–#906 | **não gravado, de propósito** — `User Story` não existe na organização (decisão do sprint 029) |
| épico | — | **não há épico** para a 065 |
| sub-issue tarefa → US | T001, T002, T003, T005, T006, T007 → #904 · T004, T008 → #906 · T011, T012 → #905 | **10 ligadas** |
| item no projeto [The Band](https://github.com/orgs/The-Band-Solution/projects/2) | as 17 | **17 acrescentadas** |
| `Iteration` | as 17 | *Sprint 025 — Contas e o elo do GitHub* (2026-09-12 a 2026-09-19) |
| `Status` — tarefas | #890–#903 | **Done** — fechadas em 2026-09-13 |
| `Status` — user stories | #904–#906 | **In review** — veredito proposto pelo papel, confirmação pendente |

## O que ficou de fora, e por quê

- **T009, T010, T013, T014 sem pai** — o `tasks.md` não as prende a user story (T009/T010
  atendem FR-016/FR-017, que não têm US; T013 e T014 são conferência). A lacuna é da spec;
- **T008 tinha dois candidatos a pai** — o corpo da #904 a lista, e o da #906 também. Uma
  issue tem um pai só: ficou na **US3**, porque a T008 é a FR-009 (*recusar interpretar o
  conteúdo do rótulo*), que é a regra da US3;
- **`Estimate`** não preenchida; **`Priority`** das US vem da spec (US1 P1, US3 P1, US2 P2) e
  pode ser gravada na confirmação;
- **o `Status` das tarefas como `Done`** afirma que a tarefa foi executada — não que o
  entregável foi aceito. T005, T007, T011 e T012 estão `Done` e são
  `non_successfully_performed`; a fase mora na aceitação, não no board.

## Leitura de volta (amostra)

```
#890  type=Task  parent=904  status=Done       iter=Sprint 025
#897  type=Task  parent=906  status=Done       iter=Sprint 025
#904  type=∅     parent=∅    status=In review  iter=Sprint 025
#906  type=∅     parent=∅    status=In review  iter=Sprint 025
```
