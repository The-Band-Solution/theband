# Contrato — coleta e promoção de issues

API pública de `TheBand.WorkItems` e das promoções em `TheBand.Ontology.Continuum.SRO`.

Escrito **antes** da primeira função, como a constituição exige no princípio VI. Se
a implementação mostrar que este contrato erra, ele é corrigido no mesmo commit —
nunca contornado.

---

## Fronteira

`TheBand.WorkItems` é a camada de plataforma: a issue como o GitHub a devolveu, e a
decisão que a plataforma tomou sobre ela. Nenhum módulo fora de `work_items/`
alcança os schemas, e nenhum chama `Repo` sobre as tabelas dela.

A promoção **atravessa** para o domínio, e atravessa pela API pública do módulo
ontológico — nunca por schema.

---

## Coleta

### `record_collected_issue/2`

```elixir
@spec record_collected_issue(Tenant.t(), map()) ::
        {:ok, CollectedIssue.t()} | {:error, Ecto.Changeset.t()}
def record_collected_issue(%Tenant{} = tenant, attrs)
```

Grava ou atualiza a issue pela Application Reference. **Idempotente**: duas chamadas
idênticas devolvem a mesma linha, e nenhuma contagem muda.

`attrs` exige:

| Chave | Observação |
|---|---|
| `observed_repository_id` | o escopo. Sem ele não há como marcar ausência corretamente |
| `external_id` | o identificador **global**, nunca o número |
| `number` | para exibir e localizar |
| `issue_type` | o nome que o GitHub deu, **cru**. `nil` é valor válido |
| `title`, `state`, `collected_at` | |

**`issue_type` não é normalizado aqui.** Normalizar destruiria o dado que a lacuna
precisa mostrar: FR-034 manda exibir o nome do tipo encontrado, e "tipo
desconhecido" sem o nome não diz nada a quem administra.

### `mark_issues_no_longer_observed/3`

```elixir
@spec mark_issues_no_longer_observed(Tenant.t(), Ecto.UUID.t(), DateTime.t()) ::
        {:ok, non_neg_integer()}
def mark_issues_no_longer_observed(%Tenant{} = tenant, repository_id, collection_started_at)
```

Marca as issues do **repositório informado** que não apareceram nesta coleta.

**`repository_id` é obrigatório na assinatura, e isso é a L19 impedida no tipo.**
Uma versão sem esse argumento marcaria as issues de repositórios que a coleta nunca
olhou. O defeito original atingiu três organizações; numa organização com trinta
repositórios ele atingiria vinte e nove.

Não existe `mark_issues_no_longer_observed/2`. A ausência é deliberada.

---

## Promoção

### `record_promotion/2`

```elixir
@spec record_promotion(Tenant.t(), map()) :: {:ok, IssuePromotion.t()}
def record_promotion(%Tenant{} = tenant, attrs)
```

Registra o que a regra decidiu. **Sempre chamada**, inclusive quando não promove —
uma issue sem registro de promoção é indistinguível de uma issue não processada.

Três formas de `attrs`, e o contrato as distingue:

```elixir
# promovida
%{collected_issue_id: id, declared_concept: "sro.user_story",
  derived_concept: "sro.user_story", target_table: "sro_user_stories",
  target_id: uuid, rule_id: "github.issue_type_routing", rule_version: 1}

# promovida CONTRA o rótulo declarado
%{collected_issue_id: id, declared_concept: "sro.epic",
  derived_concept: "sro.atomic_user_story", target_table: "sro_user_stories",
  target_id: uuid, rule_id: "github.issue_type_routing", rule_version: 1,
  divergence_reason: "tipo Epic sem sub-issues; não existe épico sem partes"}

# não promovida
%{collected_issue_id: id, declared_concept: nil, derived_concept: nil,
  rule_id: "github.issue_type_routing", rule_version: 1,
  skip_reason: :type_unknown, skip_detail: "Spike"}
```

`skip_reason` é um dos:

| Valor | Quando |
|---|---|
| `:type_absent` | `issueType` nulo — a organização não usa tipos |
| `:type_unknown` | nome de tipo que nenhuma rota reconhece. `skip_detail` traz o nome |
| `:sub_issues_unavailable` | a instância não expõe sub-issues, e a distinção épico/atômica não é possível |

