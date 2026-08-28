# Contrato — TheBand.Tenants.Access

**Módulo**: `TheBand.Tenants.Access` (exposto pela fachada `TheBand.Tenants`).
**Escrito antes da implementação** (constituição VI).

## scopes/2 — a união vigente, com origem

```elixir
@spec scopes(Tenant.t(), User.t()) :: [scope()]

@type scope :: %{
        level: :person | :team | :project | :organization,
        target_id: Ecto.UUID.t() | nil,   # nil só no piso person
        target_name: String.t() | nil,
        origin: :floor | :derived_team | :derived_project | :granted,
        grant: ScopeGrant.t() | nil        # presente quando origin == :granted
      }
```

- Piso `person` entra sse o elo está vigente (FR-006).
- Derivados pela cadeia declarada e vigente (research R5/R6); fecham com o fato —
  nunca aparecem se o vínculo/ligação/elo caiu (FR-020/021).
- Concessões vigentes (`revoked_at IS NULL`), com o grant para a tela mostrar
  proveniência.
- Leitura em passadas fixas por coleção — sem consulta por linha (L38).

## pode_ver/3 — o veredito único da visão

```elixir
@spec pode_ver(Tenant.t(), User.t(), person_id :: Ecto.UUID.t()) ::
        {:ok, motivo :: atom()} | {:nao, motivo :: atom()}
```

- Ordem dos ramos (o motivo mais específico vence): própria pessoa (piso) → escopo
  team/project/organization que alcança a pessoa-alvo → liderança declarada da regra
  #369 (delegada a `EO.Visibility.pode_ver/3`, FR-018 — soma, nunca subtrai).
- Motivos do NÃO distinguem: `:sem_elo_declarado`, `:fora_dos_escopos`,
  `:alvo_da_concessao_nao_existe_mais` — a tela nomeia (FR-011).
- **O ramo "admin vê tudo" não existe aqui nem volta ao Visibility** (FR-022): ser
  administrador não abre painel. A migração compensa (research R9).

## grant/5 · revoke/5

```elixir
@spec grant(Tenant.t(), user_id, level :: :team | :project | :organization,
            target_id, actor :: User.t()) ::
        {:ok, ScopeGrant.t()} | {:error, :not_admin | :target_not_found | Changeset.t()}
@spec revoke(Tenant.t(), grant_id, actor :: User.t()) ::
        {:ok, ScopeGrant.t()} | {:error, :not_admin | :not_found}
```

- Só administrador concede/revoga (FR-008) — verificado AQUI, não só na tela.
- Alvo obrigatório e existente no tenant (FR-007): equipe, projeto declarado ou
  organização; nível `person` não é concedível (é piso).
- Revogar grava `revoked_by/revoked_at` — marca, nunca delete (III).
- Escopo derivado não passa por aqui em nenhuma direção (FR-021).

## operacional?/2 — o gating de FR-023

```elixir
@spec operacional?(Tenant.t(), User.t()) :: {true, :admin | {:organizations, [org_id]}} | false
```

- `true` para administrador (tenant inteiro) ou para quem tem concessão organization
  vigente — devolvendo QUAIS organizações, para as telas operacionais filtrarem
  (research R8).

## O que esta API NÃO expõe, e por quê

- **Não expõe booleano seco em pode_ver** — o motivo é requisito (FR-011); booleano
  no lugar de relator é antipadrão nomeado da casa.
- **Não grava escopo derivado** — segunda verdade dessincroniza (FR-021).
- **Não expõe concessão de `person`** — piso não se concede.
- **Não decide menu** — a camada web pergunta `operacional?/2` e `User.admin?/1`;
  markup é assunto dela.
