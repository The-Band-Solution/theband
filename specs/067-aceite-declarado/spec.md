# Feature Specification: O critério de aceite declarado pela organização

**Feature Branch**: `067-aceite-declarado`

**Created**: 2026-09-14

**Status**: Draft — emendada em 2026-09-14 (o gesto em dois passos: estágio de avaliação +
sentido de cada saída, com a saída *sem veredito*; o modelo por transições não muda) e em
2026-09-15 (o protótipo, e os links para a 066 que passaram a resolver com o merge dela)

**Input**: a pessoa mantenedora, em 2026-09-14, concordou com o caminho (c) da spec 066: *"o
caminho honesto é um critério de aceitação declarado: a organização declara que Homologation →
Done é a avaliação de aceite e → Desaprovado a recusa — objeto social como
`spo.activity_start_criterion`, declarado com autor e data, resolvido na leitura. Estou de
acordo."*

**Irmãs**: a **042** declara qual movimentação marca o **começo** do trabalho; a
[**066**](../066-pronto-declarado/spec.md) — **mergeada em 2026-09-15** — declara
qual estágio marca o **fim** da execução e preserva o estágio como período; esta declara qual
transição é a **avaliação de aceite** do entregável. As três têm o mesmo desenho: por quadro,
autor e data, revogar marca, resolução na leitura, e o quadro apontado como coleta — porque não é
conceito da rede.

**Protótipo, 2026-09-14** — <https://claude.ai/artifact/Gi7gtFR9uJfynPbuEuAU9g>, com a cópia
que vale em [`../066-pronto-declarado/prototipo/board-declarations.html`](../066-pronto-declarado/prototipo/board-declarations.html)
(mergeado com a 066, porque as três declarações vivem na **mesma tela**). **O cartão C — *Where
evaluation happens* — é desta spec**: o estágio de avaliação escolhido, as seis saídas com
contagem, os três sentidos, a cláusula do robô e a cobertura. A régua do QA é a seção 3 do
[`PROMPT.md`](../066-pronto-declarado/prototipo/PROMPT.md); as decisões e as cinco perguntas em
aberto, o [`README.md`](../066-pronto-declarado/prototipo/README.md). **Aprovação: aguardando a
pessoa mantenedora.** A tela implementada é **exatamente** a aprovada.

**Decisões da pessoa mantenedora que esta spec respeita**: a issue é da pessoa pelo responsável;
*Homologation* é em andamento e trabalho da pessoa (066); o estágio é período no item (066,
FR-024); duplicata é `stateReason`; aceitação **não** deriva do PR nem do fechamento.

---

## O que já existe, medido e não suposto

**A aceitação não existe na plataforma.** A matriz de cobertura GitHub → SRO marca
`sro.accepted_deliverable` como não observável — *"não há avaliação contra critério de
aceitação"* —, o estado fica `unknown`, e a regra que materializa sprints recusa
`sro.sprint_deliverable` pelo mesmo motivo: ele é composto **só de aceitos**. A regra
`sro.rule03` fixa o porquê: *"um entregável é aceito quando está em conformidade com todos os
critérios de aceitação das user stories que materializa; a classificação nunca é atribuída
manualmente sem avaliação dos critérios"*. Os critérios não são extraídos do texto da issue, por
decisão: *"extrair por heurística produziria critério plausível e errado"*.

**"PR mergeado = sucesso" foi testado e refutado** — quadro 43 da `leds-conectafapes`,
2026-09-14:

| estágio | itens | com PR mergeado vinculado | com PR aprovado em revisão |
|---|---|---|---|
| Done | 459 | 259 | 247 |
| **Homologation** | 335 | **248** | 246 |
| **Desaprovado** | 8 | **5** | **5** |
| In Progress | 23 | 1 | 1 |

O PR entra **antes** da homologação; os cinco *Desaprovado* têm PR mergeado **e** aprovado. O
PR dá `sro.deliverable` (a tarefa produziu algo) e a execução — nada sobre aceite. Quem avalia,
no Conecta Fapes, é o **cliente**, na homologação.

