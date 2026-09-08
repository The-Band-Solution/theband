# Extensão da 060 — os quatro gráficos de fluxo, por membro da equipe

**Esta é uma EXTENSÃO da feature 060, não uma spec nova.** A pessoa mantenedora não
pediu feature: pediu **acrescentar** à tela que já existe. Tudo aqui se prende a
[`spec.md`](spec.md) — as user stories continuam a numeração dela (US10 a US12), os
requisitos continuam a dela (FR-085 em diante, porque ela termina em FR-084), e os
critérios de sucesso continuam a dela (SC-022 em diante, porque ela termina em
SC-021). Nada aqui reabre decisão da 060 nem das 055, 057 e 058.

**Feature Branch**: `feat/060-tela-da-equipe` (a mesma)

**Created**: 2026-09-08

**Status**: Draft — escrita pelo papel de Product Owner a pedido da pessoa
mantenedora em 2026-09-08. **Sete perguntas seguem abertas** e estão na seção
*Perguntas abertas*; duas delas — a leitura da FR-063 e a ordenação por medida —
**bloqueiam a aceitação**, não o começo.

**Input** — pedido da pessoa mantenedora, textual, em 2026-09-08:

> "Especifique colocar na tela da equipe para cada membro os gráficos: Working in
> progress, prometido x realizado, throughput e monte carlo."

**Protótipo**: **não existe ainda para esta extensão.** A 060 tem protótipo aprovado
em 2026-09-07 — [`prototipo/README.md`](prototipo/README.md), prompt em
[`prototipo/PROMPT.md`](prototipo/PROMPT.md), artifact
`https://claude.ai/code/artifact/0be1668f-3afa-4668-bfb2-c77fae11d941` — e ele **não
contempla** a quebra de fluxo por membro. Ver *O desenho vem antes do código*: esta
spec não vai a `/speckit-plan` antes de o protótipo desta extensão ser aprovado e
republicado no mesmo endereço.

---

## O que esta extensão resolve

Hoje o Dashboard de `/teams/:id` responde **como a equipe está fluindo**: burn-up/
burn-down, *Promised × Delivered*, e o *Delivery forecast* de Monte Carlo — os três
sobre o conjunto distinto de pessoas e itens da equipe (FR-058 a FR-064), com a
janela sempre escrita no título (FR-078). E responde **o que está na mão de cada
pessoa agora**: a seção *What each person is on* lista, por membro, cada tarefa
aberta e há quantos dias (FR-019 a FR-021).

O que ele **não** responde: como o fluxo de **cada membro** se comporta ao longo da
mesma janela. Uma lista de tarefas abertas é um retrato de agora; não diz se o
trabalho aberto daquela pessoa vem crescendo, quanto ela levou a fechamento em cada
período, nem se há história suficiente para prever o que está na mão dela.

**A dificuldade não é o dado — é a tela.** Quatro gráficos por pessoa, numa equipe de
31 membros (LEDS - ConectaFapes existe e tem esse tamanho), são **124 gráficos numa
página**. Nenhuma decisão se toma olhando 124 gráficos, e a página que os tenta
mostrar não é uma página: é um arquivo. A extensão inteira gira em torno do recorte.

### E há uma dificuldade que não é de tela

Medida por pessoa, exibida ao lado da medida de outra pessoa, é a porta para ranking
individual. A plataforma tem doutrina explícita contra apresentar pessoa como número
de produtividade — está escrita na própria tela hoje, no rodapé da seção de
habilidades: *"Read the other way round, this becomes a ranking of people, which it
is not and cannot support."* Esta extensão coloca quatro números por pessoa lado a
lado, o que é exatamente a leitura contra a qual aquele texto avisa. Por isso a US12
existe, e por isso ela vai **antes** da US11 na ordem de entrega.

---

## Decisão de recorte — onde os gráficos vivem

**Recomendação: uma terceira aba em `/teams/:id`, `?tab=people`, cujo conteúdo padrão
é uma tabela comparativa de números — e os quatro gráficos de uma pessoa abrem sob
demanda, dentro dela.**

Três alternativas foram consideradas:

| Alternativa | Por que não |
|---|---|
| **seção nova no Dashboard** | o Dashboard já responde *como a equipe está fluindo* e *o que está na mão de cada um*. Acrescentar *como cada um flui na janela* faz a tela responder três perguntas, e o princípio X da constituição decide isto: tela faz uma coisa. Além disso a seção ficaria abaixo de *Problemas agora*, de *Projetos* e dos três gráficos da equipe — 124 gráficos depois de tudo o que já está lá |
| **só a tela da pessoa (`/people/:id`)** | ela **já existe** e já tem `closed_by_month/2`, `open_age_buckets/2`, `lead_time/2` e `state_changes_by_period/3`. É a casa certa da leitura **profunda** de uma pessoa, e continua sendo. Mas ela não permite a única coisa que a tela da equipe acrescenta: **comparar membros sob a mesma janela**. Trinta e uma abas abertas não são uma comparação |
| **seletor de uma pessoa por vez no Dashboard** | resolve o problema de tela e apaga a comparação, que é a razão de a seção existir na tela da equipe |

