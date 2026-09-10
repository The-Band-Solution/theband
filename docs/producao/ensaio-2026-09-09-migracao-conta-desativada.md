# Ensaio da migração `20260909180000` sobre dado real — 2026-09-09

A migração da **conta desativada** (achado H3, parte B) acrescenta `users.disabled_at` e
`users.disabled_by_user_id`, mais um índice parcial.

## Por que ensaiar uma migração que só acrescenta coluna nula

Porque a anterior ensinou. A `20260908010000` da v0.6.0 **quebrou** no banco de
desenvolvimento por ordem invertida — `CREATE CONSTRAINT` valida as linhas existentes no
instante da criação, e as CHECKs vinham antes do backfill. **Passava em banco vazio**, que é
o da suíte, e reprovava em qualquer banco com dado.

Esta é a migração de menor risco possível — só-acréscimo, sem backfill, sem CHECK, e a versão
anterior da aplicação sobe sobre este esquema (runbook §5). Ensaiar assim mesmo custa cinco
minutos, e o que ele mediu de facto está abaixo.

## O que foi ensaiado

A migração aplicada a uma **cópia restaurada do banco de desenvolvimento**, a partir do estado
**pré-migração** — que é o estado em que a produção está.

| medida | antes | depois |
|---|---:|---:|
| linhas em `users` | 3 | **3** |
| vínculos de equipe | 90 | **90** |
| issues coletadas | 4 971 | **4 971** |
| colunas `disabled%` | 0 | **2, as duas anuláveis** |
| índice `users_desativadas_por_tenant` | ausente | **existe** |
| **contas desativadas por acidente** | — | **0** |

A última linha é a que importa: uma migração que acrescenta coluna de estado e a preenche por
engano **desligaria contas em produção**. Ela nasce nula, e o ensaio confere que nasceu.

`== Migrated 20260909180000 in 0.0s`, **código de saída 0**.

## O que este ensaio NÃO responde

**O §6 do runbook** — baixar o backup do destino S3, restaurar num banco novo do Dokploy e
conferir os números na tela de uma instância de ensaio. Continua **adiado**: a conta no destino
S3 não existe (`docs/backlog/backup-restaurado-de-verdade.md`).

São perguntas diferentes, e parecem a mesma:

| pergunta | respondida? |
|---|---|
| *a migração roda sobre dado real?* | **sim**, medido acima |
| *o backup existe de verdade?* | **não**, desde a v0.1.0 |

## O defeito que o ensaio pegou — no ensaio, não na migração

**A primeira tentativa imprimiu `== Migrated` e não tocou a cópia.**

`config/dev.exs` fixa `database: "the_band_dev"` e **ignora `DATABASE_URL`**. A migração rodou
no banco de desenvolvimento, e a mensagem de sucesso era verdadeira — sobre o banco errado.

O passo 4 pegou: as colunas não existiam na cópia. **Sem o passo de verificação, este
documento diria "ensaio aprovado" sobre uma execução que não mediu nada** — a família do
sucesso silencioso, dentro do procedimento que existe para evitá-la.

Duas tentativas seguintes também falharam, e valem registro para quem repetir:

- `mix run --no-start` não sobe o `DBConnection.Watcher`, e o `start_link` do Repo morre num
  `GenServer.call` a processo inexistente;
- `Application.ensure_all_started(:postgrex)` não basta — falta o `Ecto.Repo.Registry`, que
  vem com `:ecto_sql`.

**O que funcionou** é o que um ensaio humano faz: apontar `config/dev.exs` para a cópia, rodar
`mix ecto.migrate`, e restaurar. Com `trap restaurar EXIT` no script, para o config voltar
mesmo se algo abortar no meio — e com a conferência final de que voltou.

## O procedimento, para repetir

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

## Referências

- `docs/producao/ensaio-2026-09-08-migracao-060.md` — o ensaio da v0.6.0, e o formato;
- `docs/backlog/backup-restaurado-de-verdade.md` — o §6, bloqueado em recurso;
- `docs/seguranca/2026-09-09-o-que-consertar-agora.md` — o achado H3 e o cenário do QA;
- `docs/producao/runbook.md` §5 (rollback) e §6 (o ensaio do backup).
