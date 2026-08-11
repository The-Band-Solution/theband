# Contrato — quadros, campos, itens e iterações

API pública de `TheBand.Projects`, e as promoções que o conteúdo do quadro produz.

---

## O que o quadro é, e o que ele não é

**O quadro não é promovido a nada.** Decisão da pessoa mantenedora em 2026-08-11:
quadro é planejamento — uma forma de organizar as issues e seus estados, e uma forma
de visualização. Não é o empreendimento.

`observed_projects` não tem coluna apontando para conceito nenhum. **Quem promove é
o conteúdo:**

```
quadro (Projects v2)          artefato de fonte, sem promoção
  ├── iteração iniciada    ──▶ sro.sprint                            ocorreu
  ├── iteração futura      ──▶ spo.specific_intended_project_process pretendida
  ├── item com iteração
  │     iniciada           ──▶ compõe sro.sprint_backlog
  └── item sem iteração    ──▶ compõe sro.product_backlog
```

Registrado em `rules/github_project_board.yaml`, cujo `does_not_materialize` nomeia
os três conceitos que o quadro **não** vira: `spo.software_project`,
`sro.scrum_project` e `sro.planning_meeting`.

---

## Coleta do quadro

### `record_observed_project/2`

```elixir
@spec record_observed_project(Tenant.t(), map()) ::
        {:ok, ObservedProject.t()} | {:error, Ecto.Changeset.t()}
def record_observed_project(%Tenant{} = tenant, attrs)
```

Idempotente pela Application Reference. `attrs` exige `connected_tool_id`,
`external_id`, `number`, `title`, `collected_at`.

**Não aceita `spo_project_id` nem qualquer campo de promoção.** A ausência do
parâmetro é o que impede alguém promover por engano — a assinatura não dá caminho.

### `record_field_definition/2`

```elixir
@spec record_field_definition(Tenant.t(), map()) ::
        {:ok, FieldDefinition.t()} | {:error, Ecto.Changeset.t()}
def record_field_definition(%Tenant{} = tenant, attrs)
```

**A identidade é `field_external_id`, nunca `name`** (FR-027). Renomear "Priority"
para "Prioridade" atualiza `name` da mesma linha; não cria campo novo, e não
invalida o mapeamento declarado por tenant.

### `record_item/2` e `record_item_field_value/2`

```elixir
@spec record_item(Tenant.t(), map()) :: {:ok, Item.t()} | {:error, Ecto.Changeset.t()}
@spec record_item_field_value(Tenant.t(), map()) ::
        {:ok, FieldValue.t()} | {:error, Ecto.Changeset.t()}
```

`record_item/2` aceita `collected_issue_id` **nulo** — item de rascunho não tem issue
por trás, e `is_draft: true`. Rascunho não é promovido a nada: é intenção de alguém,
não escopo do produto.

`record_item_field_value/2` sempre grava `raw_value`. Preenche `interpreted_as`
**apenas** quando existe mapeamento declarado para aquele `field_external_id` no
`rules/tenants/<tenant>.yaml`.

```elixir
# com mapeamento declarado
%{project_item_id: id, field_definition_id: fid,
  raw_value: %{"number" => 8}, interpreted_as: "sro.user_story.complexity"}

# sem mapeamento
%{project_item_id: id, field_definition_id: fid,
  raw_value: %{"name" => "P1"}, interpreted_as: nil}
```

**`interpreted_as: nil` não é falha.** É o caso comum, e é o que a tela mostra como
*não interpretado*. Converter por semelhança de nome é o antipadrão declarado em
`AGENTS.md` §7.7: um campo chamado `Priority` **não** é `importance` — importance é
decimal com escala declarada, Priority é seleção única cujos valores o tenant
inventou.

---

## Iterações, e o par pretendida/ocorrida

### `record_iteration/2`

```elixir
@spec record_iteration(Tenant.t(), map()) ::
        {:ok, %{iteration: Iteration.t(), promoted_to: promotion_target()}}
        | {:error, Ecto.Changeset.t()}
@type promotion_target :: {:sprint, Ecto.UUID.t()} | {:intended_process, Ecto.UUID.t()}
def record_iteration(%Tenant{} = tenant, attrs)
```

A promoção é decidida pela regra `github.iteration_started`, e o retorno **diz qual
foi**. Não devolve só `{:ok, iteration}`: quem chama precisa saber se registrou um
sprint ou um plano, e descobrir isso relendo a linha seria um segundo caminho de
derivação.

