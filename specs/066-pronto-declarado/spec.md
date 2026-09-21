# Feature Specification: A definição de pronto declarada pela organização

**Feature Branch**: `066-pronto-declarado`

**Created**: 2026-09-14

**Protótipo, 2026-09-14** — <https://claude.ai/artifact/Gi7gtFR9uJfynPbuEuAU9g>, com a cópia
que vale em [`prototipo/board-declarations.html`](prototipo/board-declarations.html). Cobre as
**três** declarações do quadro (042 existente, 066 e 067) numa tela só, mais o detalhe do item e
o painel da pessoa. A régua do QA é a seção 3 do [`prototipo/PROMPT.md`](prototipo/PROMPT.md);
as decisões e as cinco perguntas em aberto estão no [`prototipo/README.md`](prototipo/README.md).
**Aprovação: aguardando a pessoa mantenedora.** A tela implementada é **exatamente** a aprovada;
divergência volta ao protótipo antes do código.

**Status**: Draft — emendada em 2026-09-14 duas vezes: (1) destinos com id da ontologia,
`rule03`, `github.project_item_status`, depois da análise da SRO/SPO; (2) o **estágio do quadro**
preservado ao lado da fase (FR-023/024) e *Desaprovado* decidido — aceite declarado, spec 067

**Input**: *"podemos criar um mapeamento para done com os status do board. Por exemplo, mapear
concluído pra done e isso contar como Done — igual fizemos com o tipo de issues. Podemos ter
essas regras definidas pelo usuário."* — pessoa mantenedora, 2026-09-14, respondendo ao
feedback de quem usa o Conecta Fapes: *"issues com status Done são tratadas como open"*.

**Decisões da pessoa mantenedora, uma a uma, em 2026-09-14** — esta spec as respeita e não as
reabre: (1) a plataforma **não adota definição de pronto por padrão**; cada organização declara,
por quadro, quais valores de `Status` significam concluído, e a regra é do usuário, no molde das
regras de mapeamento que ele já ativa; (2) **a issue continua sendo da pessoa** pelo responsável
(regra de 2026-08-27) — o recorte por sprint é outra spec; (3) **Homologation é trabalho da
pessoa**, compartilhado com quem homologa, e é responsabilidade dela acompanhar — mapeia para *em
andamento*, nunca para concluído nem para fila de terceiros; (4) duplicata é `stateReason`, não
título igual — outra spec.

---

## O que já existe, medido e não suposto

Medido em 2026-09-14 direto na origem (quadro nº 43 da organização `leds-conectafapes`) e no
banco de desenvolvimento (coleta de 2026-09-09):

| fato | número |
|---|---|
| itens no quadro 43 | **1 194** |
| `Status = Done` | **459** — **294 com a issue aberta** na origem, 165 fechadas |
| `Status = Homologation` | **335** — 309 abertas |
| issues **fechadas** na origem cujo `Status` **não** é Done | **41** |
| desacordo entre "Done" e "fechada", agosto/2026 | 11% (34 de 299) |
| desacordo hoje | **64%** (294 de 459) |
| workflows nativos do quadro *Auto-close issue* e *Item closed* | **desligados** |
| valores de `Status` do quadro 43 já no banco (`item_field_values.raw_value`) | 1 077 itens — Done 377 abertas · 68 fechadas |

**Hoje "concluído" é a issue fechada, em toda medida.** Burn, throughput, previsão, *open now*,
o painel da pessoa, a tela da equipe e o detalhe do item decidem por `state`/`closed_at`. O
campo `Status` do quadro é coletado **cru** — nome e identificador da opção — e **nunca decide
nada**; o valor atual não aparece em tela nenhuma. Ele só é lido para *cycle time* (que hoje
sempre recusa) e para antipadrões.

**O processo do Conecta Fapes mudou desde julho**: o card vai para Done e a issue não fecha.
Quadro e issue foram desconectados **de propósito** — os dois workflows que os ligariam estão
desligados. Para essa organização, toda medida de entrega da plataforma **subconta**, e a pessoa
que abriu o feedback viu 23 dos seus 27 entregáveis contados como abertos.

**O que já existe para reaproveitar**: a plataforma já tem o gesto de *regra proposta a partir
do vocabulário observado, ativada pelo usuário com autor e data* — é assim que os prefixos de
título viram tipo, na tela de sincronização. E já tem a irmã desta pergunta: a spec 042 declara
**qual movimentação marca o começo** do trabalho (critério de início). Esta spec declara **qual
valor marca o fim**.

