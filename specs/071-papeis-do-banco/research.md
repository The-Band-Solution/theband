# Research — spec 071, os papéis do banco

Cada decisão parte do que a avaliação de segurança mediu num PostgreSQL 16 local
(`seguranca.md`, "Como foi medido") e das decisões da pessoa mantenedora de 2026-10-02.

## R1 — Como a migração recebe a credencial que migra

**Decisão**: o entrypoint lê `DATABASE_MIGRATION_URL` e a entrega **só** ao comando da migração,
por atribuição na própria linha:

```sh
DATABASE_URL="$DATABASE_MIGRATION_URL" THE_BAND_URL_QUE_SERVE="$DATABASE_URL" \
  /app/bin/the_band eval 'TheBand.Release.migrate()'
```

Depois o entrypoint faz `unset DATABASE_MIGRATION_URL` antes do `exec "$@"`. `config/runtime.exs`
continua lendo **só** `DATABASE_URL`, e `lib/` não conhece o nome da variável que migra (FR-004).

**Por quê**: a VM do `eval` lê `DATABASE_URL` pelo `runtime.exs` de sempre. Trocar o valor só
naquela linha é o menor caminho, e não ensina a aplicação a escolher credencial. A credencial que
serve vai junto, porque o passo de concessão de R2 precisa do **nome** do papel que serve, e o nome
sai do usuário dessa URL.

**Alternativas recusadas**:
- `runtime.exs` preferindo a variável que migra quando presente. É o defeito A6: o `eval` de
  qualquer comando de release, que tem o ambiente do contêiner, conectaria como dono;
- um segundo `Repo` só para migrar. É configuração nova para o mesmo banco, e um segundo caminho que
  alguém usaria fora da migração.

## R2 — A concessão é um passo idempotente a cada deploy, e não uma migração

**Decisão**: `TheBand.Papeis.conceder/2` roda depois de migrar, com a credencial que migra, a cada
deploy. Ela:
- concede FR-002, por nome, em todas as tabelas e sequências existentes;
- define `ALTER DEFAULT PRIVILEGES FOR ROLE current_user IN SCHEMA public` para tabelas e
  sequências;
- revoga tudo em `schema_migrations`;
- revoga `CREATE` em `public` e na base de `PUBLIC`, e confere que o PostgreSQL 16 já faz isso.

**Por quê** (S7): a concessão numa migração rodaria uma vez. Uma restauração ou uma tabela criada
fora do caminho ficaria sem privilégio, e uma migração com o nome do papel derrubaria o deploy
quando o papel ainda não existe. Idempotente a cada deploy é auto-corretiva.

**O que fica pior**: o deploy faz uns `GRANT` a mais a cada subida. São leves, mas tomam lock
curto de catálogo.

## R3 — O veredito vem de uma medição no banco (o relator)

**Decisão**: `TheBand.Papeis.conferir/1` devolve
`{:em_vigor | :nao_em_vigor | :inconclusivo, [motivo]}`. São duas partes:
- **leitura de catálogo**: `rolsuper` e os atributos de FR-001; as posses em `pg_class`, `pg_proc`,
  `pg_namespace`, `pg_type` e `pg_database`; `pg_has_role` para cada dono e cada papel predefinido;
  os privilégios comparados à lista fechada; `pg_parameter_acl`; as funções de trigger em `public`
  sem `search_path`;
- **tentativas**: as de FR-003, numa transação que sempre termina em `ROLLBACK`, com
  `lock_timeout` de 200 ms. Só `42501` conta como recusa.

Motivos, um átomo cada:
- `:superusuario`;
- `:atributo_perigoso`;
- `:dono_de_objeto`;
- `:membro_do_dono`;
- `:membro_predefinido`;
- `:privilegio_a_mais`;
- `:schema_migrations_gravavel`;
- `:replica_permitida`;
- `:create_no_esquema`;
- `:mesma_credencial`;
- `:credencial_que_migra_ausente`;
- `:tentativa_passou`;
- `:tentativa_inconclusiva`;
- `:funcao_sem_search_path` e `:dono_superusuario` (aviso, R8).

**Por quê** (S2, S4): a presença da variável não diz se o banco está protegido. A conferência
precisa medir o papel que **de fato** serve, e por isso roda por `rpc`, dentro do nó (FR-009).