| Condição | Promove a |
|---|---|
| `start_date` já passou | `sro.sprint` — `complex_action`, ocorreu |
| `start_date` no futuro | `spo.specific_intended_project_process` — `intention` |

**Exatamente um dos dois, nunca os dois, nunca nenhum** (SC-009c).

### A transição, que é onde isto engana

A mesma iteração troca de registro ao começar. A troca acontece **na coleta seguinte
ao início**, não no instante do início.

Uma iteração que começou hoje, com a última coleta de ontem, continua registrada
como pretendida até a próxima coleta rodar. Isso é consequência de a plataforma
afirmar o que **observou**, e não o que o calendário implica — e está no contrato
porque quem ler o dado sem saber disso concluirá que a plataforma está atrasada.

### `record_iteration_absent/3`

```elixir
@spec record_iteration_absent(Tenant.t(), Ecto.UUID.t(), DateTime.t()) :: {:ok, Iteration.t()}
```

Iteração removida da configuração do quadro é marcada, nunca apagada. Apagar
destruiria a resposta a "o que foi feito naquele sprint" e a "o que foi planejado e
nunca aconteceu".

**Os itens dela NÃO voltam ao product backlog.** Voltar afirmaria um replanejamento
que ninguém decidiu.

---

## Os dois backlogs, derivados

```elixir
# TheBand.Ontology.Continuum.SRO
@spec product_backlog(Tenant.t(), Ecto.UUID.t()) :: [item()]
@spec sprint_backlog(Tenant.t(), Ecto.UUID.t()) :: [item()]
```

`product_backlog/2` recebe o **id do quadro**; `sprint_backlog/2` recebe o **id do
sprint**. A diferença de argumento não é detalhe: o product backlog é do produto
visto por aquele quadro, e o sprint backlog é de um sprint.

**A composição é derivada da atribuição de iteração** (FR-032b), nunca gravada.
Gravar pertencimento faria o registro divergir da origem no instante em que alguém
arrastasse um item no quadro — o mesmo erro que materializar épico contra atômica.

**Invariante verificável** (SC-009b):

```elixir
length(product_backlog(tenant, project_id)) +
  Enum.sum(for s <- sprints_of(tenant, project_id), do: length(sprint_backlog(tenant, s.id))) ==
  count_items(tenant, project_id)
```

Nenhum item nos dois conjuntos, nenhum fora dos dois.

---

## Ausência de importância, exposta e não suprida

```elixir
@spec importance_source(Tenant.t(), Ecto.UUID.t()) ::
        {:mapped, String.t()} | :not_declared
def importance_source(%Tenant{} = tenant, project_id)
```

Devolve `:not_declared` quando nenhum campo do quadro está mapeado para
`sro.user_story.importance` — que é o caso do quadro deste tenant.

**A função existe para a tela poder dizer isso** (FR-026). Sem ela, a tela mostraria
uma lista sem ordem e ninguém saberia se a ordem não existe ou se a plataforma
falhou em lê-la. Ausência declarada é diferente de ausência silenciosa.

Nenhuma função devolve importância derivada de outro campo. `Priority` não é
substituto.

---

## Quando o tenant não usa Projects v2

```elixir
@spec projects_available?(Tenant.t(), ConnectedTool.t()) :: boolean()
```

Verificado no **início** da coleta de projetos, e o resultado entra no relatório do
`sync` (FR-040).

**Uma organização sem quadros não produz sprint nem backlog**, e isso precisa
aparecer como *declarado* e não como coleta vazia por falha. Descobrir depois de três
dias de sincronização sem resultado é o risco que o backlog do GitHub → SRO já
registrava.

---

## O que este contrato **não** expõe

| Ausente | Por quê |
|---|---|
| `promote_project_to_software_project/2` | quadro é planejamento; empreendimento vem de cadastro declarado |
| `promote_project_to_scrum_project/2` | adotar Scrum não é observável — quadro com iterações pode ser Kanban |
| `derive_planning_meeting/2` | o quadro é o resultado de planejar, não a cerimônia |
| `set_product_backlog/3` | a composição é derivada da atribuição de iteração |
| `record_item_history/2` | o histórico de itens está fora de escopo por custo de consumo |
| `interpret_field_by_name/2` | mapeamento por semelhança de nome é antipadrão declarado |
