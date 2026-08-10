# Feature Specification: Editar e remover ferramentas conectadas

**Feature Branch**: `feature/003-editar-remover-ferramentas`
**Created**: 2026-08-10
**Status**: Draft
**Input**: "adicionar a opção de editar ou remover ferramentas. Por exemplo, remover a observação do github."

## User Scenarios & Testing *(mandatory)*

### O problema, medido

A plataforma sabe conectar uma ferramenta e não sabe desfazer. Hoje há três
organizações observadas, e nenhuma pode deixar de ser:

| Organização | Membros | Só por causa dela | Equipes | Derivadas | Payloads |
|---|---:|---:|---:|---:|---:|
| The-Band-Solution | 6 | 4 | 2 | 0 | 64 |
| ifesserra-lab | 5 | **4** | 1 | **1** | 24 |
| leds-conectafapes | 64 | **62** | 9 | 1 | 384 |

Quem quiser parar de observar `ifesserra-lab` está pedindo que a plataforma deixe
de afirmar coisas sobre 5 pessoas, 1 equipe que ela mesma criou, e 24 payloads
preservados — sem que nada disso deixe de ter existido.

**Duas ausências deliberadas precisam de decisão.** O contrato da feature 001
recusou remover ferramenta e recusou trocar a organização dela, e escreveu por quê:
apagar deixaria órfãos os registros cuja proveniência aponta para ela, e trocar a
organização faria a mesma linha apontar para duas origens ao longo do tempo. As duas
recusas continuam certas. Esta feature decide o que fazer **em vez** de apagar.

### User Story 1 - Parar de observar uma organização (Priority: P1)

Uma pessoa autorizada escolhe uma ferramenta conectada, vê **quanto dado depende
dela**, e encerra a observação. A plataforma para de coletar daquela origem, o
segredo deixa de existir, e o que foi observado continua consultável marcado como
não mais observado.

**Why this priority**: é o pedido. E é o que a plataforma hoje não sabe fazer de
nenhuma forma — nem manualmente, nem pela interface.

**Independent Test**: encerrar a observação de uma organização e conferir que a
próxima sincronização não a inclui, que a credencial não existe mais, e que as
pessoas e equipes dela continuam consultáveis com a marca de não mais observadas.

**Acceptance Scenarios**:

1. **Given** uma ferramenta com dado coletado, **When** o usuário pede para encerrar
   a observação, **Then** a plataforma mostra **antes de confirmar** quantas pessoas,
   equipes e vínculos dependem dela, e quantos existem só por causa dela.
2. **Given** a confirmação dada, **When** a observação é encerrada, **Then** a
   ferramenta deixa de ser sincronizada, e nenhuma coleta futura a inclui.
3. **Given** a observação encerrada, **When** o usuário consulta pessoas e equipes,
   **Then** os registros daquela origem continuam visíveis, marcados como não mais
   observados, com a data em que deixaram de ser.
4. **Given** a observação encerrada, **When** alguém procura a credencial,
   **Then** ela **não existe mais** — nem cifrada, nem desativada.
5. **Given** uma pessoa que estava em duas organizações e perdeu uma, **When** o
   usuário a consulta, **Then** ela continua vinculada à outra, e o vínculo encerrado
   permanece como histórico.
6. **Given** uma organização que tinha equipe derivada, **When** a observação é
   encerrada, **Then** a equipe derivada é marcada como não mais observada, e não
   apagada — ela existiu.

### User Story 2 - Retomar uma observação encerrada (Priority: P2)

A pessoa que encerrou por engano, ou que voltou a precisar daquela organização,
reconecta informando uma credencial nova. A plataforma reconhece que já observou
aquela organização e **retoma o registro existente** em vez de criar um segundo.

**Why this priority**: sem isso, encerrar é irreversível na prática, e um encerramento
irreversível faz as pessoas não encerrarem — deixam a ferramenta lá, quebrada.
Depende de US1 existir.

**Independent Test**: encerrar uma observação, reconectar a mesma organização, e
conferir que a plataforma não criou uma segunda ferramenta nem duplicou pessoas e
equipes.

**Acceptance Scenarios**:

