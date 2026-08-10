# Feature Specification: Pessoas e equipes separadas por organização observada

**Feature Branch**: `002-escopo-por-organizacao`

**Created**: 2026-08-10

**Status**: Draft

**Input**: A plataforma passou a observar mais de uma organização por cliente, e o que ela conhece não diz de qual organização veio. Uma pessoa pode atuar em várias organizações e em várias equipes; uma equipe pertence a uma só organização. A feature entrega esse vínculo preservado, exibido e filtrável.

## Contexto

Operando a feature 001, uma organização cliente passou a observar três
organizações do GitHub. O resultado: **72 pessoas e 10 equipes conhecidas, e
nenhuma delas dizendo de qual organização veio.**

A pergunta que a plataforma existe para responder — "quem trabalha aqui, e onde"
— deixou de ter resposta no momento em que a segunda organização foi conectada.
Não é um detalhe de exibição: sem o vínculo, toda medida futura por organização
some junto, e um número agregado sobre três organizações distintas parece um
número e é uma soma sem sentido.

Ao investigar apareceu uma questão de modelo que muda a solução:

- **A mesma conta aparece em mais de uma organização.** Como a pessoa é
  identificada pela sua origem — sistema, instância e identificador externo —,
  ela é **um registro só**. Um campo único de organização alternaria de valor a
  cada coleta, e a última organização sincronizada apagaria a anterior.
- **Pessoa e equipe é muitos-para-muitos**, e já era: uma pessoa integra várias
  equipes.
- **Equipe e organização é um-para-muitos**: uma equipe pertence a exatamente
  uma organização e não é compartilhada.
- **Vínculo com organização não é alocação.** A ferramenta de origem diz que a
  conta aparece entre os membros; não diz em que função, desde quando, nem sob
  qual vínculo. Tratá-lo como alocação afirmaria o que a origem não afirma.

### O caminho escolhido: a organização da pessoa vem da equipe

**Decisão de projeto**: toda organização observada tem uma equipe com o nome
dela, e todo membro que não integra nenhuma outra equipe pertence a essa. Com
isso, **todo membro está em ao menos uma equipe da organização**, e a organização
de uma pessoa é lida pelas equipes dela.

O que isso evita: um segundo vínculo, direto entre pessoa e organização,
convivendo com o vínculo pela equipe. Dois caminhos para a mesma pergunta podem
discordar, e nada avisaria qual está certo.

O que isso custa: a equipe com o nome da organização **não existe na ferramenta
de origem**. Ela é derivada, e precisa se declarar como tal em todo lugar onde
aparece — senão a plataforma passa a afirmar que existe um time que não existe.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Saber de qual organização veio cada registro (Priority: P1)

Uma pessoa autorizada abre a lista de pessoas e a de equipes e vê, em cada
registro, **a qual organização observada ele pertence**. Onde a mesma pessoa
atua em mais de uma, todas aparecem.

**Why this priority**: sem isso, tudo o que a plataforma sabe sobre três
organizações vira um monte único e não interpretável. É a correção do defeito,
e sem ela as outras duas histórias não têm o que exibir.

**Independent Test**: com duas ou mais organizações coletadas, abrir a lista de
pessoas e conferir que cada linha indica a organização de origem, e que uma
pessoa presente em duas mostra as duas.

**Acceptance Scenarios**:

1. **Given** duas organizações coletadas, **When** o usuário abre a lista de pessoas, **Then** cada pessoa exibe a organização observada de onde veio.
2. **Given** uma conta que aparece em duas organizações, **When** o usuário a consulta, **Then** ela aparece **uma vez** como pessoa, indicando as duas organizações.
3. **Given** duas organizações coletadas, **When** o usuário abre a lista de equipes, **Then** cada equipe exibe a organização a que pertence.
4. **Given** duas organizações com equipes de mesmo identificador curto, **When** ambas são coletadas, **Then** são registradas como equipes distintas, cada uma sob a sua organização.
5. **Given** uma organização conectada e ainda não sincronizada, **When** o usuário abre as listas, **Then** ela aparece sem registros, e o estado vazio diz que a coleta ainda não ocorreu.

---

### User Story 2 - Consultar uma organização de cada vez (Priority: P2)

A pessoa usuária escolhe uma organização observada e vê apenas as pessoas e
equipes dela. As contagens acompanham a escolha.

**Why this priority**: é o que torna o vínculo útil. Ver a origem em cada linha
responde "de onde veio"; filtrar responde "quem é daqui", que é a pergunta que
se faz na prática.

**Independent Test**: filtrar por uma organização e conferir que a quantidade
exibida corresponde ao que aquela organização tem na origem, e que registros das
outras não aparecem.

**Acceptance Scenarios**:

