---
name: The Band
description: Orchestrating data into information organisations can act on
colors:
  verdete: "#1f6f68"
  verdete-deep: "#14504a"
  paper: "#f7f8f7"
  paper-shade: "#eef0ee"
  paper-line: "#d7dcd8"
  ink: "#101614"
  info-blue: "#23566f"
  amber-divergence: "#8a5a0c"
  clay-refusal: "#8c3327"
typography:
  scale:
    tick: "0.625rem"
    micro: "0.6875rem"
    label: "0.75rem"
    meta: "0.8125rem"
    body: "0.875rem"
    prose: "1rem"
    lead: "1.125rem"
    title: "1.25rem"
    section: "1.5rem"
    hero: "1.875rem"
  display:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    fontWeight: 650
    letterSpacing: "-0.02em"
    lineHeight: 1.2
  body:
    fontFamily: "ui-serif, Georgia, 'Iowan Old Style', 'Times New Roman', serif"
    fontSize: "1rem"
    lineHeight: 1.6
  label:
    fontFamily: "ui-monospace, 'SF Mono', SFMono-Regular, Menlo, Consolas, monospace"
    letterSpacing: "0.06em"
rounded:
  mark: "0.125rem"
  field: "0.25rem"
  box: "0.5rem"
  pill: "9999px"
components:
  button-primary:
    backgroundColor: "{colors.verdete}"
    textColor: "#f4f6f4"
    rounded: "{rounded.field}"
  button-soft:
    backgroundColor: "#e2edeb"
    textColor: "{colors.verdete-deep}"
    rounded: "{rounded.field}"
---

# Design System: The Band

## Overview

**Creative North Star: "A Partitura"**

A pauta que separa o que estava escrito do improviso. A interface existe para uma distinção só — **observado versus derivado** — e todo o sistema visual é essa distinção tornada material: preenchimento sólido é o que a origem afirmou, hachura é derivação declarada, tracejado é ausência nomeada. Um músico que improvisa não está errado, mas quem ouve precisa saber que aquilo não estava escrito.

O suporte é papel de desenho técnico: neutros com viés para a primária (nunca cinza puro, que lê como não escolhido), três vozes tipográficas do sistema operacional (nenhuma webfont), superfícies planas separadas por camada tonal e borda fina. A cor primária é **verdete de instrumento** — cor de instrumento de medição calibrado, deliberadamente não-urgente: onde ela aparece significa "a origem afirmou", nunca "aja agora". A fonte normativa profunda deste sistema é `docs/design-system.md`; este arquivo é a captura portátil.

**Key Characteristics:**
- O preenchimento carrega a proveniência: sólido / hachurado / tracejado, sempre com texto e `title` redundantes (cor nunca é o único canal).
- Ausência é nomeada com dono ("not collected", "no type at the source") — nunca travessão, célula vazia ou zero.
- Três vozes: grotesca para o que se escaneia, serifa para o que se lê, mono para o que se compara.
- Plano por doutrina: profundidade é camada tonal, nunca sombra.
- A interface fala inglês; código e documentação falam português.

## Colors

Paleta de instrumento medido sobre papel técnico: um verde-azulado calmo faz todo o trabalho de identidade, e as cores semânticas descrevem fatos sobre o dado, não falhas do sistema.

