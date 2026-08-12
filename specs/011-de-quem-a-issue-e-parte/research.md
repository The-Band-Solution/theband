# Pesquisa — Feature 011: de quem cada issue é parte

Cinco questões. Três foram respondidas por **medida no dado real**, e uma achou defeito numa função
que já existe.

| Questão | O que decidiu |
|---|---|
| R1 | quem decide a relação é o **conceito da filha** — e o defeito não cai em nenhuma |
| R2 | `fetch_parent/2` tem `limit: 1` **sem ordem** — 36 issues afetadas |
| R4 | **duas** consultas — uma por fronteira, e a segunda é o nome do repositório |
| R6 | a coluna **não** repete o aviso de tarefa sem pai: seriam 2 091 células |

---

## R1 — Qual relação a linha mostra, e quem decide

**Decisão**: a relação é decidida pelo **conceito da filha**, e a **dupla** decide só a violação —
por `Axioms.rule07/2`, que já existe. Quatro respostas, e a quarta é "a ontologia não nomeia".

**Razão de ser o conceito da filha**: é assim que a plataforma **já** decide, do outro lado da mesma
relação. `list_composition/2` filtra filhas promovidas a épico ou user story; `list_attendance/2`,
filhas promovidas a tarefa. A coluna decidir pela dupla faria a mesma relação ter nome diferente
dependendo da tela por onde se olha.

**Medido**, por conceito da filha:

| conceito da filha | vínculos | a relação é |
|---|---:|---|
| tarefa | 1 436 | atendimento — **293** deles violando a `sro.rule07` |
| user story | 183 | composição |
| épico | 14 | composição |
| **defeito** | **33** | **a ontologia não nomeia** |

**E aqui a medida achou um defeito no que já existe.** Uma filha promovida a **defeito** não cai em
`list_composition/2`, não cai em `list_attendance/2`, e não cai em `list_unpromoted_parts/2` — que é
das filhas **sem** conceito. **Os 33 vínculos não aparecem no detalhe do pai.** É a família do
sucesso silencioso: nenhum erro, nenhuma linha, e a tela parece completa.

**Registrado como dívida vizinha**, não corrigido aqui: a tela do pai é outra tela, e esta feature
mostra os 33 corretamente do lado da filha — dizendo que o vínculo existe e que a ontologia não
nomeia a relação.

**Recusado: chamar de composição o que não é.** Enfiar defeito em composição daria à tela uma
convicção que a rede de ontologias não sustenta — `sro.epic_composed_of_user_story` fala de user
story, e defeito é `osdef`.

**Razão para reusar o axioma**: `rule07_violations/2` já roda essa decisão na **mesma tela**, num
painel separado. Duas implementações fariam a lista avisar sobre uma issue que o painel declara
correta — e o projeto já pagou por dois caminhos para uma decisão três vezes: em `classification/2`,
na prévia contra o recálculo, e na coleta contra o recálculo.

**O que fica pior**: a lista passa a depender do axioma, e mudar o axioma muda duas telas de uma vez.
É o comportamento desejado: elas afirmam a mesma coisa.

**Recusado: uma tabela de duplas na tela.** Nove duplas hoje, e a décima nasce na primeira coleta com
tipo novo. Uma tabela literal ficaria incompleta em silêncio, e o axioma decide por conceito, não por
enumeração.

---

## R2 — Os 36 pais múltiplos, e o defeito que já existe

**Medido**: **36** issues têm mais de um pai. E `fetch_parent/2`, usada no detalhe da issue:

```elixir
limit: 1,
select: %{id: c.id, number: c.number, ...}
```

**`limit: 1` sem `order_by`.** Para as 36, o pai devolvido é o que o plano de execução entregar
primeiro — e isso pode mudar entre execuções, entre versões do PostgreSQL, ou depois de um `VACUUM`.

**Decisão**: a consulta desta feature devolve **todos** os pais, com ordem determinística, e a linha
diz quando há mais de um. **A função existente não é reusada como está.**

**Razão**: escolher um pai em silêncio é o que a L20 proíbe — estado derivado do "um" precisa de
desempate. E aqui a escolha é pior que arbitrária: ela **esconde** que existe outro.

**O que fica pior**: a consulta devolve lista onde a antiga devolvia um, e a tela precisa tratar o
plural. É o custo de não mentir sobre 36 linhas.

**Declarado como dívida vizinha**: `fetch_parent/2` continua com o defeito no detalhe da issue. Não é
escopo desta feature — a tela dela mostra a decomposição completa por outro caminho —, e vai para o
backlog.

---

## R3 — O pai em outro repositório

