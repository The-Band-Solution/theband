# Data Model: O critério de início

**Feature**: 042 · **Data**: 2026-08-24

---

## O conceito na rede

Entra em `priv/knowledge_base/ontology/seon/spo/modules/activity_start_criterion.yaml`, **antes do código** — os gates reprovam se o YAML faltar.

```yaml
concepts:
  - id: spo.activity_start_criterion
    classification: { ufo_category: social_object, ontouml_stereotype: kind }
    definition:
      pt-BR: >
        O tipo de evento que uma organização declara como aquele que traz à tona a
        situação de um trabalho ter começado.

        É objeto SOCIAL porque a resposta não está no dado observado: organizações
        diferentes reconhecem eventos diferentes como início, e nenhuma está errada.
        A plataforma não escolhe — ela registra a escolha, com quem a fez e quando.

relations:
  - id: spo.criterion_recognises
    source: spo.activity_start_criterion
    target: ufo.event
    cardinality: { source: many, target: one }

  - id: spo.criterion_declared_for_project
    source: spo.activity_start_criterion
    target: spo.project

  - id: spo.criterion_declared_for_board
    source: spo.activity_start_criterion
    target: spo.project      # o quadro observado; ver nota
```

> **Nota sobre o alvo quadro.** A rede não tem conceito para "quadro do Projects v2" — `observed_projects` é tabela de **coleta**, não de domínio. A relação com o quadro é do esquema, não da rede, e isso fica **declarado como limitação** no YAML em vez de inventar um conceito para acomodar a implementação. É a mesma forma da limitação que `workflow_run` já declara sobre `cmpo.source_repository`.

---

## `spo_activity_start_criteria`

| coluna | tipo | nulo | o que é |
|---|---|---|---|
| `id` | uuid | não | |
| `tenant_id` | uuid | não | princípio V — toda consulta filtra por ele |
| `project_id` | uuid | **sim** | alvo, quando a declaração é do projeto |
| `observed_project_id` | uuid | **sim** | alvo, quando é do quadro |
| `event_type` | string | não | o tipo cru da origem, ex. `ProjectV2ItemStatusChangedEvent` |
| `declared_by_user_id` | uuid | sim | autor — `nilify_all`, porque apagar a pessoa não apaga a decisão |
| `declared_at` | utc_datetime | não | |
| `revoked_by_user_id` | uuid | sim | |
| `revoked_at` | utc_datetime | **sim** | nulo = vigente |

### As restrições, e o que cada uma impede

```sql
-- exatamente um alvo. Sem isto, uma linha com os dois preenchidos entraria na
-- escala duas vezes, e a precedência ficaria indefinida.
CHECK (num_nonnulls(project_id, observed_project_id) = 1)

-- um critério vigente por alvo. Parcial sobre os vigentes: o revogado precisa
-- continuar existindo, e um índice total impediria redeclarar.
UNIQUE (tenant_id, project_id)          WHERE revoked_at IS NULL AND project_id IS NOT NULL
UNIQUE (tenant_id, observed_project_id) WHERE revoked_at IS NULL AND observed_project_id IS NOT NULL
```

**`event_type` fica cru**, sem enum e sem tabela de tipos. A origem nomeia os eventos, e congelar a lista num enum faria a plataforma recusar um evento novo do GitHub como se fosse erro. A `FR-012` restringe a **escolha na tela** ao que é coletado — que é validação de interface, não de esquema.

---

## A resolução, que é o coração da feature

Nenhuma coluna guarda o resultado. A leitura resolve, **em lote**, nesta ordem:

```
para cada issue:
  1. quadros vigentes da issue que declararam critério
     → se 1: esse critério
     → se >1: o do quadro cujo spo_project_boards.linked_at é MAIOR
       → se houver empate no maior: AMBÍGUO
  2. senão, o critério do projeto da issue, se declarado
  3. senão: SEM CRITÉRIO
```

E com o critério em mãos:

```
4. a primeira ocorrência do event_type naquela issue  → start_date
   → se o tipo não foi coletado para ela: EVENTO NÃO COLETADO
```

### As quatro saídas, e por que nenhuma pode virar zero

| saída | significa | o que a tela faz |
|---|---|---|
| instante | resolvido | mostra, **com a origem do critério** — `FR-013` |
| `sem_criterio` | ninguém declarou | *"Nenhum critério foi declarado para este projeto."* + o que fazer |
| `criterio_ambiguo` | dois quadros empatados em `linked_at` | nomeia **os quadros e a data** — `FR-016` |
| `evento_nao_coletado` | critério declarado, evento ausente naquela issue | lacuna de coleta, não de declaração |

**As três ausências são derivadas, nunca gravadas** — decisão 3 do plano. E nenhuma é zero: zero seria afirmar que o trabalho começou no instante zero.

---

## O que esta feature NÃO acrescenta ao esquema

- **Nenhuma coluna `start_date`** em `spo_performed_project_activities`. Ela já tem o atributo no conceito; a materialização é de leitura.
- **Nenhuma tabela de tipos de evento.** A lista da tela vem de `SELECT DISTINCT activity_type` com contagem — o que é coletado, com o volume que a `FR-012` manda mostrar.
- **Nenhum cache.** Decisão 4 do plano: 19.200 atividades não justificam invalidação.
