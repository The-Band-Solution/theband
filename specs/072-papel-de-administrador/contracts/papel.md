# Contrato — a marca de administrador

## `TheBand.Tenants.promote_user(%Tenant{}, user_id, %User{} = actor, opts) :: {:ok, episodio} | {:error, motivo}`
## `TheBand.Tenants.demote_user(%Tenant{}, user_id, %User{} = actor, opts) :: {:ok, episodio} | {:error, motivo}`

`opts`: `note: String.t() | nil`. Uma transação, nesta ordem:
1. o guarda de R1;
2. a escrita de `users.role` por `update_all` condicional;
3. o episódio;
4. depois do `commit`, o aviso (só no rebaixamento) e o evento.

| motivo | quando |
|---|---|
| `:nao_autorizado` | o ator não é admin ativo da organização, relido sob a trava |
| `:not_found` | a conta não é da organização. A tela diz "não encontrada" (FR-003) |
| `:ultimo_admin_ativo` | rebaixar o único admin ativo |
| `{:estado_mudou, episodio \| nil}` | promover quem já é admin, ou rebaixar quem já é membro. Volta com o último episódio da conta, para a frase de D5 do protótipo; `nil` quando a conta não tem episódio. Corrigido na T006: o texto dizia `:estado_mudou` e "volta com", e um átomo não volta com nada |
| `:conta_desativada` | promover conta desativada. Rebaixar desativada é permitido (Q1) |

Nenhum retorno carrega a struct do ator.

## `TheBand.Tenants.role_changes(%Tenant{}, opts) :: %{mudancas: [episodio], total: integer()}`

Os episódios da organização, do mais novo ao mais antigo, `limit: 20` por padrão (Q5), mais a
contagem total (corrigido na T010: o cabeçalho dizia `[episodio]`, e uma lista não carrega a
contagem). Quem mudou e quem agiu vêm carregados só com id, nome e e-mail. Só lê; quem chama é a tela de contas, já atrás de `require_admin`.

## `TheBand.Tenants.role_summary(%Tenant{}, user_ids) :: %{user_id => %{ate_admin: episodio | nil, ate_membro: episodio | nil}}`

Para a célula `Management` (T011), e acrescentada ao contrato antes do código dela: o último
episódio de cada conta **para** `admin` e o último **para** `member`, numa consulta só. Conta sem
episódio fica fora do mapa. A tela não completa a ausência: sem episódio, ela diz "no role change
recorded" (Q6), e não "never an administrator" nem "since the organisation was created", que
afirmariam o que ninguém registrou — o registro começa com a 072.

## `TheBand.Tenants.PapelDeAdministrador.exigir_ator(tenant_id, actor_id) :: :ok | {:error, :nao_autorizado}`

Pública só para os módulos de `Tenants` (R2). Relê no banco, sem lock.

## Eventos (`AccessEvents`)

`ato_administrativo(:conta_promovida | :conta_rebaixada, sobre_user_id, tenant_id, por: actor_id,
de:, para:)` no sucesso, e `ato_administrativo(:papel_recusado, …, motivo:)` na recusa (S9).

## O que NÃO se expõe

| ausência | por quê |
|---|---|
| promover pela API ou pelo MCP | a API é só leitura (061, FR-017) |
| razão de lista fechada | decisão da spec; o registro de quem, quando e de-para basta |
| apagar ou editar um episódio | somente-acréscimo, garantido no banco |
