# Contrato — `TheBand.Platform.Credentials`

FR-011, O4, O11, O16. Desenho em [research.md](../research.md) R1 e R2; tabela em
[data-model.md](../data-model.md) §1.

> **Bloqueado pela revisão de segurança da segunda autenticação** (plan.md, "Gate de segurança").
> Nenhuma linha deste módulo é escrita antes dela.

Depende de: nenhuma ontologia. É infraestrutura de acesso, como `TheBand.Tenants.Auth`.

## `autenticar(email :: String.t(), senha :: String.t()) :: {:ok, Operator.t()} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}}`

- resolve o operador por `lower(email)`;
- **recusa única** `{:error, :invalid_credentials}` para: e-mail inexistente, senha errada, senha
  ainda não definida, **sem concessão vigente**;
- o custo do Bcrypt roda **sempre**: `Bcrypt.no_user_verify/0` quando não há operador, quando não há
  concessão e quando não há senha;
- espera crescente com as mesmas constantes de `auth.ex:36-37` e `:162-165`;
- **sem concessão vigente não registra falha**: a credencial pode estar certa, e é o papel que caiu
  (forma de `auth.ex:90-93`);
- o sucesso zera as falhas **depois** de registrar quantas apagou, e grava `logged_in_at`.

Cada recusa gera `AccessEvents.operador_entrada_recusada/2` com o motivo interno
(`:identificador_nao_resolveu`, `:senha_errada`, `:sem_senha`, `:sem_concessao`).

## `definir_senha(email, codigo :: TheBand.Segredo.t(), senha :: String.t()) :: {:ok, Operator.t()} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}} | {:error, Ecto.Changeset.t()}`

- o código chega como `Segredo.t()` (FR-006 da 064): um `FunctionClauseError` não o imprime;
- confere `sha256(codigo)` contra `setup_code_hash` com `Plug.Crypto.secure_compare/2`, e
  `setup_code_expires_at` no futuro;
- código errado, vencido, ausente ou e-mail inexistente: **a mesma** recusa única, e conta falha;
- `{:error, changeset}` só depois de o código conferir, e só pela política de senha (12 a 128);
- no sucesso, numa transação: grava `password_hash`, sobe `password_epoch` de forma atômica, apaga
  `setup_code_hash` e `setup_code_expires_at`, e encerra toda sessão aberta do operador.

## `emitir_codigo(Operator.t()) :: {:ok, TheBand.Segredo.t()}` — interna ao contexto

Chamada só por `TheBand.Platform.Grants` (contrato em `concessao-do-operador.md`). 20 bytes
aleatórios, base32 minúscula; grava `sha256` e a validade de 30 minutos, **substituindo** o código
anterior. Devolve o bruto **uma vez**, como `Segredo.t()`.

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| nenhuma função recebe senha que não venha do navegador do operador | O11: senha não passa por comando, ambiente nem log |
| nenhuma função devolve o hash, o código gravado nem a época | quem precisa decidir chama `autenticar/2`; o resto é estado interno |
| não há `change_password(atual, nova)` | trocar a senha é pedir um código novo pelo comando. Para uma ou duas pessoas, um caminho só é menos superfície que dois |
| não há bloqueio de conta | bloqueio é negação de serviço para quem souber o e-mail (forma de `auth.ex:20-23`) |
| nenhuma função aceita `%User{}`, e nenhuma função de `TheBand.Tenants` aceita `%Operator{}` | é o que mantém as duas autenticações sem ponto de contato (FR-011) |
| não há segundo fator | risco residual O16; pergunta 2 do plano |