**As transições já estão coletadas.** O banco tem **9 863** eventos de mudança de estágio
(estágio anterior, novo, ator, instante), **5 503 do `conectafapes-project`**, até 2026-09-09.
O que eles dizem sobre "Done":

| transição | vezes | período |
|---|---|---|
| In Progress → Done | 197 | fev/25 – jul/26 |
| **Backlog → Done** | **119** | mar/25 – dez/25 |
| To Do → Done | 58 | fev/25 – jul/26 |
| (entrou no quadro já Done) | 48 | mar/25 – ago/26 |
| **Homologation → Done** | **10** | mai/26 – jul/26 |
| In Validation → Done | 9 | jul/26 – set/26 |
| Refinamento → Done | 5 | mai/26 |
| **Homologation → Desaprovado** | **0** | — (o único *Desaprovado* veio de *In Progress*) |
| Homologation → In Validation / To Do / Dependencies | 4 | jul/26 – set/26 |

E **80 das movimentações para Done foram do robô do quadro** (`github-project-automation`), que
move o card quando a issue fecha. **Done não é uma coisa só**: chega-se a ele do Backlog, do To
Do, pelo robô, e — dez vezes — da homologação. Só a última é avaliação. É por isso que o critério
tem de ser a **transição** (de onde → para onde), não o estágio de chegada.

**Cobertura**: 147 issues passaram por *Homologation* segundo os eventos, 2 delas duas vezes;
hoje **335** itens estão em *Homologation* no quadro 43. A diferença é coleta parcial — itens que
chegaram ao quadro já naquele estágio, ou eventos ainda não coletados. Toda medida desta spec
diz **quantos itens têm evento e quantos não**.

**O molde existe.** O critério de início (042) é um objeto social declarado por quadro — tipo do
evento, quem declarou e quando, quem revogou e quando —, com a determinação do início resolvida
**na leitura, nunca gravada**, e com a limitação escrita de que o quadro não é conceito da rede.
Esta spec copia o desenho e muda a pergunta.

## A decisão central: a organização diz qual evento É a avaliação

A `rule03` proíbe **marcar** um item como aceito. Ela não proíbe a organização de dizer **qual
acontecimento do seu processo é a avaliação dos critérios** — no Conecta Fapes, o cliente move o
card de *Homologation* para *Done* quando aprova e para *Desaprovado* quando recusa. A
plataforma registra **essa declaração**, com quem e quando, e deriva a fase de cada entregável
**na leitura**, carregando a proveniência: *"aceito — declarado pela organização pelo critério
X; transição Homologation → Done em 30/07/2026, por joaomrpimentel"*. Nunca *"verificado"*.

Três afirmações passam a coexistir sobre o mesmo item, com naturezas distintas e **nunca
somadas**:

| afirmação | natureza | de onde vem |
|---|---|---|
| fechada na origem | observado | `state` / `closed_at` |
| concluída pelo quadro | declarado (066) | estágio atual lido pela definição de pronto |
| **aceito / não aceito pelo critério da organização** | **declarado (esta spec)** | a transição declarada como avaliação, ocorrida no item |

Sem critério declarado, a aceitação continua `unknown` — escrita como *"critério não
declarado"*. Com critério e sem a transição no item, *"sem avaliação declarada"*. São duas
ausências diferentes, e a tela distingue.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declarar onde a avaliação acontece, e o que cada saída significa (Priority: P1)

Quem administra a organização abre o quadro e declara em **dois passos** (decisão da pessoa
mantenedora, 2026-09-14): (1) **qual estágio é a avaliação** neste quadro — *Homologation*; (2)
**o que cada saída dele significa** — → *Done* é **aceito**, → *Desaprovado* é **não aceito**,
→ *To Do* e → *Dependencies* é **voltou sem veredito**. O modelo por baixo é o mesmo: cada saída
classificada é uma transição (de → para) com um sentido. Um quadro pode ter mais de um estágio de
avaliação (*In Validation* e *Homologation*), cada um com as suas saídas. A plataforma **não
propõe nem sugere** — como na 042, recomendar seria escolher com passos a mais; ela mostra, ao
lado de cada saída, quantas vezes ocorreu nos eventos coletados. A declaração fica com autor e
instante; pode ser **revogada**, nunca apagada.