E a razão de a aba escolhida ser **tabela por padrão, gráfico sob demanda**: a 057
FR-011 proibia gráficos na tela da equipe composta, e a 060 FR-058 emendou essa
proibição — mas registrando o que ela protegia: *"comparação em números alinhados,
sem gráfico, continua valendo para a **tabela** por subequipe"*. Aqui é o mesmo
fenômeno com pessoas no lugar de subequipes. **Comparar são números alinhados;
entender é o gráfico de um.** A tabela compara 31 pessoas em quatro colunas; o
gráfico explica uma.

A aba fica no endereço pela mesma razão da FR-001: um link cai onde aponta.

---

## User Scenarios & Testing

### User Story 10 - O fluxo de cada membro, comparável na mesma janela (Priority: P3)

Quem alcança a equipe abre a aba *Flow per person* e vê uma linha por membro, com
quatro colunas na **mesma janela** dos gráficos do Dashboard: o trabalho aberto agora
e a direção da série, os abertos e os fechados na janela, a vazão por período, e o
estado da previsão. Sem gráfico nenhuma linha, sem ordenação por medida, e com a
janela escrita no título.

**Why this priority**: P3, a mesma da US9, e **depois** dela. As definições (FR-062),
a ressalva (FR-063), a granulação e a janela no endereço (FR-078, FR-079) nascem na
US9; construir isto antes obrigaria a inventá-las duas vezes. E o conjunto de membros
que alimenta as linhas é o que as cinco P1 decidem.

**Independent Test**: com uma equipe de série conhecida, conferir que a soma da
coluna *closed in window* das linhas é **maior ou igual** à vazão da equipe no mesmo
período (maior quando há item com dois responsáveis), que trocar a granulação ou a
janela no endereço muda **todas** as linhas ao mesmo tempo, e que nenhuma coluna de
medida ordena a tabela por padrão.

**Acceptance Scenarios**:

1. **Given** uma equipe com membros vigentes, **When** a aba abre, **Then** há uma
   linha por membro do **mesmo conjunto** que alimenta o Dashboard (FR-057), a janela
   mostrada está no título da seção, e nenhuma linha traz gráfico.
2. **Given** a granulação em semana, **When** quem lê troca para mês no endereço,
   **Then** todas as linhas reagrupam sobre a mesma janela, e o título diz a janela
   nova quando a troca de granulação a troca (FR-078).
3. **Given** um item com **duas** pessoas responsáveis da mesma equipe, **When** as
   linhas são lidas, **Then** o item conta **uma vez para cada** pessoa, e a seção
   declara que somar as linhas não dá a vazão da equipe.
4. **Given** a tabela recém-aberta, **When** a ordem é observada, **Then** ela é por
   papel declarado e depois por nome — **nunca** por uma das quatro medidas.
5. **Given** uma pessoa cujo vínculo começou dentro da janela, **When** a linha dela é
   lida, **Then** a data de início aparece (ou *start date unknown*, 057 FR-006), e o
   texto diz que menos períodos com dado é história mais curta dentro da mesma
   janela, e não menos trabalho.

---

### User Story 11 - Os quatro gráficos de uma pessoa, abertos sob demanda (Priority: P3)

Quem lê escolhe uma linha e os quatro gráficos daquela pessoa abrem ali mesmo: a
série do trabalho aberto, *Promised × Delivered* por período, a vazão por período, e
a previsão de Monte Carlo — ou a recusa dela. Os quatro sobre a mesma janela dos
gráficos da equipe. O bloco aberto leva a `/people/:id` para a leitura profunda.

**Why this priority**: P3, e é **o pedido literal** da pessoa mantenedora. Vai depois
da US12 e não antes: sem a ausência dita por pessoa, a primeira versão destes
gráficos mostra branco para a maioria das pessoas de uma equipe real, e branco é a
afirmação que a plataforma recusa.

**Independent Test**: com uma pessoa de série conhecida, conferir que a distância da
série de trabalho aberto em qualquer instante é o número de itens dela abertos ali,
que a soma de abertos e a de fechados na janela são iguais nas três granulações, que
a previsão é idêntica em duas consultas, e que abrir três pessoas não passa do teto de
consultas da página.

**Acceptance Scenarios**:

1. **Given** a tabela, **When** quem lê escolhe uma pessoa, **Then** os quatro
   gráficos daquela pessoa abrem **no lugar**, sem trocar de tela, e o bloco traz o
   caminho para `/people/:id`.
2. **Given** três pessoas já abertas, **When** quem lê escolhe uma quarta, **Then** o
   comportamento é o definido pela FR-087 — e ele está entre as perguntas abertas.
3. **Given** o bloco de uma pessoa aberto, **When** *Promised × Delivered* dela é
   lido, **Then** a definição operacional e a declaração de que **não há escopo
   comprometido** estão dentro do bloco, junto do título do gráfico (FR-097).
4. **Given** a previsão de uma pessoa acima do piso, **When** é exibida, **Then** é
   **semanal** independentemente da granulação escolhida para os outros gráficos, com
   as duas hipóteses e a proporção de rodadas que não concluíram (FR-064, FR-098).
5. **Given** a mesma consulta duas vezes, **When** os quatro gráficos são comparados,
   **Then** são idênticos (057 FR-036).

---

