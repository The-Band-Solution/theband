# Feature Specification: A primeira conta nasce do ambiente

**Feature Branch**: `052-primeira-conta-do-ambiente`

**Created**: 2026-09-01

**Status**: Draft

**Input**: User description: "A primeira conta nasce do ambiente: quando a plataforma sobe com o banco vazio, ela cria a organização e o primeiro administrador a partir de quatro variáveis de ambiente (nome e slug da organização, e-mail e senha da pessoa), e só quando não existe administrador nenhum. Roda em todo boot, logo depois das migrações, e não faz nada quando já foi feito. Variável ausente não derruba o contêiner — a plataforma sobe vazia dizendo no log qual variável faltou. A senha nunca aparece em log nem em argumento de comando."

## O problema, medido

A produção subiu em 2026-09-01 às 01:25 e **ninguém consegue entrar**. As
migrações rodaram, o endpoint respondeu, `/sign-in` devolveu 200 — e o banco tem
zero contas. A plataforma está no ar e é inacessível.

Não é descuido: é o desenho funcionando ao contrário. O `seeds.exs` **levanta em
produção de propósito** (senha padrão conhecida seria a porta aberta que a
feature 045 existe para fechar), e o caminho normal de criar conta — `/accounts`,
com senha temporária gerada por quem administra — pressupõe que já exista alguém
administrando. Numa instalação nova não existe.

O que sobrou é um passo manual que o runbook não descreve: abrir um console
dentro do contêiner e colar quatro linhas de Elixir. Isso tem três defeitos.
Depende de achar um terminal — a sessão de 2026-09-01 gastou tempo justamente
nisso. Não deixa registro de que foi feito nem de como. E some da memória: se a
produção for recriada em seis meses, ninguém lembra do comando.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Instalar sem console (Priority: P1)

Quem implanta a plataforma pela primeira vez preenche quatro variáveis no painel
de quem hospeda, aperta implantar, e entra pela tela de entrada com o e-mail e a
senha que acabou de escolher. Nenhum console, nenhum comando, nenhuma linha de
código colada em lugar nenhum.

**Why this priority**: é a feature inteira. Sem ela, uma instalação nova é
inacessível até alguém com conhecimento desta conversa intervir manualmente.

**Independent Test**: subir a plataforma contra um banco vazio, com as quatro
variáveis definidas, e entrar pela tela de entrada usando aquelas credenciais.

**Acceptance Scenarios**:

1. **Given** um banco sem nenhuma conta e as quatro variáveis definidas, **When**
   a plataforma sobe, **Then** existem uma organização e uma pessoa com a marca de
   administração, e o log diz o e-mail e a organização criados.
2. **Given** a plataforma subiu no cenário 1, **When** quem instalou abre a tela
   de entrada e informa aquele e-mail e aquela senha, **Then** a sessão abre e a
   pessoa vê a plataforma com poder de administração.
3. **Given** um banco sem nenhuma conta e as quatro variáveis definidas, **When**
   a plataforma sobe, **Then** a senha NÃO aparece em nenhuma linha do log.

---

### User Story 2 - Reiniciar não duplica nem sobrescreve (Priority: P1)

Quem opera reinicia o contêiner — por atualização, por queda, por dez vezes numa
madrugada. Nada é criado de novo, nenhuma senha é sobrescrita, e o log diz que
não havia o que fazer.

**Why this priority**: mesma prioridade da US1 porque a criação roda em todo
boot. Sem essa garantia, a US1 introduz um defeito pior que o problema que
resolve — uma senha do painel voltando a valer depois de trocada pela interface.

**Independent Test**: subir a plataforma duas vezes seguidas com as mesmas
variáveis e conferir que a segunda não altera conta alguma.

**Acceptance Scenarios**:

1. **Given** uma plataforma que já tem administrador, **When** ela sobe de novo
   com as mesmas variáveis, **Then** nenhuma conta é criada nem alterada, e o log
   diz que já existe administrador.
2. **Given** uma plataforma cujo administrador trocou a própria senha pela
   interface, **When** ela sobe de novo com a variável de senha ainda no valor
   antigo, **Then** a senha em vigor continua sendo a que a pessoa escolheu.
3. **Given** uma plataforma que já tem administrador, **When** ela sobe com um
   e-mail DIFERENTE nas variáveis, **Then** nenhuma segunda conta é criada — a
   verificação é "existe algum administrador", e não "existe este e-mail".

---

### User Story 3 - A ausência é dita, e não derruba (Priority: P2)

Quem opera sobe a plataforma sem definir as variáveis — porque está restaurando
um banco existente, porque vai criar as contas de outro jeito, ou porque
esqueceu. A plataforma sobe normalmente e diz no log, nomeando, qual variável
faltou.

**Why this priority**: P2 porque a US1 já entrega valor sem ela. Mas sem esta, a
US1 transforma uma variável esquecida em produção fora do ar, o que é pior que o
problema original.

**Independent Test**: subir a plataforma contra um banco vazio sem nenhuma das
variáveis e conferir que ela atende requisições normalmente.

**Acceptance Scenarios**:

1. **Given** um banco vazio e nenhuma das quatro variáveis definida, **When** a
   plataforma sobe, **Then** ela atende requisições normalmente, sem conta
   alguma, e o log nomeia as variáveis ausentes.
2. **Given** um banco vazio e apenas três das quatro variáveis definidas,
   **When** a plataforma sobe, **Then** nada é criado — nem organização sozinha,
   nem pessoa sem organização — e o log nomeia a que faltou.