**Why this priority**: sem a declaração não há aceitação na plataforma — é a fundação, e é a
decisão que a `rule03` exige que seja de quem conhece o processo.

**Independent Test**: no quadro 43, escolher *Homologation* como estágio de avaliação, ver as
saídas observadas dele com as contagens — → *Done* **10**, → *In Validation* 2, → *To Do* 1, →
*Dependencies* 1, → *Desaprovado* **0** —, classificar *Done* = aceito, *Desaprovado* = não
aceito, as outras = sem veredito, e ler quantos itens estão hoje em *Homologation* sem evento
de entrada.

**Acceptance Scenarios**:

1. **Given** um quadro com estágios observados, **When** a pessoa que administra abre a
   declaração de aceite, **Then** vê os estágios na ordem observada e escolhe **qual é a
   avaliação**; **nenhum** vem pré-marcado nem sugerido.
2. **Given** *Homologation* escolhido como avaliação, **When** a tela mostra as saídas, **Then**
   lista **toda** saída observada desse estágio nos eventos (e os estágios do quadro ainda sem
   saída registrada), cada uma com a contagem e sem sentido pré-atribuído; a pessoa dá a cada
   saída um de três sentidos — **aceito** · **não aceito** · **sem veredito**.
3. **Given** *→ Done = aceito* ativado, **When** a pessoa lê a regra, **Then** vê autor e
   instante, as **10** ocorrências coletadas, e quantos itens estão em *Done* **sem** ter saído
   da avaliação (119 do *Backlog*, 80 pelo robô) — que **não** são aceitos.
3b. **Given** *→ Desaprovado = não aceito* ativado, **When** a pessoa lê a regra, **Then** vê
   **zero ocorrências coletadas** — e que zero é contagem, não ausência de critério.
3c. **Given** uma saída observada que a pessoa **não classificou**, **When** um item a percorre,
   **Then** a tela diz *"saída não declarada"* — nunca assume veredito nem "sem veredito".
4. **Given** uma declaração ativa, **When** a pessoa a revoga, **Then** ela ganha fim, autor e
   instante; segue listada como revogada; e as fases derivadas de avaliações **anteriores à
   revogação** continuam a existir, porque usam o critério vigente no instante da avaliação.
5. **Given** conta que não administra, **When** tenta declarar ou revogar, **Then** é recusada
   com a razão, e nada muda.
6. **Given** a declaração, **When** a pessoa escolhe restringir a **atores humanos** (excluir o
   robô do quadro), **Then** a cláusula fica gravada com a declaração, e transições feitas pelo
   robô deixam de contar como avaliação — ditas como *"movida pela automação, não avaliada"*.

---

### User Story 2 - Ver a fase de aceite no item, como declarada (Priority: P1)

Quem abre um item vê, ao lado de *fechada na origem* e *concluída pelo quadro*, a terceira
afirmação: **aceito**, **não aceito**, **sem avaliação declarada** ou **critério não declarado**
— sempre com a marca *declarado*, o nome do critério, o instante e o ator da transição. E, para
a tarefa, a fase de sucesso que decorre: executada **com sucesso** ou **sem sucesso**, pela mesma
proveniência.

**Why this priority**: é o que fecha a lacuna da matriz — `sro.accepted_deliverable` deixa de
ser `unknown` onde a organização declarou, e continua `unknown` **dito** onde não.

**Independent Test**: com o critério do quadro 43 ativo, abrir uma das 10 issues com transição
*Homologation → Done* e ler *"aceito — Homologation → Done em <data>, por <ator> · critério
declarado por <quem> em <quando>"*; abrir uma das 119 *Backlog → Done* e ler *"concluída pelo
quadro · sem avaliação declarada"*.

**Acceptance Scenarios**:

