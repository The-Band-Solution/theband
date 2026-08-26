# Contrato: o critério de início

**Feature**: 042 · **Data**: 2026-08-24

O contrato vem **antes** da implementação. Se a implementação mostrar que ele errou, corrige-se aqui no mesmo commit.

---

## `SPO.declare_start_criterion/4`

```elixir
@spec declare_start_criterion(Tenant.t(), alvo(), binary(), Ecto.UUID.t()) ::
        {:ok, ActivityStartCriterion.t()} | {:error, Ecto.Changeset.t() | :unknown_event_type}

@type alvo :: {:project, Ecto.UUID.t()} | {:board, Ecto.UUID.t()}
```

O alvo é **tupla marcada**, e não dois argumentos ou duas funções. Uma função por alvo duplicaria a validação; dois argumentos com um deles nulo deixaria a chamada `declare(t, nil, board_id, ...)` legível ao contrário.

`{:error, :unknown_event_type}` quando o tipo não existe na coleta — **retorno, não exceção**, porque é erro previsto de negócio (princípio VIII).

**Redeclarar revoga a anterior e cria a nova**, na mesma transação. Não é `update`: a `FR-010` manda preservar o histórico, e sobrescrever apagaria quem declarou antes.

## `SPO.revoke_start_criterion/3`

```elixir
@spec revoke_start_criterion(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
        {:ok, ActivityStartCriterion.t()} | {:error, :not_found}
```

Marca `revoked_at` e `revoked_by_user_id`. Nunca apaga.

## `SPO.start_criterion_for/2`

```elixir
@spec start_criterion_for(Tenant.t(), alvo()) :: ActivityStartCriterion.t() | nil
```

O critério **vigente daquele alvo**, sem escala. É o que a tela de declaração mostra como "o que está declarado aqui".

## `SPO.boards_overriding/2`

```elixir
@spec boards_overriding(Tenant.t(), Ecto.UUID.t()) :: [%{id: _, title: String.t(), event_type: String.t()}]
```

Os quadros do projeto que **têm critério próprio** e portanto vão ignorar a declaração do projeto.

Existe para a `FR-014`: a tela precisa dizer isso **antes** de a pessoa gravar. Sem esta função, o aviso só seria possível depois.

## `SPO.resolve_start/2` — a resolução em lote

```elixir
@spec resolve_start(Tenant.t(), [Ecto.UUID.t()]) :: %{
        Ecto.UUID.t() => {:ok, DateTime.t(), origem()}
                        | {:missing, :sem_criterio}
                        | {:missing, {:criterio_ambiguo, [quadro_em_empate()]}}
                        | {:missing, {:evento_nao_coletado, String.t()}}
      }

@type origem :: {:board, Ecto.UUID.t(), String.t()} | {:project, Ecto.UUID.t(), String.t()}
@type quadro_em_empate :: %{id: Ecto.UUID.t(), title: String.t(), linked_at: DateTime.t()}
```

**Recebe uma lista de issues e devolve um mapa.** Nunca uma issue por chamada: a decisão 2 do plano só se sustenta em lote, e com 19.200 atividades a versão unitária é N+1.

Três coisas que o tipo de retorno obriga, e são requisito:

- **`origem` acompanha o instante** — a `FR-013` exige que a tela diga de qual quadro ou projeto o critério veio. Devolver só o `DateTime` tornaria a proveniência impossível sem segunda consulta.
- **`criterio_ambiguo` carrega os quadros em empate, com título e data** — a `FR-016` exige nomeá-los. Um átomo sozinho obrigaria a tela a redescobrir quais eram.
- **`evento_nao_coletado` carrega o tipo declarado** — para a frase dizer *qual* evento falta.

**As três ausências são valores distintos, nunca `nil`.** `nil` colapsaria as três, e a `FR-009` proíbe agregá-las.

## `SPO.collected_event_types/1`

```elixir
@spec collected_event_types(Tenant.t()) :: [%{event_type: String.t(), occurrences: non_neg_integer()}]
```

Os tipos que a coleta traz, com volume, ordenados por volume. É a lista da `FR-012` — e é o que impede declarar um tipo que não existe.

**Não recomenda.** Devolver "sugerido: true" faria a plataforma escolher com passos extras, que é o que a `FR-007` da feature 022 proíbe.

---

## O que o contrato deliberadamente não tem

- **`SPO.start_date_of/2`**, para uma issue só. Convidaria ao N+1 que a decisão 2 recusa. Quem precisa de uma passa lista de um.
- **`SPO.suggest_criterion/2`**. Ver acima.
- **Qualquer função que grave o resultado.** A resolução é de leitura, sempre — `FR-005`.
