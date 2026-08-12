# Design system

A regra que decide todo o resto: **o preenchimento carrega a proveniência.**

A plataforma existe para separar o que foi **observado** do que foi **derivado**, e para nunca
deixar ausência parecer zero. Se a interface não carrega essa distinção, ela desfaz o produto.

Este documento é normativo: o que está aqui vale para toda tela nova.

---

## De onde vem o nome, e por que isso importa para a interface

> Cada serviço da arquitetura é um **músico** que toca um **instrumento** — uma ontologia, com
> seus conceitos, relações e regras. Juntos produzem **música** — informação — a partir de
> **notas** — os dados das aplicações — para satisfazer um **público**: a organização.
>
> — rodapé da tese, UFES 2023

| na metáfora | na plataforma | onde aparece na tela |
|---|---|---|
| músico | serviço baseado em ontologia | as fases da sincronização |
| instrumento | ontologia: conceitos, relações, regras | o identificador do conceito, sempre à vista |
| nota | dado da aplicação, como a origem entregou | *type at source*, o título cru, o rótulo |
| música | informação: o conceito, a medida, a resposta | *promoted to*, as contagens, as divergências |
| público | a organização que decide | toda tela é escopada por organização |

A tagline é **`Orchestrating data into information organisations can act on`**.

Ela diz a cadeia inteira, na ordem em que a plataforma a percorre:

| na frase | na plataforma |
|---|---|
| `data` | a nota: o dado como a origem entregou |
| `orchestrating` | os músicos e os instrumentos: cada serviço tocando uma ontologia |
| `information` | a música: o conceito, a medida, a resposta |
| `organisations can act on` | o público: quem decide, e a decisão que a medida sustenta |

**A metáfora saiu da tagline e ficou no nome.** `The Band` carrega a banda; a linha abaixo diz o que
a banda entrega, sem pedir que ninguém conheça o rodapé da tese. Quem pergunta pelo nome recebe a
tabela acima.

`Orchestrating` tem um sentido a desfazer, e vale registrar: em vocabulário técnico a palavra virou
infraestrutura — orquestrar contêiner, orquestrar fluxo de tarefa. Aqui é o maestro, e o que impede
a leitura errada é o fim da frase: nenhum orquestrador de contêiner entrega **informação sobre que a
organização age**.

`act on` é o teste da frase inteira. Informação que ninguém usa para decidir não é o produto — e é o
que a base de conhecimento já exige, com `decision_supported` declarado em cada necessidade de
informação antes de existir medida.

Versões anteriores, e por que saíram: `notes into music` parava no meio — transformar dado em
informação é o que todo pipeline promete; `notes into music you can decide on` acrescentava o
público e continuava exigindo a metáfora para ser entendida.

E a metáfora dá o argumento central: **um músico que improvisa não está errado, mas quem ouve
precisa saber que aquilo não estava escrito.** É a distinção entre observado e derivado.

---

## 1. A gramática da evidência

Três canais ao mesmo tempo, e remover um não remove a informação:

| canal | observado | derivado | ausente |
|---|---|---|---|
| preenchimento | sólido | hachurado | tracejado |
| texto | sempre | sempre | sempre |
| leitor de tela | `title` na marca | idem | idem |

```elixir
<.evidence
  concept={i.derived_concept}
  source={i.evidence_source}
  confidence={i.confidence}
  skip_reason={i.skip_reason}
  skip_detail={i.skip_detail}
/>
```

`source` decide a forma, e **não** o conceito: a mesma user story pode vir das duas origens.

| `source` | forma | significa |
|---|---|---|
| `declared_type` | sólido | alguém tipou a issue na ferramenta |
| `title` | hachurado | convenção de título que a organização declarou |
| `structure` | hachurado | posição no grafo de decomposição — a evidência mais fraca |
| `nil` | sólido | promoção anterior ao registro de proveniência |

A confiança aparece **só quando não é a mais alta**: dizer `high` em toda linha gastaria a
atenção que `low` precisa ter.

