# Feature Specification: Mensagens internacionalizadas

**Feature Branch**: `047-mensagens-internacionalizadas`

**Created**: 2026-08-28

**Status**: Draft — backlog (não selecionada para sprint; sprint 023 em curso)

**Input**: User description: "Nenhuma mensagem de erro deve estar em código. Temos
que ter um arquivo de internacionalização para isso. E o mesmo para a mensagem do
sistema."

## O problema

As mensagens que a plataforma diz às pessoas — erro, recusa, estado vazio, aviso —
vivem espalhadas como texto literal nos módulos e nas telas, num misto de português e
inglês que cresceu tela a tela. Texto em código tem três custos: não há UM lugar para
revisar o que a plataforma fala; a mesma situação ganha frases diferentes em telas
diferentes; e traduzir (a landing pública já é bilíngue PT/EN) exigiria caçar strings
no fonte. A infraestrutura já existe — gettext está no projeto com `errors.pot` — mas
quase nada passa por ela.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Toda mensagem de erro sai de arquivo de tradução (Priority: P1)

Quem desenvolve escreve mensagens de erro — de validação, de recusa de acesso, de
falha de operação — somente em arquivos de tradução; o código as referencia por
chave/domínio. Quem revisa encontra todas as frases de erro num lugar só, e uma
verificação automática recusa mensagem literal nova em código.

**Why this priority**: é o pedido nuclear — erro é o texto mais lido nos piores
momentos, e é onde frase divergente confunde mais.

**Independent Test**: alterar uma mensagem de erro só no arquivo de tradução e vê-la
mudar na tela; rodar a verificação e vê-la recusar um literal plantado.

**Acceptance Scenarios**:

1. **Given** uma recusa qualquer (login inválido, acesso negado, alvo obrigatório),
   **When** ela aparece na tela, **Then** a frase veio de arquivo de tradução — e
   editá-la lá muda a tela sem tocar código.
2. **Given** um literal de erro plantado num módulo ou tela, **When** a verificação
   do repositório roda, **Then** ela reprova apontando arquivo e linha.
3. **Given** as mensagens de segurança da feature 045 (recusa única de credenciais,
   motivos de recusa de painel), **When** migradas, **Then** a recusa única CONTINUA
   única — a migração não pode reintroduzir distinção entre os casos.

---

### User Story 2 - Mensagens do sistema no mesmo regime (Priority: P2)

Confirmações ("Senha definida."), estados vazios nomeados, avisos e rótulos de
situação seguem o mesmo caminho: arquivo de tradução por domínio, código por chave.

**Why this priority**: fecha o inventário do que a plataforma fala; sem isso o
regime vale só para metade das frases.

**Independent Test**: editar um estado vazio no arquivo de tradução e ver a tela
mudar.

**Acceptance Scenarios**:

1. **Given** uma mensagem de sistema (flash, estado vazio, aviso), **When** exibida,
   **Then** vem de arquivo de tradução.
2. **Given** os textos com termo fixado por decisão registrada (ex.: "Checks", nunca
   "CI"), **When** migrados, **Then** a decisão vem junto como comentário no arquivo
   de tradução — a razão não se perde na mudança de casa.

---

### User Story 3 - Um idioma escolhido, dois disponíveis (Priority: P3)

A plataforma define o idioma padrão (português) e mantém inglês como segundo idioma,
com as lacunas de tradução visíveis (relatório do que falta), nunca silenciosas.

**Why this priority**: é o que a internacionalização compra; vem por último porque
depende do inventário completo das duas primeiras.

**Independent Test**: trocar o idioma configurado e ver as telas no segundo idioma;
gerar o relatório de lacunas.

**Acceptance Scenarios**:

1. **Given** o idioma configurado, **When** qualquer tela renderiza, **Then** as
   mensagens saem no idioma configurado.
2. **Given** uma chave sem tradução no segundo idioma, **When** o relatório roda,
   **Then** ela aparece nomeada — ausência nunca silenciosa.

---

### Edge Cases

- Mensagem com interpolação (contagens, nomes): a chave carrega os placeholders; a
  verificação recusa concatenação de string com frase.
- Mensagem de segurança com forma exigida por spec (recusa única da 045): o teste da
  forma (respostas byte-idênticas) continua valendo por cima da tradução.
- Texto de domínio observado (nome de equipe, título de issue) NÃO é mensagem — dado
  coletado não se traduz.
- Logs e mensagens de exceção para quem opera: fora do escopo — são para quem
  desenvolve, não para quem usa (registrado em Assumptions).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Nenhuma mensagem de erro exibida a pessoa usuária MUST existir como
  literal em código de aplicação; toda mensagem MUST viver em arquivo de tradução,
  referenciada por chave e domínio.
- **FR-002**: Mensagens do sistema — confirmações, avisos, estados vazios, rótulos de
  situação — MUST seguir o mesmo regime.
- **FR-003**: O repositório MUST ter verificação automática que reprove literal de
  mensagem novo em código, apontando arquivo e linha, integrada aos quality gates.
- **FR-004**: A migração MUST preservar as invariantes de forma das mensagens de
  segurança (recusa única da 045: byte-idêntica entre os casos) — os testes que as
  provam MUST continuar passando sem enfraquecer.
- **FR-005**: O idioma padrão MUST ser configurável; chave sem tradução no idioma
  ativo MUST cair no idioma padrão, nunca em chave crua na tela.
- **FR-006**: Lacunas de tradução MUST ser enumeráveis por comando, com a lista de
  chaves faltantes por idioma.
- **FR-007**: Decisões de vocabulário registradas (ex.: "Checks" nunca "CI") MUST
  migrar com a razão junto, como comentário na entrada de tradução.

### Key Entities

- **Catálogo de mensagens**: arquivos de tradução por domínio (erros, sistema,
  telas), com chaves estáveis, placeholders nomeados e comentários de decisão.
- **Verificação de literais**: regra automatizada nos gates; a definição do que é
  "mensagem" (exibida a pessoa) vs. texto técnico (log, exceção) é dela.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das mensagens de erro e de sistema exibidas nas telas saem de
  arquivo de tradução — verificado pela regra automática com 0 literais apontados.
- **SC-002**: Editar uma frase no arquivo muda a tela sem recompilar código de
  aplicação além do catálogo — demonstrado em 3 telas distintas.
- **SC-003**: O relatório de lacunas lista 0 chaves faltantes no idioma padrão e
  enumera as do segundo idioma.
- **SC-004**: Os testes de forma das mensagens de segurança da 045 passam inalterados
  após a migração.

## Assumptions

- **gettext é a infraestrutura** — já é dependência do projeto com `priv/gettext/`;
  a feature o adota em vez de introduzir tecnologia nova.
- **Idioma padrão: português**; inglês como segundo idioma. A interface hoje mistura
  os dois — a migração é a oportunidade de unificar, tela a tela, sem big-bang.
- **Logs, exceções e mensagens de operação ficam fora**: são para quem desenvolve.
  Redação de log continua seguindo a regra de segurança existente (sem segredo, sem
  payload sensível).
- **Escopo por varredura incremental**: a verificação automática nasce estrita para
  código NOVO e com lista de pendências para o legado, queimada por tela — nunca uma
  lista de exceções permanente.
- **Não entra no sprint 023**: especificada durante o sprint da autenticação (045) e
  contida no backlog — trabalho novo não começa enquanto o anterior não tem destino.
  As mensagens da 045 são candidatas primeiras da migração (US1, cenário 3).
