# Feature Specification: A tela da equipe, e a equipe feita de equipes

**Feature Branch**: `057-tela-da-equipe-complexa`

**Created**: 2026-09-02

**Status**: Draft

**Input**: User description: "A tela de equipe é focada na equipe e responde quatro perguntas de gestão: o que a equipe está fazendo, o que já fez, o que vem a seguir, e o que ela sabe. Quando a equipe é complexa — composta por duas ou mais equipes —, os indicadores das subequipes aparecem SEPARADAMENTE, uma linha por subequipe, e NUNCA somados; clicar numa subequipe abre o detalhe dela. Gráfico nenhum na tela da equipe complexa: os gráficos vivem na tela da subequipe. Na subequipe: as seis medidas, semana a semana, um burn-up/burn-down onde o burn-up é o acumulado de issues abertas e o burn-down o acumulado de issues fechadas — o trabalho ainda em aberto é a DISTÂNCIA entre as duas curvas, hachurada porque é derivada, e não uma terceira linha; e uma previsão de Monte Carlo com duas hipóteses (escopo congelado e escopo vivo, amostrando o que a equipe de fato teve), apresentada como faixa de confiança e nunca como data prometida. Ainda na subequipe: por pessoa, TODAS as tarefas abertas com o tempo em cada uma (nada colapsa em 'tarefa atual'), e as habilidades demonstradas como pílulas hachuradas com marca derived, na mesma gramática da tela de pessoa. Ausência é nomeada: pessoa sem tarefa aberta diz isso, pessoa abaixo do piso de perfil não lista habilidade nenhuma e a tela diz por quê. Antes de qualquer medida, corrigir o defeito registrado em docs/backlog/tela-da-equipe-complexa.md: Profiles.team_skills lê a evidência do GitHub e ignora o vínculo declarado (started_at, ended_at, invalidação da 055), de modo que quem saiu continua contando depois da saída e evolution/2 aplica o conjunto de membros de hoje a meses passados, mudando hoje o número de um mês fechado."

## O que esta feature resolve

Hoje a tela da equipe mostra estrutura, membros, projetos, avisos de processo e
competências. Ela **não** responde as quatro perguntas que quem gerencia faz, e
**mede errado** as que responde: o conjunto de membros vem da evidência que o
GitHub mostra hoje, sem olhar o vínculo declarado que a feature 055 criou.

Duas consequências, e a segunda é a grave:

| # | O que acontece |
|---|---|
| 1 | quem saiu da equipe **continua contando depois** da saída, se a origem ainda o lista |
| 2 | o conjunto de membros **de hoje** é aplicado a **todos os meses passados** — o número de um mês fechado muda hoje |

A segunda é o mesmo defeito que o **SC-003 da feature 055** proíbe no vínculo,
acontecendo na medida. Uma medida cujo passado se reescreve não sustenta decisão
nenhuma, e é por isso que a correção vem antes de qualquer indicador novo.

A feature também estabelece o que a equipe **composta de equipes** mostra: cada
subequipe em sua própria linha, **nunca somadas**, porque a mesma pessoa pode
pertencer a duas subequipes e a mesma tarefa pode aparecer nas duas — somar
contaria duas vezes e o total pareceria maior do que o trabalho existente.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A medida conta só enquanto a pessoa pertenceu (Priority: P1)

Quem gerencia abre a tela de uma equipe da qual alguém saiu em março. As
competências, a contagem de tarefas e a série de evolução refletem a equipe **como
ela era em cada momento**: o trabalho que a pessoa fez enquanto pertencia continua
contando para a equipe, e o que ela fez depois de sair não conta. Reabrir a tela
semanas depois mostra, para os meses já fechados, exatamente os mesmos números.

**Why this priority**: toda medida desta feature se apoia no conjunto de membros.
Construir indicador novo sobre um conjunto errado propaga o defeito em vez de
corrigi-lo — e o defeito de reescrever o passado destrói a confiança em qualquer
número que a tela venha a mostrar.

**Independent Test**: declarar uma equipe com três pessoas, registrar a saída de
uma delas com data no passado, e conferir que a tela conta o trabalho dela até a
saída e não depois; anotar os números dos meses fechados, registrar a saída de uma
segunda pessoa, e conferir que os números dos meses fechados **não mudaram**.

**Acceptance Scenarios**:

