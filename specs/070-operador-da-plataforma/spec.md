# Feature Specification: O operador da plataforma — suspender e reativar uma organização

**Feature Branch**: `070-operador-da-plataforma`

**Created**: 2026-10-01

**Status**: Draft

**Input**: issue #1009 e decisão da pessoa mantenedora em 2026-09-29. Quem suspende uma organização
é um **operador da plataforma**, um papel acima das organizações. Hoje esse papel não existe:
`users.role` tem só `admin` e `member`, e os dois pertencem a um tenant. Também não existe ato de
suspender: `tenants.status` aceita `"suspended"`, e o login e a leitura o respeitam desde a v0.7.0,
mas nenhuma função e nenhuma tela o escrevem. Suspender hoje é `UPDATE` à mão no banco, e reativar
**devolve as sessões** abertas antes da suspensão.

## O que já existe, medido e não suposto

| fato | onde |
|---|---|
| `tenants.status` é string livre: o código lê `"active"` e `"suspended"`, mas não há `check_constraint` nem `validate_inclusion` (`seguranca.md`, O10) | `lib/the_band/tenants/tenant.ex:22` |
| organização não ativa recusa a entrada | `lib/the_band/tenants/auth.ex:134` |
| organização não ativa derruba a sessão na requisição seguinte | `lib/the_band_web/plugs/current_scope.ex`, `lib/the_band_web/live/hooks.ex` |
| `user_sessions` tem `tenant_id`, e `Sessions.encerrar_da_conta/2` encerra por conta | spec 064, T009 e T011 |
| a desativação de conta guarda **episódio** com autor, instante e razão de lista fechada | `lib/the_band/tenants/account_disablement.ex`, regra `access.account_lifecycle` |
| nenhum caminho escreve `tenants.status` | busca em `lib/` em 2026-10-01 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Suspender uma organização, e as sessões caem de verdade (Priority: P1)

Quem opera a plataforma suspende uma organização, com a razão. Toda pessoa daquela organização é
desconectada, e **reativar não devolve nenhuma sessão**: cada pessoa entra de novo.

**Why this priority**: é o defeito de segurança #1009. Hoje a única forma de suspender é o banco à
mão, e reativar ressuscita a sessão que pode ter motivado a suspensão.

**Independent Test**: com uma sessão aberta na organização A, suspender A e reativar A; o cookie
de antes vai para `/sign-in`. Com o encerramento retirado, o teste precisa dar `200`.

**Acceptance Scenarios**:

1. **Given** uma organização ativa com sessões abertas, **When** o operador a suspende com uma razão
   da lista, **Then** a organização fica `suspended`, **todas** as sessões dela recebem `ended_at`
   na mesma transação, e o episódio guarda quem, quando e por quê.
2. **Given** uma organização suspensa, **When** o operador a reativa com uma razão da lista,
   **Then** ela volta a `active`, o episódio é fechado com quem, quando e por quê, e **nenhuma**
   sessão anterior volta a valer.
3. **Given** a suspensão sem razão, ou com razão fora da lista, **When** o operador tenta, **Then**
   é recusada com o motivo, e nada muda.

---

### User Story 2 - O papel de operador existe, e não vaza dado de organização (Priority: P1)

Existe um papel de **operador da plataforma**, concedido de forma deliberada e registrada. O
operador vê **a lista das organizações e o estado de cada uma**, e **não** vê o dado de domínio de
nenhuma: pessoas, equipes, issues, medidas.

**Why this priority**: é o pré-requisito da US1, e o risco dela. Um papel que atravessa tenants e
enxerga dado seria a quebra do isolamento que a plataforma inteira protege (constituição,
princípio V).

**Independent Test**: um operador abre a tela de organizações e vê nome, slug e estado. Tentar
abrir `/people`, `/teams` ou `/api/v1/*` de **outra** organização dá a mesma recusa de quem não é
de lá.

**Acceptance Scenarios**:

1. **Given** uma conta que não é operadora, **When** ela tenta a tela de operação da plataforma,
   **Then** recebe "not found", e não "permission denied" (o recurso não se confirma).
2. **Given** um operador, **When** ele abre a tela, **Then** vê só nome, slug, estado e a data do
   último episódio de cada organização, e nada de dado de domínio.
4. **Given** a conta do operador, que não tem organização, **When** ela tenta qualquer tela de
   domínio, a API ou a MCP, **Then** recebe a recusa de quem não é de lá, e nenhuma consulta roda
   sem filtro de tenant.
3. **Given** a concessão do papel, **When** ela acontece, **Then** fica registrada com quem
   concedeu e quando, e é revogável.

---

### Edge Cases

- **Suspender a única organização da instalação.** Possível: o operador não pertence a ela
  (FR-011) e continua podendo reativá-la.
- **A conta do operador e as telas de domínio.** Ela não tem organização, e toda tela de domínio
  MUST recusá-la como recusa quem não é de lá. Um `nil` de tenant que caísse num filtro como
  "todas" seria o pior defeito possível desta spec.
- **Suspender duas vezes.** A segunda é recusada com o motivo: já está suspensa.
- **Uma coleta rodando** na organização suspensa: o job valida o tenant ao executar (AGENTS §7.4),
  e a coleta seguinte não começa. A que está em voo termina a página atual.
- **Tokens da API** da organização suspensa: já são recusados, porque `ApiAuth` lê o estado, e a
  suspensão os revoga (FR-013), para que não voltem na reativação.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A plataforma MUST ter um papel de **operador da plataforma**, distinto de `admin`
  (que é da organização), concedido **só por comando de quem opera o servidor**
  (`TheBand.Release`, pelo Dokploy). Nenhuma tela concede nem revoga o papel: quem tomar uma conta
  pela web não consegue se promover. *(Decisão de 2026-10-01.)*
