# Contrato — a estrutura da equipe: quem está nela, e o que se declara

**Feature**: 060, PR 1 · **Escrito antes da implementação** (constituição VI; AGENTS §12).
Cobre as consultas do roster (US1) e os comandos de declarar papel, registrar saída e marcar
equívoco (US2 a US4).

## O princípio que atravessa tudo

**A lista de membros é o VÍNCULO, não a evidência** (FR-008, ADR 0008). `list_team_members/3`
lê `eo_team_membership_evidence` e devolve o nível de acesso da plataforma; nada disso responde
o que a tela precisa, e o nível de acesso é justamente o que ela não pode mostrar como papel.

**Nada é apagado** (SC-012): saída encerra, equívoco invalida, papel oculto some da escolha e
continua nos vínculos. Toda mudança guarda **quem** e **quando**.

---

## Consultas

### `EO.list_team_roster(tenant, team_id, opts)`

```elixir
@spec list_team_roster(Tenant.t(), Ecto.UUID.t(), keyword()) :: [linha()]
```

`opts`: `search` (nome ou login), `order_by` (só `:name`), `limit`, `offset`.

Uma linha **por pessoa** (FR-009), agregando os vínculos dela com esta equipe **e** com as
subequipes de composição vigente:

```elixir
%{
  person_id: uuid, name: String.t() | nil, login: String.t() | nil,
  situacao: :vigente | :saiu | :equivoco,
  vinculos: [%{
    membership_id: uuid, team_id: uuid, team_name: String.t(), direta?: boolean(),
    role: %{id: uuid, code: String.t(), name: String.t()} | nil,
    origem: :observado | :declarado,
    declared_by: String.t() | nil, declared_at: DateTime.t() | nil,
    started_at: DateTime.t() | nil,
    fim: nil
       | {:declarado, autor :: String.t(), em :: DateTime.t(), quando :: DateTime.t()}
       | {:coleta, quando :: DateTime.t()}
       | {:sem_autor, quando :: DateTime.t()},
    equivoco: nil | %{razao: String.t(), por: String.t(), em: DateTime.t()}
  }]
}
```

**As três situações**, na mesma regra de `membership_disagreements/2`: `:vigente` se algum
vínculo é vigente; `:equivoco` se **todos** são invalidados; `:saiu` nos demais casos.

**Os três nulos que significam**: `role: nil` é *papel não declarado*; `started_at: nil` é
*desde quando não se sabe*; `fim: nil` é *vigente*.

**As três formas do fim** (FR-022): `{:declarado, …}` alguém disse; `{:coleta, quando}` a origem
deixou de mostrar — e a data é quando a plataforma **parou de ver**, não quando a pessoa saiu;
`{:sem_autor, quando}` fim anterior a esta PR, sem quem.

**Custo**: duas consultas — pessoas distintas da página, e os vínculos dessas pessoas. Nunca uma
por linha.

### `EO.count_team_roster(tenant, team_id, opts)`

```elixir
@spec count_team_roster(Tenant.t(), Ecto.UUID.t(), keyword()) :: non_neg_integer()
```

As **mesmas** `opts` da listagem: um cabeçalho dizendo 64 sobre uma lista de 10 é o defeito que
este módulo se organiza para não ter.

### `EO.team_roster_totals(tenant, team_id)`

```elixir
@spec team_roster_totals(Tenant.t(), Ecto.UUID.t()) ::
        %{vigentes: non_neg_integer(), sairam: non_neg_integer(), equivocos: non_neg_integer()}
```

Por **pessoa**, com a definição acima. Os três números batem com a listagem porque saem da mesma
agregação (FR-012).

### `EO.role_holder_counts(tenant, organization_id, team_id)`

```elixir
@spec role_holder_counts(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
        %{Ecto.UUID.t() => %{nesta_equipe: non_neg_integer(), na_organizacao: non_neg_integer()}}
```

Pessoas **distintas** com vínculo vigente (FR-029). Papel do catálogo sem linha tem `0/0` por
construção. Uma consulta.

---

## Comandos

### `EO.declare_role(tenant, team_id, person_id, papel, actor_id, opts)`