1. **Given** uma observação encerrada, **When** o usuário reconecta a mesma
   organização na mesma instância, **Then** a plataforma retoma a ferramenta
   existente, e não cria uma segunda.
2. **Given** a observação retomada, **When** a coleta seguinte ocorre, **Then** as
   pessoas e equipes que voltaram a aparecer perdem a marca de não mais observadas, e
   as que não voltaram a mantêm.
3. **Given** uma observação encerrada, **When** o usuário reconecta, **Then** é
   exigida uma credencial nova — a anterior deixou de existir no encerramento.
4. **Given** a observação retomada, **When** o usuário consulta o histórico da
   ferramenta, **Then** consta quando foi encerrada e quando foi retomada.

### User Story 3 - Ajustar o que é ajustável (Priority: P3)

A pessoa autorizada renomeia credenciais, remove uma credencial que não usa mais, e
limpa o estado de atenção depois de resolver o que o causou. A tela diz **o que não é
editável e por quê**.

**Why this priority**: é o menor pedaço do pedido, e o mais fácil de fazer errado. A
tentação é permitir editar a instância e a organização, e isso é a segunda ausência
que a feature 001 recusou com razão.

**Independent Test**: renomear uma credencial e conferir que só o rótulo mudou;
tentar alterar a organização e conferir que a interface não oferece, dizendo o motivo.

**Acceptance Scenarios**:

1. **Given** uma ferramenta com duas credenciais, **When** o usuário renomeia uma,
   **Then** só o rótulo muda — o segredo, os escopos e a data de validação
   permanecem.
2. **Given** uma ferramenta com duas credenciais, **When** o usuário remove uma,
   **Then** o segredo deixa de existir, e a ferramenta continua funcionando com a
   outra.
3. **Given** uma ferramenta com **uma** credencial ativa, **When** o usuário tenta
   removê-la, **Then** a plataforma recusa, dizendo que encerrar a observação é o
   caminho para parar de coletar.
4. **Given** uma ferramenta marcada como precisando de atenção, **When** o usuário
   limpa o estado depois de trocar a credencial, **Then** a ferramenta volta a
   sincronizar.
5. **Given** qualquer ferramenta, **When** o usuário procura editar a organização ou
   a instância, **Then** a interface não oferece, e explica que aquilo é a identidade
   da ferramenta — outra organização é outra ferramenta.

### Edge Cases

- **Encerrar durante uma coleta em andamento.** A coleta em curso termina ou é
  interrompida? Uma coleta que continua escrevendo depois do encerramento produziria
  registros observados de uma origem que a plataforma diz não observar.
- **Encerrar a última ferramenta do tenant.** A organização cliente fica sem nenhuma
  origem. As telas precisam distinguir "nunca conectou" de "encerrou tudo".
- **Retomar uma organização que foi renomeada na origem.** O `login` mudou no GitHub,
  e o identificador externo é o mesmo. A plataforma reconhece pelo identificador, não
  pelo nome.
- **Pessoa que existia só por causa da organização encerrada.** Quatro das cinco de
  `ifesserra-lab`. Ela continua existindo, marcada, e sem organização observada
  vigente — o que é diferente de não ter organização nenhuma.
- **A equipe derivada de uma organização encerrada.** Ela não existe na origem, e
  agora a origem também não é observada. Continua existindo como registro, marcada.
- **Duas ferramentas para a mesma organização em instâncias diferentes.** Encerrar
  uma não encerra a outra, e os registros com proveniência da outra permanecem
  vigentes.
- **Encerrar e reconectar no mesmo dia.** A marca de não mais observado é aplicada e
  depois removida pela coleta. O histórico precisa mostrar as duas transições, não
  apenas o estado final.
- **Remover credencial que está em uso por uma coleta naquele instante.**

## Requirements *(mandatory)*

### Functional Requirements

**Encerrar a observação**

- **FR-001**: A plataforma MUST permitir encerrar a observação de uma ferramenta
  conectada.
- **FR-002**: A plataforma MUST apresentar, **antes da confirmação**, quantas
  pessoas, equipes e vínculos têm proveniência naquela ferramenta, e quantos deles
  existem exclusivamente por causa dela.
