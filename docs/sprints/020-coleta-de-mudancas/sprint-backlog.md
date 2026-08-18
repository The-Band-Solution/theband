# Sprint 020 — A coleta das mudanças e o rastreio

**Período**: 2026-08-18 a 2026-09-01
**Feature**: [032](../../specs/032-coleta-de-mudancas/spec.md)
**Plano**: [plan.md](../../specs/032-coleta-de-mudancas/plan.md)

## Objetivo do sprint

O rastreio `issue → solicitação → commit → pessoa` deixa de ser modelo e vira dado e
tela: quem pediu a mudança, quem integrou, quem executou cada commit.

## O que veio antes, e destrava este sprint

As relações estavam **declaradas** (PR #427, issue #426) e não havia dado. A ordem foi
essa de propósito: o contrato primeiro, e foi ele que expôs a lacuna das relações antes
de qualquer linha de coleta.

## Lições aplicadas

| Lição | Como está sendo aplicada |
|---|---|
| L25 | identidade do commit por `[tenant, external_id]`; número de PR não identifica entre repositórios |
| L26 | casamento estreito no envelope (`{:ok, %{data: data}}`) — lista vazia com `totalCount > 0` seria erro |
| L29 | falha por repositório vira `unreachable`, sem checkpoint gravado: a próxima coleta tenta de novo |
| L30/L35 | SC-001 conferido contra a API viva, não pela suíte |
| L46 | **e ela reincidiu**: marcar vínculo sumido por `last_observed_at < now` falha quando as duas gravações caem no mesmo segundo. Corrigido para marcar por conjunto observado |
| L47 | a fase lê issues da BASE, não da memória da fase anterior |
| L48 | closing keyword em inglês, **uma por issue** — a segunda ocorrência da lição, agora na sintaxe |

## Tarefas

Ver [tasks.md](../../specs/032-coleta-de-mudancas/tasks.md). Phases 1 a 3 feitas; Phase 4
(lista, busca e linha do tempo) aprovada em proposta e pendente.

## Os critérios, com a evidência

| # | critério | evidência |
|---|---|---|
| SC-001 | coleta termina e bate com a origem | **5.032 solicitações, 16.416 commits distintos, 17.928 autorias, 1.078 vínculos, 66 pessoas** em 1.396s (23min). 3 repositórios inalcançáveis, registrados. |
| SC-002 | rastreio completo na tela | Issue #395 → PR #396 → 9 commits, cada um com dois autores (Paulo + claude). Verificado ao vivo. |
| SC-003 | número fixo de consultas | `commits_of/2` custa 2 com um commit ou com vinte. Tetos atualizados com acréscimo nomeado: issue 40→42, pessoa 19→22. |
| SC-004 | co-autoria não é achatada | 477 commits com mais de um autor na primeira medição; a tela mostra o selo `co-author`, e a pessoa aparece na lista dela mesmo sem ter aberto solicitação. |

## O que a coleta expôs, e virou correção

**509 solicitações truncadas** na primeira passada — PRs com mais de 50 commits. A saída
não foi declarar limitação: a API pagina, então **a limitação era nossa**. Entrou a
consulta `pull_request_commits.graphql`, chamada só para os truncados. Os campos
`commits_total` e `commits_collected` ficam como rede: se a paginação falhar no meio, a
tela diz o que falta em vez de mostrar parcial como total.

## Fora do escopo

Commits fora de solicitação (push direto), revisões de PR, conflitos, `cmpo.artifact_copy`
e o CI (#401) — todos declarados na spec e nos mapeamentos.

## Definition of Done

- [x] quality gates verdes
- [x] base de conhecimento válida
- [x] SC-001 a SC-004 verificados no tenant real
- [ ] issues encerradas
- [ ] `sprint-review.md`
- [ ] `licoes-aprendidas.md` atualizado (L46 reincidiu; a nova ocorrência da L48)