1. **Given** critério ativo e item com a transição de aceite, **When** abro o detalhe, **Then**
   leio *aceito*, com a marca *declarado*, o instante e o ator da transição, e o nome do
   critério; e a tarefa correspondente diz *executada com sucesso — por declaração*.
2. **Given** critério ativo e item com a transição de recusa, **When** abro o detalhe, **Then**
   leio *não aceito*, com a mesma proveniência, e a tarefa diz *executada sem sucesso — por
   declaração*.
3. **Given** critério ativo e item em *Done* **sem** a transição declarada, **When** abro o
   detalhe, **Then** leio *"concluída pelo quadro · sem avaliação declarada"* — nunca *aceito*.
4. **Given** quadro **sem** critério, **When** abro qualquer item dele, **Then** leio *"critério
   de aceite não declarado"* — distinto de *"sem avaliação"*.
5. **Given** item avaliado e depois **reavaliado** (recusado, voltou, aceito), **When** abro o
   detalhe, **Then** a fase atual é a da **última** avaliação, e o histórico das avaliações
   aparece, uma por linha, com instante e veredito.
6. **Given** issue fechada como *não planejada* ou *duplicada*, **When** abro o detalhe, **Then**
   a afirmação de aceite diz *"fora da avaliação — fechada como <razão>"*, e o item não entra em
   nenhuma contagem de aceite.

---

### User Story 3 - Aceitos, recusados e sem avaliação — por pessoa, equipe e quadro (Priority: P2)

Quem acompanha uma pessoa, uma equipe ou um quadro vê **três contagens, sempre as três**:
aceitos pelo critério da organização, recusados, e sem avaliação declarada — mais, à parte, os
fechados como não planejados ou duplicados. Nenhuma tela soma essas contagens com fechadas na
origem nem com concluídas pelo quadro. E toda tela diz a **cobertura**: quantos itens têm evento
de transição coletado e quantos não.

**Why this priority**: é o que a pessoa do feedback pediu ao dizer que Done era tratado como
open — mas com a distinção que o Done sozinho não faz: dos 459 Done do quadro 43, os aceitos
pelo cliente são os que passaram pela homologação.

**Independent Test**: no painel de uma pessoa com itens no quadro 43, ler *"N aceitos · M
recusados · K sem avaliação declarada · J fora da avaliação"*, e a linha de cobertura.

**Acceptance Scenarios**:

1. **Given** critério ativo, **When** abro o painel da pessoa, **Then** vejo as três contagens
   com a definição escrita, cada uma abrindo a lista, e a cobertura *"X com evento · Y sem"*.
2. **Given** critério ativo, **When** abro a tela da equipe ou o quadro, **Then** as mesmas três,
   restritas ao recorte, e **nenhum** número que as some a fechadas ou a concluídas pelo quadro.
3. **Given** quadro sem critério, **When** abro qualquer dessas telas, **Then** no lugar das três
   leio *"critério de aceite não declarado — declarar no quadro"*, com o caminho.

---

### User Story 4 - O retrabalho medido sem heurística (Priority: P2)

Quem acompanha o quadro vê **quantos itens foram recusados e voltaram**, quantas vezes cada um, e
o **tempo entre a recusa e a avaliação seguinte** — e, dos períodos de estágio da 066, o tempo
em homologação. É a razão de as fases de aceite existirem na SRO: *"é assim que se mede
retrabalho sem inventar heurística"*.

**Why this priority**: depende da US1 e dos períodos da 066; hoje o dado é pequeno (2 retornos
em 147 passagens), mas é o dado que o processo do Conecta produz todo dia.

**Independent Test**: no quadro 43, ler *"2 itens voltaram à homologação (de 147 que passaram) ·
mediana em Homologation: N dias · 335 lá agora, 188 sem evento de entrada"*.

**Acceptance Scenarios**:

1. **Given** critério ativo e períodos de estágio, **When** abro o quadro, **Then** vejo os
   retornos (itens, vezes), o tempo entre recusa e nova avaliação, e o tempo no estágio de
   homologação — cada medida com o **n** e a cobertura.
