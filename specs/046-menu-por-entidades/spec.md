# Feature Specification: Menu por entidades

**Feature Branch**: `046-menu-por-entidades`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "Organizar o menu: colocar os menus de sync, tools, roles e outros em uma área de configuração e People, Team, Project, Organization na principal. Work em Settings também."

## O problema

A barra de navegação carrega doze itens numa única linha rolável. Ela já passou de
1.280px num viewport de 1.280 (medido em 2026-08-19), e a história das telas Changes,
Files e Checks — milhares de registros alcançáveis só por URL até ganharem item —
mostra o custo real: **o que não se acha, não existe**. Empilhar mais um item por tela
não escala; a estrutura precisa dizer o que cada coisa é.

A proposta aprovada em protótipo (canvas da spec 045, artboard "Proposta de menu"):
navegação principal com as **entidades** — as mesmas do axioma de acesso da spec 045 —
e todo o resto numa área de **Settings** em três seções nomeadas: Trabalho,
Vocabulário e Operação.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A barra vira entidades + Settings (Priority: P1)

A pessoa logada vê na barra principal: **People**, **Teams**, **Projects**, e o botão
**Settings** (com o menu da conta ao lado). Os demais itens de hoje — Roles, Work,
Changes, Files, Checks, Boards, Process, Syncs, Tools — saem da barra e passam a viver
no menu Settings, agrupados em seções nomeadas: **Trabalho** (Work, com a trilha das
suas visões), **Vocabulário** (Roles) e **Operação** (Syncs, Tools). A seção Operação
só aparece para conta administradora. Nenhuma URL muda: quem tem uma tela nos
favoritos continua chegando nela.

**Why this priority**: é a reorganização em si — o valor pedido. Sem ela, as outras
duas histórias não têm onde morar.

**Independent Test**: logar com uma conta administradora e uma comum; conferir a barra
(3 entidades + Settings), abrir Settings e alcançar cada tela movida; conferir que a
conta comum não vê Operação; abrir cada URL antiga direto e chegar na mesma tela.

**Acceptance Scenarios**:

1. **Given** uma sessão aberta, **When** a pessoa olha a barra principal, **Then** vê
   People, Teams, Projects, Settings e o menu da conta — e nenhum dos outros nove
   itens de hoje.
2. **Given** o menu Settings aberto, **When** a pessoa o percorre, **Then** encontra
   as seções Trabalho (Work), Vocabulário (Roles) e — se for administradora —
   Operação (Syncs, Tools), cada tela alcançável por clique.
3. **Given** uma conta não administradora, **When** ela abre Settings, **Then** a
   seção Operação não existe para ela — nem título, nem itens.
4. **Given** qualquer URL de tela existente hoje (por exemplo a de Changes), **When**
   acessada direto com sessão aberta, **Then** a tela responde como antes — nenhuma
   rota muda nesta feature.
5. **Given** a tela ativa, **When** a pessoa olha a barra, **Then** a área ativa está
   marcada — a entidade correspondente, ou Settings quando a tela mora lá.
6. **Given** um viewport estreito, **When** a barra não cabe, **Then** ela rola dentro
   do próprio contêiner — a página nunca rola de lado (regra existente, preservada).

---

### User Story 2 - Work carrega as suas visões como sub-abas (Priority: P2)

Quem abre Work — pela entrada em Settings ou por URL — encontra, além da tela, uma
navegação secundária com as visões do trabalho: **Issues** (a própria Work),
**Changes**, **Files**, **Checks**, **Boards** e **Process**, com a ativa marcada.
As seis telas de hoje viram irmãs visíveis: um clique entre elas, sem voltar ao menu.

**Why this priority**: Work saiu da barra na US1; sem as sub-abas, alternar entre
Changes e Checks passaria a exigir dois cliques via Settings a cada troca — pior que
hoje. As sub-abas devolvem a adjacência que a barra dava, num lugar melhor.

**Independent Test**: abrir Work, navegar pelas seis sub-abas, conferir a marcação da
ativa em cada uma e que as URLs continuam as de hoje.

**Acceptance Scenarios**:

1. **Given** a tela Work aberta, **When** a pessoa olha abaixo do cabeçalho, **Then**
   vê as sub-abas Issues, Changes, Files, Checks, Boards e Process, com Issues
   marcada.
2. **Given** qualquer uma das seis telas aberta por URL direta, **When** ela renderiza,
   **Then** as mesmas sub-abas aparecem, com a tela atual marcada.
3. **Given** a sub-aba Changes ativa, **When** a pessoa clica em Checks, **Then** chega
   à tela de Checks pela URL de hoje, num clique.

---

### User Story 3 - Tela Organization no menu principal (Priority: P3)

A barra principal ganha **Organization**: a página da organização, que mostra as
organizações do tenant e, para cada uma, as equipes, os projetos e as pessoas
responsáveis. Com zero organizações observadas, a tela diz isso — estado vazio nomeado,
nunca tela em branco.

**Why this priority**: completa o espelho entre menu e entidades do axioma (spec 045).
Vem por último porque é tela nova — as outras duas histórias só movem o que existe.

**Independent Test**: abrir Organization pelo menu, conferir as organizações do tenant
com equipes, projetos e responsáveis; num tenant sem organizações, conferir o estado
vazio nomeado.

