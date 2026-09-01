# Feature Specification: Entrar com o GitHub

**Feature Branch**: `049-entrar-com-github`

**Created**: 2026-08-28

**Status**: Draft — **pedida de novo em 2026-09-01**, com a plataforma já em
produção. Sai do backlog; pronta para `/speckit-plan`.

**Input**: User description: "É possível pensar no sign up/sign in com o GitHub? Ao
logar, já associar a pessoa à pessoa que já puxamos."

## O problema

A feature 045 fechou a porta com identificador e senha, e deixou dois atritos
deliberados: cadastro é ato administrativo (quem administra cria a conta e entrega a
senha temporária), e o elo conta↔pessoa observada é declaração manual. Para uma
organização com dezenas de pessoas observadas, isso é uma fila de trabalho — criar
conta, entregar senha, declarar elo — para provar algo que o GitHub pode provar
sozinho: **quem entra pelo OAuth do GitHub demonstrou ser dono da conta que a coleta
observou**. As 88 pessoas do piloto têm o identificador do GitHub (88/88 com
`external_id`); o casamento é por identidade exata, nunca por nome.

O axioma continua mandando: *a pessoa tem acesso aos dados com os quais está
relacionada*. Esta feature só troca a PROVA da relação — de declaração manual para
demonstração criptográfica via OAuth — e o resto (piso person, escopos derivados,
concessões) já funciona a partir do elo.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Entrar com o GitHub (Priority: P1)

A tela de entrada ganha o botão "Sign in with GitHub". Quem clica autoriza no GitHub
e volta logado — sem senha — desde que exista conta cujo elo aponte para a pessoa
observada com aquele identificador do GitHub. A entrada por identificador+senha
continua exatamente como está: são duas portas para a mesma conta.

**Why this priority**: é a metade sem risco — nenhuma conta nasce, nenhum elo muda;
só uma prova nova para uma relação que já existe.

**Independent Test**: conta com elo vigente para uma pessoa observada entra pelo
botão; conta sem elo não entra por esse caminho; a recusa nomeia.

**Acceptance Scenarios**:

1. **Given** conta com elo vigente para a pessoa observada X, **When** a pessoa
   autoriza no GitHub como dona da conta X, **Then** a sessão abre — mesma sessão,
   mesmo token versionado, mesmas regras de expiração da 045.
2. **Given** autorização no GitHub de alguém cujo identificador não casa com pessoa
   observada de tenant nenhum, **When** o retorno chega, **Then** a entrada é
   recusada com o motivo ("nenhuma organização observada te observa") — sem criar
   nada.
3. **Given** a pessoa nega a autorização no GitHub, **When** volta à plataforma,
   **Then** a tela de entrada explica que nada foi autorizado e nada mudou.
4. **Given** conta com senha E GitHub, **When** entra por qualquer das duas portas,
   **Then** é a mesma conta, a mesma sessão, os mesmos escopos.

---

### User Story 2 - A conta nasce sozinha para quem a organização observa (Priority: P2)

Pessoa observada que ainda NÃO tem conta entra pelo GitHub e a conta nasce na hora:
no tenant que a observa, com o elo já declarado — proveniência registrada como
"demonstrado por OAuth", não como declaração de administrador — e o e-mail vindo do
GitHub. O piso person e os escopos derivados valem imediatamente: a pessoa vê o
próprio painel e o das relações dela no primeiro minuto, sem fila administrativa.

**Why this priority**: é o sign up pedido — mata a fila de criar conta + entregar
senha + declarar elo para quem a organização já observa.

**Independent Test**: pessoa observada sem conta entra pelo GitHub → conta criada,
elo vigente com proveniência OAuth, painel próprio acessível; pessoa NÃO observada →
nada criado, recusa nomeada.

**Acceptance Scenarios**:

1. **Given** pessoa observada no tenant T sem conta, **When** autoriza no GitHub,
   **Then** a conta nasce em T com o elo declarado (proveniência: OAuth, com data) e
   a sessão abre — e a tela de contas mostra a conta com a origem "entrou pelo
   GitHub".
2. **Given** pessoa cujo identificador é observado em MAIS de um tenant, **When**
   entra pela primeira vez, **Then** escolhe em qual organização está entrando; a
   conta nasce só ali (entrar nos demais permanece ato administrativo — limitação
   declarada).
3. **Given** o elo daquela pessoa observada já pertence a OUTRA conta vigente,
   **When** alguém autoriza no GitHub como ela, **Then** nada nasce e a recusa diz
   que a pessoa já tem conta — o caminho é quem administra resolver.
4. **Given** conta nascida por OAuth (sem senha), **When** tenta entrar por
   identificador+senha, **Then** recebe a recusa única da 045 — senha só depois de
   definida em /profile; a conta OAuth-sem-senha NÃO é a "conta pré-045 recusada":
   ela entra pelo GitHub.

---

### User Story 3 - Conectar o GitHub a uma conta que já existe (Priority: P3)

Quem já tem conta (com senha) conecta o GitHub pelo /profile: autoriza, e se o
identificador casa com a pessoa do SEU elo vigente, a porta OAuth passa a valer para
a conta. Se a conta não tem elo, a autorização DECLARA o elo (mesma prova da US2) —
e o que era manual vira demonstrado.

**Why this priority**: fecha o ciclo para as contas criadas na 045; vem por último
porque as duas primeiras entregam o valor maior.

**Acceptance Scenarios**:

1. **Given** conta com elo para a pessoa X, **When** conecta o GitHub e a
   autorização volta como X, **Then** a porta OAuth vale — e /profile mostra as duas
   portas.
2. **Given** conta com elo para X, **When** a autorização volta como OUTRA pessoa Y,
   **Then** nada muda e a recusa explica: a conta é de X; trocar o elo é ato
   administrativo.
