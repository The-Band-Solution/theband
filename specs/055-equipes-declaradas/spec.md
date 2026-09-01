# Feature Specification: A organização declara suas equipes

**Feature Branch**: `feat/055-equipes-declaradas`

**Created**: 2026-09-01

**Status**: Draft

**Input**: User description: "vamos focar em criar equipes .. uma equipe pode ter outra equipe .. e uma equipe pode adicionar ou remover uma pessoa ou informar que ela saiu da equipe."

## Por que agora

Hoje **equipe só nasce da coleta**. A plataforma vê o que o GitHub mostra — 12
equipes e 88 pessoas no banco de desenvolvimento — e não há como dizer que existe
uma equipe que o GitHub não conhece, nem que duas delas formam uma terceira, nem
que alguém saiu.

Organizações reais não cabem no que a forja de código expõe: há times que
atravessam repositórios, células dentro de departamentos, e pessoas que entram e
saem sem que nada mude no GitHub. **A plataforma mede o que essas pessoas
produzem e não sabe dizer de quem elas são.**

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A organização cria a equipe que o GitHub não conhece (Priority: P1)

Quem administra abre a lista de equipes, cria uma com nome próprio, e ela passa a
existir ao lado das que vieram da coleta — **distinguível delas na tela**, porque
uma foi observada e a outra foi declarada, e confundir as duas é o defeito que
esta plataforma existe para não cometer.

**Why this priority**: sem criar, não há o que compor nem a que vincular. É a
base das outras duas histórias.

**Independent Test**: criar uma equipe pela tela e encontrá-la na lista, marcada
como declarada, sem tocar em nada do GitHub.

**Acceptance Scenarios**:

1. **Given** a lista de equipes, **When** quem administra cria uma equipe com
   nome, **Then** ela aparece na lista **marcada como declarada**, com quem a
   declarou e quando.
2. **Given** uma equipe que veio da coleta, **When** alguém olha a lista,
   **Then** ela aparece **marcada como observada** — e a distinção **não** é
   carregada só por cor.
3. **Given** uma equipe declarada, **When** quem administra tenta criar outra com
   o mesmo nome no mesmo escopo, **Then** é recusado com a razão — nomes
   repetidos tornam impossível saber de qual equipe um painel fala.
4. **Given** alguém que não administra, **When** tenta criar, **Then** é
   recusado.

---

### User Story 2 - A pessoa entra, sai, e o que ela fez continua lá (Priority: P1)

Quem administra vincula pessoas à equipe, com o papel que cada uma desempenha. E
quando alguém sai, isso é **registrado como saída** — a pessoa **esteve** ali, e
o que ela entregou naquele período continua contando para a equipe.

**Why this priority**: mesma prioridade da US1 porque **a US1 sozinha entrega uma
casca**. Equipe sem pessoas não responde nenhuma pergunta.

**Independent Test**: vincular três pessoas, registrar a saída de uma, e conferir
que um painel de período anterior à saída mostra **o mesmo número** antes e
depois.

**Acceptance Scenarios**:

1. **Given** uma equipe, **When** quem administra vincula uma pessoa com um
   papel, **Then** o vínculo passa a valer a partir da data informada, com quem
   o declarou.
2. **Given** uma pessoa vinculada, **When** quem administra registra que ela
   **saiu**, **Then** o vínculo ganha data de fim — e **nenhum número de período
   anterior muda**.
3. **Given** um vínculo criado **por engano** — a pessoa nunca esteve nessa
   equipe —, **When** quem administra o desfaz, **Then** ele deixa de valer para
   qualquer período, e **o registro do equívoco permanece**, com autor e razão.
4. **Given** uma pessoa que saiu, **When** ela é vinculada de novo à mesma
   equipe, **Then** nasce um vínculo novo — os dois períodos coexistem, e o
   histórico mostra os dois.
5. **Given** uma pessoa já vinculada e vigente, **When** alguém tenta vinculá-la
   de novo à mesma equipe, **Then** é recusado com a razão.

---

### User Story 3 - Equipe dentro de equipe (Priority: P2)

Quem administra diz que uma equipe faz parte de outra, e a estrutura da
organização passa a existir na plataforma — departamento com células dentro,
frente com times dentro.

**Why this priority**: P2 porque as duas primeiras já entregam valor. A
composição é o que torna possível perguntar da organização inteira em vez de time
a time — e é ela que o rollup de competências vai usar depois.

**Independent Test**: pôr duas equipes dentro de uma terceira e ver a estrutura
na tela; tentar fechar um ciclo e ser recusado.

**Acceptance Scenarios**:

1. **Given** duas equipes, **When** quem administra declara que a primeira faz
   parte da segunda, **Then** a estrutura aparece nas duas telas — a de cima
   mostra o que contém, a de baixo mostra de quem faz parte.
2. **Given** a equipe A dentro da B, **When** alguém tenta pôr a B dentro da A,
   **Then** é recusado: **a composição não pode fechar ciclo**, direto ou por
   qualquer caminho.
3. **Given** uma equipe que contém outras, **When** ela deixa de conter uma
   delas, **Then** a que saiu continua existindo, com o seu histórico intacto.
