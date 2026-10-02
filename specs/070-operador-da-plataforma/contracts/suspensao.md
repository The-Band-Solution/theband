# Contrato — `TheBand.Platform`: listar, suspender e reativar

FR-003 a FR-010, FR-013 a FR-015, O6, O8, O9, O10. Transação em [research.md](../research.md) R8;
tabelas em [data-model.md](../data-model.md) §4 a §6.

`TheBand.Platform` é a fachada (`defdelegate`), e `TheBand.Platform.Suspensions` faz o trabalho.
Depende de: nenhuma ontologia. Usa `TheBand.Tenants`, `TheBand.Tenants.Sessions` e
`TheBand.Tenants.ApiTokens` **só pelas funções públicas** de `sessoes-e-tokens-da-organizacao.md`
(`Tenants.trocar_estado_no_multi/5`, `Tenants.resumos_para_a_plataforma/0`,
`Tenants.resumo_para_a_plataforma/1`, `Sessions.encerrar_da_organizacao/1`,
`ApiTokens.revogar_por_suspensao/2`) e por `Tenants.fetch/1`, que já existe (`tenants.ex:72-78` de
`development`). **Não lê nem escreve a tabela `tenants`**, nem usa o schema `Tenant` em consulta:
constituição, princípio X, letra D (achado D1 do `/speckit-analyze`, 2026-10-01). As tabelas que
este módulo consulta são as da `Platform`: `tenant_suspensions`, `platform_operator_sessions` e
`platform_operator_grants`.

**Toda função recebe a sessão do operador, e confere a autorização por dentro** (FR-014, O6): a
sessão aberta e no prazo, e a concessão vigente. Ter passado pelo plug não basta.

