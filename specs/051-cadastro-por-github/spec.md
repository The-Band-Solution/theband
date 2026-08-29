# Feature Specification: Cadastrar contas pela pessoa do GitHub

**Feature Branch**: `051-cadastro-por-github`

**Created**: 2026-08-29

**Status**: Draft

**Input**: User description: "Cria uma área administrativa para eu cadastrar usuários
por e-mail ou id do GitHub."

## O problema

Cadastrar alguém hoje é um trabalho em DOIS lugares: quem administra cria a conta em
`/accounts` (e-mail, nome, temporária mostrada uma vez — feature 045) e depois vai à
página da pessoa declarar o elo conta↔pessoa. Esquecer o segundo passo é fácil e
caro: sem o elo, a pessoa não entra pelo username do GitHub, não tem o escopo person
sobre si mesma, e os painéis dela não a reconhecem. A plataforma já sabe quem existe
— 88 pessoas coletadas, todas com identidade estável do GitHub (`external_id`) — e
mesmo assim quem administra digita identidades à mão.

A área administrativa que o pedido nomeia JÁ existe (`/accounts`); o que falta é ela
cadastrar **a partir da pessoa do GitHub**, com o elo nascendo declarado no mesmo ato.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cadastrar escolhendo a pessoa do GitHub (Priority: P1)

Quem administra abre `/accounts` e cadastra uma conta escolhendo **uma pessoa já
coletada** (busca por nome ou login do GitHub). O e-mail continua obrigatório — o
GitHub escolhe QUEM, o e-mail identifica a conta (decisão de 2026-08-29). A conta
nasce com o elo conta↔pessoa **já declarado**, pela identidade estável (o id do
GitHub, nunca o login mutável — decisão da 049), e a senha temporária aparece uma
única vez, como hoje. A pessoa entra por e-mail OU pelo username do GitHub, no
primeiro minuto.

**Why this priority**: é o pedido — e mata o passo esquecível que deixa conta sem
elo.

**Independent Test**: cadastrar escolhendo uma pessoa coletada; entrar com o
username do GitHub dela e a temporária; ver o escopo person funcionando sobre a
própria página.

**Acceptance Scenarios**:

1. **Given** `/accounts` aberto por quem administra, **When** cadastra escolhendo
   uma pessoa coletada (busca por nome/login) e informando e-mail, **Then** a conta
   existe, o elo vigente aponta para aquela pessoa pela identidade estável, e a
   temporária aparece uma única vez.
2. **Given** a conta recém-criada, **When** a pessoa entra com o **username do
   GitHub** e a temporária, **Then** entra e é levada a definir senha (fluxo da 045
   intacto).
3. **Given** uma pessoa que JÁ tem conta vinculada vigente, **When** quem administra
   tenta cadastrar de novo por ela, **Then** recusa dizendo qual conta já a tem — um
   elo vigente por pessoa (invariante da 045).
4. **Given** um e-mail já usado por outra conta, **When** o cadastro tenta, **Then**
   recusa nomeando o conflito — nada é criado pela metade (nem conta sem elo, nem
   elo sem conta).
5. **Given** quem olha não é administrador, **When** tenta alcançar o cadastro,
   **Then** a recusa é a mesma de hoje em `/accounts` — nada desta feature afrouxa
   o acesso.

---

### User Story 2 - O cadastro por e-mail continua, e diz quando a pessoa existe (Priority: P2)

O caminho de hoje (e-mail + nome, sem pessoa) continua existindo — nem toda conta é
de alguém coletado. Mas quando o e-mail ou o nome digitado **bate com uma pessoa
coletada sem conta**, a tela oferece o vínculo antes de criar: "essa pessoa existe —
cadastrar já vinculando?". Oferecer, nunca decidir: nome parecido não é identidade
([[padrao-largo-inventa-mais]] — o reconhecido errado vira medida).

**Why this priority**: preserva o fluxo existente e reduz a conta órfã sem
adivinhar.

**Independent Test**: cadastrar por e-mail um nome que coincide com pessoa coletada
→ a oferta aparece; recusar a oferta → conta nasce sem elo, como hoje.

