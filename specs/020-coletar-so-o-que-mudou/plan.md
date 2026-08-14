# Implementation Plan: coletar só o que mudou

**Branch**: `040-plano-coletar-so-o-que-mudou` · **Data**: 2026-08-14
**Spec**: [spec.md](./spec.md) · **Pesquisa**: [research.md](./research.md)

## Summary

A coleta baixa tudo toda vez: **4295 issues para 34 alteradas**, e **121 repositórios para 15 com
atividade**. A feature corta nos dois níveis, e antes disso conserta a contagem que hoje descarta
a informação de o que mudou no instante em que a tem.

A pesquisa mudou o desenho num ponto que a spec não previa: a marca de vínculo ausente é escopada
por **repositório**, e numa coleta incremental ela marcaria os 4261 pais que não foram relidos.
O conserto é escopá-la ao conjunto efetivamente percorrido.

## Technical Context

**Linguagem**: Elixir 1.20 · OTP 27
**Dependências principais**: Oban (fila), Req (HTTP), Ecto/Postgrex
**Armazenamento**: PostgreSQL 16
**Testes**: ExUnit, com a borda HTTP do GitHub simulada por Mox — nenhum módulo de domínio é mockado
**Plataforma**: monólito modular multitenant, Phoenix LiveView
**Escala hoje**: 3 organizações · 160 repositórios · 5031 issues · 1727 vínculos

**Meta de desempenho**: uma segunda coleta sem atividade na origem termina em menos de **um
décimo** do tempo da primeira — hoje 6min 01s para as três organizações.

**Restrições**:
- a marca de ausência das features 009 e 012 **não pode** perder exatidão;
- o reprocessamento, que trabalha sobre payload preservado, não muda de comportamento;
- a coleta completa continua disponível sob demanda.