2. **Given** itens sem evento de entrada no estágio, **When** a medida é calculada, **Then** eles
   ficam **fora** da mediana e aparecem na linha *"sem período conhecido"* — nunca datados pela
   coleta.

---

### User Story 5 - O entregável do sprint, composto só de aceitos (Priority: P3)

Para quadros com critério declarado, `sro.sprint_deliverable` passa a existir: a integração dos
entregáveis **aceitos** do sprint, com a proveniência *declarado pela organização*. A regra que
hoje recusa materializá-lo passa a dizer a **condição** em vez de recusar sempre.

**Why this priority**: é consequência, não pedido — e só faz sentido depois que US1–US3 estão em
uso.

**Independent Test**: num sprint do quadro 43 com itens aceitos, ver o entregável do sprint com a
lista dos aceitos e a marca *declarado*; num quadro sem critério, ver *"não materializável —
critério de aceite não declarado"*.

**Acceptance Scenarios**:

1. **Given** sprint com itens aceitos pelo critério, **When** abro o sprint, **Then** vejo o
   entregável do sprint composto **só** deles, com a proveniência declarada.
2. **Given** quadro sem critério, **When** abro o sprint, **Then** leio a razão de não haver
   entregável do sprint — a mesma que a regra escreve.

---

### Edge Cases

- **Transição declarada que nunca ocorreu** (*Homologation → Desaprovado*: zero eventos): o
  critério é válido; a contagem é zero **dito**, com a data até a qual os eventos foram
  coletados.
- **Chegou a Done sem passar pela avaliação** (119 do *Backlog*, 58 do *To Do*, 80 pelo robô):
  *concluída pelo quadro* (066) e *sem avaliação declarada* (esta) — as duas, e nunca *aceito*.
- **O ator é a automação do quadro**: mostrado sempre; conta como avaliação salvo cláusula de
  atores humanos na declaração (US1, cenário 6).
- **Avaliação e reavaliação**: recusado, voltou, aceito — a fase atual é a última; todas ficam no
  histórico; o retrabalho conta a partir delas.
- **Aceito e depois a issue reabre**: a afirmação de origem muda (*aberta*); a de aceite **não**
  — a avaliação aconteceu. A tela mostra as duas, e a discordância é informação.
- **Critério revogado**: avaliações anteriores usam o critério vigente no instante em que
  ocorreram; depois da revogação, novos itens ficam em *"critério não declarado"*.
- **Estágio renomeado** (*Desaprovado* → *Reprovado*): a declaração referencia identificadores;
  a tela mostra o nome atual e o do momento da declaração, quando diferem.
- **Item em dois quadros com critérios diferentes**: uma afirmação de aceite por quadro,
  nomeado; nenhuma síntese.
- **Evento de saída sem evento de entrada** (coleta parcial): a avaliação vale — a transição
  ocorreu —, e o tempo em homologação fica *"desconhecido"* para esse item.
- **Issue fechada como *não planejada* ou *duplicada***: fora da avaliação, à parte, dita.
- **Dois estágios de avaliação** (*In Validation* e *Homologation*, ambos com saída → *Done* =
  aceito): um item pode ter as duas no histórico; cada avaliação nomeia o estágio de que saiu.
- **Saída nova que surge depois da declaração** (o quadro ganha *Reprovado* e um item sai de
  *Homologation* para lá): fica *não declarada*, contada e mostrada até alguém classificá-la.

## Requirements *(mandatory)*

### Functional Requirements

**A declaração**

- **FR-001**: A organização MUST poder declarar, **por quadro**, um ou mais **estágios de
  avaliação** e, para cada saída observada deles, um sentido — **aceito** · **não aceito** ·
  **sem veredito**. Cada saída classificada é uma **transição** (de → para) com sentido; a
  declaração MUST referenciar os **identificadores** das opções, guardando os nomes no momento.
  Saída não classificada MUST ficar *não declarada* — nunca recebe sentido por omissão.
