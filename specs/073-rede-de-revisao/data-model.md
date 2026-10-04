# Modelo de dados da 073 — rede de revisão

**Plano**: [plan.md](plan.md) · **Pesquisa**: [research.md](research.md) · **Contratos**: [contracts/](contracts/)

Três partes: a tabela nova e o índice (o que se grava), as estruturas em memória (o que se
calcula), e a base de conhecimento (o que se declara). **O texto dos YAMLs não está aqui**: a fonte
é [`proposta-base/`](proposta-base/), escrita em paralelo. Este documento diz só o que o código
exige deles.

---

## 1. O que se grava

### 1.1 `review_network_readings` — a leitura vigente

Uma linha por `(tenant, organização observada, janela)`. Substituída, nunca editada (FR-011).

| coluna | tipo | nulo | o que é |
|---|---|---|---|
| `id` | `uuid` PK | não | gerado na inserção; é o que o aviso de leitura pronta carrega |
| `tenant_id` | `uuid` → `tenants`, `on_delete: :delete_all` | não | R7 da segurança: a leitura é derivada e não sobrevive ao tenant |
| `organization_id` | `uuid`, FK composta `(organization_id, tenant_id)` → `eo_organizations(id, tenant_id)`, `on_delete: :delete_all` | não | a organização observada (R4). A FK composta impede a linha com organização de um tenant e `tenant_id` de outro |
| `window_days` | `integer` | não | 30, 90 ou 180; `check (window_days > 0)` no banco, lista fechada **no domínio** (R9) |
| `window_start` | `utc_datetime` | não | início da janela, inclusivo |
| `window_end` | `utc_datetime` | não | fim, exclusivo; é o instante do cálculo truncado ao segundo |
| `computed_at` | `utc_datetime` | não | quando o cálculo terminou |
| `edges` | `jsonb` | não | `[{"reviewer": uuid, "author": uuid, "change_requests": int ≥ 1}]`, ordenado por `{reviewer, author}` |
| `people` | `jsonb` | não | `[{"id": uuid, "received_change_requests": int ≥ 1 \| null}]`: toda pessoa da lista (US2), com o único número que não se deriva das arestas. `null` é *"nenhuma solicitação dela revisada"*, nunca 0 |
| `reviews_in_network` | `integer` | não | soma dos pesos; redundante com `edges`, e existe para o `check` do invariante e para a proveniência legível sem abrir o JSON |
| `excluded_self_review` | `integer` | não | auto-revisões (pares) |
| `excluded_bot_or_app` | `integer` | não | pares com bot ou aplicativo em algum lado |
| `excluded_unlinked` | `integer` | não | pares com conta sem pessoa ligada em algum lado |
| `knowledge_versions` | `jsonb` | não | `{"review.network.edge": 1, "review.network.parameters": 1, "<id de cada medida de review.concentration>": 1, ...}`: as duas regras e as nove medidas (FR-011) |
| `inserted_at` | `utc_datetime` | não | `timestamps(updated_at: false)`: a linha não é editada |

**Índices e restrições**:

- `unique_index [:tenant_id, :organization_id, :window_days]`: **uma** vigente (R7 da segurança);
- `unique_index(:eo_organizations, [:id, :tenant_id])`, criado na mesma migração, só para a FK
  composta poder existir. Redundante com a PK, e o Postgres o exige (precedente:
  `priv/repo/migrations/20260929100000_sessoes_de_usuario.exs:13-17`, `:35`);
- `check (reviews_in_network >= 0 and excluded_self_review >= 0 and excluded_bot_or_app >= 0 and
  excluded_unlinked >= 0)`;
- `check (window_end > window_start)`.

**O que não está, e por quê** (`AGENTS.md` §7.3, *"quando couberem"*):

