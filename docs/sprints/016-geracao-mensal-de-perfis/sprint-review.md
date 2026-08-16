# Sprint 016 — Review

**Período**: 2026-08-16 · **Feature**: [027](../../specs/027-geracao-mensal-de-perfis/spec.md)
**PR**: [#360](https://github.com/The-Band-Solution/theband/pull/360)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| Issues do sprint | 23 | **23** |
| Issues da feature | 28 | 23 — cinco declaradas fora ao abrir o sprint |
| Quality gates | 13 | **13**, código de saída 0 |
| Testes | — | 917, **34 novos** |

## O que foi feito

| Tarefa | Entregável | Aceito |
|---|---|---|
| T003 | fila `:perfis` própria, separada da coleta | sim |
| T004, T005 | `profile_thresholds.yaml` com N e M; validação **recusa** limiar ausente | sim |
| T006 a T009 | três migrações e três schemas — eventos, rodadas, entradas | sim |
| T010 | limiares lidos da base, sem padrão embutido no código | sim |
| T011 | quem entra na rodada, e os três motivos separados de quem não entra | sim |
| T012 | ligar e desligar com **autor**, derivado de evento e não de coluna | sim |
| T013, T015 | rodada aberta, registrada e encerrada, sequencial com checkpoint em tabela | sim |
| T014, T014a | a geração devolve o consumo; o material continua sendo o histórico inteiro | sim |
| T016, T016a | credencial recusada encerra a rodada; quem falhou volta na seguinte pelo critério normal | sim |
| T017, T017a | cron mensal, uma rodada por organização; subir a versão **não gera nada** | sim |
| T018 a T021 | tela `/profiles`, os nove números por agregação, ligar dispara, rodada a mão, isolamento entre organizações | sim |

## O que não foi feito

Cinco issues, declaradas fora **ao abrir** o sprint e não ao fechá-lo.

| Tarefa | Issue | Motivo | Destino |
|---|---|---|---|
| T022 | [#354](https://github.com/The-Band-Solution/theband/issues/354) | US3, P2 — o valor aparece quando alguém quiser ajustar o limiar | product backlog |
| T023 | [#355](https://github.com/The-Band-Solution/theband/issues/355) | polimento | product backlog |
| T024 | [#356](https://github.com/The-Band-Solution/theband/issues/356) | exige chave real e de 15 a 35 minutos de rodada contra o provedor | **pessoa mantenedora** |
| T025 | [#357](https://github.com/The-Band-Solution/theband/issues/357) | roda ao fechar — **feito**, 13 verdes | fechada com o sprint |
| T026 | [#358](https://github.com/The-Band-Solution/theband/issues/358) | percorrer o quickstart a mão, com a aplicação no ar | **pessoa mantenedora** |

## Evidências

```
mix gates → 13 gates verdes, código de saída 0, sem pipe
917 testes, 34 novos
knowledge.validate → base válida, 100 artefatos
```

## Definition of Done — item a item

| Item | Estado |
|---|---|
| as 23 issues fechadas, ou repriorizadas com justificativa escrita | **fecham no merge** do #360, pelo `Fecha #331…#353` |
| `mix gates` com código de saída 0, nunca com `\| tail` | **cumprido** — e ver a lição abaixo, porque a primeira execução desta sessão violou isto |
| `mix knowledge.validate` passando com a regra `regeneration` nova | cumprido |
| PR aberto com revisor pedido à equipe `the-band`, e o pedido **conferido** | cumprido — `reviewRequests` devolve a equipe, não lista vazia |
| `sprint-review.md` escrito, separando entregue de não entregue | este documento |
| `licoes-aprendidas.md` atualizado | cumprido — L60 |
| a lacuna da revisão independente **declarada**, se persistir | **persiste, e está declarada abaixo** |

## A lacuna da revisão independente — declarada, não cumprida

O pedido de revisão foi feito à equipe `the-band` e **conferido** com
`gh pr view 360 --json reviewRequests`, que devolveu a equipe e não lista vazia. Isso prova
que o pedido chegou; **não** prova que a revisão aconteceu.

No momento de escrever este documento, `pulls/360/reviews` está vazio. O #330 foi
incorporado sem revisão independente, e este sprint fecha com o mesmo risco em aberto — a
diferença é que agora o pedido existe e está registrado.

**Não marcar como cumprido é o ponto.** O princípio VII pede revisão por outro agente ou
pessoa; pedido enviado é condição necessária e não suficiente.

## Dívida gerada

| Dívida | Onde está |
|---|---|
| **N e M entram sem medição** | a `FR-021` exige medir o custo real antes de os limiares valerem. Os valores estão no YAML como **iniciais**, e o `SC-002` diz que mudam junto com a recontagem. A T024 ([#356](https://github.com/The-Band-Solution/theband/issues/356)) é o que fecha isso, e depende de chave real |
| **o quickstart não foi percorrido a mão** | [#358](https://github.com/The-Band-Solution/theband/issues/358). A suíte verde não substitui: a lição do projeto é que três defeitos da rodada anterior só apareceram com a aplicação no ar |
| **catorze `form-control` mortos** | `roles_live` e `source_live` seguem com a classe que o daisyUI 5 removeu. Corrigidos só os dois de `/ai`, no `5c96a41`, e a razão está no commit |

## Lições deste sprint

Registradas em [licoes-aprendidas.md](../licoes-aprendidas.md) — **L60**, a reincidência do
pipe no `mix gates`.