**Acceptance Scenarios**:

1. **Given** um tenant com organizações observadas, **When** a pessoa abre
   Organization pela barra, **Then** vê cada organização com suas equipes, seus
   projetos e as pessoas responsáveis, cada item clicável para a página que já existe.
2. **Given** um tenant sem organização observada, **When** a tela abre, **Then** diz
   que não há organização observada e o que alimentaria a tela — nunca uma página em
   branco.
3. **Given** a tela Organization aberta, **When** a pessoa olha a barra, **Then**
   Organization está marcada como área ativa.

---

### Edge Cases

- Conta não administradora acessa a URL de Tools direto: a regra de autorização de
  hoje continua valendo — esta feature move itens de menu, não muda quem pode abrir o
  quê (a spec 045 é quem muda autorização, FR-023 de lá).
- Settings aberto e a pessoa navega: o menu fecha; reabrir mostra o estado da tela
  nova.
- Tela que hoje marca item próprio na barra (por exemplo Roles): a marcação passa a
  ser em Settings — nenhuma tela fica sem indicação de onde está.
- Largura estreita com Settings aberto: o menu cabe na tela ou rola dentro de si;
  nunca provoca rolagem lateral da página.
- Tenant com organizações mas sem equipe nem projeto numa delas: a organização aparece
  com as listas vazias nomeadas ("nenhuma equipe observada"), não some da tela.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A barra principal MUST conter exatamente People, Teams, Projects,
  Organization (quando a US3 entregar a tela), o acesso a Settings e o menu da conta —
  e MUST NOT conter os demais itens de hoje.
- **FR-002**: Settings MUST agrupar as telas movidas em três seções nomeadas —
  Trabalho (Work), Vocabulário (Roles), Operação (Syncs, Tools) — cada tela alcançável
  por clique.
- **FR-003**: A seção Operação MUST aparecer apenas para conta administradora (o
  gating vigente de menu, que hoje já esconde Tools de quem não é admin, estende-se a
  Syncs dentro de Settings). Autorização de rota não muda nesta feature.
- **FR-004**: Nenhuma URL de tela existente MUST mudar; toda tela de hoje MUST
  continuar respondendo na mesma rota.
- **FR-005**: As telas de trabalho — Work, Changes, Files, Checks, Boards, Process —
  MUST exibir navegação secundária comum (sub-abas) com a tela ativa marcada, e cada
  sub-aba MUST levar à rota que a tela já tem.
- **FR-006**: A barra MUST marcar a área ativa: a entidade correspondente à tela, ou
  Settings quando a tela mora nele.
- **FR-007**: A tela Organization MUST listar as organizações do tenant e, por
  organização, as equipes, os projetos e as pessoas responsáveis — com estado vazio
  nomeado em cada nível (sem organização; organização sem equipe; sem projeto; sem
  responsável).
- **FR-008**: Conteúdo largo (a barra, o menu Settings) MUST rolar dentro do próprio
  contêiner; a página MUST NOT rolar lateralmente (regra existente, preservada).

### Key Entities

- **Área de navegação**: Principal (entidades: People, Teams, Projects, Organization),
  Settings (Trabalho, Vocabulário, Operação), Conta. Estrutura de menu — não altera
  domínio.
- **Página da organização**: leitura do que já existe — organizações do tenant,
  equipes, projetos, responsáveis — nenhum dado novo, nenhuma escrita.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A barra principal tem no máximo 4 itens de navegação + Settings + conta,
  em qualquer tela — contra 12 de hoje.
- **SC-002**: 100% das telas de hoje continuam alcançáveis por clique em no máximo 2
  passos (Settings → item, ou entidade direta), e 100% das URLs atuais respondem
  inalteradas.
- **SC-003**: Conta não administradora vê 0 entradas de Operação (Syncs, Tools) em
  qualquer menu.
- **SC-004**: Navegar entre duas visões de trabalho (por exemplo Changes → Checks)
  custa exatamente 1 clique.
- **SC-005**: Em viewport de 1.280px, 0 rolagem lateral da página em todas as telas.
- **SC-006**: Num tenant povoado, a tela Organization exibe 100% das organizações
  observadas com suas equipes, projetos e responsáveis; num tenant vazio, exibe o
  estado vazio nomeado.

## Assumptions

- **Autorização não muda aqui.** Esta feature reorganiza menu e adiciona uma tela de
  leitura. Quem pode abrir o quê continua como está; a spec 045 (FR-023) é quem
  amplia o gating de Operação para o escopo organization quando for implementada — e
  aí a condição de exibição da seção passa de "administrador" para "administrador ou
  organization" sem mudar a estrutura desta feature.
- **AI não é item de menu.** Desde a issue #428, IA é aba de Tools e geração é aba de
  Syncs — esta feature preserva isso; Operação lista só Syncs e Tools.
- **Access scopes (spec 045) morará em Settings › Vocabulário** quando existir; esta
  feature cria a seção, não a tela.
- **A tela Organization é leitura do que a EO já responde** (organizações, equipes,
  projetos, responsáveis) — nenhum conceito ontológico novo, nenhuma migração.
- **O toggle de tema permanece onde está**, junto ao menu da conta.