> **Emendado em 2026-10-01** pela avaliação da segunda autenticação: **A2** (o aviso às telas
> abertas é o do #1044, depois do `commit`) e **A15** (`FOR SHARE` também na linha da sessão). O
> código de `suspender/3` e `reativar/3` esperava o PR #1044 em `development`: **mergeado** em
> 2026-10-01 (T001 reconfere no dia da implementação).
>
> **Emendado em 2026-10-01** pelo `/speckit-analyze` (achado D1): esta `Platform` não toca a tabela
> `tenants`; o estado muda por `Tenants.trocar_estado_no_multi/5` e a lista lê
> `Tenants.resumos_para_a_plataforma/0` (`sessoes-e-tokens-da-organizacao.md`).

Na transação de `suspender/3` e de `reativar/3`, o passo `:autorizacao` lê **com `FOR SHARE`** a
linha da sessão do operador **e** a da concessão vigente. A revogação (`UPDATE` na concessão) e o
reinício de credencial (`FOR UPDATE` nas sessões, `concessao-do-operador.md`) se serializam com o
ato em voo, e o ato que perde recusa com `:nao_autorizado`.

## `listar_organizacoes(OperatorSession.t()) :: {:ok, [resumo]} | {:error, :nao_autorizado}`

`resumo :: %{id, name, slug, status, ultimo_episodio_em :: DateTime.t() | nil}`. **Duas consultas,
cada uma na tabela do seu dono**, compostas em memória pelo `id`:

1. `Tenants.resumos_para_a_plataforma/0`: `id`, `name`, `slug` e `status`, com o `select` explícito
   do lado de `Tenants` (`sessoes-e-tokens-da-organizacao.md`);
2. a da própria `Platform`, em `tenant_suspensions`: o `suspended_at` mais recente por `tenant_id`
   (`group_by` com `max/1`, uma linha por organização que já teve episódio), lido num mapa.

Nunca `%Tenant{}` inteiro nem `Tenants.list_tenants/0` (`tenants.ex:69-70` de `development`), que
devolveria a struct com `has_many :users` ao alcance de um `preload`; e nunca `join` com `tenants`
nesta consulta (princípio X, D). A composição é um `Map.get/2` por resumo, sem consulta por
organização (sem N+1). `nil` em `ultimo_episodio_em` é "nunca suspensa", e a tela escreve isso com
`<.absent>`.

## `organizacao(OperatorSession.t(), slug) :: {:ok, %{resumo, episodios :: [Suspension.t()]}} | {:error, :not_found | :nao_autorizado}`

O resumo vem de `Tenants.resumo_para_a_plataforma/1` (slug inexistente: `:not_found`); o histórico,
da `tenant_suspensions` pelo `id` do resumo, do mais novo para o mais antigo, com as razões
traduzidas por `SuspensionReasons.rotulo/1`.

## `suspender(OperatorSession.t(), tenant_id, %{reason: String.t(), note: String.t() | nil}) :: {:ok, Suspension.t()} | {:error, motivo}`

O `%Tenant{}` que as funções de `Tenants` recebem vem de `Tenants.fetch/1`, **antes** do `Multi`
(`{:error, :not_found}` daí é o `:not_found` da tabela abaixo). O passo `:estado` do `Multi` é
`Tenants.trocar_estado_no_multi(multi, :estado, tenant, "active", "suspended")`, e
`{:error, :estado_mudou}` dele vira `{:error, :ja_suspensa}`; `{:error, :not_found}` dele (a
organização sumiu entre a leitura e o passo) continua `:not_found`.

| retorno | quando |
|---|---|
| `{:ok, episodio}` | estado `suspended`, episódio aberto, toda sessão da organização com `ended_at`, todo token vigente revogado com `organizacao_suspensa` — **na mesma transação** |
| `{:error, :nao_autorizado}` | sessão encerrada, vencida, ou concessão revogada, lidas dentro da transação |
| `{:error, :not_found}` | organização inexistente |
| `{:error, :ja_suspensa}` | `Tenants.trocar_estado_no_multi/5` devolveu `:estado_mudou`, ou o índice parcial recusou o episódio |
| `{:error, :vocabulario_nao_declarado}` | a regra `platform.tenant_suspension` não está na base |
| `{:error, %Ecto.Changeset{}}` | razão fora da lista, ou nota ausente onde a base a exige. **Nada muda** |

Depois do `commit`, **e só depois**:

1. para cada id que `Sessions.encerrar_da_organizacao/1` devolveu,
   `TheBand.Tenants.Sessions.avisar_encerramento({:sessao, id})` (A2, mecanismo do #1044). A hook de
   domínio inscrita em `"sessao:<id>"` reconfere a sessão no banco, e o banco decide. **Não** se cria
   tópico por organização: o aviso por id alcança exatamente as telas das sessões encerradas, e não
   amplia o que cada socket escuta;
2. `AccessEvents.ato_de_plataforma(:organizacao_suspensa, tenant_id, …)` com as contagens de sessões
   e tokens.

Avisar **dentro** da transação seria avisar antes de o banco dizer que a sessão acabou: a hook
reconferiria, acharia a sessão aberta, e a tela continuaria.

## `reativar(OperatorSession.t(), tenant_id, %{reason:, note:}) :: {:ok, Suspension.t()} | {:error, motivo}`

Mesmos erros, com `:nao_suspensa` no lugar de `:ja_suspensa` (o `:estado_mudou` de
`Tenants.trocar_estado_no_multi(multi, :estado, tenant, "suspended", "active")`) e
`:sem_episodio_aberto` se o estado for `suspended` sem episódio (só possível por escrita externa; a migração fecha o passado com
`not_recorded`). Fecha o episódio, volta a `active` e **encerra de novo** toda sessão aberta da
organização (FR-015). **Nenhum token volta** (FR-013).

Depois do `commit`, o mesmo aviso por id de `suspender/3`, para cada sessão que a reativação
encerrou (A2): é a sessão gravada na corrida O8, que pode ter uma tela aberta, e o evento
`ato_de_plataforma(:organizacao_reativada, …)`.

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| suspender várias ou todas de uma vez | FR-008: a recusa vale por ato, um por organização, com razão |
| qualquer leitura de `users`, `eo_*`, `spo_*`, `cmpo_*` ou demais tabelas de domínio | FR-007, SC-003; a guarda de telemetria (research R10) reprova se uma consulta dessas acontecer |
| a contagem de pessoas ou de contas de cada organização | é dado da organização, e a FR-007 lista o que o operador vê |
| apagar episódio, ou reescrever a abertura | FR-006; trigger (research R7) |
| devolver os tokens na reativação | FR-013 |
| escrever `tenants.status` por outro caminho | O10: `:status` sai do `cast`, o `CHECK` recusa valor fora da lista, e a única escrita é `Tenants.trocar_estado_no_multi/5`, dentro deste `Multi` |
| ler ou escrever a tabela `tenants` direto, ou usar o schema `Tenant` numa consulta | constituição, princípio X, letra D (achado D1): `Platform` depende da fronteira pública de `Tenants` |
| aceitar `%User{}` como autor | o autor é o operador, e o tipo diz isso |
| criar, renomear ou apagar organização | fora de escopo da spec |
