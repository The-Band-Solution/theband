# Sprint 007 — Review

**Período**: 2026-08-12 a 2026-08-18
**Feature**: [008 — destravar sync presa](../../../specs/008-destravar-sync-presa/spec.md)
**PR**: [#212](https://github.com/The-Band-Solution/theband/pull/212), incorporado em
2026-08-12T13:37:23Z · `main` em `f09e467`

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 9 | 9 |
| Entregáveis aceitos | 9 | **9** |

**10 gates verdes por código de saída**, 402 testes. A avaliação critério por critério está em
[aceitacao.md](../../../specs/008-destravar-sync-presa/aceitacao.md): **14 de 14 SC atendidos**, dois
com ressalva declarada.

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T001 | [#202](https://github.com/The-Band-Solution/theband/issues/202) | `interrupted_by_user_id`, anulável e sem check constraint | sim |
| T002 | [#203](https://github.com/The-Band-Solution/theband/issues/203) | a ligação sync↔trabalho pelos args, com os estados derivados da fila | sim |
| T003 | [#204](https://github.com/The-Band-Solution/theband/issues/204) | `reconcile_stuck_syncs/0`, com carência de 1 minuto | sim |
| T004 | [#205](https://github.com/The-Band-Solution/theband/issues/205) | o motivo por causa, sem inventar falha | sim |
| T005 | [#206](https://github.com/The-Band-Solution/theband/issues/206) | idempotência: age só sobre `running` | sim |
| T006 | [#207](https://github.com/The-Band-Solution/theband/issues/207) | o resultado da criação do trabalho conferido | sim |
| T007 | [#208](https://github.com/The-Band-Solution/theband/issues/208) | o worker periódico, e o teste que impede o `Lifeline` de voltar | sim |
| T008 | [#209](https://github.com/The-Band-Solution/theband/issues/209) | `interrupt_sync/3` com autor, `:job_alive` e `:not_found` | sim |
| T009 | [#210](https://github.com/The-Band-Solution/theband/issues/210) | quem encerrou, por extenso | sim |

## O que não foi feito

| Item | Motivo | Destino |
|---|---|---|
| a prova no dado real — o órfão encerrado pela plataforma | **não há execução `running` ligada ao job órfão**: as duas que havia foram destravadas por SQL antes desta feature. Não há o que reconciliar | pendente até a próxima coleta que morrer |
| iteration própria do sprint no ProjectV2 | configurar iterations recria as existentes — L11 | product backlog, #176 |
| verificação visual da tela em 360 px | o markup é o mesmo do cartão existente, e ninguém **olhou** | conferir antes de fechar o próximo sprint |

## A mudança de desenho durante a execução, e ela é o aprendizado do sprint

O plano tinha **uma** noção de "trabalho vivo". Rodar contra o dado real mostrou que ela estava
errada: o job órfão de 2026-08-09 está `executing`, e `executing` bloquearia tanto o encerramento
automático quanto o humano — **a feature deixaria preso exatamente o caso que a motivou**.

```
não terminal (bloqueia o automático):  suspended scheduled available executing retryable
vai executar (bloqueia a pessoa):      suspended scheduled available           retryable
```

**Trabalho em execução não é prova de vida**: é o registro de que algum processo reivindicou o
trabalho, e a reivindicação sobrevive ao processo. A plataforma não encerra sozinha — se a coleta
estiver rodando, liberar a restrição faria uma segunda começar em paralelo. A pessoa pode, porque
só ela sabe que reiniciou a aplicação.

## Evidências

```
$ mix gates > /tmp/gates_main2.txt 2>&1; echo "código de saída: $?"
código de saída: 0
10 gates verdes.
Result: 402 passed
```

**Dois defeitos conferidos por reprovação**, invertendo o código de propósito:

| defeito introduzido | testes que reprovaram |
|---|---|
| o resultado da criação do trabalho descartado | **3 de 3** no arquivo de `enqueue_failure` |
| `executing` bloqueando a pessoa | os dois casos novos de `executing`, nos dois sentidos |

**Os jobs dos testes vão para a tabela `oban_jobs`**, não para um mock: a decisão consulta a fila, e
um mock testaria o mock.

## Dívida gerada

| Dívida | Por quê |
|---|---|
| dois registros `interrupted` históricos dirão `the platform` | foram destravados por SQL antes de a coluna existir; inventar autor seria pior, e está declarado na aceitação |
| o worker compete por slot na fila `ingestion` | com 5 coletas em andamento a reconciliação espera — atrasa, não impede |
| a prova no dado real é pendente | depende de uma coleta morrer; fabricar o cenário no banco para marcar o item seria declarar sucesso sem evidência |

## O que a conferência contra a origem achou, e não é desta feature

A L30 aplicada à `leds-conectafapes` achou **dois defeitos vivos**:

| # | Defeito | Custo medido |
|---|---|---|
| [#213](https://github.com/The-Band-Solution/theband/issues/213) | a marca de inacessível **não se cura**: o repositório marcado é filtrado antes da coleta, e a função que limparia a marca nunca o alcança | **39 repositórios, 899 issues** fora de toda coleta futura |
| [#214](https://github.com/The-Band-Solution/theband/issues/214) | erro **interno** do GitHub — HTTP 200 com `errors` — classificado como falha permanente | criou a 39ª marca hoje, às 12:32:29 |

E a resposta à pergunta que motivou a conferência: **a coleta não está perdendo issues por
arquivamento nem por estado.** 4283 na origem, 4280 no banco; as 3 que faltam nasceram depois da
última coleta. `OPEN` e `CLOSED` vêm as duas, e os 7 repositórios arquivados estão todos coletados.

## Lições deste sprint

**L34** — a mesma palavra para duas coisas diferentes esconde o caso que a feature existe para
resolver.

**L35** — conferir contra a origem acha defeito **fora** da feature que se está entregando.

Detalhamento em [licoes-aprendidas.md](../licoes-aprendidas.md).