1. **Given** uma pessoa com vínculo encerrado em 2026-03-15, **When** a tela da
   equipe é aberta, **Then** as tarefas que ela concluiu até 2026-03-15 contam
   para a equipe e as concluídas depois não contam
2. **Given** uma pessoa cujo vínculo foi marcado como equívoco (invalidação da
   055), **When** a tela é aberta, **Then** nenhum trabalho dela conta para a
   equipe em nenhum período — o vínculo nunca existiu
3. **Given** a série mensal exibida em 2026-09-02, **When** uma saída é
   registrada em 2026-09-03 e a tela é reaberta, **Then** os pontos dos meses
   anteriores a setembro têm exatamente os mesmos valores
4. **Given** uma pessoa que entrou na equipe em 2026-06-01, **When** a série
   mensal é exibida, **Then** ela não aparece nos meses anteriores a junho
5. **Given** uma pessoa listada pela origem mas sem vínculo declarado, **When** a
   tela é aberta, **Then** ela aparece nomeada como evidência não promovida, e
   não é somada silenciosamente aos números da equipe

---

### User Story 2 - A equipe complexa mostra suas equipes, uma a uma (Priority: P1)

Quem gerencia abre a tela de uma equipe composta por outras equipes. Vê uma linha
por subequipe, cada uma com seus indicadores, **lado a lado e nunca somados**, mais
uma linha separada para os membros diretos da própria equipe. Clicar numa
subequipe abre a tela dela. Nenhum gráfico aparece aqui: a tela da equipe complexa
é para comparar, e a comparação se faz em números alinhados.

**Why this priority**: é o pedido central, e é a decisão que impede o erro mais
caro — um total somado que ninguém consegue reconciliar com a realidade porque
conta a mesma pessoa e a mesma tarefa mais de uma vez.

**Independent Test**: compor uma equipe com duas subequipes que compartilham uma
pessoa, e conferir que nenhum número apresentado é a soma das duas linhas, que a
tela diz por que não soma, e que clicar em cada subequipe leva à tela dela.

**Acceptance Scenarios**:

1. **Given** uma equipe composta por três subequipes, **When** a tela é aberta,
   **Then** há três linhas de indicadores mais a linha dos membros diretos, e
   nenhuma célula de total
2. **Given** uma pessoa que pertence a duas das subequipes, **When** os
   indicadores são exibidos, **Then** ela conta em cada uma das duas linhas, e a
   tela explica que por isso as linhas não se somam
3. **Given** uma equipe sem subequipes, **When** a tela é aberta, **Then** ela
   mostra diretamente o conteúdo de equipe simples, sem seção de composição vazia
4. **Given** uma subequipe sem nenhum trabalho no período, **When** a tela é
   aberta, **Then** a linha dela aparece com ausência nomeada, nunca com zero
5. **Given** a tela da equipe complexa, **When** ela é inspecionada, **Then**
   nenhum gráfico é apresentado nela

---

### User Story 3 - O detalhe da subequipe: fazendo, feito, e o que vem (Priority: P2)

Quem gerencia clica numa subequipe e vê o que ela está fazendo agora, o que já
concluiu, o que vem a seguir, e o que ela sabe — nesta ordem, e semana a semana
para o que varia no tempo.

**Why this priority**: é o destino do clique da US2. Sem ela, a tela da equipe
complexa aponta para uma página que não responde nada.

**Independent Test**: abrir a tela de uma subequipe com trabalho aberto, fechado e
enfileirado, e conferir que as três seções apresentam itens distintos e
identificáveis, e que a série semanal cobre o período declarado.

**Acceptance Scenarios**:

1. **Given** uma subequipe com trabalho em aberto, **When** a tela é aberta,
   **Then** a seção do que está sendo feito lista esse trabalho com identificação
   e link para o item
2. **Given** uma subequipe sem trabalho concluído no período, **When** a tela é
   aberta, **Then** a seção diz que nada foi concluído no período, e não mostra
   zero como se fosse uma medida
3. **Given** semanas sem nenhum item, **When** a série semanal é exibida, **Then**
   a semana aparece com valor zero **observado** — distinto de semana fora do
   período coletado, que não aparece

---

### User Story 4 - O que cada pessoa está fazendo, e o que demonstrou (Priority: P2)

Na tela da subequipe, quem gerencia vê cada pessoa com **todas** as tarefas
abertas atribuídas a ela e há quanto tempo cada uma está aberta, e — em seção
própria — as habilidades que o trabalho concluído demonstrou, marcadas como
derivadas.

