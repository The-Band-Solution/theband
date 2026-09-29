# Contrato — `TheBand.Tenants.Sessions` (T011)

FR-004, FR-006, FR-015. Desenho em [data-model.md](../data-model.md). Achados em
[seguranca-us2.md](../seguranca-us2.md): S1, S2, S4, S6, S8 e S11.

A leitura da sessão pela tabela nova é da **T013**. Esta tarefa entrega o módulo, e a única
chamada que ele já recebe é a da desativação de conta (S1).

## `abrir(%User{}) :: {:ok, {UserSession.t(), Segredo.t()}} | {:error, Ecto.Changeset.t()}`

Gera 32 bytes aleatórios. Grava **só** `sha256(bruto)`, junto com o `tenant_id`, o `user_id` e o
`password_epoch` **da struct recebida**. A struct é a da mesma leitura que conferiu a senha.
Assim, uma senha definida entre essa leitura e a gravação deixa a sessão nascer com a época
velha, e ela já nasce recusada (S2, a corrida).

O bruto é devolvido **como `Segredo.t()`** (S11), e só volta a ser binário no `put_session` da
T013. Nunca é persistido e nunca é logado.

## `conferir(id, Segredo.t()) :: {:ok, UserSession.t()} | {:error, motivo}`

| motivo | quando |
|---|---|
| `:malformado` | `id` não é UUID, o segredo não é `Segredo.t()`, ou qualquer um dos dois está ausente. **Recusa por cabeça de função**, e nunca `raise` (S4) |
| `:inexistente` | não há linha com esse `id` |
| `:resumo_errado` | `sha256(bruto)` difere de `token_hash`, comparado por `Plug.Crypto.secure_compare/2` **em memória** |
| `:encerrada` | `ended_at` preenchido |
| `:vencida` | `inserted_at` mais velho que **7 dias**, contados da abertura **desta** sessão, e não do último login da conta (S6, P2) |
| `:epoca_velha` | `password_epoch` da linha diferente do de `users` |

A busca é pela **chave primária** (S8, na forma da ADR 0010), e a época de `users` vem na mesma
consulta, por junção. A ordem das cláusulas não muda a resposta: **quem chama trata todos os
motivos como uma recusa só**. O motivo existe para o log interno, como em
`ApiTokens.autenticar/1`.

**Não confere** se a conta está ativa nem se a organização está ativa. Isso continua no plug e
na hook, como hoje. A desativação encerra as sessões (abaixo), então uma conta reativada não
recupera nenhuma.

## `encerrar(UserSession.t()) :: :ok`

Grava `ended_at` naquela sessão. Encerrar uma sessão já encerrada não muda a data.

## `encerrar_da_conta(tenant_id, user_id) :: {:ok, non_neg_integer()}`

Grava `ended_at` em toda sessão aberta da conta e devolve quantas encerrou. É chamada **dentro
da transação** de `Tenants.disable_user/4`, junto com o episódio (S1). A T013 também a chama nas
definições de senha.

## `girar_todas() :: {:ok, non_neg_integer()}`

Grava `ended_at` em toda sessão aberta, de todos os tenants. É o giro operacional (T016) e o
passo **obrigatório** depois de restaurar um backup (P5).

## O que o módulo NÃO faz, e por quê

- **Não apaga.** Todo encerramento é `ended_at`. Apagar é da retenção, na T020, 90 dias depois.
- **Não devolve o `user`.** Quem chama já busca a conta, com o tenant pré-carregado, e
  duplicar essa leitura aqui criaria duas fontes para a mesma decisão.
- **Não distingue a recusa para fora.** Os motivos acima são para o log. Na tela a queda é uma
  só, como hoje.
