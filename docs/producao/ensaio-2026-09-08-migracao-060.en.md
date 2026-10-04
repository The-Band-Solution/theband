# Rehearsal of migration `20260908010000` on real data — 2026-09-08

The riskiest thing this release brings is a migration that **alters data**:
`20260908010000_saida_declarada_com_autor.exs` adds three columns, backfills
`declared_at` and creates two CHECKs.

It **broke** on the development database before I fixed it, and the reason is what this
rehearsal measures: `CREATE CONSTRAINT` validates the existing rows **at the moment of creation**, and the
CHECKs came before the backfill. It passed on an empty database — which is the suite's — and failed on
any database with a declared team membership.

## What was rehearsed, and what was NOT

**Rehearsed**: the migration applied to a restored copy of the development database, starting
from the **pre-migration** state — which is the state production is in.

**Not rehearsed**: runbook §6 — downloading the backup from the S3 destination, restoring it into a new Dokploy
database and checking the numbers on the screen of a rehearsal instance. Those steps are
milestones for a person (they require the VPS and access to S3), and they remain pending. This rehearsal **does not replace them**:
it answers "does the migration run on real data?", and not "does the backup really exist?".

## The procedure

```bash
pg_dump the_band_dev > /tmp/ensaio.sql        # cópia
createdb band_ensaio && psql band_ensaio < /tmp/ensaio.sql
# volta ao estado da produção: derruba as três colunas, as duas CHECKs, e a linha
# de schema_migrations
# roda a migração na ordem do arquivo, numa transação
```

## The numbers

| measure | before | after |
|---|---:|---:|
| team memberships (`eo_team_memberships`) | **90** | **90** |
| with `declared_by_user_id` filled in | 34 | 34 |
| with `declared_at` filled in | — (column did not exist) | **34** |
| **incomplete pair** (author without instant) | — | **0** |
| ended (`ended_at`) | 0 | 0 |
| end with author (`ended_by_user_id`) | — | 0 |

The backfill `UPDATE` reported **34 rows** — exactly the ones that have an author. No row
lost, no incomplete pair, and both CHECKs created without violation.

## The proof that the order mattered

I took the rehearsal back to the pre-migration state and tried **in the wrong order** — the CHECK before the
backfill. On the same 90 rows:

```
ERROR:  check constraint "eo_declaracao_tem_autor" of relation
        "eo_team_memberships" is violated by some row
```

The transaction aborted and the constraint was not created. It is the same error that appeared on the
development database, and it is the reason the order in the file is backfill → CHECKs.

## What this allows us to state about production

Both CHECKs are **satisfied by construction** on a pre-migration database, and the rehearsal
confirms it empirically:

- `eo_declaracao_tem_autor` would only fail with `declared_at` filled in and a null author. Before the
  migration the column does not exist, so every row comes in with a null `declared_at` — and the backfill
  fills it in exactly where there is an author;
- `eo_saida_declarada_completa` would only fail with the author or the instant of the end filled in. Both
  columns are born in this migration, null on every row.

What the rehearsal does **not** guarantee is the time: 90 rows in a local container do not tell how much the
`UPDATE` costs over a larger volume. In production the number of team memberships is of the same order, and the
migration runs in a transaction — if it fails, it fails entirely, and the schema stays as it was.
