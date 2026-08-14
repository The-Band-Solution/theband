# Contrato — a atividade executada

**Feature** `022-timeline-das-issues` · **Data**: 2026-08-14

O contrato vem antes da implementação. Se ela mostrar que ele está errado, o conserto entra **no
mesmo commit**.

---

## 1. Registrar a ocorrência

```elixir
@spec record_activity(Tenant.t(), map()) ::
        {:ok, PerformedProjectActivity.t()} | {:error, Ecto.Changeset.t()}
```

O resultado carrega `:outcome` — `:created` ou `:unchanged` —, no mesmo campo virtual que
`Person`, `CollectedIssue` e `ObservedRepository` usam. **`:updated` não existe aqui**: uma
ocorrência não muda. Ela aconteceu.

| Entrada | Obrigatória |
|---|---|
| `activity_type`, `occurred_at`, `subject_type`, `subject_id` | sim |
| `source_system`, `source_instance` | sim |
| `source_external_id` | não — a origem pode não dar identidade ao evento |
| `performer_id`, `performer_login` | não |
| `concept_id` | não — nulo é "a rede não nomeia este tipo" |

**Reprocessar não duplica**: o `internal_id` sai do critério de identidade da ontologia, e o
índice único o garante.

## 2. Ler as atividades de uma entidade

```elixir
@spec list_activities(Tenant.t(), subject_type :: String.t(), subject_id :: Ecto.UUID.t()) ::
        [map()]
```

Em ordem de `occurred_at`, **crescente**: é a sequência do que aconteceu, e inverter faria a
tela contar a história de trás para frente.

## 3. Contar os tipos observados

```elixir
@spec count_activity_types(Tenant.t()) :: [%{type: String.t(), concept: String.t() | nil, count: pos_integer()}]
```

**É o que permite a decisão da FR-007.** Quem vai declarar qual evento marca o início precisa
saber quais existem e com que frequência — e a tela mostra isso.

Inclui os de conceito nulo, e é o ponto: são eles que dizem o que a rede ainda não nomeia.

## 4. O que a coleta pede, e quando

```graphql
timelineItems(first: $page_size, itemTypes: [...]) {
  totalCount
  pageInfo { hasNextPage endCursor }
  nodes { __typename ... on AssignedEvent { createdAt actor { login } assignee { ... } } }
}
```

> **Medido em 2026-08-14**, contra a API real: `timelineItems` vem na consulta da issue e aceita
> `itemTypes:`. E a medida refutou a suposição maior — `ProjectV2ItemStatusChangedEvent` **está**
> na timeline, com estado anterior, novo e autor. A dependência da #181 caiu. É a **L23** dando
> lucro: a consulta antes do código evitou uma feature desenhada em torno de dependência que não
> existia.

**Não é pedida** quando o repositório foi pulado pela feature 020, nem quando a issue não mudou
— FR-011 e FR-012.

## 5. O que a plataforma recusa responder

```elixir
@spec cycle_time(Tenant.t(), Ecto.UUID.t()) ::
        {:ok, Duration.t()} | {:error, :no_start_signal}
```

`{:error, :no_start_signal}` quando não há movimentação que a regra reconheça como início.

**E nunca lead time no lugar.** São medidas diferentes: lead time inclui o tempo em que ninguém
tocou na issue, e trocá-las em silêncio faria a organização decidir sobre um número que responde
outra pergunta — FR-009.

**A mensagem nomeia o que falta, e são três coisas diferentes:**

| Situação | O que falta |
|---|---|
| há movimentação, e nenhuma regra diz qual marca o início | a **declaração** — FR-007 recusa escolher sozinha |
| o quadro não tem estado que signifique "em andamento" | o **estado no quadro**: `process.ap05`, e aí a medida é impossível para toda issue dele |
| não há movimentação coletada | a **coleta** — e isso não é "processo saudável", é "não olhei" |

Confundir as três é o defeito da **L57**. A primeira se resolve declarando, a segunda mexendo no
quadro, e a terceira coletando — e nenhuma se resolve mostrando um número.