3. **Given** um banco vazio e as quatro variáveis definidas, mas uma delas
   recusada pelas regras que já valem para o cadastro comum (e-mail malformado,
   identificador de organização inválido, senha curta demais), **When** a
   plataforma sobe, **Then** nada é criado, o log diz qual regra recusou, e a
   plataforma sobe.

---

### Edge Cases

- **Duas subidas ao mesmo tempo.** Numa atualização, o contêiner novo sobe antes
  de o antigo sair. Se os dois criarem, nascem dois administradores. O guarda não
  pode ser "consultei e não havia ninguém" — precisa ser uma garantia do
  armazenamento, do mesmo tipo que a plataforma já usa quando duas coletas
  disputam o mesmo registro.
- **Organização existe, administrador não.** Um banco restaurado pode ter
  organizações e nenhuma conta com marca de administração. Criar a pessoa dentro
  da organização já existente, e não uma segunda com o mesmo identificador.
- **Falha no meio.** Se a criação da pessoa falhar depois de a organização ter
  sido criada, nada deve sobrar. Organização sem administrador é um estado que
  nenhuma tela sabe nomear, e que faria a subida seguinte tentar criar de novo
  contra um identificador já ocupado.
- **A variável fica no painel.** Enquanto a variável de senha existir, a senha do
  primeiro administrador é legível por quem tem acesso ao painel. Isso é
  consequência aceita do desenho, e precisa estar dito no procedimento.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A plataforma MUST criar uma organização e uma pessoa com marca de
  administração a partir de valores do ambiente quando, e somente quando, não
  existir nenhuma pessoa com marca de administração.
- **FR-002**: A verificação MUST ser "existe alguma pessoa com marca de
  administração", e não "existe esta pessoa" — trocar o e-mail no ambiente não
  cria uma segunda conta.
- **FR-003**: A criação MUST acontecer depois de o esquema estar aplicado e antes
  de a plataforma atender a primeira requisição.
- **FR-004**: A criação MUST ser um ato único: ou existem organização e pessoa,
  ou não existe nenhuma das duas. Estado intermediário MUST NOT persistir.
- **FR-005**: Duas subidas simultâneas MUST NOT produzir dois administradores. A
  garantia MUST vir do armazenamento, e não de uma consulta prévia.
- **FR-006**: A senha MUST NOT aparecer em log, em mensagem de erro, ou em
  argumento de processo. Ela MUST ser guardada apenas na forma cifrada que a
  plataforma já usa para senha.
- **FR-007**: A ausência de qualquer valor obrigatório MUST NOT impedir a
  plataforma de subir. Ela MUST ser dita no log, nomeando o que faltou.
- **FR-008**: Valor presente mas recusado pelas regras de cadastro que já valem
  MUST produzir a mesma recusa: nada criado, motivo dito, plataforma no ar.
- **FR-009**: Quando já existir administrador, a subida MUST dizer isso no log —
  silêncio faria "não criei" e "criei" parecerem iguais.
- **FR-010**: A pessoa criada MUST poder trocar a própria senha pelos caminhos que
  já existem, e a troca MUST sobreviver a qualquer subida seguinte.
- **FR-011**: Quando já existir organização com o identificador informado, a
  pessoa MUST ser criada dentro dela, sem criar uma segunda.
- **FR-012**: O procedimento de produção MUST descrever este passo, incluindo a
  recomendação de remover o valor da senha do painel depois do primeiro acesso.

### Key Entities

- **Organização**: a organização cliente que a plataforma passa a servir. Tem
  nome legível e identificador estável, e é o que separa um cliente de outro.
- **Pessoa com marca de administração**: a conta que abre a plataforma e cria as
  demais. Tem e-mail, nome e senha.
- **Valores de instalação**: nome e identificador da organização, e-mail e senha
  da pessoa. Vivem no ambiente de quem hospeda, nunca no repositório.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Quem implanta uma instalação nova entra na plataforma **sem abrir
  console algum**, usando apenas o painel de quem hospeda e a tela de entrada.
- **SC-002**: Da implantação até a primeira sessão aberta se passam **menos de 5
  minutos**, contados do momento em que a plataforma responde.
- **SC-003**: **Zero** ocorrências da senha nos registros da plataforma, medidas
  por varredura no log da subida.
- **SC-004**: Dez subidas seguidas com as mesmas variáveis produzem **exatamente
  uma** pessoa com marca de administração.
- **SC-005**: Uma senha trocada pela interface continua valendo depois de **cinco**
  subidas com a variável no valor antigo.
- **SC-006**: Subir sem nenhuma das variáveis mantém a plataforma respondendo, e o
  log **nomeia** cada valor ausente.

## Assumptions

- Quem hospeda oferece um jeito de definir variáveis de ambiente por aplicação, e
  quem implanta tem acesso a ele. É o caso do painel usado hoje na produção.
- As regras de cadastro que já valem — formato de e-mail, formato do
  identificador de organização, força mínima de senha — se aplicam iguais aqui.
  Esta feature não afrouxa nenhuma delas.
- A pessoa criada não passa por troca obrigatória de senha: ela escolheu a
  própria senha, e a troca obrigatória existe para senha que outra pessoa
  conhece — o caso de `/accounts`, com senha temporária gerada por terceiro.
- A janela entre a plataforma responder e alguém instalar não é protegida por
  esta feature: quem define as variáveis é quem já tem acesso ao painel, e a
  criação não depende de nenhuma rota exposta.
- Fica fora do escopo: tela de instalação pela interface, criação de mais de um
  administrador, e criação de organizações adicionais. Todas continuam pelo
  caminho que já existe.
