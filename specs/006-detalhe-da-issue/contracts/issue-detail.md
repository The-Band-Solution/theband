# Contrato — detalhe da issue e issues do repositório

Feature 006. Escrito **antes** da primeira função pública, como o princípio VII exige.

Fronteiras envolvidas: `TheBand.WorkItems` (issues, vínculos, promoção) e
`TheBand.Ontology.SEON.CMPO` (repositório observado). Nada aqui devolve `Ecto.Query`, e
nenhuma função alcança tabela de outro contexto — a ligação com pessoa é **referência**,
resolvida por `TheBand.Ontology.SEON.EO.people_names/2`.

---

## `TheBand.WorkItems`

### `fetch_issue(tenant, id) :: {:ok, map()} | {:error, :not_found}`

A issue com tudo o que foi coletado dela, a promoção vigente, os designados e os rótulos.

Devolve `{:error, :not_found}` para issue de outro tenant — **nunca** `:unauthorized`.
Dizer "sem permissão" confirmaria que o recurso existe, e é a mesma regra que as telas de
ferramenta já seguem.

Campos do mapa:

| Campo | Origem | Ausência significa |
|---|---|---|
| `number`, `title`, `state` | origem | — (obrigatórios) |
| `body` | origem | issue ainda não reobservada desde a feature 006, **ou** issue sem corpo |
| `state_reason` | origem | issue aberta, ou fechamento sem motivo declarado |
| `author_login`, `author_person_id` | origem / referência | autor removido da origem / pessoa não coletada |
| `assignees` | tabela própria | ninguém designado |
| `labels` | tabela própria | nenhum rótulo |
| `milestone_title`, `project_titles` | origem, **como referência** | issue fora de marco/quadro |
| `comment_count`, `reaction_count` | origem | zero é zero, e é diferente de ausente |
| `derived_concept`, `declared_concept`, `divergence_reason` | promoção vigente | não promovida |
| `skip_reason`, `skip_detail` | promoção vigente | promovida |
| `rule_id`, `rule_version` | promoção vigente | — |
| `classification` | **derivada** das partes | nunca ausente: `:epic` ou `:atomic_user_story` |
| `external_created_at`, `external_updated_at`, `external_closed_at` | origem | não informado / issue aberta |
| `collected_at`, `last_observed_at`, `no_longer_observed_at` | plataforma | — / issue vigente |

**`body` ausente distingue dois casos, e a distinção é no valor — não na data.**

Durante a implementação ficou claro que a data da última observação não resolve: ela muda por
qualquer coleta, e uma issue reobservada depois desta feature ainda pode ter corpo vazio na
origem. O que resolve é o próprio valor, porque `bodyText` devolve `""` e nunca `nil`:

- **`nil`** — a plataforma nunca pediu o corpo. Estado das 4463 issues coletadas antes desta
  feature;
- **`""`** — a origem devolveu corpo vazio: a issue não tem descrição.

A tela diz coisas diferentes para os dois — FR-009. É a L13 no valor, em vez de na data.

### `promotion_history(tenant, collected_issue_id) :: [map()]`

As promoções em ordem cronológica, a **última** marcada como vigente. Append-only já é
como a feature 004 grava; esta função só lê.

Ordena por `inserted_at` em microssegundo — a L20 vale aqui: duas promoções do mesmo
segundo tornariam a ordem dependente do plano de execução.

### `list_composition(tenant, collected_issue_id) :: [map()]`

As partes promovidas a `sro.epic` ou `sro.atomic_user_story` — o que **compõe** a issue.

### `list_attendance(tenant, collected_issue_id) :: [map()]`

As partes promovidas a `sro.intended_scrum_development_task` — o que **atende** a issue.

**As duas nunca são somadas.** São relações ontologicamente distintas:
`sro.epic_composed_of_user_story` é composição; a tarefa atende por
`sro.intended_task_planned_to_meet_user_story`. Uma contagem única de "filhas" apagaria a
distinção que a plataforma existe para preservar — FR-016, SC-003.

Num épico com 3 user stories e 36 tarefas, `list_composition/2` devolve 3 e
`list_attendance/2` devolve 36. **39 não aparece em lugar nenhum** — SC-004.

### `list_unpromoted_parts(tenant, collected_issue_id) :: [map()]`