### Primary
- **Verdete de Instrumento** (#1f6f68 claro / #5cbcb2 escuro): a marca de evidência ("a origem afirmou"), botões primários, anel de foco, barras de cobertura. Também é o `success` — observado, promovido, alcançado.
- **Verdete Profundo** (#14504a claro / #3f9e94 escuro): secundária; hover e variação de ênfase da mesma família.

### Neutral
- **Papel** (#f7f8f7): fundo da página (base-100). Puxa para o verdete — papel de desenho técnico, não branco puro.
- **Sombra de Papel** (#eef0ee): superfície de cartão e painel (base-200).
- **Linha de Papel** (#d7dcd8): bordas e divisores (base-300), sempre 1.5px.
- **Tinta** (#101614): texto. Contraste acima de 12:1 sobre Papel.

### Tertiary
- **Azul de Informação** (#23566f claro / #7fb4d6 escuro): informativo neutro, raro.
- **Âmbar de Divergência** (#8a5a0c claro / #d9a441 escuro): rótulo e estrutura discordam. Não é erro do sistema.
- **Barro de Recusa** (#8c3327 claro / #e08574 escuro): vínculo recusado, contagem que não fecha. Também é fato sobre o dado.

**The Calibrated Instrument Rule.** Nenhuma cor de alerta na marca de evidência, e nenhum vermelho de erro na paleta: divergência é âmbar, recusa é barro, e ambas descrevem o dado — o sistema não falhou. Uma cor urgente onde se lê "a origem afirmou" diria que observar é emergência.

**The No-Pure-Grey Rule.** Todo neutro puxa para a primária. Cinza puro lê como não escolhido — o teste de tokens (`design_tokens_test.exs`) recusa o roxo e o laranja do gerador do Phoenix de volta.

## Typography

**Display Font:** pilha grotesca do sistema (-apple-system, BlinkMacSystemFont, Segoe UI)
**Body Font:** pilha serifada do sistema (ui-serif, Georgia, Iowan Old Style)
**Label/Mono Font:** pilha monoespaçada do sistema (ui-monospace, SF Mono, Menlo)

**Character:** três vozes, cada uma com um trabalho — a grotesca escaneia, a serifa lê, a mono compara. O corpo é serifado porque esta interface explica muito: por que uma issue divergiu, de quem é a ausência. Prosa longa em grotesca cansa.

### Hierarchy
- **Display/Headline** (650, entrelinha 1.2, tracking -0.02em, `text-wrap: balance`): h1–h4 e o número que decide (`.stat-value`). Escaneado, não lido.
- **Body** (400, 1rem, entrelinha 1.6): toda a prosa — explicações, motivos, axiomas.
- **Label** (mono ou caixa alta com tracking 0.06em): cabeçalho de coluna, identificador, chave de regra, contagem alinhada.

### A ramp — dez passos, cada um com um trabalho

Declarada em `typography.scale`, e medida em 2026-09-10: o código do produto usava **oito**
tamanhos arbitrários e os quatro protótipos usavam **trinta e quatro**. Trinta e quatro
tamanhos não são uma escala — são um valor escolhido por elemento, e a diferença aparece como
desalinho que ninguém consegue nomear.

| passo | rem | px | o trabalho |
|---|---|---|---|
| `tick` | 0.625 | 10 | rótulo de eixo **dentro de gráfico SVG** — o único lugar abaixo de 11px |
| `micro` | 0.6875 | 11 | rótulo mono em caixa alta, legenda, texto de marca |
| `label` | 0.75 | 12 | cabeçalho de coluna, chave de regra, identificador |
| `meta` | 0.8125 | 13 | segunda linha da célula, nota da linha, texto de apoio |
| `body` | 0.875 | 14 | o corpo de tela — prosa densa de ferramenta |
| `prose` | 1 | 16 | prosa de documento e de protótipo |
| `lead` | 1.125 | 18 | subtítulo, primeira linha de seção |
| `title` | 1.25 | 20 | título de seção |
| `section` | 1.5 | 24 | `h2` de tela |
| `hero` | 1.875 | 30 | `h1` de documento — protótipo e página longa, nunca tela de ferramenta |

**The One-Ramp Rule.** Nenhum tamanho fora destes dez, e a ramp é a mesma no código e no
protótipo — um protótipo com escala própria não é a tela que o código deve reproduzir. Onde o
Tailwind já tem classe para o passo (`text-xs` 12, `text-sm` 14, `text-base` 16), ela ganha do
literal: `text-xs` diz o passo, `text-[12px]` diz um número. Onde não tem — 10, 11 e 13 —, o
literal fica e nomeia um passo declarado.

**The No-Webfont Rule.** Nenhuma família baixada: ferramenta interna aberta dezenas de vezes por dia; a pilha do sistema entrega a hierarquia sem custo de rede.

**The Tabular Numbers Rule.** Número em coluna leva `tabular-nums`, sempre.

## Layout

Mobile-first por doutrina: empilhado por padrão, colunas a partir de `sm:` — nunca desenhar para a mesa e quebrar para baixo. Tabela com mais de três colunas leva `stacked` + `data-label` em cada célula: abaixo de 40rem cada linha vira cartão e a coluna mantém o nome via `content: attr(data-label)` (rolagem horizontal em 360px não é utilizável). Densidade de ferramenta: cartões `p-5`, tabelas `table-sm`/`table-xs`, grids com `gap` (nunca margens por elemento). Alvo de toque de 44px em ponteiro grosso, via pseudo-elemento, sem crescer o botão.

## Elevation & Depth

**Plano por doutrina** (confirmado 2026-08-17). Sem sombras: profundidade é camada tonal — Papel (página) → Sombra de Papel (cartão) → Linha de Papel (borda 1.5px). O `--depth: 1` do daisyUI fica como está, mas nenhuma tela nova introduz `box-shadow`.

**The Flat-By-Doctrine Rule.** Se uma tela parece precisar de sombra, o problema é hierarquia tonal ou espaçamento — resolva lá.

## Shapes

Cantos discretos, quatro passos declarados em `rounded`: **0.125rem** (`mark`) na marca de evidência e no anel de foco, **0.25rem** (`field`) em campos, seletores e botões, **0.5rem** (`box`) em cartões e caixas, e **9999px** (`pill`) na pílula. Nenhum valor fora destes quatro — a medição de 2026-09-10 achou 3.2px, 4.8px, 5.6px, 6.4px e 7.2px espalhados, todos a poucos décimos de um passo declarado e nenhum deles escolhido. Bordas de 1.5px na cor Linha de Papel. A forma característica do sistema não é o canto — é o **preenchimento**: sólido (observado), hachura de 135° em `currentColor` (derivado — `repeating-linear-gradient(135deg, currentColor 0 2px, transparent 2px 4px)` com contorno de 1px), tracejado (ausente). `currentColor` faz um utilitário só servir a todos os papéis de cor.

**The Fill Carries Provenance Rule.** A gramática sólido/hachurado/tracejado nunca aparece sem os outros dois canais: texto visível e `title` para leitor de tela. Remover um canal não remove a informação.

**The No-Accent-Edge Rule** (2026-09-10). **Nenhuma borda colorida acima de 1px num lado só** —
cartão, item de lista, aviso ou chamada. Uma barra grossa de um lado é o tique mais reconhecível
de interface gerada, e aqui era também um **segundo dispositivo fazendo o trabalho do primeiro**:
o sistema já diz de que natureza é uma afirmação, e diz no **preenchimento**. A medição achou dez
ocorrências — 3px e 4px, à esquerda e no topo, em três protótipos e em nove pontos do código,
inclusive no componente de aviso da casa.

O que fica no lugar, e é o que o sistema já declarava: **camada tonal** para separar, **borda
uniforme de 1.5px** quando precisa de mais separação, e a **cor semântica na borda inteira** ou
no **quadrado de 0.6rem** quando ela carrega sentido. Fio de **1px** continua valendo como régua
de indentação — régua não é acento. Onde a cor era o canal, o quadrado passa a ser: é o
componente-assinatura, e usa `currentColor`, de forma que um modificador de cor basta.

## Components

O vocabulário do produto vive em `TheBandWeb.UI` (evidence, absent, metric, notice, empty, phase); o genérico vive em `core_components` (botão, entrada, tabela). Os dois não se misturam.

### Buttons
- **Shape:** cantos discretos (0.25rem), altura daisyUI `btn`.
- **Primary:** Verdete sólido com texto claro (#f4f6f4) — só na ação principal da tela.
- **Default:** `btn-soft` — verdete diluído sobre papel, texto Verdete Profundo.
- **Hover / Focus:** anel de foco global de 2px em Verdete com offset de 2px, nunca removido; vale para todo focável, inclusive o que o daisyUI gera.
- **Regra dura:** a classe base `btn` entra SEMPRE — `class` do chamador acrescenta, nunca substitui (botão sem `btn` renderiza como texto puro; visto em produção 2026-08-16).

### Evidence Mark (componente-assinatura)
- **Sólido** em Verdete: a origem afirmou (`declared_type`).
- **Hachurado** 135°: derivado — convenção de título ou posição na estrutura; contorno de 1px em `currentColor`.
- **Tracejado:** ausência, sempre com o motivo em texto.
- A confiança só aparece quando não é a mais alta: `high` em toda linha gastaria a atenção que `low` precisa.

### Cards / Containers
- **Corner Style:** 0.5rem.
- **Background:** Sombra de Papel (`bg-base-200`); nunca sombra projetada.
- **Border:** 1.5px Linha de Papel quando precisa de separação extra.
- **Internal Padding:** p-5 (1.25rem).

### Badges / Chips
- daisyUI `badge` em variantes `-outline`/`-soft`; semântica sempre acompanhada de texto (badge de cor sozinho não informa).

### Inputs / Fields
- daisyUI `fieldset` (daisyUI 5 — `form-control` não existe mais); cantos 0.25rem; foco pelo anel global.

### Navigation
- Barra superior com as áreas do produto (People, Teams, Work, Projects, Boards, Process, Syncs, Tools, AI, Profiles); tenant e usuário à direita; grotesca.

### Stacked Table (padrão-assinatura)
- `table.stacked` + `data-label`: em telas estreitas cada linha vira cartão com o nome da coluna à esquerda em caixa alta 0.7rem.

## Do's and Don'ts

### Do:
- **Do** carregar a proveniência no preenchimento (sólido/hachurado/tracejado) com texto e `title` redundantes.
- **Do** nomear toda ausência com dono: "not collected — issue not re-observed", nunca "—" nem zero.
- **Do** usar `tabular-nums` em qualquer número em coluna.
- **Do** empilhar tabelas largas com `stacked` + `data-label` abaixo de 40rem.
- **Do** escrever frase de tela em inglês, mesmo nascendo no domínio — com comentário no código dizendo isso.
- **Do** declarar recorte na própria tela quando uma lista é limitada ("the 5 widest-covered skills of today; the coverage list above has them all").

### Don't:
- **Don't** usar webfont — a pilha do sistema é compromisso.
- **Don't** usar cinza puro, roxo ou laranja do gerador — o teste de tokens recusa.
- **Don't** introduzir `box-shadow` — plano por doutrina; profundidade é camada tonal.
- **Don't** remover ou substituir o anel de foco global de 2px.
- **Don't** deixar cor ser o único canal de um estado — ícone ou texto sempre junto.
- **Don't** escrever "permission denied" para recurso de outro tenant — é "not found"; dizer "sem permissão" confirma que o recurso existe.
- **Don't** esconder seção vazia em silêncio — a ausência aparece nomeada, com o que a faria existir.