### Ausência é nomeada, nunca desenhada como quantidade

```elixir
<.absent reason="nobody assigned" />
<.absent reason="not in a milestone" />
```

| ✅ | ❌ |
|---|---|
| `undefined — no type at the source` | `—` |
| `not collected — issue not re-observed` | célula em branco |
| `no team — organisation unknown` | `0` |

O travessão é a mentira mais barata que uma tabela conta: ocupa o lugar de um número e não diz
**de quem** é a ausência — da origem, ou da plataforma.

E `undefined` **não é conceito da ontologia**. Criar `sro.undefined` faria a ausência de
conhecimento virar conhecimento: as issues entrariam em contagens de conceito, e
"3 451 undefined" seria lido como um tipo de trabalho que o time faz.

---

## 2. Cor

**Primária: verdete de instrumento** — `#1f6f68` claro, `#5cbcb2` escuro.

Ela aparece na marca de evidência, onde significa *"a origem afirmou"*. Uma cor de alerta ali
diria que observar é urgente.

**Cor semântica é separada da primária**, e nenhuma é vermelho de erro — os três são fato sobre
o dado, não falha do sistema:

| papel | claro | escuro | quando |
|---|---|---|---|
| `success` | `#1f6f68` | `#5cbcb2` | observado, promovido, alcançado |
| `warning` | `#8a5a0c` | `#d9a441` | divergência entre rótulo e estrutura |
| `error` | `#8c3327` | `#e08574` | vínculo recusado, contagem que não fecha |

**Neutros puxam para a primária**, não para cinza puro: cinza puro lê como não escolhido.

Contraste conferido nos dois temas — texto acima de 12:1, primária acima de 4.5:1 (WCAG 1.4.3,
nível AA).

---

## 3. Tipografia

Três vozes, e cada uma tem um trabalho:

| voz | variável | onde |
|---|---|---|
| grotesca, peso alto | `font-sans` | título de tela e número que decide |
| serifada | `font-serif` | o que precisa ser **lido**: divergência, recusa, axioma |
| monoespaçada | `font-mono` | identificador, contagem alinhada, chave de regra |

O corpo é **serifado** porque esta interface explica muito, e prosa longa em grotesca cansa.

**Nenhuma webfont.** Uma família de 40 KB por peso, em três pesos, para uma ferramenta que abre
dezenas de vezes por dia — a pilha do sistema entrega a mesma hierarquia sem custo de rede.

Número em coluna leva `tabular-nums`, sempre.

---

## 4. Acessibilidade — WCAG 2.0, nível AA

| critério | como é atendido | onde vive |
|---|---|---|
| **1.4.1** cor não é o único meio | preenchimento + texto + `title` | `TheBandWeb.UI` |
| **1.4.3** contraste 4.5:1 | paleta conferida nos dois temas | `app.css` |
| **1.3.1** estrutura programática | `<table>` real, `role="progressbar"` com valores, `<dl>` | componentes |
| **2.4.7** foco visível | anel de 2px explícito, nunca removido | `app.css` |
| **2.5.5** alvo de toque | 44 px em ponteiro grosso, sem crescer o botão | `app.css` |
| **2.3.3** movimento | pulso para sob `prefers-reduced-motion` | `app.css` |

O rótulo de leitor de tela de uma barra de fase lê **o número**, não a cor:
`"issues: 3,383 of 3,383"`.

---

## 5. Mobile-first

Empilhado por padrão; colunas a partir de `sm:`. **Nunca o contrário** — desenhar para a mesa e
quebrar para baixo produz o menu que corta no meio em 360 px.

Tabela com mais de três colunas leva `stacked` e cada `<td>` leva `data-label`:

```heex
<table class="table table-sm stacked">
  <thead><tr><th>organisation</th><th>repository</th></tr></thead>
  <tbody>
    <tr>
      <td data-label="organisation">leds-conectafapes</td>
      <td data-label="repository">portal-fapes</td>
    </tr>
  </tbody>
</table>
```