| coluna da casa | por que não |
|---|---|
| `internal_id`, `record_version` | a leitura não é conceito de domínio com identidade entre módulos, e não tem versões: é substituída inteira. Precedente: `eo_person_profiles`, leitura derivada, sem as duas |
| `source_system`, `source_instance`, `external_id`, `collected_at` | não é alimentada por fonte externa. A proveniência dela é a janela, o instante e as versões da base (FR-011) |
| `updated_at` | nunca editada |
| nome, login, id de solicitação | R3, R7 e R9 da segurança: nome se resolve na leitura; quem revisou qual solicitação não se guarda |
| grupos, concentração | função pura de `edges` e do alcance de quem lê ([research.md R7](research.md#r7--a-leitura-materializada-uma-por-organização-e-janela)) |

**Quem apaga**: só o cálculo, ao substituir, e a cascata do tenant ou da organização. Nenhuma tela
apaga ou edita.

**Migração reversível**: `change/0` com `create table`, `create unique_index` e `create
constraint`; o rollback desfaz os três e o índice de `eo_organizations`. Nenhum `execute/1`.

### 1.2 Índice novo em `collected_artifact_evaluations`

`create index(:collected_artifact_evaluations, [:tenant_id, :external_submitted_at])`, na mesma
migração. Razão e medida em [research.md R10](research.md#r10--índice-e-volume).

---

## 2. O que se calcula, em memória

### 2.1 Par classificado — a entrada do cálculo

Uma linha por **(conta revisora, solicitação)** com avaliação contável na janela mais larga (180
dias). Vem de `Quality.review_pairs/3`, classificada por `ReviewNetwork` com `EO.account_types/2`
e `Mapper.account_type/1`:

```text
%{change_request_id, last_submitted_at,
  destino: {:aresta, revisor_id, autor_id} | :self_review | :bot_or_app | :unlinked_person}
```

Os logins usados para classificar a conta não ligada **não saem** desta etapa: nem para a tabela,
nem para o log, nem para a leitura. As três janelas saem desta lista por filtro sobre
`last_submitted_at >= window_start` (as janelas são aninhadas e terminam no mesmo instante, então
um par está na janela W se o envio mais recente dele está em W).

**Regras de classificação** (ordem e razão em [research.md R3](research.md#r3--quais-avaliações-contam-e-a-ordem-das-exclusões)):
bot ou aplicativo → não ligada → auto-revisão → aresta. Cada par cai em **um** destino.

**Invariante**: `pares da janela = reviews_in_network + excluded_self_review + excluded_bot_or_app + excluded_unlinked`.

### 2.2 A visão recortada — o que `ReviewNetwork.read/4` devolve

Calculada **a cada leitura**, a partir da linha vigente e do alcance de quem lê. Forma exata em
[contracts/review-network.md](contracts/review-network.md#read4).

| campo | sobre qual população | de onde |
|---|---|---|
| total de revisões, revisores, pessoas revisadas (`authors`, D10) | **subgrafo induzido** pelas pessoas alcançadas (arestas com as duas pontas alcançadas) | `edges` |
| concentração k = 1, 2, 3 | o mesmo subgrafo (decisão R1 de 2026-10-03); ausente abaixo de 10 **revisões** do recorte, e ausente no k maior que o número de revisores | `edges` + `minimum_sample` |
| lista por pessoa, ordenada por nome | pessoas alcançadas da lista | `people` + `edges` + `EO.people_names/2` |
| totais de uma pessoa | **a rede inteira**: o total é fato sobre ela (R2 da segurança, item 1) | `edges` + `people` |
| pares de uma pessoa | só pares alcançados; os de fora não viram linha nem número | `edges` |
| grupos | componentes fracos do **mesmo subgrafo** (Q4, decidido em 2026-10-03): com alcance parcial, só entre pessoas alcançadas | `edges` |
| coleta mais nova que a leitura | o maior `changes_collected_at` dos repositórios observados da organização, contra `computed_at` (Q3) | `CMPO.list_observed/2` |
| pessoas sem atividade na janela | pessoas `person` da organização, **alcançadas**, fora da lista | `EO.organization_person_ids/2` |
| exclusões, as três, bot inclusive | só com alcance total (Q5; [research.md R12](research.md#r12--o-que-a-tela-de-alcance-parcial-mostra-das-exclusões)) | colunas `excluded_*` |

### 2.3 Estados de ausência

Toda medida sem valor é `{:ausente, motivo}` (FR-009), e o motivo diz de quem é a ausência. Tabela
completa em [research.md R14](research.md#r14--ausências-o-que-a-leitura-devolve-quando-não-há-o-que-mostrar).
Nenhuma função devolve 0 no lugar de ausência, nem valor de reserva quando o cálculo falha.

---

## 3. O que se declara na base

**Fonte do conteúdo**: `priv/knowledge_base/`, desde a T004 (2026-10-03), depois da revisão
semântica ([revisao-semantica.md](revisao-semantica.md)). Este documento diz o que o código **exige**
de cada artefato; `ReviewNetwork.Parameters` levanta na carga quando falta, e
`test/the_band/review_network/parameters_test.exs` lê a base real.

### Necessidade de informação

`review.concentration` (`information_needs/review_concentration.yaml`): `required_concepts` com
`qapo.artifact_evaluation`, `cmpo.change_request` e `eo.person`; `candidate_measurements` com as
**nove** medidas abaixo. O código lê a lista para gravar a versão de cada uma.

### Medidas

**Nove**, todas com `answers_information_need: [review.concentration]`, `limitations`,
`misinterpretations` (as quatro mínimas da FR-007) e `version: 1` (campo opcional acrescentado ao
schema na T004).

| id | `value_type` | `unit` | o que conta |
|---|---|---|---|
| `review.network.reviews_given.count` | `count` | `reviews` | revisões feitas pela pessoa (soma dos pesos das arestas que saem), e de quantas pessoas |
| `review.network.reviews_received.count` | `count` | `change_requests` | solicitações distintas da pessoa com revisão contável, e por quantas pessoas |
| `review.network.unconnected_groups.count` | `count` | `groups` | componentes fracamente conexos do recorte; o tamanho de cada é em pessoas |
| `review.network.concentration.top_k_share` | `percentage` | `percent` | soma das k maiores revisões feitas ÷ revisões do recorte; o contrato transporta os dois inteiros |
| `review.network.reviews.count` | `count` | `reviews` | pares revisor–solicitação do recorte |
| `review.network.reviewers.count` | `count` | `people` | pessoas que revisaram, no recorte |
| `review.network.authors_reviewed.count` | `count` | `people` | pessoas revisadas, no recorte (D10) |
| `review.network.people_without_activity.count` | `count` | `people` | pessoas `person` alcançadas da organização, sem revisão nem solicitação na janela |
| `review.network.excluded.count` | `count` | `reviews` | pares deixados fora, por motivo |

A limitação obrigatória da concentração: **uma solicitação com dois revisores conta duas revisões**.

### Regra da aresta, `review.network.edge` (FR-005)

`rules/review_network_edge.yaml`. O código lê, e levanta se faltar:

- `version`;
- `rules.counted_states.values.states`: os estados que contam, por lista de inclusão;
- `rules.exclusions.values.order`: **conferida** contra a ordem que `Classification` implementa
  (`bot_or_app`, `unlinked_person`, `self_review`); outra ordem levanta.

`semantics.equivalence` (`derived`), a justificativa, as limitações e a categoria UFO (relação
derivada, sem relator) estão lá, e não são lidos pelo código.

### Regra dos parâmetros, `review.network.parameters` (FR-008, FR-013)

`rules/review_network_parameters.yaml`. O código lê, e levanta se faltar:

- `version`;
- `rules.window_days.values.allowed` ([30, 90, 180]) e `.default` (90, pertence à lista);
- `rules.k_values.values.k`: lista crescente de inteiros positivos ([1, 2, 3]);
- `rules.min_reviews.values.min_reviews`: 10 **revisões**, na unidade par revisor–solicitação.

`rules.min_group_size_shown` (3) está declarado e **não** é lido nesta fatia: com a Q4 os grupos são
do recorte.
