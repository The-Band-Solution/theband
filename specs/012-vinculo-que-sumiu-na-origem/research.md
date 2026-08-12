# Pesquisa — o vínculo que sumiu na origem

**Feature**: `012-vinculo-que-sumiu-na-origem` · **Data**: 2026-08-12
**Método**: ler o código que já existe e medir o banco. Nenhuma decisão aqui vem de memória.

---

## D1 — Qual é o escopo da marca

**Decisão**: o **repositório do pai**. Uma chamada por repositório coletado, com o id dele.

**Por quê, e a evidência**: `vincular/2` recebe os `nodes` de **um** repositório e lê
`subIssues.nodes` **dentro** de cada issue. A origem declara a decomposição de cima para baixo:
quem afirma "esta issue tem estas partes" é o pai. Uma coleta do repositório da **filha** não vê a
lista, e portanto não tem como saber que o vínculo acabou.

**Medido**: **57** dos 1 666 vínculos têm pai e filha em repositórios diferentes. Se o escopo fosse a
filha, esses 57 seriam marcados por engano toda vez que o repositório da filha fosse coletado sem o
do pai.

**Alternativas descartadas**:

| Alternativa | Por que não |
|---|---|
| por tenant | é a **L19** no nível do vínculo: numa organização de 121 repositórios, coletar um marcaria os vínculos dos outros 120 |
| por repositório da **filha** | os 57 vínculos entre repositórios seriam marcados sem que ninguém tenha deixado de declará-los |
| por issue-pai, uma chamada por issue | 4 529 chamadas por coleta para responder o que uma responde; e a issue-pai que **sumiu** da origem não seria visitada — os vínculos dela nunca seriam marcados |

---

## D2 — Dois instantes, e eles não são o mesmo

**Decisão**: **corte** é `sync.started_at`; **data da marca** é o instante em que a ausência foi
notada (`DateTime.utc_now/1`).

**Por quê, e a evidência**: as três implementações irmãs já decidiram isso, e conferi as três:

| O que marca | Corte | Data gravada |
|---|---|---|
| `mark_issues_no_longer_observed/3` | `desde`, o `started_at` da execução | `DateTime.utc_now(:second)` |
| `replace_assignees/3` | quem não veio na lista | `DateTime.utc_now(:second)` |
| `replace_labels/3` | quem não veio na lista | `DateTime.utc_now(:second)` |

**A spec pedia o contrário, e foi corrigida aqui.** A primeira versão do FR-002 mandava gravar o
`started_at` **na marca**. Ler o código mostrou que isso daria à mesma coluna dois significados em
tabelas vizinhas — em `collected_issues` seria "quando notei", em `decomposition_links` seria "quando
a execução começou" —, e qualquer pergunta que atravessasse as duas passaria a comparar coisas
diferentes. Corrigido antes de existir código.

**O corte precisa ser o início da execução**, e esse é o outro lado: `record_decomposition_link/2`
carimba `last_observed_at` com o instante da escrita, sempre **posterior** ao início da execução.
Cortar por "agora" marcaria como ausente o vínculo que a própria execução acabou de gravar.

---

## D3 — Como a marca é aplicada

**Decisão**: um `UPDATE` só, com o conjunto dos pais daquele repositório vindo de subconsulta.

**Por quê**: os 1 666 vínculos e as 4 529 issues cabem num comando. Marcar em laço faria uma ida ao
banco por vínculo, que é o defeito que a feature 007 pagou com 135 consultas por render.

**Índices conferidos, e servem sem migração**:

| Índice | Serve para |
|---|---|
| `collected_issues (tenant_id, observed_repository_id)` | achar os pais do repositório |
| `decomposition_links (parent_issue_id, child_issue_id)` UNIQUE | o prefixo `parent_issue_id` filtra os vínculos daqueles pais |

**Nenhuma coluna nova, nenhuma migração**: `no_longer_observed_at` existe em
`decomposition_links` desde a migração `20260811150500` — o defeito é que nada a escreve.

