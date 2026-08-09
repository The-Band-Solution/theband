# Modelo de dados — Fase 1

**Feature**: 001 — Coleta de pessoas e equipes do GitHub para a Enterprise Ontology
**Data**: 2026-08-09
**Depende de**: [plan.md](plan.md) · [research.md](research.md) · [ADR 0004](../../docs/adr/0004-modelo-de-informacao-one-table-per-kind.md)

As tabelas se dividem em três grupos com origens distintas, e a distinção
importa: o grupo ontológico é **derivado** da base de conhecimento e não pode ser
editado à mão (ADR 0004, D4); os outros dois são de plataforma e de coleta, e são
escritos como qualquer tabela de aplicação.

## Convenções obrigatórias

Da constituição, princípios III e V — valem para toda tabela abaixo salvo onde
indicado.

| Coluna | Onde se aplica | Papel |
|---|---|---|
| `id` | todas | chave primária, `uuid` v4 |
| `tenant_id` | todas as de domínio e de coleta | fronteira de isolamento; toda query a recebe explicitamente |
| `internal_id` | todas as de domínio | identidade estável entre módulos ontológicos |
| `record_version` | todas as de domínio | detecção de dessincronização |
| `source_system`, `source_instance`, `external_id`, `collected_at` | todas alimentadas por fonte externa | Application Reference; registro sem ela é inválido, não incompleto |
| `inserted_at`, `updated_at` | todas | timestamps |

**Índice de idempotência**, em toda tabela alimentada por fonte externa:

```text
unique_index(:tabela, [:tenant_id, :source_system, :source_instance, :external_id])
```

É ele que sustenta FR-014 e SC-003 — a segunda sincronização não cria nada. O
upsert resolve por essa quádrupla, nunca por nome ou login.

---

## Grupo 1 — Ontologia EO (derivado)

Saída de `derive_information_model.py --ontology eo`, que aplica `one table per
kind`: 10 conceitos produzem 6 tabelas. Não editar à mão — corrigir na base de
conhecimento e regerar.

### Tabelas que esta feature cria

| Tabela | Conceito | Estereótipo | Colunas próprias |
|---|---|---|---|
| `eo_organizations` | `eo.organization` | kind | `parent_organization_id` (uuid, NULL, FK parthood), `name` |
| `eo_people` | `eo.person` | kind | `name` (NOT NULL), `email` (NULL) |
| `eo_teams` | `eo.team` | kind | `type` enum NOT NULL `{organizational_team, project_team}`, `name`, `slug`, `external_created_at` |

`eo.organizational_team` e `eo.project_team` **não** ganham tabela: são
`subkind`, absorvidos em `eo_teams.type`. Esta feature grava sempre
`organizational_team`, conforme o mapeamento
[`github.team.to.eo.organizational_team`](../../priv/knowledge_base/mappings/github/eo/team.yaml) —
os times observados têm zero repositórios e zero projetos, e nome coincidente não
basta para promover a equipe de projeto.

`eo.team_member` **não** vira coluna nem tabela: é `role`, absorvido em
`eo_people`, e materializa pelo relator (ADR 0004, D5/D6).

### Tabelas do modelo derivado que esta feature NÃO popula

| Tabela | Por que fica vazia |
|---|---|
| `eo_organizational_roles` | catálogo de papéis; o GitHub não fornece papel organizacional. Criada pela migração, sem linhas |
| `eo_team_memberships` | o relator exige pessoa **e** equipe **e** papel. Sem o terceiro, não se grava |
| `eo_sectors` | setor não existe na API do GitHub |

Criar a tabela vazia é deliberado: o esquema é derivado da ontologia inteira, e
omitir tabela porque a primeira fonte não a alimenta faria a próxima fonte exigir
migração. `eo_organizational_roles` e `eo_team_memberships` são o destino da
promoção prevista, e a coluna que liga uma à outra já existe desde já.

### Distinção que o esquema precisa preservar

`eo.person` é a identidade; ser membro de equipe é papel, e o papel vive no
relator com equipe, papel e período. Uma coluna `team_id` em `eo_people` seria a
violação óbvia — impossibilitaria a pessoa em várias equipes e apagaria a
temporalidade. Não existe.

---

## Grupo 2 — Evidência de vínculo observado

### `eo_team_membership_evidence`

Materializa `observed_link` da regra
[`github.team_membership_evidence`](../../priv/knowledge_base/rules/github_team_membership_evidence.yaml).
O nome vem de `persisted_as` na regra — ver D-1 no [plan.md](plan.md), que
substitui o `eo_observed_team_links` proposto em R7.

