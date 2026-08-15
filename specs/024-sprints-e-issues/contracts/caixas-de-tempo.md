# Contrato — as caixas de tempo, e as issues dentro delas

**Feature** `024-sprints-e-issues` · **Data**: 2026-08-15

O contrato vem antes da implementação. Se ela mostrar que ele está errado, o conserto entra **no
mesmo commit**.

---

## 1. Registrar a caixa de tempo

```elixir
@spec record_sprint(Tenant.t(), map()) :: {:ok, Sprint.t()} | {:error, Ecto.Changeset.t()}
```

O resultado carrega `:outcome` — `:created`, `:updated` ou `:unchanged`. **Aqui `:updated`
existe**, ao contrário de `record_activity/2` da feature 022: uma caixa de tempo **muda**. A
pessoa renomeia `Sprint 38`, corrige a data de início, a iteração passa de em curso a concluída.

| Entrada | Obrigatória |
|---|---|
| `board_number`, `field_name`, `title` | sim |
| `started_on`, `duration_days` | sim |
| `source_system`, `source_instance`, `source_external_id` | sim |
| `board_title`, `completed` | não |

`ended_on` **não é entrada**: é derivado de `started_on + duration_days - 1`.

## 2. Associar a issue à caixa

```elixir
@spec place_issue_in_sprint(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
        {:ok, SprintIssue.t()} | {:error, Ecto.Changeset.t()}
```

Idempotente. A mesma issue em duas caixas produz **dois** vínculos — é o caso medido, e não a
exceção.

```elixir
@spec mark_issues_no_longer_in_sprint(Tenant.t(), Ecto.UUID.t(), [Ecto.UUID.t()], DateTime.t()) ::
        {:ok, non_neg_integer()}
```

Marca os vínculos daquele sprint que **não** estão na lista observada. Escopado ao sprint, e não
ao tenant — marcar por tenant atingiria caixas que a execução nunca olhou, que é a **L19**.

## 3. Ler

```elixir
@spec list_sprints(Tenant.t(), keyword()) :: [Sprint.t()]
@spec list_sprint_issues(Tenant.t(), Ecto.UUID.t()) :: [map()]
@spec count_issues_outside_any_sprint(Tenant.t(), board_number :: integer()) ::
        {:ok, non_neg_integer()} | {:error, :board_has_no_iteration_field}
```

A terceira é a FR-009/FR-010, e o par de retornos é o ponto: **`{:error, :board_has_no_iteration_field}`
não é zero.** "O quadro não usa caixas de tempo" e "todas as issues estão fora delas" produzem o
mesmo `0` e afirmam coisas opostas.

## 4. O que a coleta pede

```graphql
projectsV2(first: 20) {
  nodes {
    number title
    fields(first: 30) {
      nodes { ... on ProjectV2IterationField {
        name
        configuration { iterations { title startDate duration }
                        completedIterations { title startDate duration } } } }
    }
    items(first: 100, after: $after) {
      nodes { content { ... on Issue { id } }
              fieldValues(first: 20) {
                nodes { ... on ProjectV2ItemFieldIterationValue {
                  title startDate duration
                  field { ... on ProjectV2IterationField { name } } } } } }
    }
  }
}
```

**Medido em 2026-08-15**: a consulta de campos custou **1 ponto** para 26 quadros. Os itens são
paginados de 100 em 100 — o DevOps tem 677, sete páginas.

**Não é pedida** para quadro sem campo de iteração: 15 dos 26 medidos são assim, e consultar os
itens deles seria gasto sem resposta.

## 5. O que a plataforma recusa responder

```elixir
@spec velocity(Tenant.t(), Ecto.UUID.t()) :: {:error, :no_size_unit}
```

**Velocity não é calculável**, e a razão não é falta de coleta: a origem **não fornece unidade de
tamanho**. Contar issues por sprint mudaria de significado quando alguém decompusesse mais fino —
a mesma limitação que `flow.throughput.rate` já declara.

E há a consequência da decisão de que todo campo vira sprint: no DevOps a mesma issue está num
`Sprint` de 14 dias e num `Quarter` de 90. **Qualquer velocity por sprint a somaria duas vezes.**