## A decisão central: não escolher, e mostrar as duas

Um levantamento externo sobre a mesma pessoa concluiu *"para qualquer métrica de entrega vale o
campo Status do Project, não o estado da issue"*. É uma escolha — e a organização que desligou
os workflows fez a escolha oposta sem dizer. Esta casa **não escolhe sozinha**: a plataforma
passa a carregar **duas afirmações** sobre o mesmo item, com proveniência distinta —

| afirmação | natureza | de onde vem |
|---|---|---|
| **fechada na origem** | observado | `state` e `closed_at` da issue |
| **concluída pelo quadro** | **declarado** pela organização | o valor de `Status` do card, lido pela regra que a organização ativou |

— e as mostra **lado a lado, nunca somadas**. Onde discordam, a discordância é **informação**:
294 itens que o quadro chama de concluídos e a origem chama de abertos são o retrato de um
processo, não um erro a esconder. Sem declaração, **nada muda** — e as telas dizem *"concluído
pelo quadro: não declarado"*, porque ausência escrita não é zero.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declarar o que "concluído" quer dizer neste quadro (Priority: P1)

Quem administra a organização abre o quadro na plataforma e vê o vocabulário de `Status` que a
coleta observou — cada valor com quantos cards o carregam hoje —, e declara quais desses valores
significam **concluído**. A plataforma **propõe** (valores cujo nome coincide com vocabulário
reconhecido de pronto, como *Done* e *Concluído*), a pessoa **ativa**, e a ativação fica gravada
com quem e quando. Uma declaração pode ser **encerrada** depois; nunca apagada.

**Why this priority**: sem a declaração não existe segunda afirmação. É a fundação, e é a
decisão da pessoa mantenedora: a regra é do usuário.

**Independent Test**: abrir o quadro 43, ver *Done* com 459 cards, ativar *Done → concluído*, e
ver a regra listada com autor e data. Desativar, e ver a regra encerrada, não sumida.

**Acceptance Scenarios**:

1. **Given** um quadro coletado com campo `Status`, **When** a pessoa que administra abre a
   declaração de pronto dele, **Then** vê **todos** os valores observados do campo, cada um com
   a contagem atual de cards, e os que a plataforma **propõe** como concluído marcados como
   proposta — não como ativos.
2. **Given** a proposta *Done → concluído*, **When** a pessoa a ativa, **Then** a regra passa a
   valer com autor e instante gravados, e a tela diz **quantos cards** a regra alcança agora.
3. **Given** uma regra ativa, **When** a pessoa a encerra, **Then** a regra ganha fim, autor e
   instante do fim; a lista continua a mostrá-la como encerrada; e as telas voltam a dizer *"não
   declarado"* para aquele quadro.
4. **Given** um quadro **sem** campo `Status` (ou sem nenhum valor observado), **When** a pessoa
   abre a declaração, **Then** a tela diz que não há vocabulário a declarar — e por quê.
5. **Given** conta que **não** administra a organização, **When** tenta ativar ou encerrar,
   **Then** a ação é recusada com a razão, e nada muda.

---

### User Story 2 - Ver as duas afirmações no item e na lista (Priority: P1)

Quem abre um item de trabalho — no detalhe ou na listagem — vê **duas** coisas onde hoje vê uma:
se a issue está **fechada na origem**, e se o card está **concluído pelo quadro**. Cada uma com a
sua marca de proveniência (observado × declarado). Quando a organização não declarou, a segunda
diz *"não declarado"*. Quando o item está em mais de um quadro, cada quadro fala por si.

**Why this priority**: é o que a pessoa do feedback pediu. A issue `#2107` está aberta na
origem e *Done* no quadro; hoje a tela diz *open* e só.

**Independent Test**: com *Done → concluído* ativa no quadro 43, abrir `#2107` e ler *"aberta na
origem · concluída pelo quadro (Done, quadro Conecta Fapes)"*. Sem a regra, ler *"aberta na origem
· concluída pelo quadro: não declarado"*.

**Acceptance Scenarios**:

1. **Given** regra ativa no quadro, **When** abro um item com `Status` mapeado para concluído e
   issue aberta, **Then** vejo as duas afirmações, distintas em forma **e** em texto, e nenhuma
   delas sozinha pretende ser "o estado".