**`rule_version` é obrigatório.** É o que permite responder "por que esta issue foi
classificada assim em março" depois de a regra mudar — e ela vai mudar, tem
`status: proposed`.

### `record_decomposition_link/2`

```elixir
@spec record_decomposition_link(Tenant.t(), map()) ::
        {:ok, DecompositionLink.t()}
        | {:error, {:cycle, [String.t()]}}
        | {:error, {:out_of_scope, Ecto.UUID.t()}}
def record_decomposition_link(%Tenant{} = tenant, attrs)
```

**O ciclo é recusado aqui, no comando, e não no banco.** O axioma `sro.rule04` diz
por quê: *"uma constraint de banco sozinha não pega ciclo transitivo em
auto-relacionamento; é preciso checar o caminho até a raiz"*.

`{:error, {:cycle, caminho}}` traz o caminho que fecharia o ciclo, na ordem, e o
vínculo recusado **é persistido** em `refused_links`. Recusar sem registrar deixaria
FR-017 sem como nomear o caminho depois da coleta.

**As duas issues permanecem coletadas.** Recusa-se o vínculo, nunca a issue: ela
existe no GitHub, e esconder dado observado por causa de relação inválida seria pior
que registrar a relação inválida.

`{:error, {:out_of_scope, id}}` quando a parte está em repositório fora do escopo
observado. Também persistido, com `reason: :out_of_scope`.

---

## Consulta

```elixir
@spec list_issues(Tenant.t(), keyword()) :: [issue_com_promocao()]
@spec count_by_promotion(Tenant.t(), keyword()) :: %{String.t() => non_neg_integer()}
@spec count_gaps_by_reason(Tenant.t(), keyword()) :: %{atom() => non_neg_integer()}
@spec list_divergences(Tenant.t(), keyword()) :: [divergencia()]
@spec count_collected(Tenant.t(), keyword()) :: non_neg_integer()
```

Opções aceitas por todas: `repository_id`, `organization_id`, `limit`, `offset`.

**Invariante que a tela usa e o teste verifica** (SC-001):

```elixir
count_collected(tenant, opts) ==
  count_by_promotion(tenant, opts) |> Map.values() |> Enum.sum() |> Kernel.+(
    count_gaps_by_reason(tenant, opts) |> Map.values() |> Enum.sum())
```

Nenhuma issue desaparece entre a coleta e a classificação. Se a soma não fechar, o
defeito é da promoção não ter sido registrada — e o teste falha nomeando isso.

**Nenhuma função devolve `Ecto.Query`.** Quem recebe query compõe sobre ela, e ao
compor contorna o filtro de tenant.

---

## Classificação derivada

```elixir
# TheBand.Ontology.Continuum.SRO
@spec classification(Tenant.t(), Ecto.UUID.t()) :: :epic | :atomic_user_story
def classification(%Tenant{} = tenant, user_story_id)

@spec list_epics(Tenant.t(), keyword()) :: [user_story()]
@spec list_atomic(Tenant.t(), keyword()) :: [user_story()]
```

**Um caminho só.** A tela, a consulta de escopo e o teste usam `classification/2`.
Dois caminhos discordariam, e a tela mostraria como épico o que a consulta trata
como atômica.

**Não existe `set_classification/3`, e a ausência é deliberada.** A classificação é
situação, e situação é derivada (ADR 0004 D7). Uma função para gravá-la é a porta
para materializar, e a issue #98 deste repositório mostra o custo: nasceu sem partes
e ganhou duas no mesmo dia.

---

## O que este contrato **não** expõe

| Ausente | Por quê |
|---|---|
| `create_issue/2` | não há cadastro manual; expor convidaria a criar registro sem proveniência |
| `delete_issue/2` | ausência marca, nunca apaga |
| `set_classification/3` | a classificação é derivada |
| `promote_issue/2` sem regra | promover sem registrar qual regra decidiu quebra FR-012 |
| `mark_issues_no_longer_observed/2` | sem escopo de repositório é a L19 |
| qualquer `Ecto.Query` | vaza a fronteira e permite contornar o tenant |

Ausência documentada com motivo é decisão. Ausência silenciosa é esquecimento — as
duas parecem iguais no código, e é por isso que o motivo está escrito.
