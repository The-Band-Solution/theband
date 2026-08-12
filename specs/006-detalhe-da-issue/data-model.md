# Modelo de dados — Feature 006

Duas tabelas novas e nove colunas em `collected_issues`. Nenhuma coluna é removida, e
nenhuma tabela de ontologia é tocada.

**O que este documento não é**: a fonte do esquema das ontologias. Aquele é **derivado** da
base de conhecimento pelo derivador (ADR 0004 D4). O que está aqui é camada de plataforma —
vocabulário do GitHub —, e camada de plataforma é escrita à mão.

---

## `collected_issues` — as nove colunas

| Coluna | Tipo | Nulo | O que a ausência significa |
|---|---|---|---|
| `body` | `text` | sim | **`nil` ≠ `""`** — ver abaixo |
| `state_reason` | `string` | sim | issue aberta, ou fechamento sem motivo na origem |
| `author_login` | `string` | sim | autor removido da origem, ou conta apagada |
| `author_person_id` | `uuid` → `eo_people` | sim | pessoa não coletada; o login fica |
| `milestone_title` | `string` | sim | issue fora de marco |
| `project_titles` | `text[]` | não, `{}` | issue fora de quadro |
| `comment_count` | `integer` | não, `0` | zero é zero — e é diferente de ausente |
| `reaction_count` | `integer` | não, `0` | idem |
| `external_updated_at` | `utc_datetime` | sim | origem não informou |
| `external_closed_at` | `utc_datetime` | sim | issue aberta |

### `body`: `nil` e `""` dizem coisas diferentes

- **`nil`** — a plataforma **nunca pediu** o corpo à origem. É o estado das 4455 issues
  coletadas antes desta feature, e vai continuar assim até cada organização ser reobservada;
- **`""`** — a origem devolveu corpo vazio: a issue não tem descrição.

A distinção é possível porque `bodyText` devolve `""`, nunca `nil`. A tela diz coisas
diferentes para os dois casos, e é a L13 aplicada à exibição.

**Uma migração que preenchesse `""` apagaria a distinção** e afirmaria algo falso sobre 4455
issues que ninguém olhou.

### `author_person_id` é referência, não cópia

Aponta para `eo_people`, **através da fronteira** entre a camada de plataforma e a ontologia
EO. O nome da pessoa **não** é copiado: vem por `EO.people_names/2` no momento da leitura.

Copiar o nome criaria duas verdades sobre a mesma pessoa, e a cópia envelheceria em silêncio
quando a pessoa mudasse de nome na origem.

`on_delete: :nilify_all`: pessoa removida deixa o login e desfaz o vínculo — a issue não
desaparece porque a pessoa saiu.

### `project_titles` é `text[]`, e é deliberadamente pobre

O quadro **não** é entidade nesta feature: a coleta de quadros ficou fora da feature 004
(fase F4, não implementada). Guardar o título responde "esta issue aparece em qual quadro" sem
inventar a entidade pela porta de trás.

**Nenhum dos dois é promovido.** O quadro não é o sprint — sprint é a iteração, que continua
fora do escopo. E o marco do GitHub é usado para release e para sprint indistintamente:
promovê-lo escolheria por conta própria.

---

## `issue_assignees`

| Coluna | Tipo | Nulo | Nota |
|---|---|---|---|
| `id` | `uuid` | não | |
| `tenant_id` | `uuid` → `tenants` | não | `on_delete: :restrict` |
| `collected_issue_id` | `uuid` → `collected_issues` | não | `on_delete: :delete_all` |
| `login` | `string` | não | preservado sempre |
| `person_id` | `uuid` → `eo_people` | **sim** | ausência é **declaração** |

**Índice único**: `(collected_issue_id, login)`. A mesma pessoa não aparece duas vezes na
mesma issue, e a substituição é idempotente por causa dele.

**Por que tabela, e não coluna nem array**: designado é zero ou muitos. Coluna guardaria um
e perderia o resto; array perderia a referência à pessoa coletada.

**`person_id` nulo é o caso comum, não a exceção**: bot (`github-actions`), conta fora da
organização, ou coleta de pessoas mais antiga que a de issues. O login fica, o vínculo fica
visivelmente ausente, e a tela diz "pessoa não coletada" — criar a pessoa a partir da issue
produziria registro sem a proveniência que a coleta de EO dá.

---

## `issue_labels`

| Coluna | Tipo | Nulo | Nota |
|---|---|---|---|
| `id` | `uuid` | não | |
| `tenant_id` | `uuid` → `tenants` | não | |
| `collected_issue_id` | `uuid` → `collected_issues` | não | `on_delete: :delete_all` |
| `name` | `string` | não | como a origem escreveu |
| `color` | `string` | sim | hexadecimal sem `#` |

**Índices**: único em `(collected_issue_id, name)`; e `(tenant_id, name)`, para responder
"quais issues usam o rótulo X" sem varrer a tabela.

**O rótulo é preservado e NÃO é promovido.** Um rótulo `bug` não faz a issue um defeito: quem
decide o conceito é o tipo declarado ou a regra da organização. Esta tabela existe justamente
para registrar o que a origem diz **sem agir sobre isso** — sem ela, a tentação de inferir
conceito a partir do nome do rótulo voltaria, e é o antipadrão do princípio I.

---

## Substituição **marca**, e a decisão anterior foi revertida

`replace_assignees/3` e `replace_labels/3` **marcam** com `no_longer_observed_at` o que a
origem não traz mais. A linha permanece.

A decisão original era apagar, com a justificativa de que designação é atributo do agora. Foi
**revertida em 2026-08-12**, quando a pessoa mantenedora enunciou a regra da plataforma: nunca
se apaga dados. O critério de reversão estava escrito, e foi atendido.

A tela continua respondendo *"quem está nisto agora"* — ela filtra por vigência. O que mudou é
que *"quem já esteve"* passou a ser respondível por consulta, e não por arqueologia de payload.

Designado que **volta** a aparecer tem a marca limpa: quem devolve vigência é a coleta, como em
toda a plataforma.

---

## O que esta feature **não** cria

| Não criado | Por quê |
|---|---|
| `sro_user_stories.status` | a classificação é derivada; materializá-la é a ADR 0004 D7 |
| coluna com a violação de `sro.rule07` | divergiria quando a classificação do pai mudasse |
| tabela de comentários | a contagem é coletada, o conteúdo não |
| tabela de quadros | ficou na feature 004 F4; meia entidade seria pior que nenhuma |
| tabela de anexos | a plataforma não armazena binário da origem |

---

## Consultas que este modelo sustenta

| Pergunta | Função | Custo |
|---|---|---|
| tudo desta issue | `fetch_issue/2` | 3 consultas (issue+promoção, designados, rótulos) + classificação |
| o que compõe | `list_composition/2` | 1 |
| o que atende | `list_attendance/2` | 1 |
| partes sem conceito | `list_unpromoted_parts/2` | 1 |
| pai | `fetch_parent/2` | 1 |
| histórico de decisão | `promotion_history/2` | 1 |
| vínculos recusados | `list_refused_for/2` | 1 |
| violações do axioma no repositório | `rule07_violations/2` | 1, e a decisão é em memória |

`rule07_violations/2` traz o grafo numa consulta e decide em memória, como `list_links/1` já
fazia: uma consulta por issue seriam 4455 idas ao banco para desenhar uma tela.
