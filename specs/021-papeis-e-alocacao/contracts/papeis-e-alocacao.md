# Contrato — papéis e alocação

**Feature** `021-papeis-e-alocacao` · **Data**: 2026-08-14

O contrato vem antes da implementação. Se a implementação mostrar que ele está errado, o
conserto entra **no mesmo commit**.

---

## 1. O catálogo

```elixir
@spec create_role(Tenant.t(), map()) ::
        {:ok, OrganizationalRole.t()} | {:error, Ecto.Changeset.t()}

@spec list_roles(Tenant.t(), keyword()) :: [OrganizationalRole.t()]

@spec rename_role(Tenant.t(), Ecto.UUID.t(), String.t()) ::
        {:ok, OrganizationalRole.t()} | {:error, :not_found | :blank_name}

@spec delete_role(Tenant.t(), Ecto.UUID.t()) ::
        {:ok, OrganizationalRole.t()} | {:error, :not_found | {:in_use, pos_integer()}}
```

**`rename_role/3` não toca no código.** É por ele que os vínculos referenciam o papel, e
renomear é mudar o rótulo, não a identidade.

**`delete_role/2` devolve `{:in_use, quantos}`**, e não só `:error`. Quem lê a recusa precisa
saber o tamanho do que a impede — é a mesma regra do impacto antes de encerrar observação.

## 2. Os papéis que a ontologia sugere

```elixir
@spec suggested_roles() :: [%{code: String.t(), name: String.t()}]
```

Lidos da base de conhecimento, **nunca gravados**. Uma função que devolve lista e não escreve —
e a SC-004 é a asserção de que ela não escreve.

## 3. A alocação

```elixir
@spec allocate(Tenant.t(), map()) ::
        {:ok, TeamMembership.t()}
        | {:error, :not_found | :period_inverted | :already_allocated | Ecto.Changeset.t()}

@spec end_allocation(Tenant.t(), Ecto.UUID.t(), Date.t() | DateTime.t()) ::
        {:ok, TeamMembership.t()} | {:error, :not_found | :already_ended}
```

| Entrada de `allocate/2` | Obrigatória? |
|---|---|
| `person_id`, `team_id`, `organizational_role_id` | sim |
| `declared_by_user_id` | sim, vindo da sessão |
| `started_at` | **não** — ausente significa "não se sabe desde quando" |
| `ended_at` | não |
| `evidence_id` | não — quando presente, a evidência passa a apontar para o vínculo |

**`:already_allocated`, e não um erro genérico**: a mesma pessoa, mesmo papel, mesma equipe, com
período vigente. Qualquer outra combinação é permitida — dois papéis diferentes ao mesmo tempo
são a regra em Scrum, não a exceção.

**`started_at` ausente não vira `hoje`.** Inventar a data de hoje afirmaria que a alocação
começou agora, e o que se sabe é que ninguém disse quando — FR-007, e o cenário 5 da US2.

**`end_allocation/3` grava `ended_at` e não apaga.** `:already_ended` é resposta, não exceção:
encerrar duas vezes é engano de quem opera, e a segunda não deve reescrever a data da primeira.

## 4. O que a coleta continua fazendo, e o que ela nunca faz

```elixir
# continua igual
mark_evidence_no_longer_observed(tenant, organization_id, desde)
```

Ela toca **apenas** `eo_team_membership_evidence`. Não escreve, não marca e não encerra vínculo
— e o teste dessa garantia é uma contagem antes e depois.

**Se um dia a coleta precisar criar vínculo**, será outra feature: o `declared_by_user_id` nulo é
o que tornará os dois distinguíveis sem coluna de tipo.

## 5. O que a tela mostra, e o que ela não pode mostrar

| Onde | O quê |
|---|---|
| página da pessoa, bloco de participação | a evidência: equipe, nível de acesso **rotulado como acesso**, e desde quando é observada |
| página da pessoa, bloco de papéis | o vínculo: papel, período, **quem declarou** e quando |
| bloco de papéis, sem alocação | "papel pendente", e quantas evidências esperam |
| evidência marcada, vínculo vigente | os dois, e a frase de que a participação não aparece mais na origem |

**Proibido**: apresentar `MAINTAINER` ou `MEMBER` no lugar onde a tela mostra papel. É a SC-006,
e ela se verifica por `refute`.