### User Story 12 - A ausência dita, pessoa por pessoa (Priority: P3)

Numa equipe real, a maioria das pessoas **não** alcança o piso da previsão, e algumas
não fecharam nada na janela. A tela diz isso por pessoa, com o que falta, e nunca com
branco, zero ou coluna escondida. Acima da tabela, quantas pessoas têm previsão e de
quantas — para que a maioria de recusas se leia como estado do registro, e não como
defeito da tela.

**Why this priority**: P3, e **antes da US11** na ordem de entrega. `Forecast.
monte_carlo/2` exige 6 períodos de história e 10 itens fechados; para a equipe isso é
comum, para uma pessoa muitas vezes não. Uma tela que mostra 27 espaços vazios em 31 é
pior do que nenhuma tela: cada vazio é uma afirmação sobre uma pessoa que a plataforma
não fez.

**Independent Test**: com uma equipe em que uma pessoa está acima do piso e as outras
abaixo, conferir que cada pessoa abaixo traz os dois números que ela tem e os dois
exigidos, que nenhuma célula fica vazia, e que a contagem acima da tabela diz *1 de N*.

**Acceptance Scenarios**:

1. **Given** uma pessoa com 3 semanas de história e 4 fechadas, **When** a previsão
   dela é lida, **Then** nenhuma previsão aparece e a tela diz que faltam 6 semanas e
   10 fechadas, contra as 3 e as 4 que ela tem — a mesma forma da recusa da equipe
   (057 FR-034).
2. **Given** a mesma pessoa, **When** o texto da recusa é lido, **Then** ele diz que é
   **lacuna do registro observado**, e nunca afirmação sobre a pessoa — a mesma
   gramática de FR-023.
3. **Given** uma pessoa sem nenhum item fechado na janela, **When** a vazão dela é
   lida, **Then** a célula diz *nenhum item fechado nesta janela*, e **não** `0`.
4. **Given** uma pessoa sem item aberto, **When** a série de trabalho aberto é lida,
   **Then** ela diz *nenhuma tarefa aberta designada* — a pessoa **não** sai da tabela
   (FR-021).
5. **Given** uma equipe em que 4 de 31 pessoas alcançam o piso, **When** a aba abre,
   **Then** acima da tabela está *forecast available for 4 of 31 people*, e o texto
   diz que o piso é do método e não das pessoas.
6. **Given** uma pessoa cujos repositórios não foram coletados, **When** os números
   dela são lidos, **Then** a cobertura aparece **junto** dos números, e o texto diz
   que número baixo ali é lacuna de coleta.

---

### Edge Cases

- **Item com dois responsáveis, ambos da equipe.** Conta **uma vez para cada** na
  tabela por pessoa; conta **uma vez** nos gráficos da equipe (`DISTINCT`, FR-060). É
  por isso que somar as linhas não dá o número da equipe, e é por isso que a tela diz.
- **Item com dois responsáveis, um de fora da equipe.** A linha da pessoa de dentro
  conta o item; a de fora não tem linha. A tela **não** declara que existe alguém de
  fora — isso é vínculo, não item.
- **Pessoa que entrou no meio da janela.** Mesma janela, história mais curta. A data de
  início aparece; sem ela, *start date unknown* (057 FR-006).
- **Pessoa que saiu com data declarada.** O que ela fez continua contando na janela
  (US3), e a linha dela diz a saída. Ela **não** desaparece da tabela retroativamente.
- **Pessoa em duas subequipes da mesma equipe composta.** Uma linha só na aba da equipe
  composta — a aba é por pessoa, não por vínculo.
- **Item reaberto.** Aparece como abertura no período em que reabriu e mantém o
  fechamento anterior, nos quatro gráficos — a limitação já declarada em
  `flow.open_work.cumulative` e em `flow.wip.count`.
- **Granulação ano com um só período.** Um ponto não é uma série. A tela apresenta o
  ponto e diz que uma série de um ponto não descreve fluxo — a limitação já declarada
  em `flow.wip.count`: *"um valor isolado não descreve o sprint"*.
- **Equipe com exatamente um membro vigente.** A tabela tem uma linha, e ela **é** a
  equipe com outro rótulo. A mesma fronteira de 058 FR-025 vale: quem não alcança a
  equipe não vê a linha.
- **Equipe sem membro vigente.** A tabela não existe, e a tela diz *no one has a
  declared membership in this team right now* — o mesmo texto que a seção do Dashboard
  já usa.
- **Pessoa cujo trabalho está todo em repositório não coletado.** Quatro números baixos
  por uma razão que não é o trabalho dela. É o caso que a FR-110 e a FR-111 existem
  para cobrir, e é o mais perigoso da extensão inteira.

---

## Requirements

### Onde os gráficos vivem

- **FR-085**: `/teams/:id` MUST ganhar uma **terceira aba**, com o valor `people` no
  mesmo parâmetro de aba da FR-001, e MUST NOT ganhar rota nova. A aba MUST ser
  nomeada pelo que responde — o fluxo de cada pessoa —, e não por "métricas".
- **FR-086**: O conteúdo **padrão** da aba MUST ser uma **tabela**, uma linha por
  membro do mesmo conjunto que alimenta o Dashboard (FR-057), **sem gráfico em nenhuma
  linha**. O que a 057 FR-011 protegia — comparação em números alinhados — vale aqui
  com pessoas no lugar de subequipes.