## R4 — Os três estados sem a credencial que migra

**Decisão**: sem `DATABASE_MIGRATION_URL`, o entrypoint roda `TheBand.Release.migrar_sem_credencial()`.

| condição | ação |
|---|---|
| `current_user` é dono de `schema_migrations` (o estado de hoje) | migra, e o relator diz `:nao_em_vigor, [:credencial_que_migra_ausente, …]` |
| não é dono, e não há pendente | não migra e sobe, com o relator lido |
| não é dono, e há pendente | levanta: "migração pendente e `DATABASE_MIGRATION_URL` ausente" |

As pendentes se conferem comparando as versões dos arquivos de migração da release (`priv/repo/migrations`)
com `SELECT version FROM schema_migrations`. A `Ecto.Migrator` não é usada aqui, porque faz
`CREATE TABLE IF NOT EXISTS`, que recusa sem `CREATE` (medido).

Problema: o papel que serve não tem privilégio em `schema_migrations` (S3), então não a lê. **Decisão**:
conceder **só `SELECT`** em `schema_migrations` ao papel que serve. `INSERT`, `UPDATE` e `DELETE`
continuam negados, e o defeito de S3 é a escrita. A FR-002 é emendada com isso.

## R5 — A linha repetida a cada subida

**Decisão**: depois de o `Repo` subir, um `Task` sem link da árvore de supervisão roda
`Papeis.conferir/1` e emite `Logger.warning` quando o veredito não é `:em_vigor`. Uma falha da
conferência dá `:inconclusivo`, e nunca derruba o boot.

**Por quê**: FR-008 manda repetir o aviso a cada subida. O log do deploy some, e o do processo fica.

## R6 — A URL no erro (S6)

**Decisão**: `TheBand.Release.migrate/0` e `migrar_sem_credencial/0` envolvem o início do repositório
e traduzem `Ecto.InvalidURLError` para "`DATABASE_URL` malformada (verifique caracteres reservados
na senha)", sem a URL. O roteiro gera a senha com `openssl rand -hex 32`.

## R7 — O teste em CI (FR-011, A1–A10)

**Decisão**: `test/the_band/papeis_test.exs`, `async: false`.
- Na transação do sandbox, como o `postgres` do CI, roda
  `CREATE ROLE serve_t_<n> NOLOGIN` (transacional, medido).
- `Papeis.conceder/2` concede com o papel do teste como "que serve". É o mesmo artefato da produção.
- `SET LOCAL ROLE serve_t_<n>`, e cada tentativa em `SAVEPOINT`.
- **A asserção de que mediu**: `current_user` é o papel e `rolsuper` é falso.
- As asserções são sobre `42501`, `tgenabled = 'O'` e as contagens.

**O controle positivo (A10)**: as mesmas tentativas, com o papel do sandbox (`postgres`), passam
dentro de `SAVEPOINT` desfeito.

O A9 (o ambiente do contêiner) é do quickstart, e não da suíte.

O CI roda PostgreSQL 17, e a produção 16 (S8): a lista vai por nome, e o teste confere que o papel
**não** tem `MAINTAIN` onde ele existe.

## R8 — O dono dedicado (S11) é passo do roteiro, e não código

**Decisão**: o runbook §14 cria `the_band_owner`, `NOSUPERUSER`, e roda `REASSIGN OWNED BY postgres
TO the_band_owner` **na base da aplicação**, uma vez, como `postgres`, antes da troca das
credenciais. O código não depende disso: o papel que migra é quem a credencial disser, e a
conferência relata se é superusuário (`:dono_superusuario`, como aviso e não como `:nao_em_vigor`,
porque o G1 é sobre quem serve).

## R9 — O que não muda

- **O Oban.** Usa as tabelas `oban_*` por DML, e `LISTEN/NOTIFY` não exige privilégio (medido). O
  Pruner apaga por `DELETE`.
- **`setval` e `oban_jobs_id_seq`.** Quem serve não precisa de `setval`, e ele é recusado (medido).
- **O backup do Dokploy**, que roda como o usuário administrativo. Não verificado, e entra no
  roteiro como conferência.
