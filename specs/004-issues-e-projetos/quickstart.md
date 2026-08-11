# Quickstart — issues e projetos

**Feature**: 004 · **Spec**: [spec.md](spec.md) · **Contratos**: [contracts/](contracts/)

Doze verificações. Cada uma diz o que executar e **o número que precisa aparecer** —
não "funciona", mas o valor conferível.

## Os números vêm de dado real, medido em 2026-08-11

Organização `The-Band-Solution`, pela API do GitHub:

```text
14 repositórios · 157 issues
```

Repositório `theband`, que é o caso mais rico:

```text
95 issues
  Task ....... 79
  Feature .... 15
  Bug ......... 1

Feature COM sub-issues ....... 6
Feature SEM sub-issues ....... 9
Task com pai Feature ........ 78
Task SEM pai ................. 1   ← viola sro.rule07, e existe de verdade
```

**E o caso que a regra de roteamento avisa ser o mais fácil de errar existe no dado
real**, em duas formas:

```text
#  1  39 partes  {Feature, Task}  → ÉPICO
#  3   9 partes  {Task}           → ATÔMICA — tarefas ATENDEM, não compõem
#  4  20 partes  {Task}           → ATÔMICA
#  5   8 partes  {Task}           → ATÔMICA
# 79   8 partes  {Feature, Task}  → ÉPICO
# 98   2 partes  {Feature}        → ÉPICO
```

Três Features **com** sub-issues que **não** são épicos, porque as partes são
tarefas. Se a implementação errar aqui, ela conta três épicos a mais e três user
stories atômicas a menos — e nenhuma tarefa tem a quem se ligar.

## Pré-requisitos

```bash
mix gates                # nove verdes antes de começar
mix ecto.migrate
```

---

## V1 — O kind referenciado tem tabela, e é uma só

```bash
.venv/bin/python scripts/derive_information_model.py --ontology cmpo | \
  grep -A 3 "kinds referenciados"
```

**Precisa aparecer**:

```text
tabelas de kinds referenciados em outras ontologias — criar se ainda não existirem,
uma vez só:

┌─ sys_swo_loaded_software_system_copies  (sys_swo.loaded_software_system_copy, kind de sys_swo)
```

E **não** pode aparecer nenhuma exigência pendente:

```bash
.venv/bin/python scripts/derive_information_model.py --ontology cmpo | \
  grep -c "sem ontouml_stereotype"
# precisa dar 0
```

**O que isto prova**: a regra da fronteira funcionando — um conceito anotado, não
onze. E que os outros 10 conceitos da SysSwO continuam sem estereótipo, porque
anotá-los não era necessário.

---

## V2 — Repositórios descobertos a partir da organização

```elixir
{:ok, _} = TheBand.Ingestion.start_sync(tenant, tool)
TheBand.Ontology.SEON.CMPO.count_repositories(tenant, organization_id: org.id)
```

**Precisa dar 14** para `The-Band-Solution`, e nenhum precisou ser conectado
individualmente.

---

## V3 — A soma fecha: nada desaparece entre coleta e classificação

```elixir
total     = WorkItems.count_collected(tenant, repository_id: repo.id)
promovido = WorkItems.count_by_promotion(tenant, repository_id: repo.id) |> Map.values() |> Enum.sum()
lacuna    = WorkItems.count_gaps_by_reason(tenant, repository_id: repo.id) |> Map.values() |> Enum.sum()

total == promovido + lacuna
```

**Para `theband` precisa dar 95 = 95 + 0** — os três tipos usados têm rota.

**O que isto prova**: SC-001. Se não fechar, alguma promoção não foi registrada, e o
número que a tela mostra passa a ser menor que a realidade sem avisar.

---

## V4 — O caso mais fácil de errar, nos dois sentidos

```elixir
SRO.classification(tenant, us_1.id)   # issue #1  — 39 partes, {Feature, Task}
SRO.classification(tenant, us_3.id)   # issue #3  —  9 partes, {Task}
```

**Precisa dar**:

```text
#1  → :epic               tem partes que são user stories
#3  → :atomic_user_story  as partes são TAREFAS: atendem, não compõem
#4  → :atomic_user_story
#5  → :atomic_user_story
#79 → :epic
#98 → :epic
```

E a contagem:

```elixir
length(SRO.list_epics(tenant, repository_id: repo.id))   # 3
length(SRO.list_atomic(tenant, repository_id: repo.id))  # 12
```

**A verificação que importa é a segunda linha**: `#3` com nove sub-issues **não** é
épico. Se der `:epic`, a implementação confundiu composição com atendimento — e
nenhum outro número compensa, porque as 78 tarefas passam a se ligar a épicos,
violando `sro.rule07`.

---

## V5 — Tarefa sem pai é registrada como divergência, não descartada

```elixir
WorkItems.list_divergences(tenant, repository_id: repo.id)
|> Enum.filter(&(&1.rule == "sro.rule07"))
|> length()
```

**Precisa dar 1** — a tarefa sem pai que existe no dado real.

E ela **continua coletada**:

```elixir
WorkItems.count_collected(tenant, repository_id: repo.id)  # 95, não 94
```

**O que isto prova**: FR-017 na forma geral — recusa-se o vínculo, nunca a issue.

---

## V6 — Tipo desconhecido não vira user story presumida

Criar uma issue de tipo próprio na origem, ou simular no teste:

