# O prompt do design — as três declarações do quadro (042 · 066 · 067)

Registro fiel do que produziu o protótipo [`board-declarations.html`](board-declarations.html),
publicado em `https://claude.ai/artifact/Gi7gtFR9uJfynPbuEuAU9g` em **2026-09-14**.
**A implementação reproduz exatamente esta tela** — seções, ordem, textos, marcas, ações e
recusas. Mudança no protótipo é mudança de spec, e passa por aqui: republicação **no mesmo
endereço**, com a mudança registrada no `README.md`.

**A cópia que vale é a deste diretório.** O endereço publicado pode mudar; a spec não pode
depender dele.

## 1. Os pedidos, textuais e em ordem

**2026-09-14** — a pessoa mantenedora, respondendo ao feedback de quem usa o Conecta Fapes
(*"issues com status Done são tratadas como open"*), abriu a 066:

> "podemos criar um mapeamento para done com os status do board. Por exemplo, mapear concluído
> pra done e isso contar como Done — igual fizemos com o tipo de issues. Podemos ter essas
> regras definidas pelo usuário."

E decidiu, uma a uma, no mesmo dia (spec 066, cabeçalho): (1) a plataforma **não adota
definição de pronto por padrão**; (2) **a issue continua sendo da pessoa** pelo responsável;
(3) **Homologation é trabalho da pessoa** — em andamento, nunca concluído; (4) duplicata é
`stateReason`, outra spec. E, para a 067: *"o caminho honesto é um critério de aceitação
declarado: a organização declara que Homologation → Done é a avaliação de aceite e →
Desaprovado a recusa — objeto social como `spo.activity_start_criterion`, declarado com autor e
data, resolvido na leitura. Estou de acordo."* Depois emendou a 067: **o gesto em dois passos**
— escolher o estágio de avaliação, dar sentido a cada saída dele, com a saída *sem veredito*.

**2026-09-14** — o pedido ao papel de Design, pelo Product Owner, resumido:

1. Desenhar, **antes do código**, o protótipo navegável da tela do quadro nº 43 "Conecta Fapes"
   com **três componentes de declaração, nesta ordem**, cada um dizendo quem declarou e quando,
   com botão de revogar que **marca**, nunca apaga: **A.** "O trabalho começa quando…" (042,
   existente — reproduzir como está, sem redesenhar); **B.** "Cada coluna significa…" (066);
   **C.** "A avaliação acontece em…" (067).
2. Em **B**: os 12 estágios na ordem observada, cada um com a contagem de hoje (aberta/fechada);
   para cada um, um destino entre os cinco da FR-001 com o conceito da ontologia ao lado;
   mostrar Done → concluída **ativa** e Homologation → em andamento **ativa**, o resto "sem
   decisão"; mostrar a **proposta** (não ativa) para In Progress → em andamento e Done →
   concluída, visivelmente diferente de ativa. Abaixo, **o desacordo como sinal**: 294 · 41, cada
   número abrindo a lista; a nota dos workflows desligados (observado). E onde a pessoa
   procuraria "aceito/não aceito", um texto curto explicando a `sro.rule03` e apontando para C.
3. Em **C**: o gesto em dois passos — Homologation escolhido; **todas** as saídas observadas
   com contagem (→ Done 10 · → In Validation 2 · → Homologation In Progress 2 · → To Do 1 · →
   Dependencies 1 · → Desaprovado 0); Done = aceito e Desaprovado = não aceito ativos; To Do e
   Dependencies = sem veredito; In Validation e Homologation In Progress **não declaradas**. A
   cláusula "só transições feitas por pessoa" (80 movimentações do robô). **Nada proposto.**
   Cobertura sempre: 147 · 335 · até 2026-09-09. Os três números: aceitos 10 · não aceitos 0 ·
   sem avaliação declarada.
4. **D.** Uma segunda faixa navegável: o detalhe do item **#2107** com as **três** afirmações
   lado a lado e o estágio como período; o painel de **@harianadm** com "27 concluídas pelo
   quadro (23 abertas na origem) · 25 em andamento pelo quadro — 24 Homologation · 1 In
   Progress" e as três contagens de aceite com a cobertura.