3. **Given** conta sem elo, **When** conecta o GitHub e o identificador casa com
   pessoa observada sem conta, **Then** o elo nasce com proveniência OAuth.

---

### Edge Cases

- **Elo revogado depois** de a conta ter nascido por OAuth: a porta GitHub fecha
  junto (a prova era o elo); com senha definida, a porta de senha continua.
- **GitHub sem e-mail público/verificado** no sign up: a conta nasce e o primeiro
  acesso exige definir e-mail (identidade de entrada da 045) antes de qualquer tela
  — mesma mecânica do must_change_password.
- **E-mail do GitHub já usado por outra conta**: o sign up recusa nomeando o
  conflito — e-mail é único global (invariante da 045).
- **Renomeação de usuário no GitHub**: irrelevante — o casamento é pelo identificador
  estável, não pelo login.
- **Autorização órfã** (retorno sem estado correspondente, replay): recusada; o
  fluxo usa proteção padrão de OAuth contra replay/CSRF.
- **Tenant sem ninguém observado**: o botão existe e a recusa da US1/2 explica o que
  alimentaria a entrada.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A tela de entrada MUST oferecer "Sign in with GitHub" ao lado da
  entrada por identificador+senha; nenhuma das duas portas MUST remover a outra.
- **FR-002**: O casamento pessoa↔autorização MUST usar o identificador estável do
  GitHub que a coleta registra — nunca login, nome ou e-mail.
- **FR-003**: Entrada por OAuth MUST exigir elo vigente (US1) ou criá-lo com
  proveniência própria e nomeada — "demonstrado por OAuth do GitHub", com data —
  distinta da declaração administrativa (US2/US3). Elo continua revogável; revogado,
  a porta OAuth fecha.
- **FR-004**: Sign up por OAuth MUST criar conta apenas para pessoa observada, no
  tenant que a observa, sem marca de administrador e sem concessão nenhuma — o
  acesso inicial é o piso e os derivados do elo.
- **FR-005**: Toda recusa do fluxo MUST nomear o motivo (não observado; pessoa já
  tem conta; autorização negada; e-mail em conflito) — e o fluxo MUST ser imune a
  replay/CSRF pelo mecanismo padrão de OAuth.
- **FR-006**: A sessão aberta por OAuth MUST ser a mesma da 045 — token versionado,
  expiração, derrubada por troca de senha; nenhuma sessão paralela.
- **FR-007**: A credencial do aplicativo OAuth MUST viver no ambiente da plataforma
  (como a chave mestra), nunca em tenant, YAML ou repositório.
- **FR-009** (2026-09-01): A conta que entra pelo OAuth MUST enxergar, no primeiro
  minuto e sem concessão nenhuma, **a própria pessoa, as equipes de que participa e
  os projetos em que está**. Isto não é feature nova: `Tenants.Access` já deriva
  `piso ++ derivados_team ++ derivados_project ++ concedidos` a partir do elo
  vigente, e escopo derivado **nunca se grava** — é leitura das relações do momento.
  O requisito existe para que a entrega seja verificada por esse critério, e não
  pela suposição de que o elo basta.
- **FR-008**: /accounts MUST mostrar a origem de cada conta (administrativa ou
  GitHub) e a proveniência do elo (declarado ou demonstrado).

### Key Entities

- **Porta OAuth da conta**: o vínculo conta↔identidade GitHub demonstrada, com
  quando e por qual fluxo. Não substitui o elo — prova-o.
- **Elo com proveniência OAuth**: o mesmo elo da #369, com origem "demonstrado"
  em vez de "declarado por alguém".

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Pessoa observada sem conta entra do zero — clique, autorização, painel
  próprio — em menos de 1 minuto, sem nenhum ato administrativo.
- **SC-002**: 0 contas criadas para identificadores não observados, em qualquer
  tentativa.
- **SC-003**: 100% dos elos criados por OAuth exibem a proveniência "demonstrado",
  distinta da declaração manual, em /accounts e /profile.
- **SC-004**: As invariantes da 045 permanecem: recusa única na porta de senha,
  sessão única versionada, e-mail único — suítes existentes passam sem afrouxar.

## Por que ela volta agora (2026-09-01)

A plataforma entrou em produção nesta madrugada, e a primeira conta passou a nascer
de variáveis de ambiente (feature 052). Isso resolve **uma** conta — a de quem
instala. As outras continuam pela fila administrativa que esta spec existe para
eliminar: criar conta, entregar senha temporária, declarar o elo, uma pessoa por vez.

Com 88 pessoas observadas no piloto, todas com identificador do GitHub, a fila é o
gargalo entre "a plataforma está no ar" e "a organização usa a plataforma".

E o custo de não ter isto ficou concreto: a senha do primeiro administrador precisou
passar pelo painel de quem hospeda, e a recomendação de removê-la depois é
procedimento que alguém pode esquecer. Entrada por OAuth não tem senha para vazar.

## Assumptions

- **O identificador estável existe para todos**: medido no piloto, 88/88 pessoas com
  o id do GitHub. Pessoa futura sem id não casa e cai na recusa nomeada.
- **Aplicativo OAuth único da plataforma** (env), não por tenant — o tenant é
  descoberto pela pessoa observada, não pela credencial.
- **Cadastro administrativo continua existindo** — para quem não é pessoa observada
  (diretoria sem conta GitHub observada, por exemplo). A 049 não o substitui;
  remove a fila para quem o GitHub prova.
- **Não entra no sprint 023** — especificada durante ele e contida no backlog.
  Depende da 045 mergeada (portas, sessão, elo) — já verdadeiro. Candidata forte a
  acompanhar o sprint de produção: em produção, entregar senha temporária por canal
  próprio é atrito real; o OAuth o elimina para a maioria.