- **FR-087**: Os quatro gráficos de uma pessoa MUST abrir **sob demanda**, no lugar, e
  o número máximo de pessoas abertas ao mesmo tempo MUST ser limitado — *proposto:
  três*. O bloco aberto MUST levar a `/people/:id`. *(O número está entre as perguntas
  abertas; o limite não está.)*
- **FR-088**: A seção *What each person is on* do Dashboard MUST permanecer onde está,
  MUST ganhar o caminho para a aba nova, e as duas MUST NOT ser fundidas. A do
  Dashboard responde **o que está na mão de alguém agora**; a aba nova responde **como
  o fluxo de cada um se comportou na janela**. A aba MUST NOT repetir a lista de
  tarefas abertas.

### Working in progress — a definição

- **FR-089**: *Working in progress* por pessoa MUST ser a **série** do número de itens
  designados a ela e abertos em cada instante amostrado da janela, na granulação em
  uso — e MUST NOT ser um número solto. O valor de agora MAY aparecer como o último
  ponto, rotulado com o instante em que foi amostrado.

  *Das três leituras possíveis — o número de agora, a série, ou o limite de WIP do
  quadro — a base já escolheu a segunda: `flow.wip.count` declara `period: weekly` e a
  limitação "o painel da equipe da issue #506 lê a série, e nunca um valor solto". Um
  valor solto é a má leitura que a própria medida enumera.*