**NEEDS CLARIFICATION — resolvido antes de escrever código, não antes de planejar**: as três
verificações contra a API real listadas no [research.md](./research.md#o-que-fica-pendente-de-medida).

## Constitution Check

| Princípio | Como esta feature se comporta |
|---|---|
| **I — domínio pelas ontologias** | nada muda no modelo semântico: muda o que é **pedido** à origem |
| **II — fonte externa não é domínio** | o filtro por data vive no conector, e `WorkItems` não sabe que existe |
| **III — proveniência e idempotência** *(não negociável)* | `collected_at` e `last_observed_at` continuam gravados por item; coletar duas vezes continua produzindo o mesmo estado |
| **IV — semântica em YAML versionado** | não tocada |
| **V — monólito modular** | a mudança fica em `Ingestion` e no conector; nenhuma fronteira nova |
| **VI — Spec Kit antes do código** | spec, pesquisa e plano antes da primeira linha; e a pesquisa já mudou o desenho |
| **VII — gates e revisão** | treze gates, e o teste de custo mede os dois lados — L53 |
| **VIII — desenho que o problema justifica** | ver a tabela abaixo |
| **IX — ontologias modulares** | não tocada |
| **X — responsabilidade única** | `Ingestion.tally/2` continua sendo quem conta; nenhuma tela nova |

### Princípio VIII — as três perguntas, por decisão introduzida

| Decisão | Qual problema concreto? | Existe agora? | O que fica pior? |
|---|---|---|---|
| **`syncs.mode`** — completa ou incremental | a tela precisa dizer qual foi, e a completa periódica precisa saber quando foi a última | **sim** — sem isso a rede de segurança da FR-012 não tem em que se apoiar | uma coluna a mais, e um estado a mais para quem lê a tabela considerar |
| **escopar a marca por lista de pais** | a marca por repositório marcaria 4261 vínculos falsos | **sim**, e é a razão da FR-012 | a assinatura fica mais longa, e quem chama passa a carregar a lista |
| **`tally` com o resultado real** | `records_created` e `records_updated` zerados em 38 execuções | **sim**, medido | nada: o upsert já devolve o resultado, e ele é descartado na linha seguinte |
| **filtro `since` no conector** | 4295 baixadas para 34 alteradas | **sim**, medido | a consulta ganha um parâmetro, e a janela precisa de sobreposição declarada |

**Nenhum padrão novo.** Não entra behaviour, não entra camada, não entra indireção. O que entra é
um parâmetro de consulta, uma coluna de estado e uma assinatura mais honesta.

**Nenhuma alternativa foi introduzida "para o futuro".** Webhooks estão fora do escopo da spec, e
não há gancho preparatório para eles neste plano — seria generalidade especulativa.

### O antipadrão que este plano tem de evitar

**Acoplamento temporal.** Gravar `issues_collected_at` antes de o repositório ter sido percorrido
por inteiro faria a próxima coleta pulá-lo, e o pulo seria permanente — uma coleta interrompida
no meio deixaria o repositório congelado para sempre.

A FR-010 é isso virando requisito: **a marca de revisão é gravada depois do trabalho que ela
descreve**, nunca antes. É a mesma regra do checkpoint, e a mesma que a `tally` de repositório
inacessível já segue.

## Fases

### Fase 0 — verificar a origem *(bloqueia tudo)*

As três perguntas do [research.md](./research.md#o-que-fica-pendente-de-medida), respondidas
contra a API real com a chave mestra. **Uma consulta cada.** Nenhuma linha de coleta incremental
antes disto: construir sobre suposição de API é a L23 — verificação que não aconteceu lida como
verificação que passou.

### Fase 1 — a contagem dizer a verdade *(história 1, P1)*

`github_work_items.ex:121` e `:408` passam o resultado real do upsert a `Ingestion.tally/2`, em
vez de `:unchanged` fixo. A tela já exibe os três números.

**É o que torna as fases seguintes verificáveis.** Sem ela, "baixou 5%" e "perdeu 95%" produzem a
mesma tela.

### Fase 2 — escopar a marca *(pré-requisito da 3, e conserto por si)*

`mark_decomposition_links_no_longer_observed/3` passa a receber os identificadores dos pais
percorridos. Com a coleta ainda completa, o comportamento é **idêntico** — o teste de regressão é
que os 52 continuam 52.

Fazer isto antes de qualquer corte é o que permite provar que o corte não mudou a marca.

### Fase 3 — pular repositório sem atividade *(história 2, P1)*

Compara `last_pushed_at` com `issues_collected_at`. Elimina 106 de 121 sem tocar na consulta de
issues. A tela diz quantos foram pulados e por quê — pular em silêncio é indistinguível de não
achar nada.

### Fase 4 — trazer só a issue alterada *(história 3, P2)*

`filterBy: {since:}` na consulta, com sobreposição de janela declarada. Depende da fase 0.

### Fase 5 — a rede de segurança *(FR-012)*

Coleta completa periódica, com a cadência declarada e visível. Entra **de qualquer jeito**, e não
como plano B: mesmo que remover sub-issue altere o `updatedAt` do pai, uma passada completa é o
que impede a marca de derivar em silêncio ao longo de meses.

## Artefatos gerados

| Arquivo | O que traz |
|---|---|
| [research.md](./research.md) | as três perguntas, e a quarta que apareceu ao ler o código |
| [data-model.md](./data-model.md) | `syncs.mode`, e o que muda de significado em `issues_collected_at` |
| [contracts/coleta-incremental.md](./contracts/coleta-incremental.md) | as assinaturas que mudam, antes de a implementação existir |
| [quickstart.md](./quickstart.md) | como provar, e o que medir dos dois lados |

## Constitution Check — reavaliação depois do desenho

**Nenhuma violação.** Duas observações que a reavaliação produziu:

**A FR-012 deixou de ser risco e virou requisito com forma.** A spec dizia "o plano MUST declarar
a estratégia"; a estratégia é escopar a marca, e a coleta completa periódica é rede de segurança —
não a estratégia principal, que era como a spec a imaginava.

**A fase 1 não é acessório.** Ela aparecia como conserto de tela e é, na verdade, o instrumento de
medida da feature inteira. Sem contagem correta, o sucesso desta feature não é verificável — e uma
feature cujo sucesso não é verificável não deveria ser construída.