2. **Given** regra ativa, **When** abro um item com issue fechada e `Status` fora do mapeamento,
   **Then** vejo *"fechada na origem · não concluída pelo quadro (Homologation)"* — o valor atual
   do `Status` aparece, porque é ele que explica a discordância.
2b. **Given** regra ativa com *Homologation → em andamento*, **When** abro um item nesse estágio,
   **Then** vejo *"aberta na origem · em andamento pelo quadro — Homologation"*: a fase e o
   estágio, lado a lado, e o estágio com a palavra da organização, não traduzida.
3. **Given** item em **dois** quadros com declarações diferentes, **When** abro o detalhe,
   **Then** vejo uma linha por quadro, nomeado, e nenhuma síntese entre eles.
4. **Given** item que **não** está em quadro nenhum, **When** abro o detalhe, **Then** a segunda
   afirmação diz *"em quadro nenhum"* — não "não concluído".
5. **Given** a listagem `/work`, **When** a organização tem regra ativa, **Then** cada linha
   carrega as duas afirmações sem que a coluna de estado atual mude de significado; e o custo em
   consultas da listagem **não cresce** com o número de linhas.

---

### User Story 3 - O desacordo como sinal (Priority: P2)

Quem acompanha um quadro ou uma pessoa vê **dois números** que hoje não existem: quantos itens o
quadro chama de concluídos e a origem chama de abertos, e quantos a origem fechou sem o quadro
concluir. Cada número abre a lista dos itens. Sem regra ativa, os dois dizem *"não declarado"*.

