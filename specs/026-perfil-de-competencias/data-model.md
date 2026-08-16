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
| `content` | jsonb, não nulo | o perfil **estruturado** — habilidades, resumo, trajetória, destaques, lacunas. `check` de habilidade não vazia: resposta degenerada é falha, não perfil |
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

## Por que `content` é jsonb, e não texto

**Corrigido em 2026-08-16, durante a implementação.** A primeira versão guardava prosa, e o
custo apareceu na primeira geração em que o modelo largou os subtítulos: a limpeza do resumo
tratou o documento inteiro como resumo e apagou dezenove citações, em silêncio.

Com o provedor respondendo num schema declarado e `strict: true`, a estrutura é garantida na
origem. Três consequências:

- **a tela renderiza cada parte com o componente certo** — habilidades como marcas, destaques
  com o critério visível, lacunas classificadas por forma — em vez de despejar markdown;
- **a limpeza do resumo endereça três campos**, e não um documento cuja estrutura precisa
  adivinhar;
- **faltar uma seção vira erro de changeset**, e não um buraco na tela que parece a
  plataforma não ter tido o que dizer.
