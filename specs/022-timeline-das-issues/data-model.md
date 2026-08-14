# Data model — a atividade executada

**Feature** `022-timeline-das-issues` · **Data**: 2026-08-14

Uma tabela nova, e ela é a **primeira materialização de um conceito compartilhado**. O que ela
não tem é tão decidido quanto o que ela tem.

---

## `spo_performed_project_activities`

Nome com o prefixo do módulo ontológico, como `cmpo_source_repositories` e `eo_team_memberships`.

| Coluna | Tipo | Nulo | Por quê |
|---|---|---|---|
| `tenant_id` | uuid | não | escopo, como em toda tabela |
| `internal_id` | texto | não | o hash do critério de identidade |
| `organization_id` | uuid | **sim** | está no critério; nem toda origem futura o conhece |
| `project_id` | uuid | **sim** | idem — e omiti-lo agora faria o hash mudar quando for preenchido |
| `activity_type` | texto | não | **o tipo como a origem o nomeia** |
| `concept_id` | texto | **sim** | o conceito da rede, quando houver; nulo é o tipo não mapeado |
| `performer_id` | uuid | **sim** | a ontologia declara: *"atividades automatizadas não têm executor humano"* |
| `performer_login` | texto | **sim** | quem a origem nomeou, quando a pessoa não é conhecida |
| `occurred_at` | timestamp | não | o instante que **individua a ocorrência**, e não muda depois |
| `subject_type` | texto | não | de que entidade é a atividade — `issue` hoje, `commit` amanhã |
| `subject_id` | uuid | não | a entidade, sem chave estrangeira dedicada |
| `source_system` · `source_instance` · `source_external_id` | texto | não · não · **sim** | proveniência; o último preserva a identidade da origem |
| `payload` | jsonb | **sim** | o que a origem mandou e a plataforma ainda não interpreta |

### `activity_type` é texto, e não `Ecto.Enum`

O GitHub acrescenta tipos de timeline, e o conjunto é **do mundo**, não do código. Um enum
obrigaria migração a cada tipo novo — e, pior, faria a coleta **falhar** ao encontrar um
desconhecido, quando a decisão é registrá-lo.

### `subject_type` e `subject_id`, e não `collected_issue_id`

Um commit não tem issue. Uma implantação não tem issue. Coluna dedicada ficaria nula em metade
das linhas quando a segunda origem chegar — e a ontologia **já declara** que ela vai chegar:
*"commits, execuções de teste, cerimônias, implantações e inspeções são todos especializações
deste conceito"*.

**O custo está nomeado**: achar as atividades de uma issue exige filtrar por `subject_type`, e
não seguir uma chave estrangeira.

### `concept_id` nulo é informação

Nulo significa **a rede não nomeia este tipo**. Não é falha da coleta nem dado faltando: é o
estado honesto de `labeled`, `mentioned`, `cross-referenced` e `renamed`.

Preencher com um conceito aproximado seria inventar; descartar a linha seria a **L57**.

---

## O que a tabela deliberadamente não tem

| Não tem | Por quê |
|---|---|
| `start_date` e `end_date` no critério de identidade | a ontologia escreveu o motivo: *"end_date é nulo enquanto a atividade corre e preenchido ao terminar, e incluí-lo faria o hash mudar no encerramento, quebrando toda referência existente"* |
| coluna de duração | derivada, e derivar exige saber o par de eventos — que é decisão de outra feature |
| coluna dizendo se é antipadrão | a detecção é consumidora, e gravar aqui congelaria a regra: mudá-la exigiria recoletar |
| `collected_issue_id` | ver acima |

---

## O índice de unicidade

```
UNIQUE (tenant_id, internal_id)
```

E `internal_id` é o hash do critério da ontologia, com representação canônica para os
componentes ausentes — a ontologia exige isso explicitamente: *"a ausência tem representação
canônica no hash para manter o resultado determinístico"*.

**É o que faz duas coletas do mesmo evento produzirem uma linha**, e é a FR-003.

---

## Invariantes que os testes têm de afirmar

1. **Duas coletas seguidas produzem o mesmo número de ocorrências** — nenhuma duplicata.
2. **A soma dos eventos com conceito e sem conceito é igual ao total que a origem devolveu** —
   nada foi descartado.
3. **Evento sem executor é gravado**, com `performer_id` nulo, e o `internal_id` continua
   determinístico.
4. **Nenhuma linha é apagada por coleta seguinte** — atividade é ocorrência, e ocorreu.
5. **Repositório pulado pela feature 020 não produz atividade alguma** — e isso não é o mesmo
   que "não houve atividade".
