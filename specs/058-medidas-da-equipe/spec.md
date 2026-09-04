# Feature Specification: As medidas que faltam na tela da equipe, e o elo com o projeto

**Feature Branch**: `058-medidas-da-equipe`

**Created**: 2026-09-02

**Status**: Draft

**Input**: User description: "As medidas que faltam na tela da equipe, e o elo com o projeto. Três coisas, e a terceira tem uma pergunta em aberto que a pesquisa precisa responder. (1) O tempo até a primeira revisão humana, por equipe e por pessoa. (2) O elo equipe ↔ projeto com período. (3) A taxa de sucesso do pipeline no nível da equipe — o caminho de uma verificação até uma equipe não se sabe, e a resposta pode ser que a medida não se calcula neste nível."

## O que esta feature resolve

O épico [#504](https://github.com/The-Band-Solution/theband/issues/504) pediu
painéis na tela da equipe em 2026-08-25. Ele ficou bloqueado por três
dependências, e a revisão de 2026-09-02 encontrou que **as três mudaram de estado
sem ninguém revisar o épico**: duas fecharam, e a feature 057 entregou parte do
que ele pedia sem que os dois fossem ligados.

O que resta é **menor e diferente** do que estava escrito, e são três coisas:

| # | O que falta | Depende da feature 042? |
|---|---|---|
| 1 | o tempo até a primeira revisão, recortado por equipe | não |
| 2 | o elo equipe ↔ projeto **com período** | não |
| 3 | a taxa de sucesso do pipeline por equipe | não — a pesquisa resolveu |

A terceira nasceu como pergunta aberta, e a pesquisa a respondeu (R1): existem
**dois** caminhos de uma verificação até uma equipe, e eles afirmam coisas
diferentes. O escolhido é **por repositório → projeto → equipe**; o do ator da
execução responde *quem apertou o botão*, e não *quem cuida do código*.

A recusa continua existindo — mas **por equipe sem projeto declarado**, e não
pela medida inteira.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - O tempo até a primeira revisão, desta equipe (Priority: P1)

Quem gerencia abre a tela da equipe e vê quanto tempo as solicitações de mudança
desta equipe esperam pela primeira revisão **humana**, e a mesma medida por
pessoa. O recorte respeita o período do vínculo: a solicitação conta para a
equipe quando quem a abriu pertencia a ela **na data em que ela foi aberta**.

**Why this priority**: é a medida que já existe calculada e não chega à tela —
`TheBand.Quality.time_to_first_review/2` devolve as últimas 50 solicitações do
tenant inteiro, sem recorte nenhum. O caminho mais curto entre trabalho feito e
valor entregue.

**Independent Test**: abrir a tela de uma equipe cujas pessoas abriram
solicitações, e conferir que só as delas aparecem; registrar a saída de alguém e
conferir que as solicitações anteriores à saída continuam contando.

**Acceptance Scenarios**:

1. **Given** duas equipes com solicitações de mudança, **When** a tela de uma é
   aberta, **Then** apenas as solicitações de quem pertencia a ela aparecem
2. **Given** uma pessoa que saiu da equipe em 2026-03-15, **When** a medida é
   exibida, **Then** as solicitações que ela abriu até 2026-03-15 contam e as
   posteriores não
3. **Given** uma solicitação cuja primeira revisão foi de um robô, **When** o
   tempo é calculado, **Then** ele conta até a primeira revisão **humana**, e a
   tela declara isso
4. **Given** uma solicitação ainda sem revisão, **When** a medida é exibida,
   **Then** ela aparece como **espera em curso**, e não é omitida nem contada
   como tempo zero
5. **Given** uma equipe sem solicitação nenhuma no período, **When** a tela é
   aberta, **Then** a ausência é dita em texto, nunca como zero

---

### User Story 2 - Quem trabalhou neste projeto, e quando (Priority: P1)

Quem gerencia pergunta *quem trabalhou neste projeto entre janeiro e março*, e
recebe a resposta com as pessoas que pertenciam a uma equipe **que estava ligada
ao projeto** naquele intervalo. Quando um dos períodos é desconhecido, a resposta
diz isso em vez de assumir que estava aberto.

**Why this priority**: o dado existe e **nenhuma consulta o usa**. O vínculo
equipe ↔ projeto guarda início e fim desde que foi criado, e a pergunta que ele
existe para responder nunca foi feita.

**Independent Test**: ligar uma equipe a um projeto por um intervalo, mover uma
pessoa para dentro e para fora da equipe, e conferir que a interseção dos três
períodos devolve exatamente quem estava nos dois ao mesmo tempo.

**Acceptance Scenarios**:

1. **Given** uma equipe ligada ao projeto de janeiro a junho e uma pessoa nela de
   março a dezembro, **When** a pergunta é sobre fevereiro, **Then** a pessoa
   **não** aparece
2. **Given** a mesma configuração, **When** a pergunta é sobre abril, **Then** a
   pessoa aparece
3. **Given** uma equipe desligada do projeto, **When** a pergunta é sobre o
   período em que ela estava ligada, **Then** as pessoas daquele período
   aparecem — desligar não apaga o que houve
4. **Given** uma pessoa cujo vínculo não tem data de início, **When** a
   interseção é calculada, **Then** o resultado marca **parcialmente
   desconhecido**; e **Given** um vínculo apenas em curso, **Then** ele **não** é
   marcado — `fim` nulo é vigente, não desconhecido
5. **Given** a mesma pessoa em duas equipes ligadas ao mesmo projeto, **When** o
   resultado é exibido, **Then** ela aparece **uma vez**, com as duas equipes
   nomeadas

---

### User Story 3 - A taxa do pipeline dos projetos desta equipe (Priority: P2)

Quem gerencia vê a taxa de sucesso das verificações **dos repositórios dos
projetos em que esta equipe trabalhava**, no período. Equipe sem projeto
declarado não tem a taxa — e a tela diz **isso**, nomeando o elo que falta.

**Why this priority**: a pesquisa respondeu a pergunta que a spec deixou aberta
(R1). Vem por último porque reusa a interseção de períodos que a US2 constrói —
e não porque a viabilidade seja incerta.

**Independent Test**: com verificações coletadas e equipes declaradas, conferir
que a tela ou apresenta a taxa com o caminho declarado, ou apresenta o motivo da
ausência nomeando o elo que falta.

**Acceptance Scenarios**:

1. **Given** uma equipe ligada a um projeto com repositórios, **When** a tela é
   aberta, **Then** a taxa aparece com o caminho declarado junto do número, e com
   sobre **quantas execuções** ela foi calculada
2. **Given** uma equipe **sem projeto declarado**, **When** a tela é aberta,
   **Then** ela nomeia o elo que falta — a plataforma não sabe de quais
   repositórios essa equipe cuida — e **não** apresenta taxa nenhuma
3. **Given** uma execução disparada por alguém de fora da equipe num repositório
   do projeto dela, **When** a taxa é calculada, **Then** ela **conta**: a medida
   é do pipeline dos repositórios, e não de quem apertou o botão
4. **Given** verificações em andamento, **When** a taxa é calculada, **Then** elas
   **não** entram como sucesso nem como falha, e a contagem delas é exibida em
   separado
5. **Given** verificações interrompidas, não executadas ou expiradas, **When** a
   taxa é calculada, **Then** cada fase conta em separado, e nenhuma é somada a
   "falhou" — cancelar é decisão humana

### Edge Cases

- **Solicitação sem revisão nenhuma** — espera em curso, nunca tempo zero.
- **Primeira revisão de robô** — o tempo conta até a primeira **humana**, e a
  tela declara que descarta a do robô.
- **Solicitação de quem nunca teve vínculo declarado** — não conta para equipe
  nenhuma, e aparece na contagem do que ficou de fora.
- **Vínculo de pessoa sem `started_at`** — período parcialmente desconhecido,
  nunca aberto desde sempre. É a **única** ponta que produz dúvida: `linked_at` é
  `NOT NULL` nas duas tabelas de projeto (R2a), e `fim` nulo significa **vigente**.
- **Pessoa em duas equipes do mesmo projeto** — uma linha, duas equipes nomeadas.
- **Equipe ligada, desligada e religada ao mesmo projeto** — os dois intervalos
  contam, e o intervalo entre eles não.
- **Janela perguntada que não intersecta nada** — resposta vazia **dita**, e não
  lista em branco.
- **Verificação em andamento** — fora do numerador e do denominador.
- **Equipe sem projeto declarado** — sem taxa, com o elo que falta nomeado.
- **Repositório ligado ao projeto e depois desligado** — as execuções do
  intervalo em que esteve ligado contam; as de fora, não.

## Requirements *(mandatory)*

### O tempo até a primeira revisão

- **FR-001**: O sistema MUST apresentar o tempo até a primeira revisão humana das
  solicitações de mudança **desta equipe**.
- **FR-002**: Uma solicitação MUST contar para a equipe quando quem a abriu
  pertencia a ela **na data de abertura da solicitação**, e não na data da
  consulta.
- **FR-003**: Revisão de robô MUST NOT encerrar a contagem, e a tela MUST
  declarar que ela é descartada.
- **FR-004**: Solicitação ainda sem revisão MUST aparecer como **espera em
  curso**, e MUST NOT ser omitida nem contada como tempo zero.
- **FR-005**: O sistema MUST apresentar a mesma medida por pessoa, e a tela MUST
  declarar que os valores por pessoa e o da equipe respondem perguntas
  diferentes.
- **FR-006**: Equipe sem solicitação no período MUST ter a ausência dita em
  texto.

### O elo equipe ↔ projeto, com período

- **FR-007**: O sistema MUST responder quem trabalhou num projeto num intervalo,
  pela interseção de três períodos: pessoa ↔ equipe, equipe ↔ projeto, e a janela
  perguntada.

  **A definição, dada pela pessoa mantenedora em 2026-09-04**: *uma pessoa trabalha
  num projeto quando a equipe dela está no projeto.* Ela decide duas coisas que a
  spec deixava implícitas:

  1. a participação é **derivada** de dois vínculos declarados, e não observada no
     trabalho — a tela MUST dizer isso junto da lista (FR-017);
  2. as duas direções do erro são **consequência da definição**, e não lacuna de
     coleta: quem está na equipe e não tocou em nada aparece; quem commitou nos
     repositórios do projeto sem estar em equipe ligada não aparece. A tela MUST
     declarar as duas.
- **FR-007a**: A lista de quem trabalhou num projeto é **estrutura declarada**, e
  não desempenho de pessoa nomeada — por isso **não** está sob a fronteira de
  FR-024. Ela tem a mesma natureza da lista de integrantes que a tela já mostra
  aberta: diz quem a organização declarou onde, e nenhum número sobre como a pessoa
  trabalha.
- **FR-008**: Vínculo encerrado MUST continuar contando no intervalo em que
  vigeu — desligar **não** apaga o que houve.
- **FR-009**: Quando o **início** de qualquer período é desconhecido, o resultado
  MUST marcar **parcialmente desconhecido**, e MUST NOT tratá-lo como aberto.
- **FR-009a**: `fim` nulo significa **vigente**, e MUST NOT ser marcado como
  desconhecido. Marcá-lo poria a dúvida em quase toda linha até ela deixar de
  significar alguma coisa.
- **FR-010**: Pessoa que alcança o projeto por mais de uma equipe MUST aparecer
  **uma vez**, com todas as equipes nomeadas.
- **FR-011**: Intervalo sem interseção MUST devolver ausência dita, e não lista
  vazia sem explicação.
- **FR-012**: A borda de todo período MUST ser `[início, fim)` — a mesma
  convenção da feature 057.

### A taxa do pipeline

- **FR-013**: A taxa MUST ser calculada sobre as verificações dos **repositórios
  dos projetos** ligados à equipe no período, e MUST NOT ser calculada por quem
  disparou a execução — o ator é quem apertou o botão, não quem cuida do código.
- **FR-013a**: Equipe sem projeto declarado MUST NOT receber taxa, e a tela MUST
  nomear o elo que falta.
- **FR-013b**: O sistema MUST NOT apresentar duas taxas de pipeline com o mesmo
  rótulo e denominadores diferentes.
- **FR-014**: Verificação **em andamento** MUST ficar fora do numerador e do
  denominador, e MUST ser exibida em separado.
- **FR-015**: Interrompida, não executada e expirada MUST contar cada uma em sua
  própria fase, e MUST NOT ser somadas a "falhou".
- **FR-016**: Quando a taxa existir, o **caminho** da verificação até a equipe e
  o **número de execuções** sobre o qual ela foi calculada MUST aparecer junto do
  número.

### Regras que valem em toda medida desta feature

- **FR-017**: Toda medida MUST carregar sua proveniência — observada, derivada ou
  declarada.
- **FR-018**: Ausência MUST ser nomeada, e MUST NOT ser apresentada como zero.
- **FR-019**: A limitação de cada medida MUST aparecer junto do número, e MUST
  NOT viver numa página de ajuda.
- **FR-020**: O sistema MUST NOT somar valores de níveis que contam a mesma
  unidade mais de uma vez, e a tela MUST dizer por que não soma.
- **FR-021**: Toda medida nova MUST estar declarada na base de conhecimento,
  com limitações e interpretações incorretas, **antes** de aparecer na tela.
- **FR-022**: Toda consulta MUST ser restrita ao tenant de quem consulta.
- **FR-023**: Ver estas medidas MUST NOT exigir permissão de administrar equipes.
- **FR-024**: A quebra **por pessoa nomeada** MUST ser apresentada apenas a quem
  alcança a equipe pelo veredito de acesso vigente, e a decisão MUST vir **antes**
  da carga. O agregado da equipe — mediana, espera em curso, ausência dita e as
  limitações — MUST permanecer legível por qualquer conta do tenant.

  *Acrescentado em 2026-09-04, por decisão do Product Owner, depois de a revisão de
  segurança do PR #798 encontrar que qualquer conta do tenant lia login, número de
  solicitação e mediana individual de pessoa nomeada.* **Não é regra nova**: aplica
  à tela da equipe a decisão registrada em FR-012 da spec 023 (2026-08-26) — o
  trabalho de alguém é visível para a própria pessoa, para quem lidera a equipe dela
  e para quem responde pela organização — e o alcance definido em FR-010 da spec
  045. A rota é artefato do roteador, e não fronteira do domínio.
- **FR-024a**: A recusa MUST nomear o motivo — nunca esconder a seção sem dizer por
  quê, e nunca apresentar a quebra vazia como se a equipe não tivesse solicitações.
- **FR-025**: Equipe com **exatamente um** vínculo vigente MUST ser identificada como
  antipadrão de estrutura, e o **agregado** dela MUST seguir a mesma fronteira de
  FR-024 — ali a mediana da equipe é a mediana daquela pessoa, com outro rótulo.

  *Decisão da pessoa mantenedora em 2026-09-04.* A pergunta chegou como escolha entre
  aceitar o risco e definir um piso de pessoas, e a resposta recusou as duas: **é
  anomalia, e anomalia se identifica.** O piso seria vocabulário que a base de
  conhecimento não tem, e escolhê-lo seria a plataforma inventando política. A máxima
  vive em `priv/knowledge_base/rules/structure_antipatterns.yaml`, com a equipe sem
  vínculo nenhum ao lado — zero e um quebram a aritmética da medida por razões
  diferentes, e cada um tem sua máxima.

### Key Entities

- **Solicitação de mudança** — o que é aberto e revisto; carrega quem abriu e
  quando.
- **Avaliação de artefato** — a revisão, com autor humano ou robô e o instante em
  que foi submetida.
- **Vínculo de equipe** — pessoa, papel, equipe e período; a fonte do recorte.
- **Vínculo equipe ↔ projeto** — com `linked_at` e `unlinked_at`, hoje sem
  consumidor.
- **Verificação coletada** — a execução do pipeline, com as cinco fases separadas
  e "em andamento" distinto de "não coletado".

## Success Criteria *(mandatory)*

- **SC-001**: 100% das solicitações apresentadas na tela de uma equipe pertencem
  a quem era membro dela na data de abertura.
- **SC-002**: Registrar uma saída **não altera** nenhum valor já apresentado para
  um período encerrado.
- **SC-003**: 100% das solicitações sem revisão aparecem como espera em curso —
  nenhuma omitida, nenhuma com tempo zero.
- **SC-004**: A resposta de "quem trabalhou no projeto em X" contém exatamente as
  pessoas cuja interseção dos três períodos é não vazia — verificável montando os
  períodos à mão.
- **SC-005**: 100% dos resultados com borda desconhecida trazem a marca de
  período parcialmente desconhecido.
- **SC-006**: Nenhuma pessoa aparece duas vezes na resposta do projeto.
- **SC-007**: A taxa do pipeline **ou** existe com o caminho e o tamanho da
  amostra declarados, **ou** a tela nomeia o elo que falta — nunca "não
  disponível" sem motivo.
- **SC-008**: Verificações em andamento não aparecem em numerador nem
  denominador de nenhuma taxa.
- **SC-009**: 100% das medidas novas estão declaradas em YAML antes de aparecer
  na tela.
- **SC-010**: Nenhuma consulta desta feature devolve dado de outro tenant.
- **SC-011** *(emendado em 2026-09-04)*: Uma pessoa **sem permissão de administrar
  equipes e com escopo sobre a equipe** lê todas as medidas, inclusive a quebra por
  pessoa.

  *A emenda não ajusta o critério ao que foi entregue — faz o contrário.* Como
  estava escrito, SC-011 **exigia o vazamento**: uma conta sem relação nenhuma
  também é "uma pessoa sem permissão de administrar equipes", e o teste implementava
  fielmente o critério. O defeito estava no critério, que confundiu *não administra*
  com *não tem relação nenhuma*.
- **SC-012**: Uma conta sem escopo sobre a equipe lê os agregados e **não** lê
  login, número de solicitação nem mediana individual — **exceto** quando a equipe tem
  um único vínculo vigente, caso em que o agregado também é retido e a anomalia é
  nomeada na tela (FR-025).

## Assumptions

- **O recorte segue a feature 057**: vigência avaliada contra a data do evento,
  borda `[início, fim)`, e `started_at` nulo é membro — nulo é desconhecido,
  nunca "nunca pertenceu".
- **O período padrão é o mesmo da 057**: 8 semanas, sem seletor nesta feature.
- **A distinção robô/humano já existe** em `collected_artifact_evaluations`, e
  esta feature consome — não redefine.
- **As cinco fases de verificação já existem** desde a feature 037, e esta
  feature consome a separação delas.
- **O caminho verificação → equipe foi resolvido pela pesquisa** (R1): é por
  repositório → projeto → equipe, e **não** pelo ator da execução. Os dois
  existem no esquema, e o do ator responde outra pergunta — *quem disparou* não é
  *quem cuida do código*.
- **A cobertura do dado é desconhecida**: a aplicação não sobe neste ambiente
  (`:missing_master_key`), e medir contra o banco não foi possível. Por isso a
  tela declara o tamanho da amostra, e a aceitação inclui medi-lo (R6).
- **A interface é em inglês**, com pt como tradução.
- **Fora de escopo**: `flow.throughput.rate` e `flow.wip.count`, que dependem do
  critério de início da feature 042 e são o único item do épico #504 que precisa
  dela; `rework.not_accepted_deliverable_ratio`, que não se calcula porque a
  aceitação nunca é registrada; seletor de período; exportação; e alerta ativo.
