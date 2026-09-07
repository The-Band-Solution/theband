# Feature Specification: A tela da equipe — quem está nela, e como ela está

**Feature Branch**: `feat/060-tela-da-equipe`

**Created**: 2026-09-07

**Status**: Draft — escrita pelo papel de Product Owner a pedido da pessoa
mantenedora em 2026-09-07, sobre o protótipo aprovado no mesmo dia
([`prototipo/README.md`](prototipo/README.md)). As **oito decisões** registradas
ali estão incorporadas e **não são reabertas** aqui. O que ficou em aberto está na
seção *Perguntas abertas*, e são três.

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
| *Teams inside this one* — linha por subequipe, sem total, sem gráfico | 057 US2 | **Dashboard**: cartão por subequipe **e** a tabela por medida | reorganiza; ganha o cartão como porta |
| burn, previsão, *what each person is on* (só equipe simples) | 057 US4–US6 | **Dashboard** da equipe simples, como está; a composta passa a ter fluxo próprio | mantém; **emenda 057 FR-011** |
| *Structure* — faz parte de / contém / *Declare inside* / *remove from here* | 055 US3 | **Estrutura**: seção *Subequipes*, com data, histórico e composição de equipe **existente** | reorganiza; ganha composição com data e de equipe existente |
| tabela *members* por evidência (acesso, observado em, última observação) | 021/043 | **Estrutura**: lista por **vínculo** — papel, origem, desde, subequipes, ações por linha | **substitui** |
| *Source and declaration disagree* | 055 FR-012 | **Estrutura**, junto da lista | mantém |
| *observed members without a declared role* — formulário em lote | 043 US3, #317 | **Estrutura**: ação *declarar papel* na linha da pessoa | reorganiza — ver Perguntas abertas, Q3 |
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
| **057 FR-011** | a tela da equipe composta MUST NOT apresentar gráficos | a equipe composta apresenta o **fluxo da equipe inteira** — burn, Prometido × Entregue, Monte Carlo — e um gráfico pequeno por cartão de subequipe; a tabela por subequipe continua sem gráfico | FR-058, FR-059 |
| **057 FR-029** | a tela MUST declarar que não há escopo comprometido | continua valendo, e vale **também** para *Prometido × Entregue*: "prometido" é rótulo para *aberto no período*, definido junto do título, e MUST NOT ser lido como compromisso | FR-063 |
| **057 FR-008** (esclarecimento, não emenda) | MUST NOT somar as linhas de subequipe | continua; o fluxo da equipe inteira é medido sobre o **conjunto distinto** de pessoas e itens, e a tela diz que não é soma | FR-060 |
| **055, decisão em aberto 2** da emenda de 2026-09-06 | equívoco em vínculo observado: permitir ou não | **permitido** — decisão de 2026-09-07; a coleta não recria | FR-024 a FR-028 |

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
6. **Given** uma conta do tenant **sem** escopo para declarar estrutura na
   organização desta equipe, **When** abre a aba, **Then** lê a lista inteira e
   **nenhuma** ação de escrita é apresentada.
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
diretos. No Dashboard, cada subequipe é um cartão, e o cartão é a porta para a
página dela.

**Why this priority**: P2 porque as cinco histórias anteriores entregam valor numa
equipe simples. A composição é o que permite perguntar da organização inteira, e é
o segundo item do foco declarado.

**Independent Test**: compor duas equipes existentes numa terceira, uma com data e
uma sem; tentar fechar um ciclo de comprimento 3 e ser recusado com o caminho;
encerrar uma composição e conferir que a subequipe continua existindo e a linha foi
para o histórico; clicar no cartão e chegar a `/teams/:id` da subequipe.

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
6. **Given** o Dashboard de uma equipe composta, **When** quem lê clica no cartão de
   uma subequipe **ou** no gráfico pequeno dele, **Then** abre o Dashboard daquela
   subequipe.
7. **Given** uma equipe com **uma** composição vigente, **When** a tela abre,
   **Then** ela segue como equipe simples no Dashboard (057) e a Estrutura mostra a
   composição.

---

### User Story 7 - O Dashboard reorganizado: medidas com composição, projetos declarados, e o que está fora deles (Priority: P2)

