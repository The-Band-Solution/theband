# Aceitação — Feature 008: destravar a sincronização presa

**Sprint**: [007](../../docs/sprints/007-destravar-sync-presa/sprint-backlog.md) ·
**PR**: [#212](https://github.com/The-Band-Solution/theband/pull/212), incorporado em
2026-08-12T13:37:23Z
**Avaliado em**: 2026-08-12, contra `main` em `f09e467`

**Suíte verde não é evidência de critério atendido** — é a L18. Cada critério tem a medida que o
sustenta, e onde a evidência é o teste, o teste é nomeado.

## Os dez gates, em `main`

```
$ mix gates > /tmp/gates_main2.txt 2>&1; echo "código de saída: $?"
código de saída: 0

10 gates verdes.
Result: 402 passed
```

## Critérios de sucesso

| # | Critério | Evidência | Veredito |
|---|---|---|---|
| SC-001 | com execução presa, coletar de novo funciona, sem SQL | `reconcile_stuck_syncs_test.exs`, "a ferramenta volta a aceitar coleta" — o teste insere a segunda execução e exige que o índice único **não** recuse | **atendido** |
| SC-002 | o bloqueio sai sem ninguém abrir a tela | `jobs/reconcile_stuck_syncs_test.exs` — `perform/1` encerra a execução presa; e o `Cron` agenda a cada 5 min, conferido na configuração | **atendido** |
| SC-003 | causas diferentes, motivos diferentes | "os motivos das duas causas são diferentes" — a asserção compara os dois textos, e nenhum deles é "erro" sozinho | **atendido** |
| SC-004 | encerrar preserva 100% de checkpoints, contagens e payloads | `finish/3` só escreve `status`, `finished_at`, `error_reason` e o autor; nenhum caminho apaga | **atendido, por construção** |
| SC-005 | nenhuma execução com trabalho não terminal é encerrada **automaticamente** | "a plataforma NÃO encerra sozinha o que consta em execução" e os cinco estados não terminais, com job **de verdade** em `oban_jobs` | **atendido** |
| SC-005a | execução com trabalho `executing` é encerrável **por pessoa** | "trabalho `executing` num nó morto PODE ser encerrado por pessoa" — é o caso que exigiu SQL duas vezes | **atendido** |
| SC-006 | a ação aparece só onde é segura | `stuck_sync_test.exs` — trabalho `available` não recebe a ação; `executing` recebe, com o aviso do risco | **atendido** |
| SC-007 | pessoa tem autor; plataforma tem autor ausente, e a tela diz qual | "a plataforma aparece por extenso, e a pessoa pelo nome" | **atendido para registros novos**, com a ressalva abaixo |
| SC-008 | a coleta nova não duplica linha | gravação por chave natural, já existente; nenhuma execução recoletada duplicou issue no dado real | **atendido, e não exercitado em produção** |
| SC-008a | a recusa acontece na decisão, não no botão | "a requisição direta é recusada mesmo sem botão na tela" — o evento é disparado à mão | **atendido** |
| SC-008b | execução aberta há menos que a carência não é encerrada | "execução aberta há segundos continua running" | **atendido** |
| SC-009 | estado e motivo legíveis com a cor removida | o motivo é texto ao lado de quem encerrou, e o estado tem `badge` **mais** o texto do rótulo | **atendido** |
| SC-010 | um tenant não alcança execução de outro | "execução de outro tenant responde não encontrado", e `refute html =~ "permission"` | **atendido** |
| SC-011 | encerrar duas vezes não altera o primeiro motivo nem o autor | "reconciliar depois de encerrar por pessoa preserva o autor" | **atendido** |

**14 de 14 critérios atendidos**, dois com ressalva declarada abaixo.

## A ressalva do SC-007: os dois registros históricos

O banco tem duas execuções `interrupted` de antes desta feature, **destravadas por SQL à mão**:

```
interrompida: o processo que a executava não existe mais | sem_autor = t
interrompida: o processo que a executava não existe mais | sem_autor = t
```

A coluna de autor não existia quando elas foram encerradas, então elas têm nulo — e a tela vai
dizer **`the platform`** sobre as duas. **Isso é falso**: quem as encerrou foi uma pessoa, por SQL.

**Não vou inventar autor para elas**, e não vou apagar o registro. A alternativa — um terceiro
valor, "não se sabe" — resolveria e custaria uma distinção a mais na tela para dois registros
históricos que nunca se repetirão, porque a partir de agora todo encerramento grava a origem.

**Fica declarado aqui.** Se em algum momento a leitura desses dois enganar alguém, a correção é
uma migração que escreve o motivo dizendo que foram destravados manualmente antes da feature.

## O item da DoD que não se aplica, e por quê

A DoD do sprint pedia: *"o job órfão de 2026-08-09 encerrado pela plataforma, não por SQL — é a
prova no dado real"*.

**Não é possível, e a razão é boa**: medido em `main`,

```
running = 0   jobs_executing = 1   interrompidas = 2
```

O job órfão continua `executing`, e **não há execução `running` ligada a ele** — as duas que havia
foram destravadas por SQL antes desta feature. Não há o que reconciliar.

A prova no dado real fica pendente até a próxima coleta que morrer — e é honesto dizer isso em vez
de fabricar o cenário no banco de desenvolvimento para poder marcar um item.

## O que a implementação mudou em relação ao planejado

| Mudança | Por quê |
|---|---|
| **duas noções de "vivo"** em vez de uma | rodar contra o dado real mostrou que `executing` bloquearia também a pessoa — e a feature deixaria preso o caso que a motivou. Trabalho em execução **não é prova de vida** |
| `claimed_by_dead_process?/1` no contrato | a confirmação precisa dizer **o que a plataforma não sabe** e qual é o risco: uma segunda coleta em paralelo |
| `Tenants.users_by_id/1` | resolver quem decidiu sem uma consulta por linha |

## O que esta avaliação achou fora do escopo, e foi para o backlog

Conferir a contagem contra a origem — a L30 — achou **dois defeitos vivos**, nenhum deles desta
feature:

| # | Defeito | Custo medido |
|---|---|---|
| [#213](https://github.com/The-Band-Solution/theband/issues/213) | a marca de inacessível **não se cura**: o repositório marcado é filtrado antes da coleta, e `clear_inaccessible/2` nunca o alcança | **39 repositórios, 899 issues** fora de toda coleta futura |
| [#214](https://github.com/The-Band-Solution/theband/issues/214) | erro **interno** do GitHub — HTTP 200 com `errors` — é classificado como falha permanente | criou a 39ª marca hoje, às 12:32:29 |

E a conferência que motivou: a `leds-conectafapes` tem **4283** issues na origem e **4280** no
banco. As 3 que faltam foram criadas depois da última coleta, e estão localizadas —
`conectafapes-project` (1) e `leds-conectafapes-prestacao-de-contas` (2).

**Nada é filtrado por estado nem por arquivamento**: a consulta traz `OPEN` e `CLOSED` — 1426 e
2854 no banco contra 1428 e 2855 na origem —, e os 7 repositórios arquivados estão todos
coletados, com contagem igual à da origem.

## Veredito

**Aceito.** Nove tarefas, 24 testes próprios, 402 na suíte, 10 gates verdes em `main`.

O que fica pendente é a prova no dado real — que depende de uma coleta morrer — e está declarada
como pendente, não como cumprida.