```elixir
WorkItems.count_gaps_by_reason(tenant, repository_id: repo.id)
# %{type_unknown: 1}

WorkItems.list_issues(tenant, repository_id: repo.id)
|> Enum.find(&(&1.issue_type == "Spike"))
|> Map.get(:derived_concept)
# nil
```

**O que isto prova**: SC-005, e pela violação — a issue existe, está contada, e
`derived_concept` é `nil`. Se aparecer promovida a qualquer conceito, toda medida de
escopo passa a incluir o que ninguém classificou.

**O nome do tipo tem de aparecer** na lacuna: "tipo desconhecido: Spike (1)". Sem o
nome, a lacuna não diz onde a regra precisa mudar.

---

## V7 — A marca de ausência não atravessa repositório

O teste da L19, em volume maior. **Dois repositórios, duas coletas em sequência:**

```elixir
{:ok, _} = collect_repository(tenant, repo_a)   # 19 issues
{:ok, _} = collect_repository(tenant, repo_b)   # 11 issues

# depois de coletar B, as issues de A NÃO podem estar marcadas
WorkItems.list_issues(tenant, repository_id: repo_a.id)
|> Enum.count(& &1.no_longer_observed_at)
```

**Precisa dar 0.**

**O que isto prova**: SC-003, pela violação. Com o escopo por tenant em vez de por
repositório, este número daria 19 — e numa organização de 14 repositórios o defeito
atingiria 13 deles, contra as 3 organizações do defeito original.

---

## V8 — Repositório excluído: para de coletar, e não marca ausência

```elixir
{:ok, _} = CMPO.exclude_from_observation(tenant, repo.id, user.id)
{:ok, relatorio} = collect_organization(tenant, tool)

relatorio.repositories_collected            # não inclui repo.id
WorkItems.list_issues(tenant, repository_id: repo.id)
|> Enum.count(& &1.no_longer_observed_at)   # 0
```

**Os dois lados, e o segundo é o que engana.** A plataforma parou de olhar, e isso
não é o mesmo que o dado ter sumido — FR-005.

---

## V9 — Iteração futura não é sprint

```elixir
{:ok, %{promoted_to: destino}} = Projects.record_iteration(tenant, attrs_futura)
destino
# {:intended_process, uuid}

SRO.count_sprints(tenant, project_id: proj.id)
# não inclui a futura
```

E o par, verificável em uma linha:

```elixir
Projects.list_iterations(tenant, project_id: proj.id)
|> Enum.all?(fn i ->
  (i.sro_sprint_id != nil) != (i.spo_intended_process_id != nil)
end)
# true — exatamente um dos dois, nunca os dois, nunca nenhum
```

**O que isto prova**: SC-009 e SC-009c. Um sprint que não começou não ocorreu, e uma
iteração sem nenhum dos dois registros é iteração perdida.

---

## V10 — Os dois backlogs somam o total de itens

```elixir
produto = length(SRO.product_backlog(tenant, proj.id))
sprints = for s <- SRO.list_sprints(tenant, project_id: proj.id),
              do: length(SRO.sprint_backlog(tenant, s.id))

produto + Enum.sum(sprints) == Projects.count_items(tenant, proj.id)
```

**No quadro real deste tenant: 6 + 73 + 28 = 107.**

**O que isto prova**: SC-009b. Nenhum item nos dois conjuntos, nenhum fora dos dois.
Se a soma passar do total, algum item foi contado duas vezes — e é o sintoma de
alguém ter gravado pertencimento em vez de derivar da atribuição.

---

## V11 — Campo sem mapeamento é guardado, não convertido

```elixir
Projects.list_field_values(tenant, item_id: item.id)
|> Enum.find(&(&1.field_name == "Priority"))
```

**Precisa dar**:

```elixir
%{raw_value: %{"name" => "P1"}, interpreted_as: nil}
```

E:

```elixir
Projects.importance_source(tenant, proj.id)
# :not_declared
```

**O que isto prova**: SC-008 e FR-026. `Priority` é seleção única cujos valores o
tenant inventou; `importance` é decimal com escala declarada. A tela mostra a
ausência por extenso em vez de inventar ordem.

**Contraprova necessária**: `Estimate`, que **tem** mapeamento declarado, precisa vir
com `interpreted_as: "sro.user_story.complexity"`. Sem ela, o teste passaria com a
interpretação quebrada para todos os campos.

---

## V12 — O quadro não aparece como projeto, e o segredo não aparece em tela

```bash
curl -s -b cookies.txt -L http://localhost:4000/quadros > /tmp/q.html

grep -c "não é um projeto" /tmp/q.html          # 1 por quadro
grep -c "projeto Scrum" /tmp/q.html             # 0
grep -c "ghp_" /tmp/q.html                      # 0
```

E o isolamento, pela violação:

```elixir
{:error, :not_found} = Projects.fetch_observed_project(outro_tenant, proj.id)
Projects.list_observed_projects(outro_tenant) == []
```

**O que isto prova**: a decisão de 2026-08-11 visível na tela, SC-011, e SC-012.
"Não encontrado" e nunca "sem permissão" — dizer "sem permissão" já entrega que o
recurso existe.

---

## Ordem de execução

| Fase | Verificações |
|---|---|
| F0 | V1 |
| F2 | V2, V8 |
| F3 | V3, V4, V5, V6, V7 |
| F4 | V9, V10, V11 |
| F5 | V12 |

**V4 e V7 são as que não podem passar por acidente.** V4 distingue composição de
atendimento no dado real; V7 é a L19 num volume quatro vezes maior. Se uma das duas
falhar, nenhuma das outras dez compensa.
