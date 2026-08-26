# Feature Specification: O critério de início, declarado pela organização

**Feature Branch**: `042-criterio-de-inicio`
**Created**: 2026-08-24
**Status**: Draft
**Fecha**: [#370](https://github.com/The-Band-Solution/theband/issues/370)
**Input**: Decisão da pessoa mantenedora em 2026-08-24 — *"que tal deixar o usuário escolher essa medição por projeto? Colocar um conceito ontológico nisso?"*, seguida de *"podemos fazer uma escala, sendo que o quadro vence o projeto"* e *"tem que ser `linked_at`"*.

## O problema, e por que ele não é de implementação

A `FR-007` da feature 022 diz, e a recusa é deliberada:

> A plataforma MUST NOT escolher sozinha qual evento marca o início de um trabalho.

Por causa disso, **três medidas não existem hoje**: `flow.throughput`, `flow.wip.count` e o cycle time por pessoa. Todas dependem de um instante de início que ninguém nomeou.

A saída não é a plataforma passar a escolher. É a organização **declarar** — e a declaração virar conceito da rede, com proveniência, como tudo mais aqui.

### Por que é conceito ontológico, e não configuração

A UFO já tem as peças:

| conceito | o que diz |
|---|---|
| `ufo.event` | "Indivíduo que ocorre no tempo. Acontece, não persiste." |
| `ufo.situation` | "Eventos são disparados por situações e **trazem à tona** novas situações." |
| `ufo.brings_about` | `event → situation`, causação |
| `ufo.social_object` | "Objeto cuja existência depende de **convenção social**." |

O `ProjectV2ItemStatusChangedEvent` é um `ufo.event`. A situação que ele traz à tona é *"o trabalho começou"*. E `spo.performed_project_activity` **já tem** `start_date` como atributo — o que falta não é o campo, é dizer qual evento o preenche.

Qual evento marca o início **é convenção social**: não há resposta no dado, e organizações diferentes respondem diferente sem que nenhuma esteja errada. Por isso o critério é `ufo.social_object`, e não uma coluna de configuração.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declarar o critério do projeto (Priority: P1)

Quem administra abre um projeto e declara qual evento observado marca o início de um trabalho naquele projeto. A partir daí, as atividades executadas do projeto passam a ter `start_date`.

**Why this priority**: é o mínimo que destrava as três medidas. Sem ela, nada muda.

**Independent Test**: declarar o critério num projeto sem quadros associados e conferir que as atividades daquele projeto ganham `start_date` — e que as de outro projeto continuam sem.

**Acceptance Scenarios**:

1. **Dado** um projeto sem critério declarado, **quando** a pessoa declara `ProjectV2ItemStatusChangedEvent`, **então** a declaração fica gravada com autor e data, e as atividades do projeto passam a ter `start_date` no instante daquele evento.
2. **Dado** um projeto com critério declarado, **quando** a pessoa troca o evento declarado, **então** o `start_date` das atividades muda junto — a resolução acontece **na leitura**, e nunca fica gravada.
3. **Dado** um projeto sem critério, **quando** a tela é aberta, **então** ela diz **quantas** atividades estão sem `start_date` por falta de critério — nunca um padrão implícito.
4. **Dado** um projeto que já tem quadros com critério próprio, **quando** a pessoa vai declarar o critério do projeto, **então** a tela diz **quais quadros vão ignorar** esta declaração — antes de ela gravar, e não depois.

---

### User Story 2 - O quadro vence o projeto (Priority: P1)

Um projeto pode ter mais de um quadro, e quadros podem ter processos diferentes. Quem administra declara o critério no quadro, e ele prevalece sobre o do projeto.

**Why this priority**: sem a escala, um projeto com dois processos precisa de dois projetos. A feature 041 já estabeleceu que um projeto tem vários quadros; esta é a consequência.

**Independent Test**: declarar critérios diferentes no projeto e num quadro dele, e conferir que as issues daquele quadro seguem o do quadro e as demais seguem o do projeto.

**Acceptance Scenarios**:

1. **Dado** um projeto com critério `AssignedEvent` e um quadro dele com critério `ProjectV2ItemStatusChangedEvent`, **quando** uma issue está naquele quadro, **então** vale o do quadro.
2. **Dado** o mesmo projeto, **quando** uma issue **não** está em quadro nenhum, **então** vale o do projeto.
3. **Dado** um quadro **sem** critério declarado, **quando** a issue está nele, **então** vale o do projeto — o quadro só vence quando declarou.

---

### User Story 3 - Desempatar quando a issue está em vários quadros (Priority: P2)

Medido em 2026-08-24: **414 de 3.215 issues (13%) estão em mais de um quadro**, e todas com os dois vínculos vigentes. A escala precisa de uma regra para elas.

**Why this priority**: é 13% do dado. Sem a regra, essas issues ficam sem `start_date` mesmo com critério declarado.

**Independent Test**: pôr uma issue em dois quadros com critérios diferentes e conferir que vale o do quadro cujo vínculo com o projeto é o mais recente.

**Acceptance Scenarios**:

1. **Dado** uma issue em dois quadros com critérios diferentes, **quando** um deles foi associado ao projeto depois, **então** vale o critério desse.
2. **Dado** uma issue em dois quadros associados **no mesmo instante**, **então** `start_date` fica **nulo** com motivo `criterio_ambiguo` — e a issue aparece numa lista de pendências para quem administra resolver.
3. **Dado** uma issue em dois quadros, mas só um deles com critério declarado, **então** vale o declarado — sem desempate, porque não há empate.

---

### Edge Cases

- **Issue em quadros de projetos diferentes**: vale o critério do quadro mais recentemente associado **ao seu próprio projeto**, atravessando a fronteira de projeto. Nenhum caso desses existe no dado de 2026-08-24; a decisão fica registrada como revisável.
- **Critério declarado para um evento que a coleta não traz**: a declaração é aceita e o `start_date` fica nulo, com motivo distinto de "sem critério" — é lacuna de coleta, não de declaração.
- **Evento ocorre mais de uma vez** na mesma issue — uma tarefa que voltou para o Backlog e saiu de novo: vale a **primeira** ocorrência. O início é quando começou, e recomeçar não apaga o começo.
- **Critério desfeito**: marca com autor e data, nunca apaga. As atividades voltam a ter `start_date` nulo, e o histórico da declaração permanece.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A rede MUST declarar `spo.activity_start_criterion` como especialização de `ufo.social_object`, com a definição registrando que qual evento marca o início é **convenção social**, e não fato observado.
- **FR-002**: A rede MUST declarar a relação entre o critério e o tipo de evento que ele reconhece, e a relação entre o critério e aquilo para que ele foi declarado.
- **FR-003**: A plataforma MUST permitir declarar um critério **por projeto** e **por quadro**, com autor e data em cada declaração.
- **FR-004**: A plataforma MUST NOT escolher um critério na ausência de declaração. Sem critério aplicável, `start_date` MUST ficar **nulo**, e a tela MUST informar **quantas** atividades estão nessa condição.
- **FR-005**: A resolução do critério aplicável MUST acontecer **na leitura**, e MUST NOT ser gravada junto da atividade. Trocar a declaração muda a medida sem recálculo.
- **FR-006**: A escala de precedência MUST ser, nesta ordem: **quadro** que declarou, depois **projeto** que declarou, depois **nulo**.
- **FR-007**: Quando a issue estiver em mais de um quadro com critério declarado, MUST prevalecer o do quadro cujo vínculo com o projeto tem `linked_at` **mais recente**.
- **FR-008**: Quando dois ou mais vínculos empatarem em `linked_at`, `start_date` MUST ficar nulo com motivo **`criterio_ambiguo`**, distinto do nulo por ausência de declaração. A plataforma MUST NOT desempatar por conta própria.
- **FR-009**: A tela MUST distinguir, em separado e nunca agregados, três ausências: **sem critério declarado**, **critério ambíguo**, e **evento não coletado**.
- **FR-010**: Desfazer uma declaração MUST marcar com autor e data, e MUST NOT apagar o registro.
- **FR-011**: Quando o evento reconhecido ocorrer mais de uma vez na mesma atividade, MUST valer a **primeira** ocorrência.
- **FR-012**: A plataforma MUST oferecer, para escolha, apenas tipos de evento que ela **coleta** — e MUST mostrar o volume observado de cada um, para a escolha ser informada e não às cegas.

### A regra tem de estar na tela

Uma escala de precedência que decide um número e vive só na spec produz exatamente o efeito que esta casa combate: quem lê o número não sabe de onde ele veio, e quem discorda dele não sabe onde mexer.

- **FR-013**: Toda tela que mostre um instante de início, ou uma medida derivada dele, MUST mostrar **de onde o critério veio** — do quadro (e qual) ou do projeto (e qual). A proveniência acompanha o número, e não vive numa página de ajuda.
- **FR-014**: A tela de declaração MUST mostrar a escala **em vigor naquele alvo**, e não a escala em abstrato. Ao declarar num projeto que tem quadros com critério próprio, a tela MUST dizer **quais quadros vão ignorar** esta declaração, e por quê.
- **FR-015**: As três ausências MUST ser escritas em frase, e nunca em código. *"Nenhum critério foi declarado para este projeto"* é a frase; `criterio_ausente` não é. E cada frase MUST dizer **o que fazer** — declarar, desambiguar, ou coletar.
- **FR-016**: A frase do **critério ambíguo** MUST nomear os quadros em empate e a data que empatou. Sem isso, quem administra sabe que há um problema e não sabe onde ele está.
- **FR-017**: A tela MUST explicar, no ponto da decisão, **por que o desempate é a data do vínculo** — em uma frase, com o custo de errar. Uma regra de precedência que ninguém entende é obedecida sem ser conferida.

### Key Entities

- **Critério de início** — o que a organização declara: qual tipo de evento traz à tona a situação de um trabalho ter começado. Tem autor, data de declaração, e data de desfazimento quando houver.
- **Alvo da declaração** — o projeto ou o quadro para o qual o critério vale.
- **Tipo de evento reconhecido** — o tipo do evento observado que o critério nomeia.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Depois de declarado um critério para um projeto, **100%** das atividades executadas daquele projeto cujo evento reconhecido foi coletado passam a ter instante de início.
- **SC-002**: Quem administra consegue declarar o critério de um projeto em **menos de um minuto**, sem consultar documentação, escolhendo de uma lista que mostra o volume observado de cada tipo de evento.
- **SC-003**: Nenhuma atividade recebe instante de início sem que exista declaração aplicável — verificável contando atividades com início e sem critério: **deve ser zero**.
- **SC-004**: As três ausências aparecem separadas em toda tela que as mostre; **nenhuma tela agrega** "sem critério" com "critério ambíguo" ou com "evento não coletado".
- **SC-005**: Trocar a declaração de um projeto muda a medida na leitura seguinte, **sem nenhuma etapa de recálculo**.
- **SC-006**: Das 414 issues em mais de um quadro medidas em 2026-08-24, a regra de precedência resolve **todas** que tiverem `linked_at` distintos, e nomeia como ambíguas as que empatarem — sem escolher nenhuma por conta própria.
- **SC-007**: Uma pessoa que nunca leu esta spec consegue dizer, olhando a tela, **de onde veio** o instante de início de uma atividade e **o que fazer** quando ele está ausente — sem abrir documentação.
- **SC-008**: Nenhuma tela exibe um código de motivo. Verificável procurando `criterio_ambiguo`, `criterio_ausente` e afins no que a tela renderiza: **deve ser zero**.

---

## Assumptions

- **A declaração é da organização, não da pessoa.** Qualquer pessoa com permissão de administrar o tenant pode declarar, e a declaração vale para todos que leem — não há critério por pessoa.
- **A feature 041 é pré-requisito.** A regra de desempate depende de `spo_project_boards.linked_at`, criada nela. Sem o vínculo projeto↔quadro, a `FR-007` não tem sobre o que operar.
- **`collected_at` foi descartado com medição.** Ele empata em **0,0 segundo em 100% dos 414 casos** — as duas linhas são gravadas na mesma varredura —, e significa *quando nós olhamos*, não quando a organização decidiu. Ordenar por ele devolveria resultado não-determinístico.
- **`AddedToProjectV2Event` foi descartado com medição.** O payload coletado tem apenas `__typename`, `actor` e `createdAt` — **não identifica o quadro**, então não serve para dizer quando a issue entrou em cada um.
- **A escolha de `linked_at` diverge do padrão do mapeamento.** As `issue_mapping_rules` usam `position` para precedência, com ordem explícita. Aqui a ordem é implícita na data do vínculo, porque associar o quadro novo por último **já é** o gesto de dizer qual é o corrente — e pedir uma ordenação separada seria pedir à pessoa que declarasse duas vezes a mesma coisa.
- **Os eventos candidatos, com volume medido em 2026-08-24**: `ProjectV2ItemStatusChangedEvent` 5.965, `AddedToProjectV2Event` 3.028, `AssignedEvent` 2.172.
- **Esta feature não define o fim do trabalho.** `end_date` continua vindo de onde já vem, e `flow.wip.count` — que precisa de início **e** fim — só fica completa quando o critério de fim tiver o mesmo tratamento. Fica declarado como limitação, não como esquecimento.

## Fora do escopo

- **O critério de fim de trabalho.** Mesma forma, feature própria.
- **Sugerir um critério a partir da evidência.** A plataforma mostra o volume de cada tipo de evento; recomendar qual escolher seria escolher com passos extras, e a `FR-007` da 022 proíbe.
- **Migrar declarações entre projetos.** Cada projeto declara o seu.
