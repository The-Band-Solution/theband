# Feature Specification: O rótulo como campo do item de trabalho

**Feature Branch**: `065-rotulos-no-item`

**Created**: 2026-09-13

**Status**: Draft

**Input**: *"as labels podem vir do campo label do github ou do titulo `[Devops]`, por exemplo"*

**Protótipo aprovado**: <https://claude.ai/code/artifact/e52ca895-fa21-40b2-bbbc-bab0b4a711b0> — aprovado em 2026-09-13. A tela implementada é **exatamente** a aprovada; mudança volta ao protótipo antes do código.

---

## O que já existe, medido e não suposto

Medido no banco de desenvolvimento em 2026-09-13:

| fato | número |
|---|---|
| vínculos de rótulo já coletados | **1 733** |
| nomes distintos | **138** |
| issues com prefixo de área no título | **1 519** |
| consultas que montam item de trabalho | **9** |
| dessas, as que trazem o rótulo | **2** |

Os rótulos **já são coletados**, com nome, cor e a data em que deixaram de ser observados. O
ato de recoleta **marca** o que saiu em vez de apagar — *"o rótulo que a issue teve é fato
sobre como o time a classificou"*.

O campo já existe no **detalhe** de um item. Ele para ali: a listagem, a tela de divergências
e as cinco consultas de hierarquia não o trazem.

## A descoberta central: a triagem já estava feita, pelo motivo oposto

Um rótulo chega ao item por **duas** vias — o campo de rótulo do GitHub, e o prefixo entre
colchetes do título. A segunda parecia território novo. Não é.

A base de conhecimento já separou esses prefixos em agosto, **para decidir o que não pode
virar tipo**:

| prefixo | issues | o que a base faz com ele |
|---|---|---|
| `[TASK]` | 1 188 | roteia como **tipo** — tarefa |
| `[FEATURE]` | 312 | roteia como **tipo** — user story |
| `[BUG]` | 170 | roteia como **tipo** — defeito |
| `[Devops]` | 369 | **recusa** como tipo |
| `[Back-end]` | 316 | **recusa** como tipo |
| `[Front-end]` | 303 | **recusa** como tipo |
| `[Dados]` | 267 | **recusa** como tipo |
| `[QA]` | 113 | **recusa** como tipo |

A razão escrita para a recusa:

> Estes prefixos dizem **quem** faz ou **em que área**, não **o que** a issue é. (…) Conceito
> errado é pior que conceito ausente: a medida passa a existir e a mentir, e ninguém tem como
> notar.

**Isso é a definição de caracterização.** A recusa nunca foi descarte — foi uma triagem que
ninguém tinha usado. O mesmo corte que decide o que **não** é tipo decide o que **é** rótulo.

E a contagem cresceu: a base registrou 340 para `[Devops]` em 2026-08-11; hoje são 369. A
convenção continua viva, o que é o argumento para **lê-la** em vez de pedir a alguém que
redigite 1 519 títulos.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver, na lista, como o time chamou cada item (Priority: P1)

Quem acompanha o trabalho abre a lista de itens e vê, em cada linha, os rótulos que o time
escreveu — sem precisar abrir item por item.

**Why this priority**: é o volume. A lista é onde se olha muitos itens; o detalhe é onde se
olha um. Hoje a caracterização só existe no lugar onde ela menos ajuda a comparar.

**Independent Test**: abrir a lista e ler os rótulos de vários itens numa tela só, e conferir
que os mesmos rótulos aparecem ao abrir cada item.

**Acceptance Scenarios**:

1. **Given** um item com rótulos no campo do GitHub, **When** a lista é aberta, **Then** os
   rótulos aparecem na linha dele, com a marca de **observado**.
2. **Given** um item cujo título começa com um prefixo de área reconhecido, **When** a lista é
   aberta, **Then** o prefixo aparece como rótulo, com a marca de **derivado** — e as duas
   marcas são distinguíveis **sem depender de cor**.
3. **Given** um item sem rótulo nenhum e sem prefixo, **When** a lista é aberta, **Then** a
   linha diz **ausência**, escrita — nunca um espaço em branco que se confunda com "ainda não
   carregou".
4. **Given** uma lista de qualquer tamanho, **When** ela é montada, **Then** o número de
   consultas ao banco **não cresce** com o número de linhas.

---

### User Story 2 - Ver a alegação ao lado do veredito (Priority: P2)

Quem investiga uma divergência entre o que o time declarou e o que a plataforma derivou vê as
**duas** coisas na mesma linha.

**Why this priority**: a tela de divergências existe para mostrar desacordo, e hoje mostra só
um dos lados. Vem depois da US1 porque atinge menos gente, e porque a US1 já prova o
mecanismo.

**Independent Test**: achar um item em que o rótulo diz uma coisa e o conceito derivado diz
outra, e conferir que a tela mostra as duas — e que dá para ver que discordam.

**Acceptance Scenarios**:

