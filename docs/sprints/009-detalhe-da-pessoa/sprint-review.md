# Sprint 009 — Review

**Período**: 2026-08-12 · **Feature**: [010 — detalhe da pessoa](../../specs/010-detalhe-da-pessoa/spec.md)
**Escrita em**: 2026-08-12, **depois** de o sprint 010 abrir — e isso é o primeiro achado desta review

## Por que esta review chegou atrasada

O sprint 009 foi entregue e mergeado — PR [#247](https://github.com/The-Band-Solution/theband/pull/247),
as treze issues fechadas — **sem review, sem aceitação e sem lições**. A ausência só apareceu quando o
sprint 010 citou as lições **L38** e **L39** como restrição: elas tinham sido rascunhadas no commit da
feature e **nunca consolidadas** no registro acumulado.

**Citar uma lição que não existe é pior que não citá-la**: o documento passa a parecer completo.
Registrado como **L44**.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 9 | 9 |
| Entregáveis aceitos | 9 | 9 |

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T001 | [#237](https://github.com/The-Band-Solution/theband/issues/237) | `EO.list_person_teams/2` — uma consulta, com organização e promoção | sim |
| T002 | [#238](https://github.com/The-Band-Solution/theband/issues/238) | `EO.count_roles/1` | sim |
| T003 | [#239](https://github.com/The-Band-Solution/theband/issues/239) | `count_assigned_to/2` e `count_authored_by/2`, **separadas** | sim |
| T004 | [#240](https://github.com/The-Band-Solution/theband/issues/240) | `assigned_to:` e `authored_by:` em `escopo/2` — dois nomes, nunca `person_id` | sim |
| T005 | [#241](https://github.com/The-Band-Solution/theband/issues/241) | `repositories_of_person/2` | sim |
| T006 | [#242](https://github.com/The-Band-Solution/theband/issues/242) | `/people/:id`, com as três seções | sim |
| T007 | [#243](https://github.com/The-Band-Solution/theband/issues/243) | o nome virou link em `/people` | sim |
| T008 | [#244](https://github.com/The-Band-Solution/theband/issues/244) | a explicação da não promoção, vinda do **dado** | sim |
| T009 | [#245](https://github.com/The-Band-Solution/theband/issues/245) | designação e autoria mostradas sem somar | sim |

**As treze issues do sprint estão fechadas** — épico, três user stories e nove tarefas.

## O que não foi feito

| Item | Motivo | Destino |
|---|---|---|
| a página olhada em **360 px** | precisa de navegador e olho humano | pessoa mantenedora |
| a página de `vinicius-je` **no dado real** — 350 e 609, nunca 959 | a plataforma sobe com a chave mestra | pessoa mantenedora |
| **a review e as lições** | não foram escritas ao fechar | **feito agora**, com atraso |

## Evidências

```
mix gates → 10 gates verdes, 460 testes (na entrega)
PR #247 mergeado em main — 13 arquivos, 1 443 linhas
```

Números medidos no dado real em 2026-08-12: **75 pessoas, 12 equipes, 88 evidências de vínculo, zero
vínculos materializados, zero papéis**, 4 232 designações e 4 241 autorias.

## Os três defeitos que os testes acharam durante a implementação

| # | O que era | Como apareceu |
|---|---|---|
| 1 | um `join` em `escopo/2` **deslocou os bindings** de `list_issues/2` | `field derived_concept in select does not exist in schema IssueAssignee` — corrigido com subconsulta |
| 2 | `sum/1` devolve `Decimal`, e o teste esperava inteiro | `left: Decimal.new("1")` — corrigido com `type(..., :integer)` |
| 3 | `@por_pagina` no template é **assign**, não atributo de módulo | `KeyError` no render — corrigido com assign explícito |

## Dívida gerada

| Dívida | O que é |
|---|---|
| o componente `origem/1` tem **dois** usos, não três | está no limiar do critério do projeto, e foi declarado no plano em vez de escondido |
| `TeamsLive.Show` continua em português | a migração para inglês passou por ela sem tocá-la |
| as **88 evidências** não viram vínculo | depende de papel existir — #99 e #100 |

## Lições deste sprint

Consolidadas agora em [licoes-aprendidas.md](../licoes-aprendidas.md) como **L38**, **L39** e **L44**.

1. **O custo de uma tela se mede pela diferença e pela constância**, nunca pelo total: o teste
   esperava 8 numa página que faz 24, porque 16 são framework e autenticação. → **L38**
2. **Um `join` acrescentado num escopo compartilhado desloca os bindings de quem compõe sobre ele.**
   → **L39**
3. **Sprint que fecha sem review deixa a lição rascunhada e não registrada** — e a próxima feature a
   cita como se existisse. → **L44**