**Why this priority**: é a pergunta que quem gerencia faz primeiro numa
conversa de acompanhamento, e a que hoje exige abrir a origem item por item.

**Independent Test**: atribuir duas tarefas abertas à mesma pessoa e conferir que
ambas aparecem, com tempos distintos, sem que nenhuma seja eleita "a atual".

**Acceptance Scenarios**:

1. **Given** uma pessoa com duas tarefas abertas, **When** a tela é aberta,
   **Then** as duas aparecem, cada uma com seu tempo, e nenhuma é apresentada como
   a tarefa atual
2. **Given** uma pessoa sem nenhuma tarefa aberta, **When** a tela é aberta,
   **Then** a ausência é dita em texto, e a pessoa não é omitida da lista
3. **Given** uma tarefa aberta há mais de 90 dias, **When** a tela é aberta,
   **Then** ela recebe marca visível de parada, e a tela diz que a marca é um
   convite a perguntar, não um veredito
4. **Given** qualquer tarefa aberta, **When** o tempo é exibido, **Then** ele é
   contado da abertura do item, e a tela declara que a origem não informa quando a
   pessoa assumiu
5. **Given** uma pessoa cujo material no período está abaixo do piso de geração de
   perfil, **When** a seção de habilidades é exibida, **Then** nenhuma habilidade
   é listada para ela e a tela diz por quê
6. **Given** a seção de habilidades, **When** ela é exibida, **Then** cada
   habilidade carrega marca de derivada, e a tela declara que habilidade ausente
   significa não observada aqui, nunca incapacidade

---

### User Story 5 - Burn-up e burn-down, com o que resta entre as curvas (Priority: P2)

Quem gerencia vê, na tela da subequipe, duas curvas acumuladas — o que foi aberto
e o que foi fechado — e lê o trabalho ainda em aberto como a **distância entre
elas**, marcada como derivada. A faixa alargando diz que a equipe abre mais rápido
do que fecha; estreitando, que está alcançando.

**Why this priority**: responde "a equipe fecha na velocidade em que abre" sem
depender de um critério de término declarado, que a plataforma não tem — e por
isso é desenhável com o dado que já existe.

**Independent Test**: com uma série conhecida de aberturas e fechamentos, conferir
que a diferença entre as curvas em qualquer semana é igual ao número de itens em
aberto naquela semana.

**Acceptance Scenarios**:

1. **Given** as duas curvas acumuladas, **When** qualquer semana é lida, **Then**
   a distância entre elas é igual à contagem de itens em aberto naquela semana
2. **Given** o gráfico, **When** ele é inspecionado, **Then** o que resta é
   apresentado como a faixa entre as curvas e **não** como uma terceira série
3. **Given** o gráfico, **When** ele é lido, **Then** a tela declara que não há
   escopo comprometido, e que ele não responde se um sprint termina
4. **Given** um item fechado sem critério de término declarado, **When** ele entra
   na curva, **Then** a tela declara que "fechado" é o ato da ferramenta —
   abandonado e concluído entram iguais
5. **Given** o mesmo período consultado duas vezes, **When** as curvas são
   comparadas, **Then** os valores são idênticos

---

### User Story 6 - Uma previsão que diz sua confiança (Priority: P3)

Quem gerencia vê uma previsão de entrega construída por simulação sobre o que a
equipe **de fato teve**, apresentada em duas hipóteses — escopo congelado e escopo
vivo — e sempre como faixa de confiança, nunca como data.

**Why this priority**: é o maior salto de valor da tela, e o mais fácil de
transformar em compromisso indevido. Vem por último porque depende de todas as
medidas anteriores estarem certas.

**Independent Test**: com histórico conhecido, conferir que a faixa de 85% cobre
pelo menos 85% das simulações, e que a tela recusa prever quando o histórico está
abaixo do piso.

**Acceptance Scenarios**:

1. **Given** histórico suficiente, **When** a previsão é exibida, **Then** ela
   apresenta as duas hipóteses e, em cada uma, a faixa e sua confiança
2. **Given** a previsão, **When** ela é lida, **Then** nenhum texto apresenta um
   valor como data prometida, e a tela declara o que a simulação assume
3. **Given** histórico abaixo do piso declarado, **When** a tela é aberta,
   **Then** nenhuma previsão é apresentada e a tela diz o que falta para ela
   existir
