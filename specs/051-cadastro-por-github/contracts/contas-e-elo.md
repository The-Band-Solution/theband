# Contrato — Cadastro com temporária e o elo administrado na área

Escrito antes do código (constituição VI). Erro de contrato se corrige no mesmo
commit, com a razão.

## `Tenants.cadastrar_conta/3` — NOVA

```elixir
@spec cadastrar_conta(Tenant.t(), map(), User.t()) ::
        {:ok, {User.t(), String.t()}} | {:error, Ecto.Changeset.t()}
cadastrar_conta(tenant, %{"name" => nome, "email" => email}, actor)
```

- Cria a conta (role "member") E emite a senha temporária **numa transação** —
  tudo ou nada; falha em qualquer parte não deixa conta sem senha nem senha sem
  conta.
- Devolve a temporária UMA vez, em claro, para a tela mostrar — nunca logada,
  nunca persistida em claro (regras da 045 intactas: `must_change_password`,
  hash bcrypt, token de sessão).
- `actor` fica no rastro da temporária (mesmo formato do `reset_password/3`).
- E-mail duplicado devolve o changeset com o conflito — nada criado (FR-006).
- `create_user/2` PERMANECE como está (seeds e fixtures dependem); este é o ato
  da tela.

## `Tenants.user_of_person/2` — NOVA (leitura estreita)

```elixir
@spec user_of_person(Tenant.t(), Ecto.UUID.t()) :: User.t() | nil
```

- A conta com elo VIGENTE para a pessoa, ou nil. Uma consulta, filtrada por
  tenant.
- Chamada SÓ no caminho do `{:error, :taken}` de `declare_person/4`, para nomear
  a conta dona na recusa (cenário 3 da US2). Zero custo no caminho feliz.

## O que NÃO muda

- `declare_person/4` e `revoke_person/3`: contratos vigentes intactos — o `:taken`
  continua nascendo do índice único parcial (corrida segura), a revogação continua
  marcando sem apagar.
- `reset_password/3`: intacto.
- Invariante de login da 045 (e-mail sempre; username enquanto houver elo vigente).

## A tela (`/accounts`)

- **Lista**: cada linha diz o GitHub associado (login observado, com marca de
  derivado? NÃO — o elo é DECLARADO por quem administra: marca sólida) ou a
  ausência nomeada. O carregamento do elo é UMA consulta com join para a lista
  inteira — nunca por linha (L38).
- **Cadastrar**: nome + e-mail → `cadastrar_conta/3`; a temporária aparece uma
  única vez e some no evento seguinte (padrão existente do reset).
- **Associar**: busca `EO.list_people(tenant, q:, limit: 8)` disparada por evento
  (nunca no mount); resultado com nome, login e organização; escolher chama
  `declare_person/4`. `:taken` → recusa nomeando a conta dona
  (`user_of_person/2`).
- **Revogar**: botão na linha chama `revoke_person/3` com confirmação; a linha
  volta a dizer a ausência.
- Toda frase nova nasce em `dgettext` (errors/sistema) — gate da 047.

## Testes que provam o contrato

| Invariante | Teste |
|---|---|
| Tudo-ou-nada do cadastro | `tenants_cadastro_test.exs` — e-mail duplicado: contagens de users e de temporárias emitidas inalteradas |
| Temporária funciona | fluxo: cadastrar → entrar com a temporária → gate de troca (reusa helpers da 045) |
| Conflito nomeado | tela: associar pessoa já vinculada mostra o e-mail da conta dona; contagens inalteradas (SC-003) |
| Revogar fecha sem apagar | `person_declared_at` original preservado; `person_revoked_at` preenchido; login por username recusa depois |
| Lista sem N+1 | teste de contagem de consultas da tela (forma L38) |
| Busca com 0 resultados | ausência nomeada na tela |
