# Contrato — regras de mapeamento por organização

Feature 005. Escrito **antes** da primeira função pública, como o princípio VII exige.

Fronteira nova: `TheBand.Mapping`. Ela é a dona das regras, das decisões de "não é tipo", da
prévia e do recálculo. `TheBand.WorkItems` continua dona das issues e da promoção, e a decisão
por regra entra em `Routing.decide/2` — que já existe.

Nada aqui devolve `Ecto.Query`, e nenhuma função alcança tabela de outro contexto.

---

## `TheBand.Mapping` — escritas

### `create_rule(tenant, organization_id, attrs, actor) :: {:ok, rule} | {:error, changeset | {:invalid_pattern, motivo}}`

Grava a regra **depois** de validar o padrão. `actor` é obrigatório na assinatura, e não existe
versão sem ele: mapeamento é decisão, e uma regra sem autor não tem a quem perguntar por quê
(FR-005).

`{:error, {:invalid_pattern, motivo}}` com um dos três motivos, e cada um traz o que a pessoa
precisa para corrigir:

| Motivo | Devolve | Por que recusa |
|---|---|---|
| `{:does_not_compile, razão, posição}` | a razão e a **posição** | é o que permite corrigir |
| `:matches_empty` | — | casaria **todas** as issues |
| `{:too_slow, limite_ms}` | o limite | prenderia o processo da tela |

**A validação é a mesma função que a prévia usa.** Prévia e efeito por caminhos diferentes é o
que o SC-007 proíbe.

### `update_rule(tenant, rule_id, attrs, actor)`

Incrementa `version`. Regra vinda do catálogo passa a ter versão da organização, e o catálogo
**não** é alterado (FR-042).

### `deactivate_rule(tenant, rule_id, actor)`

`active = false`, com quem e quando. **Não apaga**: as promoções que a regra produziu apontam
para ela, e apagá-la tornaria a proveniência ilegível (FR-006).

### `activate_catalog_rule(tenant, organization_id, catalog_key, actor)`

Materializa uma proposta do catálogo como regra da organização, com **a pessoa** como autora —
nunca "sistema" (FR-041).

### `activate_all_proposals(tenant, organization_id, actor) :: {:ok, [rule]}`

FR-044. Uma ação, uma autoria: todas as regras criadas registram o mesmo `actor`.

### `declare_not_a_type(tenant, organization_id, pattern, actor, note \\ nil)`

Registra que o padrão **não** designa tipo. O padrão sai da lista de pendências e passa a
aparecer como ausência **declarada** (FR-032).

### `revert_not_a_type(tenant, decision_id, actor)`

Devolve o padrão à lista. A decisão é reversível porque alguém pode marcar como "não é tipo" o
que é; o registro de quem decidiu o quê permanece.

### `recompute(tenant, organization_id, actor) :: {:ok, %Oban.Job{}}`

Enfileira o recálculo na fila **`transformation`, que já existe**. Declarar fila nova sem
configurá-la faz o job ficar `available` para sempre — aconteceu nesta sessão, e o sintoma foi
uma coleta que "completou" sem coletar nada.

**Assíncrono sempre, sem limite condicional.** Um limite — síncrono até N — criaria dois
caminhos, e o raro é o que quebra: seria testado com 10 issues e usado com 3440.

---

## `TheBand.Mapping` — leituras

### `list_rules(tenant, organization_id, opts) :: [map()]`

As regras **na ordem em que são aplicadas** (FR-033), com autor, data, versão e quantas issues
cada uma promoveu.

### `list_proposals(tenant, organization_id) :: [map()]`

O catálogo **composto** com as regras da organização. Cada entrada devolve:

| Campo | Significa |
|---|---|
| `catalog_key` | `(where, how, pattern)` normalizado — **nunca** o índice no YAML |
| `state` | `:proposed`, `:activated` ou `:edited` |
| `would_match` | quantas issues daquela organização casariam |
| `is_type` | se o catálogo declara que o padrão designa tipo |

**Nada é copiado para o banco na conexão.** A composição é em leitura: a organização só tem
linha quando alguém **decidiu**, e a ausência de linha significa "nunca decidido" em vez de
"cópia intocada" (FR-043).