---

## D4 — Onde a chamada entra na coleta

**Decisão**: dentro de `coletar_issues/2`, no ramo `{:ok, ...}`, **depois** de `vincular/2` e ao lado
de `mark_issues_no_longer_observed/3`.

**Por quê**: `vincular/2` é quem renova os vínculos vistos. Marcar antes dele marcaria todos, e a
renovação em seguida limparia parte — dois estados para o mesmo fato dentro da mesma execução.

**O ramo importa mais que a ordem.** O ramo `{:error, reason}` **não** marca nada, e é a feature 009
inteira: falha transitória que marca tira o repositório de observação, e a coleta seguinte não olha
mais. Um `:nxdomain` de um instante já custou 38 repositórios e 899 issues.

Repositório **excluído** ou **inacessível** nem chega ali: `coletar_repositorios/2` já filtra por
`list_collectable/2` antes.

---

## D5 — Como o número aparece, e por que não vira campo na tela de sincronizações

**Decisão**: a função devolve `{:ok, count}`, a fase soma por repositório, e o log nomeia repositório
e número. **Sem coluna nova em `syncs`, e sem número novo na tela de sincronizações.**

**Por quê**: o consumidor visível já existe — a lista de issues do repositório diz, em texto, que
aquele vínculo acabou. Um segundo número no cartão da sincronização entraria ao lado de "records
collected" e "issues", que respondem outras perguntas, e o princípio X tem o caso concreto deste
projeto: um resumo do tenant dentro do cartão de cada sincronização fez uma coleta de 14
repositórios aparecer com 135 ao lado. Nada falhou, e o número respondia outra pergunta.

**O que fica pior**: quem quiser o total de uma execução precisa do log ou de uma consulta. É aceito:
a pergunta "o que esta coleta deixou de ver" ainda não foi feita por ninguém, e inventar o campo
agora é o padrão sem o problema que o princípio VIII recusa.

**Alternativa descartada**: derivar o total pela janela da execução — `no_longer_observed_at` entre
`started_at` e `finished_at`. Funciona para um tenant com uma ferramenta, e mistura duas execuções
concorrentes de ferramentas diferentes no mesmo tenant. Precisão que depende de não haver
concorrência é precisão que some sem avisar.

---

## D6 — O que a feature 011 já entrega, e o que falta

**Conferido no branch `015-de-quem-a-issue-e-parte`**, que é o PR [#264](https://github.com/The-Band-Solution/theband/pull/264):

| Peça | Estado |
|---|---|
| `list_parents/2` carrega `no_longer_observed_at` | **existe** |
| rótulo *"absent: this link existed and is not present now"* | **existe** |
| "mais de um pai" conta só vigentes (`vigentes/1`, `mais_de_um?/1`) | **existe** |
| **dado que chegue nesse estado** | **não existe** — é esta feature |

**Consequência para o plano**: FR-011 e FR-012 são satisfeitos por código já escrito, e o que esta
feature acrescenta neles é **teste com dado nesse estado**. Hoje nenhum teste pode montar o caso a
partir de uma coleta, porque nenhuma coleta o produz.

**Dependência declarada**: a verificação visível exige o #264 incorporado. A parte de coleta não
depende dele.

---

## D7 — O que fica de fora, e por quê

| Fora | Razão |
|---|---|
| `refused_links` (4 hoje, todas `out_of_scope`) | recusa não é vínculo: nunca foi afirmada como decomposição, e marcar ausência do que nunca foi afirmado não diz nada |
| ciclos recusados | mesmo motivo |
| `fetch_parent/2` sem `order_by` ([#261](https://github.com/The-Band-Solution/theband/issues/261)) | defeito vizinho, com issue própria — refatoração oportunista no mesmo diff é o que o princípio VIII proíbe |
| filha promovida a defeito fora das listas do pai ([#262](https://github.com/The-Band-Solution/theband/issues/262)) | idem |