4. **Given** uma equipe cujo ritmo de abertura supera o de fechamento, **When** a
   hipótese de escopo vivo é simulada, **Then** a tela apresenta a proporção de
   simulações que **não** terminaram, em vez de omitir o caso
5. **Given** a mesma consulta repetida, **When** as previsões são comparadas,
   **Then** as faixas apresentadas são iguais

### Edge Cases

- **Pessoa em duas subequipes** — conta em cada linha, e a tela diz que é por isso
  que as linhas não somam.
- **Tarefa com duas pessoas responsáveis** — aparece uma vez para cada, e o texto
  declara isso onde os números por pessoa são apresentados.
- **Equipe que deixou de compor outra** — a composição encerrada não aparece como
  atual; a subequipe continua existindo com seu histórico intacto.
- **Composição que formaria ciclo** — recusada, como já exige a feature 055.
- **Subequipe sem membros** — linha presente, com ausência nomeada.
- **Pessoa listada pela origem sem vínculo declarado** — nomeada como evidência
  não promovida; não entra nos números.
- **Vínculo com `started_at` desconhecido** — a pessoa entra a partir da primeira
  evidência observada, e a tela declara que a data de início é desconhecida.
  **Nunca é excluída**: nulo é desconhecido, não "nunca pertenceu" — FR-006a.
- **Semana sem trabalho** dentro do período coletado — zero observado.
  **Semana fora** do período coletado — ausente, nunca zero.
- **Item aberto antes da janela e ainda aberto** — entra na linha de base de
  FR-026a; sem ela o gráfico afirmaria menos trabalho aberto do que existe.
- **Item reaberto** — o fechamento anterior permanece na curva na semana em que
  ocorreu, e a reabertura acrescenta uma abertura na semana em que ocorreu.
- **Histórico abaixo do piso** para previsão — recusa explicada, nunca faixa
  larga apresentada como se informasse.
- **Equipe complexa com uma única subequipe** — não é composta para efeito desta
  tela; segue como equipe simples com uma composição declarada.

## Requirements *(mandatory)*

### O período do vínculo

- **FR-001**: O conjunto de membros usado em **qualquer** medida MUST ser o
  vínculo declarado vigente **na data medida**, e não a evidência da origem no
  momento da consulta.
- **FR-002**: Trabalho concluído por uma pessoa MUST contar para a equipe apenas
  quando concluído dentro do período do vínculo — de `started_at` inclusive até
  `ended_at` exclusive.
- **FR-003**: Vínculo invalidado como equívoco MUST ser excluído de todos os
  períodos, e não apenas do presente.
- **FR-004**: Um valor já apresentado para um período encerrado MUST permanecer o
  mesmo em consultas posteriores, independentemente de saídas, entradas ou
  invalidações registradas depois.
- **FR-005**: Pessoa observada pela origem sem vínculo declarado MUST ser
  apresentada nomeada como evidência não promovida, e MUST NOT entrar nas
  contagens da equipe.
- **FR-006**: Vínculo sem `started_at` conhecido MUST ser tratado a partir da
  primeira evidência observada da pessoa na equipe, e a tela MUST declarar que a
  data de início é desconhecida.
- **FR-006a**: Vínculo sem `started_at` MUST NOT ser excluído das medidas. Uma
  comparação de data contra nulo não é falsa: é desconhecida — e tratá-la como
  falsa faz a pessoa deixar de ser membro **em data alguma**, sem erro e sem
  aviso. É o fallback silencioso que o princípio VIII trata como defeito.

### A equipe composta de equipes

- **FR-007**: A tela de uma equipe com duas ou mais subequipes MUST apresentar uma
  linha de indicadores por subequipe, mais uma linha para os membros diretos.
- **FR-008**: O sistema MUST NOT apresentar soma, média ou total consolidado das
  linhas de subequipe.
- **FR-009**: A tela MUST declarar por que não soma, nomeando a dupla contagem de
  pessoa e de tarefa como causa.
- **FR-010**: Cada linha de subequipe MUST levar à tela daquela subequipe.
- **FR-011**: A tela da equipe composta MUST NOT apresentar gráficos.
- **FR-012**: Subequipe sem trabalho no período MUST aparecer com ausência
  nomeada, e MUST NOT aparecer com zero.
- **FR-013**: Composição encerrada MUST NOT ser apresentada como composição atual.

### O detalhe da subequipe