Quem gerencia abre `/teams/:id` e cai no Dashboard. Vê, se a equipe é composta, um
cartão por subequipe com as mesmas medidas e um gráfico pequeno, **nunca um total**,
e a razão de não somar. Cada medida diz sobre quem foi calculada. Os projetos em
que a equipe trabalha são **os declarados**, com período e com as subequipes que
têm vínculo próprio ao mesmo projeto. Trabalho em repositório ou quadro que não
pertence a nenhum projeto declarado da equipe aparece como **alerta** — onde, quem,
quanto —, e nunca como projeto.

**Why this priority**: é a reorganização que as cinco P1 já pedem para existir, e o
que dá lugar ao fluxo (US8). O alerta é o que torna visível a diferença entre
"a plataforma não sabe" e "a organização não declarou".

**Independent Test**: abrir `/teams/:id` sem `?tab` e cair no Dashboard; abrir
`?tab=structure` e cair na Estrutura; recarregar e continuar na mesma aba; numa
equipe composta, varrer a tela e não encontrar célula de total; conferir que 100%
das medidas trazem *N — X observados sem papel, Y declarados*; criar trabalho num
repositório não ligado a projeto da equipe e ver o alerta nascer — e sumir ao
declarar o vínculo.

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
5. **Given** itens de trabalho de membros da equipe em repositório ou quadro que
   não está ligado a nenhum projeto declarado da equipe, **When** o Dashboard abre,
   **Then** aparece um **alerta** com onde (repositório ou quadro), quem e quanto —
   e o alerta **não** é uma linha de projeto.
6. **Given** o alerta, **When** a organização declara o projeto e liga a equipe a
   ele, **Then** o alerta deixa de existir e o trabalho passa a contar na linha do
   projeto.
7. **Given** uma subequipe sem trabalho no período, **When** o cartão é exibido,
   **Then** a ausência é dita em texto, nunca zero (057 FR-012).
8. **Given** uma conta sem escopo sobre a equipe, **When** o alerta é exibido,
   **Then** ela lê onde e quanto, e **não** lê quem — a quebra por pessoa nomeada
   segue a fronteira de 058 FR-024.

---

### User Story 8 - O fluxo da equipe inteira: burn, Prometido × Entregue, Monte Carlo (Priority: P3)

No Dashboard da equipe composta, quem gerencia vê o burn-up/burn-down da equipe
**inteira** por semana, mês ou ano; *Prometido × Entregue* — abertos e levados a
fechamento em cada período —; e a previsão de Monte Carlo, semanal, com duas
hipóteses e a confiança de cada uma. Trocar a granulação reagrupa os mesmos itens;
não muda a medida.

**Why this priority**: P3 porque é o maior salto de leitura e o mais fácil de ler
errado — e porque depende de as cinco P1 estarem certas: o conjunto de membros é o
que decide o que entra nas curvas. Pedido da pessoa mantenedora em 2026-09-07,
emendando 057 FR-011.

**Independent Test**: com uma série conhecida, conferir que a distância entre as
curvas em qualquer ponto é o número de itens em aberto naquele ponto, nas três
granulações; que o total de abertos e de fechados na janela é o mesmo em semana,
mês e ano; que a previsão é idêntica em duas consultas; e que abaixo do piso nenhuma
previsão aparece.

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
- **Saída sem data.** Ver Perguntas abertas, Q2.
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
- **Ano sobre janela de oito semanas.** Ver Perguntas abertas, Q1.
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
- **FR-006**: Toda ação de escrita MUST exigir que a conta possa declarar estrutura
  na organização da equipe — a mesma pergunta que hoje autoriza compor (`admin` do
  tenant, ou escopo `organization` nesse alvo). Quem não pode MUST NOT ver a ação,
  **e** a tentativa por evento MUST ser recusada — esconder o botão não é
  autorização (055 FR-011). *Isto inclui declarar papel, que hoje não confere
  permissão nenhuma antes de gravar — ver Impacto.*