- **FR-002**: A concessão e a revogação do papel MUST ficar registradas com autor e instante, e o
  registro MUST NOT ser apagado.
- **FR-003**: O operador MUST poder suspender e reativar uma organização, sempre com uma razão de
  **lista fechada** declarada na base de conhecimento, e uma nota opcional.
- **FR-004**: Suspender MUST encerrar (`ended_at`) toda sessão aberta da organização **na mesma
  transação** que muda o estado e abre o episódio.
- **FR-005**: Reativar MUST NOT devolver sessão nenhuma. Cada pessoa entra de novo.
- **FR-006**: Cada suspensão MUST ser um **episódio**, com quem suspendeu, quando e por quê, e quem
  reativou, quando e por quê. O histórico de episódios de uma organização MUST ser legível pelo
  operador.
- **FR-007**: O operador MUST NOT ler dado de domínio de nenhuma organização pelo papel de
  operador. O que ele vê de cada organização é nome, slug, estado e o histórico de episódios.
- **FR-008**: Como a conta do operador não pertence a organização nenhuma (FR-011), nenhuma
  suspensão o desconecta. A plataforma MUST, mesmo assim, recusar suspender **todas** as
  organizações de uma vez: a recusa vale por ato, um por organização, com razão.
- **FR-009**: A tela e a rota do operador MUST responder "not found" a quem não é operador.
- **FR-010**: Toda suspensão e reativação MUST gerar um evento de acesso no log (`AccessEvents`),
  como a desativação de conta já gera.
- **FR-011**: O operador é uma **entidade separada** de `users`, com autenticação e sessão
  próprias *(decisão de 2026-10-01, depois da avaliação de segurança, `seguranca.md`, O1/O2)*.
  `users.tenant_id` continua `NOT NULL`, e `user_sessions` não muda. Nenhum plug, hook, veredito de
  `Access`, a API ou a MCP passa a aceitar conta sem tenant: o operador não é uma conta de
  `users`, e por isso não alcança nenhum desses caminhos. A área do operador tem pipeline,
  `live_session`, plug e hook próprios, e a sessão do operador nunca é lida pelo leitor de sessão
  das organizações.
- **FR-012**: A suspensão MUST parar **todo worker que age em nome do tenant** — coleta,
  reprocessamento, promoções e a rodada de perfis via LLM: o agendador não agenda, o sync manual é
  recusado, e o job que começar confere o estado do tenant antes de executar *(decisões de
  2026-10-01; achado O7)*. É a issue #1033, que existe hoje e é corrigida **antes** desta feature.
  Reativar não dispara coleta: a próxima segue o intervalo da ferramenta.
- **FR-013**: Suspender MUST revogar todos os tokens de API da organização na mesma transação.
  Reativar não devolve nenhum: cada token é emitido de novo *(decisão de 2026-10-01; achado O12)*.
- **FR-014**: Revogar o papel de um operador MUST encerrar a sessão dele na mesma transação, e a
  autorização de operador MUST ser conferida dentro da função que suspende e reativa, e não só na
  montagem da tela (achado O6).
- **FR-015**: Reativar MUST encerrar também as sessões gravadas depois da suspensão, para fechar a
  corrida entre entrar e suspender (achado O8).

### Key Entities

- **Operador da plataforma**: entidade própria, fora de `users`, com credencial e sessão próprias
  (FR-011).
- **Concessão de operador**: quem recebeu o papel, quem concedeu, quando, e a revogação, se houver.
  É um relator, e não uma coluna booleana (AGENTS §7.7: booleano no lugar do relator).
- **Episódio de suspensão**: a organização, quem suspendeu, quando, a razão e a nota; e quem
  reativou, quando, a razão e a nota. `tenants.status` continua sendo a resposta rápida, e o
  episódio é o registro.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Depois de suspender e reativar uma organização, **zero** sessões anteriores à
  suspensão continuam valendo.
- **SC-002**: Nenhuma organização é suspensa ou reativada sem um episódio com autor, instante e
  razão. A consulta que procura uma organização `suspended` sem episódio aberto devolve zero.
- **SC-003**: Um operador não consegue ler nenhum dado de domínio de outra organização por
  nenhuma das três portas (tela, API e MCP). O teste de paridade cobre o caso.
- **SC-004**: Suspender uma organização leva menos de um minuto, pela tela, sem acesso ao banco.

## Assumptions

- A lista de razões de suspensão segue o padrão de `access.account_lifecycle`: uma lista fechada
  na base de conhecimento, com `other` e nota livre.
- O papel de operador é raro: uma ou duas pessoas por instalação. A tela não precisa de paginação
  nem de busca.
- Encerrar sessões reaproveita `user_sessions.tenant_id`, que a 064 criou exatamente para isto
  (decisão P4).

## Dependencies

- Spec 064: `user_sessions` com `tenant_id` e `Sessions` (já em produção na v0.11.0).
- Avaliação do agente `security` **antes do plano**, porque o papel atravessa tenants (AGENTS
  §14.0).
- Protótipo da tela antes do código (o Design).

## Out of Scope

- **A gestão de `admin` dentro da organização** (promover, rebaixar, o guarda do último admin): é a
  issue #568, numa spec própria, porque age dentro de uma organização, e esta atravessa todas.
- Criar, apagar ou renomear organização pela tela do operador.
- Qualquer leitura de dado de domínio pelo operador, inclusive "só para suporte".
