# T024 — Percurso do quickstart

**Feature**: 042 · **Data**: 2026-08-25 · **Issue**: [#482](https://github.com/The-Band-Solution/theband/issues/482)

O registro que a T024 pede: os sete passos, o que apareceu, e o que divergiu.

## Como este percurso foi feito

**Na tela, com o navegador, contra o banco de desenvolvimento.** `mix phx.server` no ar,
Chromium conduzido por Playwright, autenticado como `admin@the-band-solution.example` no
tenant *The Band Solution*. Cada passo foi clicado, e o texto abaixo é o que a página
renderizou — não o que o código promete.

Isso é diferente do [percurso da 027](../027-geracao-mensal-de-perfis/percurso-t026.md), que
foi derivado do banco e do código porque a feature dependia de credencial externa. Aqui não
dependia, e derivar seria escolher o caminho mais barato sem motivo.

As capturas de tela ficaram fora do repositório — a do passo 5 tem 4 MB, e o que ela prova
está transcrito. O que **não** está transcrito não aconteceu.

## O estado de partida

| | |
|---|---|
| tenant | The Band Solution |
| `project_items` | 4.070 |
| quadros observados | 26 |
| projetos vigentes | **nenhum** |
| critérios declarados | nenhum |

Tipos de evento coletados, os cinco maiores: `ProjectV2ItemStatusChangedEvent` 5.965,
`AddedToProjectV2Event` 3.028, `AssignedEvent` 2.172, `IssueTypeAddedEvent` 2.036,
`CrossReferencedEvent` 1.547 — **os mesmos números que o quickstart previu**, escritos
quando a feature era só especificação.

---

## Passo 0 — o pré-requisito, e a primeira divergência

O quickstart pede "um projeto com pelo menos um quadro associado". Não havia: os quatro
projetos do banco de desenvolvimento foram removidos em 2026-08-19.

Criar um chamado `Conecta Fapes` foi **recusado**:

> That change was refused.
> name: has already been taken

E na mesma tela, ao mesmo tempo:

> No project registered yet. A project is declared, never observed — the platform will not
> create one from a repository name or an organisation.

**Divergência D1**, registrada como [#509](https://github.com/The-Band-Solution/theband/issues/509).
`unique_index(:spo_projects, [:tenant_id, :name])` é total, e reserva o nome de projetos
removidos para sempre. É exatamente o oposto do que a migração da 042 fez de propósito, e
pelo motivo que ela escreveu: *"um índice total impediria redeclarar"*.

Não é da 042. O percurso seguiu com `Conecta Fapes 042`, e quatro quadros associados pela
tela: `Conecta Fapes`, `Conecta Fapes - Delivery`, `Conecta Fapes - Discovery` e
`Conecta Fapes - Teste`. **1.110 issues alcançadas.**

---

## Passo 1 — sem critério, nada é afirmado (`FR-004`)

Apareceu, em frase:

> No criterion declared. Until one is, this project has **no start instant** — and throughput,
> work in progress and cycle time have nothing to measure from. Choose the event below.

E a contagem:

> START INSTANT · 1110 ISSUES REACHED
> 0 have a start instant.
> 1110 have none because no criterion applies to them — declare one above, on this project or
> on their board.

**Passa.** Nenhum código de motivo na tela.

---

## Passo 2 — o volume, e nada recomendado (`FR-012`)

O seletor trouxe doze tipos, ordenados por volume, cada um com a contagem:

```
ProjectV2ItemStatusChangedEvent — 5965 observed
AddedToProjectV2Event — 3028 observed
AssignedEvent — 2172 observed
IssueTypeAddedEvent — 2036 observed
...
ReopenedEvent — 16 observed
```

Nenhum pré-selecionado, nenhum marcado como sugerido. **Passa.**

---

## Passo 3 — a declaração vale na leitura seguinte (`FR-005`, `FR-013`)

Declarado `ProjectV2ItemStatusChangedEvent`. Na mesma tela, sem nenhum passo intermediário:

> 939 have a start instant.
> 171 have none because the declared event was never observed on them — collect again, or the
> event genuinely never happened.

Numa issue (`580ad45f`):

> **2026-06-10 18:24** — the first time `ProjectV2ItemStatusChangedEvent` happened on it.
> Criterion declared by **project Conecta Fapes 042**.

Trocado para `AssignedEvent`. **A mesma issue, recarregada, sem nenhum botão de recalcular:**

> **2026-06-11 14:00** — the first time `AssignedEvent` happened on it.

**Passa.** O instante mudou porque a leitura resolve, e não porque alguém rodou algo.

---

## Passo 4 — o quadro vence, e a tela avisa antes (`FR-006`, `FR-014`)

Declarado `AddedToProjectV2Event` no quadro `Conecta Fapes - Discovery`:

> Work on this board starts when `AddedToProjectV2Event` happens. This wins over the project's
> criterion.

De volta à tela do projeto, **antes de qualquer nova gravação**:

> **1 board(s) will ignore this** — they declared their own, and the board wins over the project:
> `Conecta Fapes - Discovery → AddedToProjectV2Event`

**Passa.** O aviso nomeia o quadro, e aparece antes.

---

## Passo 5 — o desempate, e a frase quando ele não resolve (`FR-007`, `FR-008`)

**A parte que desempata.** Declarados `LabeledEvent` em `Conecta Fapes - Delivery`
(vinculado 02:40:47) e `ClosedEvent` em `Conecta Fapes` (02:40:50). Duas issues nos dois
quadros resolveram por **`ClosedEvent`** — o do vínculo mais recente. **Passa.**

**A parte que não desempata.** Os dois quadros foram desassociados e reassociados em
rajada pela tela, que é o que uma associação em lote faz. `linked_at` ficou **idêntico** nos
dois: `2026-08-26 02:45:38`.

> **399 have none because two boards tie** — unlink one of them, listed below.
>
> **Waiting on a decision.** These were linked to two boards **at the same instant**, and both
> boards declared a criterion. The platform **does not pick one** — picking would be choosing
> on your behalf, where nobody would look for it.
>
> `[FIX][Front-end] Correção da chamada de endpoint de histórico` — Conecta Fapes ·
> Conecta Fapes - Delivery · linked 2026-08-26 02:45

**Passa** — e mostra que o empate não é hipótese de spec: **399 issues em 1.110**, produzidas
por dois cliques seguidos numa tela.

---

## Passo 6 — as três ausências não se misturam (`FR-009`, `FR-015`)

As três apareceram juntas e separadas, cada uma com o que fazer:

| ausência | a tela escreveu |
|---|---|
| sem critério | *no criterion applies to them — **declare one above**, on this project or on their board* |
| evento não coletado | *the declared event was never observed on them — **collect again**, or the event genuinely never happened* |
| critério ambíguo | *two boards tie — **unlink one of them**, listed below* |

Nenhuma somada com outra. Nenhuma renderizada como zero. Nenhum código de motivo.
**Passa** — é a `SC-008` observada, e não afirmada.

---

## Passo 7 — desfazer preserva (`FR-010`)

Revogado o critério do projeto. A tela voltou à frase do passo 1, e o histórico no banco:

| evento | declarado | revogado | quem declarou | quem revogou |
|---|---|---|---|---|
| `ProjectV2ItemStatusChangedEvent` | 02:41:42 | 02:42:37 | sim | sim |
| `AssignedEvent` | 02:42:37 | 02:46:06 | sim | sim |
| `AddedToProjectV2Event` (quadro) | 02:43:06 | — | sim | — |
| `LabeledEvent` (quadro) | 02:43:55 | — | sim | — |
| `ClosedEvent` (quadro) | 02:43:58 | — | sim | — |

**Passa.** Revogar marca, e nunca apaga.

---

## O que divergiu, e o que foi feito

| # | divergência | destino |
|---|---|---|
| D1 | projeto removido mantém o nome reservado, e a tela se contradiz | [#509](https://github.com/The-Band-Solution/theband/issues/509) — não é da 042 |
| D2 | datas em ISO cru (`2026-08-26T02:42:37Z`) ao lado de datas formatadas | corrigido |
| D3 | *"the first time X happened on it — the first, because…"* — repetição que atrapalha a leitura | corrigido |
| D4 | 399 linhas de empate renderizadas sem corte | corrigido: vinte, e a frase diz quantas ficaram de fora |
| D5 | a explicação do desempate só na tela do quadro, e o empate na do projeto | corrigido, com caso de teste |

D2 a D5 são da 042 e foram corrigidos neste mesmo percurso. Nenhum deles teria aparecido
na suíte: a suíte confirma que a frase está lá, não que ela é legível ao lado das outras.

## A `SC-007` — a frase ensina quem nunca leu a spec?

É a pergunta que teste automatizado não responde, e a razão de a T024 existir.

**Onde ensina.** A frase da ausência sempre termina na ação, e a ação é diferente em cada
uma — *declare one*, *collect again*, *unlink one of them*. Quem lê não precisa saber que
existem três ausências: descobre pela ação que cada uma pede.

O aviso do passo 4 ensina a escala inteira numa linha: *"the board wins over the project"*,
com os nomes dos quadros que vão ignorar. Ninguém precisa procurar a regra.

**Onde não ensinava.** A explicação do desempate — *"the criterion that applies is the one
from the board most recently linked to the project"* — estava só na tela do **quadro**, e o
empate aparece na tela do **projeto**. Quem via as 399 linhas lia que a plataforma não escolhe,
e não lia ali **por que** a data do vínculo é o critério. A `FR-017` pede a explicação *no
ponto da decisão*, e o ponto da decisão são os dois lugares.

**Divergência D5**, corrigida no mesmo percurso: a explicação passou a abrir o bloco de
pendências, e a frase seguinte diz o que o empate tem de particular — *"there is no most
recent one"*. Repetir a regra nas duas telas é barato; mandar quem lê procurar na outra não é.

Um caso novo em `criterio_na_tela_test.exs` guarda isso, e é o único achado deste percurso
que a suíte passou a cobrir — os outros três são de forma, e nenhuma asserção os alcançaria.