- **FR-014**: A tela da subequipe MUST responder, em seções distintas, o que a
  equipe está fazendo, o que já fez, o que vem a seguir, e o que ela sabe.
- **FR-015**: As medidas que variam no tempo MUST ser apresentadas semana a
  semana dentro do período coletado.
- **FR-016**: Semana sem trabalho dentro do período coletado MUST ser apresentada
  como zero observado; semana fora do período coletado MUST NOT ser apresentada.

### As pessoas

- **FR-017**: Para cada pessoa, o sistema MUST apresentar **todas** as tarefas
  abertas atribuídas a ela, uma por linha.
- **FR-018**: O sistema MUST NOT eleger uma tarefa como "atual" quando há mais de
  uma aberta.
- **FR-019**: Cada tarefa aberta MUST trazer há quanto tempo está **aberta**,
  contado da abertura do item — e a tela MUST declarar que é da abertura, e não de
  quando a pessoa a assumiu nem de quando o trabalho começou.
- **FR-019a**: O sistema MUST NOT apresentar tempo desde a atribuição. A origem
  não registra quando a atribuição aconteceu, e derivar essa data de qualquer
  outra seria inventá-la.
- **FR-020**: Tarefa aberta além do limiar de parada MUST receber marca visível, e
  a tela MUST declarar que a marca é um convite a perguntar.
- **FR-021**: Pessoa sem tarefa aberta MUST aparecer com a ausência dita em texto.
- **FR-022**: As habilidades demonstradas MUST ser apresentadas em seção própria,
  cada uma com marca de derivada.
- **FR-023**: Pessoa com material abaixo do piso de geração de perfil MUST NOT ter
  habilidade listada, e a tela MUST dizer por quê.
- **FR-024**: A tela MUST declarar que habilidade ausente significa não observada
  aqui, e nunca incapacidade.
- **FR-025**: Quando uma tarefa tem mais de uma pessoa responsável, ela MUST
  aparecer para cada uma, e a tela MUST declarar que por isso as linhas não somam.

### Burn-up e burn-down

- **FR-026**: O sistema MUST apresentar o acumulado de itens abertos e o acumulado
  de itens fechados no período, como duas séries num único eixo.
- **FR-026a**: O acumulado de abertos MUST partir da contagem de itens **já em
  aberto no início do período**, e não de zero. Sem essa linha de base a distância
  entre as curvas mede apenas os itens nascidos dentro da janela, e não o trabalho
  em aberto — que é o que FR-028 exige.
- **FR-027**: O trabalho ainda em aberto MUST ser apresentado como a região entre
  as duas séries, marcada como derivada, e MUST NOT ser uma terceira série.
- **FR-028**: A distância entre as séries em qualquer ponto MUST ser igual à
  contagem de itens em aberto naquele ponto.
- **FR-029**: A tela MUST declarar que não há escopo comprometido e que o gráfico
  não responde se um sprint termina.
- **FR-030**: A tela MUST declarar que "fechado" é o ato registrado na ferramenta,
  e que item abandonado e item concluído entram iguais.

### A previsão

- **FR-031**: A previsão MUST ser construída por simulação sobre o histórico
  observado da própria equipe, sem estimativa declarada.
- **FR-032**: O sistema MUST apresentar duas hipóteses: escopo congelado e escopo
  vivo, esta amostrando também o ritmo de abertura observado.
- **FR-033**: Todo resultado MUST ser apresentado com sua confiança, e MUST NOT
  ser apresentado como data prometida.
- **FR-034**: Quando o histórico está abaixo do piso declarado, o sistema MUST NOT
  apresentar previsão, e MUST dizer o que falta.
- **FR-035**: Quando parte das simulações não conclui dentro do horizonte, o
  sistema MUST apresentar essa proporção.
- **FR-036**: A mesma consulta MUST produzir a mesma previsão.
- **FR-037**: A tela MUST declarar o que a simulação assume — que o período à
  frente se parece com o observado.

### Acesso

- **FR-038**: Todas as consultas MUST ser restritas ao tenant de quem consulta.
- **FR-039**: Ver a tela da equipe MUST NOT exigir permissão de administrar
  equipes — administrar não é ver.

### Key Entities

- **Equipe** — coletivo de pessoas; pode ser parte de outras equipes e conter
  outras, com a composição carregando seu próprio período.
- **Vínculo de equipe** — o relator que liga pessoa, papel e equipe, com início,
  fim e a marca de invalidação criada pela feature 055. **É a fonte do conjunto de
  membros em qualquer data.**
