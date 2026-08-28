# Feature Specification: Gerar só com chave — o botão diz antes do clique

**Feature Branch**: `048-botao-sem-chave-desabilitado`

**Created**: 2026-08-28

**Status**: Draft — backlog (não selecionada para sprint; pedida durante o sprint 023)

**Input**: User description: "Se a AI tools não tiver preenchido [a chave do
provedor], o botão Generate Again não pode estar habilitado."

## O problema

Os botões de geração de perfil — "Generate again" e "Generate profile" na página da
pessoa, "Start run" na geração mensal — aparecem clicáveis mesmo quando a organização
não tem chave de provedor configurada. O clique falha com a recusa nomeada ("This
organisation has no provider key of its own"), o que é correto — mas tarde: a pessoa
já clicou, já esperou, e a frase chega como erro do que ela fez, não como estado do
que falta. O estado é conhecido ANTES do clique, e a tela deve dizê-lo antes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - O botão desabilitado diz o que falta (Priority: P1)

Sem chave de provedor configurada para a organização, os botões de geração aparecem
**desabilitados**, acompanhados da frase do porquê e de onde se resolve: a chave se
configura em Tools › AI provider (quem administra). Com a chave configurada, os botões
habilitam sem recarregar a plataforma.

**Why this priority**: é o pedido — e é o padrão da casa: ausência nomeada ANTES de
virar erro de quem clica.

**Independent Test**: numa organização sem chave, abrir a página da pessoa e a geração
mensal — botões desabilitados com a frase; configurar a chave; voltar — habilitados.

**Acceptance Scenarios**:

1. **Given** organização sem chave de provedor, **When** a página da pessoa renderiza
   com perfil ("Generate again") ou sem ("Generate profile"), **Then** o botão está
   desabilitado e a frase ao lado diz que falta a chave e onde configurá-la.
2. **Given** organização sem chave, **When** a tela da geração mensal renderiza,
   **Then** "Start run" está desabilitado com a mesma frase.
3. **Given** a chave configurada, **When** as telas renderizam, **Then** os botões
   estão habilitados e a frase da lacuna não aparece.
4. **Given** o botão desabilitado, **When** alguém dispara o evento por fora do botão
   (console, HTML editado), **Then** a recusa do domínio continua exatamente como hoje
   — desabilitar o botão é aviso, nunca a defesa (a defesa já existe e fica).
5. **Given** quem olha não é administrador, **When** a frase da lacuna aparece,
   **Then** ela diz que QUEM ADMINISTRA configura em Tools › AI provider — sem link
   para onde a pessoa não alcança.

---

### Edge Cases

- Chave existe mas foi **desativada/destruída** depois: mesmo estado de "sem chave" —
  a pergunta é "há chave utilizável agora?", não "houve chave algum dia?".
- Organização com chave e outra sem, no mesmo tenant: cada página responde pela
  organização da pessoa/geração em questão.
- A verificação do estado não pode custar consulta por linha em listas — é por
  página, uma vez.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Botão de geração de perfil MUST aparecer desabilitado quando a
  organização não tem chave de provedor utilizável, com frase dizendo o que falta e
  onde se configura.
- **FR-002**: O estado MUST ser reavaliado a cada render da página — chave configurada
  habilita sem reiniciar nada.
- **FR-003**: A recusa do domínio ao gerar sem chave MUST permanecer intacta —
  desabilitar é comunicação, não autorização.
- **FR-004**: A frase MUST se adaptar a quem lê: administrador recebe o caminho
  (Tools › AI provider); quem não administra recebe "quem administra configura".

### Key Entities

Nenhuma nova — leitura do estado da credencial de provedor que já existe.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em organização sem chave, 0 cliques possíveis nos botões de geração — e
  100% deles acompanhados da frase da lacuna.
- **SC-002**: Configurar a chave e recarregar habilita 100% dos botões, sem passo
  extra.
- **SC-003**: O evento disparado por fora do botão continua recusado pelo domínio com
  a mensagem de hoje (teste da violação).

## Assumptions

- **A defesa já existe** (`Profiles.request` recusa sem chave) — esta feature é a
  camada de comunicação; nada de autorização muda.
- **Não entra no sprint 023** — pedida durante ele e contida no backlog; candidata
  natural a acompanhar a 047 (mensagens) ou entrar num sprint de polimento com o fix
  #563, que tocou o mesmo fluxo.
