# Rehearsal of migration `20260909180000` on real data — 2026-09-09

The **disabled account** migration (finding H3, part B) adds `users.disabled_at` and
`users.disabled_by_user_id`, plus a partial index.

## Why rehearse a migration that only adds a null column

Because the previous one taught us. The v0.6.0 `20260908010000` **broke** on the
development database because of inverted order — `CREATE CONSTRAINT` validates the existing rows at the
moment of creation, and the CHECKs came before the backfill. **It passed on an empty database**, which is
the suite's, and failed on any database with data.

This is the lowest-risk migration possible — add-only, no backfill, no CHECK, and the previous
version of the application starts on this schema (runbook §5). Rehearsing anyway costs five
minutes, and what it actually measured is below.

## What was rehearsed

The migration applied to a **restored copy of the development database**, starting from the
**pre-migration** state — which is the state production is in.

| measure | before | after |
|---|---:|---:|
| rows in `users` | 3 | **3** |
| team memberships | 90 | **90** |
| collected issues | 4,971 | **4,971** |
| `disabled%` columns | 0 | **2, both nullable** |
| index `users_desativadas_por_tenant` | absent | **exists** |
| **accounts disabled by accident** | — | **0** |

The last row is the one that matters: a migration that adds a state column and fills it in by
mistake **would disable accounts in production**. It is born null, and the rehearsal checks that it was.

`== Migrated 20260909180000 in 0.0s`, **exit code 0**.

## What this rehearsal does NOT answer

**Runbook §6** — downloading the backup from the S3 destination, restoring it into a new Dokploy database and
checking the numbers on the screen of a rehearsal instance. It remains **postponed**: the account at the
S3 destination does not exist (`docs/backlog/backup-restaurado-de-verdade.md`).

They are different questions, and they look like the same one:

| question | answered? |
|---|---|
| *does the migration run on real data?* | **yes**, measured above |
| *does the backup really exist?* | **no**, since v0.1.0 |

## The defect the rehearsal caught — in the rehearsal, not in the migration

**The first attempt printed `== Migrated` and did not touch the copy.**

`config/dev.exs` pins `database: "the_band_dev"` and **ignores `DATABASE_URL`**. The migration ran
on the development database, and the success message was true — about the wrong database.

Step 4 caught it: the columns did not exist in the copy. **Without the verification step, this
document would say "rehearsal passed" about a run that measured nothing** — the
silent success family, inside the procedure that exists to prevent it.

Two following attempts also failed, and are worth recording for whoever repeats this:

- `mix run --no-start` does not start `DBConnection.Watcher`, and the Repo's `start_link` dies in a
  `GenServer.call` to a nonexistent process;
- `Application.ensure_all_started(:postgrex)` is not enough — `Ecto.Repo.Registry` is missing, which
  comes with `:ecto_sql`.

**What worked** is what a human rehearsal does: point `config/dev.exs` at the copy, run
`mix ecto.migrate`, and restore. With `trap restaurar EXIT` in the script, so the config comes back
even if something aborts midway — and with the final check that it came back.

## The procedure, to repeat it

```bash
# no contêiner do Postgres
pg_dump -U postgres the_band_dev > /tmp/e.sql
createdb -U postgres band_ensaio_h3b && psql -U postgres band_ensaio_h3b < /tmp/e.sql

# volta ao estado da produção
alter table users drop column if exists disabled_at, drop column if exists disabled_by_user_id;
drop index if exists users_desativadas_por_tenant;
delete from schema_migrations where version = 20260909180000;

# aponta o config, migra, restaura com trap
sed -i '' 's/database: "the_band_dev"/database: "band_ensaio_h3b"/' config/dev.exs
MIX_ENV=dev mix ecto.migrate
# e CONFERIR na cópia — é o passo que a primeira tentativa não tinha
```

## References

- `docs/producao/ensaio-2026-09-08-migracao-060.md` — the v0.6.0 rehearsal, and the format;
- `docs/backlog/backup-restaurado-de-verdade.md` — §6, blocked on a resource;
- `docs/seguranca/2026-09-09-o-que-consertar-agora.md` — finding H3 and the QA scenario;
- `docs/producao/runbook.md` §5 (rollback) and §6 (the backup rehearsal).