- **FR-007**: A lista de membros e a lista de subequipes são **estrutura declarada**
  (058 FR-007a) e MUST ser legíveis por qualquer conta do tenant. Números sobre o
  trabalho de pessoa **nomeada** — o *quem* do alerta de trabalho fora de projeto
  (FR-053), a quebra por pessoa da espera por revisão — MUST seguir a fronteira de
  058 FR-024 e FR-024a.

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
- **FR-014**: Pessoa que a origem mostra e que já tem vínculo observado MUST NOT ter
  uma segunda seção "aguardando confirmação": o que falta nela é o papel, e a ação
  está na linha (FR-015).

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
- **FR-023**: Data no futuro MUST ser recusada. Saída em vínculo já encerrado MUST
  ser recusada sem reescrever a data original.

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
- **FR-041**: No Dashboard da equipe composta, cada subequipe MUST ser um **cartão**
  com as mesmas medidas da tabela e um gráfico pequeno, e clicar no cartão **ou** no
  gráfico MUST abrir o Dashboard daquela subequipe (057 FR-010).
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
- **FR-053**: O Dashboard MUST apresentar um **alerta** quando houver itens de
  trabalho, na janela, de membros da equipe (no período do vínculo) cujo repositório
  **ou** quadro não está ligado a **nenhum** projeto declarado da equipe. O alerta
  MUST dizer **onde** (repositório ou quadro, e que ele não está ligado a projeto),
  **quem** (sob a fronteira de FR-007) e **quanto** (abertos, fechados na janela).
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
  mês e ano**. Trocar a granulação MUST reagrupar os **mesmos itens**, e MUST NOT
  mudar a medida: a soma de abertos e a de fechados na janela MUST ser igual nas
  três. *A janela de cada granulação está em aberto — Q1.*
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
  FR-061 — as amostras são semanas. A tela MUST dizer isso.

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
  granulações; a soma de abertos e a de fechados na janela é **igual** em semana,
  mês e ano.
- **SC-010**: **0** projetos no Dashboard sem vínculo declarado; **100%** do trabalho
  em repositório/quadro fora de projeto declarado aparece no alerta e em **nenhuma**
  linha de projeto.
- **SC-011**: Uma conta sem escopo na organização lê as duas abas e encontra **0**
  ações de escrita; **100%** das tentativas por evento dessa conta são recusadas
  (055 FR-011).
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

## Fora de escopo

