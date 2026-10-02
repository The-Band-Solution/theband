# Contrato — a sessão do operador

FR-011, FR-014, O6. Desenho em [research.md](../research.md) R3; tabela em
[data-model.md](../data-model.md) §3.

> **Emendado em 2026-10-01** pela avaliação da segunda autenticação: A11 (inatividade de 30 min) e
> A15 (`FOR SHARE` na linha da sessão). O gate de desenho está fechado.

Dois módulos, com uma razão para mudar cada um (princípio X):

- `TheBand.Platform.Sessions`: a linha no banco;
- `TheBandWeb.Plataforma.SessaoDoOperador`: o cookie. É o **único** leitor e escritor de
  `_the_band_operator`, e **nunca** lê `"session_id"` nem `"session_secret"`. `TheBandWeb.Sessao`,
  por sua vez, nunca lê `_the_band_operator`.

## `TheBand.Platform.Sessions`

### `abrir(Operator.t()) :: {:ok, {OperatorSession.t(), TheBand.Segredo.t()}} | {:error, Ecto.Changeset.t()}`

32 bytes, grava `sha256` e a `password_epoch` **da struct recebida** (a mesma leitura que conferiu
a senha), como `sessions.ex:48-71`. Devolve o bruto uma vez, como `Segredo.t()`.

### `conferir(id :: term(), segredo :: term()) :: {:ok, OperatorSession.t(), Operator.t()} | {:error, motivo}`

| motivo | quando |
|---|---|
| `:malformado` | id não é UUID, segredo não é `Segredo.t()`, ausência. Por cabeça de função, nunca `raise` |
| `:inexistente` | sem linha |
| `:resumo_errado` | `secure_compare` em memória falha |
| `:encerrada` | `ended_at` preenchido |
| `:vencida` | mais de **8 h** desde `inserted_at` |
| `:inativa` | mais de **30 min** desde `last_seen_at` (A11; ASVS V3.3.2) |
| `:epoca_velha` | época da linha diferente da do operador |
| `:sem_concessao` | o operador não tem concessão vigente, lida **na mesma consulta** |

Quem chama trata todos os motivos como uma recusa só; o motivo é para o log.

No sucesso, grava `last_seen_at = agora` com `update_all` condicional, no máximo uma vez por
minuto, para não escrever a cada requisição. As duas constantes (8 h e 30 min) são atributos
nomeados, com o motivo escrito.

### `autorizada(OperatorSession.t()) :: :ok | {:error, :nao_autorizado}`

**Emendado em 2026-10-02**, na implementação de `listar_organizacoes/1`. É a conferência "por
dentro" que `suspensao.md` exige de toda função de `TheBand.Platform` (FR-014, O6). Relê do banco a
sessão recebida, numa consulta só: aberta, menos de 8 h desde `inserted_at`, menos de 30 min desde
`last_seen_at`, época igual à do operador e concessão vigente. Qualquer falha é `:nao_autorizado`.
Não confere o segredo, que o plug já conferiu, nem grava `last_seen_at`.

O `FOR SHARE` do passo `:autorizacao` de `suspender/3` e `reativar/3` (A15) entra com eles, em T049.
Ele não entra antes, porque não haveria chamador que o provasse.

### `encerrar(OperatorSession.t()) :: :ok`

### `encerrar_do_operador(Operator.t()) :: {:ok, non_neg_integer()}`

Recebe `%Operator{}`, e não `operator_id` cru (antipadrão "primitivo no lugar do conceito"; mesma
razão de `encerrar_da_organizacao(%Tenant{})`). Grava `ended_at` em toda sessão aberta do operador e
devolve quantas. Roda **dentro da transação de quem chama**, e não abre a sua. Os chamadores, todos
em `TheBand.Platform`:

| chamador | contrato |
|---|---|
| `Grants.revogar/3` | `concessao-do-operador.md` (FR-014) |
| `Grants.conceder/3`, quando o operador já existe sem concessão vigente | `concessao-do-operador.md` (A6) |
| `Grants.reiniciar_credencial/2`, depois do `FOR UPDATE` nas sessões abertas (A15) | `concessao-do-operador.md` |
| `Credentials.definir_senha/3` | `credenciais-do-operador.md` (passo 1) |
| `Credentials.concluir_cadastro/2` | `credenciais-do-operador.md` (passo 3) |

`Release.encerrar_todas_as_sessoes/0` e `Release.girar_sessoes/0` **não** a chamam: encerram todas
as do operador numa função própria (`encerrar_todas/0`, abaixo), sem passar operador nenhum.

### `encerrar_todas() :: {:ok, non_neg_integer()}`

Grava `ended_at` em toda sessão de operador aberta. Só para o giro operacional de `TheBand.Release`
(T032); nenhum controller a chama.

### `apagar_as_que_deixaram_de_valer(DateTime.t()) :: {:ok, non_neg_integer()}`

Chamada por `TheBand.Jobs.ApagaSessoesAntigas` junto da de `user_sessions`. Único caminho que apaga.

## `TheBandWeb.Plataforma.SessaoDoOperador`

### `conferir(Plug.Conn.t()) :: {:ok, OperatorSession.t(), Operator.t()} | {:error, motivo, operator_id | nil}`

Lê `_the_band_operator` com `fetch_cookies(conn, encrypted: [...])`.

### `abrir(Plug.Conn.t(), Operator.t()) :: Plug.Conn.t()`

`put_resp_cookie("_the_band_operator", %{"id" => …, "secret" => …}, encrypt: true, http_only: true,
secure: Application.get_env(:the_band, :cookie_de_sessao_seguro, false), same_site: "Strict",
path: "/platform", max_age: 8 * 3600)`.

### `soltar(Plug.Conn.t()) :: Plug.Conn.t()`

`delete_resp_cookie` com o mesmo `path`.

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| nenhuma função de sessão do operador aceita `%User{}`, e as de `TheBand.Tenants.Sessions` não aceitam `%Operator{}` | FR-011: dois leitores, nenhum ponto de contato |
| não há `girar_todas/0` público fora do giro | a revogação encerra por operador. O giro operacional encerra **também** as do operador, por `encerrar_todas/0`, chamada **só** por `Release.encerrar_todas_as_sessoes/0` (aplicação parada, por `eval`) e por `Release.girar_sessoes/0` (aplicação no ar, por `rpc`, criada pela #1050, PR #1051). A sessão do operador é de controller, sem socket, e não precisa do aviso por PubSub: a próxima requisição confere a linha |
| `dona/1` não existe aqui | o log da recusa leva o `operator_id` que `conferir/1` devolve no erro; não há outra leitura |
| a sessão do operador não vai para `Plug.Session` | se fosse, chegaria a toda rota e todo socket de domínio, e cairia com o `drop` da saída de domínio (research R3.2) |