Abaixo de 40 rem cada linha vira cartão e a coluna mantém o nome. Rolagem horizontal em 360 px
não é utilizável.

---

## 6. Onde cada coisa vive, e por quê

**Tailwind no markup; CSS só para o que Tailwind não expressa.**

A gramática da evidência é utilitário, **junto do componente**:

```elixir
@shape == :hatched &&
  "text-success outline outline-1 -outline-offset-1 outline-current
   bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"
```

Longo, e é o preço de o padrão viver junto de quem o usa: quem lê o componente vê a diferença
sem abrir outro arquivo. `currentColor` faz um utilitário só servir para os três papéis.

O que fica em `app.css`, e **cada bloco tem a razão escrita**:

| bloco | por que não é utilitário |
|---|---|
| foco visível | precisa valer para todo focável, inclusive o que o daisyUI gera |
| alvo de toque | depende de `@media (pointer: coarse)` e de pseudo-elemento |
| movimento reduzido | `motion-safe:` protege a animação que eu escrevo, não a de terceiros |
| tabela que empilha | `content: attr(data-label)` — nenhuma classe gera conteúdo de atributo |

Um bloco de CSS próprio **sem** a razão escrita é convite para alguém convertê-lo em utilitário
e quebrar o que ele protegia.

---

## 7. Os componentes

`TheBandWeb.UI` — vocabulário do **produto**. `core_components` é o que o Phoenix gera: botão,
entrada, tabela. Manter os dois separados é o princípio X aplicado a componentes.

| componente | responde |
|---|---|
| `evidence` | qual conceito, e de onde veio |
| `absent` | o que falta, e de quem é a falta |
| `metric` | um número que decide, com a composição embaixo |
| `field` | rótulo e valor; empilha no telefone |
| `notice` | `:gap`, `:divergence`, `:refused` — cada um com ícone além da cor |
| `empty` | qual dos três vazios, e o que fazer |
| `phase` | progresso da própria fase, hachurado quando derivado |

`ConceptLabel` traduz identificador, lacuna, fonte, confiança, divergência e recusa. Não
**decide** nada: traduzir é exibição, decidir é `WorkItems.Routing`.

---

## 8. Voz

| situação | não escreva | escreva |
|---|---|---|
| campo sem valor | `—` | `not collected` · `no type at the source` |
| axioma contradiz o rótulo | `invalid type` | `there is no epic without parts — the structure decided` |
| rótulo e estrutura discordam | `classification error` | `the concept was kept; this is a signal about the team's process` |
| vínculo recusado | `import failed` | `decomposition cycle — both issues are still collected` |
| recurso de outro tenant | `permission denied` | `not found` |

A última linha não é estilo: dizer "sem permissão" confirma que o recurso existe.

**A interface fala inglês; código, comentários e documentação falam português.** Frase que vai
para a tela é em inglês **mesmo nascendo no domínio** — `Axioms.explicacao/1`, os motivos de
divergência, `Client.describe_error/1` —, e cada uma tem comentário dizendo isso, para ninguém
traduzir de volta por engano.

---

## 9. Como verificar que está aplicado

"Apliquei a paleta" é afirmação sobre o **build**, não sobre o arquivo editado: o Tailwind poda
o que não encontra no markup, e um token declarado que ninguém usa não chega ao navegador.

```bash
mix test test/the_band_web/design_tokens_test.exs
```

Nove verificações: o verdete no CSS compilado, o roxo e o laranja **recusados** de volta, as
três vozes como variáveis do tema, nenhuma webfont, e cada bloco de CSS próprio com
justificativa.

---

## Protótipos

- [design system e proposta](https://claude.ai/code/artifact/9c862bee-0638-4386-bbe2-d34a5fac428e)
- [as nove telas, alternando telefone e mesa](https://claude.ai/code/artifact/07a08a47-adf1-44ac-8230-3532debadd93)
