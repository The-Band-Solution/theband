# Contrato — `TheBand.Papeis` e o que muda em `TheBand.Release` e no entrypoint

FR-001 a FR-012. Decisões em [research.md](../research.md).

`TheBand.Papeis` é infraestrutura de acesso: **depende de nenhuma ontologia**, não recebe tenant e
só fala com o banco por SQL literal (nenhum identificador interpolado vem de fora: o nome do papel
que serve é citado com `quote_ident` do próprio PostgreSQL, via `format('%I', $1)` dentro de um
bloco `DO`, nunca por interpolação Elixir — Sobelow `SQL.Query`).

## `TheBand.Papeis.conceder(repo, papel_que_serve :: String.t()) :: :ok`

O passo idempotente de FR-005. Roda com a conexão do papel que migra. Em ordem:

1. `GRANT CONNECT` na base e `USAGE` no esquema `public`;
2. `GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public`;
3. `GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public`;
4. `ALTER DEFAULT PRIVILEGES FOR ROLE current_user IN SCHEMA public` para tabelas e sequências,
   com os mesmos privilégios;
5. `REVOKE ALL ON schema_migrations`, e depois `GRANT SELECT ON schema_migrations`;
6. `REVOKE CREATE ON SCHEMA public FROM PUBLIC` e `REVOKE CREATE ON DATABASE … FROM PUBLIC`.

Levanta, com a frase e sem credencial:
- se `papel_que_serve` for igual a `current_user` (`:mesma_credencial`);
- se o papel não existir.

Não concede nada de FR-002 negado. Não recebe a credencial: recebe o **nome**.

## `TheBand.Papeis.conferir(repo) :: {:em_vigor | :nao_em_vigor | :inconclusivo, [motivo]}`

A conferência de FR-009, com os motivos de `data-model.md`. Roda com a conexão de quem serve.
- Lê o catálogo sem lock.
- Faz as tentativas de FR-003 numa transação com `lock_timeout` de 200 ms, que **sempre** termina
  em `ROLLBACK`. Cada tentativa vai num `SAVEPOINT`.
- Não grava nada: depois dela, `tgenabled`, as constraints e as contagens são as de antes.

## `TheBand.Papeis.pendentes(repo) :: {:ok, [versao]}`

As versões de `priv/repo/migrations` que não estão em `schema_migrations`. Usa `SELECT` direto, e
não a `Ecto.Migrator` (R4).

## `TheBand.Release`

| função | muda | o que faz |
|---|---|---|
| `migrate/0` | sim | migra, e depois `Papeis.conceder(repo, usuario(THE_BAND_URL_QUE_SERVE))`. Traduz `Ecto.InvalidURLError` sem a URL (S6) |
| `migrar_sem_credencial/0` | nova | os três estados de R4; imprime a linha do relator; levanta só no terceiro |
| `conferir_papeis/0` | nova | `Papeis.conferir/1`, traduzido em frase, por `rpc` |
| `rollback/2` | não | o roteiro diz para chamá-lo com `DATABASE_URL="<a credencial que migra>"` na linha |
| demais | não | usam o `DATABASE_URL`, que é o de quem serve |

## `rel/entrypoint.sh`

```text
se DATABASE_MIGRATION_URL presente:
    DATABASE_URL=<ela> THE_BAND_URL_QUE_SERVE=<DATABASE_URL> eval migrate()
senão:
    eval migrar_sem_credencial()
unset DATABASE_MIGRATION_URL
eval semear_primeira_conta()        # com o DATABASE_URL de quem serve
exec "$@"
```

Nunca `set -x`. Nenhuma linha ecoa as variáveis.

## O que este contrato NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| `runtime.exs` lendo `DATABASE_MIGRATION_URL` | A6: todo `eval` teria o dono |
| função que crie papel ou mude senha | é do roteiro, como `postgres`; a aplicação não administra papéis |
| a conferência por `eval` | mediria o `runtime.exs` daquela VM, e não o processo que serve |
| tela | não há consumidor; a conferência é de quem opera |
