# Evidência no contêiner — quickstart §3 (T008, T009) e SC-003 (T005)

Medido em 2026-10-02, com a imagem da release construída deste branch (`docker build`,
`BUILD_EXIT=0`), contra uma base local isolada (`the_band_test_papeis`). A base foi migrada pelo
`postgres`, e o papel `the_band_app_teste` foi concedido por `Papeis.conceder/2`. As senhas eram
locais, geradas por `openssl rand`, e não saem deste registro.

## O defeito que a medição pegou

Na primeira subida com as duas credenciais, o deploy recusou com `:mesma_credencial`.
- **A causa:** no `sh`, as atribuições em prefixo são feitas da esquerda para a direita.
  `THE_BAND_URL_QUE_SERVE="$DATABASE_URL"` vinha depois de `DATABASE_URL="$DATABASE_MIGRATION_URL"`
  e lia a credencial que migra.
- **O efeito:** a guarda de `conceder/2` recusou, e nada foi concedido ao papel errado.
- **O conserto:** o entrypoint lê a URL de quem serve antes. A suíte não pegaria isso, porque
  não roda o entrypoint.

## Com as duas credenciais

```
aplicando migrações pendentes…
papéis: privilégios de quem serve concedidos
migrações aplicadas.
[info] papéis: separação em vigor
```

- **PID 1**: o nome `DATABASE_MIGRATION_URL` aparece **0** vezes em `/proc/1/environ`. A guarda
  de que mediu: `DATABASE_URL` aparece 1 vez no mesmo arquivo.
- **Processo aberto por `docker exec`**, como o `HEALTHCHECK`: a variável aparece **1** vez. É o
  limite S5, aceito e declarado em 2026-10-02 (#1140). Uma primeira contagem, com `/proc/self`
  dentro de um redirecionamento do `sh`, deu 0. Foi erro de medição, e a contagem pelo `env` do
  próprio processo é a que vale.
- **A conferência por `rpc`** disse `papéis: separação em vigor`.

## Sem a credencial que migra, os três estados de FR-008

| estado | o que o contêiner fez |
|---|---|
| quem serve é dono (`postgres`) | migrou e subiu; o deploy disse `separação NÃO em vigor (credencial_que_migra_ausente)`, e o boot repetiu em `warning` com os motivos (`superusuario`, `dono_de_objeto`, …) |
| quem serve não é dono, e não há pendente | subiu; o deploy disse `separação em vigor; DATABASE_MIGRATION_URL ausente, nada a migrar` |
| quem serve não é dono, e há uma pendente | **não subiu** (`exit=1`): `1 migração(ões) pendente(s) e DATABASE_MIGRATION_URL ausente; configure-a no painel (runbook §14) e reimplante` |

## SC-003, a suíte como quem serve

`mix test` com `THE_BAND_TEST_DB_USER=the_band_app_teste`: `2659 tests, 0 failures, 20 excluded`
(`SUITE_EXIT=0`). Os 20 excluídos são os da 071, que criam papel. Fumaça do Oban como esse papel:
`INSERT`, `UPDATE`, `NOTIFY`, `LISTEN` e `DELETE` em `oban_jobs`, todos aceitos.
