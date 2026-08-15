# Research — as caixas de tempo, e as issues dentro delas

**Feature** `024-sprints-e-issues` · **Data**: 2026-08-15

Cinco decisões. A primeira é a que a fase 0 obrigou, e ela não estava no radar da spec.

---

## R1 — `sro.sprint` não tem critério de identidade, e nenhum ancestral tem

**Medido em 2026-08-15**, na base de conhecimento:

```
sro.sprint                                  → sem identity_criterion
  parent spo.specific_performed_project_process → sem identity_criterion
    parent spo.performed_project_process        → sem identity_criterion
```

Compare com `spo.performed_project_activity`, que a feature 022 materializou: ele **declara** os
sete componentes, os anuláveis, e a nota sobre representação canônica da ausência.

**Decisão**: declarar o critério na ontologia **antes** da migração, como parte desta feature.

```
tenant_id · source_system · source_instance · source_external_id
```

**Fundamento**: a iteração do Projects v2 **tem identificador próprio na origem** — diferente do
evento de timeline, que não tinha. Então o critério é a Application Reference que a plataforma já
usa em `eo` e `cmpo`, e não um hash composto de atributos.

Isso evita o problema que a feature 022 enfrentou: nome, data de início e duração **mudam** — a
pessoa renomeia `Sprint 38`, corrige a data —, e um hash sobre eles trocaria a identidade a cada
correção, duplicando a caixa.

**Alternativas consideradas**:

| Alternativa | Por que não |
|---|---|
| hash de `nome + início + duração` | os três são editáveis na origem; renomear criaria caixa nova |
| deixar sem critério, chave só interna | duas coletas gerariam duas caixas, e a FR-004 exige o contrário |
| reaproveitar o hash de `performed_project_activity` | é de outro conceito, com componentes que não se aplicam |

---

## R2 — Uma tabela para a caixa de tempo, e o nome do campo vai nela

**Decisão**: `sro_sprints`, com o **nome do campo de origem** gravado em coluna própria.

**Fundamento, medido em 2026-08-15**: 11 de 26 quadros têm campo de iteração, e os campos se
chamam `Sprint`, `Iteration` e `Quarter`. A decisão da pessoa mantenedora é que **todos viram
sprint**, independente do nome.

Mas o nome não é descartado, e a razão é a mesma da 022 com `activity_type`: **é o que a origem
disse**. Sem ele, `Quarter 3` de 90 dias e `Sprint 38` de 14 ficam indistinguíveis na tabela, e
quem olhar uma contagem por sprint não saberá que está somando granularidades diferentes.

| Coluna | Por quê |
|---|---|
| `field_name` | `Sprint`, `Iteration`, `Quarter` — como a origem nomeia |
| `title` | `Sprint 38`, `Quarter 3` — o nome da iteração |
| `started_on` · `duration_days` | os dois vêm da origem, **por iteração** |
| `ended_on` | **derivado** de início + duração; a origem não fornece |

**A duração é a da iteração, e não a do campo.** Medido: `Sprint 10` tem 3 dias num campo
configurado para 14, e `Quarter 1` tem 61 num de 90. Gravar a do campo faria toda a série mentir
sobre o período coberto.

---

## R3 — A associação é muitos-para-muitos, e a medida obrigou

**Decisão**: tabela de associação `sro_sprint_issues`, com marca de ausência.

**Fundamento**: no quadro DevOps, `527 + 203 = 730` associações sobre **677 itens**. A mesma
issue está num sprint **e** num trimestre.

Uma coluna `sprint_id` em `collected_issues` teria de escolher uma das duas, e a escolha seria
arbitrária — o Produtos Internos inverte a proporção, com `Quarter` em 15 itens e `Sprint` em 3.

| Alternativa | Por que não |
|---|---|
| `sprint_id` em `collected_issues` | perderia uma das duas caixas; medido, não hipotético |
| dois campos, `sprint_id` e `quarter_id` | fixaria dois papéis que a origem não declara, e um terceiro campo quebraria |
| guardar só a mais curta | inventaria uma regra de precedência que ninguém decidiu |

**A ausência é marcada, nunca apagada** — `no_longer_observed_at`, como em toda associação
observada da plataforma. Issue que saiu de um sprint continua tendo estado nele.

---

## R4 — A coleta é uma fase nova, e ela não cabe na janela da 020

**Decisão**: fase própria na sincronização, **por quadro**, e não por repositório.

**Fundamento**: a janela da feature 020 pula repositório sem push desde a última revisão. A
caixa de tempo **não pertence ao repositório** — pertence ao quadro, que cruza repositórios. Um
quadro pode ter sprint novo sem que nenhum repositório tenha recebido push.

**Custo medido**: a sondagem de 26 quadros com os campos custou **1 ponto** de cota. A
associação dos itens é mais cara — o DevOps tem 677 itens, paginados de 100 em 100, sete
consultas. Com 11 quadros usando iteração, a ordem de grandeza é de dezenas de consultas por
coleta completa, não de milhares.

**Alternativas consideradas**:

| Alternativa | Por que não |
|---|---|
| coletar junto das issues | a issue não sabe de quadro; a associação vive no item do quadro |
| coletar só quadros com push recente | quadro não tem push; o conceito não se aplica |
| pular quadro sem iteração nova | ainda exige consultar para saber, e a economia seria da segunda consulta |

---

## R5 — O que fica fora, e por que não é adiamento disfarçado

**Decisão**: velocity, burndown e burnup **não** entram.

**Fundamento**: velocity precisa de **unidade de tamanho** — story point ou estimativa — que a
plataforma não coleta. Sem ela, "velocity" viraria contagem de issues por sprint, que muda de
significado quando alguém decompõe mais fino.

É a mesma limitação que `flow.throughput.rate` já declara: *"contar tarefa concluída ignora o
tamanho da tarefa"*.

E há a consequência aceita da decisão de que todo campo vira sprint: no DevOps, a mesma issue
está num `Sprint` de 14 dias e num `Quarter` de 90. **Qualquer velocity por sprint somaria essa
issue duas vezes** — a SC-008 existe para a plataforma dizer isso em vez de escolher um.

---

## O que foi medido, e o que mudou

**Três sondagens contra a API real em 2026-08-15**:

| # | Pergunta | Resposta |
|---|---|---|
| 1 | os quadros têm campo de iteração | **11 de 26**, com 15 campos |
| 2 | as iterações são usadas ou é configuração morta | **usadas** — DevOps com 32 concluídas, Sprint 40 |
| 3 | `Quarter` carrega trabalho | **sim, e às vezes mais que `Sprint`** — 15 contra 3 no Produtos Internos |

A terceira mudou o desenho: coletar só o campo chamado `Sprint` era o caminho óbvio, e mediria
3 itens num quadro com 15.

E a segunda sondagem, sobre a associação, revelou a sobreposição — `527 + 203 > 677` — que
descartou `sprint_id` como coluna antes da primeira migração.

**Uma pergunta nova apareceu na fase 0 e está resolvida no R1**: `sro.sprint` não tem critério de
identidade declarado, e nenhum ancestral tem. A feature 022 encontrou o critério pronto; aqui ele
precisa ser escrito.