**Medido**: **57** vínculos têm pai em repositório diferente do da filha.

**Decisão**: quando o repositório difere, a linha diz **de qual repositório** o pai é.

**Razão**: `#12` existe em vários repositórios — esta organização tem 121, e vários têm `#1`. Mostrar
só o número faria a linha apontar para a issue errada na cabeça de quem lê. É a **L25**: o número não
identifica.

**Quando o repositório é o mesmo**, o número basta — e repetir o nome do repositório em 1 609 linhas
gastaria a atenção que os 57 precisam ter.

---

## R4 — O custo, e onde a consulta vive

**Decisão**: **duas** consultas — uma por fronteira. A primeira, em `WorkItems`, traz os pais de
**todas** as issues da página, agrupados. A segunda, em `CMPO`, traz os nomes dos repositórios
observados e vira mapa.

**Razão**: a tela pagina em 50, e um repositório real tem 2 514 issues. Consultar o pai por linha
seria 50 consultas por render — o defeito que a feature 007 pagou com 135.

E o teste mede como a feature 010 mediu: **a diferença** contra a tela sem a coluna, e a
**constância** entre uma página de poucas issues e uma de muitas. É a L38.

**Por que duas, e não uma**: o pai vem com `observed_repository_id`, e o **nome** do repositório é de
`CMPO`. `WorkItems` juntar a tabela de CMPO quebraria a fronteira da ADR 0003 — e resolver o nome por
linha seria o defeito que a própria FR-013 existe para impedir. É a **mesma terceira fronteira** que a
análise da feature 010 achou no A1, e a solução é a mesma: `CMPO.list_observed/2` virando mapa, como
`nomes_de_repositorio/1` em `people_live/show.ex`.

**Incondicional, e não "só quando houver pai fora"**: 135 repositórios num mapa custam uma consulta
barata, e um ramo condicional faria o número de consultas variar com o dado — o que tornaria a
constância do SC-008 impossível de asserir.

**Onde vive**: a consulta dos pais em `TheBand.WorkItems`, ao lado de `fetch_parent/2`. A relação é de
trabalho, e a fronteira é a mesma. A composição das duas é do LiveView, que já compõe três fronteiras
nesta tela.

---

## R5 — O que a linha diz quando não há pai

**Decisão**: texto dizendo que a issue **não é parte de nada**, e nunca célula vazia.

**Medido**: **2 863** das 4 529 estão nesse caso — a maioria. Uma coluna vazia em 63% das linhas
seria ruído, e é por isso que o texto é curto.

**Razão**: ausência é nomeada. Célula vazia não distingue "não é parte de nada" de "a plataforma não
sabe" — e aqui ela sabe.

**Recusado: esconder a coluna quando nenhuma issue tem pai.** A coluna sumindo mudaria a tabela de
forma imprevisível, e quem lê não saberia se a informação não existe ou se ela não foi pedida.

---

## R6 — A tarefa sem pai, e o aviso que a coluna não dá

**Decisão**: a coluna caracteriza **a relação**. Sem pai não há relação, e a coluna diz apenas a
ausência — **sem** o aviso de violação.

**Medido**, entre as 2 899 issues sem pai:

| conceito | sem pai |
|---|---:|
| **tarefa** | **2 091** |
| user story | 615 |
| defeito | 154 |
| épico | 39 |

**O que isso quase causou.** `Axioms.rule07/2` devolve `{:violation, :task_without_parent}` quando o
conceito do pai é `nil`. Chamar o axioma com o pai ausente — o caminho óbvio, e o que a FR-006 parece
pedir — encheria **2 091 das 2 899** células de aviso, e as **293** que são o caso interessante
ficariam indistinguíveis num mar de avisos.

**Razão**: o axioma tem duas formas de violação, e o próprio moduledoc diz que **somá-las esconderia**
que pedem ações diferentes. A tela já as separa em **dois painéis**, cada um com sua contagem e seu
texto. A coluna repetir uma das duas em 2 091 linhas não acrescentaria informação — desidrataria a
que ela existe para dar.

**O que fica pior**: quem lê só a coluna vê "not part of anything" numa tarefa e não sabe que isso é
violação. A mitigação está na mesma tela, acima da tabela, com a contagem — e a coluna não tem como
dizer tudo sobre 2 899 linhas sem parar de dizer o que é dela.

**Recusado: chamar o axioma sempre e mostrar o aviso só quando há pai.** Seria a decisão certa tomada
no lugar errado: a tela filtrando o resultado do axioma é exatamente a segunda implementação que a
FR-006 proíbe. A coluna chama o axioma **quando há pai**, e essa é a condição, não um filtro sobre a
resposta dele.
