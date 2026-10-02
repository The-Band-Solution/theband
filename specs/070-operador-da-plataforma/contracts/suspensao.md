# Contrato — `TheBand.Platform`: listar, suspender e reativar

FR-003 a FR-010, FR-013 a FR-015, O6, O8, O9, O10. Transação em [research.md](../research.md) R8;
tabelas em [data-model.md](../data-model.md) §4 a §6.

`TheBand.Platform` é a fachada (`defdelegate`), e `TheBand.Platform.Suspensions` faz o trabalho.
Depende de: nenhuma ontologia. Usa `TheBand.Tenants`, `TheBand.Tenants.Sessions` e
`TheBand.Tenants.ApiTokens` **só pelas funções públicas** de `sessoes-e-tokens-da-organizacao.md`
(`Tenants.trocar_estado_no_multi/5`, `Tenants.resumos_para_a_plataforma/0`,
`Tenants.resumo_para_a_plataforma/1`, `Sessions.encerrar_da_organizacao/1`,
`ApiTokens.revogar_por_suspensao/2`) e por `Tenants.get_by_slug/1`, que já existe (`tenants.ex:92-93`
de `development`, conferido em `origin/development` em 2026-10-01; emenda U1, abaixo). **Não lê nem escreve a tabela `tenants`**, nem usa o schema `Tenant` em consulta:
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
>
> **Emendado em 2026-10-01** pela reanálise (achado **U1**): `suspender/3` e `reativar/3` recebiam
> `tenant_id` cru, e as rotas têm `:slug`. Passam a receber **o slug**, e quem o resolve é
> `Suspensions`, com **uma** leitura de `tenants` por ato (`Tenants.get_by_slug/1`). O controller
> não lê `tenants` nos dois `POST`: entrega o `:slug` da rota. Receber o resumo de
> `resumo_para_a_plataforma/1` foi recusado porque o passo `:estado` e as funções de `Tenants`
> recebem `%Tenant{}`, e o resumo obrigaria a uma segunda leitura (`fetch/1` pelo `id`) — duas
> leituras da mesma linha por ato, e uma janela entre elas. E o banco ganhou o invariante
> "estado só com episódio" (achado **D1-a**, decisão da pessoa mantenedora; `data-model.md` §4a).

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

## `suspender(OperatorSession.t(), slug :: String.t(), %{reason: String.t(), note: String.t() | nil}) :: {:ok, Suspension.t()} | {:error, motivo}`

Recebe o `:slug` da rota, e não `tenant_id` nem o resumo (U1). O `%Tenant{}` que as funções de
`Tenants` recebem vem de **`Tenants.get_by_slug/1`**, chamada **uma vez**, por `Suspensions`, antes do
`Multi` (`nil` daí é o `:not_found` da tabela abaixo). É a **única** leitura de `tenants` dentro do
ato: o controller não chama `resumo_para_a_plataforma/1` antes, e o passo `:estado` não relê a linha,
porque a condição de estado está no `WHERE` do `UPDATE`. Na recusa, o controller lê o resumo
**depois**, para re-renderizar; no sucesso, redireciona (`rotas-da-plataforma.md`, U3). A struct **não sai** de `Suspensions`: nenhum
retorno, sucesso ou recusa, a contém (D1-d; afirmado em T049). O controller responde `404` a
`:not_found` e a `:nao_autorizado`, mas **não** igualmente: `:nao_autorizado` encerra o cookie e
`:not_found` não (`rotas-da-plataforma.md`). Como o slug é lido antes de `:autorizacao`, um operador
cuja concessão foi revogada **no meio do ato** distingue, pelo cookie que sobrevive ou não, se o slug
existia. Fica assim, declarado (achado U2): quem distingue é alguém que tinha o papel um instante
antes e via a lista inteira de organizações, então o que ele aprende já sabia; o impacto é
desprezível. Encerrar o cookie também no `:not_found` foi recusado porque derrubaria a sessão do
operador por um slug digitado errado. O passo `:estado` do `Multi` é
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

## `reativar(OperatorSession.t(), slug :: String.t(), %{reason:, note:}) :: {:ok, Suspension.t()} | {:error, motivo}`

O slug é resolvido como em `suspender/3`: uma leitura, por `Tenants.get_by_slug/1`, antes do `Multi`.

Mesmos erros, com `:nao_suspensa` no lugar de `:ja_suspensa` (o `:estado_mudou` de
`Tenants.trocar_estado_no_multi(multi, :estado, tenant, "suspended", "active")`) e
`:sem_episodio_aberto` se o estado for `suspended` sem episódio. Desde o trigger adiado
(`data-model.md` §4a, D1-a) esse estado não se confirma por caminho nenhum, nem por `eval`; o retorno
fica como defesa e só é alcançável com o trigger desligado por quem tem o banco. A migração fecha o
passado com `not_recorded` antes de o trigger existir. Fecha o episódio, volta a `active` e **encerra de novo** toda sessão aberta da
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
| escrever `tenants.status` por outro caminho | O10: `:status` sai do `cast`, o `CHECK` recusa valor fora da lista, e a única escrita é `Tenants.trocar_estado_no_multi/5`, dentro deste `Multi`. Uma escrita por fora (`change/2`, `force_change/3`, `update_all`, `eval`) que deixe o estado sem o episódio correspondente é recusada **no `COMMIT`** pelo trigger adiado (`data-model.md` §4a, D1-a) |
| `suspender` ou `reativar` por `tenant_id` | as rotas têm `:slug`, e quem resolve é `Suspensions`, numa leitura só (U1) |
| ler ou escrever a tabela `tenants` direto, ou usar o schema `Tenant` numa consulta | constituição, princípio X, letra D (achado D1): `Platform` depende da fronteira pública de `Tenants` |
| aceitar `%User{}` como autor | o autor é o operador, e o tipo diz isso |
| criar, renomear ou apagar organização | fora de escopo da spec |
