# Data model — spec 072

## `account_role_changes` — o episódio da mudança de papel

| coluna | tipo | regra |
|---|---|---|
| `id` | uuid, PK | |
| `tenant_id` | uuid, FK `tenants`, `restrict`, not null | |
| `user_id` | uuid, FK `users`, `restrict`, not null | a conta cujo papel mudou |
| `changed_by_user_id` | uuid, FK `users`, `restrict`, not null | quem agiu; sempre um admin ativo no instante (R1) |
| `from_role`, `to_role` | string, not null | `CHECK` em `admin` e `member`, e `from_role <> to_role` |
| `note` | text, null | opcional; nunca vai ao log; `CHECK account_role_changes_nota_curta`: até 2000 caracteres (S6) |
| `txid` | bigint, not null, default `txid_current()` | liga o episódio à transação que mudou `users.role` (R3) |
| `inserted_at` | utc_datetime_usec | em microssegundo: em segundo, a ordem do registro empatava e desempatava pelo UUID |

- **Índices**: `(tenant_id, inserted_at)` para a seção "Administrator changes", e `(user_id,
  inserted_at)` para a linha de cada conta.
- **Triggers**: `nao_apaga`, `nao_altera` (todo `UPDATE`) e `nao_trunca`. É somente-acréscimo.
- **Sem backfill** (Q6): os administradores de hoje não ganham episódio, e a tela escreve "no role
  change recorded".

## `users`

- `CHECK users_role_valido`: `role IN ('admin','member')`, criado depois de conferir as linhas.
- Um trigger de constraint adiado, `users_papel_tem_episodio`, `AFTER UPDATE OF role`: no `COMMIT`,
  precisa existir o episódio da mesma transação (`txid`) com `to_role = NEW.role`.