- **Rollup de competências pela hierarquia** (#397). Depende da composição; é outra
  entrega (055).
- **"Aceitar como trabalho não planejado."** O protótipo sugere essa saída para o
  alerta de FR-053. Não há conceito na base para uma aceitação assim, e esta spec
  **não** o cria: o alerta permanece até haver vínculo declarado. A lacuna fica
  registrada aqui, sem nome.
- **Seletor livre de período.** A granulação de FR-061 não é seletor de período
  (057, L86). Ver Q1 sobre a janela por granulação.
- **Critério de término declarado** (#506). "Fechado" continua sendo o ato da
  ferramenta, e "done" no protótipo é rótulo para isso (FR-062).
- **Mudanças em `/roles`.** As concessões de visibilidade continuam lá; esta spec só
  chama o comando de criar/renomear/ocultar de outro lugar (FR-030).
- **Mover pessoa entre equipes** como ato único: é saída numa e vínculo noutra.
- **Equipe derivada** (`github.default_team`): segue a 055 e a ADR 0008; nada aqui é
  específico dela.
- **Exportação, notificação, importação de planilha** (055).
- **Alterar o detalhe da equipe simples** da 057 além de pô-lo dentro da aba
  Dashboard.

## Premissas

Carregadas do protótipo (`prototipo/README.md`) e desta escrita, até serem
contestadas:

- **Mês e ano só mudam a granulação** do burn e do *Prometido × Entregue*; o Monte
  Carlo continua semanal (README). Sobre a **janela** de cada granulação, ver Q1.
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
- **Janela padrão: 8 semanas**, sem seletor (057).
- **Quem administra é quem pode declarar estrutura na organização** — `admin` do
  tenant ou escopo `organization` nesse alvo. Esta spec não cria papel nem escopo
  novo (055).
- **Onde o protótipo diverge desta spec**: (a) o protótipo mostra o alerta com nomes
  para qualquer leitor — FR-007 restringe o *quem*; (b) o protótipo sugere "aceitar
  como não planejado" — fora de escopo; (c) o protótipo não mostra o autor da saída
  em vínculo observado encerrado pela coleta — FR-022 exige distinguir. A spec vence
  nos três.

## Perguntas abertas

Só onde há duas leituras materiais que o dia de hoje não decidiu.

- **Q1 — A janela por granulação** [NEEDS CLARIFICATION]. Com a janela fixa de 8
  semanas, a granulação *mês* produz dois ou três pontos e *ano* produz **um**. Duas
  leituras: (a) a janela é sempre 8 semanas e mês/ano só reagrupam — o gráfico anual
  é uma barra, e a premissa do README está literalmente cumprida; (b) a janela é
  **função da granulação**, fixa por granulação — por exemplo 8 semanas, 12 meses,
  todos os anos coletados —, o que mantém a objeção da 057 ao seletor livre (não há
  período escolhido pela pessoa) e faz mês e ano informarem. **Recomendação do
  papel**: (b), com as três janelas declaradas no YAML da medida.
- **Q2 — Saída sem data** [NEEDS CLARIFICATION]. A premissa da 055 diz: *hoje, marcada
  como presumida*. O vínculo não tem campo de "presumida", e a doutrina da base é
  *vazio é desconhecido, nunca hoje*. Duas leituras: (a) recusar sem data — o
  formulário exige a data, sem valor pré-preenchido; (b) cumprir a 055 e criar a
  marca de data presumida no vínculo. **Recomendação do papel**: (a); a 055 é
  corrigida por quem a mantém.
- **Q3 — O formulário em lote de declarar papel** [NEEDS CLARIFICATION]. A tela de
  hoje tem *Declare all roles*; o protótipo declara na linha. O princípio X pede a
  ação num lugar só. Duas leituras: (a) remover o lote — a ação vive na linha; (b)
  manter o lote como atalho na Estrutura, chamando o mesmo comando. **Recomendação
  do papel**: (a); com 17 pessoas sem papel na equipe de referência, o lote é
  conveniência real, e por isso a pergunta é feita em vez de decidida.

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

### Base de conhecimento — antes da tela (princípio IV; 058 FR-021, FR-026e)

Nenhum destes tem `id`; **quem mantém a base nomeia**. Aqui vai o que cada um precisa
dizer.

| O que precisa existir | Natureza | Responde a | Observação |
|---|---|---|---|
| **abertos e fechados por período**, sem acumular — o *Prometido × Entregue* | medida nova | `flow.open_work_balance` (já declarada) | são as duas entradas de `flow.open_work.cumulative` sem o acumulado; limitações a copiar: "fechado é ato da ferramenta", "não há escopo comprometido", "prometido é rótulo, não compromisso" (FR-063) |
| granulação semana/mês/ano em `flow.open_work.cumulative` e na medida acima | emenda de medida | — | hoje `period: weekly`; declarar que mês e ano são **reagrupamento da mesma medida**, e as janelas de Q1 |
| o conjunto de membros da **equipe composta** em `flow.open_work.cumulative` e `flow.completion.forecast` | emenda de medida (filtro) | — | FR-056: união distinta pela composição vigente na data do evento; item conta uma vez; "não é soma dos cartões" nas *misinterpretations* |
| o recorte **equipe ∩ projeto** nos números da linha de projeto | emenda de medida (escopo) | — | `review.time_to_first_review.duration` e `ci.pipeline_success_rate.ratio` declaram `team` e `project`, não a interseção; ou se declara, ou a linha de projeto fica sem esses números |
| o **alerta de trabalho fora de projeto declarado** | regra/anomalia (como `structure_antipatterns.yaml`) | decisão: declarar o projeto e ligar a equipe | FR-053, FR-054; consequência: o trabalho não entra em nenhuma linha de projeto nem na taxa do pipeline |
| `github_team_membership_evidence` **v3** | emenda de regra | — | v2 diz "vínculo declarado não é tocado"; precisa dizer que **saída e equívoco em vínculo observado** também bloqueiam a recriação enquanto a observação for contínua (FR-026, FR-027) |

### Documentos de outros papéis que esta spec afeta, sem alterá-los

- **Spec 057**: FR-011 e FR-029 (emendas), FR-008 (esclarecimento) — pela tabela
  no início.
- **Spec 055**: decisão em aberto 2 da emenda de 2026-09-06 (fechada por FR-024);
  premissa "saída sem data" (Q2).
- **ADR 0008**: a guarda de recriação (item 4 da decisão) precisa cobrir saída e
  equívoco em vínculo observado — FR-026.
- **`docs/backlog/perguntas-do-painel-da-equipe.md`**: P1 a P3 (vazão, WIP,
  concentração) **não** entram aqui; a lista de perguntas continua à espera de
  aprovação.
