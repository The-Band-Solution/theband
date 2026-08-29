# Feature Specification: Contas — cadastrar pessoas e associar o GitHub

**Feature Branch**: `051-cadastro-por-github`

**Created**: 2026-08-29 (reescrita no mesmo dia por instrução: pessoa primeiro —
nome e e-mail — e a associação do GitHub vivendo na própria área)

**Status**: Draft

**Input**: User description: "Cria uma área administrativa para eu cadastrar
usuários por e-mail ou id do GitHub. Quero uma área no account que eu consiga
cadastrar as pessoas e associar contas do GitHub — dados da pessoa: nome, e-mail."

## O problema

Cadastrar alguém hoje é um trabalho em DOIS lugares: quem administra cria a conta em
`/accounts` (nome, e-mail, temporária mostrada uma vez — feature 045) e depois vai à
**página da pessoa** declarar o elo conta↔pessoa do GitHub. O segundo passo é
esquecível e caro: sem o elo, a pessoa não entra pelo username do GitHub, não tem o
escopo person sobre si mesma, e os painéis não a reconhecem. A plataforma já sabe
quem existe no GitHub — 88 pessoas coletadas, todas com identidade estável
(`external_id`) — e mesmo assim a associação mora longe do cadastro.

O pedido: **uma área só** (`/accounts`) onde quem administra cadastra a pessoa —
nome e e-mail — e associa a conta do GitHub dela, no mesmo lugar.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cadastrar a pessoa: nome e e-mail (Priority: P1)

Quem administra abre `/accounts` e cadastra uma pessoa com **nome** e **e-mail** —
os dois dados do pedido. A conta de acesso nasce desse cadastro, com a senha
temporária mostrada uma única vez e a troca forçada no primeiro acesso (fluxo da
045, intacto). É o caminho de hoje, que permanece — a feature não o move, o
completa.

**Why this priority**: é a metade "cadastrar as pessoas" do pedido, e é a base da
outra metade.

**Independent Test**: cadastrar nome+e-mail; entrar com o e-mail e a temporária;
ser levado a definir senha.

**Acceptance Scenarios**:

1. **Given** `/accounts` aberto por quem administra, **When** cadastra nome e
   e-mail, **Then** a conta existe e a temporária aparece uma única vez.
2. **Given** um e-mail já usado, **When** o cadastro tenta, **Then** recusa nomeando
   o conflito, sem criar nada.
3. **Given** quem não administra, **When** tenta alcançar a área, **Then** a recusa
   existente de `/accounts` vale — nada afrouxa.

---

### User Story 2 - Associar a conta do GitHub, na mesma área (Priority: P1)

Na linha de cada pessoa cadastrada em `/accounts`, quem administra **associa a conta
do GitHub**: busca entre as pessoas coletadas (por nome ou login), escolhe, e o elo
nasce pela **identidade estável** (o id do GitHub, nunca o login mutável — decisão
da 049). A associação fica visível na própria lista — quem tem GitHub associado e
quem não tem —, e é revogável ali. Do momento da associação em diante, a pessoa
entra também pelo username do GitHub, e os painéis dela a reconhecem (escopo
person).

**Why this priority**: é a metade "associar contas do GitHub" do pedido — e é ela
que mata o passo esquecível na página da pessoa.

**Independent Test**: cadastrar alguém (US1), associar o GitHub na mesma tela,
entrar com o username do GitHub e a temporária.

**Acceptance Scenarios**:

1. **Given** uma conta cadastrada sem GitHub, **When** quem administra busca uma
   pessoa coletada e associa, **Then** o elo vigente aponta para aquela identidade
   estável, e a lista mostra a associação.
2. **Given** a associação feita, **When** a pessoa entra com o **username do
   GitHub**, **Then** entra — mesmo fluxo, mesma senha.
3. **Given** uma pessoa do GitHub JÁ associada a outra conta, **When** a associação
   tenta, **Then** recusa dizendo qual conta já a tem — um elo vigente por pessoa
   (invariante da 045).
4. **Given** uma associação vigente, **When** quem administra a revoga na área,
   **Then** o elo fecha (a história fica), e a pessoa volta a entrar só pelo e-mail.
