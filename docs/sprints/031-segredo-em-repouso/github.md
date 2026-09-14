# Sprint 031 — o que foi materializado no GitHub

**Executado em**: 2026-09-13, ao escrever o backlog — as issues existiam desde o #889 com
labels e **sem tipo, sem hierarquia, fora do projeto**. Script e log ficaram fora do
repositório; o que está aqui foi **lido de volta** da API depois de gravar, não copiado do
que o script disse que fez.

| passo | issues | resultado |
|---|---|---|
| tipo `Task` (`updateIssueIssueType`) | #866–#884 (19) | **19 gravados**, lidos de volta como `type=Task` |
| tipo nas US e no épico | #885–#888 | **não gravado, de propósito** — `User Story` e `Epic` não existem na organização (só `Task`, `Bug`, `Feature`); tipar como `Feature` faria a regra de roteamento classificar errado. Decisão do sprint 029, mantida |
| sub-issue tarefa → US (`addSubIssue`) | T002–T005 → #885 · T006–T008 → #887 · T009–T014 → #886 | **13 ligadas** |
| sub-issue US → épico | #885, #886, #887 → #888 | **3 ligadas** |
| item no projeto [The Band](https://github.com/orgs/The-Band-Solution/projects/2) | as 23 | **23 acrescentadas** |
| `Iteration` | as 23 | *Sprint 025 — Contas e o elo do GitHub* (2026-09-12 a 2026-09-19) |
| `Status` | as 23 | **Ready** — selecionadas para o sprint, nenhuma começada |

## O que ficou de fora, e por quê

- **T001, T015, T016, T017, T018, T019 sem pai.** O `tasks.md` não as prende a user story:
  T001 é fundação; T015–T016 são o que fica escrito; T017–T019 atendem FR-016 a FR-019, que o
  #889 acrescentou à spec **sem user story própria**. Ligá-las ao épico contaria tarefa como
  composição — errado pela regra de roteamento. Ficam soltas, e a lacuna é da spec;
- **`Priority`, `Size`, `Estimate`** não preenchidos — desconhecidos, não zero. `Priority` das
  US vem da spec (P1, P2, P3) e pode ser gravada quando o papel confirmar o backlog;
- **a numeração da iteration** (*Sprint 025*) está atrás da destas pastas (031). É o campo que
  existe; corrigir a numeração do projeto é trabalho próprio, com snapshot antes (L11).

## Leitura de volta (amostra)

```
#866  type=Task  parent=∅    status=Ready  iter=Sprint 025
#870  type=Task  parent=885  status=Ready  iter=Sprint 025
#885  type=∅     parent=888  status=Ready  iter=Sprint 025
#888  type=∅     parent=∅    status=Ready  iter=Sprint 025
```