- **FR-002**: Toda declaração e toda revogação MUST gravar quem e quando; revogar MUST marcar,
  nunca apagar; períodos de vigência MUST ficar consultáveis.
- **FR-003**: A plataforma MUST NOT propor nem sugerir estágio de avaliação nem sentido de saída;
  MUST apenas oferecer os estágios observados do quadro, na ordem observada, e — escolhido o
  estágio de avaliação — **toda** saída observada dele com a contagem nos eventos coletados,
  mais os estágios sem saída registrada.
- **FR-004**: Só quem administra a organização MUST poder declarar ou revogar; quem não
  administra MUST ver a declaração e MUST NOT ver ação.
- **FR-005**: A declaração MAY carregar a cláusula *"só transições feitas por pessoa"*; sem a
  cláusula, transições da automação do quadro contam, e o ator MUST aparecer sempre.

**A derivação**

- **FR-006**: A fase de aceite de um entregável — `sro.accepted_deliverable` ou
  `sro.not_accepted_deliverable` — MUST ser **derivada na leitura** da última saída com sentido
  *aceito* ou *não aceito* ocorrida no item, sob o critério vigente **no instante da transição**;
  uma saída *sem veredito* MUST NOT produzir fase — o item volta a *sem avaliação declarada*, e a
  passagem conta como retorno (FR-014); nada de fase MUST ser gravado no item.
- **FR-007**: Toda fase derivada MUST carregar a proveniência **declarado pela organização**: o
  critério, a transição, o instante, o ator, e quem declarou o critério e quando; MUST NOT ser
  apresentada como verificação da plataforma.
- **FR-008**: A fase de sucesso da tarefa — `sro.successfully_performed_scrum_development_task`
  ou `sro.non_successfully_performed_…` — MUST decorrer **exclusivamente** da fase de aceite dos
  entregáveis que ela produziu, com a mesma proveniência; MUST NOT decorrer de PR mergeado,
  aprovado, nem de issue fechada.
- **FR-009**: A plataforma MUST distinguir, em texto, **quatro** situações: *aceito*, *não
  aceito*, *sem avaliação declarada* (critério existe, transição não ocorreu no item) e *critério
  não declarado* (o quadro não tem critério); e MUST pôr **à parte** as issues fechadas como não
  planejadas ou duplicadas.
- **FR-010**: A plataforma MUST NOT oferecer, em tela nenhuma, ação que marque um item como
  aceito ou não aceito diretamente — a `sro.rule03` fica preservada porque a declaração nomeia o
  **evento** que é a avaliação, não a fase de um item.

**As três afirmações**

- **FR-011**: O detalhe do item MUST mostrar a afirmação de aceite ao lado de *fechada na origem*
  e *concluída pelo quadro* (066), as três com a marca de natureza (observado · declarado), sem
  síntese; e MUST mostrar o histórico de avaliações do item, uma por linha.
- **FR-012**: Painel da pessoa, tela da equipe e quadro MUST mostrar **as três contagens**
  (aceitos · recusados · sem avaliação declarada) mais a *fora da avaliação*, cada uma abrindo a
  lista; MUST NOT mostrar número que some qualquer delas a fechadas ou a concluídas pelo quadro.
- **FR-013**: Toda tela que mostra contagem ou medida desta spec MUST dizer a **cobertura**:
  quantos itens têm evento de transição coletado e quantos não, e até quando os eventos foram
  coletados.

**O retrabalho**

- **FR-014**: Por quadro, a plataforma MUST contar itens recusados que voltaram à avaliação, o
  número de passagens de cada um, e o tempo entre a recusa e a avaliação seguinte — com o *n* e
  a cobertura.
- **FR-015**: O tempo no estágio de avaliação MUST vir dos períodos de estágio (066, FR-024);
  itens sem período conhecido MUST ficar fora da medida e contados em *"sem período conhecido"*.

**A rede e o sprint**

