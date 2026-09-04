# Sprint 013 — Review

**Período**: 2026-08-13 · **Features**: [014](../../../specs/014-clicar-leva-a-pagina/spec.md) e [015](../../../specs/015-quem-escreveu-a-issue-tambem-e-observado/spec.md)
**PRs**: [#286](https://github.com/The-Band-Solution/theband/pull/286) e [#287](https://github.com/The-Band-Solution/theband/pull/287)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| Features | 2 | 2 |
| Tarefas | 12 | **11** — a 12ª precisa da chave mestra |
| Requisitos funcionais aceitos | 23 | **23** |
| Critérios de sucesso aceitos | 14 | **9** — cinco pendem de coleta |

## O que foi feito

| Tarefa | Entregável | Aceito |
|---|---|---|
| 014-T001 a T005 | ligação condicional no detalhe da issue e da equipe; 7 testes | sim |
| 015-T001 | consulta alargada, com `__typename` e `id` | sim |
| 015-T002 | pessoa nascendo da coleta, com o contexto fiado entre repositórios | sim |
| 015-T003 | bot recusado, por `Mapper.account_type/1` chamado | sim |
| 015-T004 | idempotência, com `collected_at` preservado | sim |
| 015-T005 | evidência de equipe intacta — trabalhar não é pertencer | sim |
| 015-T006 | `worked at` na página da pessoa, com a evidência e sem a palavra membro | sim |

## O que não foi feito

| Tarefa | Motivo | Destino |
|---|---|---|
| 015-T007 | exige coleta com a origem respondendo, e a chave mestra | pessoa mantenedora |

## Evidências

```
mix gates → 10 gates verdes, código de saída 0
542 testes, 17 novos
39 → 38 consultas no detalhe da issue (a ligação não custa consulta)
```

## O que a análise achou antes do código

| Achado | Consequência se passasse |
|---|---|
| `ctx.pessoas` montado uma vez | vínculo em alguns repositórios e não em outros, na mesma execução, **sem erro** |
| `gravar_issue` lê o mapa na mesma passada | `author_person_id` nulo com a pessoa existindo |
| `replace_assignees` usa o mesmo mapa | o defeito atingiria designado, e a spec só falava de autor |

## O erro de processo deste sprint, e ele é meu

**Empurrei as duas features na mesma branch**, e o PR #284 nasceu com os dois diffs — contra o
`AGENTS.md` §17 e contra o que o **meu próprio backlog** dizia na segunda seção: *"dois PRs, um
sprint"*.

Corrigido sem reescrever histórico: duas branches novas a partir da `main`, por cherry-pick, e o #284
fechado explicando. Nada se perdeu.

**Por que aconteceu**: a 015 começou como continuação da conversa da 014 — a decisão de criar as
pessoas saiu de medir a 014 —, e a continuidade da conversa virou continuidade da branch.

## Dívida gerada

| Dívida | Por quê |
|---|---|
| as issues antigas só ganham autor na **próxima** coleta | o payload guardado não tem o `id`; reprocessar não inventa o que não foi pedido |
| `worked at` mostra a organização, não o papel | papel organizacional é #99/#100, e o GitHub não fornece |

## Lições deste sprint

- **L52** — continuidade de conversa não é continuidade de branch;
- **L53** — o teto de um teste de custo vem da medida dos dois lados, nunca de escolha.