**Acceptance Scenarios**:

1. **Given** cadastro por e-mail com nome/e-mail que não bate com ninguém, **When**
   cria, **Then** conta nasce sem elo — exatamente o comportamento de hoje.
2. **Given** o texto digitado batendo com pessoa coletada sem conta, **When** a tela
   percebe, **Then** OFERECE o vínculo nomeando a pessoa — e só vincula se quem
   administra escolher.
3. **Given** a oferta recusada, **When** a conta é criada, **Then** nasce sem elo, e
   nada registra a pessoa como vinculada.

---

### Edge Cases

- Pessoa coletada cuja observação terminou (`no_longer_observed_at`): pode ser
  escolhida — a conta é de gente, e gente sai do GitHub sem sair da organização; a
  tela diz que a observação terminou.
- Busca com 0 resultados: ausência nomeada ("nenhuma pessoa coletada bate com…"),
  nunca lista vazia muda.
- Duas pessoas com o mesmo nome: a busca mostra o login e a organização de cada uma
  — quem administra decide pelo identificador, nunca a plataforma pelo nome.
- O cadastro falha DEPOIS de validar (e-mail duplicado numa corrida): conta e elo
  nascem juntos ou nada nasce — nunca metade.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `/accounts` MUST oferecer cadastro escolhendo uma pessoa coletada, com
  busca por nome e login; a escolha carrega a identidade estável do GitHub
  (`external_id`), nunca o login mutável.
- **FR-002**: O e-mail MUST continuar obrigatório em todo cadastro (decisão de
  2026-08-29) — o invariante de login da 045 (e-mail OU username via elo) não muda.
- **FR-003**: No cadastro pela pessoa, conta e elo MUST nascer no mesmo ato — tudo
  ou nada; falha em qualquer parte não deixa metade criada.
- **FR-004**: Pessoa com elo vigente MUST ser recusada para novo cadastro, nomeando
  a conta que já a tem (um elo vigente por pessoa).
- **FR-005**: O cadastro por e-mail sem pessoa MUST continuar funcionando como hoje;
  quando o digitado bater com pessoa coletada sem conta, a tela MUST oferecer o
  vínculo — e MUST NOT vincular sem escolha explícita.
- **FR-006**: A senha temporária MUST seguir o fluxo da 045: mostrada uma única vez,
  troca forçada no primeiro acesso.
- **FR-007**: Toda a área MUST permanecer restrita a administração, com a recusa
  existente.

### Key Entities

Nenhuma nova. O elo conta↔pessoa já existe (045); a feature muda **quando** ele
nasce (junto do cadastro), não **o que** ele é.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Cadastrar alguém coletado e ele entrar pelo username do GitHub leva
  UM fluxo numa tela só — zero visitas à página da pessoa para vincular.
- **SC-002**: 100% dos cadastros pela pessoa produzem conta+elo juntos — auditável:
  nenhuma conta criada por esse caminho sem elo vigente.
- **SC-003**: O teste da violação passa: tentar cadastrar por pessoa já vinculada, e
  por e-mail duplicado, recusa sem criar nada (contagens de contas e elos
  inalteradas).
- **SC-004**: O fluxo antigo por e-mail permanece byte-idêntico quando nada bate com
  pessoa coletada.

## Assumptions

- **A área é `/accounts`** — o pedido diz "área administrativa", e ela já existe;
  criar outra violaria o princípio X (telas fazem uma coisa; a coisa de /accounts é
  contas).
- **Só pessoas coletadas entram na busca** — a plataforma só fala do que observa;
  cadastrar por um id do GitHub que ela nunca viu criaria elo com o nada. Quem ainda
  não foi coletado entra pelo caminho de e-mail e é vinculado quando a coleta o
  trouxer.
- **Recuperação de senha segue administrativa** (assumption da 045, inalterada).
- **A 049 (entrar COM o GitHub, OAuth) é outra feature** — esta cadastra contas
  locais apontando para identidades do GitHub; aquela autentica NO GitHub. As duas
  usam a mesma identidade estável, de propósito.