- **FR-003**: A plataforma MUST exigir, para encerrar uma observação que tenha dado
  coletado, que a pessoa **digite o nome da organização** — confirmação distinta de um
  clique, e distinta de dois cliques.
- **FR-004**: A plataforma MUST NOT apagar pessoas, equipes, vínculos ou payloads
  preservados ao encerrar uma observação.
- **FR-005**: A plataforma MUST marcar como não mais observados, com a data do
  encerramento, os registros cuja proveniência é aquela ferramenta e que não tenham
  proveniência vigente em outra.
- **FR-006**: A plataforma MUST preservar vigentes os registros que também têm
  proveniência em outra ferramenta ainda observada.
- **FR-007**: A plataforma MUST destruir as credenciais da ferramenta ao encerrar a
  observação — não desativar.
- **FR-008**: A plataforma MUST NOT incluir ferramenta com observação encerrada em
  nenhuma coleta.
- **FR-009**: A plataforma MUST registrar quando a observação foi encerrada e por
  qual usuário.
- **FR-010**: A plataforma MUST marcar como não mais observada a equipe derivada da
  organização encerrada, sem apagá-la.

**Retomar**

- **FR-011**: A plataforma MUST permitir reconectar uma organização cuja observação
  foi encerrada.
- **FR-012**: A plataforma MUST retomar a ferramenta existente ao reconectar a mesma
  combinação de tipo, instância e organização, sem criar uma segunda.
- **FR-013**: A plataforma MUST exigir credencial nova ao retomar, porque a anterior
  foi destruída.
- **FR-014**: A plataforma MUST registrar cada encerramento e cada retomada, de forma
  que o histórico mostre as transições e não apenas o estado atual.

**Editar**

- **FR-015**: A plataforma MUST permitir renomear o rótulo de uma credencial sem
  alterar o segredo, os escopos ou a data de validação.
- **FR-016**: A plataforma MUST permitir remover uma credencial, destruindo o
  segredo.
- **FR-017**: A plataforma MUST recusar a remoção da última credencial ativa de uma
  ferramenta observada, dizendo que encerrar a observação é o caminho para parar de
  coletar.
- **FR-018**: A plataforma MUST permitir limpar o estado de atenção de uma
  ferramenta.
- **FR-019**: A plataforma MUST NOT permitir alterar o tipo, a instância ou a
  organização de uma ferramenta conectada.
- **FR-020**: A interface MUST explicar por que tipo, instância e organização não são
  editáveis, no lugar onde alguém procuraria editá-los.

**Interface**

- **FR-021**: A tela de ferramentas MUST oferecer encerrar a observação, editar
  credenciais e limpar o estado de atenção, cada um no contexto da ferramenta.
- **FR-022**: A tela MUST distinguir ferramenta observada, ferramenta com
  observação encerrada e ferramenta precisando de atenção.
- **FR-023**: As telas de pessoas e equipes MUST distinguir registro de origem
  vigente de registro de origem encerrada.
- **FR-024**: O estado vazio MUST distinguir "nenhuma ferramenta foi conectada" de
  "todas as observações foram encerradas".

**Segurança e escopo**

- **FR-025**: A plataforma MUST recusar encerrar, editar ou remover ferramenta de
  outra organização cliente, devolvendo não encontrado.
- **FR-026**: A plataforma MUST NOT expor o segredo de uma credencial em nenhuma tela
  de edição.
- **FR-027**: A plataforma MUST interromper de forma controlada a coleta em
  andamento da ferramenta cuja observação foi encerrada, preservando o progresso
  parcial.

### Key Entities

- **Ferramenta conectada**: passa a ter um estado de observação — vigente ou
  encerrada — com a data e o autor de cada transição. Tipo, instância e organização
  permanecem identidade imutável.
- **Credencial**: passa a poder ser renomeada e destruída. Destruir é diferente de
  desativar: desativada continua existindo cifrada, destruída não existe.
- **Registro observado** — pessoa, equipe, vínculo: já sabe dizer que não é mais
  observado. O encerramento passa a ser uma segunda causa dessa marca, ao lado da
  ausência percebida entre coletas.
