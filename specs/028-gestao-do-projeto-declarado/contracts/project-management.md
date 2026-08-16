# Contrato — gestão do projeto declarado

**Feature**: 028 · **Data**: 2026-08-16 · Fronteiras: `TheBand.Ontology.SEON.SPO` e `...EO`

## `update_project/4`

```elixir
@spec update_project(Tenant.t(), Ecto.UUID.t(), map(), Ecto.UUID.t()) ::
        {:ok, Project.t()} | {:error, :not_found | Ecto.Changeset.t()}
```

Edita `name`, `started_on`, `ended_on`. Grava `updated_by_user_id`. Não alcança `parent_id`
— mover na hierarquia continua sendo `set_parent/3`/`clear_parent/2`, porque mover tem
regra própria (ciclo) e misturar os dois faria a validação de ciclo rodar em edição de nome.

## `remove_project/3`

```elixir
@spec remove_project(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
        {:ok, Project.t()} | {:error, :not_found | :has_parts}
```

**Marca, nunca apaga**: `removed_at` + `removed_by_user_id`. `:has_parts` quando existem
subprojetos vigentes — as partes são movidas ou removidas primeiro. Projeto removido sai
de `list_projects/1` e das travessias; a linha permanece.

**Não existe `undelete`**: declarar de novo é criar de novo, com autor novo.

## `link_organization/4` · `unlink_organization/3` · `list_project_organizations/2`

```elixir
@spec link_organization(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
        {:ok, ProjectOrganization.t()} | {:error, term()}
@spec unlink_organization(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, ProjectOrganization.t()}
@spec list_project_organizations(Tenant.t(), Ecto.UUID.t()) :: [map()]
```

O mesmo desenho de repositório: vínculo com `linked_by/at`, desfazer é `unlinked_by/at`,
e religar cria vínculo novo — a história dos vínculos é o dado.

## `collectable_for_project/2` (CMPO, leitura)

```elixir
@spec collectable_for_project(Tenant.t(), Ecto.UUID.t()) ::
        {:filtered, [map()]} | {:unfiltered, [map()]}
```

O que o seletor de repositórios oferece. `{:filtered, _}` quando o projeto tem organização
vigente associada — só repositórios delas; `{:unfiltered, _}` sem associação — todos, e a
tela diz que o filtro não está agindo. O átomo existe para a tela não ter que deduzir qual
caso aconteceu comparando tamanhos de lista.

## `create_declared_team/3` (EO)

```elixir
@spec create_declared_team(Tenant.t(), String.t(), Ecto.UUID.t()) ::
        {:ok, Team.t()} | {:error, Ecto.Changeset.t()}
```

`type: "project_team"`, sem organização — o schema da EO já documenta que o que justifica
o tipo é o vínculo com projeto. Proveniência `the_band/declared`, `external_id` gerado,
`declared_by_user_id` gravado. **Nasce vazia** (FR-009): membro exige papel (#99/#100).

## `link_team/4` · `unlink_team/3` · `list_project_teams/2` (SPO)

Mesmo desenho dos vínculos acima. `list_project_teams/2` devolve a equipe com a
proveniência junto — a tela separa declarada de observada.

## O que este contrato não expõe

| Ausente | Por quê |
|---|---|
| `delete_project!` (hard) | apagaria declaração e história dos vínculos |
| `add_team_member/…` | membership exige papel organizacional — #99/#100 |
| `update_team/…` | ciclo de vida de equipe é feature própria |
| filtro obrigatório no seletor | sem associação o comportamento de hoje fica — dito, não imposto |