4. **Given** uma equipe observada, **When** quem administra a põe dentro de uma
   declarada, **Then** funciona — a composição é declaração, e vale para os dois
   tipos.

---

### Edge Cases

- **Ciclo por caminho longo.** A dentro de B, B dentro de C, e alguém tenta pôr C
  dentro de A. A recusa precisa alcançar o caminho inteiro, não só o vizinho.
- **Equipe declarada com o nome de uma observada.** Não é erro — a organização
  pode ter um time interno homônimo. A tela precisa deixar claro qual é qual.
- **Saída sem data.** Quem registra a saída pode não saber o dia exato. O que
  acontece: recusa, ou aceita com a data de hoje e diz que foi presumida?
- **Pessoa que a coleta mostra na equipe e a declaração diz que saiu.** As duas
  afirmações são verdadeiras em fontes diferentes: o GitHub ainda a lista, a
  organização diz que saiu. **A tela mostra as duas, não escolhe.**
- **Equipe com pessoas dentro, sendo removida.** Remover apagaria vínculos que
  contam para períodos passados.
- **Profundidade.** Uma equipe dentro de outra, dentro de outra — até onde?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Quem administra MUST poder criar uma equipe declarada, com nome, e
  o registro MUST guardar **quem declarou e quando**.
- **FR-002**: A tela MUST distinguir equipe **observada** de **declarada**, e a
  distinção MUST NOT ser carregada apenas por cor.
- **FR-003**: Quem administra MUST poder vincular uma pessoa a uma equipe, com
  papel e data de início, e o vínculo MUST guardar quem o declarou.
- **FR-004**: Quem administra MUST poder registrar que uma pessoa **saiu**,
  informando a data. O vínculo MUST continuar existindo com fim registrado.
- **FR-005**: Registrar a saída MUST NOT alterar nenhum número de período
  anterior à data de saída. **Esta é a diferença entre sair e ser apagado**, e é
  o requisito que decide o desenho.
- **FR-006**: Quem administra MUST poder desfazer um vínculo criado **por
  engano** — aquele que nunca vigeu. O registro do equívoco MUST permanecer, com
  autor e razão. **Nenhuma linha é removida fisicamente.**
- **FR-007**: A plataforma MUST recusar vincular à mesma equipe uma pessoa que já
  tem vínculo vigente ali, dizendo a razão.
- **FR-008**: Quem administra MUST poder declarar que uma equipe faz parte de
  outra, e desfazer essa composição.
- **FR-009**: A plataforma MUST recusar composição que feche **ciclo**, por
  caminho de qualquer comprimento.
- **FR-010**: Toda consulta MUST ser escopada ao tenant. Equipe de uma
  organização MUST NOT aparecer para outra.
- **FR-011**: Nenhuma das ações MUST estar disponível para quem não administra.
- **FR-012**: Quando a coleta e a declaração discordarem sobre uma pessoa estar
  na equipe, a tela MUST mostrar **as duas afirmações**, e MUST NOT escolher uma.

### Key Entities

- **Equipe**: já existe. Ganha origem — observada ou declarada — e a composição.
- **Vínculo de pessoa a equipe**: já existe, com pessoa, equipe, papel, início,
  fim e autor. Ganha o registro de equívoco.
- **Composição entre equipes**: **nova**. Qual equipe faz parte de qual, desde
  quando, declarada por quem.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Quem administra cria uma equipe e vincula três pessoas em **menos
  de 3 minutos**, sem console e sem sair da tela de equipes.
- **SC-002**: **100%** das equipes na lista dizem se foram observadas ou
  declaradas, e a informação sobrevive à leitura sem cor.
- **SC-003**: Um painel que mede um período **anterior** a uma saída mostra
  **exatamente o mesmo número** antes e depois de a saída ser registrada.
- **SC-004**: **100%** das tentativas de fechar ciclo na composição são
  recusadas, incluindo ciclos de comprimento 3 ou mais.
- **SC-005**: **Zero** linhas removidas fisicamente: toda operação de desfazer
  deixa registro com autor e razão, conferível por consulta.
- **SC-006**: Uma pessoa que saiu e voltou aparece com **dois períodos**
  distintos, e a soma do tempo dela na equipe não conta o intervalo em que
  esteve fora.

## Assumptions

- **Quem administra é quem declara.** O papel de administração já existe na
  plataforma (045/052), e esta feature não cria papel novo. Delegar a declaração
  a outros papéis é decisão futura.
- **A saída exige data.** Quando quem registra não souber o dia exato, a data de
  hoje é usada **e marcada como presumida** — ausência não vira zero, e presunção
  não vira fato.
- **Sem limite de profundidade** na composição, com o ciclo proibido. Limite
  arbitrário resolveria um problema que não existe.
- **O rollup de competências fica FORA.** A issue #397 pede a soma das
  competências pela hierarquia; ela depende desta feature e é outra entrega.
  Construir as duas juntas esconderia qual delas quebrou.
- **A coleta continua mandando no que ela vê.** Esta feature não altera equipe
  observada nem apaga o que o GitHub mostrou; ela acrescenta a camada declarada
  ao lado.
- **Fora de escopo**: importar equipes de planilha, convidar pessoa que ainda não
  foi coletada, e notificar alguém sobre a entrada ou saída.