`would_match == 0` aparece como **não aplicável a esta organização**, não como erro (FR-045).

### `preview(tenant, organization_id, attrs) :: {:ok, map()} | {:error, {:invalid_pattern, motivo}}`

A prévia, calculada sobre as issues **já coletadas** — nenhuma requisição à origem (FR-023,
SC-008).

| Campo | Significa |
|---|---|
| `matched` | quantas issues a regra casa |
| `would_change` | quantas **mudariam de conceito** — distinto de `matched` |
| `sample` | os primeiros títulos, para conferir a olho |

`matched` sem `would_change` esconderia o caso perigoso: uma regra que casa 900 issues e muda o
conceito de 900 é muito diferente de uma que casa 900 e muda 3.

**`would_change` é calculado pela mesma função de decisão que o recálculo usa**, e o SC-007
exige que a diferença entre prévia e efeito seja zero.

### `list_gaps(tenant, organization_id) :: map()`

A lacuna agrupada, e ela separa o que a tela **não pode** confundir:

| Chave | O que traz |
|---|---|
| `declared_types` | tipos declarados sem rota, com o nome e a contagem |
| `title_patterns` | padrões candidatos das issues sem tipo, com contagem |
| `not_a_type` | padrões já declarados como não sendo tipo, com quem decidiu |
| `total_unpromoted` | quanto do total ainda não tem conceito (FR-034) |

**`title_patterns` traz `likely_type`**, vindo do catálogo: `[TASK]` e `[US]` provavelmente são
tipo; `[Devops]` e `[QA]` provavelmente não. A tela usa isso para separar as duas listas —
sugerir "crie regra para `[Devops]`" empurraria alguém a mapear área como tipo, e o produto
ganharia 340 user stories que são rótulos de equipe (FR-031).

---

## `TheBand.Mapping.PatternValidator` — a validação, isolada

### `validate(how, pattern, sample) :: :ok | {:error, motivo}`

Função pura, sem banco. `sample` são títulos reais da organização: uma expressão rápida em
`"abc"` pode ser lenta no título de 200 caracteres que o time escreve.

Usa `Regex.compile/2`, **nunca** `Regex.compile!/2` — erro previsto é retorno, não exceção
(princípio VIII).

O limite de tempo é medido com `Task.await/2`: `:re` não tem limite de passos, e uma expressão
com quantificadores aninhados sobre título longo pode custar segundos. Avaliar numa `Task` dá a
resposta sem prender o processo da tela.

---

## `TheBand.WorkItems.Routing` — a mudança

### `decide(issue, opts) :: map()`

Ganha uma **segunda etapa**, e a ordem é a regra:

```text
1. tipo declarado  → regra da organização, depois tenant, depois global
2. título, SE a etapa 1 não decidiu → regra da organização apenas
```

FR-008 exige que tipo declarado vença regra de título, e a única forma de garantir isso é **não
chegar** à etapa 2 quando a etapa 1 decidiu. Avaliar as duas e escolher depois deixaria a
precedência dependente da ordem de comparação.

O retorno ganha `evidence_source` (`declared_type` | `title`), `confidence` (`high` | `medium`)
e `mapping_rule_id`.

**Regra de título não existe em YAML global.** O catálogo propõe padrões de título, mas eles só
valem depois de ativados por organização — e ativados, vivem no banco. Isso mantém a inferência
sobre texto livre sempre como **decisão declarada de alguém**, nunca como padrão da plataforma.

---

## O que este contrato deliberadamente **não** declara

| Função ausente | Por quê |
|---|---|
| `create_rule/3` sem `actor` | regra sem autor não tem a quem perguntar por quê |
| `delete_rule/2` | desativar preserva a proveniência das promoções |
| `apply_rule_now/2` síncrono | dois caminhos, e o raro é o que quebra |
| `infer_rules_automatically/2` | inferência sobre texto livre é decisão de pessoa, sempre |
| `promote_by_label/2` | rótulo não é tipo; é o antipadrão do princípio I |
| qualquer função em `tool_concept_mappings` | substituída por esta feature (FR-036) |
