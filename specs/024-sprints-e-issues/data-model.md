# Data model — as caixas de tempo, e as issues dentro delas

**Feature** `024-sprints-e-issues` · **Data**: 2026-08-15

Duas tabelas. A primeira é a **primeira materialização da SRO** neste repositório, e a forma dela
será copiada pelas irmãs.

---

## `sro_sprints`

| Coluna | Tipo | Nulo | Por quê |
|---|---|---|---|
| `tenant_id` | uuid | não | escopo, como em toda tabela |
| `internal_id` | texto | não | hash da Application Reference — ver abaixo |
| `connected_tool_id` | uuid | não | de qual ferramenta veio |
| `board_number` | inteiro | não | o quadro no Projects v2 |
| `board_title` | texto | **sim** | o quadro pode não ter título |
| `field_name` | texto | não | **`Sprint`, `Iteration`, `Quarter` — como a origem nomeia** |
| `title` | texto | não | `Sprint 38`, `Quarter 3` |
| `started_on` | date | não | da iteração |
| `duration_days` | inteiro | não | **da iteração, nunca a do campo** |
| `ended_on` | date | não | derivado: início + duração − 1 |
| `completed` | booleano | não | a origem separa `iterations` de `completedIterations` |
| `source_system` · `source_instance` · `source_external_id` | texto | não | proveniência |

### O critério de identidade, que **não existia**

`sro.sprint` não declara `identity_criterion`, e nenhum ancestral declara. Esta feature o escreve:

```
tenant_id · source_system · source_instance · source_external_id
```

**É a Application Reference, e não um hash de atributos** — diferente de
`spo.performed_project_activity`. O motivo é que a iteração **tem identificador próprio na
origem**, e o evento de timeline não tinha.

E é o que protege contra o defeito óbvio: nome, data e duração são **editáveis** na origem.
Renomear `Sprint 38` ou corrigir a data trocaria a identidade num hash de atributos, e a coleta
seguinte criaria uma caixa nova ao lado da antiga.

### `field_name` é gravado, e o motivo é o mesmo do `activity_type`

Todo campo de iteração vira sprint — decisão da pessoa mantenedora. Mas **`Quarter` de 90 dias e
`Sprint` de 14 continuam distinguíveis no dado**, porque somá-los sem saber produziria uma
contagem por sprint que mistura granularidades.

### `duration_days` é da iteração

Medido em 2026-08-15: `Sprint 10` tem **3 dias** num campo configurado para 14; `Quarter 1` tem
**61** num de 90. Gravar a do campo faria a série mentir sobre o período coberto.

---

## `sro_sprint_issues`

| Coluna | Tipo | Nulo | Por quê |
|---|---|---|---|
| `tenant_id` | uuid | não | escopo |
| `sprint_id` | uuid | não | a caixa |
| `collected_issue_id` | uuid | não | a issue |
| `observed_at` · `last_observed_at` | timestamp | não | quando a plataforma viu |
| `no_longer_observed_at` | timestamp | **sim** | **ausência marca, nunca apaga** |

```
UNIQUE (tenant_id, sprint_id, collected_issue_id)
```

### Muitos-para-muitos, e a medida obrigou

No DevOps, `527 + 203 = 730` associações sobre **677 itens**: a mesma issue está num `Sprint` e
num `Quarter`.

Uma coluna `sprint_id` em `collected_issues` teria de escolher uma das duas, e **não há regra que
justifique a escolha** — o Produtos Internos inverte a proporção, com `Quarter` em 15 itens e
`Sprint` em 3.

---

## O que as tabelas deliberadamente não têm

| Não tem | Por quê |
|---|---|
| `sprint_id` em `collected_issues` | ver acima; a sobreposição é medida, não hipótese |
| coluna dizendo se é sprint "de verdade" | todo campo de iteração é sprint, por decisão; `field_name` preserva a origem |
| velocity, pontos ou tamanho | a origem não fornece unidade de tamanho, e contá-la em issues muda com a granularidade |
| `ended_on` vindo da origem | a origem não fornece; é aritmética de início mais duração |
| item de quadro que não é issue | rascunho do Projects não vira issue inventada |

---

## Invariantes que os testes têm de afirmar

1. **Duas coletas produzem o mesmo número de caixas e de vínculos.**
2. **A soma das associações do DevOps é maior que o número de itens** — 730 sobre 677, porque a
   mesma issue está em duas caixas. Achatar isso é o defeito que o modelo existe para impedir.
3. **A duração gravada é a da iteração** — `Sprint 10` com 3 dias, e não 14.
4. **Issue que saiu de um sprint tem o vínculo marcado**, e a linha continua existindo.
5. **Quadro sem campo de iteração não produz consulta de itens** — e isso não é erro.
6. **"O quadro não usa caixas de tempo" e "todas as issues estão fora delas"** produzem respostas
   diferentes.
