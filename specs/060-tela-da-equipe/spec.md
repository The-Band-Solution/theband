# Feature Specification: A tela da equipe — quem está nela, e como ela está

**Feature Branch**: `feat/060-tela-da-equipe`

**Created**: 2026-09-07

**Status**: Draft — escrita pelo papel de Product Owner a pedido da pessoa
mantenedora em 2026-09-07, sobre o protótipo aprovado no mesmo dia
([`prototipo/README.md`](prototipo/README.md)). As **oito decisões** registradas
ali estão incorporadas e **não são reabertas** aqui — inclusive a **decisão 9**,
acrescentada no mesmo dia depois do início desta escrita: o Dashboard é a **visão
geral do gestor**, com *Problemas agora* e *Pessoas*. As quatro perguntas que esta
escrita deixou abertas, e seis outras levantadas pela coordenação, foram
**respondidas pela pessoa mantenedora em 2026-09-07** — ver *Decisões de
2026-09-07*. Nenhuma pergunta da escrita de 2026-09-07 segue em aberto.

**Emenda de 2026-09-10 — a aba *Flow per person*.** Esta spec passou a carregar os requisitos
da terceira aba (US10 a US12, FR-085 a FR-131, SC-022 a SC-038), transcritos do protótipo
aprovado em 2026-09-08 e da escrita de 2026-09-08 que o antecedeu. **Nove decisões seguem
abertas** para essa aba — Q18 a Q26, na seção *Decisões do protótipo da aba Flow per person* —,
e três delas bloqueiam: Q20 o código de duas colunas, Q21 e Q25 a aceitação.

**Input**: User description, na ordem em que veio: "Vamos projetar a tela de
equipes. Uma equipe tem um dashboard com as métricas, uma tela de estrutura
contendo a lista de subequipes, seus membros e permitindo deletar um membro
(quando cadastrou errado), informar que um membro não faz mais parte (informando a
data de saída), o papel de cada membro e as subequipes que faz parte dela." — "na
tela de estruturação da equipe permita criar os roles" — "adicione também na tela
principal gráfico de burn up e burn down por semana, mês e ano, Prometido vs
Entregue e Monte Carlo" — "adicione em quais projetos estão trabalhando" — "se a
equipe é composta, pode mostrar o resumo dos dados de todas as subequipes, e ao
clicar nela ou no gráfico vemos os detalhes". Foco declarado: **primeiro definir os
membros, depois definir subequipes.**

**Referência visual**: [`prototipo/team-dashboard-structure.html`](prototipo/team-dashboard-structure.html).
Onde o protótipo e esta spec divergirem, **a spec vence** — e a divergência é
registrada na seção *Premissas*.

**Referência visual da aba *Flow per person***:
[`prototipo/team-people.html`](prototipo/team-people.html), publicada em
`https://claude.ai/code/artifact/a8c7e08c-e9df-4a28-94ea-0800087f9751` em **2026-09-08** —
**terceira tela** da mesma feature, com endereço próprio, e que **não altera** o protótipo de
2026-09-07. A régua da aceitação é a **seção 3** de
[`prototipo/team-people-PROMPT.md`](prototipo/team-people-PROMPT.md), 26 itens; as decisões
estão em [`prototipo/team-people-README.md`](prototipo/team-people-README.md).

### A aba *Flow per person* — de onde vieram FR-085 a FR-131, e por que os números são estes

**Transcrição de 2026-09-10.** Os requisitos desta aba nasceram fora desta spec, em
[`spec-graficos-por-membro.md`](spec-graficos-por-membro.md), escrita em 2026-09-08 **antes**
do protótipo — ordem invertida em relação à decisão de 2026-09-07, *a tela implementada é
exatamente a tela aprovada*. O protótipo veio depois, foi aprovado, e **derrubou quatro
pontos** daquela escrita. Requisito aprovado que mora em arquivo à parte, ainda com o texto
anterior à aprovação, é declaração que ninguém confere: por isso FR-085 a FR-112 passam a
viver **aqui**, com as emendas aplicadas, e FR-113 a FR-131 nascem da aprovação.

**Os números foram preservados, não renumerados.** FR-085 a FR-112 são exatamente os de
2026-09-08, e são os que já são citados por cinco documentos: o próprio protótipo (FR-087,
FR-088, FR-089, FR-091, FR-101, FR-104, FR-111, FR-112), o `team-people-PROMPT.md`, o
`team-people-README.md`, o [`tasks.md`](tasks.md) — *"FR-085 a FR-112 (os quatro gráficos por
membro, US10 a US12) — sem tarefa"* — e
[`decisoes-do-cartao-de-subequipe.md`](decisoes-do-cartao-de-subequipe.md) (FR-088).
Renumerar tornaria cinco documentos errados de uma vez para produzir uma sequência mais
bonita. Número é contrato; contrato preservado continua contrato. A sequência é contínua a
partir de FR-084 porque a escrita de 2026-09-08 já a continuava, e nenhum buraco é aberto.

**Onde o protótipo aprovado venceu o texto de 2026-09-08**, a emenda está no próprio
requisito, no formato desta casa — `~~texto vencido~~` mais a emenda datada:

| Requisito | O que dizia | O que passa a valer |
|---|---|---|
| **FR-087** | pessoas abertas ao mesmo tempo, *proposto: três* | **duas**, e a segunda troca o layout — FR-124 |
| **FR-104** | mesma janela e granulação do Dashboard, sem seletor por pessoa | continua, **e** o controle é **um só**, no cabeçalho da seção — FR-115 |
| **FR-106** | a ordem padrão não é por medida | continua, **e** nenhum cabeçalho **se oferece** para ordenar — FR-117 |
| **SC-022**, **SC-031** | teto de doze gráficos; abrir três pessoas | **oito** gráficos; abrir **duas** |

**A aprovação está atestada, e não registrada.** A afirmação de que a pessoa mantenedora
aprovou o protótipo em **2026-09-08** chegou na tarefa de **2026-09-10**, de quem coordena o
trabalho. Nenhum arquivo traz a marca da aprovação: `team-people-PROMPT.md` e
`team-people-README.md` ainda dizem *"aguardando aprovação"*. Esta transcrição assume a
atestação e a declara como tal — é **lacuna de prova**, não de aprovação. Fecha-se com o
Design marcando *Approved 2026-09-08* e republicando no mesmo endereço, e com a pessoa
mantenedora confirmando. Até lá, nenhum entregável desta aba é aceito contra uma régua cuja
aprovação só existe de memória.

## O que esta feature resolve

`/teams/:id` hoje é **uma página só** com quinze seções empilhadas, e responde três
perguntas ao mesmo tempo: *quem está na equipe*, *como ela está* e *o que ela sabe*.
É o caso que o princípio X da constituição descreve — cabeçalho que precisa de mais
de uma frase para dizer o que a tela responde. E ela **não permite** as três
correções que quem administra mais precisa: registrar que alguém saiu, registrar
que um vínculo nunca existiu, e ver de onde veio cada afirmação de pertencimento.
A lista de membros ainda é a **evidência** da origem (login, nível de acesso,
observado em), e não o **vínculo** que a feature 055 criou e a emenda de 2026-09-06
tornou o único conjunto de membros.

### O que existe hoje, e para onde vai

| Seção de `/teams/:id` hoje | Origem | Destino nesta feature | Natureza |
|---|---|---|---|
| cabeçalho: N membros · M sem papel | 043/055 | cabeçalho das duas abas | mantém |
| *Teams inside this one* — linha por subequipe, sem total, sem gráfico | 057 US2 | **Dashboard**: cartão por subequipe **e** a tabela por medida | reorganiza; ganha o cartão como porta (US7, FR-041) e o gráfico pequeno (US9, FR-084) |
| burn, previsão (só equipe simples) | 057 US5–US6 | **Dashboard** da equipe simples, como está; a composta passa a ter fluxo próprio | mantém; **emenda 057 FR-011** |
| *what each person is on* + habilidades por pessoa (só equipe simples) | 057 US4 | **Dashboard** da simples, como está; a **composta** ganha *Pessoas — diretas e pelas subequipes*, agrupadas por subequipe | mantém; **novo** na composta (decisão 9) |
| — | — | **Dashboard**: *Problemas agora* — cartões contados, cada um com limiar declarado na base; verde = conferido e nada achado | **novo** (decisão 9) |
| *Structure* — faz parte de / contém / *Declare inside* / *remove from here* | 055 US3 | **Estrutura**: seção *Subequipes*, com data, histórico e composição de equipe **existente** | reorganiza; ganha composição com data e de equipe existente |
| tabela *members* por evidência (acesso, observado em, última observação) | 021/043 | **Estrutura**: lista por **vínculo** — papel, origem, desde, subequipes, ações por linha | **substitui** |
| *Source and declaration disagree* | 055 FR-012 | **Estrutura**, junto da lista | mantém |
| *observed members without a declared role* — formulário em lote | 043 US3, #317 | **Estrutura**: ação *declarar papel* na linha da pessoa **e** o lote mantido, com a contagem das puladas | reorganiza (decisão 3, 2026-09-07) |
| *Projects* — badges, associar/desassociar (admin) | 028/058 | leitura no **Dashboard** com período; escrita na **Estrutura** (*Where this team sits*) | reorganiza |
| antipadrões de estrutura (ap01, ap02) | 058 FR-025 | **Dashboard**, *Structure warnings* | mantém |
| *Who worked on these projects* | 058 US2 | **Dashboard** | mantém |
| *Waiting for first review* — com composição e cerimônia à parte | 058 US1, #805 | **Dashboard**, por subequipe quando composta | mantém |
| *Pipeline success rate* | 058 US3 | **Dashboard**, por subequipe quando composta | mantém |
| *Process warnings* | regra `process_antipatterns.yaml` | **Dashboard** | mantém |
| *Skills* — cobertura, evolução, quem demonstra | 029 | **Dashboard** | mantém |
| — | — | **Estrutura**: seção *Papéis* — criar, renomear, ocultar; catálogo SRO | **novo** na tela (comando já existe em `/roles`) |
| — | — | **Estrutura**: *saída com data*, *equívoco com razão* por linha | **novo** na tela (comandos existem; ver Impacto pelo que falta neles) |
| — | — | **Dashboard**: projetos declarados com período e subequipes; **alerta** de trabalho fora de projeto declarado | **novo** |
| — | — | **Dashboard** da composta: burn semana/mês/ano, *Prometido × Entregue*, Monte Carlo | **novo**; emenda 057 FR-011 e FR-029 |

### Por que duas abas, e não duas rotas nem uma página

O princípio X exige que uma tela mostre **uma coisa**. *Como a equipe está* e *quem
está nela* são duas coisas; a página de hoje mostra as duas e mais uma. Duas abas
com a aba na URL (`?tab=dashboard`, `?tab=structure`) são **duas telas** que
compartilham a rota `/teams/:id` — cada uma responde uma pergunta, cada uma tem um
cabeçalho de uma frase, e um link para `?tab=structure` cai onde aponta. É a
decisão 1 do protótipo, e a razão de ela atender ao princípio está aqui, não no
número de rotas.

**Toda escrita mora na Estrutura; o Dashboard só lê.** Declarar papel, registrar
saída, marcar equívoco, compor, criar papel, ligar a projeto — tudo na aba
Estrutura. É o que faz do Dashboard uma tela legível por qualquer conta do tenant
(057 FR-039, 058 FR-023) sem que um botão apareça e desapareça conforme quem olha.

### Emendas que esta spec faz a outras, num só lugar

| Spec e requisito | O que dizia | O que passa a valer | Onde nesta spec |
|---|---|---|---|
| **057 FR-011** | a tela da equipe composta MUST NOT apresentar gráficos | a equipe composta apresenta o **fluxo da equipe inteira** — burn, Prometido × Entregue, Monte Carlo — e um gráfico pequeno por cartão de subequipe; a tabela por subequipe continua sem gráfico | FR-058, FR-059, FR-084 |
| **057 FR-029** | a tela MUST declarar que não há escopo comprometido | continua valendo, e vale **também** para *Prometido × Entregue*: "prometido" é rótulo para *aberto no período*, definido junto do título, e MUST NOT ser lido como compromisso | FR-063 |
| **057 FR-008** (esclarecimento, não emenda) | MUST NOT somar as linhas de subequipe | continua; o fluxo da equipe inteira é medido sobre o **conjunto distinto** de pessoas e itens, e a tela diz que não é soma | FR-060 |
| **055, decisão em aberto 2** da emenda de 2026-09-06 | equívoco em vínculo observado: permitir ou não | **permitido** — decisão de 2026-09-07; a coleta não recria | FR-024 a FR-028 |
| **055, premissa "saída sem data"** | hoje, marcada como presumida | **recusar** — a data é obrigatória (decisão 2, 2026-09-07) | FR-023 |
| **057 e 058, premissa "período padrão, sem seletor nesta feature"** | 8 semanas / 56 dias, seletor é trabalho separado | o trabalho separado chega aqui: padrão fixo **e** período escolhível, com a janela sempre no título (decisões 1 e 9, 2026-09-07) | FR-078, FR-079 |
| **058 FR-024** (confirmação, não emenda) | quebra por pessoa nomeada só para quem alcança a equipe | confirmado: admin, escopo `team`, escopo `organization` **e membro vigente** — os quatro caminhos de `pode_ver_equipe/3` (decisão 7, 2026-09-07) | FR-007, FR-076 |
| **055 FR-011 / premissa "quem administra é quem declara"** | ações só para quem administra | administrador **e** quem desempenha papel organizacional com a concessão *gerir estrutura da equipe* (decisão 8, 2026-09-07) | FR-006, FR-080 a FR-082 |

Nenhum arquivo das specs 055 e 057 é alterado por esta. Cada emenda é aplicada por
quem mantém a spec de origem, a partir do que está escrito aqui.

## User Scenarios & Testing *(mandatory)*

A ordem das histórias é a ordem do foco declarado: membros primeiro, subequipes
depois, e o dashboard e o fluxo por último. Cada história é atômica — tem critérios
que se avaliam sobre um entregável — e nenhuma depende de outra para ser testada.

### User Story 1 - Quem está na equipe, e de onde veio cada afirmação (Priority: P1)

Quem administra abre a aba Estrutura e vê **cada pessoa em uma linha**: o papel
que desempenha ou *papel não declarado*; se o vínculo foi **observado** na
ferramenta ou **declarado** pela organização, e por quem e quando; desde quando
está na equipe, ou *desconhecido*; e em quais subequipes desta equipe está, com a
marca *direta* quando o vínculo é com esta equipe mesma. Quem saiu e quem foi
registrado por equívoco continuam na lista, marcados, e contados à parte.

**Why this priority**: é a base das outras quatro histórias P1 — não se registra
saída nem equívoco de quem não se enxerga. E é o que a tela de hoje não mostra:
ela lista evidência da origem, não o vínculo que conta nas medidas.

**Independent Test**: numa equipe com vínculos observados, declarados, um encerrado
e um invalidado, abrir `?tab=structure` e conferir que cada linha diz origem, papel,
desde quando e subequipes sem depender de cor; e que os contadores do cabeçalho da
lista (vigentes, saíram, equívocos) batem com uma consulta ao banco.

**Acceptance Scenarios**:

1. **Given** uma equipe com vínculos observados e declarados, **When** a aba
   Estrutura abre, **Then** cada pessoa aparece uma vez, com papel (ou *papel não
   declarado*), a origem do vínculo — *observado na origem* ou *declarado por X em
   D* —, o início (data ou *desconhecido*) e as subequipes desta equipe em que tem
   vínculo vigente.
2. **Given** uma pessoa com vínculo direto nesta equipe e vínculo em uma subequipe,
   **When** a lista é exibida, **Then** ela aparece **uma vez**, com a marca *direta*
   e a subequipe, e é contada uma vez no total de membros.
3. **Given** uma pessoa que saiu em D, **When** a lista é exibida, **Then** a linha
   permanece, marcada como *saiu em D*, com o período em que pertenceu e quem
   registrou a saída — e não conta entre os vigentes.
4. **Given** um vínculo marcado como equívoco, **When** a lista é exibida, **Then** a
   linha permanece, marcada como *equívoco*, com razão, autor e data, e o texto diz
   que ela está **excluída de toda medida, em toda data**.
5. **Given** a origem ainda lista uma pessoa que a organização declarou ter saído,
   **When** a aba abre, **Then** as duas afirmações aparecem lado a lado, com a
   origem de cada uma nomeada, e a tela não escolhe (055 FR-012).
6. **Given** uma conta do tenant que **não** é administradora e **não** desempenha
   papel com a concessão de gerir estrutura nesta equipe, **When** abre a aba,
   **Then** lê a lista inteira e **nenhuma** ação de escrita é apresentada.
7. **Given** a distinção observado/declarado/saiu/equívoco, **When** a tela é lida
   sem cor, **Then** a distinção sobrevive — está em texto, não só em cor.

---

### User Story 2 - Declarar o papel de quem a origem mostra, e alterá-lo (Priority: P1)

Quem administra escolhe, na linha da pessoa, o papel que ela desempenha e declara.
O vínculo observado **ganha** o papel — não nasce um segundo. Um papel já declarado
pode ser alterado, e o anterior fica na história com o período em que vigeu. Duas
funções ao mesmo tempo são permitidas.

**Why this priority**: é o que preenche a lacuna que a emenda da 055 deixou
declarada — 17 de 19 membros da equipe de referência estão *sem papel declarado* — e
é o ato que faz CQ14 e CQ16 terem resposta.

**Independent Test**: declarar um papel num vínculo observado e conferir que o `id`
do vínculo é o mesmo antes e depois; alterar o papel e conferir que existem dois
registros, um encerrado e um vigente; declarar um segundo papel simultâneo e conferir
que os dois aparecem.

**Acceptance Scenarios**:

1. **Given** um vínculo observado sem papel, **When** quem administra declara um
   papel com a data de início em branco, **Then** o **mesmo** vínculo passa a ter
   papel, autor e data da declaração; o início continua *desconhecido*; a linha
   passa a dizer *declarado*.
2. **Given** um papel declarado, **When** quem administra o altera para outro,
   **Then** o papel anterior fica registrado com o período em que vigeu, o novo passa
   a valer, e a lista mostra o vigente com acesso ao histórico.
3. **Given** uma pessoa com um papel declarado, **When** quem administra declara um
   **segundo** papel simultâneo, **Then** é aceito (043 FR-006a) e os dois aparecem
   na linha.
4. **Given** o seletor de papel aberto na linha, **When** quem administra escolhe
   *novo papel…*, **Then** o formulário de papel (US5) abre **sem sair da linha**, e
   o papel criado já está selecionável ao voltar.
5. **Given** a data de início em branco, **When** a declaração é gravada, **Then** o
   início é *desconhecido* — **nunca** a data de hoje (043 FR-019, 055 FR-013c).

---

### User Story 3 - A pessoa saiu, e o que ela fez continua contando (Priority: P1)

Quem administra registra, na linha da pessoa, que ela **saiu**, com a data. O
vínculo ganha fim; nada é apagado; nenhum número de período anterior à saída muda.
Se a origem continuar listando a pessoa, a coleta **não** recria o vínculo — a tela
mostra as duas afirmações até a origem ser corrigida.