| Coluna | Tipo | Nulo | Origem / papel |
|---|---|---|---|
| `person_id` | uuid | NOT NULL | FK → `eo_people` |
| `team_id` | uuid | NOT NULL | FK → `eo_teams` |
| `person_external_id` | string | NOT NULL | `team.members.node.id` — rastreabilidade antes de resolver a chave interna |
| `team_external_id` | string | NOT NULL | `organization.teams.nodes.id` |
| `platform_access_level` | enum | NOT NULL | `MAINTAINER` \| `MEMBER`. **Nível de acesso na plataforma, não papel organizacional** |
| `observed_at` | utc_datetime | NOT NULL | primeira observação |
| `last_observed_at` | utc_datetime | NOT NULL | última coleta em que apareceu |
| `no_longer_observed_at` | utc_datetime | NULL | preenchido quando some da origem; **nada é apagado** |
| `promoted_membership_id` | uuid | NULL | FK → `eo_team_memberships`; preenchido na promoção futura |

`unique_index([:tenant_id, :source_system, :source_instance, :person_external_id, :team_external_id])`.

**A restrição semântica que o código precisa impor**: `platform_access_level`
MUST NOT ser convertido em `eo_organizational_roles`. Promover `MAINTAINER` a
papel produziria um catálogo que não corresponde a função nenhuma, e faria as
perguntas de competência CQ12, CQ14 e CQ16 devolverem resposta falsa em vez de
nenhuma. Vive em `lib/the_band/ontology/seon/eo/constraints/`.

**Métrica de lacuna (FR-021, SC-010)**: contagem de linhas com
`promoted_membership_id` nulo. É informação sobre o quanto da estrutura
organizacional o sistema ainda não conhece — não é erro, e a tela a apresenta
como número, não como alerta.

### Conta de automação (FR-022)

`eo_people.account_type` enum `{person, bot, app}`, derivado de `__typename` e do
tipo da conta no GitHub. Conta classificada como `bot` ou `app` é registrada e
**não conta como pessoa** em nenhuma contagem apresentada. Não é filtro de
exibição: é classificação persistida, porque descartar a conta perderia o vínculo
com a equipe onde ela aparece.

---

## Grupo 3 — Plataforma e coleta

Nenhuma destas é derivada da ontologia: descrevem a operação da plataforma, não o
domínio observado.

### `tenants`

Organização cliente. A fronteira de isolamento (FR-001). Sem `tenant_id` próprio
— ela **é** o tenant.

`name`, `slug` único, `status`.

### `users` e perfil

Usuário da plataforma, ligado a um tenant. `role` enum `{admin, member}` —
somente `admin` conecta ferramenta e gerencia credencial (Assumptions da spec).
Modelo de permissões mais rico fica para depois.

### `connected_tools`

Declaração de que um tenant usa uma ferramenta, numa instância (FR-002, FR-003).

| Coluna | Tipo | Papel |
|---|---|---|
| `tool_type` | enum | `github` nesta entrega. Enum e não string livre, para que a ferramenta nova seja migração declarada e não dado solto |
| `instance_url` | string | serviço público ou instalação própria |
| `status` | enum | `active` \| `needs_attention` \| `disabled` |
| `needs_attention_since`, `needs_attention_reason` | | FR-009: data e motivo da falha, sem afetar as demais ferramentas do tenant |

`unique_index([:tenant_id, :tool_type, :instance_url])`.

### `tool_credentials`

Mais de uma por ferramenta, ativáveis independentemente (FR-004).

| Coluna | Tipo | Papel |
|---|---|---|
| `secret` | binary | cifrado pelo `Ecto.Type` do Cloak — AES-GCM 256. A cifragem acontece no tipo, não no código de aplicação, o que remove a possibilidade de gravar em claro por esquecimento (R3) |
| `last_four` | string(4) | os quatro últimos caracteres em claro, só para distinguir uma credencial da outra (FR-007). Quatro caracteres não reduzem materialmente o espaço de busca de um token de 40 |
| `label` | string | nome dado pela pessoa |
| `active` | boolean | |
| `validated_at` | utc_datetime | FR-006: validada contra a ferramenta no cadastro; sem isso não se grava |
| `last_failure_at`, `last_failure_reason` | | histórico de falha |

**Nunca em log, nunca em relatório de erro, nunca em dado coletado** (FR-008). O
`Inspect` do schema é derivado com `except: [:secret]`, e o campo é redigido
antes de qualquer telemetria.

