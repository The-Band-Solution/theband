# Contrato — TheBand.Tenants.Auth

**Módulo**: `TheBand.Tenants.Auth` (exposto pela fachada `TheBand.Tenants`).
**Escrito antes da implementação** (constituição VI). Errou, corrige no mesmo commit,
com a razão.

## authenticate/2

```elixir
@spec authenticate(String.t(), String.t()) ::
        {:ok, User.t()} | {:error, :invalid_credentials} | {:error, {:throttled, seconds :: pos_integer()}}
```

- `identificador` = e-mail (case-insensitive) ou usuário do GitHub resolvido pelo elo
  vigente (research R3). Zero contas, mais de uma conta, elo revogado, conta sem senha
  (`password_hash` NULL) ou senha errada → **sempre** `{:error, :invalid_credentials}`
  — um único erro para todos os casos (FR-002/014/019).
- A verificação de hash roda mesmo sem conta (hash dummy) — o tempo de resposta não
  revela existência.
- Espera crescente (FR-016, research R4): dentro da janela,
  `{:error, {:throttled, s}}` — a TELA mostra a mesma mensagem única; o valor `s`
  existe para teste e log, nunca para o HTML.
- Sucesso: zera tentativas, gira/garante `session_token`, grava `logged_in_at`, e
  devolve a conta com tenant carregado.
- **Sem tenant no argumento, de propósito**: o identificador é global (e-mail único;
  GitHub username ambíguo entre tenants não identifica) — o tenant SAI da conta
  autenticada, nunca entra como escolha de quem loga.

## set_password/3 · change_password/4 · reset_password/3

```elixir
@spec set_password(Tenant.t(), user_id, senha) :: {:ok, User.t()} | {:error, Changeset.t()}
@spec change_password(Tenant.t(), user_id, senha_atual, senha_nova) ::
        {:ok, User.t()} | {:error, :invalid_current} | {:error, Changeset.t()}
@spec reset_password(Tenant.t(), user_id, actor_id) :: {:ok, senha_temporaria :: String.t()}
```

- Regra de senha: mínimo 12 caracteres (assumption da spec), sem exigência de
  composição. Validação no changeset, nunca na tela.
- `change_password` exige a atual (FR-012) e **gira `session_token`** (FR-015);
  `must_change_password` vira false.
- `reset_password` é ato de administrador (chamador garante): gera senha temporária
  aleatória, grava o hash com `must_change_password: true`, gira o token, e devolve a
  temporária **uma única vez** — ela não é gravada em claro nem logada (FR-013).
- `set_password` cobre a primeira definição forçada (fluxo da temporária).

## O que esta API NÃO expõe, e por quê

- **Não expõe qual parte errou** — mensagem única é requisito (FR-002), não limitação.
- **Não expõe a senha nem o hash** em retorno algum além da temporária de
  `reset_password` (uma vez, para quem administra entregar por canal próprio).
- **Não expõe "login por tenant"** — ver `authenticate/2`.
- **Não faz recuperação por e-mail** — fora da entrega (assumption; não há envio).
