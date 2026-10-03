# Contrato — o que muda nas fronteiras de outros módulos

A rede lê por cinco APIs públicas, e quatro delas ganham uma função ou opção. Razão de cada uma em
[research.md R4](../research.md#r4--a-organização-e-as-consultas-sem-furar-fronteira). Toda função
recebe `%Tenant{}` e filtra **cada tabela** que toca pelo tenant (princípio V; R12 da segurança).

---

## `TheBand.Quality.review_pairs/3` (nova)

```elixir
@spec review_pairs(Tenant.t(), observed_repository_ids :: [Ecto.UUID.t()],
                   opts :: [since: DateTime.t(), states: [String.t()]]) :: [review_pair()]

@type review_pair :: %{
        change_request_id: Ecto.UUID.t(),
        reviewer_person_id: Ecto.UUID.t() | nil,
        reviewer_login: String.t() | nil,
        reviewer_type: String.t() | nil,     # __typename cru
        author_person_id: Ecto.UUID.t() | nil,
        author_login: String.t() | nil,
        last_submitted_at: DateTime.t()
      }
```

Uma consulta, agrupada por **(conta revisora, solicitação)**, com `max(external_submitted_at)`.

- `where a.tenant_id == ^t and c.tenant_id == ^t`, e o join é `a.collected_change_request_id ==
  c.id and a.tenant_id == c.tenant_id` (A1, A2: retirar **qualquer um** dos dois filtros reprova um
  teste);
- `c.observed_repository_id in ^ids`; lista vazia devolve `[]` sem consultar;
- `a.state in ^states` (lista de inclusão vinda da regra; nunca *"diferente de PENDING"*),
  `not is_nil(a.external_submitted_at)`, `a.external_submitted_at >= ^since`;
- `is_nil(a.no_longer_observed_at) and is_nil(c.no_longer_observed_at)`.

**Não expõe**: corpo da revisão, estado por par, título da solicitação. **Não classifica**: bot,
pessoa e auto-revisão são decisão da rede, com a regra da base. Os logins existem no retorno só
porque a classificação da conta não ligada precisa deles; o contrato de `ReviewNetwork` garante
que não passam dali.

## `TheBand.Quality.by_reviewer/2` (removida)

Ranking de revisores por login, sem alcance e sem chamador. Removida em commit próprio
([research.md R13](../research.md#r13--qualitybyreviewer2-sai-nesta-feature)).

---

## `TheBand.Changes.change_request_authors/3` (nova)

```elixir
@spec change_request_authors(Tenant.t(), observed_repository_ids :: [Ecto.UUID.t()],
                             opts :: [since: DateTime.t()]) ::
        [%{author_person_id: Ecto.UUID.t(), last_opened_at: DateTime.t()}]
```

Quem **abriu** solicitação nos repositórios dados, a partir de `since`, só com pessoa ligada
(`not is_nil(c.author_person_id)`), agrupado por pessoa com `max(external_created_at)`.
`c.tenant_id` filtrado, `no_longer_observed_at` nulo. É o que põe na lista quem abriu e ninguém
revisou (US2, cenário 2).

**Não expõe**: quais solicitações, quantas, nem título.

---

## `TheBand.Ontology.SEON.EO` — três funções novas

### `fetch_organization/2`

```elixir
@spec fetch_organization(Tenant.t(), Ecto.UUID.t()) :: {:ok, Organization.t()} | {:error, :not_found}
```

Por id **e** tenant juntos. Id malformado é `{:error, :not_found}`, e não exceção. É a versão sem
`!` de `fetch_organization!/2` (`eo/queries.ex:768-773`), que continua para quem já a usa.

### `account_types/2`

```elixir
@spec account_types(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => String.t()}
```

`"person" | "bot" | "app"`, uma consulta, `p.tenant_id` filtrado. Id de outro tenant não aparece no
mapa, e quem chama o trata como **não ligada** (falha fechada).

### `organization_person_ids/2`

```elixir
@spec organization_person_ids(Tenant.t(), Ecto.UUID.t()) :: [Ecto.UUID.t()]
```

As pessoas `account_type = "person"` da organização, pelo caminho que EO já define para "pessoa de
uma organização" (`filter_organization/2`, `eo/queries.ex:1044-1058`). Uma consulta.

**Não expõe**: nome, login, equipe.

---

## `TheBand.Ontology.SEON.CMPO.list_observed/2` (opção nova)

`organization_id:` filtra `r.organization_id` **no banco**. A consulta já seleciona o campo
(`cmpo/queries.ex:39`). A rede chama com `organization_id:` e descarta os `excluded_at` não nulos,
como `Verification.by_organization/1` (`verification.ex:762-763`): repositório tirado da observação
não entra na rede.

---

## `TheBand.Tenants.pessoas_alcancadas/2` (sem mudança, dependência)

Usada como está, **depois** da #1181 (`2535f6d` em `development`). Ver
[research.md R6](../research.md#r6--o-alcance-pessoas_alcancadas2-e-não-pode_ver3).

## `TheBand.Jobs.SyncGithubEo` (uma linha nova)

`coletar_mudancas/1` enfileira `ComputeReviewNetwork` depois de `GithubChangeRequests.collect/1`
devolver `{:ok, _}`; `run/5` passa `organization_id` no `ctx` de `coletar_trabalho/1`. Ver
[job.md](job.md).