**Chave mestra** vem de variável de ambiente. `TheBand.Application` recusa o boot
se ausente (FR-005a) — subir sem chave gravaria credencial desprotegida e ninguém
perceberia. A rotação (FR-005b) usa múltiplas chaves rotuladas do Cloak: incluir
a nova como padrão, manter a antiga para leitura, recifrar em background, remover
a antiga. Exposta como Mix task.

### `syncs`

Uma execução de coleta.

`connected_tool_id`, `credential_id` (qual credencial foi usada — credenciais
diferentes enxergam conjuntos diferentes), `started_at`, `finished_at`, `status`
enum `{running, completed, failed, interrupted}`, e o relatório de FR-028:
`records_collected`, `records_created`, `records_updated`, `records_skipped`,
`skip_reasons` (jsonb), `memberships_pending_role`.

**Uma por ferramenta de cada vez** (FR-018): índice único parcial sobre
`connected_tool_id` onde `status = 'running'`, mais `unique` do Oban no worker.
Duas defesas porque a corrida existe nos dois níveis — a segunda requisição HTTP
e o segundo job enfileirado.

### `sync_checkpoints`

R5. Registro por `(sync_id, entity_type)` com cursor opaco.

`cursor` (string, **opaca — não interpretar**), `page_count`, `record_count`,
`last_page_at`, `status`.

Gravado **depois** de processar a página, não antes: uma interrupção reprocessa
no máximo a última página, o que é seguro porque a ingestão é idempotente, e
atende SC-006.

### `raw_payloads`

FR-011 e FR-017. O conteúdo recebido, sem alteração.

`sync_id`, `raw_entity_type` (`github.organization`, `github.user`,
`github.team`, `github.team_member`), `external_id`, `payload` (jsonb),
`collected_at`, `mapping_id` e `mapping_version` aplicados.

Guardar o mapeamento aplicado é o que torna FR-017 verificável: reprocessar com
mapeamento corrigido lê daqui e não consulta o GitHub (SC-007).

---

## Relações entre os grupos

```text
tenants 1──n connected_tools 1──n tool_credentials
                   │
                   └──n syncs 1──n sync_checkpoints
                              1──n raw_payloads
                                      │ transformação pelos mapeamentos YAML
                                      ↓
                    eo_organizations   eo_people   eo_teams
                                          │           │
                                          └─ eo_team_membership_evidence ─┘
                                                      ┆ promoção futura
                                                      ↓
                                   eo_team_memberships ── eo_organizational_roles
```

A linha pontilhada é o que esta feature **não** faz. A coluna que a sustenta
existe desde já para que a promoção não exija migração de dados.

## Regras de validação, por requisito

| Requisito | Onde é imposto |
|---|---|
| FR-005 | `Ecto.Type` do Cloak — no tipo, não no changeset |
| FR-005a | `TheBand.Application`, no `start/2`, antes de qualquer supervisor |
| FR-006 | comando de cadastro chama a ferramenta antes de gravar; falha não grava nada (cenário 2 da US1) |
| FR-007 | schema sem getter do valor; só `last_four` sai do módulo |
| FR-012 | `NOT NULL` nas quatro colunas de proveniência, no banco — não só no changeset |
| FR-014 | `unique_index` da quádrupla + `on_conflict` comparando `record_version` |
| FR-018 | índice único parcial + `unique` do Oban |
| FR-019, FR-020 | constraint de módulo: `platform_access_level` não alcança `eo_organizational_roles` |
| FR-023 | `eo_teams.type` gravado como `organizational_team`; promoção exige vínculo efetivo ou declaração do tenant |
| FR-024 | `started_at` e `ended_at` de `eo_team_memberships` permanecem nulos — a API não informa quando a pessoa entrou |
| FR-025 | nenhuma unificação de contas: duas contas da mesma pessoa são duas linhas em `eo_people`, registrado como limitação conhecida |
| FR-027 | toda função de query recebe o tenant; teste com dois tenants povoados prova o isolamento (SC-008) |

## Transições de estado

**`connected_tools.status`**: `active` → `needs_attention` quando a credencial
falha (FR-009); volta a `active` quando uma credencial válida é cadastrada ou
revalidada. `disabled` é ato explícito da pessoa administradora.

**`syncs.status`**: `running` → `completed` \| `failed` \| `interrupted`.
`interrupted` preserva os checkpoints e é retomável; `failed` também preserva o
progresso parcial, e a diferença é só a causa. Credencial revogada no meio da
coleta leva a `interrupted` com a ferramenta marcada como precisando de atenção.

**`eo_team_membership_evidence`**: presente → ausente marca
`no_longer_observed_at` e nunca apaga. A plataforma não recebe evento de remoção;
percebe a ausência por comparação entre coletas.