- **Composição de equipes** — a relação parte-todo entre equipes, com período
  próprio; encerrá-la não encerra nenhuma das equipes.
- **Item de trabalho** — o que é aberto, atribuído e fechado; a unidade das duas
  curvas e da simulação.
- **Perfil de pessoa** — a leitura derivada de onde saem as habilidades
  demonstradas, com seu piso de geração.
- **Recorte semanal** — a semana como unidade da série, com a distinção entre
  semana observada com zero e semana fora do período coletado.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em 100% dos casos, o trabalho concluído por uma pessoa fora do
  período do seu vínculo não aparece nos números da equipe.
- **SC-002**: Registrar uma saída, uma entrada ou uma invalidação **não altera
  nenhum** valor já apresentado para um período encerrado — verificável comparando
  a série antes e depois do registro.
- **SC-003**: Nenhuma tela de equipe composta apresenta soma, média ou total das
  linhas de subequipe — verificável por varredura da tela renderizada.
- **SC-004**: Em toda subequipe com trabalho no período, a distância entre as duas
  curvas em qualquer semana é igual à contagem de itens em aberto naquela semana.
- **SC-005**: Quem gerencia identifica, em menos de 30 segundos na tela da equipe
  composta, qual subequipe tem mais trabalho parado.
- **SC-006**: 100% das pessoas listadas têm ou uma tarefa aberta apresentada ou a
  ausência dita em texto — nenhuma linha em branco.
- **SC-007**: 100% das habilidades apresentadas carregam marca de derivada.
- **SC-008**: A faixa de 85% cobre pelo menos 85% das simulações executadas.
- **SC-009**: A mesma consulta repetida produz curvas e faixas idênticas.
- **SC-010**: Com histórico abaixo do piso, nenhuma previsão é apresentada e a
  tela nomeia o que falta.
- **SC-011**: Nenhuma consulta desta feature devolve dado de outro tenant.
- **SC-011a**: 100% dos vínculos com `started_at` desconhecido aparecem nas
  medidas da equipe — nenhum é excluído por comparação com nulo.
- **SC-012**: Uma pessoa sem permissão de administrar equipes consegue abrir e ler
  a tela da equipe.

## Assumptions

- **O trabalho de uma equipe é o dos seus membros.** Segue a regra já usada nos
  avisos de processo: os itens atribuídos às pessoas da equipe — agora restritos
  ao período do vínculo. Não existe vínculo direto entre item e equipe na origem.
- **O que é o "período coletado"**: a janela em que a plataforma de fato tem
  observação da origem para aquela equipe — a mesma borda que a cobertura de
  timeline já expõe hoje para a pessoa. Fora dela não se afirma zero, porque não
  se observou; dentro dela, zero é observação.
- **Período padrão das séries: 8 semanas**, sem seletor nesta feature. Escolher o
  período é trabalho separado, e um seletor sem definição de período fechado
  reabriria a questão do denominador móvel.
- **Limiar de parada: 90 dias** desde a **abertura do item**. A origem não
  registra quando a atribuição aconteceu — decisão já em vigor desde 2026-08-27 —,
  e uma tarefa assumida tarde lê como mais lenta do que foi. A tela declara isso
  em vez de esconder.
- **Piso para previsão: 6 semanas completas dentro do período coletado e ao menos
  10 itens fechados.** Abaixo disso a faixa seria larga a ponto de não informar, e
  apresentá-la seria pior do que recusar.
- **Horizonte da simulação: 12 semanas.** Simulação que não conclui dentro dele
  entra na proporção de não conclusão (FR-035).
- **Confiança apresentada: 50%, 85% e 95%.**
- **Uma subequipe não é "composta"** para efeito desta tela: composição com uma
  única parte segue como equipe simples.
- **A interface é em inglês**, com pt como tradução — decisão de 2026-09-01.
- **A gramática de proveniência já existe**: sólido para observado, hachurado para
  derivado, tracejado para ausente. Esta feature consome, não redefine.
- **Depende da feature 055** (equipes declaradas, composição e invalidação de
  vínculo) já entregue, e da 029 (perfis e competências de equipe).
- **A geração de perfis não muda** aqui: a feature consome o piso existente.
- **Fora de escopo**: seletor de período, exportação, alerta ativo, comparação
  entre equipes de organizações diferentes, e qualquer soma consolidada — esta
  última por decisão, não por prazo.