- **FR-090**: A tela MUST declarar que *aberto* aqui é `external_created_at` presente e
  `external_closed_at` nulo no instante observado, e que isso **não é**
  `flow.wip.count` como a base a define: aquela fórmula exige `start_date` e `end_date`
  da tarefa executada, o **critério de fim não existe** (limitação declarada na própria
  medida, issue #506), e o tempo aqui conta de quando o **item** foi aberto, não de
  quando a pessoa o assumiu — a origem não registra isso.

  *Apresentar esta série sob o nome `flow.wip.count` seria reivindicar uma medida que a
  coleta não sustenta. A substituição é legítima e é a mesma que o burn da equipe já
  faz; o que não é legítimo é não dizer.*
- **FR-091**: A plataforma MUST NOT apresentar **limite de WIP**. Não há limite
  declarado na coleta e não há escopo comprometido (057 FR-029, FR-063). A tela MUST
  NOT desenhar linha de limiar que insinue um.
- **FR-092**: As más interpretações que `flow.wip.count` declara MUST aparecer junto da
  série, **copiadas e não resumidas** — em especial: WIP baixo não significa fluxo
  saudável; WIP alto não é sinônimo de produtividade; e comparar entre pessoas sem
  normalizar transforma a medida em outra coisa.

### Throughput — a definição

- **FR-093**: *Throughput* por pessoa MUST ser a contagem de itens designados a ela com
  `external_closed_at` dentro de cada período da janela, na granulação em uso — o nível
  **person** de `flow.throughput.rate`, que a medida já declara em `scope.levels`.
- **FR-094**: Item com **duas pessoas responsáveis** MUST contar **uma vez para cada**
  aqui, e a seção MUST declarar que somar as linhas **não** dá a vazão da equipe: a da
  equipe é medida sobre o conjunto distinto (FR-060), e não derivada destas linhas.

  *É a regra da 057 — "aparece uma vez para cada" — e a limitação que
  `flow.throughput.rate` já declara: "no nível person, a mesma tarefa aparece uma vez
  por participante, e a soma dos níveis person não é igual ao nível sprint". A unidade
  desta seção é a pessoa, então vale a regra da pessoa. A regra da equipe continua
  valendo onde a unidade é a equipe, e as duas nunca se somam.*
- **FR-095**: *Fechado* MUST ser declarado como `external_closed_at` — ato da
  ferramenta, e não coluna de quadro nem critério de término declarado (FR-062, 057
  FR-030). E a limitação de que a contagem **ignora o tamanho do item** MUST aparecer
  junto do número: decompor mais fino eleva a vazão sem mais trabalho feito.

### Prometido × Realizado, por pessoa

- **FR-096**: *Promised × Delivered* por pessoa MUST apresentar, por período da mesma
  janela, os itens **abertos** no período e os **fechados** no período, **sem
  acumular** — as mesmas duas contagens da FR-062, restritas às designações da pessoa.
- **FR-097**: A definição operacional — *prometido = aberto no período; entregue =
  fechado no período* — e a declaração de que **não há escopo comprometido** MUST
  aparecer **uma vez no cabeçalho da seção**, acima da tabela, **e outra vez dentro de
  cada bloco de pessoa aberto**. MUST NOT ser repetida por linha fechada. As colunas da
  tabela fechada MUST usar as palavras operacionais — *opened in the window*, *closed
  in the window* — de modo que a palavra "prometido" nunca apareça sem a definição ao
  lado.

  *A FR-063 exige que "prometido" nunca apareça sem a definição **ao lado**. Repetir a
  ressalva 31 vezes é ruído que ninguém lê, e omiti-la é a FR-063 violada. A saída é
  não usar a palavra onde a definição não cabe, e usá-la onde ela cabe. **Esta é uma
  das duas leituras possíveis da FR-063 — ver Perguntas abertas.***

### Monte Carlo, por pessoa

- **FR-098**: A previsão por pessoa MUST usar `Forecast.monte_carlo/2` com o **mesmo
  piso** — 6 períodos de história e 10 itens fechados, os valores que `Forecast.piso/0`
  devolve — e MUST ser **semanal** independentemente da granulação escolhida para os
  outros gráficos (FR-064). A tela MUST dizer isso.
- **FR-099**: Abaixo do piso, a tela MUST **recusar e dizer o que falta, por pessoa**,
  com os dois números que a pessoa tem e os dois exigidos — a forma da recusa da equipe
  (057 FR-034), que o código já devolve em `{:sem_historico, %{semanas, semanas_
  exigidas, fechadas, fechadas_exigidas}}`. Célula vazia, `0`, "N/A", traço e coluna
  escondida MUST NOT ser usados.
- **FR-100**: A seção MUST declarar, **acima da tabela**, para quantas pessoas há
  previsão e de quantas, e MUST dizer que o piso é do método. Numa equipe real a
  maioria fica abaixo dele, e sem esta linha a tela é lida como quebrada.
- **FR-101**: A previsão de uma pessoa abaixo do piso MUST NOT ser calculada a partir
  da história da **equipe**. Sem história da pessoa, não há previsão sobre a pessoa —
  emprestar o ritmo da equipe fabricaria um número sobre alguém.
- **FR-102**: A recusa MUST ser dita como **lacuna do registro observado**, nunca como
  afirmação sobre a pessoa — a mesma gramática que a FR-023 já usa para habilidades:
  *"That is a gap in the record, never a statement about the person."*
- **FR-103**: A previsão por pessoa MUST ser enunciada como pergunta sobre **o
  trabalho** — quando o que está na mão dela termina, ao ritmo observado dela —, e MUST
  NOT ser enunciada como capacidade, compromisso ou prazo da pessoa.

### A janela, a granulação e a ordem

- **FR-104**: Os gráficos e as colunas por pessoa MUST usar a **mesma** janela e a
  mesma granulação dos gráficos do Dashboard, lidas do endereço (FR-078, FR-079), e
  MUST NOT oferecer seletor por pessoa. Trocar qualquer uma das duas MUST reagrupar
  **todas** as pessoas ao mesmo tempo.

  *A FR-079 exige que toda comparação na mesma tela use a mesma janela. Comparação
  entre pessoas é exatamente isso; janela por pessoa faria duas colunas vizinhas medirem
  períodos diferentes, e a seção perderia a única coisa que ela acrescenta.*
- **FR-105**: Pessoa cujo vínculo começou dentro da janela MUST ter a data de início
  junto da linha, ou *start date unknown* (057 FR-006), e a seção MUST declarar que
  menos períodos com dado é história mais curta dentro da mesma janela, e **não** menos
  trabalho.
- **FR-106**: A ordem padrão da tabela MUST NOT ser nenhuma das quatro medidas. MUST ser
  por papel declarado e depois por nome.

### Quem vê

- **FR-107**: A aba inteira **é** a quebra por pessoa nomeada, então MUST ser
  apresentada apenas a quem alcança a equipe pelo veredito de acesso vigente (058
  FR-024), e a decisão MUST vir **antes** da carga. O veredito é `Tenants.Access.
  pode_ver_equipe/3`, e os caminhos são **quatro**, confirmados no código em
  2026-09-08: `:admin` (conta administradora do mesmo tenant), `:escopo_de_equipe`,
  `:escopo_da_organizacao` (escopo de organização que contém a equipe) e
  `:vinculo_vigente` (quem está na equipe). O escopo `project` **não** entra — a razão
  está declarada no próprio módulo: *"ele nomeia um projeto, e uma equipe pode
  trabalhar em vários; deixá-lo passar faria autoridade subir de lado."*
- **FR-108**: A recusa MUST nomear o motivo (058 FR-024a) — `:fora_do_alcance` é o que
  o veredito devolve. A aba MUST NOT ser escondida em silêncio, e MUST NOT ser
  apresentada vazia como se a equipe não tivesse pessoas.

### O que estes gráficos NÃO podem fazer

- **FR-109**: A seção MUST declarar, em palavras e não em rodapé, que **não é avaliação
  de desempenho e não é ranking de pessoas**: as quatro medidas descrevem o **trabalho
  observado**, e não a pessoa.
- **FR-110**: A tela MUST NOT derivar nenhum número da equipe destas linhas, e MUST NOT
  apresentar média por pessoa como medida da equipe. O número da equipe é medido
  separadamente (FR-060), e a tela já diz isso na seção *What each person is on*.
- **FR-111**: A **cobertura da coleta relativa à pessoa** MUST aparecer junto dos
  números dela, e não em nota de pé. Número baixo de quem tem repositório não coletado
  é lacuna de coleta, e a tela MUST dizer qual dos dois é.

  *`PersonWork.timeline_coverage/2` responde cobertura de **timeline**, e as quatro
  medidas desta extensão não dependem de timeline — saem de `external_created_at` e
  `external_closed_at`, que o próprio módulo declara com cobertura completa. A
  cobertura que importa aqui é outra: se os repositórios em que a pessoa trabalha foram
  coletados.* **[NEEDS CLARIFICATION: existe hoje um número de cobertura de
  repositórios por pessoa? `WorkItems.repositories_of_person/2` lista os observados;
  não há como saber os não observados.]**
- **FR-112**: Comparar duas pessoas cuja cobertura difere MUST ser declarado como **não
  comparável**, junto da tabela. Duas colunas alinhadas convidam à comparação; quando o
  denominador difere, a comparação é ilusão e a tela precisa dizê-lo antes de alguém
  fazê-la.

---

## Success Criteria

### Measurable Outcomes

- **SC-022**: Numa equipe de 31 membros, a aba aberta apresenta **31 linhas e zero
  gráficos**; o número de gráficos na tela é igual a quatro vezes o número de pessoas
  abertas, e nunca passa de doze.
- **SC-023**: A soma da coluna *closed in the window* das linhas é **maior ou igual** à
  vazão da equipe no mesmo período, e a diferença é exatamente o número de itens com
  mais de um responsável da equipe.
- **SC-024**: Trocar a granulação ou a janela no endereço muda **todas** as linhas; não
  existe estado da tela em que duas linhas mostrem janelas diferentes.
- **SC-025**: A soma de abertos e a soma de fechados na janela, para uma mesma pessoa,
  são **iguais** nas três granulações.
- **SC-026**: Em nenhuma célula das quatro medidas aparece célula vazia, `0` sem
  contexto, "N/A" ou traço: cada ausência é uma frase que diz do que ela é ausência.
- **SC-027**: A recusa da previsão por pessoa traz os **quatro** números — semanas que
  tem, semanas exigidas, fechadas que tem, fechadas exigidas — em 100% das pessoas
  abaixo do piso.
- **SC-028**: A contagem *previsão disponível para N de M pessoas* aparece acima da
  tabela em toda equipe, inclusive quando N = M e quando N = 0.
- **SC-029**: A palavra "prometido"/"promised" não aparece em nenhum estado da tela sem
  a definição operacional visível no mesmo bloco.
- **SC-030**: Conta que não alcança a equipe recebe recusa com motivo nomeado, e **zero
  linhas** por pessoa: nenhum login, nenhum nome, nenhum número individual chega ao
  navegador. Conferido pela revisão de segurança, como no PR #798.
- **SC-031**: Abrir três pessoas não passa do teto de consultas por render que o teste
  guarda hoje para a tela da equipe.
- **SC-032**: A tabela recém-carregada nunca está ordenada por uma das quatro medidas,
  em nenhuma equipe.

---

## Fora de escopo

- **Limite de WIP.** Não existe na coleta e não é derivável; seria declaração. Fora
  daqui (FR-091).
- **Ordenar a tabela por medida.** Ordenar por vazão decrescente **é** um ranking, a um
  clique de distância. Fica fora desta extensão e está entre as perguntas abertas.
- **Janela por pessoa.** Quebra a comparação, que é a razão da seção (FR-104).
- **O critério de término declarado** (issue #506). Enquanto ele não existir, *fechado*
  é ato da ferramenta, e a extensão diz isso em vez de esperar.
- **Medidas que dependem de timeline** — tempo em cada estado, tempo até a primeira
  revisão por pessoa. Cobertura de timeline é de 5 repositórios em 53 (medido em
  2026-08-15), e as quatro medidas desta extensão foram escolhidas justamente por não
  dependerem dela.
- **Redesenho de `/people/:id`.** A tela da pessoa continua a casa da leitura profunda,
  e esta extensão só aponta para ela.
- **Comparar pessoas de equipes diferentes.** A aba é de uma equipe.
- **Avaliação de desempenho individual, em qualquer forma.** Não é fora de escopo por
  ser difícil: é fora de escopo por decisão (FR-109).

---

## Premissas

- **O protótipo desta extensão ainda não existe.** A 060 tem um aprovado, e ele não
  cobre a quebra de fluxo por membro. Esta spec assume que o desenho vem antes do
  código, e não vai a `/speckit-plan` sem ele.
- **A US9 vem antes.** A janela no endereço, o seletor de granulação, as definições da
  FR-062 e a ressalva da FR-063 nascem nela. Se a US9 mudar qualquer uma, esta extensão
  muda com ela.
- **`Forecast.monte_carlo/2` serve por pessoa sem alteração.** Ela recebe uma série de
  `%{criadas, fechadas}` e o número de abertos; nada nela é da equipe. Verificado em
  2026-09-08 lendo a assinatura e o piso.
- **O conjunto de membros é o da 060.** Vínculo vigente, invalidado excluído, saída
  declarada respeitada (FR-057). Esta extensão não decide quem é membro.
- **A cadência é de uma semana** (decisão de 2026-08-10). Três user stories P3 numa
  extensão não caberão numa semana junto da US9; ver a recomendação de importância no
  relatório do papel.
- **Equipe de referência para a conferência**: LEDS - ConectaFapes, 31 membros. É o
  caso que reprova qualquer desenho que não faça o recorte.

---

## Perguntas abertas

Nenhuma bloqueia começar o desenho. As duas primeiras bloqueiam **aceitar**.

| # | Pergunta | As leituras | Recomendação |
|---|---|---|---|
| 1 | **A FR-063 admite duas leituras, e elas aceitam e recusam o mesmo entregável.** "Prometido MUST NOT aparecer sem a definição **ao lado**" — o cabeçalho da seção, 800 pixels acima de um gráfico, é "ao lado"? | (a) sim, se a palavra só aparece onde o cabeçalho está visível — e a FR-097 resolve não usando a palavra nas colunas; (b) não: cada gráfico que traz a palavra traz a definição, e são 31 | **(a)**, com a FR-097 como está. Mas a decisão é da pessoa mantenedora: a leitura (b) recusa o entregável que a (a) aceita, e o papel não escolhe a que faz o sprint fechar |
| 2 | **Ordenar a tabela por medida — permitido?** | (a) não, em nenhuma coluna de medida: um clique produz ranking individual; (b) sim, porque encontrar quem tem mais trabalho aberto é o uso legítimo mais óbvio | **(a)** nesta extensão. A pergunta (b) tem resposta melhor: *Problemas agora* já responde "o que precisa de olhar hoje" sem ordenar pessoas |
| 3 | Quantas pessoas abertas ao mesmo tempo? | uma, três, sem limite | **três** — permite comparar dois gráficos vizinhos e mantém o teto de consultas. Número proposto, não medido |
| 4 | **A previsão por pessoa vale a pena, se o piso raramente é atingido?** | (a) sim, com a moldura da FR-103; (b) não: quatro previsões em 31 pessoas é uma coluna quase toda de recusa | **(a)**. A recusa da FR-099 **é** informação — diz que não há história observada suficiente sobre aquele trabalho. Mas foi a pessoa mantenedora que pediu Monte Carlo por membro, e é dela a chamada |
| 5 | A pessoa vê a **própria** linha quando não alcança a equipe? | a 023 FR-012 diz que o trabalho de alguém é visível para a própria pessoa; `pode_ver_equipe/3` **não tem** esse caminho | levar à pessoa mantenedora. A resposta pode exigir um quinto caminho no veredito, e isso é decisão de acesso, não de tela |
| 6 | Onde a substituição do WIP é declarada? | limitação nova em `flow.wip.count`; ou medida com id próprio para "itens abertos por instante" | é decisão do papel de Ontologia. O que esta spec exige é que a tela **diga** (FR-090) |
| 7 | Existe cobertura de repositórios por pessoa? | **[NEEDS CLARIFICATION]** — `repositories_of_person/2` lista os observados; não há denominador | sem ela, a FR-111 vira texto qualitativo. Aceitável para a primeira versão, e a lacuna fica declarada |

---

## O desenho vem antes do código

`.claude/agents/design.md` desenha a tela antes do código, e a decisão da pessoa
mantenedora em 2026-09-07 é que **a tela implementada é exatamente a tela aprovada**.
Então:

1. Esta spec **não vai a `/speckit-plan`** antes de o Design produzir o protótipo desta
   extensão e a pessoa mantenedora aprová-lo.
2. O protótipo é republicado **no mesmo endereço** do da 060, e
   [`prototipo/PROMPT.md`](prototipo/PROMPT.md) ganha a seção da estrutura aprovada
   desta aba — é ela que a aceitação vai conferir item a item, com a captura da tela
   real ao lado e a conferência do QA como evidência.
3. O item do backlog cita o endereço do artifact, o `PROMPT.md` e o `README.md` das
   decisões. Sem os três, o item não está registrado.

### As perguntas de desenho que o Design vai encontrar

| # | A dificuldade |
|---|---|
| 1 | **Quatro medidas em quatro colunas, sem que a linha vire painel.** Trinta e uma linhas × quatro números é uma planilha; o desenho tem de deixar a linha legível de passagem sem esconder a ausência |
| 2 | **A tensão do gráfico pequeno na linha fechada.** A FR-086 diz nenhum gráfico, e a US9 pôs gráfico pequeno no cartão de subequipe (FR-084). Por que ali sim e aqui não? Porque o cartão é **porta** e a linha é **comparação** — e o Design vai perguntar isso, com razão. Se a resposta mudar, a FR-086 muda |
| 3 | **A maioria das células é recusa.** Quatro previsões em 31 pessoas. O desenho tem de fazer a coluna de recusas parecer o estado do registro, e não uma tela quebrada — e a FR-100 sozinha não resolve isso visualmente |
| 4 | **Onde a frase anti-ranking é lida, e não pulada.** Rodapé não é lido. A FR-109 exige palavras; o Design decide onde elas ficam para serem lidas antes dos números |
| 5 | **Como a expansão de três pessoas se comporta** com quatro gráficos cada — doze gráficos numa coluna, ou dois por linha, ou lado a lado para comparar |
| 6 | **A hachura do derivado.** A previsão é derivada e a tela já tem a gramática (pílula âmbar tracejada, hachura). A série de WIP é observada, a previsão é simulada, e as duas ficam no mesmo bloco: o desenho precisa distinguir sem poluir |
| 7 | **A cobertura junto do número** (FR-111), sem que cada célula ganhe um segundo número que ninguém lê |

---

## Impacto

### Telas

| Arquivo | O que muda |
|---|---|
| `lib/the_band_web/live/teams_live/show.ex` | terceira aba; a máquina de abas já existe (`?tab=structure`, FR-001) e o seletor de granulação e a janela já vivem no endereço. A seção *What each person is on* ganha o caminho para a aba nova (FR-088) |
| `lib/the_band_web/live/people_live/show.ex` *(a confirmar o caminho)* | nada muda. Continua a leitura profunda, e o bloco aberto aponta para ela |

### Módulos — o que a tela precisa e hoje não existe ou está incompleto

| O que | Estado hoje, verificado em 2026-09-08 | Requisitos |
|---|---|---|
| **abertos e fechados por período, por pessoa** | `WorkItems.state_changes_by_period(tenant, person_id, escala)` **existe** e é exatamente isto — mas tem **aridade 3 e não recebe janela**. A da equipe é `team_state_changes_by_period(tenant, team_id, escala, opts)`, com `opts`. Precisa receber `desde`/`ate` como a da equipe, ou a FR-104 é impossível | FR-093, FR-096, FR-104 |
| **série do trabalho aberto por pessoa** | **não existe**. `TeamWork.open_tasks_by_person(tenant, team_id, quando, ids)` devolve a **lista** de tarefas abertas de cada pessoa num **instante**. Chamá-la por instante devolveria a lista inteira 8 vezes para 31 pessoas — consulta nova, contando por pessoa e por período numa passagem, é o caminho | FR-089 |
| **previsão por pessoa** | `Forecast.monte_carlo/2` serve **sem alteração**: recebe a série e `:aberto`, e nada nela é da equipe. `Forecast.piso/0` já expõe os dois números para a tela dizer o que falta sem duplicá-los | FR-098, FR-099 |
| **cobertura de repositórios por pessoa** | **não existe.** `PersonWork.timeline_coverage/2` responde timeline, que estas medidas não usam. `WorkItems.repositories_of_person/2` lista os observados, sem denominador | FR-111 **[NEEDS CLARIFICATION]** |
| **teto de consultas** | há teste-guarda de consultas por render nesta tela (a L38 já reprovou uma versão). Três pessoas abertas × quatro medidas precisa caber, e o número de consultas MUST NOT crescer com o número de membros | SC-031 |

### Base de conhecimento — antes da tela (princípio IV)

Duas das quatro medidas **não declaram o nível `person`**, e isso é bloqueio, não
detalhe: apresentar por pessoa uma medida cujo escopo declarado é a equipe é afirmar
com a base algo que a base não diz.

| Medida | `scope.levels` hoje | O que falta |
|---|---|---|
| `flow.wip.count` | `[sprint, project, team, person]` | **nada a acrescentar** ao escopo. Falta declarar a **substituição** da FR-090 — a fórmula exige `start_date`/`end_date` da tarefa, e o critério de fim não existe |
| `flow.throughput.rate` | `[sprint, project, team, person]` | **nada**. A limitação da não-aditividade no nível `person` **já está declarada** |
| `flow.open_work.cumulative` | `[team, project]` — **sem `person`** | declarar o nível `person`, com a regra de contagem (uma vez por participante) e a não-aditividade. O filtro atual já antecipa a regra em texto; falta o nível |
| `flow.completion_forecast` | `[team]` — **sem `person`** | declarar o nível `person`, com o piso e a limitação de que a história da equipe **não** substitui a da pessoa (FR-101) |

**Nenhuma medida nova.** As quatro necessidades de informação já existem:
`flow.work_in_progress`, `flow.throughput`, `flow.open_work_balance` e — para a
previsão — a que `flow.completion_forecast` responde. Esta extensão não cria número.

### O que exige decisão de outro papel

| O quê | De quem | Por quê |
|---|---|---|
| declarar `person` em `flow.open_work.cumulative` e em `flow.completion_forecast` | **Ontologia** | escopo de medida é semântica, e ampliá-lo muda o que a medida afirma |
| onde a substituição do WIP é declarada, e sob que id | **Ontologia** | pergunta aberta 6 |
| **candidato a ADR**: o que a plataforma chama de WIP enquanto o critério de fim não existe | **Arquiteto** | a substituição já acontece no burn da equipe, e esta extensão a espalha para 31 pessoas por equipe. Nomear uma medida por algo que a fórmula declarada não computa é decisão com alcance além desta tela. **Este papel aponta; não decide, e não abre ADR** |
| consulta nova da série de trabalho aberto por pessoa | **Desenvolvedor** | ver a tabela de módulos |
| quinto caminho no veredito de acesso, se a resposta à pergunta 5 for "sim" | **Arquiteto** + pessoa mantenedora | acesso, não tela |

### Documentos de outros papéis que esta extensão afeta, sem alterá-los

- `docs/sprints/NNN/sprint-backlog.md` — três user stories P3 que dependem da US9.
- `docs/metrics/indicadores.md` — se a aba entrar, `flow.wip.count` e
  `flow.throughput.rate` passam a ter leitura no nível `person`, com as limitações
  copiadas.
- `specs/060-tela-da-equipe/tasks.md` — US10 a US12 entram sem tarefa, como US7 a US9
  já estão.
