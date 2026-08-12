# Contrato — de quem cada issue é parte

**Feature** `011-de-quem-a-issue-e-parte` · **Fronteiras**: `TheBand.WorkItems` e
`TheBand.Ontology.SEON.CMPO`

Escrito **antes** da primeira função pública, como o princípio VI exige.

---

## `TheBand.WorkItems.Axioms.relacao/2`

Qual relação o vínculo é, dado o conceito da **filha** e o do **pai**. Função pura.

```elixir
@spec relacao(String.t() | nil, String.t() | nil) ::
        :atendimento
        | :composicao
        | :nao_nomeada
        | :pai_sem_conceito
        | {:violacao, :task_parent_is_epic}
```

| entrada | devolve | quantos hoje |
|---|---|---:|
| filha tarefa, pai **épico** | `{:violacao, :task_parent_is_epic}` | 293 |
| filha tarefa, pai qualquer outro conceito | `:atendimento` | 1 143 |
| filha épico ou user story | `:composicao` | 197 |
| filha **defeito** | `:nao_nomeada` | 33 |
| **pai sem conceito** (segundo argumento `nil`) | `:pai_sem_conceito` | 0 |

**Precondição: há pai.** A ausência de pai **não** é caso desta função — quem não tem pai não tem
relação. `rule07/2` trata `nil` como "não tem pai" e devolveria `{:violation, :task_without_parent}`
para **2 091** tarefas; essa violação continua sendo contada e explicada no painel que a tela já tem.

**O `nil` do segundo argumento significa aqui "o pai não foi promovido"** — e é tratado **antes** de
`rule07/2` ser chamado. Duas coisas com o mesmo `nil`, e a ordem das cláusulas é o que as separa.

**A violação é decidida por `rule07/2`.** Nenhuma segunda implementação do axioma — FR-006.

### Rótulos na tela

O texto é de `TheBandWeb.ConceptLabel`, em inglês, e cada caso tem **texto próprio** — cor nunca
sozinha (FR-014):

| relação | texto |
|---|---|
| `:atendimento` | `attends` |
| `:composicao` | `composes` |
| `{:violacao, _}` | `attends — and this parent is an epic, which violates sro.rule07` |
| `:nao_nomeada` | `part of — the ontology network does not name this relation` |
| `:pai_sem_conceito` | `part of — the parent has no concept` |

---

## `TheBand.WorkItems.list_parents/2`

Os pais vigentes e ausentes de um conjunto de issues, **numa consulta**, agrupados por filha.

```elixir
@spec list_parents(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => [parent()]}

@type parent :: %{
        id: Ecto.UUID.t(),
        number: integer(),
        title: String.t(),
        observed_repository_id: Ecto.UUID.t(),
        derived_concept: String.t() | nil,
        no_longer_observed_at: DateTime.t() | nil
      }
```

### Garantias

| # | Garantia | Por que |
|---|---|---|
| G1 | **uma** consulta, qualquer que seja o tamanho da lista | FR-013; a feature 007 nasceu com 135 por render |
| G2 | ordem `number` asc, `id` asc — **determinística** | FR-009; 36 issues têm mais de um pai |
| G3 | issue sem pai **não aparece** no mapa | ausência é do chamador nomear, não um `[]` disfarçado de erro |
| G4 | escopo por `tenant_id` | princípio V |
| G5 | vínculo com `no_longer_observed_at` **vem**, marcado | ausência é marcada, nunca deletada |
| G6 | `derived_concept` é o da promoção **vigente** | o histórico infla: 2 238 contra 1 666 |
| G7 | lista vazia de entrada devolve `%{}` **sem** consultar | página vazia não pergunta ao banco |

**G5 tem consequência para quem chama**: "mais de um pai" conta só os **vigentes**. Uma filha com um
pai vigente e um ausente **não** é caso de mais de um pai — é um pai, mais um vínculo que acabou.

**A fronteira não é cruzada**: devolve `observed_repository_id`, **não** o nome. O nome é de CMPO, e
`WorkItems` juntar a tabela dele quebraria a ADR 0003.

---

## `TheBand.Ontology.SEON.CMPO.list_observed/2` — já existe

Usada como **mapa** de `observed_repository_id` para nome, como `nomes_de_repositorio/1` faz em
`people_live/show.ex`.

**Uma consulta, incondicional.** Condicioná-la a "existe pai fora do repositório" faria o número de
consultas variar com o dado, e a constância do SC-008 deixaria de ser asserível.

---

## O que a tela garante

| # | Garantia | Requisito |
|---|---|---|
| T1 | issue sem pai tem texto, nunca célula vazia | FR-002 |
| T2 | o pai é `~p"/work/issues/#{id}"` | FR-012 |
| T3 | pai em **outro** repositório vem com o nome dele | FR-010 |
| T4 | pai no **mesmo** repositório **não** repete o nome | 1 609 linhas de ruído a menos |
| T5 | mais de um pai é dito, com todos listados | FR-008 |
| T6 | vínculo ausente aparece tracejado, com a data | FR-011 |
| T7 | `data-label` na célula, para virar cartão em 360 px | FR-015 |
| T8 | issue de outro tenant: **not found** | FR-016 |
