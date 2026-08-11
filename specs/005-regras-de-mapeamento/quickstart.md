# Quickstart — Feature 005: regras de mapeamento por organização

Doze verificações. Os números vêm do **dado real**, medidos no banco de desenvolvimento em
2026-08-11:

```text
4463 issues coletadas
1020 promovidas
3406 sem tipo na origem          →  type_absent
  37 com tipo desconhecido       →  type_unknown  (Chore 17, Refactor 16, Hotfix 4)
```

Prefixos das issues sem conceito, medidos agora:

| provavelmente **é** tipo | | provavelmente **não é** tipo | |
|---|---:|---|---:|
| `[TASK]` | 1031 | `[Devops]` | 340 |
| `[FEATURE]` | 111 | `[Back-end]` | 262 |
| `[US]` | 60 | `[Front-end]` | 243 |
| `[FIX]` | 58 | `[Dados]` | 188 |
| `[BUG]` | 51 | `[QA]` | 97 |
| `[EPIC]` | 33 | `[Backend]` | 57 |

**Cerca de 1344 issues são resgatáveis; cerca de 1187 têm prefixo de área.** A segunda coluna é
a razão de existir a decisão "não é tipo": sugerir regra para `[Devops]` daria ao produto 340
user stories que são rótulos de equipe.

## Pré-requisitos

```bash
docker compose up -d
export THE_BAND_MASTER_KEY=...
mix ecto.migrate
mix phx.server                    # localhost:4000
```

---

## V1 — A regra exige autor

```bash
mix test test/the_band/mapping/rules_test.exs -o "exige autor"
```

**Esperado**: não existe caminho que grave regra sem `actor`. A obrigatoriedade está **na
assinatura** — como em `mark_issues_no_longer_observed/3`, onde o escopo é obrigatório no tipo.

**Por que**: mapeamento é decisão. Regra sem autor não tem a quem perguntar "por que isto é uma
user story".

---

## V2 — As três recusas de expressão

```bash
mix test test/the_band/mapping/pattern_validator_test.exs
```

**Esperado**, cada uma com o que a pessoa precisa para corrigir:

| Entrada | Recusa |
|---|---|
| `"[US"` | não compila, com a **posição** do erro |
| `".*"` | casa string vazia — casaria todas as 4463 issues |
| `"(a+)+$"` sobre título longo | excede o limite de tempo, e o limite é dito em ms |

**Nenhuma das três é gravada** — SC-006. E a validação usa `Regex.compile/2`, nunca
`compile!/2`: erro previsto é retorno.

---

## V3 — `começa com` não é `contém`

```bash
mix test test/the_band/mapping/rules_test.exs -o "começa com"
```

**Esperado**: `starts_with "[TASK]"` casa as 1031 issues cujo título **começa** com o texto.
Uma regra `contains "US"` casaria também `"STATUS"` — e é por isso que a forma de comparação é
declarada, e não inferida.

---

## V4 — Tipo declarado vence regra de título

```bash
mix test test/the_band/work_items/routing_test.exs -o "tipo declarado vence"
```

**Esperado**: uma issue com tipo `Task` e título `[FEATURE] alguma coisa` é promovida a
**tarefa**. A regra de título **não é avaliada** — a etapa 2 não é alcançada.

**Se falhar**: a precedência passou a depender da ordem de comparação, e o SC-003 caiu.

---

## V5 — A prévia bate com o efeito

```bash
mix test test/the_band/mapping/preview_test.exs -o "prévia bate com o recálculo"
```

**Esperado**: `preview/3` devolve `would_change: N`, e o recálculo grava exatamente N promoções
novas. **A diferença é zero** — SC-007.

**Por que este é o teste que mais importa**: prévia e efeito por caminhos diferentes é o defeito
que faz alguém aprovar uma regra vendo 3 e reclassificar 900.

---

## V6 — `matched` e `would_change` são números diferentes

Na tela, crie uma regra `starts_with "[TASK]"` para uma organização que já tenha issues
promovidas por tipo declarado.

**Esperado**: `matched` maior que `would_change`. Uma regra que casa 1031 e muda 1031 é muito
diferente de uma que casa 1031 e muda 3, e mostrar só o primeiro número esconderia isso.

---

## V7 — Gravar regra não consulta a origem

**Esperado**: nenhuma requisição à API do GitHub ao gravar, prever ou recalcular — SC-008. Os
payloads estão preservados desde a feature 004, e a promoção é recalculável a partir do que já
está no banco.

---

## V8 — O recálculo é idempotente

```bash
mix test test/the_band/mapping/recompute_test.exs -o "duas vezes"
```

**Esperado**: executar duas vezes sobre o mesmo estado **não** produz linha nova. O recálculo
compara com a decisão vigente e só grava quando diferem — FR-027, SC-009.

---

## V9 — A confiança distingue as duas origens

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select evidence_source, confidence, count(*) from issue_promotions
 where derived_concept is not null group by 1,2 order by 3 desc;"
```

**Esperado**: `declared_type | high` para as decisões por tipo, `title | medium` para as por
inferência, e `(null) | (null)` para as 1020 promoções da feature 004 — que **não** são
retrofitadas, porque preencher retroativamente afirmaria algo que ninguém verificou.

---

## V10 — O catálogo chega proposto, e não promove nada

Conecte uma organização nova e abra a tela de regras **sem** ativar nada.

**Esperado**: as propostas do catálogo aparecem com `would_match` preenchido e **nenhuma issue
promovida por elas**. A organização não tem linha em `issue_mapping_rules` até alguém decidir —
FR-039, FR-043.

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) from issue_mapping_rules where organization_id = '<id>';"
```

**Esperado**: `0`. Copiar o catálogo na conexão criaria 18 linhas com autor "sistema", contra
FR-041.

---

## V11 — Reordenar o catálogo não desliga decisões

Troque a ordem de duas entradas em
`priv/knowledge_base/rules/github_issue_pattern_catalog.yaml`, reinicie e reabra a tela.

**Esperado**: as regras ativadas continuam ativadas, e continuam marcadas como **editada** ou
**ativada**. A chave é `(where, how, pattern)` normalizado — usar o índice da lista faria a
reordenação desligar decisões já tomadas.

---

## V12 — "Não é tipo" tira o padrão da pendência sem mapear

Na tela, marque `[Devops]` como **não é tipo**.

**Esperado**: as 340 issues saem da lista de pendências e passam a aparecer como ausência
**declarada**, com quem decidiu e quando. Nenhuma delas é promovida a nada.

**E é reversível**: reverter devolve o padrão à lista, e o registro de quem decidiu o quê
permanece — FR-032.

---

## Os nove gates

```bash
mix gates
```

**Esperado**: `9 gates verdes`, e código de saída zero.