1. **Given** um item rotulado `task` cujo conceito derivado é **defeito**, **When** a tela de
   divergências é aberta, **Then** o rótulo e o conceito aparecem lado a lado, e a linha diz
   que **divergem**.
2. **Given** um item sem rótulo nenhum, **When** ele aparece entre as divergências, **Then** a
   tela diz que **não há o que comparar** — e não deixa a célula vazia, que se leria como
   concordância.
3. **Given** qualquer divergência, **When** alguém a lê, **Then** fica claro **qual dos dois
   lados a plataforma seguiu** — o fato estrutural — e que o outro é a intenção declarada.

---

### User Story 3 - O rótulo nunca vira conceito (Priority: P1)

A plataforma mostra o rótulo e **não muda sua classificação por causa dele**.

**Why this priority**: é P1 junto com a US1, e não depois, porque é a regra que a US1 pode
quebrar. Um campo novo ao lado do conceito é exatamente a situação em que alguém, mais tarde,
"melhora" a classificação lendo o rótulo.

**Independent Test**: pôr um rótulo `bug` num item que a plataforma classificou como tarefa, e
conferir que a classificação **não muda**.

**Acceptance Scenarios**:

1. **Given** um item classificado como tarefa, **When** ganha o rótulo `bug`, **Then** a
   classificação continua **tarefa**.
2. **Given** um prefixo de área no título, **When** o item é classificado, **Then** o prefixo
   **não** participa da decisão de tipo — participa só da caracterização.
3. **Given** um rótulo escrito como `chave:valor`, **When** ele é mostrado, **Then** aparece
   **como escrito**, e nenhum campo do item é preenchido a partir dele.

---

### Edge Cases

- **A mesma caracterização chega pelas duas vias.** Um item tem `backend` no campo e
  `[Back-end]` no título. As duas aparecem, **sem unificar**: juntá-las seria a plataforma
  decidindo que dois atos de escrita diferentes queriam dizer a mesma coisa. Quem lê vê que o
  time diz em dois lugares, e escreve de dois jeitos.
- **Rótulo removido na origem.** Sai do campo do item e **continua** no registro histórico. O
  campo mostra o vigente; o que a issue já teve não se perde.
- **Prefixo que ninguém reconhece.** Título com `[Alguma Coisa]` fora da lista declarada
  **não** vira rótulo. Aceitar qualquer colchete transformaria erro de digitação em
  caracterização.
- **Prefixo de tipo no título.** `[TASK]` fica de fora dos rótulos — é o tipo, e já é roteado
  como tal. Mostrá-lo como rótulo faria o mesmo texto significar duas coisas na mesma tela.
- **Item sem rótulo e sem prefixo.** Estado legítimo e comum. Precisa estar **escrito**.
- **Ordem dos rótulos.** Sem ordem declarada, ela muda entre execuções, e uma tela que se
  reordena sozinha faz quem compara duas capturas concluir que algo mudou.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Um item de trabalho — épico, user story ou tarefa — MUST expor os rótulos que o
  caracterizam, na **listagem** e no **detalhe**.
- **FR-002**: Um rótulo MUST declarar **de onde veio**: do campo de rótulo da origem, ou do
  prefixo do título.
- **FR-003**: A distinção da FR-002 MUST ser perceptível **sem depender de cor** — a forma e o
  texto MUST carregá-la também.
- **FR-004**: Só os prefixos de uma **lista declarada** viram rótulo. Prefixo fora da lista
  MUST NOT virar rótulo.
- **FR-005**: A lista da FR-004 MUST viver junto da declaração que já recusa esses mesmos
  prefixos como tipo, e MUST NOT ser repetida em outro lugar. Duas listas divergem, e a
  divergência aparece como ausência silenciosa na que ficou para trás.
- **FR-006**: Prefixo que a plataforma usa para decidir **tipo** MUST NOT virar rótulo.
- **FR-007**: Um rótulo MUST NOT alterar a classificação do item. A classificação vem do fato
  estrutural; o rótulo é a intenção declarada.
- **FR-008**: Rótulos vindos de origens diferentes MUST NOT ser unificados nem ter a grafia
  normalizada, mesmo quando o texto coincide.
- **FR-009**: O conteúdo de um rótulo MUST NOT ser interpretado. Um rótulo escrito como
  `chave:valor` é texto, e MUST NOT preencher campo nenhum do item.
- **FR-010**: A ausência de rótulos MUST ser **escrita**, e MUST NOT ser um espaço em branco.
- **FR-011**: Um rótulo que a origem deixou de mostrar MUST sair do campo do item e MUST
  permanecer no registro histórico.
- **FR-012**: A ordem dos rótulos MUST ser a mesma a cada leitura dos mesmos dados.
- **FR-013**: O número de consultas ao banco para montar uma listagem MUST NOT crescer com o
  número de itens listados.
- **FR-014**: Onde a plataforma mostra divergência entre o declarado e o derivado, ela MUST
  mostrar **os dois**, e MUST dizer qual deles seguiu.