**Why this priority**: é o pedido literal da pessoa mantenedora ("informar que um
membro não faz mais parte, informando a data de saída"), e é o que a tela de hoje
não permite fazer para vínculo nenhum.

**Independent Test**: anotar os números de uma semana fechada; registrar a saída de
uma pessoa em data anterior a hoje; reabrir e conferir que a semana fechada tem os
mesmos números; rodar a coleta com a origem ainda listando a pessoa e contar os
vínculos do par pessoa–equipe antes e depois: **zero novos**.

**Acceptance Scenarios**:

1. **Given** um vínculo vigente — observado **ou** declarado —, **When** quem
   administra registra a saída em D, **Then** o vínculo passa a ter fim D, **quem
   registrou e quando**, e nenhuma linha é removida (055 FR-004, FR-005).
2. **Given** os números de um período anterior a D já apresentados, **When** a saída
   é registrada e a tela reaberta, **Then** os números são **exatamente** os mesmos.
3. **Given** uma data no futuro, **When** quem administra tenta registrar, **Then** é
   recusado com a razão.
4. **Given** a saída registrada num vínculo observado e a origem **ainda listando** a
   pessoa, **When** a coleta seguinte roda, **Then** **nenhum** vínculo novo nasce
   para o par, e a aba Estrutura mostra as duas afirmações (055 FR-012).
5. **Given** um vínculo já encerrado, **When** alguém tenta registrar a saída de novo,
   **Then** é recusado e a data original **não** é reescrita.
6. **Given** um vínculo com fim, **When** a linha é lida, **Then** ela diz se o fim
   foi **declarado** (por quem) ou **constatado pela coleta**, e neste caso declara
   que a data é limitada pela cadência da coleta (055 FR-015, FR-015a).

---

### User Story 4 - O vínculo que nunca foi (Priority: P1)

Quem administra marca, com uma razão escrita, que um vínculo foi registrado **por
engano** — a pessoa nunca esteve nesta equipe. Vale para vínculo declarado **e**
observado (decisão de 2026-09-07). O vínculo sai de toda medida, em toda data; o
registro fica, com razão, autor e data; e a coleta não o recria.

**Why this priority**: é o "deletar um membro quando cadastrou errado" do pedido,
traduzido para o que a plataforma faz — nada é deletado, o equívoco é registrado. E
é a decisão que fecha a segunda pergunta em aberto da emenda da 055.

**Independent Test**: marcar equívoco num vínculo observado cuja pessoa a origem
ainda lista; conferir que o trabalho dela não conta em nenhuma semana; rodar a
coleta e contar vínculos do par: zero novos; conferir que a seção de discordância
mostra *equívoco*, e não *saída*.

**Acceptance Scenarios**:

1. **Given** um vínculo declarado por engano, **When** quem administra o marca com
   uma razão, **Then** ele é invalidado para **todo** período, e o registro traz
   razão, autor e data (055 FR-006).
2. **Given** um vínculo **observado**, **When** quem administra o marca como
   equívoco com uma razão, **Then** o efeito é o mesmo: sai de toda medida em toda
   data; a coleta seguinte **não** recria o vínculo enquanto a origem continuar
   listando a pessoa; a tela mostra as duas afirmações.
3. **Given** o formulário de equívoco sem razão, **When** quem administra envia,
   **Then** é recusado — a razão é obrigatória.
4. **Given** uma pessoa com equívoco registrado e outra com saída registrada,
   **When** as duas linhas são lidas, **Then** os textos são distintos — *nunca
   esteve* e *saiu em D* pedem conversas diferentes — e nenhuma das duas é
   apresentada como "removida".
5. **Given** uma pessoa que **pertenceu** (tem vínculo encerrado) e depois teve um
   segundo vínculo invalidado, **When** a discordância é calculada, **Then** ela
   **não** é apresentada como *nunca esteve* — o veredito é agregado por pessoa.

---

### User Story 5 - Criar o papel da organização a partir da estrutura (Priority: P1)

Quem administra cria, na aba Estrutura, um papel que a organização usa — nome e
código —, e ele fica disponível **para toda equipe da organização**, imediatamente,
no seletor de *declarar papel* e em `/roles`. Os quatro papéis do Scrum vêm do
catálogo da ontologia e não precisam de cadastro. Papel em uso não é removido;
renomear preserva a história.

**Why this priority**: sem o papel certo no seletor, a US2 obriga quem administra a
sair da tela, ir a `/roles`, voltar e reencontrar a linha. Foi o pedido "permita
criar os roles" na estruturação, e o comando já existe — muda o lugar de onde é
chamado.

**Independent Test**: criar um papel na aba Estrutura, declará-lo em uma pessoa da
mesma equipe na mesma sessão, e conferir que aparece em `/roles` da organização;
tentar criar outro com o mesmo código e ser recusado; tentar ocultar um papel em
uso e receber a contagem do que impede.

**Acceptance Scenarios**:

1. **Given** a aba Estrutura, **When** quem administra cria um papel com nome e
   código, **Then** o papel existe **para a organização da equipe**, com autor e
   data, e aparece de imediato no seletor de *declarar papel* desta e de qualquer
   equipe da organização, e em `/roles`.
2. **Given** um código já existente na mesma organização, **When** quem administra
   tenta criar, **Then** é recusado com a razão; o mesmo código **em outra
   organização** não é conflito.
3. **Given** um papel que alguém desempenha, **When** quem administra tenta
   removê-lo, **Then** é recusado dizendo **quantos** vínculos impedem — encerrar ou
   alterar os vínculos vem antes.
4. **Given** os papéis do catálogo SRO (Developer, Scrum Master, Product Owner,
   Client), **When** a seção é exibida, **Then** eles aparecem marcados como
   *catálogo*, sem ação de remover, e com a contagem de quem os desempenha nesta
   equipe e na organização.
5. **Given** um papel renomeado, **When** os vínculos que o usam são lidos, **Then**
   continuam apontando para o mesmo papel; nada é recriado.
6. **Given** o campo de nome preenchido, **When** o código é sugerido a partir dele,
   **Then** é **editável** — a sugestão não é a identidade.

---

### User Story 6 - As subequipes: quem compõe esta equipe, desde quando (Priority: P2)

Quem administra vê, na aba Estrutura, uma linha por subequipe — membros vigentes,
quantos observados e quantos declarados, desde quando faz parte e quem declarou —,
as composições encerradas em histórico, e declara que uma equipe **existente** da
mesma organização passa a fazer parte desta, com data ou com início desconhecido.
Ciclos são recusados com o caminho nomeado. Uma equipe composta pode ter membros
diretos.

**O cartão da subequipe no Dashboard deixou de ser cobrado aqui.** Até 2026-09-07
esta história pedia o cartão e o clique que abre o Dashboard da subequipe. O cartão
e a porta passaram a ser requisito e aceitação da **US7** (FR-041), e o gráfico
pequeno dentro dele, da **US9** (FR-084) — nenhum dos dois existe quando esta
história é entregue. Ver *Decisões de 2026-09-07*, decisão 11.

**Why this priority**: P2 porque as cinco histórias anteriores entregam valor numa
equipe simples. A composição é o que permite perguntar da organização inteira, e é
o segundo item do foco declarado.

**Independent Test**: compor duas equipes existentes numa terceira, uma com data e
uma sem; tentar fechar um ciclo de comprimento 3 e ser recusado com o caminho;
encerrar uma composição e conferir que a subequipe continua existindo e a linha foi
para o histórico; conferir que a subequipe passa a mostrar *faz parte de* esta.

**Acceptance Scenarios**:

1. **Given** uma equipe com composições vigentes e uma encerrada, **When** a aba
   Estrutura abre, **Then** cada composição vigente é uma linha com membros
   vigentes, *X observados / Y declarados*, *faz parte desde* (data ou
   *desconhecido*) e quem declarou; a encerrada aparece como **histórico**, com o
   período e quem encerrou.
2. **Given** uma equipe existente da mesma organização, **When** quem administra
   declara que ela faz parte desta, com data em branco, **Then** a composição nasce
   com início *desconhecido*, e a subequipe passa a mostrar *faz parte de* esta.
3. **Given** A dentro de B e B dentro de C, **When** alguém tenta pôr C dentro de A,
   **Then** é recusado e a recusa **nomeia o caminho** (055 FR-009).
4. **Given** uma composição vigente, **When** quem administra a encerra, **Then** a
   subequipe continua existindo com o histórico intacto, a linha vai para o
   histórico, e os números de períodos anteriores não mudam.
5. **Given** uma equipe composta com pessoas vinculadas **diretamente** a ela,
   **When** o Dashboard e a Estrutura abrem, **Then** o Dashboard tem a linha
   *membros diretos* e a Estrutura marca essas pessoas como *direta*.
6. **Given** uma equipe com **uma** composição vigente, **When** a tela abre,
   **Then** ela segue como equipe simples no Dashboard (057) e a Estrutura mostra a
   composição.

---

### User Story 7 - O Dashboard reorganizado: medidas com composição, projetos declarados, e o que está fora deles (Priority: P2)

Quem gerencia abre `/teams/:id` e cai no Dashboard. Vê, se a equipe é composta, um
cartão por subequipe com as mesmas medidas da tabela, **nunca um total**, e a
razão de não somar; clicar no cartão abre o Dashboard daquela subequipe. O gráfico
pequeno dentro do cartão chega com a US9 (FR-084): o cartão é porta antes de haver
curva. Cada medida diz sobre quem foi calculada. Os projetos em que a equipe
trabalha são **os declarados**, com período e com as subequipes que têm vínculo
próprio ao mesmo projeto. Trabalho em repositório ou quadro que não pertence a
nenhum projeto declarado da equipe aparece como **alerta** — onde, quem, quanto —,
e nunca como projeto.

**Why this priority**: é a reorganização que as cinco P1 já pedem para existir, e o
que dá lugar à visão do gestor (US8) e ao fluxo (US9). O alerta é o que torna
visível a diferença entre "a plataforma não sabe" e "a organização não declarou".

**Independent Test**: abrir `/teams/:id` sem `?tab` e cair no Dashboard; abrir
`?tab=structure` e cair na Estrutura; recarregar e continuar na mesma aba; numa
equipe composta, varrer a tela e não encontrar célula de total; conferir que 100%
das medidas trazem *N — X observados sem papel, Y declarados*; criar trabalho num
repositório não ligado a projeto da equipe e ver o alerta nascer — e sumir ao
declarar o vínculo; clicar no cartão de uma subequipe e chegar ao `/teams/:id` dela.

**Acceptance Scenarios**:

1. **Given** `/teams/:id` sem `?tab`, **When** a rota abre, **Then** o Dashboard é
   exibido; **Given** `?tab=structure`, **Then** a Estrutura; e recarregar mantém a
   aba.
2. **Given** uma equipe composta, **When** o Dashboard abre, **Then** há um cartão
   por subequipe e um para *membros diretos*, com as mesmas medidas, nenhuma célula
   de total, e o texto que explica por que não soma (057 FR-008, FR-009).
3. **Given** qualquer medida do Dashboard, **When** ela é exibida, **Then** traz *N
   membros — X observados sem papel declarado, Y declarados*, com X + Y = N (058
   FR-026), e quando X > 0 diz que para esses o papel é desconhecido (058 FR-026c).
4. **Given** vínculos equipe → projeto vigentes e encerrados, **When** a seção de
   projetos é exibida, **Then** há uma linha por vínculo declarado, com o período,
   as subequipes que têm vínculo **próprio** ao mesmo projeto, e **nenhum** projeto
   que não tenha vínculo declarado.
5. **Given** issues e solicitações de mudança **abertas** de membros da equipe em
   repositório que não está em nenhum quadro de projeto declarado da equipe, ou em
   quadro sem projeto declarado, **When** o Dashboard abre, **Then** aparece um
   **alerta** com onde (repositório ou quadro), quem e quantas abertas — e o alerta
   **não** é uma linha de projeto.
6. **Given** o alerta, **When** a organização declara o projeto e liga a equipe a
   ele, **Then** o alerta deixa de existir e o trabalho passa a contar na linha do
   projeto.
7. **Given** uma subequipe sem trabalho no período, **When** o cartão é exibido,
   **Then** a ausência é dita em texto, nunca zero (057 FR-012).
8. **Given** uma conta sem escopo sobre a equipe **e sem vínculo vigente nela**,
   **When** o alerta é exibido, **Then** ela lê onde e quanto, e **não** lê quem — a
   quebra por pessoa nomeada segue a fronteira de 058 FR-024 (FR-007).
9. **Given** o Dashboard de uma equipe composta, **When** quem lê clica no cartão de
   uma subequipe, **Then** abre o Dashboard daquela subequipe, e a porta **não**
   depende de haver gráfico no cartão (FR-041; 057 FR-010).

---

### User Story 8 - A visão geral do gestor: o que precisa de olhar hoje, e o que cada pessoa está fazendo (Priority: P2)

Quem gerencia abre o Dashboard e, antes das medidas, vê **Problemas agora**: um
cartão por fato que pede atenção — issues abertas além de um limiar, solicitações de
código esperando revisão humana além de outro, pipeline falhando **agora** na branch
padrão, tarefas paradas além do limiar de parada, pessoas sem tarefa aberta, membros
sem papel declarado, trabalho fora de projeto declarado, anomalias de estrutura —,
cada cartão com o **limiar escrito**, vindo da base de conhecimento, e cada número
**contado**, nunca inferido. Um cartão em verde significa *conferido e nada
encontrado*, o que é diferente de *não conferido*. Abaixo, **Pessoas — diretas e
pelas subequipes**: todos os membros da equipe composta, agrupados por subequipe,
com papel, **todas** as tarefas abertas agora com idade e marca de parada, e o
perfil demonstrado — ou *sem perfil ainda*, quando o material está abaixo do piso.

**Why this priority**: decisão 9 da pessoa mantenedora em 2026-09-07 — o Dashboard
é a visão geral de quem gerencia, e a visão geral começa pelo que precisa de decisão
hoje, não pela série histórica. P2 e não P1 porque cada cartão e cada linha reusa um
fato que outra história desta spec ou de spec anterior já produz; o que esta
história acrescenta é o lugar e o limiar.

**Independent Test**: numa equipe composta com dados conhecidos, conferir que cada
cartão traz o limiar escrito e que o número bate com a lista que ele abre; zerar um
fato (por exemplo, ligar o repositório ao projeto) e ver o cartão ficar *conferido,
nada encontrado*; remover a coleta de um insumo e ver o cartão dizer *não
conferido*, e não zero; conferir que uma pessoa em duas subequipes aparece nos dois
grupos e conta uma vez no total, e que nenhuma pessoa tem uma tarefa "atual" eleita.

**Acceptance Scenarios**:

1. **Given** o Dashboard de uma equipe, **When** *Problemas agora* é exibido,
   **Then** cada cartão traz o número, o **limiar escrito** e a origem do limiar na
   base de conhecimento, e o texto diz sobre que janela e que conjunto de membros foi
   contado.
2. **Given** um fato conferido e não encontrado, **When** o cartão é exibido,
   **Then** ele diz *conferido, nada encontrado*; **Given** um insumo que a coleta
   não traz, **Then** o cartão diz *não conferido* e o que falta — nunca zero.
3. **Given** um cartão com número maior que zero, **When** quem lê o aciona, **Then**
   chega à lista do que foi contado — na seção do Dashboard ou da aba Estrutura que
   detalha aquele fato.
4. **Given** uma equipe composta, **When** um cartão quebra por subequipe, **Then** o
   número do cartão é a contagem **distinta** sobre a equipe inteira, a quebra é por
   subequipe, e a tela diz que a quebra pode se sobrepor — não é partição.
5. **Given** uma equipe **sem projeto declarado**, **When** o cartão do pipeline é
   exibido, **Then** ele diz *não conferível* nomeando o elo que falta (058 FR-013a),
   e não zero nem verde.
6. **Given** a seção *Pessoas*, **When** é exibida, **Then** todos os membros
   vigentes da equipe inteira aparecem, agrupados por subequipe e *membros diretos*;
   pessoa em duas subequipes aparece nos dois grupos com *também em X* e conta uma
   vez no total.
7. **Given** uma pessoa com três tarefas abertas, **When** a linha é exibida,
   **Then** as três aparecem, cada uma com identificação, link e há quanto tempo está
   aberta desde a abertura do item, e nenhuma é eleita "atual" (057 FR-017 a
   FR-019a); a que ultrapassa o limiar de parada declarado recebe a marca (057
   FR-020).
8. **Given** uma pessoa sem tarefa aberta, **When** a linha é exibida, **Then** a
   ausência é dita em texto e a pessoa não é omitida (057 FR-021).
9. **Given** uma pessoa abaixo do piso de perfil, **When** a coluna de perfil é
   exibida, **Then** diz *sem perfil ainda*, com o piso declarado e quanto a pessoa
   tem, e nenhuma habilidade é listada (057 FR-023); toda habilidade exibida traz
   marca de derivada e a tela diz que ausência é *não observada aqui* (057 FR-022,
   FR-024).
10. **Given** uma conta sem escopo sobre a equipe **e sem vínculo vigente nela**,
    **When** a seção *Pessoas* e os cartões que nomeiam pessoas são exibidos,
    **Then** ela lê os agregados e não lê nome, tarefa nem perfil de pessoa nomeada,
    e a recusa é nomeada (058 FR-024, FR-024a); **Given** uma conta cuja pessoa é
    **membro vigente** da equipe, **Then** ela lê a quebra por pessoa.

---

### User Story 9 - O fluxo da equipe inteira: burn, Prometido × Entregue, Monte Carlo (Priority: P3)

No Dashboard da equipe composta, quem gerencia vê o burn-up/burn-down da equipe
**inteira** por semana, mês ou ano; *Prometido × Entregue* — abertos e levados a
fechamento em cada período —; e a previsão de Monte Carlo, semanal, com duas
hipóteses e a confiança de cada uma. Trocar a granulação reagrupa os mesmos itens;
não muda a medida. E o cartão de cada subequipe — que a US7 já entregou como porta —
ganha aqui o **gráfico pequeno**, que também abre o Dashboard dela.

**Why this priority**: P3 porque é o maior salto de leitura e o mais fácil de ler
errado — e porque depende de as cinco P1 estarem certas: o conjunto de membros é o
que decide o que entra nas curvas. Pedido da pessoa mantenedora em 2026-09-07,
emendando 057 FR-011.

**Independent Test**: com uma série conhecida, conferir que a distância entre as
curvas em qualquer ponto é o número de itens em aberto naquele ponto, nas três
granulações; que o total de abertos e de fechados na janela é o mesmo em semana,
mês e ano; que a previsão é idêntica em duas consultas; que abaixo do piso nenhuma
previsão aparece; e que o cartão de cada subequipe traz o gráfico pequeno e que
clicar nele chega ao `/teams/:id` da subequipe.

**Acceptance Scenarios**:

1. **Given** uma equipe composta, **When** o Dashboard abre, **Then** o burn-up e o
   burn-down da equipe inteira são exibidos, partindo da contagem de itens já
   abertos no início da janela (057 FR-026a), com o que resta como a **região**
   entre as curvas (057 FR-027), e o texto diz que a série **não é a soma** dos
   cartões.
2. **Given** a granulação em semana, **When** quem lê troca para mês e para ano,
   **Then** os mesmos itens são reagrupados; a soma de abertos e a de fechados na
   janela são **iguais** nas três granulações.
3. **Given** *Prometido × Entregue*, **When** é exibido, **Then** cada período traz
   abertos no período e fechados no período; junto do título está a definição —
   *prometido = aberto no período; entregue = fechado no período* — e a declaração
   de que **não há escopo comprometido** (057 FR-029 emendado).
4. **Given** a previsão de Monte Carlo, **When** é exibida, **Then** é **semanal**
   independentemente da granulação escolhida para os outros gráficos, com as duas
   hipóteses, a confiança de cada uma, e a proporção de rodadas que não concluíram
   (057 FR-032 a FR-035).
5. **Given** histórico abaixo do piso — menos de 6 semanas ou menos de 10 itens
   fechados —, **When** a tela abre, **Then** nenhuma previsão é exibida e a tela diz
   o que falta (057 FR-034).
6. **Given** a mesma consulta duas vezes, **When** as curvas e a faixa são
   comparadas, **Then** são idênticas (057 FR-036).
7. **Given** o Dashboard de uma equipe composta, **When** os cartões de subequipe são
   exibidos, **Then** cada um traz o **gráfico pequeno** (FR-058, FR-084), e clicar
   no gráfico abre o Dashboard daquela subequipe — a mesma porta do cartão (FR-041).

### User Story 10 - O fluxo de cada membro, comparável na mesma janela (Priority: P3)

Quem alcança a equipe abre a aba *Flow per person* e vê uma linha por membro, com as medidas
na **mesma janela** dos gráficos do Dashboard: o trabalho aberto agora e a direção da série, os
abertos e os fechados na janela, os períodos com fechamento, e o estado da previsão. Sem
gráfico em nenhuma linha, sem ordenação por medida, e com a janela escrita no cabeçalho.

**Why this priority**: P3, a mesma da US9, e **depois** dela. As definições (FR-062), a
ressalva (FR-063), a granulação e a janela no endereço (FR-078, FR-079) nascem na US9;
construir isto antes obrigaria a inventá-las duas vezes. E o conjunto de membros que alimenta
as linhas é o que as cinco P1 decidem.

**Independent Test**: com uma equipe de série conhecida, conferir que a soma da coluna *closed
in the window* das linhas é **maior ou igual** à vazão da equipe no mesmo período (maior quando
há item com dois responsáveis), que trocar a granulação ou a janela no endereço muda **todas**
as linhas ao mesmo tempo por um **único** controle, e que nenhuma coluna de medida ordena a
tabela nem se oferece para ordenar.

**Acceptance Scenarios**:

1. **Given** uma equipe com membros vigentes, **When** a aba abre, **Then** há uma linha por
   membro do **mesmo conjunto** que alimenta o Dashboard (FR-057), o cabeçalho da seção diz
   `N members · <janela> · by <granulação>`, e nenhuma linha traz gráfico.
2. **Given** a granulação em semana, **When** quem lê troca para mês, **Then** a troca acontece
   por **um único** controle, no cabeçalho da seção, reescreve o endereço e reagrupa **todas**
   as linhas ao mesmo tempo; nenhum gráfico traz controle próprio, e cada gráfico continua
   nomeando a janela no seu título (FR-115).
3. **Given** um item com **duas** pessoas responsáveis da mesma equipe, **When** as linhas são
   lidas, **Then** o item conta **uma vez para cada** pessoa, e o bloco acima da tabela declara
   que somar as linhas não dá a vazão da equipe.
4. **Given** a tabela recém-aberta, **When** a ordem é observada, **Then** ela é por papel
   declarado e depois por nome — **nunca** por uma das medidas —, a ordem está escrita abaixo
   da tabela, e nenhum cabeçalho de coluna se oferece para ordenar.
5. **Given** uma pessoa cujo vínculo começou dentro da janela, **When** a linha dela é lida,
   **Then** a data de início aparece (ou *start date unknown*, 057 FR-006), o denominador de
   *weeks with a close* é o reduzido (`2 of 3`), e o texto diz que menos períodos com dado é
   história mais curta dentro da mesma janela, e não menos trabalho.
6. **Given** qualquer equipe e qualquer tamanho, **When** a aba abre, **Then** os **dois**
   blocos — *a table of work items, not a table of people* e *"working in progress" here is not
   `flow.wip.count`* — estão acima da tabela, não colapsados, e nenhuma média, mediana ou taxa
   por pessoa aparece em lugar algum da aba (FR-116, FR-118).

---

### User Story 11 - Os quatro gráficos de uma pessoa, abertos sob demanda (Priority: P3)

Quem lê escolhe uma linha e os quatro gráficos daquela pessoa abrem ali mesmo, sob a própria
linha: a série do trabalho aberto, *Promised × Delivered* por período, a vazão por período, e a
previsão de Monte Carlo — ou a recusa dela. Os quatro sobre a mesma janela dos gráficos da
equipe, numerados na ordem de leitura. Uma **segunda** pessoa aberta tira as duas das linhas e
põe os gráficos lado a lado, uma linha por medida. O bloco aberto leva a `/people/:id`.

**Why this priority**: P3, e é **o pedido literal** da pessoa mantenedora. Vai depois da US12 e
não antes: sem a ausência dita por pessoa, a primeira versão destes gráficos mostra branco para
a maioria das pessoas de uma equipe real, e branco é a afirmação que a plataforma recusa.

**Independent Test**: com uma pessoa de série conhecida, conferir que a série de trabalho aberto
em qualquer instante é o número de itens dela abertos ali, que a soma de abertos e a de fechados
na janela são iguais nas três granulações, que a previsão é idêntica em duas consultas, e que
abrir **duas** pessoas não passa do teto de consultas da página.

**Acceptance Scenarios**:

1. **Given** a tabela, **When** quem lê escolhe uma pessoa, **Then** os quatro gráficos dela
   abrem **sob a própria linha**, em duas por duas, sem trocar de tela, numerados **1 → 4** como
   ordem de leitura, com os três primeiros marcados como observados e o quarto como derivado, e
   o bloco traz o caminho para `/people/:id`.
2. **Given** uma pessoa já aberta, **When** quem lê abre uma **segunda**, **Then** as duas saem
   das linhas, os gráficos viram **quatro linhas de duas colunas** abaixo da tabela, as duas
   linhas da tabela ficam marcadas, cada gráfico mantém a **sua** escala rotulada, e a linha diz
   que os eixos diferem — *as formas comparam, as alturas não* (FR-124, FR-129).
3. **Given** duas pessoas abertas, **When** quem lê escolhe uma terceira, **Then** a plataforma
   MUST NOT apresentar três ao mesmo tempo e MUST dizer o teto na tela; **qual dos dois
   comportamentos** — recusar a terceira ou fechar a mais antiga — é **decisão pendente** (Q25),
   e este cenário não é avaliável antes dela.
4. **Given** o bloco de uma pessoa aberto, **When** *Promised × Delivered* dela é lido, **Then**
   a definição operacional, a declaração de que **não há escopo comprometido** e a substituição
   do WIP estão **dentro** do bloco, junto do título do gráfico (FR-097, FR-090).
5. **Given** a previsão de uma pessoa acima do piso, **When** é exibida, **Then** é **semanal**
   independentemente da granulação escolhida para os outros gráficos, com as duas hipóteses e a
   proporção de rodadas que não concluíram (FR-064, FR-098).
6. **Given** uma pessoa sem nada aberto nem fechado na janela, **When** os gráficos dela abrem,
   **Then** cada gráfico vazio é **desenhado** — eixos, escala e a frase na própria área de
   plotagem —, e nenhum retângulo em branco aparece (FR-128).
7. **Given** a mesma consulta duas vezes, **When** os quatro gráficos são comparados, **Then**
   são idênticos (057 FR-036).

---

### User Story 12 - A ausência dita, pessoa por pessoa (Priority: P3)

Numa equipe real, a maioria das pessoas **não** alcança o piso da previsão, e algumas não
fecharam nada na janela. A tela diz isso por pessoa, com o que falta, e nunca com branco, zero
ou coluna escondida. Acima da tabela, quantas pessoas têm previsão e de quantas — para que a
maioria de recusas se leia como estado do registro, e não como defeito da tela.

**Why this priority**: P3, e **antes da US11** na ordem de entrega. `Forecast.monte_carlo/2`
exige 6 períodos de história e 10 itens fechados; para a equipe isso é comum, para uma pessoa
muitas vezes não. Uma tela que mostra 27 espaços vazios em 31 é pior do que nenhuma tela: cada
vazio é uma afirmação sobre uma pessoa que a plataforma não fez.

**Independent Test**: com uma equipe em que uma pessoa está acima do piso e as outras abaixo,
conferir que cada pessoa abaixo traz os **quatro** números, que nenhuma célula fica vazia, e que
a contagem acima da tabela diz *1 de N* — inclusive quando N é 0 e quando N é M.

**Acceptance Scenarios**:

1. **Given** uma pessoa com 3 semanas de história e 6 fechadas, **When** a previsão dela é lida,
   **Then** nenhuma previsão aparece e a célula traz os **quatro** números com as palavras que
   carregam a diferença — `history 3 of 6 short · closed 6 of 10 short` —, e os **dois** modos de
   bloqueio ficam distinguíveis sem depender de cor (FR-099, FR-123).
2. **Given** a mesma pessoa, **When** o texto da recusa é lido, **Then** ele diz que é **lacuna
   do registro observado**, e nunca afirmação sobre a pessoa (FR-102), e a história da **equipe**
   MUST NOT ser emprestada para preencher a lacuna (FR-101).
3. **Given** uma pessoa sem nenhum item fechado na janela, **When** a linha dela é lida, **Then**
   a célula diz *none closed*, e **não** `0`; e *weeks with a close* diz `0 of 8`.
4. **Given** uma pessoa sem **nenhum** item observado em nenhuma amostra da janela, **When** a
   linha dela é lida, **Then** ela diz de que a ausência é — *no open item assigned · and none
   observed at any sample of this window* —, a marca é **tracejada**, a pessoa **não** sai da
   tabela (FR-021), e a previsão diz *nothing to forecast*, porque o piso **não** é a razão ali.
5. **Given** uma pessoa que tem itens mas nenhum aberto agora, **When** a linha dela é lida,
   **Then** ela diz *nothing open at any sample — her items in this window were all closed* — um
   zero **medido** de uma série que existe —, e **não** empresta a frase do caso anterior
   (FR-131).
6. **Given** uma equipe em que 4 de 31 pessoas alcançam o piso, **When** a aba abre, **Then**
   acima da tabela está *delivery forecast produced for 4 of 31 people in this window*, com a
   frase de que o piso é do método; a linha aparece **também** quando N = 0 e quando N = M
   (FR-100, SC-028).
7. **Given** um item que a regra de roteamento não classificou, **When** a linha da pessoa é
   lida, **Then** ele aparece com a marca `—` **junto da contagem de que faz parte**, nunca em
   rodapé, e o que ele **é** fica declarado como desconhecido (FR-121).
8. **Given** uma pessoa cujos repositórios podem não ter sido coletados, **When** os números dela
   são lidos, **Then** a cobertura aparece **junto** deles, no formato *N repos observed ·
   denominator unknown*, e a não-comparabilidade fica ao lado da tabela (FR-111, FR-112).

---

### Edge Cases

- **Pessoa direta e em subequipe.** Uma linha, dois marcadores; conta **uma vez** no
  conjunto da equipe inteira.
- **Pessoa em duas subequipes e o fluxo da equipe inteira.** O item dela conta uma
  vez para a equipe inteira (`DISTINCT`), e uma vez em cada cartão — é por isso que
  os cartões não somam e a curva não é a soma deles.
- **Equívoco em vínculo observado enquanto a origem continua listando.** As duas
  afirmações aparecem; a coleta não cria vínculo; quando a origem deixar de listar,
  a discordância some e o registro do equívoco fica.
- **Saída declarada em vínculo observado, e a origem depois para e volta a listar.**
  "Continuar listando" e "voltar a listar" são fatos diferentes: enquanto a
  observação for **contínua**, nada é recriado; uma observação **nova** depois de uma
  ausência constatada é retorno, e nasce vínculo observado novo (055 FR-015, US2
  cenário 4).
- **Saída sem data.** Recusada — a data é obrigatória e o campo não vem preenchido
  (decisão 2, 2026-09-07; FR-023).
- **Alterar papel de quem tem dois.** A alteração é de **um** dos dois; o outro
  continua.
- **Composição com início desconhecido e a medida da equipe inteira.** O trabalho da
  subequipe conta para a equipe inteira a partir da primeira observação da
  composição, e a tela diz que o início é desconhecido — a mesma regra do vínculo
  (057 FR-006).
- **Equipe com uma composição só.** Não é composta para o Dashboard (057), e a
  Estrutura mostra a composição.
- **Papel criado com a linha de declaração aberta.** Ao voltar, o novo papel está no
  seletor; a linha não perdeu o que já estava escolhido.
- **Código sugerido colide.** É editável; se enviado igual, recusa com a razão.
- **Ano sobre janela de oito semanas** seria uma barra só. A janela padrão de cada
  granulação é própria — 8 semanas, 12 meses, todos os anos coletados — e o título
  diz qual está em uso (decisão 1, 2026-09-07; FR-078).
- **Item reaberto.** Aparece como abertura no período em que reabriu e mantém o
  fechamento anterior — nos dois gráficos (057 edge case; limitação declarada em
  `flow.open_work.cumulative`).
- **Trabalho fora de projeto de uma pessoa que também está em subequipe ligada ao
  projeto.** O critério é do **item**, não da pessoa: o repositório ou quadro do item
  não está ligado a projeto declarado da equipe. A pessoa aparece no alerta por esse
  item, e na linha do projeto pelos outros.
- **Equipe sem projeto declarado e com trabalho.** Todo o trabalho é alerta, e a
  taxa do pipeline não existe (058 FR-013a) — os dois dizem a mesma lacuna, com
  palavras diferentes.

**Da aba *Flow per person*** (transcritos de `spec-graficos-por-membro.md`, com os dois últimos
acrescentados pelo protótipo aprovado):

- **Item com dois responsáveis, ambos da equipe.** Conta **uma vez para cada** na tabela por
  pessoa; conta **uma vez** nos gráficos da equipe (`DISTINCT`, FR-060). É por isso que somar as
  linhas não dá o número da equipe, e é por isso que a tela diz.
- **Item com dois responsáveis, um de fora da equipe.** A linha da pessoa de dentro conta o
  item; a de fora não tem linha. A tela **não** declara que existe alguém de fora — isso é
  vínculo, não item.
- **Pessoa que entrou no meio da janela.** Mesma janela, história mais curta. A data de início
  aparece; sem ela, *start date unknown* (057 FR-006). O denominador de *weeks with a close* é o
  reduzido.
- **Pessoa que saiu com data declarada.** O que ela fez continua contando na janela (US3), a
  linha diz a saída e o autor dela, os itens continuam designados a ela na origem, e ela **não**
  desaparece da tabela retroativamente.
- **Pessoa em duas subequipes da mesma equipe composta.** Uma linha só na aba da equipe composta
  — a aba é por pessoa, não por vínculo —, com os chips de subequipe na célula da pessoa e sem
  total algum.
- **Item reaberto.** Aparece como abertura no período em que reabriu e mantém o fechamento
  anterior, nos quatro gráficos — a limitação já declarada em `flow.open_work.cumulative` e em
  `flow.wip.count`.
- **Granulação ano com um só período.** Um ponto não é uma série. A tela apresenta o ponto e diz
  que uma série de um ponto não descreve fluxo — a limitação declarada em `flow.wip.count`.
- **Equipe com exatamente um membro vigente.** A tabela tem uma linha, e ela **é** a equipe com
  outro rótulo. A fronteira de 058 FR-025 vale: quem não alcança a equipe não vê a linha.
- **Equipe sem membro vigente.** A tabela não existe, e a tela diz *no one has a declared
  membership in this team right now* — o mesmo texto da seção do Dashboard.
- **Pessoa cujo trabalho está todo em repositório não coletado.** Números baixos por uma razão
  que não é o trabalho dela. É o caso que FR-111 e FR-112 existem para cobrir, e o mais perigoso
  da aba inteira.
- **Pessoa com itens, nenhum aberto agora.** É zero **medido** de uma série que existe, e MUST
  NOT usar a frase de quem não tem nada observado — duas ausências diferentes, duas frases
  diferentes (FR-131).
- **A terceira pessoa aberta.** O teto é duas (FR-124). O protótipo aprovado **não desenhou** o
  que acontece ao escolher a terceira: recusar, ou fechar a mais antiga. **Decisão pendente
  (Q25)**, e nenhum entregável deste ponto é avaliável antes dela.

## Requirements *(mandatory)*

### As duas abas

- **FR-001**: `/teams/:id` MUST ter duas abas — *Dashboard* e *Estrutura* —, e a aba
  MUST estar na URL (`?tab=dashboard` | `?tab=structure`). Sem `?tab`, o Dashboard.
  Recarregar ou compartilhar a URL MUST cair na aba que ela nomeia.
- **FR-002**: O Dashboard MUST responder *como esta equipe está*; a Estrutura MUST
  responder *quem está nela, em que subequipe, em que papel*. Nenhuma seção MUST
  aparecer nas duas.
- **FR-003**: **Toda ação de escrita** — declarar papel, alterar papel, registrar
  saída, marcar equívoco, criar/renomear/ocultar papel, compor/encerrar
  composição, ligar/desligar projeto — MUST viver na Estrutura. O Dashboard MUST
  NOT ter ação de escrita.
- **FR-004**: O cabeçalho comum às duas abas MUST trazer: nome, origem da equipe
  (observada na origem / declarada por X em D — 055 FR-002), *N membros vigentes*,
  *M sem papel declarado* (055 FR-018), e *composta de K subequipes* quando houver
  duas ou mais.

### Quem vê, quem escreve

- **FR-005**: Ver qualquer das duas abas MUST NOT exigir permissão de administrar
  (057 FR-039, 058 FR-023). Toda consulta MUST ser restrita ao tenant (055 FR-010).
- **FR-006** *(decisão da pessoa mantenedora em 2026-09-07)*: Toda ação de escrita MUST estar disponível para **duas** contas, e
  só para elas: a **administradora** do tenant, e a conta cuja pessoa desempenha,
  com vínculo vigente, um **papel organizacional que carrega a concessão *gerir
  estrutura da equipe*** com alcance sobre esta equipe (FR-080 a FR-082). Quem não
  é nenhuma das duas MUST NOT ver a ação, **e** a tentativa por evento MUST ser
  recusada com o motivo — esconder o botão não é autorização (055 FR-011). *Isto
  inclui declarar papel, que hoje não confere permissão nenhuma antes de gravar; e
  substitui, para a estrutura, o caminho por escopo `organization` de conta que
  `pode_declarar_estrutura/4` aceita hoje — ver Impacto.*
- **FR-007** *(decisão da pessoa mantenedora em 2026-09-07)*: A lista de membros e a lista de subequipes são **estrutura
  declarada** (058 FR-007a) e MUST ser legíveis por qualquer conta do tenant. Números
  sobre o trabalho de pessoa **nomeada** — o *quem* do alerta de trabalho fora de
  projeto (FR-053), a quebra por pessoa da espera por revisão, as tarefas e o perfil
  em *Pessoas* (FR-076) — MUST ser apresentados a quem **alcança a equipe** pelo
  veredito vigente de 058 FR-024, que são quatro caminhos e MUST permanecer os
  quatro: administradora do tenant; conta com escopo `team` nesta equipe; conta com
  escopo `organization` na organização dela; e conta cuja pessoa é **membro
  vigente** desta equipe — colega vê colega. Os demais MUST ler os agregados, e a
  recusa MUST ser nomeada (058 FR-024a). O escopo `project` MUST NOT abrir — nomeia
  projeto, não equipe.

### Os membros

- **FR-008**: A lista de membros MUST ser construída a partir do **vínculo**
  (`eo.team_membership`), e MUST NOT a partir da evidência da origem. Ela substitui
  a tabela por evidência de hoje. O nível de acesso na plataforma (`MAINTAINER`,
  `MEMBER`) MUST NOT aparecer nesta lista — ele não é papel, e ao lado de um seletor
  de papel vira dica (043 FR-011, FR-012).
- **FR-009**: Cada pessoa MUST aparecer **uma vez**, agregando todos os seus
  vínculos com esta equipe e com as subequipes vigentes desta equipe.
- **FR-010**: Cada linha MUST apresentar, em texto e não só em cor: o(s) papel(is)
  vigente(s) ou *papel não declarado* (055 FR-013b); a **origem** de cada vínculo —
  *observado na origem*, ou *declarado por X em D*; o **início** — data, ou
  *desconhecido* (055 FR-013c); as **subequipes** desta equipe em que tem vínculo
  vigente; e *direta* quando o vínculo é com esta equipe.
- **FR-011**: Vínculo **encerrado** MUST permanecer na lista, marcado *saiu em D*,
  com o período e com quem registrou — ou *constatado pela coleta* (FR-022) —, e
  MUST NOT contar entre os vigentes. Vínculo **invalidado** MUST permanecer, marcado
  *equívoco*, com razão, autor e data, e o texto MUST dizer que está excluído de toda
  medida em toda data.
- **FR-012**: O cabeçalho da lista MUST contar separadamente **vigentes**, **saíram**
  e **equívocos**; os três números MUST bater com a consulta que os produz.
- **FR-013**: A discordância entre coleta e declaração MUST ser apresentada na
  Estrutura, junto da lista, com as duas afirmações e a origem de cada uma nomeada
  (055 FR-012); *equívoco* e *saída* MUST ser textos distintos.
- **FR-014** *(decisão da pessoa mantenedora em 2026-09-07)*: Pessoa que a origem mostra e que já tem vínculo observado MUST NOT
  ter uma seção "aguardando confirmação" separada da lista: o que falta nela é o
  papel, e a ação está na linha (FR-015). O formulário **em lote** — declarar o papel
  de várias pessoas de uma vez — MUST ser mantido na Estrutura, junto da lista,
  chamando o **mesmo** comando de FR-015, e o resultado MUST dizer **quantas linhas
  foram puladas** por não ter papel escolhido. São dois pontos de entrada para um
  comando só, na mesma aba, com o mesmo registro de autor e data — a tensão com o
  princípio X ("ação num lugar só") foi pesada e decidida.

### Declarar e alterar o papel

- **FR-015**: Quem administra MUST poder declarar o papel **na linha da pessoa**. Em
  vínculo observado sem papel, a declaração MUST completar o **mesmo** vínculo —
  papel, autor, data da declaração — e MUST NOT criar um segundo (055 FR-014).
- **FR-016**: A data de início MAY ser declarada no mesmo ato; em branco, MUST
  permanecer *desconhecido* — o campo MUST NOT vir preenchido com hoje (043 FR-019).
- **FR-017**: Quem administra MUST poder **alterar** um papel declarado. O papel
  anterior MUST permanecer registrado com o período em que vigeu; o novo MUST
  passar a valer da data informada, ou de hoje quando a alteração é feita hoje —
  e a tela MUST dizer qual das duas. Nenhum registro é apagado.
- **FR-018**: Um segundo papel simultâneo para a mesma pessoa na mesma equipe MUST
  ser aceito (043 FR-006a) e apresentado ao lado do primeiro.

### A saída

- **FR-019**: Quem administra MUST poder registrar a saída de uma pessoa, com data,
  em vínculo **observado ou declarado**. O vínculo MUST ganhar fim; MUST NOT ser
  apagado (055 FR-004).
- **FR-020**: Registrar a saída MUST NOT alterar nenhum número de período anterior à
  data (055 FR-005, SC-003).
- **FR-021**: A saída declarada MUST guardar **quem a registrou e quando** — e essa
  informação MUST ser distinta do fim constatado pela coleta (055 FR-015). *Hoje o
  comando de encerrar grava só a data — ver Impacto.*
- **FR-022**: A tela MUST distinguir, em texto, fim **declarado** (por quem, quando)
  de fim **constatado pela coleta**, e neste caso MUST declarar que a data diz quando
  a plataforma deixou de ver, não quando a pessoa saiu (055 FR-015a).
- **FR-023** *(decisão da pessoa mantenedora em 2026-09-07)*: A data da saída é **obrigatória**: saída sem data MUST ser recusada
  com a razão, e o campo MUST NOT vir preenchido com hoje — a premissa da 055 ("hoje,
  marcada como presumida") fica substituída, porque presunção sem marca no registro
  vira fato. Data no futuro MUST ser recusada. Saída em vínculo já encerrado MUST ser
  recusada sem reescrever a data original.

### O equívoco

- **FR-024**: Quem administra MUST poder marcar como equívoco um vínculo vigente,
  **observado ou declarado**, com razão escrita obrigatória. O registro MUST guardar
  razão, autor e data; nenhuma linha MUST ser removida (055 FR-006). *Decisão de
  2026-09-07; fecha a decisão em aberto 2 da emenda de 2026-09-06 da 055.*
- **FR-025**: Vínculo invalidado MUST ser excluído de **toda** medida, em **toda**
  data (057 FR-003).
- **FR-026**: Depois de saída declarada (FR-019) **ou** equívoco (FR-024) num vínculo
  observado, a coleta MUST NOT criar vínculo novo para o par pessoa–equipe
  **enquanto a observação da origem for contínua**. A evidência continua sendo
  coletada; a tela mostra as duas afirmações (055 FR-012, FR-016). *A guarda de hoje
  só reconhece declaração por autor ou papel preenchidos, e um vínculo observado
  encerrado ou invalidado tem os dois nulos — ela recria. Ver Impacto.*
- **FR-027**: Observação **nova** — depois de a origem ter deixado de listar a
  pessoa e a coleta ter constatado a ausência — MUST gerar vínculo observado novo
  (055 FR-015), e os períodos coexistem.
- **FR-028**: A recusa por falta de razão MUST nomear o motivo. A tela MUST dizer que
  equívoco **não é** saída — *nunca esteve* e *saiu em D* são afirmações diferentes
  e produzem efeitos diferentes nas medidas.

### Os papéis da organização

- **FR-029**: A Estrutura MUST listar os papéis **da organização** da equipe: os do
  catálogo SRO (Developer, Scrum Master, Product Owner, Client) e os criados pela
  organização, com origem, código, quantas pessoas os desempenham nesta equipe e na
  organização.
- **FR-030**: Quem administra MUST poder **criar** papel a partir da Estrutura, com
  nome e código, pelo **mesmo comando** de `/roles` e no **mesmo escopo** — a
  organização. O papel MUST guardar autor e data, e MUST aparecer de imediato em
  todo seletor de declarar papel da organização e em `/roles`.
- **FR-031**: O código MUST ser sugerido a partir do nome e MUST ser editável. Código
  repetido na mesma organização MUST ser recusado com a razão; o mesmo código em outra
  organização MUST NOT ser conflito.
- **FR-032**: Quem administra MUST poder **renomear** papel criado pela organização;
  os vínculos MUST continuar apontando para o mesmo papel.
- **FR-033**: Quem administra MUST poder **ocultar** papel criado pela organização.
  Papel com vínculo vigente MUST NOT ser ocultado, e a recusa MUST dizer **quantos**
  vínculos impedem. Papel do catálogo MUST NOT ter ação de remover.
- **FR-034**: O seletor de declarar papel (FR-015) MUST oferecer *novo papel…*, que
  abre o formulário de FR-030 **sem sair da linha**; ao criar, o novo papel MUST
  estar selecionável na mesma linha.

### As subequipes

- **FR-035**: A Estrutura MUST listar uma linha por composição **vigente** — nome
  da subequipe, origem dela (observada/declarada), membros vigentes, *X observados /
  Y declarados*, *faz parte desde* (data ou *desconhecido*), quem declarou.
- **FR-036**: Composição **encerrada** MUST aparecer como histórico, com período e
  quem encerrou, e MUST NOT ser apresentada como atual (057 FR-013).
- **FR-037**: Quem administra MUST poder declarar que uma equipe **existente** da
  mesma organização faz parte desta, com data de início **ou em branco =
  desconhecido** (055 FR-008). *Hoje a composição exige início e o grava como agora
  — ver Impacto.* Declarar uma equipe **nova** dentro desta continua existindo.
- **FR-038**: Composição que fecharia ciclo, por caminho de qualquer comprimento,
  MUST ser recusada com o **caminho nomeado** (055 FR-009).
- **FR-039**: Quem administra MUST poder encerrar a composição; a subequipe MUST
  continuar existindo com o histórico intacto (055 US3 cenário 3), e nenhum número
  de período anterior MUST mudar.
- **FR-040**: Equipe composta MAY ter membros **diretos**. O Dashboard MUST ter a
  linha *membros diretos* (057 FR-007) e a Estrutura MUST marcar esses vínculos como
  *direta*.
- **FR-041** *(decisão da pessoa mantenedora em 2026-09-07)*: No Dashboard da equipe
  composta, cada subequipe MUST ser um **cartão** com as mesmas medidas da tabela, e
  clicar no cartão MUST abrir o Dashboard daquela subequipe (057 FR-010). O cartão
  MUST ser porta **sem** depender de gráfico: o gráfico pequeno é FR-084, e a porta
  não espera por ele. **Cobrado na US7**, não na US6 — o cartão é artefato do
  Dashboard reorganizado, e a US6 termina antes de ele existir (decisão 11).
- **FR-042**: A Estrutura MUST mostrar *faz parte de* — as equipes de que esta é
  parte —, com link.

### O Dashboard e a composição das medidas

- **FR-043**: Toda medida do Dashboard MUST trazer a composição *N membros — X
  observados na ferramenta sem papel declarado, Y declarados*, X + Y = N, vigente na
  data da consulta (058 FR-026, FR-026b), e quando X > 0 MUST dizer que para esses o
  papel é desconhecido (058 FR-026c). Em equipe composta, a composição é por
  subequipe e por *membros diretos*.
- **FR-044**: O Dashboard da equipe composta MUST NOT apresentar soma, média ou total
  das subequipes (057 FR-008), MUST dizer por quê (057 FR-009), e MUST ordenar os
  cartões e as linhas pelo mesmo critério da tabela de hoje — trabalho parado, do
  maior para o menor (057 SC-005).
- **FR-045**: Subequipe sem trabalho no período MUST ter a ausência dita em texto,
  nunca zero (057 FR-012).
- **FR-046**: As seções da 058 — espera por revisão com cerimônia à parte, taxa do
  pipeline, quem trabalhou nos projetos —, as habilidades da 029 e os avisos de
  processo da regra `process_antipatterns.yaml` MUST permanecer no Dashboard como
  estão, com os requisitos das specs e regras de origem. Esta spec **não** os altera.
- **FR-047**: Em equipe **simples**, o Dashboard MUST continuar a mostrar o detalhe
  da 057 (US3 a US6) — as seções por pessoa, o burn e a previsão — e as seções da
  058. Esta spec não altera a equipe simples além das abas.
- **FR-048**: Os antipadrões de estrutura (ap01, ap02) MUST permanecer no Dashboard
  (058 FR-025).

### Os projetos, e o trabalho fora deles

- **FR-049**: O Dashboard MUST listar os projetos em que a equipe trabalha
  **exclusivamente** pelos vínculos declarados equipe → projeto, vigentes **e**
  encerrados no período, cada um com o seu período (058 FR-008). Nenhum projeto MUST
  ser inferido de repositório, quadro ou item.
- **FR-050**: Cada linha de projeto MUST nomear as subequipes desta equipe que têm
  vínculo **próprio** ao mesmo projeto. Subequipe sem vínculo próprio MUST NOT
  aparecer como "no projeto" pela composição.
- **FR-051**: Os números da linha de projeto — itens abertos, fechados na janela,
  aguardando revisão, taxa do pipeline — MUST ser os do trabalho dos membros da
  equipe **dentro dos repositórios e quadros daquele projeto**, na janela. A tela
  MUST dizer por que as linhas não somam (duas subequipes no mesmo projeto
  compartilham itens). *Esse recorte — equipe ∩ projeto — não está declarado nas
  medidas; ver Impacto.*
- **FR-052**: Ligar e desligar projeto MUST viver na Estrutura (FR-003), sob a
  mesma permissão de FR-006.
- **FR-053** *(decisão da pessoa mantenedora em 2026-09-07)*: O Dashboard MUST apresentar um **alerta** de trabalho fora de
  projeto declarado, definido assim: (i) **issues e solicitações de mudança
  abertas**, de membros da equipe no período do vínculo, em **repositório que não está
  em nenhum quadro de projeto declarado** da equipe — nem ligado ao projeto, nem
  presente em quadro ligado a ele —; e (ii) **quadros** (Projects v2) que contêm itens
  abertos de membros da equipe e **não estão ligados a nenhum projeto declarado**. O
  alerta MUST dizer **onde** (o repositório ou o quadro, e que ele não está ligado a
  projeto), **quem** (sob a fronteira de FR-007) e **quantas abertas**. Item fechado
  não entra: o alerta é sobre o que está em andamento sem nome.
- **FR-054**: O alerta MUST NOT ser apresentado como linha de projeto, MUST NOT
  inferir projeto, e MUST permanecer até que a organização declare o projeto e ligue
  a equipe a ele. A tela MUST dizer isso com essas palavras.
- **FR-055**: Equipe sem nenhum projeto declarado e com trabalho MUST ter todo o
  trabalho no alerta, e a taxa do pipeline MUST continuar recusada nomeando o elo
  que falta (058 FR-013a) — as duas seções nomeiam a mesma lacuna.

### O fluxo da equipe inteira

- **FR-056**: Para as medidas de fluxo da equipe **composta**, o conjunto de
  membros MUST ser a **união distinta** de quem tem vínculo vigente com a equipe ou
  com qualquer subequipe cuja composição vigia — ambos avaliados **na data do
  evento** —, recursivamente pela composição. Cada item MUST contar **uma vez**
  (`DISTINCT`). *É a definição que esta spec dá e que a base precisa declarar; ver
  Impacto e Premissas.*
- **FR-057**: O período do vínculo (057 FR-001, FR-002) e a exclusão do invalidado
  (057 FR-003) valem para a equipe inteira exatamente como para a subequipe.
- **FR-058** — **EMENDA a 057 FR-011**: O Dashboard da equipe composta MUST
  apresentar o burn-up/burn-down, o *Prometido × Entregue* e a previsão de Monte
  Carlo da equipe inteira, e um gráfico pequeno em cada cartão de subequipe. O que
  057 FR-011 protegia — comparação em números alinhados, sem gráfico — continua
  valendo para a **tabela** por subequipe.
- **FR-059**: O burn-up/burn-down MUST seguir 057 FR-026 a FR-028 e FR-030: duas
  séries num eixo, linha de base dos itens já abertos no início da janela, o que
  resta como região derivada, "fechado" declarado como ato da ferramenta.
- **FR-060**: A tela MUST declarar que a curva da equipe inteira **não é a soma** das
  curvas das subequipes — pessoa em duas subequipes e item com dois responsáveis
  contam uma vez aqui e uma vez em cada cartão (esclarecimento de 057 FR-008).
- **FR-061**: O burn e o *Prometido × Entregue* MUST oferecer granulação **semana,
  mês e ano**. Trocar a granulação **mantendo a janela** MUST reagrupar os **mesmos
  itens**, e MUST NOT mudar a medida: a soma de abertos e a de fechados na janela
  MUST ser igual nas três. Cada granulação tem janela padrão própria (FR-078), e
  quando a troca de granulação troca a janela, o título MUST dizer a nova.
- **FR-062**: *Prometido × Entregue* MUST apresentar, por período, os itens
  **abertos** no período e os itens **fechados** no período — as mesmas duas
  contagens que alimentam o burn, sem acumular. *Fechado* é `external_closed_at`
  na ferramenta, e não coluna de quadro nem critério de término (057 FR-030; issue
  #506 fora de escopo).
- **FR-063** — **EMENDA a 057 FR-029**: A declaração *não há escopo comprometido*
  continua obrigatória, e MUST aparecer **junto do título** de *Prometido ×
  Entregue* com a definição operacional — *prometido = aberto no período; entregue =
  fechado no período*. A palavra "prometido" MUST NOT aparecer sem essa definição ao
  lado, e o gráfico MUST NOT ser lido como compromisso nem como término de sprint.
- **FR-064**: A previsão de Monte Carlo da equipe inteira MUST seguir 057 FR-031 a
  FR-037 e MUST ser **semanal** independentemente da granulação escolhida em
  FR-061 — as amostras são as semanas da janela mostrada (FR-078). A tela MUST dizer
  isso, e o piso de 057 FR-034 vale sobre essa janela.

### A visão geral do gestor — problemas agora

- **FR-065**: O Dashboard MUST apresentar, antes das medidas, a seção *Problemas
  agora*: um cartão **contado** por fato, com o **limiar escrito no cartão** e a
  origem do limiar na base de conhecimento. Os fatos: (a) issues abertas há mais que
  o limiar; (b) solicitações de mudança **de código** esperando a primeira revisão
  humana há mais que o limiar; (c) pipeline falhando **agora** na branch padrão, por
  repositório dos projetos declarados da equipe; (d) tarefas abertas além do limiar
  de parada (057 FR-020); (e) pessoas sem tarefa aberta (057 FR-021); (f) membros
  sem papel declarado (055 FR-018); (g) trabalho fora de projeto declarado (FR-053);
  (h) anomalias de estrutura (058 FR-025).
- **FR-066**: Cada cartão MUST dizer sobre o que foi contado — a janela, e o
  conjunto de membros com a composição de FR-043 — e MUST NOT inferir: o número é
  contagem sobre fato coletado ou declarado.
- **FR-067**: Cartão com contagem zero MUST dizer *conferido, nada encontrado*.
  Quando um insumo não é coletado ou a medida não é calculável, o cartão MUST dizer
  *não conferido* e o que falta. Os dois estados MUST ser distinguíveis em texto, e
  nenhum dos dois MUST ser um zero mudo.
- **FR-068**: Cada cartão com número maior que zero MUST levar à lista do que
  contou — a seção do Dashboard ou da Estrutura que detalha o fato; (f) leva à aba
  Estrutura.
- **FR-069** *(decisão da pessoa mantenedora em 2026-09-07)*: **Nenhum limiar MUST viver em constante de módulo.** Cada limiar
  MUST estar declarado em YAML da base antes de o cartão existir — pela mesma razão
  que `profile.thresholds` dá: é decisão sobre o que a plataforma afirma, e mudá-lo é
  decisão registrada. Os limiares desta seção são: (a) issue aberta há mais de **30
  dias** e (b) solicitação de código esperando revisão humana há mais de **7 dias** —
  **confirmados em 2026-09-07**, a declarar em YAML com a decisão que apoiam antes
  dos cartões nascerem; (d) tarefa parada usa o limiar **já declarado**
  `profile.thresholds.stale_open_work.stale_days = 90`, contado desde a abertura do
  item. A leitura "14 dias sem mudança de estado" do protótipo foi **recusada**: um
  só limiar de parada na plataforma.
- **FR-070**: Em equipe composta, o número do cartão MUST ser a contagem
  **distinta** sobre o conjunto de FR-056; a quebra por subequipe MAY ser exibida, e
  a tela MUST dizer que as partes podem se sobrepor — pessoa em duas subequipes conta
  nas duas — e por isso não formam partição (057 FR-008).
- **FR-071**: O cartão (c) MUST seguir o caminho da 058 — repositórios dos projetos
  declarados da equipe (058 FR-013) —, olhar a **branch padrão** coletada de cada
  repositório e a **última verificação concluída** nela; verificação em andamento
  MUST NOT contar (058 FR-014). Equipe sem projeto declarado MUST ter o cartão como
  *não conferível*, nomeando o elo (058 FR-013a).
- **FR-072**: O cartão (b) MUST usar a mesma população da 058 US1 — solicitações de
  código, com a cerimônia do processo contada à parte pela regra
  `change_request.ceremony` — e a primeira revisão **humana**. *Sem revisor pedido*
  MUST NOT ser apresentado enquanto a coleta não trouxer o pedido de revisão, que
  hoje não é coletado — o protótipo mostra e a spec recusa.

### A visão geral do gestor — as pessoas

- **FR-073**: O Dashboard da equipe **composta** MUST apresentar *Pessoas — diretas e
  pelas subequipes*: todos os membros vigentes do conjunto de FR-056 na data da
  consulta, agrupados por subequipe e por *membros diretos*. Pessoa em mais de uma
  subequipe MUST aparecer em cada grupo, com *também em X*, e MUST contar **uma vez**
  no total.
- **FR-074**: Cada pessoa MUST trazer o papel ou *não declarado*; **todas** as tarefas
  abertas atribuídas a ela **agora**, cada uma com identificação, link e há quanto
  tempo está aberta, contado da **abertura do item** e declarado como tal (057 FR-017,
  FR-019, FR-019a); a marca de parada pelo limiar declarado (057 FR-020, FR-069);
  **nenhuma** tarefa eleita como "atual" (057 FR-018); e, sem tarefa, a ausência dita
  em texto (057 FR-021).
- **FR-075** *(decisão da pessoa mantenedora em 2026-09-07)*: O perfil demonstrado MUST ser lido do trabalho fechado, cada
  habilidade com marca de derivada (057 FR-022), e a coluna MUST mostrar **até
  quatro** habilidades, com *+N no perfil* quando houver mais e **link para o perfil
  detalhado da pessoa** (`/people/:id`). Quais quatro é decisão do `plan.md` contra
  `profile.thresholds.highlight`, e a tela MUST dizer o critério. Abaixo do piso de
  `profile.thresholds.evidence_floor` (**15** tarefas concluídas com descrição) a
  coluna MUST dizer *sem perfil ainda*, com o piso e quanto a pessoa tem, e MUST NOT
  listar habilidade (057 FR-023). A tela MUST declarar que ausência é *não observada
  aqui*, nunca incapacidade (057 FR-024).
- **FR-076** *(decisão da pessoa mantenedora em 2026-09-07)*: A seção *Pessoas* e todo cartão que nomeia pessoa MUST seguir a
  fronteira de FR-007: nome, tarefas e perfil de pessoa nomeada para quem tem escopo
  sobre a equipe (`team`, `organization`, administradora) **e para os membros
  vigentes da equipe** — a conta cuja pessoa tem vínculo vigente nela; os agregados —
  quantas pessoas, quantas sem tarefa, quantas paradas — legíveis por qualquer conta
  do tenant; a recusa MUST ser nomeada (058 FR-024a).
- **FR-077**: Grupo grande MAY ser truncado com *… N mais em X — abrir a subequipe*;
  o truncamento MUST dizer **quantos** ficaram de fora, como o teto da espera por
  revisão já diz quando corta.

### A janela e a granulação

- **FR-078** *(decisão da pessoa mantenedora em 2026-09-07)*: Os gráficos de fluxo (FR-058 a FR-064) MUST ter **janela padrão
  fixa por granulação** — **8 semanas** para semana, **12 meses** para mês, **todos os
  anos coletados** para ano — **e** a pessoa MAY escolher outro período. O **título de
  cada gráfico MUST dizer sempre a janela mostrada**, padrão ou escolhida. A janela
  escolhida MUST constar na URL, pela mesma razão da aba (FR-001): um link cai onde
  aponta. É a resposta à objeção da 057 (L86) ao seletor: o denominador pode mudar,
  mas nunca em silêncio.
- **FR-079** *(decisão da pessoa mantenedora em 2026-09-07)*: As medidas do Dashboard — espera por revisão, taxa do pipeline,
  cartões, linhas de projeto, alerta — MUST usar janela padrão de **56 dias** **e** a
  pessoa MAY escolher outro período; o título de cada seção MUST dizer a janela
  mostrada. Toda comparação entre subequipes ou entre projetos na mesma tela MUST
  usar a **mesma** janela. Nenhuma medida MUST ser apresentada sem a janela escrita
  junto do número.

### Quem gere a estrutura

- **FR-080** *(decisão da pessoa mantenedora em 2026-09-07)*: A plataforma MUST reconhecer a **concessão *gerir estrutura da
  equipe*** atribuída a um **papel organizacional**, com alcance `team` (as equipes em
  que a pessoa desempenha o papel, com vínculo vigente) ou `organization` (todas as
  equipes da organização), registrando quem concedeu e quando, e revogável por
  **marca**, nunca por remoção — o mesmo molde da concessão de visibilidade
  (`eo_role_visibility_grants`, #369, 045 FR-022). MUST NOT nascer segundo tipo de
  conta, nem `role` novo na plataforma: gestor é **papel organizacional com
  concessão**, e a organização cria o papel (US5) e a administradora concede.
- **FR-081**: A concessão MUST ser declarada por conta **administradora**, no mesmo
  lugar em que as concessões de visibilidade por papel são declaradas hoje
  (`/roles`). A aba Estrutura MUST mostrar, na seção *Papéis*, quais papéis carregam
  a concessão — leitura, não escrita.
- **FR-082**: Vínculo encerrado ou invalidado MUST NOT conferir a concessão — quem
  saiu da equipe deixou de gerí-la; e a concessão MUST NOT ser inferida por nome de
  papel ("Tech Lead", "Coordenador"): só a declaração confere (#369, FR-012e da 023).
  Toda recusa MUST nomear o motivo — *sem concessão*, *vínculo encerrado*, *conta sem
  pessoa declarada* são bloqueios diferentes.

### A equipe composta de referência, e a derivada

- **FR-083** *(decisão da pessoa mantenedora em 2026-09-07)*: A equipe composta de referência ("Conecta Fapes") MUST ser
  **declarada** pela organização (055 FR-001) e os squads **observados** MUST ser
  compostos nela por declaração (055 US3 cenário 4, FR-037). A equipe **derivada**
  (`github.default_team` — quem não está em time nenhum) MUST continuar existindo ao
  lado, regida pela regra dela, e MUST NOT ser composta automaticamente em equipe
  alguma; compô-la é declaração como qualquer outra, e a tela MUST continuar dizendo
  que ela não existe na ferramenta de origem.

### O gráfico pequeno no cartão da subequipe

- **FR-084** *(decisão da pessoa mantenedora em 2026-09-07)*: O cartão de subequipe
  de FR-041 MUST ganhar o **gráfico pequeno** de FR-058, e clicar no gráfico MUST
  abrir o Dashboard daquela subequipe — a mesma porta do cartão (057 FR-010). A
  **tabela** por subequipe MUST permanecer sem gráfico (057 FR-011 emendado por
  FR-058). **Cobrado na US9**, não na US6: o gráfico é fluxo, e chega quando o fluxo
  chega (decisão 11).

### A aba *Flow per person* — onde ela vive

*FR-085 a FR-112 foram transcritos em 2026-09-10 de
[`spec-graficos-por-membro.md`](spec-graficos-por-membro.md) (2026-09-08), com as emendas do
protótipo aprovado. De FR-113 em diante, cada requisito nomeia o **item da seção 3** do
[`team-people-PROMPT.md`](prototipo/team-people-PROMPT.md) de onde saiu — a mesma seção que o QA
confere item a item.*

- **FR-085** *(§3.1)*: `/teams/:id` MUST ganhar uma **terceira aba**, com o valor `people` no
  mesmo parâmetro de aba da FR-001, e MUST NOT ganhar rota nova. A aba MUST ser nomeada pelo que
  responde — o fluxo de cada pessoa —, e não por "métricas".
- **FR-086** *(§3.5)*: O conteúdo **padrão** da aba MUST ser uma **tabela**, uma linha por membro
  do mesmo conjunto que alimenta o Dashboard (FR-057), **sem gráfico em nenhuma linha**. O que a
  057 FR-011 protegia — comparação em números alinhados — vale aqui com pessoas no lugar de
  subequipes.
- **FR-087**: ~~Os quatro gráficos de uma pessoa MUST abrir sob demanda, no lugar, e o número
  máximo de pessoas abertas ao mesmo tempo MUST ser limitado — *proposto: três*.~~ — **EMENDADA
  pelo protótipo aprovado em 2026-09-08**. O teto é **duas**, e a segunda troca o layout: ver
  **FR-124**. Continuam valendo desta redação: os gráficos MUST abrir **sob demanda**, e o bloco
  aberto MUST levar a `/people/:id`.

  O texto original: *"o número máximo de pessoas abertas ao mesmo tempo MUST ser limitado —
  proposto: três. (O número está entre as perguntas abertas; o limite não está.)"* A razão da
  emenda está na tela e no `team-people-README.md`: três gráficos lado a lado nesta coluna dão
  ~19 rem cada, abaixo do que uma série de oito pontos com rótulos de eixo carrega, e três
  escalas simultâneas não são comparação.
- **FR-088** *(§3.6, item 17)*: A seção *What each person is on* do Dashboard MUST permanecer
  onde está, MUST ganhar o caminho para a aba nova, e as duas MUST NOT ser fundidas. A do
  Dashboard responde **o que está na mão de alguém agora**; a aba nova responde **como o fluxo
  de cada um se comportou na janela**. A aba MUST NOT repetir a lista de tarefas abertas.

### Working in progress — a definição

- **FR-089** *(§3.6, item 18)*: *Working in progress* por pessoa MUST ser a **série** do número
  de itens designados a ela e abertos em cada instante amostrado da janela, na granulação em uso
  — e MUST NOT ser um número solto. O valor de agora MAY aparecer como o último ponto, rotulado
  com o instante em que foi amostrado.

  *Das três leituras possíveis — o número de agora, a série, ou o limite de WIP do quadro — a
  base já escolheu a segunda: `flow.wip.count` declara `period: weekly` e a limitação "o painel
  da equipe da issue #506 lê a série, e nunca um valor solto". Um valor solto é a má leitura que
  a própria medida enumera.*
- **FR-090** *(§3.3, item 4)*: A tela MUST declarar que *aberto* aqui é `external_created_at`
  presente e `external_closed_at` nulo no instante observado, e que isso **não é**
  `flow.wip.count` como a base a define: aquela fórmula exige `start_date` e `end_date` da tarefa
  executada, o **critério de fim não existe** (limitação declarada na própria medida, issue
  #506), e o tempo aqui conta de quando o **item** foi aberto, não de quando a pessoa o assumiu —
  a origem não registra isso. A declaração MUST aparecer no bloco acima da tabela **e** dentro de
  cada bloco de pessoa aberto.

  *Apresentar esta série sob o nome `flow.wip.count` seria reivindicar uma medida que a coleta
  não sustenta. A substituição é legítima e é a mesma que o burn da equipe já faz; o que não é
  legítimo é não dizer.*
- **FR-091** *(§3.3, item 4)*: A plataforma MUST NOT apresentar **limite de WIP** em lugar algum
  da aba. Não há limite declarado na coleta e não há escopo comprometido (057 FR-029, FR-063). A
  tela MUST NOT desenhar linha de limiar que insinue um.
- **FR-092** *(§3.3, item 4)*: As más interpretações que `flow.wip.count` declara MUST aparecer
  junto da série, **copiadas e não resumidas** — em especial: WIP baixo não significa fluxo
  saudável; WIP alto não é sinônimo de produtividade; e comparar entre pessoas sem normalizar
  transforma a medida em outra coisa.

### Throughput — a definição

- **FR-093** *(§3.6, item 18)*: *Throughput* por pessoa MUST ser a contagem de itens designados a
  ela com `external_closed_at` dentro de cada período da janela, na granulação em uso — o nível
  **person** de `flow.throughput.rate`, que a medida já declara em `scope.levels`.
- **FR-094** *(§3.3, item 3)*: Item com **duas pessoas responsáveis** MUST contar **uma vez para
  cada** aqui, e a seção MUST declarar que somar as linhas **não** dá a vazão da equipe: a da
  equipe é medida sobre o conjunto distinto (FR-060), e não derivada destas linhas.

  *É a regra da 057 — "aparece uma vez para cada" — e a limitação que `flow.throughput.rate` já
  declara: "no nível person, a mesma tarefa aparece uma vez por participante, e a soma dos níveis
  person não é igual ao nível sprint". A unidade desta seção é a pessoa, então vale a regra da
  pessoa. A regra da equipe continua valendo onde a unidade é a equipe, e as duas nunca se
  somam.*
- **FR-095** *(§3.6, item 16)*: *Fechado* MUST ser declarado como `external_closed_at` — ato da
  ferramenta, e não coluna de quadro nem critério de término declarado (FR-062, 057 FR-030). E a
  limitação de que a contagem **ignora o tamanho do item** MUST aparecer junto do número:
  decompor mais fino eleva a vazão sem mais trabalho feito.

### Prometido × Realizado, por pessoa

- **FR-096** *(§3.5, itens 8 e 9; §3.6, item 18)*: *Promised × Delivered* por pessoa MUST
  apresentar, por período da mesma janela, os itens **abertos** no período e os **fechados** no
  período, **sem acumular** — as mesmas duas contagens da FR-062, restritas às designações da
  pessoa.
- **FR-097** *(§3.6, item 16)*: A definição operacional — *prometido = aberto no período;
  entregue = fechado no período* — e a declaração de que **não há escopo comprometido** MUST
  aparecer **uma vez no cabeçalho da seção**, acima da tabela, **e outra vez dentro de cada bloco
  de pessoa aberto**. MUST NOT ser repetida por linha fechada. As colunas da tabela fechada MUST
  usar as palavras operacionais — *opened in the window*, *closed in the window* — de modo que a
  palavra "prometido" nunca apareça sem a definição ao lado.

  *A FR-063 exige que "prometido" nunca apareça sem a definição **ao lado**. Repetir a ressalva
  31 vezes é ruído que ninguém lê, e omiti-la é a FR-063 violada. A saída é não usar a palavra
  onde a definição não cabe, e usá-la onde ela cabe. Esta é uma das duas leituras possíveis da
  FR-063, e o protótipo implementa a leitura (a) — ver **Q21**, pendente.*

### Monte Carlo, por pessoa

- **FR-098** *(§3.6, item 18)*: A previsão por pessoa MUST usar `Forecast.monte_carlo/2` com o
  **mesmo piso** — 6 períodos de história e 10 itens fechados, os valores que `Forecast.piso/0`
  devolve — e MUST ser **semanal** independentemente da granulação escolhida para os outros
  gráficos (FR-064). A tela MUST dizer isso.
- **FR-099** *(§3.5, item 11; §3.6, item 20; §3.8, item 25.2)*: Abaixo do piso, a tela MUST
  **recusar e dizer o que falta, por pessoa**, com os **quatro** números — as semanas que a
  pessoa tem, as exigidas, as fechadas que ela tem, as exigidas —, que o código já devolve em
  `{:sem_historico, %{semanas, semanas_exigidas, fechadas, fechadas_exigidas}}`. As palavras
  **met** e **short** MUST carregar a diferença, de modo que a distinção não dependa de cor.
  Célula vazia, `0`, "N/A", traço e coluna escondida MUST NOT ser usados.
- **FR-100** *(§3.4, item 5)*: A seção MUST declarar, **acima da tabela**, para quantas pessoas
  há previsão e de quantas, e MUST dizer que o piso é do **método** e nunca das pessoas abaixo
  dele. A linha MUST aparecer inclusive quando **N = 0** e quando **N = M**. Numa equipe real a
  maioria fica abaixo do piso, e sem esta linha a tela é lida como quebrada.
- **FR-101** *(§3.6, item 20; §3.8, item 25.2)*: A previsão de uma pessoa abaixo do piso MUST NOT
  ser calculada a partir da história da **equipe**. Sem história da pessoa, não há previsão sobre
  a pessoa — emprestar o ritmo da equipe fabricaria um número sobre alguém.
- **FR-102** *(§3.6, item 20)*: A recusa MUST ser dita como **lacuna do registro observado**,
  nunca como afirmação sobre a pessoa — a mesma gramática que a FR-023 já usa para habilidades:
  *"That is a gap in the record, never a statement about the person."*
- **FR-103** *(§3.6, item 20)*: A previsão por pessoa MUST ser enunciada como pergunta sobre **o
  trabalho** — quando o que está na mão dela termina, ao ritmo observado dela —, e MUST NOT ser
  enunciada como capacidade, compromisso ou prazo da pessoa.

### A janela, a granulação e a ordem

- **FR-104** *(§3.2, item 2)*: Os gráficos e as colunas por pessoa MUST usar a **mesma** janela e
  a mesma granulação dos gráficos do Dashboard, lidas do endereço (FR-078, FR-079), e MUST NOT
  oferecer seletor por pessoa. Trocar qualquer uma das duas MUST reagrupar **todas** as pessoas
  ao mesmo tempo. **Estendida pelo protótipo aprovado em 2026-09-08**: o controle é **um só** e
  fica no cabeçalho da seção — ver FR-115.

  *A FR-079 exige que toda comparação na mesma tela use a mesma janela. Comparação entre pessoas
  é exatamente isso; janela por pessoa faria duas colunas vizinhas medirem períodos diferentes, e
  a seção perderia a única coisa que ela acrescenta.*
- **FR-105** *(§3.5, itens 6 e 10)*: Pessoa cujo vínculo começou dentro da janela MUST ter a data
  de início junto da linha, ou *start date unknown* (057 FR-006), e a seção MUST declarar que
  menos períodos com dado é história mais curta dentro da mesma janela, e **não** menos trabalho.
- **FR-106** *(§3.5, item 13)*: A ordem padrão da tabela MUST NOT ser nenhuma das medidas. MUST
  ser por **papel declarado e depois por nome**. **Estendida pelo protótipo aprovado em
  2026-09-08**: nenhum cabeçalho de coluna **se oferece** para ordenar, e a ordem é escrita
  abaixo da tabela — ver FR-117.

### Quem vê

- **FR-107** *(§3.1)*: A aba inteira **é** a quebra por pessoa nomeada, então MUST ser
  apresentada apenas a quem alcança a equipe pelo veredito de acesso vigente (058 FR-024), e a
  decisão MUST vir **antes** da carga. O veredito é `Tenants.Access.pode_ver_equipe/3`, e os
  caminhos são **quatro**, confirmados no código em 2026-09-08: `:admin`, `:escopo_de_equipe`,
  `:escopo_da_organizacao` e `:vinculo_vigente`. O escopo `project` **não** entra — a razão está
  declarada no próprio módulo: *"ele nomeia um projeto, e uma equipe pode trabalhar em vários;
  deixá-lo passar faria autoridade subir de lado."*
- **FR-108** *(§3.1)*: A recusa MUST nomear o motivo (058 FR-024a) — `:fora_do_alcance` é o que o
  veredito devolve. A aba MUST NOT ser escondida em silêncio, e MUST NOT ser apresentada vazia
  como se a equipe não tivesse pessoas.

### O que esta aba NÃO pode fazer

- **FR-109** *(§3.3, item 3)*: A seção MUST declarar, em palavras e não em rodapé, que **não é
  avaliação de desempenho e não é ranking de pessoas**: as medidas descrevem o **trabalho
  observado**, e não a pessoa.
- **FR-110** *(§3.5, item 14)*: A tela MUST NOT derivar nenhum número da equipe destas linhas, e
  MUST NOT apresentar média por pessoa como medida da equipe. O número da equipe é medido
  separadamente (FR-060), e a tela já diz isso na seção *What each person is on*.
- **FR-111** *(§3.5, item 6)*: A **cobertura da coleta relativa à pessoa** MUST aparecer junto dos
  números dela, e não em nota de pé. Número baixo de quem tem repositório não coletado é lacuna
  de coleta, e a tela MUST dizer qual dos dois é. O protótipo aprovado implementa a forma *N repos
  observed · denominator unknown* — a leitura (a) de **Q22**, que segue **pendente**.

  *`PersonWork.timeline_coverage/2` responde cobertura de **timeline**, e as medidas desta aba não
  dependem de timeline — saem de `external_created_at` e `external_closed_at`, que o próprio
  módulo declara com cobertura completa. A cobertura que importa aqui é outra: se os repositórios
  em que a pessoa trabalha foram coletados.* **[NEEDS CLARIFICATION: existe hoje um número de
  cobertura de repositórios por pessoa? `WorkItems.repositories_of_person/2` lista os observados;
  não há como saber os não observados.]**
- **FR-112** *(§3.5, item 14)*: Comparar duas pessoas cuja cobertura difere MUST ser declarado
  como **não comparável**, junto da tabela. Duas colunas alinhadas convidam à comparação; quando o
  denominador difere, a comparação é ilusão e a tela precisa dizê-lo antes de alguém fazê-la.

### O cabeçalho da aba e o controle de granulação — do protótipo aprovado

- **FR-113** *(§3.1)*: O rótulo da aba MUST ser exatamente ***Flow per person*** e o valor no
  endereço MUST ser exatamente `people`. O rótulo nomeia o que a aba responde; o valor é curto
  porque vive na URL.
- **FR-114** *(§3.2, item 1)*: O cabeçalho da seção MUST trazer o título *Flow per person* com
  `N members · <janela> · by <granulação>` — os três juntos, no mesmo lugar, e nenhum número da
  aba MUST aparecer sem que a janela esteja escrita (FR-079, SC-020).
- **FR-115** *(§3.2, item 2)*: A aba MUST ter **um único** controle de granulação `week · month ·
  year`, no **cabeçalho da seção**, e MUST NOT repeti-lo no cabeçalho de cada gráfico. Trocá-lo
  MUST reescrever o endereço e reagrupar **todas** as linhas e todos os gráficos abertos ao mesmo
  tempo. Cada gráfico MUST continuar nomeando a janela no próprio título.

  *É **divergência deliberada** do Dashboard, onde o controle mora no cabeçalho de cada gráfico:
  dois gráficos de duas pessoas não podem ficar em janelas diferentes (FR-079, FR-104), e um
  controle repetido oito vezes afirma oito controles independentes. Decisão do desenho em
  2026-09-08, reversível pela pessoa mantenedora.*

### Os dois blocos antes dos números — do protótipo aprovado

- **FR-116** *(§3.3, itens 3 e 4)*: A aba MUST apresentar, **acima da tabela** e **sem colapsar**,
  **dois** blocos, na ordem: (1) *a table of work items, not a table of people* — o item com dois
  responsáveis, a ausência de denominador comum entre linhas, *open now* como trabalho que **não**
  se moveu, a ordem declarada, a ausência de ordenação e a ausência de média; e (2) *"working in
  progress" here is not `flow.wip.count`* — a substituição da FR-090, a ausência de limite da
  FR-091 e as más leituras copiadas da FR-092. Os dois MUST aparecer em **toda** equipe e em
  **todo** tamanho de equipe, e MUST NOT ser rodapé, nota, *tooltip* nem bloco recolhível.
- **FR-117** *(§3.5, item 13)*: Nenhum cabeçalho de coluna de medida MUST oferecer ordenação —
  nem afordância, nem seta, nem cursor de clique —, e a ordem em uso MUST estar **escrita** abaixo
  da tabela, nomeando o critério (papel declarado, depois nome). Ordenar pessoas por medida é o
  ranking que esta aba recusa, a um clique de distância.
- **FR-118** *(§3.3, item 3; §3.7, item 23)*: A aba MUST NOT apresentar **média, mediana, taxa ou
  número único por pessoa** em lugar algum — nem na tabela, nem no bloco de uma pessoa, nem no de
  duas, nem em gráfico. Um número por pessoa é exatamente a figura de produtividade que a
  plataforma não sustenta.

### A tabela — as seis colunas do protótipo aprovado

- **FR-119** *(§3.5, item 6)*: A primeira coluna MUST ser `person · role · collection`, e MUST
  trazer, na mesma célula: nome e login; o papel declarado ou ***role not declared*** com a
  origem (*observed at the source*); desde quando, ou ***start date unknown***; a marca
  ***left \<data\>*** com quem declarou e quando, para quem tem saída (FR-021, FR-022); e a
  **cobertura da coleta** (FR-111). Nenhum destes MUST ser omitido por falta de espaço.
- **FR-120** *(§3.5, item 7)*: A segunda coluna MUST ser `open now · and the change across the
  window`: o valor no **último instante amostrado** e a **variação entre a primeira e a última
  amostra** da janela, dita em palavras — *no change across the 8 samples*, *9 at the first sample
  · +2 across the window*, *first sample 20 Aug · +24 since joining*, *unchanged since 14 Aug ·
  still assigned to her at the source*. A variação MUST ser declarada como **leitura** da série
  (FR-089), e MUST NOT ser apresentada como medida nova nem como tendência. **Depende de Q20**: se
  a leitura não for declarada na base, a coluna sai (princípio IV).
- **FR-121** *(§3.5, item 7; §3.8, item 25.3)*: Item que a regra `github.issue_type_routing` não
  classificou MUST aparecer **junto da contagem de que faz parte**, com a marca `—` tracejada e
  distinta em escala de cinza de `TASK`, `US`, `BUG` e `EPIC`, e com a contagem própria — *— n the
  routing rule did not classify*. MUST NOT ser rodapé, MUST NOT ser omitido e MUST NOT ser
  reclassificado por suposição: o item conta em todos os números da linha, e o que ele **é**
  permanece desconhecido.
- **FR-122** *(§3.5, item 10)*: A coluna `weeks with a close` MUST ser a contagem de períodos da
  janela com **ao menos um** fechamento, apresentada como `n of N` — e `N` MUST ser **reduzido**
  para quem entrou dentro da janela (`2 of 3`) ou saiu dentro dela (`3 of 5`), porque o
  denominador é a parte da janela em que a plataforma tem o que dizer sobre a pessoa. MUST ser
  declarada como **leitura** de `flow.throughput.rate`, e **depende de Q20** pela mesma razão da
  FR-120.
- **FR-123** *(§3.5, item 11)*: A coluna `delivery forecast · 12 weeks · weekly` MUST ser **coluna
  de estado, e não de valor**, com fundo hachurado leve em toda a coluna — para que a maioria de
  recusas se leia como **uma região medida**, e não como células que falharam em carregar. Os
  estados MUST ser exatamente **quatro**, e cada um com as suas palavras:

  1. **acima do piso** — `p50 n wk · no p85` e a hipótese, com a proporção de rodadas que
     **nunca zeraram** (FR-098);
  2. **abaixo do piso** — `no forecast · below the floor` e os **quatro** números, com *met* e
     *short* (FR-099);
  3. **sem item aberto** — `nothing to forecast · no open item to reach zero`; **o piso não é a
     razão ali**, e usar as palavras do piso seria outra afirmação falsa;
  4. **sem nada observado** — a marca tracejada do §3.8 item 25.1, com *nothing to forecast* pela
     mesma razão.

  Percentil de rodadas que não concluíram MUST ser **nulo**, nunca um número grande (057 FR-032 a
  FR-035, corrigido em 2026-09-08).

### O bloco de uma pessoa, e o de duas — do protótipo aprovado

- **FR-124** *(§3.5, item 12; §3.6, item 15; §3.7, itens 21 e 24)*: **Emenda a FR-087.** Cada
  linha MUST ter a ação `charts ▾` / `close ▴`. **Uma** pessoa aberta MUST abrir **sob a própria
  linha**, em duas por duas, com faixa à esquerda e cabeçalho com o nome, a janela e o caminho
  para `/people/:id`. **Duas** pessoas abertas MUST **tirar as duas das linhas** e montar **quatro
  linhas de duas colunas** abaixo da tabela, uma linha por medida, com as duas linhas da tabela
  marcadas. O teto MUST ser **duas**, e a razão MUST estar escrita na própria tela. A plataforma
  MUST NOT apresentar três pessoas abertas ao mesmo tempo.

  *O comportamento ao escolher a **terceira** pessoa — recusar, ou fechar a mais antiga — **não
  foi desenhado** no protótipo aprovado. Q25, pendente.*
- **FR-125** *(§3.5, item 14)*: Ao lado da tabela MUST estar (a) a não-comparabilidade da FR-112 e
  (b) **o que a tabela diz e o que não diz da equipe** — a observação sobre **o trabalho**, com as
  leituras que produzem aquela tabela enumeradas e **nenhuma escolhida**. A tela MUST relatar a
  observação e MUST NOT apresentar conclusão: um quadro parado, uma dependência travada e cinco
  pessoas trabalhando em outro lugar produzem a mesma tabela, e a coleta não as distingue.
- **FR-126** *(§3.6, item 17)*: O bloco de uma pessoa aberta MUST trazer a **composição** do
  número de itens abertos por conceito — `TASK n · US n · BUG n · EPIC n`, com a marca do conceito
  —, e MUST NOT trazer a lista de itens, que é do Dashboard (FR-088). A composição é a mistura de
  conceitos sobre a qual a medida foi calculada (ADR 0008).
- **FR-127** *(§3.6, item 18)*: Os quatro gráficos MUST ser numerados **1 → 4**, e os números MUST
  ser a ordem de leitura: *1* o que está lá, *2* o que entrou e saiu, *3* a que ritmo, *4* o que o
  ritmo implica. Os três primeiros MUST ser marcados como **observados** e o quarto como
  **derivado**, com o cartão tracejado, para que uma simulação nunca seja lida como contagem.
- **FR-128** *(§3.6, item 19)*: Gráfico sem dado MUST ser **desenhado** — eixos, escala e a frase
  na própria área de plotagem, sobre fundo tracejado —, dizendo de que a ausência é. Área em
  branco MUST NOT ser usada: é indistinguível de gráfico que não renderizou, e há equipes inteiras
  cujos gráficos estão vazios.
- **FR-129** *(§3.7, item 22)*: No bloco de duas pessoas, cada gráfico MUST manter a **sua**
  escala, com o intervalo **rotulado**, e a linha da medida MUST dizer que os eixos diferem — *as
  formas comparam, as alturas não*. Escala compartilhada MUST NOT ser imposta: ela achataria a
  série menor numa linha no rodapé e chamaria isso de comparação.
- **FR-130** *(§3.7, item 23)*: A linha do *throughput* no bloco de duas pessoas MUST declarar que
  aquelas barras são as barras *delivered* da linha anterior lidas como ritmo — **os mesmos
  números, duas perguntas** —, e MUST declarar que **nenhuma média e nenhuma mediana por pessoa** é
  desenhada. A redundância MUST estar escrita na tela enquanto os quatro gráficos existirem
  (**Q19**, pendente).

### As três ausências — do protótipo aprovado

- **FR-131** *(§3.8, item 25)*: A aba MUST apresentar as **três** ausências como casos distintos,
  cada um com **forma, palavras e lugar próprios**, e MUST NOT usar uma frase só para as três:

  1. **nada observado para a pessoa** — marca **tracejada**, a frase que diz de que a ausência é
     (*no open item assigned · and none observed at any sample of this window*), a linha
     **permanece** na tabela (FR-021), e a distinção explícita do caso vizinho: quem tem itens mas
     nenhum aberto agora é um zero **medido** de uma série que existe, e MUST NOT herdar esta
     frase;
  2. **abaixo do piso da previsão** — os **quatro** números, e os **dois** modos de bloqueio,
     *closed short* e *history short*, mostrados de modo que se distinga qual bloqueia, ou os dois
     (FR-099);
  3. **o item que a regra não classificou** — ausência de **rótulo**, não de medida: `—` tracejado
     junto da contagem de que faz parte, nunca em rodapé (FR-121).

  E a **quarta**, que o protótipo acrescentou e a escrita de 2026-09-08 não previa: *nothing to
  forecast*, para quem não tem item aberto — o piso **não** é a razão ali (FR-123).

### A régua do QA — os 26 itens da seção 3, e o requisito de cada um

*A conferência da aceitação é contra a seção 3 do
[`team-people-PROMPT.md`](prototipo/team-people-PROMPT.md), item a item. Esta tabela é o caminho
de volta: item do prompt → requisito desta spec. Item sem requisito é lacuna; requisito sem item
é invenção — e não há nenhum dos dois.*

| Item da §3 | O que o item exige | Requisito |
|---|---|---|
| §3.1 | `people` no mesmo parâmetro, sem rota nova; rótulo *Flow per person*; só a quem alcança a equipe, com recusa nomeada | FR-085, FR-113, FR-107, FR-108 |
| 1 | título com `N members · <janela> · by <granulação>` | FR-114 |
| 2 | **um** controle de granulação, no cabeçalho da seção; cada gráfico nomeia a janela | FR-115, FR-104 |
| 3 | o bloco *a table of work items, not a table of people*, com os seis pontos | FR-116, FR-094, FR-106, FR-109, FR-112, FR-117, FR-118, FR-120 |
| 4 | o bloco *"working in progress" here is not `flow.wip.count`*, com as más leituras copiadas | FR-116, FR-090, FR-091, FR-092 |
| 5 | *forecast produced for N of M people*, acima da tabela, inclusive N = 0 e N = M | FR-100 |
| §3.5 | a tabela é o conteúdo padrão: uma linha por membro, **nenhum gráfico em nenhuma linha** | FR-086 |
| 6 | `person · role · collection` — papel, início, saída com autor, cobertura | FR-119, FR-105, FR-111 |
| 7 | `open now` e a variação em palavras; a sub-linha do item não classificado | FR-120, FR-121, FR-089 |
| 8 | `opened in the window`, com `none opened` | FR-096 |
| 9 | `closed in the window`, com `none closed` | FR-096, FR-095 |
| 10 | `weeks with a close`, `n of N`, com denominador reduzido | FR-122, FR-105 |
| 11 | a previsão como **coluna de estado**, hachurada, com os estados e os quatro números | FR-123, FR-098, FR-099 |
| 12 | a ação `charts ▾` / `close ▴` por linha — os gráficos abrem **sob demanda** | FR-124, FR-087 |
| 13 | a linha da ordem abaixo da tabela; nenhuma coluna ordena | FR-106, FR-117 |
| 14 | a não-comparabilidade e o que a tabela diz e não diz da equipe | FR-112, FR-125, FR-110 |
| 15 | o bloco de uma pessoa sob a própria linha, com o caminho para `/people/:id` | FR-124, FR-087 |
| 16 | as duas definições e a substituição do WIP **dentro** do bloco | FR-097, FR-090, FR-095 |
| 17 | a composição por conceito, e **nunca** a lista de itens | FR-126, FR-088 |
| 18 | quatro gráficos numerados 1 → 4; três observados, o quarto derivado e tracejado | FR-127, FR-089, FR-093, FR-096, FR-098 |
| 19 | **gráfico vazio é desenhado**, nunca em branco | FR-128 |
| 20 | a recusa com os quatro números, a lacuna do registro, sem emprestar a equipe, e a pergunta sobre o trabalho | FR-099, FR-101, FR-102, FR-103 |
| 21 | duas pessoas abertas saem das linhas: quatro linhas de duas colunas, com as linhas marcadas | FR-124 |
| 22 | cada gráfico com a sua escala rotulada; *as formas comparam, as alturas não* | FR-129 |
| 23 | nenhuma média nem mediana por pessoa; as barras do gráfico 3 são as de *delivered* | FR-118, FR-130 |
| 24 | teto de **duas** pessoas, com a razão na tela | FR-124 |
| 25 | as três ausências, cada uma com forma, palavras e lugar; e a quarta | FR-131, FR-099, FR-121, FR-123 |
| 26 | o cartão *Decisions and open questions* | **nenhum** — declarado **aparato do protótipo**, ver **Q26** |

**O item 26 é o único sem requisito, e a razão está escrita.** O cartão de decisões, as faixas de
narração (*what this screen is*), as marcas `real`/`example` e as faixas `screen N` existem para
quem lê o protótipo, não para quem usa o produto. Tratá-los como tela criaria requisito de
apresentar decisões de desenho a quem abre `/teams/:id`. **Se essa leitura estiver errada, a régua
passa a ter 26 itens e nasce requisito novo** — é o que Q26 pergunta, e este papel não decide por
conta própria o que a régua cobra.

### O que da 055 esta spec só reutiliza

| 055 | O que é | Aqui |
|---|---|---|
| FR-002 | equipe observada × declarada, não só por cor | FR-004 |
| FR-004, FR-005 | saída com data; nada de período anterior muda | FR-019, FR-020 |
| FR-006 | equívoco com razão, sem apagar | FR-024 |
| FR-007 (emendado) | vincular com papel em observado sem papel = declarar o papel | FR-015 |
| FR-008, FR-009 | compor e encerrar; ciclo recusado | FR-037 a FR-039 |
| FR-010, FR-011 | tenant; ações só para quem administra | FR-005, FR-006 |
| FR-012 | duas afirmações, nenhuma escolhida | FR-013, FR-026 |
| FR-013 a FR-013c | vínculo observado: papel nulo, início nulo, nunca preenchido | FR-010, FR-016 |
| FR-014 | declarar completa o mesmo vínculo | FR-015 |
| FR-015, FR-015a | fim constatado pela coleta, limitado pela cadência | FR-022, FR-027 |
| FR-016 | a coleta não toca em vínculo com declaração | FR-026 (**estende** a saída/equívoco em observado) |
| FR-018 | `memberships_pending_role` conta vínculos sem papel | FR-004 |

### Key Entities

- **Vínculo de pessoa a equipe** (`eo.team_membership`) — já existe com pessoa,
  equipe, papel (nulo = não declarado), início (nulo = desconhecido), fim, autor da
  declaração e o trio do equívoco. **Ganha**: quem registrou a saída e quando
  (FR-021). É a única fonte da lista de membros (FR-008).
- **Composição de equipes** (`eo.team_composition`) — já existe com parte, todo,
  início, fim, quem declarou e quem encerrou. **Muda**: o início passa a admitir
  desconhecido (FR-037).
- **Papel organizacional** (`eo.organizational_role`) — já existe, por organização,
  com catálogo SRO e criados; oculto em vez de apagado. Sem mudança; muda o lugar de
  onde o comando é chamado (FR-030).
- **Vínculo equipe ↔ projeto** — já existe com `linked_at`/`unlinked_at`. Sem
  mudança; ganha leitura com período no Dashboard (FR-049).
- **Item de trabalho** (`collected_issue`) — já existe com repositório, quadros
  (`project_titles`), criação e fechamento na ferramenta. É a unidade do burn, do
  *Prometido × Entregue* e do alerta de FR-053.
- **Conjunto de membros da equipe inteira** — **derivado**, não persistido: a união
  distinta de FR-056. Não é conceito novo na base; é uma regra de recorte que
  precisa estar declarada nas medidas antes da tela (Impacto).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Registrar uma saída em D **não altera** nenhum número já apresentado
  para período anterior a D — verificável anotando a série antes e comparando depois,
  para o burn, a espera por revisão e os cartões.
- **SC-002**: Após saída declarada ou equívoco num vínculo observado com a origem
  ainda listando a pessoa, a coleta seguinte cria **0** vínculos novos para o par —
  verificável por consulta antes e depois da coleta; e a tela mostra as duas
  afirmações em 100% desses casos.
- **SC-003**: **100%** das medidas do Dashboard trazem *N — X observados sem papel
  declarado, Y declarados* com X + Y = N, verificável por varredura da tela
  renderizada (058 SC-013).
- **SC-004**: **100%** das linhas da lista de membros dizem, em texto, a origem do
  vínculo (observado / declarado / saiu / equívoco), o papel ou *não declarado*, e o
  início ou *desconhecido*; **0** linhas exibem nível de acesso da plataforma.
- **SC-005**: Um papel criado na Estrutura aparece no seletor de declarar papel de
  **outra** equipe da mesma organização e em `/roles` **sem recarregar a
  aplicação**; **100%** das tentativas de código repetido na mesma organização são
  recusadas; **100%** das tentativas de ocultar papel em uso são recusadas com a
  contagem.
- **SC-006**: **100%** das composições que fechariam ciclo, inclusive de comprimento
  ≥ 3, são recusadas com o caminho nomeado (055 SC-004).
- **SC-007**: `?tab=structure` abre a Estrutura e `?tab=dashboard` (ou ausência)
  abre o Dashboard em **100%** dos acessos; recarregar mantém a aba.
- **SC-008**: Nenhuma célula de total nos cartões nem na tabela por subequipe; o
  fluxo da equipe inteira declara que não é soma — verificável por varredura (057
  SC-003).
- **SC-009**: No burn da equipe inteira, a distância entre as curvas em qualquer
  ponto é igual à contagem de itens em aberto naquele ponto, nas **três**
  granulações; **para a mesma janela**, a soma de abertos e a de fechados é
  **igual** em semana, mês e ano.
- **SC-010**: **0** projetos no Dashboard sem vínculo declarado; **100%** do trabalho
  em repositório/quadro fora de projeto declarado aparece no alerta e em **nenhuma**
  linha de projeto.
- **SC-011**: Uma conta que não é administradora e cuja pessoa não desempenha papel
  com a concessão de gerir estrutura nesta equipe lê as duas abas e encontra **0**
  ações de escrita; **100%** das tentativas por evento dessa conta são recusadas com
  motivo nomeado (055 FR-011, FR-082). Uma conta cuja pessoa desempenha o papel com
  a concessão, com vínculo vigente, encontra **todas** as ações.
- **SC-012**: **0** linhas removidas fisicamente em toda operação desta feature —
  saída, equívoco, alteração de papel, encerramento de composição, ocultação de
  papel (055 SC-005).
- **SC-013**: Quem administra registra a saída de uma pessoa, com data, em **menos
  de 1 minuto**, sem sair da aba Estrutura.
- **SC-014**: A previsão da equipe inteira é idêntica em duas consultas; abaixo do
  piso, nenhuma previsão aparece e a tela diz o que falta (057 SC-009, SC-010).
- **SC-015**: **100%** das medidas e recortes novos desta feature têm YAML na base de
  conhecimento **antes** de aparecer na tela — a lista está em *Impacto* (058
  SC-009; princípio IV).
- **SC-016**: **100%** dos cartões de *Problemas agora* trazem o limiar escrito e a
  origem dele na base; **0** limiares em constante de módulo — verificável lendo o
  código dos cartões contra `priv/knowledge_base/`.
- **SC-017**: **100%** dos cartões com contagem zero dizem *conferido, nada
  encontrado*; **100%** dos cartões cujo insumo não é coletado dizem *não conferido*
  com o que falta; **0** cartões com zero mudo — verificável por varredura da tela
  com um insumo retirado.
- **SC-018**: **100%** dos membros vigentes do conjunto da equipe inteira aparecem na
  seção *Pessoas*; pessoa em duas subequipes aparece nos dois grupos e o total a
  conta **uma** vez — verificável comparando o total com uma consulta `DISTINCT`.
- **SC-019**: **0** pessoas com tarefa "atual" eleita; **100%** das pessoas sem tarefa
  têm a ausência dita em texto (057 SC-006); **100%** das pessoas abaixo do piso
  mostram *sem perfil ainda* com o piso declarado e **0** habilidades listadas;
  **0** linhas com mais de quatro habilidades, e **100%** com link para `/people/:id`.
- **SC-020**: **100%** dos títulos de gráfico e de seção de medida dizem a janela
  mostrada; trocar a janela troca o título em **100%** dos casos; **0** medidas na
  tela sem janela escrita junto do número — verificável por varredura com dois
  períodos diferentes.
- **SC-021**: **100%** dos itens do alerta de trabalho fora de projeto estão
  **abertos** e em repositório ou quadro sem projeto declarado — verificável cruzando
  a lista com os vínculos projeto ↔ repositório e projeto ↔ quadro; **0** itens
  fechados no alerta.

**Da aba *Flow per person*** — SC-022 a SC-032 transcritos de `spec-graficos-por-membro.md` em
2026-09-10, com duas emendas do protótipo aprovado; SC-033 a SC-038 nascem dele.

- **SC-022**: Numa equipe de 31 membros, a aba aberta apresenta **31 linhas e zero gráficos**; o
  número de gráficos na tela é igual a quatro vezes o número de pessoas abertas, e nunca passa de
  ~~doze~~ **oito** — **emendado em 2026-09-08**, porque o teto passou de três pessoas para duas
  (FR-124).
- **SC-023**: A soma da coluna *closed in the window* das linhas é **maior ou igual** à vazão da
  equipe no mesmo período, e a diferença é exatamente o número de itens com mais de um
  responsável da equipe.
- **SC-024**: Trocar a granulação ou a janela no endereço muda **todas** as linhas; não existe
  estado da tela em que duas linhas mostrem janelas diferentes.
- **SC-025**: A soma de abertos e a soma de fechados na janela, para uma mesma pessoa, são
  **iguais** nas três granulações.
- **SC-026**: Em nenhuma célula de medida aparece célula vazia, `0` sem contexto, "N/A" ou traço:
  cada ausência é uma frase que diz do que ela é ausência.
- **SC-027**: A recusa da previsão por pessoa traz os **quatro** números — semanas que tem,
  semanas exigidas, fechadas que tem, fechadas exigidas — em 100% das pessoas abaixo do piso, com
  *met* e *short* escritos.
- **SC-028**: A contagem *delivery forecast produced for N of M people* aparece acima da tabela em
  toda equipe, inclusive quando **N = M** e quando **N = 0**.
- **SC-029**: A palavra "prometido"/"promised" não aparece em nenhum estado da tela sem a
  definição operacional visível no mesmo bloco.
- **SC-030**: Conta que não alcança a equipe recebe recusa com motivo nomeado, e **zero linhas**
  por pessoa: nenhum login, nenhum nome, nenhum número individual chega ao navegador. Conferido
  pela revisão de segurança, como no PR #798.
- **SC-031**: Abrir ~~três~~ **duas** pessoas não passa do teto de consultas por render que o
  teste guarda hoje para a tela da equipe — **emendado em 2026-09-08** (FR-124). O protótipo
  registra que o teto **não foi medido**: é argumento até haver teste.
- **SC-032**: A tabela recém-carregada nunca está ordenada por uma das medidas, em nenhuma equipe.
- **SC-033**: A aba tem **exatamente um** controle de granulação, no cabeçalho da seção; **0**
  controles no cabeçalho de gráfico; acioná-lo reagrupa **100%** das linhas e dos gráficos abertos
  numa só ação, e **100%** dos gráficos continuam nomeando a janela no próprio título (FR-115).
- **SC-034**: **0** áreas de plotagem em branco em qualquer estado da aba; **100%** dos gráficos
  sem dado trazem eixos, escala e a frase na própria área de plotagem — verificável abrindo uma
  pessoa sem nada aberto nem fechado na janela (FR-128).
- **SC-035**: **0** estados da tela com três ou mais pessoas abertas; **100%** das aberturas de
  duas pessoas usam o layout pareado — quatro linhas de duas colunas, fora da tabela, com as duas
  linhas marcadas — e **100%** dos gráficos pareados têm o intervalo do eixo **rotulado** e a
  frase de que os eixos diferem (FR-124, FR-129).
- **SC-036**: **0** médias, medianas, taxas ou números únicos por pessoa em qualquer estado da aba;
  **0** cabeçalhos de coluna com afordância de ordenação; **100%** das telas trazem a ordem escrita
  abaixo da tabela (FR-117, FR-118).
- **SC-037**: **100%** das células da coluna de previsão estão em **um** dos quatro estados
  declarados na FR-123; **0** células vazias na coluna, e o fundo hachurado cobre a coluna inteira
  e não célula a célula.
- **SC-038**: Os **dois** blocos acima da tabela aparecem em **100%** das equipes e em todos os
  tamanhos, **0** deles colapsáveis, e as más leituras de `flow.wip.count` estão **copiadas** —
  verificável comparando o texto da tela com o YAML da medida (FR-116, FR-092).

## Fora de escopo

- **Rollup de competências pela hierarquia** (#397). Depende da composição; é outra
  entrega (055).
- **"Aceitar como trabalho não planejado."** O protótipo sugere essa saída para o
  alerta de FR-053. Não há conceito na base para uma aceitação assim, e esta spec
  **não** o cria: o alerta permanece até haver vínculo declarado. A lacuna fica
  registrada aqui, sem nome.
- **Período sem título.** O seletor de período existe (FR-078, FR-079); o que fica
  fora é qualquer apresentação de número cuja janela não esteja escrita junto dele.
- **Critério de término declarado** (#506). "Fechado" continua sendo o ato da
  ferramenta, e "done" no protótipo é rótulo para isso (FR-062).
- **Mudanças em `/roles`.** As concessões de visibilidade continuam lá; esta spec só
  chama o comando de criar/renomear/ocultar de outro lugar (FR-030).
- **Mover pessoa entre equipes** como ato único: é saída numa e vínculo noutra.
- **Compor a equipe derivada automaticamente.** Ela fica ao lado, com a regra dela
  (FR-083); compô-la é declaração, não coleta.
- **Exportação, notificação, importação de planilha** (055).
- **Alterar o detalhe da equipe simples** da 057 além de pô-lo dentro da aba
  Dashboard.
- **"Sem revisor pedido"** no cartão de revisões. O pedido de revisão não é coletado;
  o número do protótipo não é calculável, e o cartão não o mostra até haver coleta.
- **Silenciar ou adiar um cartão** de *Problemas agora*. Não há conceito na base para
  "problema reconhecido"; o cartão fica enquanto o fato durar.

**Da aba *Flow per person***:

- **Limite de WIP.** Não existe na coleta e não é derivável; seria declaração (FR-091).
- **Ordenar a tabela por medida**, e qualquer afordância que a ofereça. Ordenar por vazão
  decrescente **é** um ranking, a um clique de distância (FR-106, FR-117).
- **Janela ou granulação por pessoa.** Quebra a comparação, que é a razão da aba (FR-104, FR-115).
- **Três ou mais pessoas abertas ao mesmo tempo** (FR-124).
- **Média, mediana ou taxa por pessoa**, em qualquer forma (FR-118).
- **Repetir a lista de tarefas abertas** — é do Dashboard (FR-088).
- **Medidas que dependem de timeline** — tempo em cada estado, tempo até a primeira revisão por
  pessoa. A cobertura de timeline era de 5 repositórios em 53 (medido em 2026-08-15), e as quatro
  medidas desta aba foram escolhidas por não dependerem dela.
- **Redesenho de `/people/:id`.** Continua a casa da leitura profunda; a aba só aponta para ela.
- **Comparar pessoas de equipes diferentes.** A aba é de uma equipe.
- **Avaliação de desempenho individual, em qualquer forma.** Não é fora de escopo por ser
  difícil: é fora de escopo por decisão (FR-109).

## Premissas

Carregadas do protótipo (`prototipo/README.md`) e desta escrita, até serem
contestadas:

- **Mês e ano mudam a granulação e a janela padrão** do burn e do *Prometido ×
  Entregue* (8 semanas · 12 meses · todos os anos coletados — decisão 1, 2026-09-07);
  o Monte Carlo continua semanal (README).
- **Nomes de pessoas no protótipo são fictícios**; contagens e medidas vêm da coleta
  real de 2026-09-06 da `leds-conectafapes`. Nenhum número do protótipo é medida.
- **O conjunto de membros da equipe inteira** é o de FR-056 — união distinta pela
  composição vigente na data do evento. Composição com início desconhecido conta a
  partir da primeira observação, como o vínculo (057 FR-006).
- **"Continuar listando" e "voltar a listar"** são distinguíveis pela evidência: a
  observação é contínua enquanto a evidência não tiver `no_longer_observed_at`; uma
  evidência nova depois disso é retorno (FR-026, FR-027).
- **"Squads on it"** na linha de projeto são as subequipes com vínculo **próprio**
  ao projeto (decisão 6: só vínculo declarado). A composição não propaga vínculo a
  projeto.
- **Alterar papel** (FR-017) encerra a alocação anterior e cria a nova — a alocação
  é relator com período, e "editar" o papel apagaria o período em que o anterior
  vigeu. É desenho a confirmar no `plan.md`, não regra nova.
- **A interface é em inglês**, com pt como tradução (decisão de 2026-09-01).
- **Janelas padrão**: 56 dias para as medidas; por granulação para os gráficos; as
  duas escolhíveis, com a janela no título (decisões 1 e 9, 2026-09-07). Se o
  controle é um só ou dois é decisão do `plan.md`; o que a spec fixa é que nenhum
  número aparece sem a janela escrita.
- **Quem age na estrutura** é a administradora do tenant e quem desempenha papel
  organizacional com a concessão *gerir estrutura da equipe* (decisão 8, 2026-09-07;
  FR-080 a FR-082). Esta spec não cria tipo de conta nem `role` de plataforma; cria
  um **tipo de concessão** a papel, no molde da de visibilidade.
- **O piso do perfil é o declarado**: `profile.thresholds.evidence_floor.tasks_with_body
  = 15` tarefas concluídas com descrição. O "floor is 5" do protótipo confunde com
  `tasks_per_period = 5`, que é o piso da **evolução**, não do perfil.
- **O conjunto de pessoas da seção *Pessoas*** é o de FR-056 na data da consulta —
  o mesmo que sustenta o fluxo da equipe inteira; não há uma segunda definição de
  membro (058 FR-026a).
- **Onde o protótipo diverge desta spec**: (a) o protótipo mostra o alerta e a seção
  *Pessoas* com nomes para qualquer leitor — FR-007 e FR-076 restringem; (b) o
  protótipo sugere "aceitar como não planejado" — fora de escopo; (c) o protótipo não
  mostra o autor da saída em vínculo observado encerrado pela coleta — FR-022 exige
  distinguir; (d) o protótipo diz "floor is 5" — o piso declarado é 15; (e) o
  protótipo mostra "12 with no reviewer requested" — não coletado, fora de escopo;
  (f) dos limiares do protótipo, 30 e 7 foram confirmados em 2026-09-07 e ganham
  YAML; "14 d sem mudança de estado" foi recusado — a parada é a declarada, 90 dias
  desde a abertura; (g) o protótipo lista o perfil sem teto — a coluna mostra até
  quatro, com link. A spec vence nos sete.

**Da aba *Flow per person*** (protótipo de 2026-09-08):

- **A aprovação do protótipo desta aba está atestada e não registrada** — ver o bloco no início
  desta spec. Toda a transcrição de FR-085 a FR-131 assume a atestação de 2026-09-10 citando
  2026-09-08.
- **`Forecast.monte_carlo/2` serve por pessoa sem alteração.** Recebe uma série de
  `%{criadas, fechadas}` e o número de abertos; nada nela é da equipe. Verificado em 2026-09-08
  lendo a assinatura e o piso.
- **O conjunto de membros é o da FR-057**: vínculo vigente, invalidado excluído, saída declarada
  respeitada. Esta aba não decide quem é membro.
- **A US9 vem antes.** A janela no endereço, o controle de granulação, as definições da FR-062 e a
  ressalva da FR-063 nascem nela. Se a US9 mudar qualquer uma, esta aba muda com ela.
- **Equipe de referência para a conferência**: LEDS - ConectaFapes, 31 membros — o caso que
  reprova qualquer desenho que não faça o recorte.
- **Nada do protótipo desta aba é medida, com quatro exceções declaradas nele**: os itens abertos
  de quem está em equipe (760 TASK · 288 US · 71 BUG · 35 EPIC, 1 154), a composição de SQUAD PINK
  (297) e da Equipe IA (83), os tamanhos das três equipes, e as idades do item aberto mais novo
  (217 dias) e do mais velho (550) — medidos na base de desenvolvimento em 2026-09-08. **Nenhum
  fechamento foi medido**: todo número de *opened*, *closed*, *weeks with a close* e previsão do
  protótipo é exemplo, e os zeros do SQUAD PINK são **inferência**. A faixa de 31 linhas é exemplo
  por inteiro. O teto de consultas (SC-031) **não foi medido**.
- **Onde o protótipo desta aba diverge desta spec**: nada, por construção — a spec foi escrita
  **a partir** dele em 2026-09-10, e onde o texto de 2026-09-08 divergia, a emenda está no
  requisito. O que resta são as **oito decisões pendentes** da seção seguinte, e nenhuma delas é
  divergência: são pontos que ninguém decidiu ainda.

## Decisões de 2026-09-07

As quatro perguntas que esta escrita deixou abertas (1 a 4), seis levantadas pela
coordenação (5 a 10) e uma levantada pela **DSM desta feature** (11) foram
respondidas pela pessoa mantenedora em **2026-09-07**.
Nenhuma está em aberto. Cada requisito tocado leva a marca *(decisão da pessoa
mantenedora em 2026-09-07)*.

| # | Pergunta | Decisão | Onde |
|---|---|---|---|
| 1 | janela dos gráficos por granulação | padrão fixo por granulação — 8 semanas · 12 meses · todos os anos coletados — **e** a pessoa pode escolher outro período; o título sempre diz a janela | FR-061, FR-064, FR-078, SC-009, SC-020 |
| 2 | saída sem data | **recusar** — a data é obrigatória | FR-023 |
| 3 | formulário em lote de declarar papel | **manter**, com a contagem das puladas | FR-014 |
| 4 | limiares de *Problemas agora* | **30 d** (issues abertas) e **7 d** (revisões esperando) confirmados, com YAML e a decisão que apoiam; parada usa os **90 d** já declarados em `profile.thresholds.stale_open_work` | FR-069, Impacto |
| 5 | perfil no Dashboard | até **4** habilidades, piso **15**, **link** para `/people/:id` | FR-075, SC-019 |
| 6 | a equipe composta e a derivada | a organização **declara** "Conecta Fapes" e compõe os squads observados nela; a derivada continua ao lado, com a regra dela | FR-083 |
| 7 | quem vê nomes, tarefas e perfil | quem tem escopo sobre a equipe **e os membros vigentes dela**; os demais veem agregados — confirma os quatro caminhos de `pode_ver_equipe/3` | FR-007, FR-076, US7 c8, US8 c10 |
| 8 | quem age na estrutura | administradora **e** um papel de gestor da equipe, modelado como **concessão a papel organizacional** (*gerir estrutura da equipe*), no molde das concessões de visibilidade; sem segundo tipo de conta | FR-006, FR-080 a FR-082, SC-011 |
| 9 | janela das medidas | **56 dias** por padrão **e** a pessoa pode escolher; o título diz a janela | FR-079, SC-020 |
| 10 | trabalho fora de projeto declarado | issues e PRs **abertos** em repositórios que não estão em nenhum quadro de projeto declarado **+** quadros sem projeto | FR-053, SC-021 |
| 11 | em que história o cartão da subequipe é cobrado | **mover**: o cartão e a porta viram requisito e aceitação da **US7**; o gráfico pequeno, da **US9**; a US6 fica com a composição, o histórico, os membros diretos e o *faz parte de*. A DSM mostrou a dependência para frente — o cenário da US6 pedia artefato de entrega posterior, e não seria avaliável ao fim dela | FR-041, FR-084, US6, US7 c9, US9 c7 |

O que estas decisões deslocam em outras specs está na tabela *Emendas*, no início.

## Decisões do protótipo da aba *Flow per person* (2026-09-08), e as nove que seguem abertas

O protótipo [`team-people.html`](prototipo/team-people.html) traz, na própria tela, quatro
cartões de decisão. Os três primeiros estão **incorporados** a FR-085 a FR-131; o quarto é o que
segue em aberto. Nenhuma das decisões de 2026-09-07 é reaberta.

### Carregadas, já decididas antes desta tela (itens 1 a 6)

| # | Decisão | Data | Onde nesta spec |
|---|---|---|---|
| 1 | a aba vive no endereço: `?tab=people`, com o rótulo dizendo o que responde | 7 Sep | FR-085, FR-113 |
| 2 | *promised = opened in the period; delivered = closed in the period*, sem escopo comprometido | 7 Sep | FR-096, FR-097 |
| 3 | a previsão continua **semanal** qualquer que seja a granulação dos outros gráficos | 7 Sep | FR-098 |
| 4 | duas hipóteses, empilhadas e nunca sobrepostas; percentil de rodada que não concluiu é **nulo** | 8 Sep | FR-123 |
| 5 | nada é apagado: a saída tem data e autor, a linha permanece, e o que a pessoa fez continua contando | 7 Sep | FR-119, FR-131 |
| 6 | a marca do conceito e a sua casa fixa; esta aba usa só `—` e as contagens de uma composição | 8 Sep | FR-121, FR-126 |

### Tomadas pelo desenho, e aprovadas com a tela (itens 7 a 17)

A aprovação da tela aprova estas onze — é o que aprovar uma tela significa nesta casa. A pessoa
mantenedora pode revertê-las; reverter qualquer uma **emenda o requisito** que a carrega.

| # | Decisão do desenho | Onde virou requisito |
|---|---|---|
| 7 | a aba responde **distribuição e história**, não triagem nem profundidade | FR-085, FR-088 |
| 8 | seis colunas, e a quarta medida é **estado**, não valor | FR-119 a FR-123 |
| 9 | "working in progress" não aparece na tabela; a coluna se chama *open now* | FR-090, FR-120 |
| 10 | a frase anti-ranking é **bloco acima dos números**, não colapsa, e vem com quatro recursos | FR-116 a FR-118 |
| 11 | **um** controle de granulação, no cabeçalho da seção — divergência deliberada do Dashboard | FR-115 |
| 12 | **duas** pessoas abertas, e a segunda troca o layout | FR-124 (emenda a FR-087) |
| 13 | três ausências, três tratamentos, e uma quarta: *nothing to forecast* | FR-131, FR-123 |
| 14 | gráfico vazio é **desenhado**, nunca em branco | FR-128 |
| 15 | a coluna da previsão tem fundo hachurado: 27 recusas em 31 linhas são **uma região medida** | FR-123 |
| 16 | a cobertura fica na célula da pessoa, como *N repos observed · denominator unknown* | FR-111, FR-119 |
| 17 | a tela relata a **observação**, nunca a conclusão | FR-125 |

**O desenho também respondeu, ao renderizar, a pergunta 4 da escrita de 2026-09-08** — *a previsão
por pessoa vale a pena se o piso raramente é atingido?* A coluna existe, e a recusa **é**
informação, com a moldura da FR-103. Reverter isto tira a coluna.

### Abertas — cada uma é da pessoa mantenedora (itens 18 a 24, mais duas desta transcrição)

Os números 18 a 24 são os do cartão de decisões da própria tela. Q25 e Q26 nasceram **desta
transcrição**, em 2026-09-10, e não estão na tela.

| # | Pergunta | As leituras | Recomendação do desenho / deste papel | O que muda se a resposta for outra |
|---|---|---|---|---|
| **Q18** | quantas pessoas abertas ao mesmo tempo? | (a) uma, e a comparação fica na tabela; (b) **duas**, com o layout pareado; (c) três, no lugar, como a FR-087 propunha | **(b)** — três gráficos lado a lado dão ~19 rem cada, abaixo do que uma série de oito pontos com rótulos carrega, e três escalas não são comparação | emenda FR-124, SC-022, SC-031, SC-035 |
| **Q19** | *throughput* e *delivered* são os mesmos números — quatro gráficos ou três? | (a) **quatro**, com a redundância escrita na tela; (b) três, com o ritmo dobrado dentro de *Promised × Delivered*; (c) quatro, tirando as barras *opened* do gráfico 2 | **(a)** na primeira versão — derrubar um gráfico pedido nominalmente não é decisão do desenho nem deste papel | emenda FR-127, FR-130, SC-022 |
| **Q20** | as **duas derivações** que a tabela introduz precisam de nome na base antes do código | (a) **declarar as duas** como leituras de `flow.open_work.cumulative` e `flow.throughput.rate`; (b) derrubar as duas colunas | **(a)** — sem elas a tabela mostra um estoque sem direção e um total sem regularidade, e a FR-089 exige a série | **bloqueia o código** de FR-120 e FR-122 (princípio IV). Recusada, as duas colunas saem |
| **Q21** | o cabeçalho da seção conta como "ao lado" da palavra *promised* (FR-063)? | (a) sim, e a palavra não aparece na tabela — o que a tela faz; (b) não: cada gráfico que traz a palavra traz a definição | **(a)** | **bloqueia a aceitação**: a leitura (b) recusa o entregável que a (a) aceita (FR-097, SC-029) |
| **Q22** | cobertura sem denominador (FR-111) | (a) a contagem dizendo que o denominador é desconhecido — o que a tela faz; (b) nenhum número, só a frase da não-comparabilidade; (c) segurar a aba até haver denominador | **(a)** — contagem que nomeia o próprio denominador ausente é mais honesta que silêncio | emenda FR-111, FR-119; a `[NEEDS CLARIFICATION]` da FR-111 só fecha aqui |
| **Q23** | a pessoa vê a **própria** linha quando não alcança a equipe? | `pode_ver_equipe/3` tem quatro caminhos, e nenhum é "é sobre mim"; a 023 FR-012 diz que o trabalho de alguém é visível para a própria pessoa | levar à pessoa mantenedora; se a resposta for sim, é **quinto caminho** no veredito — decisão de acesso, do Arquiteto, não de tela | emenda FR-107 e a fronteira de 058 FR-024 |
| **Q24** | de quem são os quatro gráficos no longo prazo? | (a) desta aba, como está; (b) de `/people/:id`, e a aba aponta; (c) os dois | **(a) agora, (b) depois** — e nunca (c), que são duas telas divergindo por construção | não muda requisito hoje; decide o destino de FR-124 a FR-130 |
| **Q25** | o que acontece ao escolher a **terceira** pessoa: recusar com motivo, ou fechar a mais antiga? | (a) recusar, dizendo o teto; (b) fechar a mais aberta há mais tempo e abrir a nova | **nenhuma** — o protótipo aprovado **não desenhou** este estado, e escolher aqui seria desenhar sem o Design e sem aprovação | **bloqueia a aceitação** do cenário 3 da US11; completa FR-124 |
| **Q26** | o que da **seção 3** do `PROMPT.md` é tela e o que é aparato do protótipo? | os itens 1 a 25 são estrutura de tela; o **item 26** — o cartão *Decisions and open questions* — e as faixas de narração (*what this screen is*), as marcas `real`/`example` e as faixas `screen N` são **aparato da página do protótipo** | **(a)** aparato, e por isso o item 26 **não** virou requisito | se for tela, nasce requisito novo, e a régua do QA passa a cobrar 26 itens contra 25 |

**Três destas bloqueiam, e por motivos diferentes**: Q20 bloqueia o **código** de duas colunas
(nada na tela sem declaração na base); Q21 e Q25 bloqueiam a **aceitação**, porque decidem se um
entregável específico é aceito ou recusado. As demais podem ser respondidas depois sem invalidar o
que já estiver escrito — mas cada resposta diferente da recomendação **emenda** os requisitos
listados na última coluna.

## Impacto

### Telas

| Tela | O que muda |
|---|---|
| `/teams/:id` (`TheBandWeb.TeamsLive.Show`, 2 092 linhas) | vira duas abas com `?tab=`; toda escrita na Estrutura; a lista de membros por evidência é **substituída** pela lista por vínculo; seções novas: papéis, saída, equívoco, subequipes com data e histórico, projetos com período, alerta, fluxo da composta. Pelo princípio X, a divisão em dois LiveViews ou componentes é decisão do `plan.md` |
| `/roles` (`RolesLive.Index`) | sem mudança funcional; passa a ser a segunda entrada do mesmo comando |
| `/teams/:id` da **subequipe** | sem mudança além das abas — é o destino do cartão |

### Módulos (o que a tela precisa e hoje não existe ou está incompleto)

| Módulo | Lacuna encontrada em 2026-09-07 | Requisito |
|---|---|---|
| `EO.Commands.end_allocation/3` | grava só `ended_at`; sem autor nem instante da declaração — fim declarado e fim constatado pela coleta ficam indistinguíveis no vínculo observado | FR-021, FR-022 |
| `EO.Commands.observar_vinculo/2` → `existe_declaracao?/3` | considera declaração só `declared_by_user_id` ou `organizational_role_id` preenchidos; vínculo **observado** com saída ou equívoco tem os dois nulos → **a coleta recria** | FR-026 |
| `EO.Commands.record_team_membership_mistake/5` | já opera sobre o vínculo vigente, observado ou declarado; sem permissão conferida em nenhum chamador | FR-024, FR-006 |
| `TeamsLive.Show` evento `promover` | grava sem conferir `pode_declarar_estrutura` | FR-006 |
| `EO.Commands.compose_teams/4` | `started_at` obrigatório e igual a agora; não aceita data nem desconhecido | FR-037 |
| alteração de papel | não há comando; é encerrar + declarar (premissa) | FR-017 |
| lista de membros por vínculo agregada por pessoa, com subequipes | não existe; `list_team_members/3` é por evidência | FR-008 a FR-012 |
| `WorkItems.TeamWork` para a equipe **inteira** | só recorta por vínculo direto; falta a união distinta pela composição vigente na data do evento | FR-056 |
| consulta do trabalho fora de projeto declarado | não existe | FR-053 |
| números de equipe ∩ projeto | não existem como consulta | FR-051 |
| pipeline falhando **agora** na branch padrão | insumos existem — `source_repository.default_branch` e `collected_verification.head_branch` —, a consulta não | FR-071 |
| issues abertas além do limiar; revisões de código esperando além do limiar | `Quality` e `WorkItems` têm as populações; a contagem por limiar não existe | FR-065 (a), (b) |
| pessoas da equipe **inteira** com tarefas abertas e perfil | `team_open_tasks_by_person/3` e `team_skills_by_person/1` operam sobre uma equipe; falta o conjunto de FR-056 agrupado por subequipe | FR-073 a FR-075 |
| pedido de revisão | **não coletado** | fora de escopo (FR-072) |
| `Tenants.Access.pode_declarar_estrutura/4` | autoriza por `admin` ou escopo `organization` **de conta**; a decisão 8 nomeia admin e o papel com concessão — o caminho por escopo de conta precisa ser **substituído** pelo da concessão (ou a decisão 8 é reaberta); sem isso a spec e o código dizem coisas diferentes sobre quem escreve | FR-006, FR-080 |
| concessão *gerir estrutura da equipe* | não existe: `eo_role_visibility_grants` só confere **visão**; falta o registro por papel + alcance + autor + revogação para **gestão**, e o veredito que o lê | FR-080 a FR-082 |
| `Tenants.Access.pode_ver_equipe/3` | já abre por admin, `team`, `organization` e vínculo vigente — **reusar**, não estender | FR-007, FR-076 |
| janela escolhível nas consultas de fluxo e de medida | `state_changes_by_period/4` já aceita `desde`/`ate`; as demais fixam 56 dias em `@janela_em_dias` — precisam receber a janela | FR-078, FR-079 |
| teto de quatro habilidades e link | `team_skills_by_person/1` devolve a lista inteira; o corte e o critério ficam na tela, ditos | FR-075 |

### Base de conhecimento — antes da tela (princípio IV; 058 FR-021, FR-026e)

Nenhum destes tem `id`; **quem mantém a base nomeia**. Aqui vai o que cada um precisa
dizer.

| O que precisa existir | Natureza | Responde a | Observação |
|---|---|---|---|
| **abertos e fechados por período**, sem acumular — o *Prometido × Entregue* | medida nova | `flow.open_work_balance` (já declarada) | são as duas entradas de `flow.open_work.cumulative` sem o acumulado; limitações a copiar: "fechado é ato da ferramenta", "não há escopo comprometido", "prometido é rótulo, não compromisso" (FR-063) |
| granulação semana/mês/ano em `flow.open_work.cumulative` e na medida acima | emenda de medida | — | hoje `period: weekly`; declarar que mês e ano são **reagrupamento da mesma medida**, as janelas padrão por granulação (8 semanas · 12 meses · todos os anos) e que a janela é **parâmetro dito no título** (decisão 1) |
| a janela como parâmetro em `review.time_to_first_review.duration` e `ci.pipeline_success_rate.ratio` | emenda de medida | — | as limitações citam "56 dias" como fixo; passa a ser padrão escolhível, com a janela no título (decisão 9) |
| o conjunto de membros da **equipe composta** em `flow.open_work.cumulative` e `flow.completion.forecast` | emenda de medida (filtro) | — | FR-056: união distinta pela composição vigente na data do evento; item conta uma vez; "não é soma dos cartões" nas *misinterpretations* |
| o recorte **equipe ∩ projeto** nos números da linha de projeto | emenda de medida (escopo) | — | `review.time_to_first_review.duration` e `ci.pipeline_success_rate.ratio` declaram `team` e `project`, não a interseção; ou se declara, ou a linha de projeto fica sem esses números |
| o **alerta de trabalho fora de projeto declarado** | regra/anomalia (como `structure_antipatterns.yaml`) | decisão: declarar o projeto e ligar a equipe | FR-053, FR-054; consequência: o trabalho não entra em nenhuma linha de projeto nem na taxa do pipeline |
| `github_team_membership_evidence` **v3** | emenda de regra | — | v2 diz "vínculo declarado não é tocado"; precisa dizer que **saída e equívoco em vínculo observado** também bloqueiam a recriação enquanto a observação for contínua (FR-026, FR-027) |
| a necessidade *o que precisa do olhar de quem gerencia hoje* | necessidade de informação | decisão: onde agir hoje — concluir, repassar, declarar, ligar | é o que sustenta a seção *Problemas agora* como um todo; sem ela a seção é dashboard sem necessidade declarada (princípio IV) |
| **limiar de issue aberta — 30 dias** | limiar em regra (como `profile.thresholds`) | a necessidade acima | **confirmado em 2026-09-07**; YAML com o valor e a decisão que apoia, **antes** do cartão (a) |
| **limiar de revisão de código esperando — 7 dias** | limiar em regra | a necessidade acima | **confirmado em 2026-09-07**; YAML com o valor e a decisão que apoia, **antes** do cartão (b) |
| **limiar de parada** | já declarado: `profile.thresholds.stale_open_work.stale_days = 90`, desde a abertura | — | o cartão (d) e a marca de FR-074 **reusam**; "14 d sem mudança de estado" recusado em 2026-09-07 |
| a **concessão *gerir estrutura da equipe*** | declaração da plataforma adjacente à EO — mesmo lugar ontológico de `spo.activity_start_criterion` (módulo YAML da SPO) | decisão: quem pode declarar estrutura numa equipe | a concessão de **visibilidade** (`eo_role_visibility_grants`) **não** está declarada na base hoje — lacuna herdada; declarar as duas juntas fecha a lacuna em vez de dobrá-la. Nome a ser dado por quem mantém a base; a proposta deste papel está no relatório |
| **pipeline falhando agora na branch padrão** | regra/anomalia (estado, não taxa) | a necessidade acima | `ci.pipeline_success_rate.ratio` é taxa sobre a janela; "falhando agora" é a última verificação concluída na branch padrão — outra afirmação, que precisa de nome |
| cartões (e) a (h) | — | — | reusam declarações existentes: 057 FR-021, 055 FR-018, a regra do alerta (linha acima), `structure_antipatterns.yaml`; sem YAML novo além da necessidade |

### A aba *Flow per person* — módulos, base de conhecimento e o que exige outro papel

**Telas**: `lib/the_band_web/live/teams_live/show.ex` ganha a terceira aba — a máquina de abas já
existe (`?tab=structure`, FR-001), e a janela e a granulação já vivem no endereço; a seção *What
each person is on* ganha o caminho para a aba nova (FR-088). A tela da pessoa **não muda**: o
bloco aberto aponta para ela.

**Módulos** — estado verificado em 2026-09-08:

| O que | Estado hoje | Requisitos |
|---|---|---|
| abertos e fechados por período, por pessoa | `WorkItems.state_changes_by_period(tenant, person_id, escala)` **existe** e é exatamente isto, mas tem **aridade 3 e não recebe janela**. A da equipe é `team_state_changes_by_period(tenant, team_id, escala, opts)`. Precisa receber `desde`/`ate`, ou a FR-104 é impossível | FR-093, FR-096, FR-104 |
| série do trabalho aberto por pessoa | **não existe**. `TeamWork.open_tasks_by_person(tenant, team_id, quando, ids)` devolve a **lista** de tarefas abertas num **instante**; chamá-la por instante devolveria a lista inteira 8 vezes para 31 pessoas. Consulta nova, contando por pessoa e por período numa passagem | FR-089, FR-120 |
| previsão por pessoa | `Forecast.monte_carlo/2` serve **sem alteração**; `Forecast.piso/0` já expõe os dois números da recusa | FR-098, FR-099 |
| períodos com ao menos um fechamento | leitura da série de fechamento; **não existe** como consulta, e o denominador reduzido por vínculo depende do período do vínculo | FR-122 |
| cobertura de repositórios por pessoa | **não existe**. `PersonWork.timeline_coverage/2` responde timeline, que estas medidas não usam; `WorkItems.repositories_of_person/2` lista os observados, sem denominador | FR-111 **[NEEDS CLARIFICATION]**, Q22 |
| teto de consultas | há teste-guarda de consultas por render nesta tela (a L38 já reprovou uma versão). Duas pessoas abertas × quatro medidas precisa caber, e o número de consultas MUST NOT crescer com o número de membros | SC-031 |

**Base de conhecimento — antes da tela (princípio IV).** Nenhuma medida nova; **cinco
declarações** faltam:

| Medida | `scope.levels` hoje | O que falta |
|---|---|---|
| `flow.wip.count` | `[sprint, project, team, person]` | nada no escopo. Falta declarar a **substituição** da FR-090 — a fórmula exige `start_date`/`end_date` da tarefa, e o critério de fim não existe (#506) |
| `flow.throughput.rate` | `[sprint, project, team, person]` | nada. A não-aditividade no nível `person` **já está declarada** |
| `flow.open_work.cumulative` | `[team, project]` — **sem `person`** | declarar o nível `person`, com a regra de contagem (uma vez por participante) e a não-aditividade |
| `flow.completion_forecast` | `[team]` — **sem `person`** | declarar o nível `person`, com o piso e a limitação de que a história da equipe **não** substitui a da pessoa (FR-101) |
| as **duas leituras** de FR-120 e FR-122 | não declaradas | a variação entre a primeira e a última amostra da janela, e os períodos com ao menos um fechamento — **Q20**, e é o que bloqueia o código das duas colunas |

**O que exige decisão de outro papel**:

| O quê | De quem | Por quê |
|---|---|---|
| declarar `person` em `flow.open_work.cumulative` e em `flow.completion_forecast` | **Ontologia** | escopo de medida é semântica, e ampliá-lo muda o que a medida afirma |
| onde as duas leituras de FR-120 e FR-122 são declaradas, e sob que id | **Ontologia** | Q20 |
| onde a substituição do WIP é declarada | **Ontologia** | limitação nova em `flow.wip.count`, ou medida com id próprio para "itens abertos por instante" |
| **candidato a ADR**: o que a plataforma chama de WIP enquanto o critério de fim não existe | **Arquiteto** | a substituição já acontece no burn da equipe, e esta aba a espalha para 31 pessoas por equipe. Este papel aponta; não decide, e não abre ADR |
| a consulta nova da série de trabalho aberto por pessoa | **Desenvolvedor** | ver a tabela de módulos |
| quinto caminho no veredito de acesso, se Q23 for "sim" | **Arquiteto** + pessoa mantenedora | acesso, não tela |
| o estado da terceira pessoa aberta | **Design** + pessoa mantenedora | Q25 — não foi desenhado, e implementar sem desenho contraria a decisão de 2026-09-07 |

### Documentos de outros papéis que esta spec afeta, sem alterá-los

- **Spec 057**: FR-011 e FR-029 (emendas), FR-008 (esclarecimento) — pela tabela
  no início.
- **Spec 055**: decisão em aberto 2 da emenda de 2026-09-06 (fechada por FR-024);
  premissa "saída sem data" (substituída por FR-023: recusar); premissa "quem
  administra é quem declara" (ampliada por FR-080: admin **e** papel com concessão).
- **Specs 057 e 058**: premissa "período padrão, sem seletor nesta feature" — o
  seletor chega por FR-078/FR-079, com a janela no título.
- **Spec 045**: ganha um segundo tipo de concessão — por papel, para **gestão** —
  ao lado das concessões de visão por conta; "administrar não é ver" continua de pé,
  e gerir estrutura é uma terceira coisa, nomeada (FR-080).
- **ADR 0008**: a guarda de recriação (item 4 da decisão) precisa cobrir saída e
  equívoco em vínculo observado — FR-026.
- **`docs/backlog/perguntas-do-painel-da-equipe.md`**: P1 a P3 (vazão, WIP,
  concentração) **não** entram aqui; a lista de perguntas continua à espera de
  aprovação.
- **`specs/060-tela-da-equipe/spec-graficos-por-membro.md`**: **superada** por esta spec em
  2026-09-10, quando FR-085 a FR-112, US10 a US12, SC-022 a SC-032 e os *edge cases* foram
  transcritos para cá com as emendas do protótipo aprovado. O arquivo permanece como registro do
  que foi escrito em 2026-09-08 — nada é apagado —, e deixa de ser normativo.
- **`specs/060-tela-da-equipe/tasks.md`**: a linha *"FR-085 a FR-112 … sem tarefa"* continua
  verdadeira, e passa a apontar para esta spec; US10 a US12 seguem **sem tarefa**, e agora com
  requisito escrito.
- **`docs/metrics/indicadores.md`**: se a aba entrar, `flow.wip.count` e `flow.throughput.rate`
  passam a ter leitura no nível `person`, com as limitações copiadas.
- **`docs/backlog/tela-da-equipe-fluxo-por-pessoa.md`**: o item do backlog desta aba, com o
  endereço do protótipo, o prompt e o registro das decisões.
