# Data model — 070, o operador da plataforma

As decisões e as alternativas estão em [research.md](research.md). Aqui ficam as tabelas, as
constraints e as transições.

**Estas tabelas não são de domínio.** Não têm `internal_id` nem `record_version`, como
`user_sessions` e `api_access_tokens` também não têm: não são registro ontológico, são
infraestrutura de acesso. E três delas **não têm `tenant_id`**, porque o operador não pertence a
organização nenhuma (FR-011). Isso é a exceção que a spec decidiu, e ela fica confinada ao módulo
`TheBand.Platform`: nenhuma função de domínio recebe estas structs.

---

## 1. `platform_operators` — o operador

| coluna | tipo | regra |
|---|---|---|
| `id` | uuid, PK | `gen_random_uuid()` |
| `email` | string, not null | índice único sobre `lower(email)` |
| `name` | string, not null | |
| `password_hash` | string, null | **nulo até a definição**; `redact: true` no schema |
| `password_epoch` | integer, not null, default 0 | sobe atômico a cada definição, como `user.ex:221-233` |
| `setup_code_hash` | bytea, null | `sha256` do código de definição; `redact: true` |
| `setup_code_expires_at` | utc_datetime, null | |
| `failed_attempts` | integer, not null, default 0 | espera crescente (research R2) |
| `last_failed_at` | utc_datetime, null | |
| `logged_in_at` | utc_datetime, null | |
| `inserted_at`, `updated_at` | utc_datetime | |

Constraints:

- `CHECK ((setup_code_hash IS NULL) = (setup_code_expires_at IS NULL))`;
- índice único `platform_operators_email_index` sobre `lower(email)`.

O e-mail **pode** coincidir com o de uma conta em `users`: são entradas diferentes, por formulários
diferentes, e nenhum resolvedor lê as duas tabelas. A reutilização de senha entre as duas não é
detectável sem ler um hash com a senha do outro, e fica como risco residual.

## 2. `platform_operator_grants` — a concessão, relator e não booleano

| coluna | tipo | regra |
|---|---|---|
| `id` | uuid, PK | |
| `operator_id` | uuid, FK `platform_operators`, `on_delete: :restrict`, not null | |
| `granted_at` | utc_datetime, not null | |
| `granted_via` | string, not null | `CHECK (granted_via = 'release_command')` |
| `granted_by_declared` | text, not null | **declarado** por quem rodou o comando, e não autenticado (O11) |
| `revoked_at` | utc_datetime, null | |
| `revoked_via` | string, null | `CHECK (revoked_via IS NULL OR revoked_via = 'release_command')` |
| `revoked_by_declared` | text, null | |
| `revoke_note` | text, null | |
| `inserted_at` | utc_datetime | sem `updated_at`: a única alteração é a revogação, que tem a própria data |

Constraints:

- índice único parcial `platform_operator_grants_vigente_index` sobre `operator_id`
  `WHERE revoked_at IS NULL`: uma concessão vigente por operador, na forma de
  `access_scope_grants` (`20260828160856_access_scope_grants.exs:39`);
- `CHECK ((revoked_at IS NULL) = (revoked_via IS NULL) AND (revoked_at IS NULL) = (revoked_by_declared IS NULL))`;
- trigger `platform_operator_grants_nao_apaga`, `BEFORE DELETE`, que levanta;
- trigger `platform_operator_grants_so_revoga`, `BEFORE UPDATE`, que levanta salvo quando
  `OLD.revoked_at IS NULL` e só `revoked_at`, `revoked_via`, `revoked_by_declared` e `revoke_note`
  mudam.

**O nome `granted_by_declared` é a afirmação**: a prova de quem executou é o acesso ao Dokploy,
que fica fora da aplicação. O nome impede que alguém leia a coluna como autor autenticado.

## 3. `platform_operator_sessions` — a sessão do operador

| coluna | tipo | regra |
|---|---|---|
| `id` | uuid, PK | é o que vai no cookie, junto com o bruto |
| `operator_id` | uuid, FK `platform_operators`, `on_delete: :restrict`, not null | |
| `token_hash` | bytea, not null | índice único |
| `password_epoch` | integer, not null | época da leitura que conferiu a senha |
| `ended_at` | utc_datetime, null | |
| `inserted_at` | utc_datetime | validade de **8 h** a contar daqui |

Índices: `operator_id`, `ended_at`, `inserted_at` (para a retenção).

Retenção: apagada 90 dias depois de deixar de valer, pelo `ApagaSessoesAntigas`. É o **único**
caminho que apaga, como em `sessions.ex:128-150`.

## 4. `tenant_suspensions` — o episódio