- **FR-016**: O critério de aceite MUST existir como **conceito na rede** — objeto social da SRO,
  no molde de `spo.activity_start_criterion`, com a relação *critério determina aceitação*
  resolvida na leitura —, declarado em YAML versionado com proveniência, e refletido nos modelos
  (classes, banco) pelo papel de documentação de modelos; a limitação de que o quadro não é
  conceito da rede MUST ficar escrita no próprio YAML, como a 042 fez.
- **FR-017**: `sro.sprint_deliverable` MUST ser materializável **apenas** em quadros com critério
  vigente, composto só dos entregáveis aceitos, com a proveniência declarada; a regra que hoje
  recusa materializá-lo MUST passar a declarar a **condição**, e a matriz de cobertura MUST
  registrar `sro.accepted_deliverable` como *declarado por critério*, não como observado.
- **FR-018**: Onde não há critério, a matriz e as telas MUST continuar a dizer `unknown` — a
  ausência escrita — e a plataforma MUST NOT inferir aceite de nenhuma outra fonte.

### Key Entities

- **Critério de aceite declarado**: quadro, **estágio de avaliação**, e por saída dele o
  sentido — aceito · não aceito · sem veredito — (cada saída é uma transição de → para, por
  identificador, com os nomes no momento), cláusula de ator (todos · só pessoas), quem declarou
  e quando, quem revogou e quando. Vários estágios de avaliação por quadro.
- **Avaliação de aceite** (derivada): item, quadro, transição, instante, ator, veredito e o
  critério que a tornou avaliação — uma por ocorrência, reconstituída dos eventos de mudança de
  estágio e dos períodos da 066. Nunca gravada como fase.
- **Fase do entregável** (derivada): aceito · não aceito · sem avaliação declarada · critério não
  declarado · fora da avaliação — a cada leitura, com proveniência.
- **Fase de sucesso da tarefa** (derivada): com sucesso · sem sucesso — só a partir da fase dos
  entregáveis.
- **Entregável do sprint** (derivado): os aceitos de um sprint, em quadros com critério vigente.
- **Cobertura**: itens com evento de transição · sem evento · data do último evento coletado.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Quem administra declara as duas transições do quadro 43 em menos de **3 minutos**,
  a partir da tela do quadro.
- **SC-002**: Com *Homologation → Done = aceito* declarado, o quadro 43 mostra exatamente as
  ocorrências coletadas dessa transição — **10** em 2026-09-14 —, cada uma com instante e ator;
  e *Homologation → Desaprovado* mostra **zero**, escrito como contagem.
- **SC-003**: **Nenhum** dos 119 itens *Backlog → Done* nem dos 80 movidos pelo robô aparece como
  *aceito*; todos aparecem como *concluída pelo quadro · sem avaliação declarada*.
- **SC-004**: Sem critério declarado, **toda** medida e contagem da plataforma devolve o valor de
  antes desta feature — regressão zero — e a matriz continua `unknown`.
- **SC-005**: **100%** das fases de aceite exibidas carregam a proveniência *declarado* com
  critério, transição, instante e ator; **zero** telas dizem "verificado".
- **SC-006**: Nenhuma tela oferece ação de marcar item como aceito — conferido por leitura de
  todas as ações do detalhe, do quadro e do painel.
- **SC-007**: Toda contagem desta spec vem acompanhada da cobertura (com evento · sem evento ·
  coletado até) — **100%** das telas.
- **SC-008**: Cada item está em **exatamente uma** das quatro situações da FR-009 (ou à parte),
  e nenhuma tela soma essas situações a fechadas ou a concluídas pelo quadro.
- **SC-009**: Renomear um estágio na origem não altera nenhuma contagem; remover o estágio zera a
  contagem **com a razão escrita**.

## Assumptions

- **O nome do conceito é proposta desta spec** — *critério de avaliação de aceite*, objeto
  social da SRO no molde de `spo.activity_start_criterion`. O nome e o id definitivos são do
  trabalho de ontologia no plano; a spec fixa a natureza (social, declarado, resolvido na
  leitura) e a relação.