- **Histórico de observação**: as transições de encerrar e retomar, para que o
  registro mostre o que aconteceu e não só onde parou.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Encerrar a observação de uma organização não apaga nenhum registro:
  as contagens de pessoas, equipes, vínculos e payloads preservados permanecem as
  mesmas antes e depois.
- **SC-002**: Depois do encerramento, 100% dos registros cuja única proveniência era
  aquela ferramenta aparecem marcados como não mais observados, com a data.
- **SC-003**: Nenhum registro com proveniência vigente em outra ferramenta é marcado.
- **SC-004**: Depois do encerramento, nenhuma credencial daquela ferramenta existe na
  base — nem cifrada.
- **SC-005**: A coleta seguinte ao encerramento não faz nenhuma consulta à origem
  encerrada.
- **SC-006**: Reconectar a mesma organização não cria uma segunda ferramenta, e não
  duplica nenhuma pessoa ou equipe.
- **SC-007**: Depois de reconectar e coletar, os registros que voltaram a aparecer na
  origem estão vigentes, e os que não voltaram continuam marcados.
- **SC-008**: A pessoa que perdeu uma organização de duas continua vinculada à outra,
  e o vínculo encerrado permanece consultável.
- **SC-009**: A tela mostra o impacto do encerramento antes da confirmação, e os
  números conferem com o que o encerramento de fato marca.
- **SC-010**: Um usuário de uma organização cliente não encerra, edita nem remove
  ferramenta de outra por nenhum caminho.
- **SC-011**: Nenhuma tela de edição exibe segredo de credencial em forma utilizável.

## Assumptions

- **Encerrar não é apagar, e isso não é escolha desta feature.** A semântica
  "ausência não é remoção" já vale para pessoas, equipes e vínculos, e o princípio III
  da constituição torna proveniência não negociável. Encerrar a observação é a mesma
  situação epistêmica de a origem parar de mostrar o registro: a plataforma marca.
- **A credencial é a única coisa destruída.** Um segredo que deixou de ser usado deve
  deixar de existir: guardá-lo cifrado "por histórico" aumenta a superfície de ataque
  sem responder pergunta nenhuma. Proveniência não depende dele.
- **A ferramenta não é apagada.** A linha dela é o que liga os payloads preservados à
  organização de origem, e é essa corrente que sustenta o reprocessamento e o
  retrofito. Apagá-la quebraria a correção de dado já coletado — o oposto do que
  FR-017 da feature 001 existe para permitir.
- **Tipo, instância e organização continuam imutáveis.** A recusa da feature 001
  permanece: a mesma linha apontando para duas origens ao longo do tempo faria a
  proveniência dos registros antigos mentir.
- **Retomar reusa a linha existente.** A identidade da ferramenta é tipo, instância e
  organização, e o índice de unicidade já garante isso. Criar uma segunda linha para a
  mesma origem produziria duas proveniências para o mesmo dado.
- **Quem pode conectar pode encerrar.** O papel administrativo do tenant já governa a
  conexão; encerrar não é ato mais perigoso que conectar uma credencial com acesso de
  leitura à organização.
- **A confirmação exige digitar o nome da organização.** Encerramento é a ação de
  maior consequência da plataforma, e um clique único é fácil demais de dar por
  engano.

## Dependencies

- Feature 001 — ferramentas conectadas, credenciais protegidas, coleta, e a
  capacidade de marcar pessoa, equipe e vínculo como não mais observados.
- Feature 002 — organização em cada pessoa e equipe, e a equipe derivada, sem as
  quais não há como dizer o que depende de qual origem.

## Out of Scope

- **Apagar dado coletado.** Não é o que "remover a observação" significa aqui, e
  contraria o princípio III. Se um dia for necessário — pedido de exclusão de dado
  pessoal, por exemplo —, é feature própria, com o seu próprio registro de decisão.
- **Trocar a organização ou a instância de uma ferramenta.** Recusa mantida.
- **Agendar a sincronização.** É a feature seguinte.
- **Exportar o dado antes de encerrar.** Encerrar não perde nada, então não há o que
  salvar antes.
- **Encerrar em lote.** Uma ferramenta por vez, com o impacto de cada uma à vista.
