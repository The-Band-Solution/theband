# Contrato — a concessão: `TheBand.Platform.Grants` e os comandos de `TheBand.Release`

FR-001, FR-002, FR-014, O11. Tabela em [data-model.md](../data-model.md) §2.

> **Emendado em 2026-10-01** pela avaliação da segunda autenticação
> ([seguranca-autenticacao.md](../seguranca-autenticacao.md)), achados **A6, A13c e A14**, e pelo
> segundo fator (FR-016). O código continua **bloqueado** até a avaliação própria do TOTP
> (`tasks.md`): conceder e reiniciar apagam o cadastro do segundo fator, e a forma disso é dela.

**Nenhuma tela concede nem revoga** (FR-001). Estas funções não são chamadas por controller nem por
LiveView, e o teste afirma que nenhum módulo de `TheBandWeb` as referencia.

**O comando não acrescenta poder a ninguém**: quem o roda já tem o banco e a
`THE_BAND_MASTER_KEY`. Ele não é controle de acesso; é o caminho registrado.

## `TheBand.Platform.Grants`

### `conceder(email, nome, declarado_por :: String.t()) :: {:ok, {Operator.t(), Grant.t(), TheBand.Segredo.t()}} | {:error, :ja_concedido} | {:error, Ecto.Changeset.t()}`

Numa transação: cria o operador se não existir, abre a concessão (`granted_via: "release_command"`,
`granted_by_declared: declarado_por`, `email_at_grant: email`, A13c) e emite o código de definição.
Concessão vigente já existente: `{:error, :ja_concedido}`, garantido pelo índice parcial.

**Conceder de novo nunca devolve credencial antiga (A6).** Se o operador já existe, sem concessão
vigente, a mesma transação faz o que `reiniciar_credencial/2` faz:

- `password_hash = NULL` e `password_epoch + 1`;
- `totp_secret = NULL`, `totp_confirmed_at = NULL`, `totp_last_used_step = NULL`,
  `second_factor_failures = 0` (destrava o segundo fator, seguranca-totp.md T1), e todo código de
  recuperação do operador marcado `used_at` (não apagado: o registro fica);
- código de cadastro e código de guarda (`ack_code_hash`, emenda T012) anulados;
- `Platform.Sessions.encerrar_do_operador/1`;
- o código de definição novo.

O operador revogado, talvez por comprometimento, não entra com a senha nem com o aplicativo de
antes no dia em que alguém conceder de novo.

### `reiniciar_credencial(email, declarado_por) :: {:ok, TheBand.Segredo.t()} | {:error, :not_found}`

Exige concessão vigente. Numa transação: apaga `password_hash`, sobe `password_epoch`, apaga o
cadastro do segundo fator (como em `conceder/3`, A6), emite código novo e encerra as sessões do
operador. A15: a mesma transação faz `FOR UPDATE` nas sessões abertas do operador antes de
encerrá-las, para serializar com o `FOR SHARE` que a suspensão em voo faz na linha da sessão
(`suspensao.md`).

### `revogar(email, declarado_por, nota :: String.t() | nil) :: {:ok, Grant.t()} | {:error, :not_found}`

Numa transação (FR-014): `UPDATE` da concessão vigente preenchendo a revogação, com a condição
`revoked_at IS NULL` no `WHERE`, **e** `Platform.Sessions.encerrar_do_operador/1`, **e** anula o
código de definição, o de cadastro e o de guarda pendentes (A14; o de guarda pela emenda T012). A suspensão em voo lê a concessão com
`FOR SHARE`, e as duas se serializam (research R8).

### `vigente?(operator_id) :: boolean()`

Lida pela conferência da sessão e pela autorização dentro de `suspender/3` e `reativar/3`.

## `TheBand.Release`

```
/app/bin/the_band eval 'TheBand.Release.conceder_operador("email", "Nome", "quem executa")'
/app/bin/the_band eval 'TheBand.Release.reiniciar_credencial_do_operador("email", "quem executa")'
/app/bin/the_band eval 'TheBand.Release.revogar_operador("email", "quem executa", "nota")'
```

Na forma de `release.ex:106-118`: `load_app/0` e `Ecto.Migrator.with_repo/2`. **Nunca recebem
senha.** A saída diz o e-mail e o ato; o código de definição é a **única** coisa secreta impressa, uma
vez, com a validade.

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| `delete`, `apagar` ou equivalente | FR-002; e o trigger `BEFORE DELETE` levanta (research R7) |
| reativar uma concessão revogada | revogação é definitiva; concede-se de novo, e o histórico fica com as duas linhas |
| qualquer argumento de senha | O11 |
| autor autenticado | o autor é **declarado**, e a coluna se chama `granted_by_declared` para dizer isso |
| listar operadores pela tela | a tela não gere o papel; quem precisa da lista roda `eval` |