**Why this priority**: é o que transforma 294 numa pergunta ao time (*"por que o card fecha e
a issue não?"*) em vez de num erro invisível da medida. E é o dado que decide se os workflows
do quadro deviam estar ligados.

**Independent Test**: no quadro 43 com a regra ativa, ler *294 concluídos pelo quadro e abertos
na origem · 41 fechados na origem e não concluídos pelo quadro*, clicar no primeiro e ver a lista.

**Acceptance Scenarios**:

1. **Given** regra ativa, **When** abro o quadro, **Then** vejo os dois números, cada um com a
   definição escrita por extenso ao lado, e cada um abre a lista correspondente.
2. **Given** regra ativa, **When** abro o painel de uma pessoa, **Then** vejo os mesmos dois
   números restritos aos itens dela — e a tela diz que são **desacordos**, não erros.
3. **Given** nenhuma regra ativa, **When** abro o quadro, **Then** no lugar dos números leio
   *"não declarado — declarar o que significa concluído neste quadro"*, com o caminho.

---

### User Story 4 - As medidas dizem qual definição usam (Priority: P2)

Toda medida de fluxo — burn, throughput, previsão, *open now* — passa a **dizer qual definição de
pronto usou**. A organização **escolhe** qual das duas alimenta as medidas (por padrão, a de
hoje: fechada na origem), e a escolha fica gravada com autor e data. Trocar a escolha recalcula
as medidas; **nenhuma tela mostra um número que some as duas**.

**Why this priority**: sem isto, a organização que declarar *Done → concluído* continua vendo
um burn que a contradiz, e sem saber por quê.

**Independent Test**: com a regra ativa e a escolha em *"fechada na origem"*, ler o burn da
equipe com o rótulo da definição; trocar para *"concluída pelo quadro"* e ver o mesmo gráfico
recalculado, com o rótulo trocado e a data da troca.

**Acceptance Scenarios**:

1. **Given** qualquer medida de fluxo, **When** a leio, **Then** ela nomeia a definição de
   pronto que usou — sempre, inclusive quando é a de hoje.
2. **Given** a escolha *"concluída pelo quadro"* e um item concluído pelo quadro **sem** instante
   de conclusão conhecido, **When** o burn é calculado, **Then** o item **não** entra na série de
   fechadas por data — entra em *"concluídos sem data conhecida"*, dito na tela.
3. **Given** a troca de escolha, **When** volto à tela, **Then** vejo quem trocou e quando, e a
   escolha anterior continua consultável.
4. **Given** uma organização sem regra ativa, **When** abro a escolha, **Then** a opção
   *"concluída pelo quadro"* está **indisponível**, com a razão: não há declaração.

---

### User Story 5 - "Em andamento" declarado, e a Homologation que é da pessoa (Priority: P3)

A mesma declaração da US1 aceita mais um destino: **em andamento**. Quem administra mapeia
*Homologation*, *In Progress*, *In Validation* para em andamento, e a carga da pessoa passa a
distinguir *em andamento pelo quadro* do resto do que está aberto — com a mesma proveniência
declarada.

**Why this priority**: é a decisão 3 da pessoa mantenedora — Homologation é trabalho da pessoa,
compartilhado, que ela acompanha. Vem depois porque depende da US1 e não muda nenhuma medida de
conclusão.

**Independent Test**: mapear *Homologation → em andamento* no quadro 43 e ver, no painel de uma
pessoa com 24 cards ali, *"24 em andamento pelo quadro (Homologation)"* ao lado do total aberto.

**Acceptance Scenarios**:

1. **Given** a declaração do quadro, **When** a pessoa escolhe o destino de um valor, **Then**
   as opções são exatamente as da FR-001 — *planejada, não começou* · *em andamento* ·
   *concluída* · *esta coluna não diz fase* · *sem decisão* —, cada uma com o conceito da
   ontologia escrito ao lado, e *sem decisão* é o padrão de todo valor não declarado.
2. **Given** *Homologation → em andamento* e *In Validation → em andamento*, **When** abro o
   painel da pessoa, **Then** leio *"24 em andamento pelo quadro — 22 Homologation · 2 In
   Validation"*: a fase agrupa, o estágio explica; e o número **não** altera o total de abertos
   nem o burn.

---

### Edge Cases

- **A opção foi renomeada na origem** (*Done* → *Concluído*): a regra referencia o
  **identificador** da opção, então continua valendo; a tela mostra o nome atual e, entre
  parênteses, o nome no momento da declaração, quando diferem.
- **A opção foi removida do quadro**: a regra permanece, marcada *"opção não existe mais na
  origem"*; nenhum card a carrega, e o número que ela alcança é zero **dito**, com a razão.
- **O quadro perdeu o campo `Status`** ou ganhou um segundo campo de seleção com o mesmo nome:
  a regra é por campo, identificado; a tela nomeia o campo quando há mais de um.
- **Item em dois quadros com declarações contrárias**: as duas afirmações aparecem, uma por
  quadro; nenhuma é escolhida pela plataforma.
- **Card removido do quadro depois de concluído**: o item deixa de ter valor de `Status`
  naquele quadro; a afirmação passa a *"não está mais neste quadro"*, e o histórico da
  conclusão declarada — se coletado — não é apagado.
- **Rascunho** (card sem issue): não tem afirmação de origem; a tela diz *"rascunho — sem
  issue na origem"*.
- **Issue fechada como *não planejada* ou *duplicada*** e `Status = Done`: as duas afirmações
  aparecem como estão; a razão do fechamento (`stateReason`) é mostrada ao lado da afirmação de
  origem, porque explica o caso. Excluir duplicatas da carga é outra spec.
- **Concluído pelo quadro sem instante conhecido**: a plataforma só sabe o **valor atual** do
  `Status`; para a série temporal precisa do instante em que o valor passou a valer. Onde não
  houver, o item conta em *"concluídos sem data"*, nunca é datado por palpite.
- **Declaração encerrada e reativada**: cada período é um registro; as medidas de um instante
  usam a declaração vigente **naquele instante**, não a atual.
- **Períodos com buraco**: o evento de saída existe e o de entrada não (coleta parcial da
  timeline) — o período fica com entrada desconhecida, dito; nunca preenchido com a criação da
  issue.
- **Estágios homônimos ou quase** (*To Do* e *Todo*; *Homologation* e *Homologação* em quadros
  diferentes): nunca fundidos. No mesmo quadro é o antipadrão `ap06`, sinalizado; entre quadros,
  a comparação é pela fase declarada, e o estágio fica como está.

## Requirements *(mandatory)*

### Functional Requirements

**A regra**

- **FR-001**: A organização MUST poder declarar, **por quadro e por campo de seleção única**,
  para cada valor observado, um destino da **ontologia** — e só estes:

  | destino (texto da tela) | conceito | o que afirma |
  |---|---|---|
  | *planejada, não começou* | `sro.intended_scrum_development_task` (intenção; pai `spo.intended_project_activity`) | há intenção de fazer; nada foi executado |
  | *em andamento* | `spo.performed_project_activity` com `start_date` e **sem** `end_date` | a atividade corre — a própria ontologia define "em andamento" assim, e não como fase |
  | *concluída* | `spo.performed_project_activity` com `end_date`; quando a issue é tarefa, `sro.performed_scrum_development_task` (causada pela pretendida, `sro.rule02`) | o trabalho terminou — **não** que foi aceito |
  | *esta coluna não diz fase* | nenhum — recusa registrada, no molde de "não é tipo" | a coluna diz outra coisa (área, pausa, refinamento) |
  | *sem decisão* | nenhum — padrão | ninguém declarou |

  A tela MUST NOT oferecer `sro.accepted_deliverable` nem `sro.not_accepted_deliverable` como
  destino: pela regra `sro.rule03`, aceitação decorre da avaliação dos critérios e **nunca de
  marcação manual**; o quadro pode dizer que o trabalho terminou, não que o entregável passou.
  A tela MUST dizer isso, com a regra, onde a pessoa procuraria "aceito".
- **FR-002**: A declaração MUST referenciar o **identificador** da opção na origem, e guardar o
  **nome** da opção no momento da declaração; o nome atual vem da coleta.
- **FR-003**: Toda ativação e todo encerramento de declaração MUST gravar **quem** e **quando**;
  declaração nunca é apagada — é encerrada, e o período vigente fica consultável.
- **FR-004**: A plataforma MUST **propor** declarações a partir do vocabulário observado, usando
  um vocabulário reconhecido de pronto declarado na base de conhecimento (versionado, com
  proveniência); proposta MUST aparecer como proposta e MUST NOT valer até ser ativada.
- **FR-005**: Só quem administra a organização MUST poder ativar ou encerrar; quem não
  administra MUST ver a declaração e MUST NOT ver ação.
- **FR-006**: A tela de declaração MUST mostrar, para cada valor, **quantos cards** o carregam
  agora, e para cada regra ativa quantos cards ela alcança.

**As duas afirmações**

- **FR-007**: Todo item de trabalho MUST carregar duas afirmações distintas — *fechada na origem*
  (observado: `state`/`closed_at`) e *concluída pelo quadro* (declarado: valor de `Status` lido
  pela regra vigente) — e a plataforma MUST NOT sintetizar as duas num único estado.
- **FR-008**: Sem declaração vigente para o quadro, a segunda afirmação MUST dizer *"não
  declarado"*; item fora de qualquer quadro MUST dizer *"em quadro nenhum"*; rascunho MUST
  dizer *"sem issue na origem"*. Nenhum desses casos MUST aparecer como "não concluído".
- **FR-009**: Item em mais de um quadro MUST ter uma afirmação de quadro **por quadro**,
  nomeado.
- **FR-010**: As duas afirmações MUST ser distinguíveis **sem cor** — por forma e por texto —,
  com a marca de proveniência da casa (observado × declarado).
- **FR-011**: O detalhe do item, a listagem de itens, o painel da pessoa, a tela da equipe e o
  quadro MUST mostrar as duas afirmações onde hoje mostram aberto/fechado; a listagem MUST
  fazê-lo sem que o número de consultas cresça com o número de linhas.
- **FR-012**: Onde as duas afirmações discordam, a tela MUST mostrar o valor atual do `Status`
  e, quando a issue está fechada, a razão do fechamento — porque explicam a discordância.

**O desacordo**

- **FR-013**: Por quadro e por pessoa, a plataforma MUST contar e mostrar (a) itens concluídos
  pelo quadro e abertos na origem, e (b) itens fechados na origem e não concluídos pelo quadro;
  cada número MUST abrir a lista dos itens; sem declaração, MUST dizer *"não declarado"*.
- **FR-014**: O desacordo MUST ser apresentado como **informação sobre o processo**, nunca como
  erro do item nem da pessoa.

**As medidas**

- **FR-015**: Toda medida de fluxo (burn, throughput, previsão, *open now* e as derivadas) MUST
  nomear a definição de pronto que usou, em toda tela, inclusive quando é *fechada na origem*.
- **FR-016**: A organização MUST poder escolher qual definição alimenta as medidas — *fechada na
  origem* (padrão) ou *concluída pelo quadro* —, com autor e instante gravados; a escolha
  anterior MUST continuar consultável; a opção *concluída pelo quadro* MUST estar indisponível,
  com a razão, enquanto não houver declaração vigente.
- **FR-017**: Com *concluída pelo quadro*, um item cujo instante de conclusão não é conhecido
  MUST NOT entrar na série por data; MUST ser contado à parte como *"concluídos sem data
  conhecida"*, dito na tela.
- **FR-018**: A coleta MUST passar a guardar o **instante em que o valor atual de `Status`
  passou a valer**, quando a origem o oferece, para que a conclusão declarada tenha data; onde
  a origem não oferece, a ausência MUST ficar registrada como ausência.
- **FR-019**: Uma medida calculada sobre um instante passado MUST usar a declaração vigente
  **naquele instante**.

**O em andamento**

- **FR-020**: Com valores mapeados para *em andamento* (`spo.performed_project_activity` sem
  `end_date`), o painel da pessoa MUST mostrar *"N em andamento pelo quadro"* com os valores que
  o compõem, sem alterar o total de abertos nem nenhuma medida de conclusão.
- **FR-021**: A regra MUST viver na base de conhecimento com o id **`github.project_item_status`**
  — o id que `mappings/github/sro/issue_task.yaml` já cita como origem da tarefa executada e que
  **não existe** —, declarando os destinos admitidos, o vocabulário que gera propostas, e o que
  ela **não materializa** (`sro.accepted_deliverable`, `sro.sprint_deliverable`), com a razão.
- **FR-022**: A declaração de um valor como *esta coluna não diz fase* MUST ser gravada como
  recusa (autor, instante), MUST NOT gerar afirmação de fase, e MUST tirar o valor da lista de
  propostas — como a recusa "não é tipo" faz hoje com os prefixos de área.

**O estágio do quadro — preservado, não promovido**

- **FR-023**: O **estágio** — o valor de `Status` como a organização o chama (*Homologation*,
  *Refinamento*, *In Validation*…) — MUST ser preservado e mostrado **ao lado** da fase declarada
  em toda tela que mostra a fase; MUST NOT ser promovido a conceito da ontologia; a **ordem** dos
  estágios MUST vir da ordem observada das opções do campo no quadro, sem declaração; e estágios
  MUST NOT ser normalizados nem fundidos entre quadros — *To Do* e *Todo* no mesmo quadro é o
  antipadrão que a plataforma **sinaliza**, nunca resolve. Medida por estágio é **por quadro**;
  entre quadros e organizações, só por fase.
- **FR-024**: O estágio MUST ser guardado no item como **período** — *entrou em*, *saiu em* —,
  no molde do rótulo da 065 (decisão da pessoa mantenedora, 2026-09-14): um registro por passagem
  do item por um estágio de um quadro. O período MUST vir dos **eventos de mudança de estágio**
  quando coletados (entrada e saída exatas); onde só o **valor atual** é conhecido, MUST existir
  um único período com a entrada no instante do valor (FR-018) e a saída em aberto; e cada
  período MUST dizer de qual das duas fontes veio. Nada é datado por palpite.
- **FR-025**: Da sequência de períodos a plataforma MUST derivar, por item, **há quanto tempo**
  está no estágio atual e **quantas vezes** passou por cada estágio (*voltou para Refinamento 2
  vezes*); sem período conhecido, MUST dizer *"idade no estágio desconhecida"* — nunca contar a
  partir da coleta. Medidas por estágio (tempo médio em *Homologation*, retornos) MUST ser por
  quadro, e MUST dizer quantos itens têm período conhecido e quantos não.

### Key Entities

- **Declaração de fase por valor de campo**: a regra da organização — quadro, campo de seleção
  única, identificador da opção, nome no momento da declaração, destino (um dos cinco da FR-001,
  gravado pelo **id do conceito** quando há conceito, e como recusa nomeada quando não há), quem
  ativou e quando, quem encerrou e quando. Uma por opção por período. O molde é o critério de
  início (`spo_activity_start_criteria`: por quadro, declarado/revogado com autor, revogar marca
  e nunca apaga) somado ao gesto do catálogo de mapeamento (proposta → ativação).
- **Vocabulário reconhecido de pronto**: lista versionada na base de conhecimento dos nomes que
  costumam significar concluído (*Done*, *Concluído*, *Closed*…), com proveniência; serve **só
  para propor**, nunca decide.
- **Escolha de definição para as medidas**: por organização — *fechada na origem* ou *concluída
  pelo quadro* —, quem escolheu e quando; períodos consultáveis.
- **As duas afirmações de um item**: derivadas a cada leitura — *fechada na origem* (do item
  coletado) e *concluída pelo quadro* (do valor atual de `Status` do card, lido pela declaração
  vigente), com a natureza de cada uma.
- **Instante do valor atual de `Status`**: quando o card passou a ter o valor que tem; coletado
  da origem, ausente quando ela não oferece.
- **Estágio do quadro**: o valor de `Status` com o nome que a organização lhe dá e a **posição**
  observada entre as opções do campo — observado, cru, por quadro. Não é conceito; é a palavra do
  processo da organização, preservada como os rótulos da 065.
- **Período no estágio**: item × quadro × estágio × *entrou em* × *saiu em* (aberto enquanto o
  item está lá) × fonte (evento de mudança · valor atual). Um por passagem. É o que dá tempo no
  estágio e retornos — e é do que a 067 deriva o instante da avaliação de aceite.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Quem administra declara *Done → concluído* num quadro em menos de **2 minutos**, a
  partir da tela do quadro, sem sair da plataforma.
- **SC-002**: Com a regra ativa no quadro 43, o detalhe da issue `#2107` diz **as duas
  afirmações** — aberta na origem, concluída pelo quadro — e nenhuma tela diz só *open*.
- **SC-003**: Os dois números de desacordo do quadro 43 coincidem com a contagem feita direto na
  origem na mesma coleta (**294** e **41** em 2026-09-14), com diferença **zero**.
- **SC-004**: **Nenhuma** tela mostra um número que some fechadas na origem com concluídas pelo
  quadro — conferido por leitura de toda medida de fluxo e de toda contagem de estado.
- **SC-005**: Sem nenhuma declaração ativa, **toda** medida e contagem da plataforma devolve
  exatamente o valor de antes desta feature — regressão zero, medida contra a suíte existente.
- **SC-006**: **100%** das medidas de fluxo nomeiam a definição de pronto que usaram.
- **SC-007**: Renomear a opção na origem e recoletar **não** altera nenhuma contagem declarada;
  remover a opção zera a contagem **com a razão escrita**.
- **SC-008**: A listagem de 100 itens com as duas afirmações custa o **mesmo número** de
  consultas que a de 10.
- **SC-009**: Um item concluído pelo quadro sem instante conhecido aparece em *"concluídos sem
  data conhecida"* e em **nenhum** ponto da série por data.

## Assumptions

- **Proposta não é decisão.** A plataforma propõe por coincidência de nome com o vocabulário
  reconhecido, comparando sem caixa e sem acento; a proposta aparece como tal e nada vale até
  a ativação. É o mesmo gesto das regras de prefixo.
- **A regra é por quadro e por campo, não por organização.** Dois quadros da mesma organização
  podem usar vocabulários diferentes (o Conecta Fapes tem *Done* num e *Concluído* noutro é
  hipótese plausível); a organização declara em cada um.
- **A escolha de qual definição alimenta as medidas é por organização.** Uma medida da equipe
  atravessa quadros; escolher por quadro obrigaria a somar definições diferentes num mesmo
  gráfico, que é o que a casa recusa.
- **Os eventos de mudança de estágio já estão coletados** como atividade executada — estágio
  anterior, estágio novo, ator e instante — para os repositórios cuja timeline foi coletada:
  **9 863 eventos**, dos quais **5 503 do `conectafapes-project`** (medido em 2026-09-14; a nota
  de agosto que dizia "zero" para esse repositório estava vencida). Os períodos exatos da FR-024
  saem deles; onde a timeline não foi coletada, só o valor atual (FR-018), e o período fica com a
  saída em aberto. Concluídos pelo quadro sem instante conhecido entram em *"sem data
  conhecida"*.
- **Homologation é em andamento** (`spo.performed_project_activity` sem `end_date`), por decisão
  da pessoa mantenedora em 2026-09-14; a spec não a mapeia automaticamente — a organização
  declara. E hoje *Homologation* **não está** em `recognized_in_progress_states`: nem o antipadrão
  `ap05` a reconhece como andamento.
- **"Em andamento" e "não iniciado" não são conceitos da rede, de propósito.** A doutrina está
  escrita em `ciro/interrupted_verification.yaml`: *"fase é resultado, e em andamento não é
  resultado"*. Por isso os destinos são o par intenção × ocorrência da SRO/SPO, e "em andamento"
  é a ocorrência sem fim.
- **Desaprovado — decidido em 2026-09-14: é aceite declarado, spec própria (067).** O destino
  natural seria `sro.not_accepted_deliverable`, e a `rule03` o proíbe sem avaliação de critérios.
  Medido no quadro 43: 248 dos 335 em *Homologation* já têm PR mergeado, e **os 5 Desaprovado têm
  PR mergeado e aprovado** — o PR não decide aceite; quem avalia é o cliente, na homologação. A
  pessoa mantenedora decidiu o caminho (c): a organização **declara** qual transição do quadro é a
  avaliação de aceite (*Homologation → Done* aceita; *→ Desaprovado* recusa), como objeto social
  no molde de `spo.activity_start_criterion` — conceito novo na rede, resolvido na leitura, com
  autor e data. Nesta spec, *Desaprovado* fica como **estágio** (FR-023) sob a fase que a
  organização declarar; a fase de aceitação vem da 067.
- **A tabela de atividades executadas não tem colunas de data hoje** — `start_date`/`end_date`
  estão na ontologia e não no schema, porque o critério de início resolve na leitura. Esta spec
  segue o mesmo desenho: a fase do item é **derivada a cada leitura** da declaração vigente e do
  valor atual; nada de fase é gravado no item.
- **A tela de declaração vive junto do quadro**, e não numa página própria — a lacuna nasce ao
  olhar o quadro; a mesma razão que pôs as regras de mapeamento na tela de sincronização.
  Protótipo antes do código, como toda tela desta casa.
- **Ligar os workflows nativos do quadro** (*Auto-close issue*) é decisão da organização, fora
  da plataforma; esta feature mede o desacordo que os workflows desligados produzem, e não o
  corrige na origem.

## Dependencies

- **004 — issues e projetos**: os itens de quadro, os campos, as opções observadas e os valores
  crus por item, que esta spec passa a interpretar por declaração.
- **028 — gestão do projeto declarado**: a escolha de quadro por evidência; o quadro que a
  organização declara como seu é o primeiro a receber declaração de pronto.
- **022 — timeline das issues, FR-007/FR-008/FR-010b**: a plataforma não escolhe sozinha qual
  evento marca o início; quando nenhum estado significa "em andamento", sinaliza.
- **042 — critério de início**: a irmã — qual movimentação marca o começo; esta marca o fim.
  Mesmo desenho: por quadro, autor e data, resolução na leitura, revogar marca. E a mesma
  limitação declarada: **o quadro não é conceito da rede** (`observed_projects` é coleta), então a
  declaração aponta para o quadro observado, como o critério de início já faz.
- **A regra por tenant `the_band_solution.yaml`** lista o `Status` em `unmapped_fields` com a
  razão *"exigiria o histórico de itens"*; esta spec a supera pela FR-018 (o instante do valor
  atual) e pela FR-001 (a declaração), e a entrada de `unmapped_fields` MUST ser atualizada
  quando a regra existir.
- **A tela de sincronização e suas regras de mapeamento**: o gesto de propor a partir do
  observado e ativar com autor, que esta spec reutiliza.
- **A marca de proveniência** da casa (observado · declarado · derivado · ausente).

## Out of Scope

- **O critério de início** (042, sobre a FR-007 da 022): qual transição marca o começo do
  trabalho. Aqui só o valor **atual** e o instante em que passou a valer.
- **O critério de aceite declarado** (spec 067): qual transição do quadro é a avaliação de
  aceite, e as fases `sro.accepted_deliverable` / `sro.not_accepted_deliverable` daí derivadas —
  decisão de 2026-09-14. Esta spec entrega a fase de execução; aquela, a de aceitação.
- **O recorte por sprint** — atrasou, não realizada, concluída por sprint — e a regra *"a issue
  é da pessoa"*: outra spec, com as decisões 2 e 3 já tomadas.
- **Duplicatas** (`stateReason = DUPLICATE`) fora da carga da pessoa: outra spec.
- **Cards arquivados** e itens que somem do quadro (`isArchived`, *no longer observed*): item de
  backlog próprio.
- **Complexidade** (*Story Points* → `complexity`): item de backlog próprio.
- **O link para a issue na origem** em toda ocorrência: item de backlog próprio.
- **Ligar workflows do quadro** na origem, ou qualquer escrita no GitHub.
- **Reconstruir o histórico** de valores de `Status` por card a partir da timeline — a
  FR-018 coleta o instante do valor **atual**; a série completa de transições é outra feature.
