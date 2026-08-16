# Data Model — Perfil de competências

## `eo_person_profiles` — uma linha por geração, nunca atualizada

| coluna | tipo | por quê |
|---|---|---|
| `id` | uuid | |
| `tenant_id` | uuid, não nulo | multitenancy; toda consulta filtra por ele |
| `person_id` | uuid, não nulo | `eo.person`, **não** o login — troca de login no GitHub não pode apagar histórico |
| `generated_at` | utc_datetime, não nulo | o vigente é o maior; não existe `updated_at` porque não existe atualização |
| `requested_by_user_id` | uuid | geração é ato de alguém, e ato tem autor |
| `model` | text, não nulo | qual modelo escreveu — muda a leitura do texto |
| `body` | text, não nulo | o perfil. `check` de não-vazio: resposta vazia é falha, não perfil |
| `citations_removed` | integer, não nulo, `default 0` | quantas citações a limpeza tirou do resumo. Zero é medição, não ausência |

### O recorte de entrada, em colunas

Não é JSON solto: é o que permite dizer, meses depois, sobre o que aquele texto falava, e é
consultado por `FR-016`.

| coluna | por quê |
|---|---|
| `tasks_closed`, `tasks_open` | o tamanho do material |
| `tasks_with_body` | o que passou no piso de evidência |
| `tasks_authored_by_other` | 44% no tenant; muda o que o texto prova |
| `tasks_shared` | trabalho de mais de uma pessoa |
| `period_from`, `period_to` | date; o intervalo coberto |
| `baseline_verdict` | text; a frase calculada sobre pessoa × projeto |

### Índices

- `unique(tenant_id, person_id, generated_at)` — impede gravar duas vezes o mesmo instante;
- `index(tenant_id, person_id)` — a consulta do vigente.

**Nenhuma chave estrangeira para `collected_issues`.** O perfil descreve um recorte que já
passou; uma issue apagada não deve apagar o perfil que a mencionou.

## O que **não** vira tabela

- **competência** — [research.md R1](./research.md): a plataforma não afirma que a pessoa tem
  a habilidade, guarda um texto que a descreve;
- **linha de base** — é derivável de `collected_issues` numa consulta, e materializá-la criaria
  uma segunda fonte que divergiria na primeira coleta;
- **períodos** — são recorte de leitura, não fato do mundo.