5. Regras: afirmações **lado a lado, nunca somadas**; ausência **sempre escrita**; marcas
   distinguíveis **sem cor**; recusa é estado; tela em inglês; um componente = uma pergunta;
   sem cor do GitHub; **dado real, nunca inventado** — onde spec e dado divergem, seguir o dado e
   anotar no README.

## 2. O brief de design que o agente seguiu

- **Nenhuma matiz nova, nenhuma forma nova.** Os tokens são os de `DESIGN.md` e do último
  protótipo aprovado (`specs/060-tela-da-equipe/prototipo/team-dashboard-structure.html`):
  papel/tinta, verdete observado, `info` declarado, âmbar derivado, clay gravidade; marcas
  `observed` (verdete cheio), `declared` (azul cheio), `proposed` (âmbar hachurado — a proposta é
  **derivada** do vocabulário reconhecido, então herda a marca de derivado), `absent` (tracejado),
  `revoked` (cinza cheio). Texto redundante em toda marca.
- **A ramp de dez passos**, as três pilhas do sistema (grotesk escaneia, serifa lê, mono compara),
  `tabular-nums` em toda contagem, plano por doutrina, sem borda de acento.
- **A tela é a tela de hoje.** A mesma ordem de cartões de `board_live/index.ex` (14 Sep): campos
  de iteração → prazo → **Start criterion** → *[B]* → *[C]* → Fields → Backlogs. O que não muda
  aparece como stub quieto "unchanged — as on the screen of 14 Sep 2026".
- **Mostrado em repouso**: os dois formulários de declaração (destino de In Validation em B;
  sentido de Homologation → In Validation em C) aparecem abertos como exemplo; nada depende de
  clique.
- **Dado real do arquivo `dado-real-quadro-43.md`** (medido 2026-09-14; eventos até 2026-09-09).
  O que não foi medido está escrito como "not measured for this prototype", nunca preenchido.
  As declarações, autores e instantes são `example` — nenhuma foi feita ainda — e o autor é um
  nome fictício (Ana Vieira), não uma pessoa real.

## 3. A estrutura aprovada, seção por seção — a régua do QA

**É contra esta seção que o QA confere, item a item: existe, na ordem, com o texto, com a marca,
com a ação e com a recusa.** Divergência é defeito, não "melhoria de implementação".

### Cabeçalho do protótipo (não é tela do produto)

`h1` **What this board declares**; parágrafo com as datas (contagens 14 Sep 2026; eventos até
9 Sep 2026); legenda das cinco marcas com forma **e** texto: `observed` · `declared` · `proposed`
· `absent` · `revoked`.

### `screen 1 · the board`

