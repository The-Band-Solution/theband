# Modelo de dados — Feature 005

Duas tabelas novas, três colunas em `issue_promotions`, e uma tabela que **não** será criada.

Camada de plataforma: o vocabulário aqui é do GitHub — nome de tipo e texto de título. Nenhuma
tabela de ontologia é tocada, e o conceito de destino entra como **identificador em texto**,
validado contra a base de conhecimento, nunca por chave estrangeira entre ontologias.

---

## `issue_mapping_rules`

A regra que uma organização declarou.

| Coluna | Tipo | Nulo | Nota |
|---|---|---|---|
| `id` | `uuid` | não | |
| `tenant_id` | `uuid` → `tenants` | não | `on_delete: :restrict` |
| `organization_id` | `uuid` → `eo_organizations` | não | o escopo é a organização (FR-001) |
| `where` | `string` | não | `declared_type` ou `title` |
| `how` | `string` | não | `equals`, `starts_with`, `contains`, `regex` |
| `pattern` | `text` | não | o texto ou a expressão, como a pessoa escreveu |
| `case_sensitive` | `boolean` | não, `false` | FR-007 |
| `target_concept` | `string` | não | identificador de conceito da base |
| `position` | `integer` | não | ordem de aplicação, visível na tela |
| `active` | `boolean` | não, `true` | desativar **não** apaga (FR-006) |
| `deactivated_at` | `utc_datetime` | sim | quando |
| `deactivated_by_id` | `uuid` → `users` | sim | quem |
| `created_by_id` | `uuid` → `users` | não | **obrigatório**: mapeamento é decisão |
| `catalog_key` | `string` | sim | de qual entrada do catálogo veio, quando veio |
| `version` | `integer` | não, `1` | incrementa a cada alteração |

**Índices**

- único em `(organization_id, where, how, pattern)` — a mesma comparação não é declarada duas
  vezes na mesma organização;
- único em `(organization_id, position)` — a ordem é determinística por construção, e não por
  convenção;
- `(tenant_id, organization_id, active)` — a consulta que a decisão faz a cada issue.

### `created_by_id` é obrigatório, e é isso que impede a regra sem autor

Mapeamento é **decisão**, não configuração. Uma regra sem autor não tem a quem perguntar
"por que isto é uma user story", e é o que o FR-005 exige. Não há caminho que grave regra com
autor "sistema" — nem para o catálogo: ativar uma proposta registra **quem ativou** (FR-041).

### `position` é único por organização

A ordem entre regras que casam a mesma issue precisa ser determinística **e visível** (FR-009).
Sem o índice único, duas regras com a mesma posição fariam a classificação depender do plano de
execução — a mesma classe de defeito da L20.

### Desativar não apaga

`active = false` com `deactivated_at` e `deactivated_by_id`. A regra desativada **para de
valer** e continua consultável: as promoções que ela produziu apontam para ela, e apagá-la
tornaria a proveniência ilegível.

### `catalog_key` liga à proposta de origem

Formato: `(where, how, pattern)` normalizado — **nunca** o índice da entrada no YAML.
Reordenar o catálogo não pode desligar decisões já tomadas, e usar o índice faria exatamente
isso.

Nulo quando a regra foi escrita à mão, e é a diferença entre "editei a proposta" e "escrevi do
zero".

---

## `unmapped_pattern_decisions`

O registro de que um padrão **não** designa tipo. Transforma pendência em ausência declarada.

| Coluna | Tipo | Nulo | Nota |
|---|---|---|---|
| `id` | `uuid` | não | |
| `tenant_id` | `uuid` → `tenants` | não | |
| `organization_id` | `uuid` → `eo_organizations` | não | |
| `pattern` | `text` | não | o padrão candidato, como a tela o agrupou |
| `decided_by_id` | `uuid` → `users` | não | obrigatório |
| `decided_at` | `utc_datetime` | não | |
| `reverted_at` | `utc_datetime` | sim | a decisão é **reversível** (FR-032) |
| `note` | `text` | sim | por que não é tipo, quando alguém quis dizer |

