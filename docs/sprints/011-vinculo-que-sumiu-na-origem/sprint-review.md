# Sprint 011 — Review

**Período**: 2026-08-12 · **Feature**: [012 — o vínculo que sumiu na origem](../../../specs/012-vinculo-que-sumiu-na-origem/spec.md)
**PR**: [#278](https://github.com/The-Band-Solution/theband/pull/278) · **Aceitação**: [aceitacao.md](../../../specs/012-vinculo-que-sumiu-na-origem/aceitacao.md)

Escrita **neste** sprint, e não no seguinte. É a L44 aplicada a ela mesma.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3, uma delas provada só em teste |
| Tarefas | 9 | 8 feitas · 1 pendente de pessoa |
| Requisitos funcionais aceitos | 14 | **14** |
| Critérios de sucesso aceitos | 7 | **3** — quatro pendem do dado real |

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T001 | [#269](https://github.com/The-Band-Solution/theband/issues/269) | `mark_decomposition_links_no_longer_observed/3`, escopada pelo repositório do pai | sim |
| T002 | [#270](https://github.com/The-Band-Solution/theband/issues/270) | teste que fixa a ressurreição e a preservação de `observed_at` | sim |
| T003 | [#271](https://github.com/The-Band-Solution/theband/issues/271) | idempotência, e a marca antiga que não se reescreve | sim |
| T004 | [#272](https://github.com/The-Band-Solution/theband/issues/272) | a fronteira do tenant, aserida pelo vínculo do vizinho | sim |
| T005 | [#273](https://github.com/The-Band-Solution/theband/issues/273) | a chamada no ramo de sucesso, depois de `vincular/2` e antes de `promover/2` | sim |
| T006 | [#274](https://github.com/The-Band-Solution/theband/issues/274) | cinco casos de "não aconteceu nada", incluindo `refused_links` | sim |
| T007 | [#275](https://github.com/The-Band-Solution/theband/issues/275) | log que nomeia repositório e número, e cala quando é zero | sim |
| T008 | [#276](https://github.com/The-Band-Solution/theband/issues/276) | tela recebendo o dado **pela coleta**, não por escrita direta | sim |

## O que não foi feito

| Tarefa | Issue | Motivo | Destino |
|---|---|---|---|
| T009 | [#277](https://github.com/The-Band-Solution/theband/issues/277) | exige a **chave mestra** e a origem respondendo, e olho humano na tela de `eo_lib` | pessoa mantenedora; segue aberta |

**T009 é a única, e não é atraso**: ela nunca foi executável por mim. Está declarada como
pendente desde o backlog, e continua declarada — nunca contada como cumprida.

## Evidências

```
mix gates → 10 gates verdes, código de saída 0
18 testes novos em três arquivos:
  test/the_band/work_items/decomposition_absence_test.exs        6 casos
  test/the_band/ingestion/decomposition_absence_test.exs        10 casos
  test/the_band_web/live/decomposition_absence_screen_test.exs   2 casos
```

Medida que originou a feature, conferida no banco antes de existir código:

```
1666 vínculos · 0 marcados · 52 que a última coleta não reviu
eo_lib 29 · theband 15 · ResearchDomain 8
nos 52, pai e filha vigentes: 0 e 0
```

## Dívida gerada

| Dívida | Por quê foi aceita |
|---|---|
| **quarta** função de marcação de ausência, sem abstração comum | os cortes não são iguais: issue corta por data, designado e rótulo cortam por lista. Generalizar juntaria coisas diferentes |
| o total de vínculos marcados por execução só existe no log | a pergunta "o que esta coleta deixou de ver" ainda não foi feita por ninguém; inventar o campo agora é padrão sem problema |
| este PR está **empilhado** sobre o #264 | a alternativa era esperar a revisão de um PR que já está pronto há um dia |

## O que a análise e o plano acharam antes do código

**Seis achados, e nenhum veio de rodar teste** — todos de medir o banco ou ler o código:

| Fase | Achado |
|---|---|
| plano | FR-002 pedia gravar o `started_at` na marca, contra a convenção das três irmãs |
| plano | FR-013 pedia número novo na tela de sincronizações — o caso concreto do princípio X |
| análise | 12 dos 52 vínculos sustentam violações da `sro.rule07`: o painel cai de 293 para 281 |
| análise | a ordem contra `promover/2` virou carga: `classification/2` conta só vigentes |
| análise | FR-014 estava sem tarefa, e era testável |
| análise | T008 estava **bloqueada**, não pendente |

**Sétima feature seguida** em que a fase de análise acha defeito de desenho.

## Lições deste sprint

Três, e as três nasceram de erro cometido dentro do sprint — não de teoria.

- **L45** — sprint novo tirado da `main` não enxerga o fecho do anterior enquanto o PR está aberto;
- **L46** — teste com corte temporal e dado montado no mesmo instante passa ou falha por sorte;
- **L47** — vínculo entre repositórios só existe a partir da **segunda** coleta.

Detalhadas em [licoes-aprendidas.md](../licoes-aprendidas.md).

---

## Depois do merge

Os PRs [#264](https://github.com/The-Band-Solution/theband/pull/264) e
[#278](https://github.com/The-Band-Solution/theband/pull/278) foram aprovados e incorporados na
ordem certa. `main` em `8677752`, **10 gates verdes por código de saída**, branches apagadas.

**E o merge deixou uma coisa por fazer, que ninguém teria notado:** a **#263** continuou aberta. O
corpo do PR dizia *"Fecha #263"*, e o GitHub só reconhece a palavra em inglês — a menção cruzada
aparece igual nos dois casos, e a issue fica aberta parecendo trabalho não feito. Fechada à mão,
com a evidência, e virou a **L48**.

**Uma quarta lição do sprint**, e da mesma família das outras três: nenhum erro, e o resultado
errado.

## O que continua pendente

| # | O que | Por quê |
|---|---|---|
| [#277](https://github.com/The-Band-Solution/theband/issues/277) | a conferência no dado real | exige a chave mestra e a origem respondendo |
| [#265](https://github.com/The-Band-Solution/theband/issues/265) | o épico | fica aberto enquanto a #277 estiver — épico com verificação pendente não está pronto |

Quatro dos sete critérios de sucesso seguem **declarados como pendentes**. O código está na `main`;
o efeito dele no dado, não foi observado.

### A reincidência, achada pela pessoa mantenedora

A pergunta foi *"olhe a lista de issues, por que estão abertas ainda?"*, e a lista respondeu: a
**#246** — o pedido que originou a feature 011 — estava aberta desde o merge do PR #264, pelo mesmo
motivo da #263. **Dois PRs, o mesmo mecanismo.**

Fechada com a evidência. E a conferência que a achou virou parte da L48: **a lista de issues abertas
é a conferência**, e ela vale ao fechar o sprint — não só a issue que se lembra de olhar.
