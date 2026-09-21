# Modelo de dados — 066

## `spo_item_phase_declarations`

A organização declara o que uma **opção** de um **campo de seleção única** de um **quadro**
significa em termos de atividade. Uma linha por opção por período de vigência.

| coluna | tipo | nota |
|---|---|---|
| `id` | uuid | |
| `tenant_id` | uuid | não nulo |
| `observed_project_id` | uuid | o quadro; não nulo |
| `field_external_id` | string | o campo na origem — o quadro pode ter mais de um de seleção única |
| `option_external_id` | string | **a identidade da opção**; renomear na origem não muda |
| `option_name_at_declaration` | string | o nome no momento — para mostrar quando divergir do atual |
| `target_concept` | string | `sro.intended_scrum_development_task` · `spo.performed_project_activity.em_andamento` · `spo.performed_project_activity.concluida` · `nao_diz_fase` |
| `declared_by_user_id` | uuid | |
| `declared_at` | utc_datetime | |
| `revoked_by_user_id` | uuid | |
| `revoked_at` | utc_datetime | nulo = vigente |

**Índice parcial** sobre `(tenant_id, observed_project_id, field_external_id,
option_external_id)` com `revoked_at IS NULL`: uma declaração vigente por opção, e revogar
preserva o começo.

**Sem enum no banco** para `target_concept`: o conceito vive no YAML. O changeset valida contra
os destinos que a regra admite.

## O que é derivado, e nunca gravado

| derivação | de onde |
|---|---|
| **fase do item** | o valor atual de `Status` do card × a declaração vigente |
| **proposta** | opção observada cujo nome coincide com o vocabulário reconhecido **e** sem declaração |
| **desacordo** | fase declarada *concluída* × `state`/`closed_at` da issue |

## O que a leitura devolve, por item

`%{estagio: nome, estagio_option_id: id, fase: :concluida | :em_andamento | :planejada |
:nao_diz_fase | nil, quadro: %{id, title}}` — `fase: nil` é *não declarado*, e a tela escreve a
ausência.