**Índice** único em `(organization_id, pattern)`.

### Por que esta tabela existe

`[Devops]` tem 340 issues, `[Back-end]` 256, `[Front-end]` 237, `[Dados]` 186, `[QA]` 97 —
cerca de 1600 issues cujo prefixo diz **quem faz** ou **em que área**, não **o que é**.

Sem esta tabela, esses padrões ficam para sempre na lista de pendências. Duas consequências, e
a segunda é pior: a lista deixa de ser lida, e a insistência empurra alguém a mapear área como
tipo — 340 user stories que são rótulos de equipe.

**A decisão é reversível** porque alguém pode marcar como "não é tipo" o que é. `reverted_at`
preenchido devolve o padrão à lista, e o registro de quem decidiu o quê permanece.

---

## `issue_promotions` — as três colunas

A tabela é da feature 004 e continua **append-only**.

| Coluna | Tipo | Nulo | Nota |
|---|---|---|---|
| `evidence_source` | `string` | sim | `declared_type` ou `title` |
| `confidence` | `string` | sim | `high` ou `medium` |
| `mapping_rule_id` | `uuid` → `issue_mapping_rules` | sim | qual regra decidiu |

### Confiança é nível, nunca número

`high` para decisão por tipo declarado; `medium` para inferência sobre título. É o vocabulário
que a base de conhecimento já usa.

**Um número — "confiança 0,7" — seria inventado.** Não há como calibrá-lo, e um número vira
meta: alguém o otimizaria escrevendo regras mais amplas, e a medida deixaria de medir.

### Por que a fonte da evidência é coluna, e não derivável da regra

Porque a promoção **sobrevive à regra**. A regra pode ser desativada, e a promoção que ela
produziu continua sendo um fato: "esta issue foi promovida por inferência de título em tal
data". Derivar a fonte da regra no momento da leitura daria resposta diferente depois de a
regra mudar.

`nil` nas três colunas é o estado das 1015 promoções da feature 004 — decididas antes de esta
feature existir. Elas **não** são retrofitadas: preencher `evidence_source` retroativamente
afirmaria algo que ninguém verificou. A tela declara "não informado" para elas.

### Uma medida derivada nunca soma os dois sem dizer

FR-015. Uma medida de escopo que somasse issues promovidas por tipo declarado e por inferência
de título **tem de declarar a composição**. A soma silenciosa transformaria 1300 inferências
sobre texto livre em fato, e é o que o princípio III existe para impedir.

---

## O que este modelo **não** cria

| Não criado | Por quê |
|---|---|
| `tool_concept_mappings` | é o caso `how: equals` desta feature; duas tabelas divergiriam (FR-036) |
| cópia do catálogo por organização | 18 linhas com autor "sistema" na conexão, contra FR-041 |
| tabela de mapeamento campo → atributo | fica no product backlog (FR-037); campo não é tipo |
| coluna com o conceito "efetivo" na issue | é a promoção vigente; materializar é a ADR 0004 D7 |
| chave estrangeira para tabela de conceito | conceito vive na base em YAML, não em tabela |

---

## Consultas que este modelo sustenta

| Pergunta | Custo |
|---|---|
| regras vigentes da organização, na ordem | 1, pelo índice `(tenant, org, active)` |
| que regra decidiu esta issue | 1, pela FK em `issue_promotions` |
| quantas issues esta regra casaria | 1 varredura das issues da organização, em memória |
| tipos declarados sem conceito, com o nome | 1, já existe — `unknown_types/2` da feature 004 |
| padrões candidatos de título, agrupados | 1 com `substring`, sobre as issues sem conceito |
| padrões já declarados como "não é tipo" | 1 |

**A prévia e o recálculo usam a mesma função de decisão.** A diferença é só o que fazem com o
resultado: a prévia conta, o recálculo grava. Duas implementações fariam a prévia mentir, e é o
SC-007.
