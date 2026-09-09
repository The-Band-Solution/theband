# A tela da equipe

**Onde**: `/teams/:id` · **Features**: [057](../../specs/057-tela-da-equipe-complexa/spec.md)
(a equipe composta) e [060](../../specs/060-tela-da-equipe/spec.md) (a tela como ela é hoje),
sobre a base de [055](../../specs/055-equipes-declaradas/spec.md) (o vínculo declarado) e
[058](../../specs/058-medidas-da-equipe/spec.md) (as medidas).

**Régua desta página**: a implementação em
[`show.ex`](../../lib/the_band_web/live/teams_live/show.ex) e
[`problems_now.ex`](../../lib/the_band/teams/problems_now.ex). O que está especificado e ainda
não está na tela vive na última seção,
[*O que ainda não está na tela*](#o-que-ainda-não-está-na-tela) — e não no meio do texto como
se estivesse.

---

## As duas abas, e a pergunta de cada uma

A tela responde **duas** perguntas, e por isso são duas abas — não duas rotas e não uma
página empilhada:

| Aba | A pergunta | O endereço |
|---|---|---|
| **`Dashboard`** | *como esta equipe está* | `/teams/:id` |
| **`Structure`** | *quem está nela* | `/teams/:id?tab=structure` |

A aba escolhida vai ao endereço, então **um link cai onde aponta** e recarregar a página
mantém a aba. Trocar de aba não recarrega a tela. Aba inexistente no endereço não dá erro:
abre o Dashboard e diz por quê — *"A team has no "…" tab. Showing the dashboard."*

**Toda escrita mora na `Structure`. O `Dashboard` só lê.** Declarar papel, registrar uma
saída, marcar um equívoco, compor uma subequipe, criar papel, ligar a equipe a um projeto —
tudo na aba `Structure`. É o que torna o Dashboard legível por qualquer conta do tenant sem
que um botão apareça e desapareça conforme quem olha.

O **cabeçalho é das duas abas**, e os números dele contam **pessoas**, nunca vínculos:

> *N* people here · *N* left · *N* recorded by mistake · *N* with no organisational role

Quem saiu e quem foi registrado por engano aparecem **separados** de quem está. Somá-los
responderia *quantas linhas existem* a quem perguntou *quantas pessoas estão na equipe*. E
uma pessoa com dois papéis vigentes conta **uma** vez: dois papéis não são duas pessoas.

---

## `Problems now` — a primeira seção do Dashboard

Oito cartões, **antes** de qualquer medida, cada um contando **um fato**. O cabeçalho diz
sobre o que se contou — *"counted over the whole team · window of 56 days where a window
applies"* — e a linha abaixo dele diz o que a seção é, e o que ela deliberadamente **não** é:

> *"Each card counts a **fact**, never an inference, and carries the threshold that decided
> the count. Nothing here is ordered by severity — counting is what the platform can do;
> deciding what is urgent is yours."*

Cada cartão carrega, em letra pequena, **o limiar que decidiu a contagem** e **a regra que o
declara**. Não é procedência decorativa: *"46 issues"* sem *"há mais de 30 dias"* é um número
sem pergunta.

| # | O cartão | O limiar escrito nele | A origem |
|---|---|---|---|
| 1 | **`Issues open beyond the threshold`** | `open for more than 30 days` | `team.dashboard.thresholds · open_issue_age` |
| 2 | **`Code changes waiting for a first human review`** | `waiting for more than 7 days` | `team.dashboard.thresholds · review_wait` |
| 3 | **`Pipeline failing now on the default branch`** | `the latest completed check, per repository` | `spec 060 · FR-071` |
| 4 | **`Assigned tasks past the stop threshold`** | `open for more than 90 days` | `profile.thresholds · stale_open_work` |
| 5 | **`People with no open task`** | `no threshold — it is a count of people` | `spec 057 · FR-021` |
| 6 | **`Members with no declared role`** | `no threshold — it is a count of links` | `spec 055 · FR-018` |
| 7 | **`Work outside any declared project`** | `repository or board with no declared project of this team` | `spec 060 · FR-053` |
| 8 | **`Structure anomalies`** | `declared in structure_antipatterns.yaml` | `spec 058 · FR-025` |

Cartão com número maior que zero traz **`see the list`** — o caminho para a lista que produziu
aquele número — quando ela existe nesta tela ou na outra aba. Os cartões 1, 4 e 5 mostram o
número **sem** esse link: a lista que os produziu ainda não tem seção própria.

### Zero não é a mesma coisa que não conferido

Esta é a distinção que carrega a seção inteira, e o motivo de serem oito cartões contados em
vez de uma lista de alertas. Há **três** estados, e nenhum deles é um zero mudo:

| Estado | O que a tela mostra | O que afirma |
|---|---|---|
| contado, maior que zero | o número, em âmbar | *a plataforma olhou, e achou tantos* |
| contado, **zero** | um `0` cinza **seguido das palavras** **`checked, nothing found`** | *a plataforma olhou ali, e não achou nada* |
| **não conferido** | a etiqueta tracejada **`not checked`**, **sem número**, e **o que falta** | *a plataforma não pôde olhar* |

**`0` afirma que a plataforma olhou. Ausência afirma que ela não olhou.** As duas levam a
decisões diferentes, e um zero mudo faz uma passar pela outra. Um cartão com zero **não**
significa que a equipe está bem — significa que aquele fato foi conferido e não estava lá.

### Por que dois dos oito nunca têm número

Os cartões **3** (`Pipeline failing now on the default branch`) e **7** (`Work outside any
declared project`) dizem `not checked` **sempre** — não conforme o dado, mas por construção.
A razão é a mesma nos dois, e está escrita no próprio cartão:

| Cartão | O que falta |
|---|---|
| **3 — pipeline falhando agora** | os insumos **são** coletados — a branch padrão de cada repositório, e a branch de cada verificação. Mas *falhando agora* é outra afirmação que a taxa de sucesso sobre uma janela: é a **última verificação concluída** na branch padrão. A tela diz: *"the query does not exist yet — the inputs are collected (default branch and check branch), and the measure needs a name in the knowledge base before the card counts"* |
| **7 — trabalho fora de projeto declarado** | falta a regra que **nomeia** o fato: *"it needs the rule that names work in a repository or board with no declared project of this team"* |

**Por que não omitir os dois cartões, e por que não mostrar `0`.** Mostrar `0` afirmaria que
todo o pipeline está verde e que todo o trabalho está dentro de projeto declarado — as duas
coisas mais caras que a seção poderia dizer de errado. Omiti-los esconderia que a pergunta
existe. Um cartão sem medida é a única forma de dizer *ainda não sabemos*, e a medida precisa
de **nome na base de conhecimento** antes de o cartão contar.

Cinco dos oito são calculados sobre dado que a página já carregou. Só o cartão 1 faz consulta
própria — e é por isso que a seção não custa oito consultas.

---

## Aba `Dashboard` — como a equipe está

### A equipe composta: um cartão por subequipe, e nenhum total

Quando a equipe tem **duas ou mais** subequipes com composição vigente, o Dashboard traz a
seção **`Teams inside this one`** — *as equipes dentro desta*: um cartão por subequipe,
**mais** um cartão para os **membros diretos** da equipe.

> *"One card per sub-team, plus this team's direct members. Click a card — or its chart — to
> open that team's dashboard."*

Com **uma** subequipe só, a equipe segue como simples: comparar uma linha com nada não é
comparação.

Cada cartão de subequipe é **porta** — clicar nele, ou no gráfico dentro dele, abre o
Dashboard daquela subequipe. O cartão dos membros diretos **não** é porta: já estamos nela, e
um link para a tela em que a pessoa está é um clique que não leva a lugar nenhum; ele leva a
*`see the N people →`*, a seção das pessoas mais abaixo.

Os cartões e as linhas são ordenados por **trabalho parado**, do maior para o menor, e a tela
diz isso: *"Ordered by stopped work, so the row that needs a conversation comes first."*
Ordenar **não é somar** — cada cartão continua com o número dele.

#### Por que nunca há total

A tela dedica um bloco a **explicar**, sob o título `why these rows are not added up`, e não
apenas a afirmar:

> *"The same person can belong to **two sub-teams**, and the same task can appear in both. A
> total would count each of them twice, and nobody could reconcile it with the work that
> exists. Each row is measured on its own."*

É isto: as subequipes **não formam partição**. A mesma pessoa pode estar em duas, e a mesma
tarefa aparecer nas duas. Um total contaria cada uma duas vezes, e ninguém conseguiria
reconciliá-lo com o trabalho que existe.

A frase é obrigatória **porque a seção tem gráfico**. Numa tela com curvas, a ausência de um
total parece descuido — e alguém somaria as linhas para "conferir", chegaria a outro número, e
concluiria que o gráfico está errado. A recusa também está na camada de domínio, e não só no
texto: a função que monta as linhas **não devolve total**, porque não há campo onde ele
caberia.

#### Os dois números do cartão

O nome da subequipe fica à esquerda do cabeçalho e **`N members`** à direita. No vão numérico,
**dois** números — os que respondem *como vai o trabalho*:

| Rótulo | O que é | Quando não há |
|---|---|---|
| **`open items`** | itens abertos com responsável | — |
| **`median wait`** | mediana de espera pela **primeira revisão humana**, em horas | **`no review yet`** — e nunca `0 h`, que afirmaria revisão instantânea |

São os **mesmos** números da tabela abaixo, com os **mesmos** rótulos. Duas apresentações do
mesmo dado precisam dizer o mesmo: quem compara o cartão com a linha e encontra dois números
não sabe qual seguir.

**Por que dois, e não três.** É decisão de Design de 2026-09-09, registrada em
[`decisoes-do-cartao-de-subequipe.md`](../../specs/060-tela-da-equipe/decisoes-do-cartao-de-subequipe.md):

- **`members` subiu para o cabeçalho** — não é medida do trabalho, é propriedade da subequipe.
  No vão numérico obrigava a ler três rótulos para achar os dois sobre trabalho;
- **`stopped` desceu para a tabela** — não há lugar para o limiar num vão daquele tamanho, e o
  número sem o limiar não é interpretável. Na tabela ele tem o limiar no cabeçalho, e é lá que
  precisa estar, porque é por ele que as linhas são ordenadas;
- **`pipeline` não entra.** A razão está no dado: `spo_project_teams` **não tem vínculo para
  nenhuma** das subequipes da equipe composta de referência, então a taxa seria *sem projeto*
  em **todos** os cartões. A recusa já tem lugar próprio na tela, com a razão anexada.

São **dois vãos, não três com uma ausência** — ausência é o valor que falta, não a medida que
não existe. E três cartões com 3, 3 e 2 vãos não alinham.

#### O gráfico pequeno dentro do cartão

É o burn da subequipe, na **mesma janela e granulação** dos gráficos grandes, reduzido a duas
curvas acumuladas: sem eixo, sem rótulo, sem faixa.

Ele responde **a forma** — abriu e fechou juntos, ou a distância cresceu? É a pergunta que
decide se vale abrir o painel daquela subequipe. Ele **não** responde *quanto*: os números
estão no cartão, em texto e alinhados.

Quando a janela não teve **movimento**, não há faísca, e o cartão diz o que de facto não
houve:

> *"Nothing opened or closed in this window — the items below are stock, not movement."*

A frase é precisa de propósito. Antes ela dizia *"No work observed in this window — which is
not the same as zero"* num cartão que exibia, na mesma caixa, itens abertos e parados: as duas
coisas eram verdadeiras e pareciam contradição. **Trabalho parado é estoque sem movimento**, e
é justamente a distância entre os dois que interessa.

#### A tabela, e por que ela não tem gráfico

Abaixo dos cartões, **`The same numbers, side by side`**:

| Coluna | |
|---|---|
| `team` | com link para o painel da subequipe |
| `members` | |
| `open items` | o mesmo número e o mesmo rótulo do cartão |
| `closed · 8w` | |
| `median wait` | ou `no review yet` |
| `stopped · open > 90 d` | **o limiar no cabeçalho**, e não numa nota de pé |

Uma subequipe sem trabalho no período tem a linha substituída por texto — *"No work observed
in the period — which is not the same as zero."* — em vez de quatro zeros.

**A tabela continua sem gráfico**, e é decisão, não lacuna: ela existe para **comparar**, e
comparação se faz em números alinhados. Ler valor numa faísca de 40 pixels seria adivinhar.
Cartão e tabela convivem na mesma seção respondendo perguntas diferentes — **a forma** e **a
quantidade**.

### O fluxo: burn, previsão e `Promised × Delivered`

Os três gráficos cobrem a **equipe inteira** — os membros próprios **mais** todos os das
subequipes com composição vigente —, e a tela declara que a curva **não é a soma** das curvas
das subequipes: o conjunto é a **união distinta**, e a pessoa em duas subequipes e o item com
dois responsáveis contam **uma** vez aqui.

#### O seletor de granulação, e a janela no título

Cada gráfico de fluxo tem o seletor **`week` / `month` / `year`** no cabeçalho, e a **janela
sempre no título**. Os dois seletores da tela mudam o **mesmo** parâmetro do endereço: dois
lugares, **um** só estado.

Cada granulação tem a **sua** janela padrão — 8 semanas, 12 meses, e **todos os anos
coletados** (com cinco anos como recuo quando não há atividade alguma). Trocar a granulação
reagrupa **os mesmos itens** sem mudar o que é medido, e a tela diz isso: *"Changing the
grouping regroups the same items over that granularity's own default window — it does not
change what is measured."*

A janela no título foi a **condição** para o seletor existir. A objeção era o denominador
móvel; a resposta é **dizer** o denominador.

#### `Burn-up and burn-down`

Duas curvas acumuladas — `opened, cumulative` e `closed, cumulative`. A **faixa hachurada**
entre elas é o trabalho ainda aberto, e é **derivada** das duas séries, não uma terceira
linha. A identidade está escrita na tela, para que a distância possa ser conferida sem
confiar no desenho:

```
open(t) = N + opened(t) − closed(t)
```

O eixo X é **linha do tempo com datas**. `2026-W36` é rótulo interno, e ninguém lê número de
semana ISO sem consultar um calendário. Há valor em cada ponto, o teto do eixo escrito, e um
`see as a table` para quem quer os números em vez da forma.

Abaixo do gráfico, a diferença e o horizonte pelo ritmo de fechamento observado — *"The gap is
N items still open. At the closing pace observed in this window — X closed per week — half of
the simulated runs reach zero within N weeks."*

É **faixa com a sua confiança, nunca uma data**. Uma data é lida como promessa, e a plataforma
não tem escopo comprometido. Duas ressalvas acompanham a frase, sempre: **assume que nada novo
entra** — o limite otimista — e **não há escopo comprometido**, logo isto não responde se um
prazo será cumprido.

E quando mais de 15 % das rodadas não chegam a zero dentro do horizonte, a tela diz que **não
há número de 85 %** em vez de escrever *"mais de N semanas"*. Escrever um número ali
inventaria o percentil que não existe.

#### `Delivery forecast` — o histograma, e as duas hipóteses

É a simulação de Monte Carlo, e o que ela produz são milhares de rodadas, cada uma sorteando
uma semana de vazão entre as semanas que **esta equipe realmente teve**. Sem estimativa. A
etiqueta diz de onde vem: **`derived — simulated from this team's own history`**.

Está desenhada como **histograma**, e não como faixa, porque faixa e percentis são três cortes
da distribuição — e três cortes não recuperam a forma. Duas simulações podem ter o **mesmo**
50 % e 85 % com distribuições muito diferentes: uma concentrada em duas semanas, outra
espalhada por oito com dois picos. A primeira é ritmo previsível; a segunda é uma equipe que
alterna semanas cheias e vazias — e a decisão de quem lê muda. Os percentis continuam
desenhados **sobre** o histograma: a forma responde *com que regularidade*, o percentil
responde *até quando*.

As **duas hipóteses** são declaradas com os nomes que a base de conhecimento lhes dá em
[`flow_completion_forecast.yaml`](../../priv/knowledge_base/measurements/flow_completion_forecast.yaml),
empilhadas e com o **mesmo** eixo X:

| Rótulo na tela | A hipótese |
|---|---|
| **`if nothing new opened · frozen scope`** | escopo **congelado** — nada novo entra. É o limite **otimista** |
| **`if work keeps arriving as it has · live scope`** | escopo **vivo** — trabalho novo continua chegando no ritmo observado |

O nome declarado vai junto do texto por uma razão prática: sem ele, a tela descreve as
hipóteses e não as nomeia, e quem for procurar a medida na base não acha o que está vendo.

São dois histogramas, e não um sobreposto: duas distribuições no mesmo par de eixos com barras
translúcidas produzem uma **terceira forma que não existe**. Empilhados, a distância
horizontal entre os picos é o **custo do trabalho novo**.

A **coluna hachurada, separada por um vão**, são as rodadas que **nunca** zeraram. Ela não é a
semana seguinte à última: é *nunca, dentro deste horizonte*, e desenhá-la encostada nas outras
a faria ser lida como mais uma semana. Quando **nenhuma** rodada concluiu, não há barra
nenhuma e a tela escreve isso em palavras — um eixo com doze barras de altura zero afirmaria
que a simulação rodou e não achou nada, quando o que ela achou foi *nunca* em todas as
rodadas. Na tabela-resumo, um traço significa **desconhecido**, nunca *longe*.

**Abaixo do piso, não há previsão.** A tela diz **`No forecast yet.`**, quantas semanas de
histórico e quantos itens fechados são exigidos, quantos a equipe tem, e por que recusar:
*"Below that, the range would cover almost the whole horizon. Refusing says more than a number
nobody could act on."*

> **Exemplo real, com procedência.** Medido no banco de desenvolvimento e registrado no
> [registro da v0.6.0](../releases/v0.6.0.md): a equipe *IA* fecha 22,1 itens por semana com
> 74 em aberto, e **metade das rodadas zera em 4 semanas**. *PLATAFORMA* e *SQUAD GREEN*
> **não** zeram no horizonte — e a tela diz isso, em vez de mostrar uma faixa.

A leitura que a base de conhecimento nomeia como equívoco vale ser repetida aqui: **concluir
que a equipe precisa trabalhar mais quando a hipótese de escopo vivo não converge**. Se a
entrada supera a saída, nenhuma quantidade de esforço dentro das taxas atuais fecha a conta —
a decisão é sobre **o que entra**.

#### `Promised × Delivered`

A definição operacional está **junto do título**, antes do gráfico, e não numa nota de pé:

> **promised** = opened in the period · **delivered** = closed in the period.

E a ressalva, no mesmo lugar: *"There is **no committed scope** in the platform, so this is not
a sprint commitment against a sprint result."*

**`promised` é rótulo para *aberto no período***, e não pode ser lido como compromisso: a
plataforma não registra escopo comprometido. **`delivered` é a issue ser fechada na origem** —
um ato da ferramenta, não um critério de término declarado.

Tem o mesmo seletor `week` / `month` / `year`, a mesma janela no título, e um `see as a table`.
Quando nenhum período da equipe cai dentro do intervalo coletado, a tela diz que **não há o que
comparar** — *"which is not the same as opened zero and closed zero"*.

### `What each person is on` — o que cada pessoa está fazendo

Uma entrada por pessoa do conjunto, com **todas** as tarefas abertas atribuídas a ela
**agora**. Nenhuma é eleita como *a atual*: qual delas é a atual é julgamento que o dado não
faz.

Cada tarefa traz a idade em dias, e a tela declara de onde ela conta:

> *"Every open task assigned, with how long it has been open. Time counts from when the item
> was opened — the source does not record when someone took it on."*

Passado o limiar de parada, a tarefa ganha a marca **`stopped · over 90 d`** — o limiar está
**no rótulo**, lido da base.

Pessoa **sem** tarefa aberta **não some da lista**: aparece com *"No open task assigned"*.
Desaparecer da lista seria a tela decidindo que ela não está na equipe.

A lista de cada pessoa **corta em oito itens**, com *"… N more open items · open the person
→"*. Não é paginação: a pergunta da seção é *o que cada um está fazendo*, e oito itens já a
respondem. Sem o corte, uma pessoa com 114 itens abertos — existe, no `SQUAD PINK` — empurra
as outras quatro do squad para fora da tela. Quem precisa dos 114 precisa da tela da pessoa.

E ao pé da seção: *"A task with more than one person responsible **appears once for each**.
Summing these lines would overcount the team."*

#### A marca do conceito, e de onde ela vem

Antes do título de cada item vem a marca do que aquele item **é**:

| Marca | O conceito | O que o rótulo diz ao passar o mouse |
|---|---|---|
| **`EPIC`** | `sro.epic` | *epic — a user story with parts* |
| **`US`** | `sro.atomic_user_story` | *atomic user story — no parts* |
| **`TASK`** | `sro.intended_scrum_development_task` | *intended development task — declared, not necessarily executed* |
| **`BUG`** | `osdef.defect` | *defect* |
| **`—`** | nenhum | *the mapping rule did not classify this item — no type at the source, and the structure does not decide* |

Ela ocupa o lugar em que antes ficava o identificador da origem. `I_kwDON0TQIs6vA1ZX` é o
`node_id` do GraphQL do GitHub: identifica a issue na origem e **não diz nada** a quem lê a
tela, ocupando o lugar da informação que importa antes do título.

**A marca vem da promoção, não do tipo declarado na origem.** A regra de roteamento
`github.issue_type_routing` tem precedência **estrutura sobre declaração** — e é por isso que
uma issue de tipo `Feature` **com** partes que são user stories é **épico**, e a mesma **sem**
partes é **user story atômica**.

Não é detalhe de implementação. Nesta base o tipo declarado é **nulo em 778 dos 1 154 itens
abertos** (medido no banco de desenvolvimento, registrado em
[`team_work.ex`](../../lib/the_band/work_items/team_work.ex)): uma marca lida do tipo declarado
deixaria **dois terços** da lista em branco.

O **`—`** é o caso em que a regra não classificou: sem tipo na origem, e a estrutura não
decide. Ele aparece, e não fica em branco — desaparecer da tela seria pior que aparecer sem
tradução. Conceito novo na base aparece com o próprio identificador, pela mesma razão.

---

## Aba `Structure` — quem está na equipe

### Uma linha por pessoa

Cada pessoa aparece **uma** vez, mesmo quem tem vínculo direto com a equipe *e* pertence a
uma subequipe. Os dois vínculos ficam **dentro** da linha, e cada um diz de qual equipe vem.

A coluna de papel diz o papel declarado ou, em destaque, **`not declared`** — *papel não
declarado*. Nunca em branco: célula vazia lê-se como *não carregou*, e o que ela precisa dizer
é que **ninguém declarou** o papel.

Equipe sem ninguém não mostra tabela vazia: diz *"Nobody has a link to this team yet — neither
declared nor observed."*

As quatro marcas de um vínculo aparecem **em texto**, com a legenda **antes** da tabela:

| Marca | O que afirma |
|---|---|
| **`declared`** | alguém declarou este vínculo na plataforma |
| **`observed`** | a ferramenta de origem mostra a participação; ninguém declarou o papel |
| **`left`** | a pessoa saiu, com data |
| **`mistake`** | o vínculo **nunca** existiu — e a coluna `since` diz `never` |

Cor sozinha não é marca: a distinção sobrevive sem cor, e é por isso que a legenda é texto.

**`MAINTAINER` não aparece em lugar nenhum desta tela.** Era nível de acesso de administração
no GitHub apresentado ao lado de uma coluna de papel — e lido como papel por quem passava os
olhos. `MAINTAINER` nunca foi papel na organização. O dado continua gravado; saiu da tela.

### Papéis: declarar, acrescentar, trocar

Os botões, para quem gere a estrutura:

| Botão | Onde | O que faz |
|---|---|---|
| **`Declare role`** | na linha, onde a pessoa **não** tem papel algum | declarar sobre um vínculo *observado* **completa o mesmo vínculo** — o registro não é recriado |
| **`＋ Add role`** | na linha, onde já há papel | **acrescenta** um segundo: *Developer* e *Scrum Master* ao mesmo tempo é comum, e o primeiro continua valendo |
| **`Change`** | **ao lado de cada papel**, na coluna de papel | **encerra** aquele papel e abre o novo; os outros continuam |

**Por que o `Change` é por papel, e não um por linha.** Com um botão só no fim da linha, quem
tinha dois papéis vigentes clicava sem saber qual estava trocando — e a tela não perguntava. O
botão encerrava o primeiro por ordem de criação. Ao lado de cada papel, **qual muda é o que a
pessoa clicou**.

O `Change` só aparece sobre papel **desta** equipe e **vigente**. Trocar o papel de alguém numa
subequipe é trabalho na tela daquela subequipe, onde o veredito é o dela; fazê-lo daqui faria
a autoridade atravessar de lado.

No formulário, **a data `since` vem vazia**, com o texto dizendo o que vazio significa:
*"empty date = unknown, never today"*. Um campo já preenchido é enviado como está, e a data de
hoje passaria a ser a data de início de quem começou no ano passado.

**`＋ new role…`** abre o campo `name of the new role` **sem sair da linha**: cria o papel na
organização da equipe e o declara na mesma submissão. O código sai do nome — *Tech Lead* vira
`tech_lead` — e é editável; a partir do momento em que você digita no código, a sugestão para
de sobrescrever.

Depois de trocar, a linha traz **dois** vínculos: o antigo com o período fechado, e o novo.
Não há tabela de histórico de papel, e isso **não é lacuna** — o histórico *é* a linha
encerrada. E trocar para o papel que a pessoa já tem é **recusado**, sem que nada mude: a
transação desfaz o encerramento.

Para quem tem muitos vínculos observados sem papel, há a declaração **em lote** —
*"N observed member(s) without a declared role"*, com **`Declare all roles`**, que pula as
linhas sem papel escolhido e **diz quantas** pulou.

### Saída e equívoco são coisas diferentes, e a tela diz qual

Esta é a distinção mais consequente da aba, porque as duas se parecem e fazem o oposto uma da
outra:

|  | **`Left the team…`** — a saída | **`Mistake…`** — o equívoco |
|---|---|---|
| o que afirma | a pessoa **pertenceu**, e deixou de pertencer na data *D* | o vínculo **nunca** existiu |
| efeito nas medidas | fecha um período que existiu: números de período **anterior a *D*** não mudam | sai de **toda** medida, em **toda** data |
| o campo | `{nome} left on` — e vem **vazio** | **`why`** — obrigatório, com exemplo: *e.g. wrong login picked when declaring* |
| o botão | **`Record departure`** | **`Invalidate link`** |
| o que a tela recusa | enviar sem data — *"A departure needs a date — the platform does not assume today."* — e data no futuro | razão vazia, e **nada** é gravado |

Nada é apagado, nos dois casos. O equívoco é **marca**, não remoção, e a tela diz por quê:

> *"**This is not "left the team".** A mistake is a link that never was: it leaves every
> measure, for **every date**. The record stays — with the reason, who, and when — because the
> mistake itself is a fact."*

Vale igualmente para vínculo `declared` e `observed`. Depois de registrar, a mensagem diz
**quantos vínculos** foram alcançados: numa pessoa com dois papéis, diz 2 — omitir o número
esconderia que a ação alcançou mais do que a linha clicada.

E depois de qualquer dos dois, **a próxima coleta não recria o vínculo** enquanto a origem
continuar mostrando a pessoa. A evidência da origem fica viva, e a tela mostra as **duas
afirmações lado a lado** em `Source and declaration disagree` — sem escolher entre elas, nem
mesmo a mais recente. Escolher esconderia que a origem não foi atualizada, e isso é informação
sobre a **organização**, não ruído.

### A seção `Roles`

Os quatro papéis do catálogo SRO e os criados pela organização, com origem e código, e
**quantas pessoas** desempenham cada um: `people here` e `in the organisation`. A mesma pessoa
com o mesmo papel em duas equipes conta **uma** vez na coluna da organização.

Papel do catálogo **não** tem `Rename` nem `Hide`: o nome vem da rede de conceitos, e mudá-lo
aqui faria a plataforma discordar da [ontologia que ela publica](../ontology/sro.md). Ocultar
um papel que tem gente é recusado dizendo **quantos** vínculos impedem — e ocultar é **marca**,
não remoção.

O papel criado aqui é o **mesmo** que aparece em `/roles` — uma porta, um escopo. Se
aparecesse só num dos dois lugares, seriam dois catálogos divergindo em silêncio.

### Quem não gere lê tudo, e não vê ação

A lista inteira, os papéis, as subequipes — tudo legível por quem alcança a equipe. E
**nenhum botão**: no lugar dele, a **recusa nomeada**, que diz o que fazer para conseguir.

A proteção **não é esconder o botão**. O veredito é re-perguntado no servidor a cada ação, e
disparar o evento sem passar pelo formulário é recusado com motivo.

---

## Os limiares

Um limiar decide **o número** que quem gerencia vê. Por isso ele **não vive em constante de
código**: é decisão sobre o que a plataforma afirma, e mudá-lo é decisão registrada. Em
constante, o limiar muda num diff de template e ninguém percebe que a plataforma passou a
afirmar outra coisa.

| Limiar | Valor | A regra que o declara | Onde aparece |
|---|---|---|---|
| **issue aberta** | **30 dias** desde a abertura na ferramenta | `team.dashboard.thresholds`, regra `open_issue_age`, campo `open_days` — [`team_dashboard_thresholds.yaml`](../../priv/knowledge_base/rules/team_dashboard_thresholds.yaml) | cartão 1 de `Problems now` |
| **espera por revisão** | **7 dias** sem a primeira revisão **humana** | `team.dashboard.thresholds`, regra `review_wait`, campo `wait_days` — [mesmo arquivo](../../priv/knowledge_base/rules/team_dashboard_thresholds.yaml) | cartão 2 de `Problems now` |
| **trabalho parado** | **90 dias** desde a abertura do item | `profile.thresholds`, regra `stale_open_work`, campo `stale_days` — [`profile_thresholds.yaml`](../../priv/knowledge_base/rules/profile_thresholds.yaml) | cartão 4; a marca `stopped · over 90 d`; a coluna `stopped · open > 90 d` |

**`humana`, na espera por revisão, é parte da definição** e não detalhe: revisão de robô não
substitui a leitura de alguém, e contá-la faria a espera desaparecer justamente onde ela dói.

**Há um só limiar de parada na plataforma.** O limiar da tela da equipe é o **mesmo** de
`profile.thresholds` — o painel e o perfil da pessoa leem o mesmo valor. A alternativa, um
segundo limiar de parada, seria a mesma pergunta com dois números em telas diferentes: a
plataforma discordando de si mesma. A leitura *"14 dias sem mudança de estado"* foi **recusada**
em 2026-09-07 por medir outra coisa — *silêncio no registro*, e não *idade do trabalho aberto*.

E se a regra faltar na base, o cartão diz **`not checked`** em vez de contar com um limiar
inventado.

### Um limiar **não afirma atraso**

Vale para os três, e é a ressalva que precisa acompanhar todo lugar em que um limiar aparece.

**A origem não registra prazo.** Nenhum destes números significa que alguém demorou.
Significam que o item cruzou uma linha que a organização escolheu, e que **alguém precisa
olhar**. Um item de 400 dias pode estar exatamente onde deveria estar; um de 20 pode estar
perdido.

É o que a base de conhecimento diz, com o cuidado de atribuir a recusa ao **registro** e nunca
à pessoa:

> *"A listagem não afirma atraso nem culpa: a origem não registra prazo. O que se pode dizer é
> que o item está aberto há esse tempo e precisa de destino — concluir, repassar, ou cancelar
> com motivo."*
>
> — [`profile_thresholds.yaml`](../../priv/knowledge_base/rules/profile_thresholds.yaml),
> `stale_open_work`

A tela repete a mesma ideia em `What each person is on`: *"**Stale** … is an invitation to ask,
not a verdict."*

---

## Ausência é dita. Nunca zero.

Não é preferência de redação — é a regra que decide o que a tela pode afirmar, e ela reaparece
em todas as seções acima:

| O que aconteceu | O que a tela diz | O que ela **não** diz |
|---|---|---|
| o insumo não é coletado | **`not checked`**, **e o que falta** | `0` |
| conferiu e não achou | `0` **seguido de** **`checked, nothing found`** | um zero mudo |
| a janela não teve movimento | *"Nothing opened or closed in this window — the items below are stock, not movement."*, e **não desenha** faísca | uma faísca reta em zero |
| subequipe sem trabalho no período | *"No work observed in the period — which is not the same as zero."* | quatro zeros na linha |
| nenhuma revisão ainda | **`no review yet`** | `0 h`, que afirmaria revisão instantânea |
| nenhum período no intervalo coletado | *"nothing to compare — which is not the same as opened zero and closed zero"* | duas barras de altura zero |
| a equipe não tem projeto declarado | *"This is not a rate of zero: zero would say the pipeline failed."* | `0 %` |
| abaixo do piso da previsão | **`No forecast yet.`**, o que falta em número, e por que recusar diz mais | uma faixa larga com rótulo de 85 % |
| nenhuma rodada da simulação concluiu | em palavras | doze barras de altura zero |
| percentil que não existe | *"There is **no 85% figure**"* | *"mais de N semanas"* |
| ninguém declarou o papel | **`not declared`**, em destaque | célula em branco |
| início do vínculo desconhecido | *"empty date = unknown, never today"* | a data de hoje |
| a pessoa não tem tarefa aberta | *"No open task assigned"*, e a pessoa **fica** na lista | a pessoa sai da lista |
| a pessoa não tem perfil de competências | *"**That is a gap in the record**, never a statement about the person."* | "nenhuma habilidade" |
| a regra de mapeamento não classificou | **`—`**, com o motivo no rótulo | `TASK` por omissão |

A distinção que carrega todas as linhas é uma só: **`0` afirma que a plataforma olhou e não
achou. Ausência afirma que ela não olhou.** As duas levam a decisões diferentes, e um zero
mudo faz uma passar pela outra.

---

## O que ainda não está na tela

Esta seção existe porque a alternativa era descrever, no presente, coisa que quem abrir a tela
não vai encontrar.

**As duas medidas que faltam nomear.** Os cartões 3 e 7 de `Problems now` dizem `not checked`
porque a consulta não existe e a medida não tem nome na base de conhecimento — ver
[acima](#por-que-dois-dos-oito-nunca-têm-número). Os insumos do cartão 3 **já são coletados**;
o que falta é a consulta e o nome.

**Especificado, sem tarefa planejada** — da feature 060:

| O que | User story |
|---|---|
| o **perfil de cada membro** dentro da tela da equipe | US6 |
| as **tarefas e problemas por pessoa** como seção própria | US8 |
| os **quatro gráficos por membro** — WIP, prometido × realizado, throughput, Monte Carlo | US10 a US12, especificadas em [`spec-graficos-por-membro.md`](../../specs/060-tela-da-equipe/spec-graficos-por-membro.md) e **sem protótipo aprovado** — e a casa não implementa tela sem ele |

**`MAINTAINER` não aparece em tela nenhuma.** O nível de acesso de administração no GitHub
continua gravado no banco e não tem consumidor visível. É lacuna a decidir — mostrar onde
pertence, ou declarar que não se mostra —, e está registrada no
[registro da v0.6.0](../releases/v0.6.0.md).

**A interface está em inglês, e há trechos em português nela.** Os textos das regras da base
de conhecimento — as anomalias de estrutura, as frases de competências da equipe — são
renderizados na língua em que a base os escreve, que é português, dentro de uma tela em
inglês. Nenhuma regra da base tem tradução, e traduzir só uma deixaria a base inconsistente. É
item de backlog em [`portugues-na-interface`](../backlog/portugues-na-interface.md).

O item de backlog da tela é [`tela-da-equipe`](../backlog/tela-da-equipe.md), e as perguntas
que o painel ainda não responde estão em
[`perguntas-do-painel-da-equipe`](../backlog/perguntas-do-painel-da-equipe.md).

---

## Onde conferir

| O quê | Onde |
|---|---|
| os requisitos e as user stories | [`specs/060-tela-da-equipe/spec.md`](../../specs/060-tela-da-equipe/spec.md) |
| como conferir cada cenário à mão | [`specs/060-tela-da-equipe/quickstart.md`](../../specs/060-tela-da-equipe/quickstart.md) |
| as decisões sobre o cartão de subequipe, com o dado que as decidiu | [`decisoes-do-cartao-de-subequipe.md`](../../specs/060-tela-da-equipe/decisoes-do-cartao-de-subequipe.md) |
| a equipe composta | [`specs/057-tela-da-equipe-complexa/spec.md`](../../specs/057-tela-da-equipe-complexa/spec.md) |
| o veredito de aceitação, user story por user story | [registro da v0.6.0](../releases/v0.6.0.md) |
| os limiares declarados | [`team_dashboard_thresholds.yaml`](../../priv/knowledge_base/rules/team_dashboard_thresholds.yaml) e [`profile_thresholds.yaml`](../../priv/knowledge_base/rules/profile_thresholds.yaml) |
| a previsão, e o que ela não afirma | [`flow_completion_forecast.yaml`](../../priv/knowledge_base/measurements/flow_completion_forecast.yaml) |
| a implementação | [`show.ex`](../../lib/the_band_web/live/teams_live/show.ex) e [`problems_now.ex`](../../lib/the_band/teams/problems_now.ex) |
| o modelo de dependências entre as user stories da 060 | [DSM da 060](../modelos/dsm/060-tela-da-equipe.md) |
| o ciclo de vida do vínculo de equipe | [máquina de estados](../modelos/estados/vinculo-de-equipe.md) |
