# Contrato: papéis por organização e promoção de evidência

**Feature**: 043 · **Data**: 2026-08-24

---

## `EO.list_roles/2`

```elixir
@spec list_roles(Tenant.t(), Ecto.UUID.t()) :: [papel()]

@type papel :: %{
        id: Ecto.UUID.t() | nil,
        code: String.t(),
        name: String.t(),
        origem: {:catalogo, String.t()} | {:declarado, Ecto.UUID.t()},
        hidden_at: DateTime.t() | nil,
        vinculos: non_neg_integer()
      }
```

**`id` é `nil` para papel do catálogo ainda não usado.** É a consequência da decisão 1 do
plano, e ela vaza para o chamador de propósito: esconder atrás de um id sintético faria a
tela achar que a linha existe.

`origem` é **tupla marcada**, e não um booleano `do_catalogo?`. O booleano perderia qual
conceito da SRO originou o papel, e a `FR-003` exige a origem visível.

`vinculos` é a contagem de quem usa o papel — a `FR-015` exige mostrá-la **antes** de
permitir ocultar.

## `EO.declare_role/4`

```elixir
@spec declare_role(Tenant.t(), Ecto.UUID.t(), map(), Ecto.UUID.t()) ::
        {:ok, OrganizationalRole.t()} | {:error, Ecto.Changeset.t() | :code_taken}
```

Papel declarado pela organização. `{:error, :code_taken}` quando o código já existe **naquela
organização** — retorno, não exceção.

## `EO.hide_role/3` e `EO.unhide_role/3`

```elixir
@spec hide_role(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
        {:ok, OrganizationalRole.t()} | {:error, :not_found | :in_use}
```

Oculta um papel **desta organização**. `{:error, :in_use}` quando há vínculo vigente — a
`FR-004` diz que ocultar não invalida vínculo, e a saída honesta é recusar em vez de deixar
vínculo apontando para papel oculto.

**Não existe `delete_role`.** Papel do catálogo não é apagável (`FR-004`), e papel declarado
com histórico de vínculo também não deveria sumir. Ocultar é a operação.

## `EO.promote_evidence/4`

```elixir
@spec promote_evidence(Tenant.t(), Ecto.UUID.t(), papel_escolhido(), Ecto.UUID.t()) ::
        {:ok, TeamMembership.t()}
        | {:error, :not_found | :already_promoted | :no_longer_observed
                 | :role_from_another_organization | Ecto.Changeset.t()}

@type papel_escolhido :: {:existente, Ecto.UUID.t()} | {:catalogo, String.t()}
```

O quarto argumento é o autor. A **data de início** vai nas opções, e é `nil` quando quem
promove não sabe:

```elixir
promote_evidence(tenant, evidence_id, papel, actor_id, started_at: ~D[2026-03-01])
promote_evidence(tenant, evidence_id, papel, actor_id)   # sem data — desconhecido
```

**`nil` é `nil`, e nunca a data de hoje** — `FR-018`. E `started_at` **nunca** é derivado de
`observed_at` da evidência: aquilo é quando a coleta viu, não quando a pessoa entrou
(`FR-019`).

**O papel escolhido é tupla marcada** porque o catálogo pode não ter linha ainda. Receber só
um `id` obrigaria a tela a materializar antes de promover — e materializar sem promover
deixaria lixo se a promoção falhasse.

Os quatro erros são **valores distintos**, e cada um vira frase diferente na tela:

| erro | a frase diz |
|---|---|
| `:already_promoted` | esta evidência já virou vínculo |
| `:no_longer_observed` | a pessoa não está mais nesta equipe na origem |
| `:role_from_another_organization` | este papel é de outra organização — `FR-008` |
| `:not_found` | a evidência não existe |

## `EO.rename_role/4`

```elixir
@spec rename_role(Tenant.t(), Ecto.UUID.t(), String.t(), Ecto.UUID.t()) ::
        {:ok, OrganizationalRole.t()} | {:error, :not_found | :from_catalog}
```

Renomeia um papel **declarado**. `{:error, :from_catalog}` para papel do catálogo — o nome
vem da rede, e editá-lo aqui produziria divergência silenciosa com o YAML (`FR-022`).

**Não existe `change_role_code`.** O código é a identidade; trocá-lo faria os vínculos
existentes apontarem para outra coisa sem que nada avisasse (`FR-021`).

## `EO.pending_evidence/2`

```elixir
@spec pending_evidence(Tenant.t(), Ecto.UUID.t()) :: [%{
        id: Ecto.UUID.t(),
        person_id: Ecto.UUID.t(),
        person_name: String.t(),
        team_id: Ecto.UUID.t(),
        team_name: String.t()
      }]
```

As evidências de uma equipe esperando confirmação.

**Não devolve `platform_access_level`.** É a `FR-011` sendo cumprida no **contrato**, e não
só na tela: se o valor não chega à camada de apresentação, nenhum template pode exibi-lo por
descuido.

É a mesma forma que a `SC-005a` verifica — e o contrato é onde a garantia é mais barata.

## `EO.team_size/2`

```elixir
@spec team_size(Tenant.t(), Ecto.UUID.t()) :: non_neg_integer()
```

**Pessoas distintas**, nunca vínculos — `FR-006c`. Existe como função própria justamente
para que ninguém conte `length(memberships)` por engano.

---

## O que o contrato deliberadamente não tem

- **`EO.suggest_role_for/2`.** Nem por acesso, nem por comportamento — `FR-012`.
- **`EO.delete_role/3`.** Ver `hide_role/3`.
- **`platform_access_level` em qualquer retorno da promoção.** É a `FR-011` no contrato.
- **`EO.activate_catalog_role/4`.** A `FR-002` diz "sem cadastro prévio", e ativar é cadastro
  prévio com outro nome — decisão 4 do plano.
