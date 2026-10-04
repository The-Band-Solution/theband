# Data model: análise de rede (076)

**Plano**: [plan.md](plan.md) · **Pesquisa**: [research.md](research.md)

Três mudanças de esquema e uma configuração. Nenhum conceito novo de ontologia: a aresta de
designação é **regra derivada, sem relator** (revisão semântica, A2), e a leitura é derivada, como a
da 073. Toda tabela nova leva `tenant_id NOT NULL` com FK composta para o dono da linha referenciada.

---

## 1. `network_analysis_readings` — a leitura vigente por organização, rede e janela

Migração `priv/repo/migrations/<ts>_create_network_analysis_readings.exs`, `change/0`, aditiva.

### 1.1 Colunas

| coluna | tipo | nulo | o que é |
|---|---|---|---|
| `id` | uuid | não | chave |
| `tenant_id` | uuid → `tenants`, `on_delete: :delete_all` | não | |
| `organization_id` | uuid, FK composta `(organization_id, tenant_id)` → `eo_organizations(id, tenant_id)`, `on_delete: :delete_all` | não | a organização **observada** (decisão R4 da 073) |
| `network` | text, `check (network in ('review', 'assignment'))` | não | a rede (`network.analysis.parameters.networks`) |
| `window_days` | integer, `check > 0` | não | 30, 90 ou 180 |
| `window_start`, `window_end` | utc_datetime, `check window_end > window_start` | não | |
| `computed_at` | utc_datetime | não | quando o cálculo gravou |
| `checked_at` | utc_datetime | não | a última vez que o job conferiu a impressão digital (R4); `>= computed_at` |
| `source_computed_at` | utc_datetime | sim | só `review`: o instante da leitura da 073 de onde vieram as arestas (R2) |
| `fingerprint` | text | não | SHA-256 hexadecimal das arestas canônicas e das versões da base |
| `edges` | jsonb | não | `[{"source", "target", "weight"}]`, dirigidas, ordenadas por (source, target); ids de pessoa |
| `exclusions` | jsonb | não | `{"pairs": n, "bot_or_app": n, "organization_account": n, "unlinked_person": n, "self": n, "issues": n, "issues_without_assignee": n}` — as chaves de `issues*` só em `assignment` |
| `people_without_edges` | integer `>= 0` | sim | pessoas `person` da organização sem aresta na janela; nulo quando não há aresta nenhuma (a ausência é da janela, e não zero) |
| `nodes` | jsonb | não | um objeto por pessoa com aresta (1.2) |
| `communities` | jsonb | não | `[{"index", "members": [ids], "internal_edges"}]`, numeradas por tamanho decrescente |
| `measures` | jsonb | não | medidas da rede (1.3) |
| `provenance` | jsonb | não | versões da base, semente, gerador, procedimento de sorteio, número de aleatórios, semente e iterações do layout, `account_type_unknown` (R13) |
| `inserted_at` | utc_datetime | não | |

**Índices e restrições**

- `unique_index [:tenant_id, :organization_id, :network, :window_days]`, nome
  `network_analysis_readings_vigente_index` — uma vigente; a substituição apaga só a da mesma rede (A21);
- `check` das contagens `>= 0` e `checked_at >= computed_at`;
- reaproveita `unique_index(:eo_organizations, [:id, :tenant_id])`, criado pela 073.

### 1.2 `nodes`, por pessoa

```json
{
  "id": "<person uuid>",
  "out_people": 3, "in_people": 2, "degree": 4,
  "out_weight": 9, "in_weight": 5,
  "degree_centrality": 0.08,
  "betweenness": {"value": 0.12} | {"absent": "network_too_small"},
  "closeness": {"value": 0.41} | {"absent": "no_reachable_person"},
  "distance_mean": {"value": 2.3, "reaches": 21} | {"absent": "no_reachable_person"},
  "eigenvector": {"value": 0.31} | {"absent": "did_not_converge"},
  "component": 1,
  "community": 2,
  "internal_degree": 3,
  "x": 412.5, "y": 133.0
}
```

`degree` é pessoas distintas na projeção sem direção (o par recíproco conta uma vez, FR-033);
`out_people` e `in_people` são por sentido. `x`/`y` ausentes acima do teto (R5). **Percentil e
papel não estão aqui** (R17).

### 1.3 `measures`, da rede