As partes que a plataforma **não promoveu a nada**.

*Acrescentada durante a implementação.* Sem ela, composição + atendimento é menor do que a
origem declara, e quem lê conclui que a plataforma perdeu vínculos. Ela não perdeu: falta regra
de mapeamento, que é a feature 005.

### `fetch_parent(tenant, collected_issue_id) :: map() | nil`

O pai vigente, com o conceito dele. `nil` quando a issue não tem pai.

Para uma tarefa, é a user story que ela atende (FR-019). Para uma user story dentro de
épico, é o épico (FR-018).

### `rule07_violations(tenant, opts) :: %{task_parent_is_epic: [map()], task_without_parent: [map()]}`

As duas formas de violar `sro.rule07`, **separadas**:

- `task_parent_is_epic` — tarefa cujo pai é épico. O axioma diz que tarefa atende user
  story, e épico não é user story atômica;
- `task_without_parent` — tarefa sem user story a atender.

**A issue continua promovida.** O inválido é o **vínculo**, não a issue — e é por isso que
esta função devolve aviso, nunca remove promoção (FR-024).

**A decisão é de `TheBand.WorkItems.Axioms.rule07/2`**, função pura, e ela é o **único**
caminho de derivação — a mesma que o detalhe de uma issue usa. O que muda entre os dois é como
os dados chegam: uma consulta por issue no detalhe, o grafo inteiro em `left_join` no lote.
Duas implementações do mesmo axioma fariam a tela do repositório avisar o que o detalhe nega, e
é a lição de `classification/2` na sua segunda forma.

Delegadas pela fronteira como `WorkItems.rule07/2` e `WorkItems.rule07_explanation/1`.

### `list_refused_for(tenant, collected_issue_id) :: [map()]`

Os vínculos recusados na coleta que envolvem esta issue, com motivo e caminho do ciclo
quando houver (FR-025).

### `count_by_promotion(tenant, opts)` e `count_gaps_by_reason(tenant, opts)`

Já existem desde a feature 004, e aceitam `observed_repository_id`. A invariante do
cabeçalho do repositório é a mesma da tela de trabalho:

```
count_collected == soma(count_by_promotion) + soma(count_gaps_by_reason)
```

Se não fechar, alguma promoção não foi registrada — FR-027, SC-008.

### `replace_assignees(tenant, collected_issue_id, [%{login:, person_id:}])`

Substitui os designados da issue pelos informados. Devolve `{:ok, contagem}`.

**Aqui a substituição apaga, e a decisão é consciente.** Designação retirada na origem
não é o mesmo caso de issue que desapareceu: o histórico continua no payload bruto, que a
feature 004 preserva em `raw_payloads`, e manter designado antigo marcado exigiria a tela
mostrar ex-designados — informação que ninguém pediu e que confundiria quem lê "quem está
nisto agora".

### `replace_labels(tenant, collected_issue_id, [%{name:, color:}])`

Mesma semântica, mesma razão.

---

## `TheBand.Ontology.SEON.CMPO`

### `fetch_observed(tenant, id) :: {:ok, map()} | {:error, :not_found}`

Já existe, e devolve **`{:ok, _}` ou `{:error, :not_found}`** — não o mapa direto. A tela do
repositório usa nome qualificado, linguagem, URL, ramo padrão, datas e estado da observação
(FR-031).

**`list_observed/2` passou a expor três campos que FR-031 pede e não estavam no select**:
`description`, `external_created_at` e `collected_at`. Ampliação de `select`, sem mudança de
assinatura nem de fronteira.

Repositório **excluído da observação** tem as issues consultáveis, e a tela diz que a
plataforma parou de olhar — não que o dado sumiu (FR-030).

---

## O que este contrato deliberadamente **não** declara

| Função ausente | Por que |
|---|---|
| `count_children/2` | somaria composição e atendimento, contra FR-016 |
| `set_classification/3` | classificação é derivada; gravá-la materializa situação, contra a ADR 0004 D7 |
| `fetch_issue_from_source/2` | abrir detalhe **não** consulta a origem: tudo vem do banco (FR-033, SC-010) |
| `update_issue/3` | não há edição: a issue é o que a origem disse |
| `list_comments/2` | a contagem é coletada, o conteúdo não (FR-002) |