1. **Given** três organizações coletadas, **When** o usuário filtra por uma, **Then** vê apenas pessoas e equipes dela.
2. **Given** um filtro por organização aplicado, **When** o usuário lê a contagem no cabeçalho, **Then** ela corresponde ao que está listado.
3. **Given** um filtro por organização, **When** o usuário o combina com a busca por nome, **Then** os dois se aplicam juntos.
4. **Given** uma pessoa em duas organizações, **When** o usuário filtra por qualquer uma delas, **Then** a pessoa aparece nas duas consultas.
5. **Given** um filtro que não devolve nada, **When** o usuário o aplica, **Then** o estado vazio diz que não há registro **para aquele filtro**, e não que não há coleta.

---

### User Story 3 - Enxergar quem atravessa organizações (Priority: P3)

A pessoa usuária identifica as contas presentes em mais de uma organização
observada, e em quais.

**Why this priority**: é informação que só existe depois das duas anteriores, e
que a organização cliente não tem em nenhuma das ferramentas de origem — cada
uma só enxerga a si mesma. Depende da US1 e da US2.

**Independent Test**: com a mesma conta presente em duas organizações coletadas,
conferir que ela é identificada como tal e que as duas organizações são exibidas.

**Acceptance Scenarios**:

1. **Given** uma conta presente em duas organizações, **When** o usuário consulta as pessoas, **Then** essa condição é visível sem precisar comparar listas manualmente.
2. **Given** uma conta presente em uma só organização, **When** o usuário a consulta, **Then** ela não é sinalizada como sobreposta.
3. **Given** uma conta que deixou de aparecer em uma das organizações, **When** a coleta seguinte ocorre, **Then** o vínculo anterior permanece marcado como não mais observado, e o atual continua ativo.

---

### Edge Cases

- **Mesma pessoa em duas organizações**: um registro de pessoa, dois vínculos observados. A contagem total de pessoas a conta **uma vez**; a contagem por organização a conta em cada uma. Os dois números não somam, e isso está correto.
- **Pessoa removida de uma organização entre coletas**: o vínculo daquela organização é marcado como não mais observado; os demais seguem. Nada é apagado — a plataforma não recebe evento de remoção.
- **Equipes com o mesmo identificador curto em organizações diferentes**: são equipes distintas. O identificador curto de equipe não é único entre organizações.
- **Organização observada removida da coleta**: os registros que ela originou permanecem, com o vínculo marcado como não mais observado. Apagar perderia o histórico que a plataforma existe para preservar.
- **Equipe coletada antes da organização**: não deve ocorrer, mas se ocorrer a equipe fica registrada como pendente de organização e a coleta relata a pendência, em vez de gravar vínculo inventado.
- **Organização sem nenhuma equipe na origem**: todos os seus membros vão para a equipe derivada com o nome da organização.
- **Organização com equipes, e membros fora delas**: só os membros de fora vão para a equipe derivada. Quem já está em equipe observada não é duplicado nela.
- **Organização cujos membros estão todos em equipes observadas**: nenhuma equipe derivada é criada. Criá-la vazia seria registro sem referente.
- **Pessoa que entra numa equipe observada depois de estar na derivada**: sai da derivada na coleta seguinte, e o vínculo anterior fica marcado como não mais observado — nada é apagado.
- **Registros já coletados antes desta feature**: precisam receber o vínculo sem nova consulta à ferramenta de origem.

## Requirements *(mandatory)*

### Vínculo entre pessoa, equipe e organização

- **FR-001**: A plataforma MUST vincular cada equipe a exatamente uma organização observada.
- **FR-002**: A plataforma MUST tratar equipes de organizações diferentes como distintas, ainda que compartilhem identificador curto.
- **FR-003**: A plataforma MUST determinar as organizações de uma pessoa pelas equipes que ela integra, admitindo **mais de uma organização por pessoa**.
- **FR-004**: A plataforma MUST criar, para cada organização observada que tenha ao menos um membro fora de todas as suas equipes, uma equipe com o nome da organização, e MUST vincular esses membros a ela.
- **FR-005**: A equipe criada por FR-004 MUST declarar-se **derivada**, e MUST NOT apresentar-se como observada na origem — ela não tem identificador na ferramenta porque não existe nela.
- **FR-006**: O vínculo de uma pessoa com uma equipe derivada MUST declarar-se derivado, e MUST NOT carregar nível de acesso na plataforma, porque a origem não informa nenhum para ele.
- **FR-007**: A plataforma MUST NOT criar equipe derivada para organização cujos membros já estejam todos em equipes observadas — equipe derivada vazia seria registro sem referente.
- **FR-008**: A plataforma MUST registrar, para cada vínculo entre pessoa e equipe, quando ele foi observado pela primeira vez e pela última vez, e MUST marcar como não mais observado o que deixou de aparecer, sem apagá-lo.
- **FR-009**: A plataforma MUST NOT unificar em um único registro de pessoa contas distintas que apareçam em organizações diferentes; a identidade continua sendo a origem.
- **FR-010**: A plataforma MUST NOT desdobrar uma pessoa em vários registros por ela pertencer a várias organizações ou equipes.
- **FR-011**: As contagens de equipes MUST distinguir as observadas das derivadas, para que a comparação com a ferramenta de origem seja possível sem investigação.

