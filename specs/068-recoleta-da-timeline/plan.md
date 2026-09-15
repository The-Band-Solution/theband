# Plano de implementação: a recoleta da timeline truncada

**Feature**: [068](spec.md) · **Branch**: `068-recoleta-da-timeline` · **Criado**: 2026-09-15

## O escopo desta fatia

**US1** (recoletar com prova) e **US2** (provar que trouxe tudo). A **US3** (o efeito por mês) é
consulta sobre o que a US1 grava, e cabe na fatia seguinte sem mudar nada do que esta entrega.

## Onde o código vive, e por quê

**`lib/the_band/ingestion/timeline_recollection.ex`** — a recoleta como função de domínio, ao
lado da coleta que ela corrige, e **não dentro** de `github_work_items.ex`: aquele módulo é a
fase da sincronização, com progresso, checkpoint e broadcast; a recoleta é um ato de operação,
disparado por pessoa, sobre um repositório, e misturar os dois faria a fase carregar um caminho
que ela nunca percorre.

**`lib/mix/tasks/coleta.timeline.ex`** — o consumidor visível desta fatia. A casa já usa Mix task
para ato de operação (`knowledge.validate`, `mensagens.verificar`), e o runbook da 050 é feito de
comandos. A **tela** de disparar a recoleta é fatia seguinte; sem a task, esta fatia seria
infraestrutura sem consumidor, que a casa recusa.

## Decisões de desenho (princípio VIII)

| decisão | que problema resolve, **hoje** | o que piora |
|---|---|---|
| **Módulo próprio**, não dentro da fase de coleta | a fase tem progresso, checkpoint e broadcast que a recoleta não usa; e a recoleta tem retomada e conferência que a fase não tem | dois lugares que falam com a mesma API — mitigado reusando o cliente e a query |
| **Mix task** como primeiro consumidor | entrega o valor hoje, e é o que o runbook usa | quem não tem terminal não recolhe; a tela vem depois |
| **Consulta por `issue(number:)` em lotes de 10** | é o caminho que **não** corta, medido: 14 de 14 na #1828, contra 12 pela conexão | mais consultas; medido em 176 pontos por repositório, contra 5 000 de cota |
| **A conferência usa a conexão** (o caminho que cortava) | provar por caminho **diferente** do usado na recoleta; se usasse o mesmo, provaria só que a origem é consistente consigo mesma | uma consulta a mais por amostra |
| **Retomada por número de issue**, não por cursor | cursor da origem expira e muda de significado entre execuções; o número da issue é estável | percorre em ordem de número, não de atividade |
| **Relatório em struct**, impresso pela task | o mesmo relatório serve à tela da fatia seguinte sem reescrever | um tipo a mais |

**Nenhum padrão novo.** É o mesmo desenho de "ato de operação com relatório" do ensaio de backup.

## Fases

**Fase 1 — a recoleta**: percorrer por números, buscar em lotes de 10, resolver pessoas antes,
gravar o que falta, contar.

**Fase 2 — a prova**: conferência por amostra pela conexão, e o veredito.

**Fase 3 — o relatório e a task**: o que mudou, o que continua suspeito, os limites declarados.

## Constitution Check

| princípio | como esta fatia o cumpre |
|---|---|
| **III** — proveniência e idempotência | não apaga, não altera; a segunda execução insere zero |
| **VIII** — desenho que o problema justifica | tabela acima; nenhuma abstração nova |
| **X** — responsabilidade única | a recoleta faz uma coisa; a fase de coleta continua fazendo a dela |
| **XI** — estado conferido, sinal nunca silenciado | a recoleta não se declara completa por terminar; divergência na amostra reprova |

Sem violação.