```elixir
@spec declare_role(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), papel_escolhido(), Ecto.UUID.t(), keyword()) ::
        {:ok, TeamMembership.t()}
        | {:error, :already_allocated | :role_from_another_organization | :not_in_catalog | Ecto.Changeset.t()}

@type papel_escolhido :: {:catalogo, String.t()} | {:existente, Ecto.UUID.t()}
```

**Completa o vínculo observado que já existe** — mesmo `id` (ADR 0008) —, ou insere a declaração
quando não há observado. `opts[:started_at]` nulo **fica nulo** (FR-016): campo vazio é
desconhecido, nunca hoje.

O papel do catálogo é materializado **dentro** da operação: materializar antes deixaria linha
órfã se a declaração falhasse. Papel de outra organização é `:role_from_another_organization`.

### `EO.change_role(tenant, membership_id, papel, actor_id, opts)`

```elixir
@spec change_role(Tenant.t(), Ecto.UUID.t(), papel_escolhido(), Ecto.UUID.t(), keyword()) ::
        {:ok, %{encerrado: TeamMembership.t(), novo: TeamMembership.t()}}
        | {:error, :not_found | :already_ended | :already_allocated | Ecto.Changeset.t()}
```

Numa transação: encerra o vínculo antigo em `opts[:desde] || agora` e declara o novo a partir da
mesma data. **O histórico é a linha encerrada** — não há tabela de histórico de papel (FR-017).
Alterar para o papel que a pessoa já tem vigente é `:already_allocated`.

### `EO.record_team_departure(tenant, team_id, person_id, quando, actor_id)`

```elixir
@spec record_team_departure(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), DateTime.t(), Ecto.UUID.t()) ::
        {:ok, non_neg_integer()} | {:error, String.t()}
```

Alcança **todos** os vínculos vigentes do par pessoa–equipe: "a pessoa saiu" é afirmação sobre a
pessoa na equipe, e FR-018 permite dois papéis ao mesmo tempo. Grava `ended_at: quando`,
`ended_by_user_id: actor_id` e `end_declared_at: agora` — três coisas, porque a data da saída
(possivelmente retroativa) e o instante do registro são perguntas diferentes.

Recusa: data no futuro; par sem vínculo vigente. **Segunda saída não reescreve a primeira**
(FR-023).

**Efeito na coleta** (FR-026): depois disto, a coleta **não recria** o vínculo enquanto a origem
continuar mostrando a pessoa — a evidência fica viva e a tela mostra as duas afirmações. Se a
origem deixar de mostrar e voltar a mostrar, é retorno, e nasce vínculo novo (FR-027).

### `EO.record_team_membership_mistake(tenant, team_id, person_id, razao, actor_id)`

```elixir
@spec record_team_membership_mistake(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
        {:ok, non_neg_integer()} | {:error, String.t()}
```

**Não é "saiu"**: é o vínculo que nunca vigeu. Sai de toda medida, para **toda** data — e a linha
fica, com razão, autor e instante (o trio que o banco exige junto). Razão vazia é recusada.
Alcança todos os vigentes do par, pelo mesmo motivo da saída. Vale para vínculo **declarado e
observado** (decisão de 2026-09-07), com o mesmo efeito sobre a coleta.

### `EO.end_allocation(tenant, membership_id, quando, actor_id)`

```elixir
@spec end_allocation(Tenant.t(), Ecto.UUID.t(), DateTime.t(), Ecto.UUID.t()) ::
        {:ok, TeamMembership.t()} | {:error, :not_found | :already_ended}
```

Encerra **um** vínculo (é o que `change_role/5` usa). Substitui a aridade 3, que não guardava
autor — sem ele, fim declarado e fim constatado pela coleta ficam indistinguíveis, e FR-022 exige
distingui-los.

---

## O que nenhuma destas funções faz

- **Nenhuma devolve `Ecto.Query`.**
- **Nenhuma apaga linha** (SC-012).
- **Nenhuma expõe `platform_access_level`** na lista de membros (FR-008, SC-004): `MAINTAINER` e
  `MEMBER` são nível de acesso da ferramenta, não papel organizacional, e mostrá-los ao lado do
  papel os transformaria em dica.
- **Nenhuma inventa data**: campo vazio é nulo, nunca hoje.
- **Nenhuma recebe os vínculos por parâmetro** — a lição do PR #798.
