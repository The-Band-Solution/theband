# Contrato — o que muda nos outros módulos

Cada função nova é pública na fachada do dono, com `@doc`, `@spec` e teste com dois tenants. Nenhum
módulo de fora toca schema ou `Repo` alheio (ADR 0003, princípio X letra D).

## `TheBand.WorkItems`

### `assignment_pairs/3` (nova)

```elixir
@spec assignment_pairs(Tenant.t(), repository_ids :: [Ecto.UUID.t()], since: DateTime.t()) ::
        [%{collected_issue_id: Ecto.UUID.t(), opened_at: DateTime.t(),
           author_person_id: Ecto.UUID.t() | nil, author_account_type: String.t() | nil,
           assignee_person_id: Ecto.UUID.t() | nil, assignee_account_type: String.t() | nil}]
```

Um elemento por par (issue, responsável **vigente**) de issue aberta (`external_created_at`) desde
`since`, nos repositórios dados; issue sem responsável vigente aparece **uma vez** com
`assignee_* = nil` (para a contagem de issues sem designação). Filtros: `i.tenant_id`, `a.tenant_id`,
`p_autor.tenant_id`, `p_resp.tenant_id` (joins à esquerda com a condição de tenant no `on`),
`i.observed_repository_id in ^ids`, `is_nil(a.no_longer_observed_at)`,
`is_nil(i.no_longer_observed_at)`. **Não lê `author_login` nem `issue_assignees.login`** (R9).
Ordenado por `(opened_at, collected_issue_id, assignee_person_id)`.

**Não expõe**: login, título, corpo, estado da issue. Repositório fora da lista nunca entra.

**Emenda de 2026-10-04 (T023)**, feita no mesmo commit da implementação: cada elemento ganha
`assigned: boolean()`. Sem ele, a issue sem responsável (`assignee_* = nil`) e o responsável não
ligado de linha antiga (pessoa nula **e** tipo gravado nulo) teriam a mesma forma, e a
classificação contaria um como o outro. As pessoas são lidas pela tabela `eo_people`, sem o
schema de EO, como `Quality.review_pairs/3` lê as avaliações: só o id, para o filtro de tenant. A
ordem desempata também pelo id da linha de `issue_assignees`, para a saída ser estável quando
dois responsáveis não ligados dão `assignee_person_id` nulo. Lista de repositórios vazia devolve
`[]` sem consultar.

### Coleta — `replace_assignees/3` e `record_collected_issue/2` (mudam)

Passam a aceitar `account_type` por responsável e `author_account_type` na issue (R13). O
chamador (`Ingestion.GithubWorkItems`) os calcula por `Mapper.account_type/1` sobre o nó.

## `TheBand.ReviewNetwork` (073)

### `current_edges/2` (nova)

```elixir
@spec current_edges(Tenant.t(), organization_id :: Ecto.UUID.t()) ::
        %{pos_integer() => %{edges: [%{source: Ecto.UUID.t(), target: Ecto.UUID.t(), weight: pos_integer()}],
                             excluded: %{atom() => non_neg_integer() | nil},
                             reviews: non_neg_integer(),
                             computed_at: DateTime.t()}}
```

As leituras vigentes por janela, só com ids: `source` = revisor, `target` = autor, `weight` =
solicitações distintas. Mapa vazio quando não há leitura. **Não** aplica alcance: é para o cálculo,
não para a tela.

### `discard_organization/2` (nova)

Apaga as leituras da organização (R18). Chamada por `Sources.end_observation/3`.

### `Commands.substituir/3` (muda — R10 da segurança, A18)

`Repo.insert/1` em vez de `insert!`; no erro, `Repo.rollback({:reading_rejected, campos})` com só os
nomes dos campos do changeset. `compute/3,4` passam a devolver `{:ok, relator} | {:error,
{:reading_rejected, [atom()]}}`, e o job cancela com esse motivo. Nenhum `{:ok, _} =` sobre termo
que contenha a leitura.

### A7 (opção padrão, a confirmar) — `Classification`

Recebe também o conjunto de contas declaradas da organização e ganha o destino
`:organization_account` entre `:bot_or_app` e `:unlinked_person`, pela ordem de
`review.network.edge` versão 2. `Parameters` confere a ordem nova.

### `ComputeReviewNetwork` (muda)

Depois do `compute/3` com sucesso, enfileira `ComputeNetworkAnalysis.enqueue(tenant_id,
organization_id)` (R3). Escrito ao lado da linha.

## `TheBand.Tenants`

### `pessoas_alcancadas/3` (nova aridade, mesma função)

```elixir
@spec pessoas_alcancadas(Tenant.t(), User.t(), origem: :concedida) :: :todas | {:algumas, MapSet.t()}
```

Como `pessoas_alcancadas/2`, mas só com os escopos `origin: :granted`; a própria pessoa entra; a
administração deste tenant é `:todas`. A `/2` não muda (R11, DS1).

### Contas da organização (novas, R14)

```elixir
@spec declare_organization_account(Tenant.t(), person_id :: term(), reason :: String.t(), actor :: User.t()) ::
        {:ok, declaration} | {:error, :not_admin | :not_found | :linked_to_platform_account | :own_person | Ecto.Changeset.t()}
@spec revoke_organization_account(Tenant.t(), declaration_id :: term(), actor :: User.t()) ::
        {:ok, declaration} | {:error, :not_admin | :not_found}
@spec organization_account_ids(Tenant.t()) :: MapSet.t()
@spec list_organization_accounts(Tenant.t(), actor :: User.t()) :: {:ok, [declaration_view]} | {:error, :not_admin}
```

Administração relida no banco (`PapelDeAdministrador.exigir_ator/2`). `:not_found` igual para pessoa
de outro tenant, inexistente e id malformado. Declarar e revogar emitem evento em `AccessEvents`
com tenant, conta que agiu, pessoa e resultado — inclusive a recusa.

**Não expõe**: a lista para quem não administra; a declaração não muda `eo_people.account_type`.

## `TheBand.Ontology.SEON.EO`

Sem função nova. Usadas: `fetch_organization/2`, `account_types/2`, `organization_person_ids/2`,
`people_names/2` (073).

## `TheBand.Ontology.SEON.CMPO`

Sem função nova. `list_observed/2` com `organization_id:` (073).

## `TheBand.Sources`

`end_observation/3`, na transação, chama `NetworkAnalysis.discard_organization/2` e
`ReviewNetwork.discard_organization/2` com a organização encerrada (R18).

## `TheBandWeb`

- `Layouts`: item **Network analysis** e `{"/network-analysis", :network_analysis}` em `@nav_areas`;
- `Router`: as rotas de [tela.md](tela.md);
- `ReviewNetworkLive.Show`: montada também em `/network-analysis/:organization_id` e com a ação
  `:legacy` no endereço antigo;
- `PeopleLive.Show` e `PeopleLive.Index`: o controle e a lista das contas da organização, só para a
  administração;
- `VerificationLive.People`: a frase do aviso de recorte corrigida (DS4, #1185).
