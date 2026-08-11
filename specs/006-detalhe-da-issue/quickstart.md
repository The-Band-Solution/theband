# Quickstart — Feature 006: detalhe da issue e decomposição navegável

Doze verificações que provam a feature de ponta a ponta. Os números vêm do **dado real**,
medidos no banco de desenvolvimento em 2026-08-11: 4463 issues, 1020 promovidas, 24 épicos,
110 tarefas, 1624 vínculos, 135 repositórios.

## Pré-requisitos

```bash
docker compose up -d
export THE_BAND_MASTER_KEY=...        # a sua; nunca no repositório
mix ecto.migrate
mix phx.server                        # localhost:4000
```

Os campos novos ficam nulos nas issues já coletadas até a próxima sincronização. **V1 depende
de sincronizar**; V2 a V12 funcionam com o que já está no banco.

---

## V1 — Os campos novos chegam da origem

Sincronize uma organização em `/sincronizacoes` e confira:

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) filter (where body is not null) as com_corpo,
       count(*) filter (where author_login is not null) as com_autor,
       count(*) filter (where state_reason is not null) as com_motivo,
       count(*) from collected_issues;"
```

**Esperado**: `com_corpo` e `com_autor` maiores que zero depois da coleta; antes dela, zero.
O contraste é a evidência de que o retrofito acontece na coleta seguinte, como a spec declara.

**Falha típica**: `com_corpo` continua zero depois de sincronizar → a consulta GraphQL não
pediu `bodyText`, ou o `record_collected_issue/2` não repassou o campo.

---

## V2 — Corpo ausente é declarado, não mostrado vazio

Abra uma issue nunca reobservada em `/trabalho/issues/:id`.

**Esperado**: "Corpo não coletado. Esta issue foi observada antes de a plataforma passar a
pedir o corpo à origem."

**E o que NÃO pode aparecer**: "A issue não tem descrição na origem." Esse texto é para
`body == ""`, e afirmá-lo sobre issue não reobservada seria mentir sobre a origem.

---

## V3 — Composição e atendimento, separadas e nunca somadas

```bash
mix test test/the_band_web/live/issue_detail_test.exs -o "mostra 9 e 30"
```

**Esperado**: no épico do cenário, **9** na composição e **30** no atendimento; e o `refute
html =~ ">39<"` passa.

**Por que este é o teste que mais importa**: 39 é exatamente a soma. Se ele passar a falhar, a
tela voltou a apresentar as duas relações como uma — que é o SC-004.

---

## V4 — A user story com nove tarefas é atômica

```bash
mix test test/the_band/work_items/detail_test.exs -o "nove tarefas atendendo"
```

**Esperado**: `list_composition/2` devolve `[]`, `list_attendance/2` devolve 9, e
`classification/2` devolve `:atomic_user_story`.

**Se falhar**: tarefa passou a compor user story. No dado real isso faz 110 tarefas se ligarem
a épicos, violando `sro.rule07` em massa.

---

## V5 — As 41 tarefas com pai épico aparecem com o aviso

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
with vig as (select distinct on (collected_issue_id) collected_issue_id, derived_concept
             from issue_promotions order by collected_issue_id, inserted_at desc)
select count(*) from decomposition_links l
  join vig c on c.collected_issue_id = l.child_issue_id
  join vig p on p.collected_issue_id = l.parent_issue_id
 where l.no_longer_observed_at is null
   and c.derived_concept = 'sro.intended_scrum_development_task'
   and p.derived_concept = 'sro.epic';"
```

**Esperado**: `41`, e as mesmas 41 aparecem na tela do repositório sob "Tarefas cujo pai é
épico", com `sro.rule07` nomeado.

**E as 41 continuam promovidas**: a mesma consulta com
`c.derived_concept is not null` devolve 41. O inválido é o vínculo, não a issue.

---

## V6 — As 3 tarefas sem user story aparecem com o mesmo axioma

Mesma consulta, com `not exists` no vínculo: **3**.

**Esperado**: seção própria — "Tarefas sem user story" —, separada da anterior. As duas formas
de violar pedem ações diferentes, e somá-las esconderia qual tomar.

---

## V7 — Os dois caminhos do axioma concordam

```bash
mix test test/the_band/work_items/detail_test.exs -o "concorda com a verificação de uma issue"
```

**Esperado**: o conjunto que a consulta em lote devolve é **igual** ao que sai de verificar
issue por issue.

**Por que existe**: é a lição de `classification/2` na segunda forma. Duas implementações do
mesmo axioma fariam a tela do repositório avisar o que o detalhe da issue nega.

---

## V8 — A contagem do repositório soma o total

Abra `/trabalho/repositorios/:id`.

**Esperado**: promovidas por conceito + não promovidas por motivo == total de issues do
repositório. Quando não fecha, a tela mostra o desvio em vermelho — nunca esconde.

```bash
mix test test/the_band_web/live/issue_detail_test.exs -o "contagem do cabeçalho soma"
```

---

## V9 — A paginação é estável

```bash
mix test test/the_band_web/live/issue_detail_test.exs -o "paginação é estável"
```

**Esperado**: a mesma ordem em duas leituras. A ordenação é `(repositório, número, id)` —
ordenar só por número daria páginas que se sobrepõem, porque o número repete entre os 135
repositórios.

---

## V10 — Abrir detalhe não consulta a origem

Com o servidor no ar, abra dez issues em sequência e confira o consumo:

```bash
grep -c "graphql" /tmp/the_band_server.log 2>/dev/null || echo "sem requisição registrada"
```

**Esperado**: nenhuma requisição nova à origem. Tudo o que a tela mostra vem do banco —
FR-033. Navegar pelo produto não pode gastar cota da API.

---

## V11 — Isolamento entre tenants

```bash
mix test test/the_band_web/live/issue_detail_test.exs -o "outro tenant"
```

**Esperado**: redirecionamento com "não encontrada" / "não encontrado".

**E o que NÃO pode aparecer**: a palavra "permissão". Dizer "sem permissão" confirmaria que o
recurso existe.

---

## V12 — Idempotência dos designados e rótulos

```bash
mix test test/the_band/work_items/detail_test.exs -o "não duplica"
```

**Esperado**: substituir duas vezes com o mesmo dado deixa uma linha. E substituir com uma
lista menor **remove** a que saiu — semântica declarada em R3, contra a regra geral do
projeto, com o critério de reversão escrito.

---

## Os nove gates

```bash
mix gates
```

**Esperado**: `9 gates verdes`, e código de saída zero. Conferir pelo texto não basta — o
validador Python avisa que pulou e sai diferente de zero, e foi a L23.