```json
{
  "people": 54, "undirected_edges": 120, "components": [40, 9, 3, 2],
  "average_distance": {"value": 2.6, "reachable_share": 0.71} | {"absent": "no_edge_in_window"},
  "diameter": {"value": 6} | {"absent": "..."},
  "global_efficiency": {"value": 0.46} | {"absent": "..."},
  "clustering": {"value": 0.52, "excluded_degree_below_two": 11} | {"absent": "no_person_with_two_neighbours"},
  "modularity": {"value": 0.61, "communities": 5} | {"absent": "no_edge_in_window"},
  "random": {
    "graphs": 100,
    "clustering": {"value": 0.13, "graphs_defined": 97},
    "average_distance": {"value": 2.9, "graphs_defined": 100, "reachable_share": 0.64},
    "diameter": {"value": 6.1}, "global_efficiency": {"value": 0.40},
    "modularity": {"value": 0.38, "graphs_defined": 100}
  } | {"absent": "network_too_large_for_platform"},
  "sigma": {"value": 3.7} | {"absent": "network_too_small" | "random_clustering_undefined" | "clustering_undefined" | "no_edge_in_window" | "network_too_large_for_platform"}
}
```

Toda ausência é `{"absent": motivo}`, com o motivo da base, e nunca 0, 0,01 ou infinito (FR-050).
`reachable_share` dos aleatórios grava a A6 da revisão 2.

### 1.4 Ciclo de vida

```text
(nenhuma) ──compute──▶ vigente ──compute, impressão igual──▶ vigente (checked_at avança)
                         │
                         ├──compute, impressão diferente──▶ substituída (apagada) + nova vigente
                         ├──end_observation da organização──▶ apagada (R18)
                         └──computed_at > 180 dias──▶ ainda gravada, NÃO mostrada ({:ausente, :stale})
```

## 2. `organization_account_declarations` — a conta da organização, declarada (R14)

Migração `<ts>_create_organization_account_declarations.exs`, `change/0`. Schema privado de
`TheBand.Tenants.Access`, como `ScopeGrant`.

| coluna | tipo | nulo | o que é |
|---|---|---|---|
| `id` | uuid | não | |
| `tenant_id` | uuid → `tenants`, `on_delete: :delete_all` | não | |
| `person_id` | uuid, FK composta `(person_id, tenant_id)` → `eo_people(id, tenant_id)`, `on_delete: :delete_all` | não | a conta declarada |
| `reason` | text, `check (length(trim(reason)) > 0)` | não | por que é da organização |
| `declared_by_user_id` | uuid → `users`, `on_delete: :nilify_all` | sim | quem declarou (nulo se a conta for apagada depois) |
| `declared_at` | utc_datetime | não | |
| `revoked_by_user_id` | uuid → `users`, `on_delete: :nilify_all` | sim | |
| `revoked_at` | utc_datetime | sim | revogação; a linha nunca é apagada |

- `unique_index(:eo_people, [:id, :tenant_id])` nasce aqui, para a FK composta (precedente da 073);
- `unique_index [:tenant_id, :person_id] where revoked_at is null` — uma declaração vigente por pessoa;
- `check (revoked_at is null or revoked_at >= declared_at)`.

**Ciclo**: `vigente` (revoked_at nulo) → `revogada`. Declarar de novo cria linha nova.

## 3. O tipo da conta na coleta de issues (R13, A3)

Migração `<ts>_add_account_type_to_issue_people.exs`, `change/0`:

| tabela | coluna nova | tipo |
|---|---|---|
| `collected_issues` | `author_account_type` | text anulável, `check in ('person','bot','app')` |
| `issue_assignees` | `account_type` | text anulável, `check in ('person','bot','app')` |

Migração de dados `<ts>_backfill_issue_account_types.exs`, `up/0` com `execute/1` que preenche a
partir do payload bruto mais recente por `(tenant_id, external_id)` de `raw_payloads` com
`raw_entity_type = 'github.issue'` (`Bot` → `bot`, `App` → `app`, demais → `person`, login com
sufixo `[bot]` → `bot`, a mesma regra de `Mapper.account_type/1`); `down/0` explícito que anula as
duas colunas. Os responsáveis casam pelo `login` dentro do payload da mesma issue.

## 4. (A7, opção padrão) `review_network_readings.excluded_organization_account`

Migração `<ts>_add_organization_account_to_review_network_readings.exs`, `change/0`: inteiro
**anulável**, `check (excluded_organization_account is null or excluded_organization_account >= 0)`.
Nulo nas leituras da versão 1 de `review.network.edge`, que não avaliavam o motivo. Só entra se a
pessoa mantenedora confirmar a A7 (T002).

## 5. Configuração

`config/config.exs`, `queues:` ganha `network_analysis: 1` (R4). `config/test.exs` mantém
`testing: :manual`.

## 6. O que não muda

`review_network_readings` (salvo o item 4), `eo_people.account_type`, o schema de medidas, nenhum
índice em `collected_issues` (46,8 ms medidos sem índice novo, R20 — se a #1190 mostrar outro
volume, o índice `(tenant_id, external_created_at)` entra em tarefa própria).