5. **Given** o cadastro e a associação feitos em sequência na mesma área, **When** a
   segunda parte falha, **Then** a conta permanece íntegra e a falha é dita — nada
   nasce pela metade em silêncio.

---

### Edge Cases

- Busca de pessoa coletada com 0 resultados: ausência nomeada ("nenhuma pessoa
  coletada bate com…"), nunca lista vazia muda. Quem ainda não foi coletado é
  associável só depois da coleta trazê-lo — a plataforma só fala do que observa.
- Duas pessoas coletadas com o mesmo nome: a busca mostra login e organização de
  cada uma — quem administra decide pelo identificador, nunca a plataforma pelo
  nome ([[padrao-largo-inventa-mais]]).
- Pessoa coletada cuja observação terminou: associável — gente sai do GitHub sem
  sair da organização; a tela diz que a observação terminou.
- A página da pessoa continua mostrando o elo (é dela também); esta feature muda
  ONDE se administra, não onde se lê.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `/accounts` MUST cadastrar pessoa com **nome** e **e-mail** — os dois
  obrigatórios; o fluxo da temporária (045) MUST permanecer intacto.
- **FR-002**: `/accounts` MUST associar a conta do GitHub de cada pessoa cadastrada,
  com busca entre as pessoas coletadas por nome e login; o elo MUST usar a
  identidade estável (`external_id`), nunca o login mutável.
- **FR-003**: A lista de contas MUST mostrar quem tem GitHub associado (com o login
  observado) e quem não tem — ausência nomeada, nunca coluna vazia.
- **FR-004**: A associação MUST ser revogável na própria área; revogar fecha o elo
  (a história fica) e MUST NOT apagar nada.
- **FR-005**: Pessoa do GitHub com elo vigente MUST ser recusada para nova
  associação, nomeando a conta que já a tem.
- **FR-006**: E-mail duplicado MUST ser recusado sem criar nada.
- **FR-007**: A área inteira MUST permanecer restrita a administração, com a recusa
  existente.
- **FR-008**: O invariante de login da 045 MUST não mudar: e-mail sempre; username
  do GitHub quando (e enquanto) houver elo vigente.

### Key Entities

Nenhuma nova. A conta (nome, e-mail) e o elo conta↔pessoa já existem (045); a
feature muda **onde** o elo se administra (junto do cadastro) e **quando** ele pode
nascer (na sequência do cadastro, na mesma área).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Cadastrar alguém e deixá-lo entrando pelo username do GitHub leva UM
  fluxo numa tela só — zero visitas à página da pessoa.
- **SC-002**: A lista de `/accounts` responde "quem tem GitHub associado?" de uma
  olhada — 100% das linhas dizem associado (com o login) ou não associado.
- **SC-003**: O teste da violação passa: associar pessoa já vinculada e cadastrar
  e-mail duplicado recusam sem criar nada (contagens de contas e elos inalteradas).
- **SC-004**: Revogar na área e a pessoa continua entrando pelo e-mail — e não mais
  pelo username — no ato seguinte.

## Assumptions

- **A área é `/accounts`** — o pedido diz "área no account"; a tela existe e a
  feature a completa (princípio X: a coisa dela é contas).
- **"Conta do GitHub" = pessoa coletada** — a associação escolhe entre as
  identidades que a plataforma observou (88/88 com identidade estável). Digitar um
  id à mão criaria elo com o que nunca foi visto.
- **Cadastrar pessoa = cadastrar a conta dela** — nome e e-mail são dados da conta
  (045); não nasce entidade "pessoa declarada" separada do registro coletado: a
  pessoa organizacional É a coletada, e a conta aponta para ela pelo elo. Criar uma
  segunda noção de pessoa duplicaria identidade sem problema que o exija
  (princípio VIII).
- **Recuperação de senha segue administrativa** (assumption da 045, inalterada).
- **A 049 (entrar COM o GitHub, OAuth) é outra feature** — esta associa identidades
  a contas locais; aquela autentica no GitHub. Mesma identidade estável, atos
  diferentes.