1. **Abas de Work** com `Boards` ativa; `h2` **Boards**; subtítulo de hoje ("What the source
   declares in each board…never promoted to a concept"). Tabela de quadros com a linha
   `43 · Conecta Fapes · open` (marca observada) selecionada.
2. **Cabeçalho do quadro**: `#43 · Conecta Fapes`; linha `collected board — nothing here is a
   project of its own · 1 194 items · 1 101 issues + drafts · counted 14 Sep 2026`.
3. **Nota da tela** (caixa verdete): o que muda — dois cartões novos logo depois de *Start
   criterion*, tudo o mais igual; a forma comum dos três cartões (vocabulário observado na ordem
   observada, contagem ao lado, quem/quando, revogar marca).
4. Stubs **What each iteration field means** e **Where the deadline comes from** — "unchanged".
5. **A · Start criterion** — reproduzido de `board_live/index.ex` sem redesenho: `h4` *Start
   criterion*; a frase de estado (sem critério próprio → segue o do projeto), o `select` "event
   that marks the start" com `event_type — N observed`, botão **Declare** (primário), e os dois
   parágrafos de desempate ("When an issue sits on more than one board…" · "If two boards were
   linked at the very same instant…"). *O estado real de #43 vem da base; o protótipo marca
   `example`.*
6. **B · What each column means** — `h4`, marca `declared by this organisation`, rótulo
   `066 · new`. Parágrafo: 12 opções na ordem da origem; a plataforma **propõe** e **decide
   nada**; *closed at the source* é outra afirmação, nunca somada.

   **Tabela** — colunas `#` · `stage · as the organisation calls it` · `items today · open ·
   closed` · `means` · `declared` · `action`. Treze linhas, nesta ordem e com estes números:

   | # | stage | items (open · closed) | means | declared | action |
   |---|---|---|---|---|---|
   | 1 | Backlog | 115 (109 · 6) | *no decision* | `absent` nobody declared | `declare…` |
   | 2 | Refinamento | 59 (57 · 2) | *no decision* | `absent` | `declare…` |
   | 3 | Pronto para desenvolvimento | 5 (5 · 0) | *no decision* | `absent` | `declare…` |
   | 4 | To Do | 50 (49 · 1) | *no decision* | `absent` | `declare…` |
   | 5 | Paused | 10 (10 · 0) | *no decision* | `absent` | `declare…` |
   | 6 | In Progress | 23 (23 · 0) | in progress · `spo.performed_project_activity · no end_date` | **`proposed — not active`** (âmbar hachurado) + nota "from recognised vocabulary… nobody has activated it" | **Activate** · `or declare another…` |
   | 7 | In Validation | 20 (19 · 1) | *no decision* | `absent` | `declare…` (formulário aberto abaixo) |
   | 8 | Dependencies | 2 (2 · 0) | *no decision* | `absent` | `declare…` |
   | 9 | **Homologation** (subtexto: "the person's work, shared with whoever homologates — decision of 14 Sep") | 335 (309 · 26) | in progress · `spo.performed_project_activity · no end_date` | **`active`** by Ana Vieira · 14 Sep 09:10 `example`; histórico: **`revoked`** earlier *completed* · declared 09:02 · revoked 09:10 · razão | **revoke** |
   | 10 | Homologation In Progress | 7 (7 · 0) | *no decision* | `absent` | `declare…` |
   | 11 | **Desaprovado** (subtexto: "looking for 'not accepted'? it is not a phase of the work — see the card below") | 8 (8 · 0) | *no decision* | `absent` | `declare…` |
   | 12 | **Done** | 459 (294 · 165) | completed · `spo.performed_project_activity · with end_date · sro.performed_scrum_development_task when the issue is a task` | **`active`** by Ana Vieira · 14 Sep 09:02 `example`; histórico: was `proposed` from vocabulary (Done) · reaches **459** items · "completed means the work ended, **not** that it was accepted" | **revoke** |
   | — | *no Status value* | 8 (3 · 5) | *not a column — nothing to declare* | `absent` no value at the source | "these items read *no stage on this board*" |

   Linhas ativas têm fundo `info-soft`. Nota sob a tabela: nomes de estágio são as palavras da
   organização, não traduzidos nem fundidos entre quadros; *To Do* e *Todo* no mesmo quadro é
   anomalia sinalizada; **quem não administra vê a tabela sem a coluna `action`**.

   **Formulário aberto** — *Declare what `In Validation` means · 20 items carry it today*: cinco
   rádios, cada um com o id e uma linha do que afirma — *planned, not started*
   (`sro.intended_scrum_development_task`) · *in progress* (`spo.performed_project_activity ·
   start_date, no end_date`, marcado) · *completed* (`… with end_date` — "**not** that it was
   accepted") · *this column says no phase* (no concept — refusal recorded with author and
   instant; removes the option from proposals) · *no decision* (default). **Caixa tracejada
   "Not offered here: accepted / not accepted"** citando `sro.rule03` e apontando para *Where
   evaluation happens*. Botões **Declare** · **Cancel**; nota "records your name and the
   instant; the option is referenced by its identifier".

   **Where the two statements disagree** — `h4`; parágrafo (informação sobre o processo, nunca
   erro); dois medidores `declared`: **294** *completed by the board · open at the source*
   ("64% of the 459 in Done") e **41** *closed at the source · not completed by the board* ("the
   current stage is shown on each"); ambos são links para a lista. **Aviso observado**: *Auto-close
   issue* off · *Item closed* off · *Auto-add sub-issues* on — "disconnected on purpose". Última
   linha: sem regra ativa, os dois leem *not declared — declare what completed means on this
   board*.
7. **C · Where evaluation happens** — `h4`, marca `declared by this organisation`, rótulo
   `067 · new`. Parágrafo com `sro.rule03`, os dois passos, "derived at read time", e **"Nothing
   here is proposed — recommending would be choosing (042)"**.

   **step 1 · The stage where evaluation happens** — 12 chips na ordem observada, nenhum
   pré-marcado por padrão; **Homologation** ligado com `335 today`; linha `chosen · Homologation ·
   by Ana Vieira · 14 Sep 09:20 example · + add another evaluation stage`.

   **step 2 · What each exit from Homologation means** — parágrafo dos três sentidos e da
   recusa "never receives a meaning by omission". **Tabela** — colunas `exit` · `times in events`
   · `means` · `declared` · `action`:

   | exit | times | means | declared | action |
   |---|---|---|---|---|
   | Homologation → **Done** | **10** (May–Jul 2026) | accepted · `sro.accepted_deliverable · derived at read time` | `active` Ana Vieira 09:22 `example` | revoke |
   | → In Validation | 2 (Jul–Sep 2026) | *not declared* | `absent` nobody classified + "reads *exit not declared* — never 'no verdict' by default" | `classify…` (formulário aberto abaixo) |
   | → Homologation In Progress | 2 | *not declared* | `absent` | `classify…` |
   | → To Do | 1 | no verdict · *no phase · counts as a return* | `active` | revoke |
   | → Dependencies | 1 | no verdict · *counts as a return* | `active` | revoke |
   | → **Desaprovado** | **0** (collected · up to 9 Sep) | not accepted · `sro.not_accepted_deliverable` | `active`; nota "**zero is a count, not a missing criterion** — the only card in Desaprovado came from In Progress (4 May 2026)" | revoke |
   | → Backlog · Refinamento · Pronto para desenvolvimento · Paused · In Progress | 0 (no exit recorded) | *not declared* | `absent` + "a new exit that appears after the declaration stays *not declared*, counted and shown" | `classify one…` |

   **Formulário aberto** — *Classify `Homologation → In Validation` · 2 occurrences collected*:
   três rádios — *accepted* (`sro.accepted_deliverable`; a tarefa lê *performed successfully — by
   declaration*) · *not accepted* (`sro.not_accepted_deliverable`; *performed without success — by
   declaration*) · *no verdict* (marcado; volta a *no declared evaluation*; a passagem conta como
   retorno). Botões **Classify** · **Cancel**.

   **Cláusula** (checkbox, **desmarcado**): *Only transitions made by a person count as
   evaluation* — texto com os **80** moves do `github-project-automation`; com a cláusula leem
   *moved by automation, not evaluated*; gravada com a declaração.

   **Coverage · always shown** (caixa): **147** issues passaram por Homologation nos eventos
   (**2** duas vezes) · **335** hoje · cerca de **188** sem evento de entrada · eventos até
   **9 Sep 2026**.

   **What follows on this board** — três medidores, nunca somados: **10** *accepted by the
   organisation's criterion* (Homologation → Done · May–Jul 2026 · each with instant and actor ·
   "never 'verified'") · **0** *not accepted* ("a count, not an absence of criterion") · *no
   declared evaluation* como **recusa de número** ("the rest of Done — item count not measured
   for this prototype") com a composição dos moves: In Progress → Done 197 · Backlog → Done 119 ·
   To Do → Done 58 · entered already Done 48 · In Validation → Done 9 · Refinamento 5 ·
   Dependencies 4 · Pronto para desenvolvimento 2 — e 80 do robô; base: "these are moves, not
   items; the screen counts items — *completed by the board · no declared evaluation*, never
   *accepted*". Linha à parte: *outside evaluation — closed as <reason>* (count not measured).
   Última linha: sem estágio escolhido, o cartão inteiro lê *acceptance criterion not declared*
   — ausência distinta de *no declared evaluation*.
8. Stubs **Fields** e **Backlogs · 1 194 items** — "unchanged".

### `screen 2 · where the statements land`

1. **Detalhe do item #2107** — `h2` com `#2107`, marca `BUG` (clay, do 060), título real;
   linha `created 1 Jun 2026 · assignee @harianadm · no sprint · on board Conecta Fapes #43`.
   **Três cartões de afirmação lado a lado**, cada um com o rótulo, a marca e a proveniência:
   - *at the source* · `observed` · **open** · "state OPEN · not closed · reason: none";
   - *by the board · Conecta Fapes #43* · `declared` · **completed — Done** · "by the rule Done →
     completed, declared by Ana Vieira on 14 Sep 2026 `example` · stage as the board calls it:
     Done" · "in Done since: `absent` instant unknown — no stage-change event collected for this
     item; only the current value is known";
   - *acceptance · Conecta Fapes #43* · `declared` · **no declared evaluation** (itálico, tinta-2)
     · "the criterion exists — Homologation → Done = accepted — and this item has no Homologation
     → Done event collected. Not accepted, not refused: not evaluated, as far as the collection
     knows" · "evaluation history: `absent` none collected".

   Aviso *three statements, three authors*: origem diz open, quadro diz completed, critério diz
   not evaluated; hoje a tela diz só *open*; o padrão de 294 itens é mostrado, não escondido.

   **Stage periods on Conecta Fapes #43** (cartão, `066 FR-024 · one row per pass`) — tabela
   `stage · entered · left · source of the period` com a linha **Done · `absent` unknown · still
   there · `observed` current value · no event**; nota "Age in the current stage: unknown — never
   counted from the collection date. Passes through stages: unknown — no events collected for
   this item".
2. **Painel de @harianadm** — `h2` `@harianadm`; `56 cards on Conecta Fapes #43 · the person who
   gave the feedback`. **Três cartões de afirmação**:
   - *at the source* · `observed` · **4 closed** · "all four among her Done cards · open/closed
     split of the other 29 cards: not measured for this prototype";
   - *by the board* · `declared` · **27 completed · 25 in progress** · "27 completed by the board
     — 23 open at the source, 4 closed · 25 in progress by the board — 24 Homologation · 1 In
     Progress" · "4 cards in stages with no decision — To Do 3 · Refinamento 1 — read *not
     declared*, not 'not completed'";
   - *acceptance* · `declared` · **not measured for this prototype** · "the screen shows, for her:
     accepted · not accepted · no declared evaluation — three counts, each opening its list — and,
     apart, *outside evaluation*".

   **Coverage · her cards**: 24 in Homologation today · entry events: not measured · up to 9 Sep
   2026. **Dois medidores**: **23** *completed by the board · open at the source* ("the 23 the
   feedback called 'treated as open'" · "a disagreement between two statements, not an error of
   hers") · *closed at the source · not completed by the board* como recusa ("not measured for
   this prototype"). Frase final: *open now*, burn e throughput mantêm a definição de hoje —
   *closed at the source* — e cada rótulo diz isso (066 FR-015); a troca é escolha da organização,
   fora desta tela.

### `decisions and open questions`

Dez decisões numeradas **D1–D10**, cinco perguntas abertas **Q1–Q5** com opções e
recomendação, e a lista dos **nomes que a base precisa antes do código**. Fecha com "Approval:
awaiting the maintainer".

## 4. Como cada papel usa este arquivo

- **Product Owner**: registra no item do backlog o endereço e este prompt; cita os dois na spec;
  leva as perguntas **Q1–Q5** à pessoa mantenedora e traz as respostas; aceita a entrega **só**
  conferida item a item contra a seção 3, com captura da tela real ao lado.
- **Elixir/Phoenix Developer**: implementa **exatamente** a seção 3 — os textos em inglês são os
  da tela; o que descobrir impossível ou desonesto com o dado volta ao protótipo, nunca é
  ajustado no código.
- **QA**: para cada item da seção 3 — existe, na ordem, com o texto, com a marca, com a ação e
  com a recusa. As marcas se distinguem **sem cor** (forma + texto). Toda ausência está escrita.
  Nenhum número soma afirmações de naturezas diferentes.
- **Design**: republica **no mesmo endereço** quando uma pergunta é decidida (marca *Decided
  <data>*) ou quando a implementação devolve uma correção; registra a mudança no `README.md`.
