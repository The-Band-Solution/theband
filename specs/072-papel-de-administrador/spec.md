# Feature Specification: A marca de administrador — promover, rebaixar, e o guarda do último

**Feature Branch**: `feature/568-papel-de-administrador`

**Created**: 2026-10-02

**Status**: Draft

**Input**: issue #568, uma lacuna nomeada pela aceitação do sprint 023 (2026-08-28). A FR-008 da spec
045 prometia conceder e revogar o papel de administrador, e essa fatia não foi entregue. Hoje
nenhuma tela altera `users.role`: não dá para promover um segundo administrador nem rebaixar um que
saiu.

## O que já existe, medido e não suposto

| fato | onde |
|---|---|
| `users.role` aceita `admin` e `member`, por `validate_inclusion`; **não há `CHECK` no banco** | `lib/the_band/tenants/user.ex:35`, `:108` |
| `User.changeset/2` faz `cast` de `:role`, e `Auth.cadastrar_conta/3` o chama com os atributos que recebe. A tela de contas fixa `"role" => "member"`, mas o contexto aceitaria `"admin"` de qualquer chamador | `user.ex:106`; `lib/the_band/tenants/auth.ex:311-315`; `lib/the_band_web/live/accounts_live/index.ex:108` |
| o guarda do último administrador ativo **já existe para a desativação**: `resta_um_admin_ativo/2` trava as contas admin ativas com `FOR UPDATE`, em ordem de id (#1055, PR #1130) | `lib/the_band/tenants.ex:631-648` |
| a desativação guarda **episódio** com autor, instante e razão de lista fechada | `lib/the_band/tenants/account_disablement.ex`, regra `access.account_lifecycle` |
| a tela de contas mostra a marca `administrator`, e um travessão para quem não é | `accounts_live/index.ex:693-696` |
| as telas e a API de admin conferem `User.admin?/1` a cada requisição e no `mount` do LiveView | `lib/the_band_web/plugs/current_scope.ex:120`, `lib/the_band_web/live/hooks.ex:102` |
| uma tela aberta reconfere a sessão quando recebe `:sessao_encerrada` (#1042) | `hooks.ex:142` |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Promover uma conta a administrador (Priority: P1)

Quem administra uma organização precisa dar a marca de administrador a outra conta ativa da mesma
organização. Assim a organização não depende de uma pessoa só para conectar ferramenta, gerenciar
credencial e administrar contas.

**Why this priority**: sem isto, uma organização com um administrador só fica presa a ele, e o
guarda do último administrador impede até de desativá-lo.

**Independent Test**: um administrador promove um membro; o membro passa a abrir as telas de
administração. Um membro tenta promover, e é recusado. O episódio diz quem promoveu, quando e
quem.

**Acceptance Scenarios**:

1. **Given** um administrador e um membro ativo da mesma organização, **When** o administrador o
   promove, **Then** o membro passa a ser administrador, e o registro diz quem promoveu, quem e
   quando.
2. **Given** um membro, **When** ele tenta promover alguém (pela tela ou por requisição forjada),
   **Then** é recusado, e nada muda.
3. **Given** uma conta desativada, **When** um administrador tenta promovê-la, **Then** é
   recusado com o motivo.
4. **Given** uma conta de **outra** organização, **When** um administrador tenta promovê-la,
   **Then** a resposta é "não encontrada", e não "sem permissão".

---

### User Story 2 - Rebaixar um administrador, nunca o último (Priority: P1)

Quem administra precisa tirar a marca de quem não deve mais tê-la, por exemplo quem mudou de
função. A organização nunca pode ficar sem nenhum administrador ativo.

**Why this priority**: a marca que só se dá, e nunca se tira, acumula poder em quem já não devia
ter. E o guarda do último, que hoje só vale para a desativação, passa a valer para o rebaixamento.

**Independent Test**:
- dois administradores, e um rebaixa o outro: passa;
- o último administrador ativo é rebaixado: é recusado, com a frase;
- duas pessoas rebaixam ao mesmo tempo os dois únicos administradores: uma passa e a outra é
  recusada.

**Acceptance Scenarios**:

1. **Given** dois administradores ativos, **When** um rebaixa o outro, **Then** o outro vira membro,
   com o registro de quem e quando.
2. **Given** um único administrador ativo, **When** alguém tenta rebaixá-lo, inclusive ele mesmo,
   **Then** é recusado com "the organisation would have no active administrator", e nada muda.
3. **Given** dois administradores, **When** cada um rebaixa o outro ao mesmo tempo, **Then** um dos
   dois atos passa e o outro é recusado pelo mesmo guarda. A organização termina com um
   administrador.
4. **Given** um administrador com uma tela de administração aberta, **When** ele é rebaixado,
   **Then** a próxima ação naquela tela não executa como administrador.

---

### User Story 3 - Os controles na tela de contas (Priority: P2)

Quem administra vê, na tela de contas, quem é administrador e o ato que cabe a cada conta. A tela
mostra **promover** para o membro ativo e **rebaixar** para o administrador, com confirmação. Quem
não é administrador não vê controle nenhum.

**Why this priority**: o ato precisa de lugar onde ser feito. A tela segue o protótipo aprovado
(regra da casa), e por isso vem depois do domínio.

**Independent Test**: a tela, como administrador, mostra os dois atos nas contas certas e nenhum
ato na conta desativada; como membro, nenhum controle.

**Acceptance Scenarios**:

1. **Given** a tela de contas aberta por um administrador, **When** ela renderiza, **Then** cada
   membro ativo tem "promover", e cada administrador tem "rebaixar", inclusive o desativado (Q1,
   decidido em 2026-10-03). Membro desativado não tem ato.
2. **Given** a recusa do último administrador, **When** ela acontece, **Then** a tela mostra a frase,
   e a marca continua.

### Edge Cases

- **Rebaixar a si mesmo** é permitido quando há outro administrador ativo: é o caso de quem passa
  a administração adiante. A tela pede confirmação.
- **Promover quem já é administrador, ou rebaixar quem já é membro**, é recusado como estado que
  mudou (outra aba chegou antes), e nada muda.
- **Desativar e reativar uma conta** não muda a marca dela. **Decidido em 2026-10-03** (S8; Q1 do
  protótipo): um administrador desativado **pode ser rebaixado**, para a reativação não devolver a
  administração sem registro. Promover continua só para conta ativa. Rebaixar um desativado não
  conta para o guarda, porque ele já não é administrador ativo.
- **Os tokens de API**: o veredito relê o papel a cada chamada (`api_auth.ex:80`, MCP
  `servidor.ex:39`, medido por leitura), então o token do rebaixado perde o alcance de admin na
  próxima chamada. Os tokens que um admin emitiu para **outros** donos continuam, e são declarados
  no risco residual (S5).
- **O bootstrap** cria a primeira conta como administradora (`bootstrap.ex:164`), e continua sendo
  o único caminho de criação com a marca.
- **O cadastro de conta pela tela** não pode criar administrador, mesmo que os atributos tragam
  `"role"`. O papel muda só pelo ato desta feature.

## Requirements *(mandatory)*

### Functional Requirements

> **Emendado em 2026-10-02** pela avaliação do agente `security` ([seguranca.md](seguranca.md),
> S1 a S9), antes do plano. Os pontos que dependem da pessoa mantenedora estão marcados.

- **FR-001**: Um administrador ativo MUST poder promover a administrador uma conta **ativa** da sua
  organização, e rebaixar a membro um administrador da sua organização.
- **FR-002**: Promover e rebaixar MUST conferir o **ator dentro do ato, relido do banco**: ele
  precisa estar no conjunto de administradores ativos travado pela mesma operação, e não basta a
  struct que a tela recebeu no `mount`. Sem isso, um rebaixado se promoveria de volta pela aba que
  ficou aberta (S2).
- **FR-002a**: Os atos de administração que já existem MUST conferir o ator relido do banco, pela
  mesma regra, e não só a tela que os chama: `Auth.reset_password`, `Auth.cadastrar_conta`,
  `Tenants.disable_user`/`enable_user`, `ApiTokens.criar`, e `Access.grant`/`revoke` (S1). Antes
  desta feature ninguém perdia a marca; com ela, o papel congelado no `mount` vira uma escalada.
- **FR-003**: Conta de outra organização MUST dar "não encontrada", e nunca "sem permissão".
- **FR-004**: O rebaixamento que deixaria a organização sem nenhum administrador ativo MUST ser
  recusado. Promover, rebaixar e desativar MUST usar **um único guarda**, com esta sequência:
  1. trava o conjunto de administradores ativos com `FOR UPDATE`, em ordem de id;
  2. trava e **relê o alvo**;
  3. decide pelo papel relido.

  A desativação de hoje decide pelo papel lido antes da trava, e com a promoção uma sequência de
  três atos deixaria zero administradores (S3).
- **FR-005**: Cada promoção e cada rebaixamento MUST deixar um registro somente-acréscimo, com quem
  agiu, sobre qual conta, o papel de antes e o de depois, e o instante. O registro é **garantido no
  banco**, como na 070 (S6):
  - triggers que recusam `DELETE`, `UPDATE` e `TRUNCATE`;
  - um trigger adiado que recusa mudar `users.role` sem o episódio correspondente.
- **FR-006**: A escrita de `users.role` MUST passar só pelo ato desta feature, salvo a criação pelo
  bootstrap. `User.changeset/2` MUST deixar de fazer `cast` de `:role` (S4). O cadastro cria sempre
  `member`. O banco recusa valor fora de `admin` e `member` com um `CHECK`, e a migração confere as
  linhas existentes antes de criá-lo (S7).
- **FR-007**: O ato, aceito ou recusado, MUST emitir um evento de acesso com quem agiu, sobre quem,
  de que papel para que papel, a organização e, na recusa, o motivo. O ato MUST devolver o
  episódio, para o teste não depender do log (S9). A nota livre não vai ao log.
- **FR-008**: Uma conta rebaixada com uma tela aberta MUST perder a capacidade de administrar
  **na próxima ação** (S1). Duas camadas:
  - o aviso por PubSub, no tópico da conta, depois do `commit`, faz a tela reler a conta e reaplicar
    a condição da área;
  - o domínio confere o ator relido (FR-002a). É a camada que vale mesmo sem o aviso.
- **FR-009**: A tela de contas MUST mostrar o ato que cabe a cada conta, com confirmação, e a
  recusa como estado, com a frase em inglês. Ela segue o protótipo aprovado pela pessoa
  mantenedora em 2026-10-03 (`prototipo/README.md`, "Aprovação").

### Key Entities

- **Mudança de papel**: o episódio de cada promoção ou rebaixamento, com a organização, a conta,
  quem agiu, o papel de antes e o de depois, e o instante. É somente-acréscimo.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Numa organização com dois administradores, dez rebaixamentos cruzados concorrentes
  terminam com pelo menos um administrador ativo, em 10 de 10 repetições.
- **SC-002**: Nenhum caminho da aplicação, além do ato e do bootstrap, muda `users.role`. A
  verificação acha zero escritas fora deles.
- **SC-003**: Uma promoção pela tela leva menos de 30 segundos, do clique à marca visível.
- **SC-004**: Toda mudança de papel feita aparece no registro com quem agiu e o instante: 100%,
  conferido contra o banco.

## Assumptions

- **Sem razão de lista fechada**, ao contrário da desativação: promover e rebaixar são atos de
  gestão do dia a dia, e o registro de quem, quando e de-para basta. Uma nota livre opcional fica
  no registro. Se a pessoa mantenedora quiser razão de lista, ela entra na base de conhecimento,
  como `access.account_lifecycle`.
- O rebaixamento **não** encerra as sessões da conta: ela continua entrando como membro. As telas
  abertas de administração deixam de agir como administrador (FR-008).
- A feature toca acesso: a avaliação do agente `security` vem antes do código (AGENTS §14.0), e a
  tela vem do protótipo aprovado (AGENTS §11.1).
