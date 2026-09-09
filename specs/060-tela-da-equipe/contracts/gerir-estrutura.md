# Contrato — quem pode gerir a estrutura de uma equipe

**Feature**: 060, PR 1 · **Escrito antes da implementação** (constituição VI; AGENTS §12).
**Decisão que ele materializa**: FR-006, FR-080 a FR-082 — administrador **ou** papel
organizacional com a concessão *gerir estrutura da equipe*. Lista fechada: não há terceiro
caminho.

## O que muda em relação a hoje

`Tenants.pode_declarar_estrutura/4` (`lib/the_band/tenants/access.ex:175-189`) autoriza
administrador **ou** escopo `organization`/`project` **de conta**. Ela é **removida**. Quem
age hoje por escopo de conta deixa de escrever na estrutura até um administrador conceder
*gerir estrutura* ao papel dessa pessoa — e ela precisa de elo com pessoa (`users.person_id`)
e de vínculo vigente com esse papel. **Não há migração de dados possível**: escopo é da conta,
concessão é do papel, e não existe função que leve um ao outro sem inventar papel.

`Tenants.Access.pode_ver_equipe/3` **não muda** (FR-007).

---

## `TheBand.Tenants.pode_gerir_estrutura(tenant, user, team_id)`

```elixir
@spec pode_gerir_estrutura(Tenant.t(), User.t(), Ecto.UUID.t()) ::
        {:ok, :admin | :gestor_da_equipe | :gestor_da_organizacao}
        | {:nao, :conta_sem_pessoa_declarada | :vinculo_encerrado | :sem_concessao}
```

Relator, nunca booleano: quem chama precisa da **razão** para dizê-la a quem foi recusado.

| Retorno | Quando |
|---|---|
| `{:ok, :admin}` | `User.admin?(user)` e `user.tenant_id == tenant.id`. Decidido em memória, sem consulta |
| `{:ok, :gestor_da_equipe}` | a pessoa da conta tem vínculo **vigente** com um papel cuja concessão **vigente** tem `scope: "team"`, **nesta** equipe |
| `{:ok, :gestor_da_organizacao}` | idem com `scope: "organization"`, na organização desta equipe |
| `{:nao, :conta_sem_pessoa_declarada}` | `user.person_id` é nulo — a conta não está ligada a ninguém, e a concessão é sobre papéis de pessoas |
| `{:nao, :vinculo_encerrado}` | existe vínculo **encerrado ou invalidado** com papel que alcançaria esta equipe, e nenhum vigente |
| `{:nao, :sem_concessao}` | nenhum papel vigente da pessoa tem concessão que alcance esta equipe |

**Ordem de avaliação**: admin primeiro (sem consulta); depois o elo; depois o alcance. O motivo
mais específico vence — `:vinculo_encerrado` é dito no lugar de `:sem_concessao` porque as duas
frases levam a ações diferentes (renovar o vínculo × pedir a concessão).

**A tela pergunta duas vezes.** Uma para decidir o que renderiza, outra dentro de cada evento de
escrita: esconder o botão não é autorização (FR-006). Para administrador o segundo custo é zero.

---

## `TheBand.Ontology.SEON.EO.declare_structure_grant(tenant, role_id, scope, actor_id)`

```elixir
@spec declare_structure_grant(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
        {:ok, RoleStructureManagementGrant.t()}
        | {:error, :already_granted | :invalid_scope | Ecto.Changeset.t()}
```

- `scope` ∈ `["team", "organization"]`; outro valor é `:invalid_scope`, nunca ignorado.
- A segunda concessão **vigente** para o mesmo (papel, alcance) é `:already_granted` — a
  garantia é do índice parcial no banco, e o changeset a traduz.
- `declared_at` é o instante da escrita; `declared_by_user_id` é obrigatório.
- **Não** confere visibilidade: ver e gerir são declarações separadas (spec 045, FR-022).

## `EO.revoke_structure_grant(tenant, role_id, scope, actor_id)`

```elixir
@spec revoke_structure_grant(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
        {:ok, RoleStructureManagementGrant.t()} | {:error, :not_declared}
```

**Revogar é marcar**: grava `revoked_at` e `revoked_by_user_id`, e a linha continua. Revogar o
que não está concedido é `:not_declared` — nunca sucesso silencioso.

## `EO.structure_grants_by_role(tenant)`

```elixir
@spec structure_grants_by_role(Tenant.t()) :: %{Ecto.UUID.t() => [String.t()]}
```

Só as **vigentes**, agrupadas por papel, para a tela desenhar a coluna *manages* em **uma**
consulta — nunca uma por linha.

## `EO.StructureGrants.alcance(tenant, person_id, team_id)`

```elixir
@spec alcance(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
        {:ok, :gestor_da_equipe | :gestor_da_organizacao}
        | {:nao, :vinculo_encerrado | :sem_concessao}
```

O núcleo consultado por `pode_gerir_estrutura/3`. Espelha `EO.Visibility` função a função;
**só o lado de quem age** exige vigência (é a pessoa que precisa estar na equipe hoje, não o
alvo).

---

## O que nenhuma destas funções faz

- **Nenhuma devolve `Ecto.Query`** — a fronteira do módulo é dado, não consulta.
- **Nenhuma apaga linha** (SC-012): revogar marca.
- **Nenhuma recebe a lista de concessões por parâmetro.** É a lição do PR #798, registrada em
  `verification.ex`: com a lista vindo de fora, o identificador deixa de decidir, e o veredito
  de uma equipe sai com o rótulo de outra. Uma consulta a mais é o preço, declarado no teto.
- **Nenhuma infere concessão por nome de papel** (FR-082): `Tech Lead` não gere nada sem
  declaração.