### Base de conhecimento

- **FR-012**: Os mapeamentos semânticos MUST declarar o vínculo entre equipe e organização, e MUST declarar que a organização de uma pessoa é lida pelas equipes dela.
- **FR-013**: A regra de derivação da equipe padrão MUST declarar o que é materializado e o que **não** é, com a razão, como já ocorre para o vínculo com equipe.
- **FR-014**: Os mapeamentos e a regra MUST declarar as limitações — em particular, que a equipe derivada não existe na ferramenta de origem, e que a origem não informa desde quando a conta pertence à organização.

### Consulta e exibição

- **FR-015**: Usuários MUST conseguir ver, em cada pessoa e em cada equipe consultada, a organização observada de origem.
- **FR-016**: Usuários MUST conseguir restringir a consulta de pessoas e de equipes a uma organização observada.
- **FR-017**: A interface MUST identificar a equipe derivada como derivada, sempre que ela aparecer.
- **FR-018**: As contagens exibidas MUST refletir o filtro aplicado, sem exceção.
- **FR-019**: A contagem total de pessoas MUST contar cada pessoa **uma vez**, ainda que ela apareça em várias organizações; as contagens por organização MUST contá-la em cada uma.
- **FR-020**: A plataforma MUST distinguir, na consulta, o estado "nenhuma coleta ocorreu" do estado "nenhum registro corresponde ao filtro".
- **FR-021**: Usuários MUST conseguir identificar as pessoas presentes em mais de uma organização observada, e quais são elas.
- **FR-022**: Toda consulta MUST permanecer restrita à organização cliente do usuário.

### Correção do que já foi coletado

- **FR-023**: A plataforma MUST atribuir o vínculo aos registros já coletados **sem consultar a ferramenta de origem**, a partir do que foi preservado da coleta anterior.
- **FR-024**: A plataforma MUST relatar quantos registros receberam vínculo e quantos permaneceram sem, com o motivo.

## Success Criteria *(mandatory)*

- **SC-001**: 100% das pessoas e das equipes exibidas indicam a organização observada de origem.
- **SC-002**: Com três organizações coletadas, filtrar por uma devolve exatamente o quadro daquela organização, conferido contra a origem.
- **SC-003**: Uma conta presente em duas organizações aparece **uma vez** na lista sem filtro e **em ambas** as listas filtradas.
- **SC-003a**: Nenhuma pessoa conhecida fica sem organização: toda pessoa integra ao menos uma equipe, observada ou derivada.
- **SC-004**: A soma das contagens por organização é maior ou igual à contagem total de pessoas, e a diferença corresponde exatamente ao número de pessoas sobrepostas.
- **SC-005**: Os registros coletados antes desta feature recebem o vínculo sem nenhuma consulta à ferramenta de origem.
- **SC-006**: Uma pessoa removida de uma organização mantém o vínculo com as demais, e o vínculo removido permanece consultável como histórico.
- **SC-007**: Duas equipes de organizações diferentes com o mesmo identificador curto permanecem dois registros distintos.
- **SC-009**: Uma organização cujos membros não estão todos em equipes observadas passa a ter exatamente uma equipe derivada, e nela estão exatamente os membros que faltavam.
- **SC-010**: A contagem de equipes de uma organização, descontadas as derivadas, é igual à quantidade que existe na origem.
- **SC-008**: Um usuário de uma organização cliente não vê, por nenhum caminho, dado de outra — verificado com duas organizações clientes povoadas.

## Assumptions

- **Papel organizacional continua fora de escopo.** O vínculo com organização é evidência, pela mesma razão do vínculo com equipe: a origem não fornece papel. Promovê-lo a alocação é feature própria.
- **Reconciliação de identidade continua fora de escopo.** Duas contas distintas da mesma pessoa permanecem dois registros, ainda que apareçam na mesma organização.
- **A organização observada de cada registro é derivável do que já foi guardado** na coleta anterior, pela ferramenta conectada que originou aquela sincronização. É isso que torna FR-019 possível sem nova consulta.
- **Não existe vínculo direto entre pessoa e organização.** A organização de uma pessoa é lida pelas equipes dela, e a equipe derivada garante que toda pessoa tenha ao menos uma. A alternativa — um segundo vínculo, direto — foi rejeitada por criar dois caminhos para a mesma pergunta, que podem discordar sem que nada avise.
- **A equipe derivada é um artifício desta fonte.** Ele funciona porque no GitHub todo integrante de time também é membro da organização. Uma fonte futura que informe vínculo com a organização sem informar equipes exigirá revisitar esta decisão, e não deve ser acomodada fabricando mais equipes.
- **Nenhuma organização nova precisa ser conectada** para esta feature ser verificável: as três já conectadas bastam.
- **Idioma**: interface e mensagens em português do Brasil.
- **Fora de escopo confirmado**: medidas por organização, hierarquia entre organizações observadas, setores, e promoção do vínculo a alocação formal.