| coluna | tipo | regra |
|---|---|---|
| `id` | uuid, PK | |
| `tenant_id` | uuid, FK `tenants`, `on_delete: :restrict`, not null | |
| `suspended_at` | utc_datetime, not null | |
| `suspended_by_operator_id` | uuid, FK `platform_operators`, `on_delete: :restrict`, null | nulo **só** em `not_recorded` |
| `suspend_reason` | string, not null | lista fechada (§5) |
| `suspend_note` | text, null | obrigatória nas razões que a base diz |
| `reactivated_at` | utc_datetime, null | |
| `reactivated_by_operator_id` | uuid, FK `platform_operators`, `on_delete: :restrict`, null | |
| `reactivate_reason` | string, null | lista fechada (§5) |
| `reactivate_note` | text, null | |
| `inserted_at`, `updated_at` | utc_datetime | |

Constraints:

- índice único parcial `tenant_suspensions_aberto_index` sobre `tenant_id`
  `WHERE reactivated_at IS NULL` — **um episódio aberto por organização** (O9, SC-002);
- índice `(tenant_id, suspended_at)` para o histórico;
- `CHECK ((suspend_reason = 'not_recorded') = (suspended_by_operator_id IS NULL))`;
- `CHECK` de tudo-ou-nada da reativação: `reactivated_at`, `reactivated_by_operator_id` e
  `reactivate_reason` são os três nulos ou os três preenchidos;
- triggers `tenant_suspensions_nao_apaga` e `tenant_suspensions_so_fecha`, na forma dos de §2.

**`tenants.status` continua sendo a resposta rápida, e o episódio é o registro.** As duas escritas
estão na mesma transação.

### Transições

```mermaid
stateDiagram-v2
    [*] --> active
    active --> suspended: suspender/3 · abre episódio · encerra sessões · revoga tokens
    suspended --> active: reativar/3 · fecha episódio · encerra sessões de novo
    suspended --> suspended: suspender de novo → {:error, :ja_suspensa}
    active --> active: reativar → {:error, :nao_suspensa}
```

## 5. As razões, na base de conhecimento

Arquivo novo: `priv/knowledge_base/rules/platform_tenant_suspension.yaml`, `derivation_rule:` com
id `platform.tenant_suspension`, `provenance.source_type: project_decision`. Forma de
`access_account_lifecycle.yaml`.

**A lista é proposta**, e quem a confirma é a revisão semântica e a pessoa mantenedora, no PR do
YAML:

| bloco | código | rótulo (tela, inglês) | nota |
|---|---|---|---|
| suspend · offered | `suspected_compromise` | Suspected compromise | obrigatória |
| suspend · offered | `contract_ended` | The contract ended | opcional |
| suspend · offered | `requested_by_the_organisation` | Requested by the organisation | opcional |
| suspend · offered | `other` | Other | obrigatória |
| suspend · recorded_only | `not_recorded` | The reason was not recorded | só a migração escreve |
| reactivate · offered | `investigation_closed_no_compromise` | Investigation closed — no compromise found | `offered_only_against: suspected_compromise` |
| reactivate · offered | `contract_resumed` | The contract resumed | opcional |
| reactivate · offered | `suspended_by_mistake` | Suspended by mistake | opcional |
| reactivate · offered | `other` | Other | obrigatória |

## 6. Alterações em tabelas existentes

### `tenants`

- `CHECK (status IN ('active', 'suspended'))`, nome `tenants_status_valido`;
- o `up` conta os valores fora da lista e **levanta** se houver algum (research R6);
- o `up` insere um episódio `not_recorded` para cada organização `suspended` sem episódio aberto.

### `api_access_tokens`

- coluna `revoked_by_suspension_id`, uuid, FK `tenant_suspensions`, `on_delete: :restrict`, null;
- `CHECK (revoked_by_suspension_id IS NULL OR revocation_clause = 'organizacao_suspensa')`;
- `CHECK (revocation_clause IS DISTINCT FROM 'organizacao_suspensa' OR revoked_by_suspension_id IS NOT NULL)`.

Os dois juntos dizem: a cláusula `organizacao_suspensa` existe **se e só se** há um episódio
apontado. As linhas antigas (cláusula nula, suspensão nula) passam pelos dois.

Na regra `api.access` (`api_access_thresholds.yaml:91-105`) entra a chave
`clausulas_so_registradas: [organizacao_suspensa]`, com rótulo
`{ pt-BR: "organização suspensa", en: "organisation suspended" }`.
`ApiTokens.clausulas_de_revogacao/0` continua devolvendo **só as oferecidas**, e a tela de tokens
não muda de select.

### `user_sessions`

**Nenhuma alteração** (FR-011). O encerramento por organização usa o índice que já existe
(`20260929100000_sessoes_de_usuario.exs:54`).

### `users`

**Nenhuma alteração** (FR-011). É o que torna a #879 independente desta feature (research R11).

## 7. A consulta do SC-002

```sql
SELECT count(*) FROM tenants t
WHERE t.status = 'suspended'
  AND NOT EXISTS (SELECT 1 FROM tenant_suspensions s
                  WHERE s.tenant_id = t.id AND s.reactivated_at IS NULL);
-- MUST devolver 0
```

E a recíproca, que a transação também garante: nenhuma organização `active` com episódio aberto.