- **FR-016**: Um item de trabalho MUST ser identificável na tela sem ambiguidade. O número
  sozinho MUST NOT servir de identificação visível — ele se repete entre repositórios.
- **FR-017**: A identificação visível MUST nomear o repositório, e o nome MUST trazer a
  organização junto.
- **FR-015**: A tela entregue MUST ser a do protótipo aprovado. Divergência do protótipo é
  **defeito**, e a mudança volta ao protótipo antes do código.

### Key Entities

- **Rótulo**: uma caracterização de um item de trabalho. Tem **texto**, **origem** (campo da
  ferramenta ou prefixo do título) e, quando vem do campo, uma cor que a origem definiu. Não
  tem significado interpretado.
- **Item de trabalho**: épico, user story ou tarefa. Tem um **tipo**, que a plataforma deriva,
  e **zero ou mais rótulos**, que ela observa. As duas coisas coexistem e podem discordar.
- **Prefixo reconhecido**: um texto entre colchetes no início do título que a plataforma
  declarou como caracterização — e que ela já recusava como tipo.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Quem abre a lista consegue dizer os rótulos de **todos** os itens visíveis sem
  abrir nenhum.
- **SC-002**: As 1 519 issues cujo título carrega um prefixo reconhecido passam a ter esse
  prefixo consultável como rótulo — hoje são **zero**.
- **SC-003**: Dado um item, quem olha a tela consegue dizer **de qual origem** veio cada
  rótulo, e acerta em 100% dos casos — inclusive numa captura em tons de cinza.
- **SC-004**: Pôr qualquer rótulo num item **não muda** sua classificação, em 100% das
  tentativas.
- **SC-005**: A listagem de 100 itens custa o **mesmo número** de consultas que a de 10.
- **SC-006**: Duas leituras seguidas dos mesmos dados devolvem os rótulos na **mesma ordem**.
- **SC-007**: Item sem rótulo nenhum mostra a ausência escrita — nunca célula vazia.
- **SC-008**: Quem investiga uma divergência vê a alegação do time e o veredito da plataforma
  na mesma linha, e diz qual foi seguido sem abrir mais nada.
- **SC-009**: Duas issues de repositórios diferentes com o mesmo número são distinguíveis na
  listagem, sem abrir nenhuma das duas.

---

## Assumptions

- **A lista de prefixos é a que já existe**, com os que a base declara como *não são tipo*.
  Acrescentar um prefixo é editar aquela declaração, e isso é decisão de quem administra — não
  de quem implementa.
- **A grafia do prefixo vira o texto do rótulo como está.** `[Back-end]` vira `Back-end`, não
  `backend`. Normalizar seria a interpretação que a FR-009 proíbe, aplicada ao nome.
- **O prefixo é lido a partir do título já guardado**, e não recoletado. Nenhum dado novo
  precisa vir da origem para esta feature existir.
- **Rótulo vindo do prefixo não tem cor** — ninguém a escolheu. A forma o distingue.
- **O detalhe do item já mostra rótulos**, e continua mostrando. Esta feature acrescenta a
  origem e estende o alcance; não refaz o que existe.

### A identificação do item, acrescentada em 2026-09-13

A pessoa mantenedora apontou que o número da issue é **por repositório**, e que a identificação
deve ser organização + repositório + número.

**Medido antes de virar requisito**: no armazenamento **isso já vale**. São 5 033 issues com
5 033 identificadores externos distintos, e o índice único impede confusão. A rota também usa
identificador interno, não número.

O defeito é de **leitura**: são 5 033 issues em apenas **2 699 números distintos**, e a tela
mostra `#2` sem dizer de qual repositório. Duas issues diferentes ficam indistinguíveis para
quem lê, mesmo o banco sabendo que são duas.

Daí as FR-016 e FR-017 serem sobre a tela, e **nenhuma migração** ser necessária. O nome
qualificado do repositório já traz a organização — `leds-conectafapes/conectafapes-project` —,
então é um campo, e não dois.

## Dependencies

- A declaração que hoje recusa `[Devops]`, `[Back-end]`, `[QA]` e os demais como tipo é a
  **fonte** da lista da FR-004. Esta feature depende dela, e a reusa em vez de duplicar.
- A regra que dá precedência ao fato estrutural sobre o tipo declarado é o que torna a FR-007
  possível de afirmar — ela já existe, e esta feature não pode enfraquecê-la.

## Out of Scope

- **Interpretar o conteúdo do rótulo.** `prioridade:alta` não vira campo de prioridade;
  `epic:base` não vira elo de épico. Isso mede mais e erra mais, e precisa de spec própria.
- **Editar rótulos pela plataforma.** O rótulo é observado; quem o muda é quem usa a
  ferramenta de origem.
- **As cinco consultas de hierarquia** — pai, partes, histórico de promoção. Rótulo ao lado de
  uma árvore lê como ruído.
- **Deduplicar ou normalizar** as duas origens. É recusa declarada na FR-008, não omissão.
