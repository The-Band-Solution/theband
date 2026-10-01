# Contrato — `TheBand.Platform`: listar, suspender e reativar

FR-003 a FR-010, FR-013 a FR-015, O6, O8, O9, O10. Transação em [research.md](../research.md) R8;
tabelas em [data-model.md](../data-model.md) §4 a §6.

`TheBand.Platform` é a fachada (`defdelegate`), e `TheBand.Platform.Suspensions` faz o trabalho.
Depende de: nenhuma ontologia. Usa `TheBand.Tenants.Sessions` e `TheBand.Tenants.ApiTokens` pelas
funções públicas de `sessoes-e-tokens-da-organizacao.md`, e lê `tenants` só pelas colunas `id`,
`name`, `slug` e `status`.

**Toda função recebe a sessão do operador, e confere a autorização por dentro** (FR-014, O6): a
sessão aberta e no prazo, e a concessão vigente. Ter passado pelo plug não basta.

## `listar_organizacoes(OperatorSession.t()) :: {:ok, [resumo]} | {:error, :nao_autorizado}`

`resumo :: %{id, name, slug, status, ultimo_episodio_em :: DateTime.t() | nil}`. Uma consulta, com
`LEFT JOIN LATERAL` sobre o último episódio. **Só essas colunas**: `select` explícito, e nunca
`%Tenant{}` inteiro nem `Tenants.list_tenants/0` (`tenants.ex:69-70`), que devolveria a struct com
`has_many :users` ao alcance de um `preload`. `nil` em `ultimo_episodio_em` é "nunca suspensa", e a
tela escreve isso com `<.absent>`.

## `organizacao(OperatorSession.t(), slug) :: {:ok, %{resumo, episodios :: [Suspension.t()]}} | {:error, :not_found | :nao_autorizado}`

O histórico, do mais novo para o mais antigo, com as razões traduzidas por
`SuspensionReasons.rotulo/1`.

## `suspender(OperatorSession.t(), tenant_id, %{reason: String.t(), note: String.t() | nil}) :: {:ok, Suspension.t()} | {:error, motivo}`

| retorno | quando |
|---|---|
| `{:ok, episodio}` | estado `suspended`, episódio aberto, toda sessão da organização com `ended_at`, todo token vigente revogado com `organizacao_suspensa` — **na mesma transação** |
| `{:error, :nao_autorizado}` | sessão encerrada, vencida, ou concessão revogada, lidas dentro da transação |
| `{:error, :not_found}` | organização inexistente |
| `{:error, :ja_suspensa}` | o `UPDATE` condicional não afetou linha, ou o índice parcial recusou o episódio |
| `{:error, :vocabulario_nao_declarado}` | a regra `platform.tenant_suspension` não está na base |
| `{:error, %Ecto.Changeset{}}` | razão fora da lista, ou nota ausente onde a base a exige. **Nada muda** |

Depois do `commit`: `AccessEvents.ato_de_plataforma(:organizacao_suspensa, tenant_id, …)` com as
contagens de sessões e tokens, e, se a pergunta 3 do plano for aceita, o `disconnect` de cada
socket.

## `reativar(OperatorSession.t(), tenant_id, %{reason:, note:}) :: {:ok, Suspension.t()} | {:error, motivo}`

Mesmos erros, com `:nao_suspensa` no lugar de `:ja_suspensa` e `:sem_episodio_aberto` se o estado
for `suspended` sem episódio (só possível por escrita externa; a migração fecha o passado com
`not_recorded`). Fecha o episódio, volta a `active` e **encerra de novo** toda sessão aberta da
organização (FR-015). **Nenhum token volta** (FR-013).

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| suspender várias ou todas de uma vez | FR-008: a recusa vale por ato, um por organização, com razão |
| qualquer leitura de `users`, `eo_*`, `spo_*`, `cmpo_*` ou demais tabelas de domínio | FR-007, SC-003; a guarda de telemetria (research R10) reprova se uma consulta dessas acontecer |
| a contagem de pessoas ou de contas de cada organização | é dado da organização, e a FR-007 lista o que o operador vê |
| apagar episódio, ou reescrever a abertura | FR-006; trigger (research R7) |
| devolver os tokens na reativação | FR-013 |
| escrever `tenants.status` por outro caminho | O10: `:status` sai do `cast`, e o `CHECK` recusa valor fora da lista |
| aceitar `%User{}` como autor | o autor é o operador, e o tipo diz isso |
| criar, renomear ou apagar organização | fora de escopo da spec |