- **O critério é a transição, não o estágio.** *Done* é alcançado de sete origens diferentes e
  por robô; só a transição diz que houve avaliação. **O gesto na tela é em dois passos** —
  escolher o estágio de avaliação e dar sentido a cada saída dele — porque é a mesma regra com
  uma decisão a menos para digitar e uma saída a mais nomeada, *sem veredito*, que o dado tem
  (→ *To Do* 1, → *Dependencies* 1, → *In Validation* 2). Decisão da pessoa mantenedora,
  2026-09-14.
- **Mais de uma transição por sentido é permitida** (*In Validation → Done* também pode ser
  aceite, se a organização disser); cada avaliação nomeia a sua.
- **O robô conta por padrão**, com o ator sempre visível; a cláusula de atores humanos é opção
  declarada — a plataforma não decide que a automação "não avalia".
- **A avaliação é do cliente, e isso cabe na SRO**: quem aceita é quem demanda
  (`sro.product_owner_client` — *"quem demanda é quem mantém"*); a homologação é esse ato.
- **QAPO não é isto.** Aprovação de PR em revisão é avaliação de artefato por pares
  (`qapo.evaluation_verdict`), anterior à homologação — os cinco *Desaprovado* com PR aprovado
  provam que são atos diferentes.
- **Os eventos são parciais e a cobertura é dado.** 147 issues com passagem por *Homologation*
  nos eventos contra 335 lá hoje; os eventos vão até 2026-09-09. A tela diz isso sempre.
- **Sem critério, `unknown`.** A plataforma não infere aceite do PR, do fechamento, nem do
  estágio *Done* — a ausência continua escrita.
- **A tela vive no quadro**, ao lado do critério de início e da definição de pronto: três
  declarações, três componentes, uma pergunta cada (princípio X). **O protótipo existe** desde
  2026-09-14 e cobre o cartão desta spec — ver o cabeçalho. Duas perguntas do Design tocam a
  067: **Q4** (a cláusula *só pessoas* nasce desmarcada, com o ator sempre visível — recomendada
  como a FR-005 já diz) e **Q2** (proposta só sai por recusa registrada). A **D7** do Design
  recusou exibir o número de itens *sem avaliação declarada* no protótipo: os 119 e os 80 são
  **movimentações**, não itens, e somá-los a 459 misturaria populações — a implementação conta
  itens, e a FR-012 continua exigindo a contagem.

## Dependencies

- **[066 — a definição de pronto declarada](../066-pronto-declarado/spec.md)**, mergeada em
  2026-09-15: *concluída pelo quadro*, o estágio como período (FR-024) e o instante do valor
  atual (FR-018); esta spec lê os períodos para datar a avaliação e o tempo em homologação. O
  **plano da 067 vem depois do da 066**, por isso o arquivo de feature corrente continua
  apontando para ela.
- **042 — critério de início**: o molde do objeto social declarado por quadro, com a limitação
  escrita de que o quadro não é conceito.
- **022 — timeline das issues**: os eventos de mudança de estágio, já coletados como atividade
  executada com estágio anterior e novo, ator e instante.
- **004 — issues e projetos**: os itens, os campos e as opções observadas.
- **Os axiomas da SRO** (`sro.rule03`) e a matriz de cobertura GitHub → SRO, que esta spec
  atualiza.
- **O papel de documentação de modelos**: o conceito novo entra nos modelos de classes e de
  banco a partir do YAML e do schema.

## Out of Scope

- **Extrair critérios de aceitação** do texto da issue, ou **avaliar** critérios pela
  plataforma — continua recusado.
- **A definição de pronto e a fase de execução** (066); **o critério de início** (042).
- **A avaliação de artefato por pares** (QAPO — revisão de PR): outra pergunta, outra ontologia.
- **O recorte por sprint** (atrasou · não realizada · concluída) e a regra *"a issue é da
  pessoa"*: outra spec.
- **Coletar a timeline** dos repositórios que ainda não a têm — operação, não feature; a spec
  mede e declara a cobertura.
- **Escrever no GitHub**: nenhuma transição é feita pela plataforma.
