# Design system

The rule that decides everything else: **the fill carries the provenance.**

The platform exists to separate what was **observed** from what was **derived**, and to never
let absence look like zero. If the interface does not carry that distinction, it undoes the product.

This document is normative: what is here applies to every new screen.

---

## Where the name comes from, and why it matters for the interface

> Each service in the architecture is a **musician** playing an **instrument** — an ontology, with
> its concepts, relations and rules. Together they produce **music** — information — from
> **notes** — the applications' data — to satisfy an **audience**: the organization.
>
> — footnote of the thesis, UFES 2023

| in the metaphor | in the platform | where it appears on the screen |
|---|---|---|
| musician | ontology-based service | the synchronization phases |
| instrument | ontology: concepts, relations, rules | the concept identifier, always in view |
| note | application data, as the source delivered it | *type at source*, the raw title, the label |
| music | information: the concept, the measure, the answer | *promoted to*, the counts, the divergences |
| audience | the organization that decides | every screen is scoped by organization |

The tagline is **`Orchestrating data into information organisations can act on`**.

It states the whole chain, in the order the platform goes through it:

| in the sentence | in the platform |
|---|---|
| `data` | the note: the data as the source delivered it |
| `orchestrating` | the musicians and the instruments: each service playing an ontology |
| `information` | the music: the concept, the measure, the answer |
| `organisations can act on` | the audience: who decides, and the decision the measure supports |

**The metaphor left the tagline and stayed in the name.** `The Band` carries the band; the line below says what
the band delivers, without asking anyone to know the thesis footnote. Whoever asks about the name gets the
table above.

`Orchestrating` has a sense to undo, and it is worth recording: in technical vocabulary the word has become
infrastructure — orchestrating containers, orchestrating task flows. Here it is the conductor, and what prevents
the wrong reading is the end of the sentence: no container orchestrator delivers **information the
organization acts on**.

`act on` is the test of the whole sentence. Information nobody uses to decide is not the product — and that is
what the knowledge base already requires, with `decision_supported` declared in each information
need before any measure exists.

Earlier versions, and why they were dropped: `notes into music` stopped halfway — turning data into
information is what every pipeline promises; `notes into music you can decide on` added the
audience and still required the metaphor to be understood.

And the metaphor provides the central argument: **a musician who improvises is not wrong, but whoever listens
needs to know that it was not written.** That is the distinction between observed and derived.

---

## 1. The grammar of evidence

Three channels at the same time, and removing one does not remove the information:

| channel | observed | derived | absent |
|---|---|---|---|
| fill | solid | hatched | dashed |
| text | always | always | always |
| screen reader | `title` on the mark | same | same |

```elixir
<.evidence
  concept={i.derived_concept}
  source={i.evidence_source}
  confidence={i.confidence}
  skip_reason={i.skip_reason}
  skip_detail={i.skip_detail}
/>
```

`source` decides the shape, and **not** the concept: the same user story can come from both sources.

| `source` | shape | means |
|---|---|---|
| `declared_type` | solid | someone typed the issue in the tool |
| `title` | hatched | a title convention the organization declared |
| `structure` | hatched | position in the decomposition graph — the weakest evidence |
| `nil` | solid | promotion prior to the provenance record |

Confidence appears **only when it is not the highest**: saying `high` on every row would spend the
attention that `low` needs to have.

### Absence is named, never drawn as a quantity

```elixir
<.absent reason="nobody assigned" />
<.absent reason="not in a milestone" />
```

| ✅ | ❌ |
|---|---|
| `undefined — no type at the source` | `—` |
| `not collected — issue not re-observed` | blank cell |
| `no team — organisation unknown` | `0` |

The dash is the cheapest lie a table tells: it takes the place of a number and does not say
**whose** absence it is — the source's, or the platform's.

And `undefined` **is not an ontology concept**. Creating `sro.undefined` would turn the absence of
knowledge into knowledge: the issues would enter concept counts, and
"3 451 undefined" would be read as a kind of work the team does.

---

## 2. Color

**Primary: instrument verdigris** — `#1f6f68` light, `#5cbcb2` dark.

It appears on the evidence mark, where it means *"the source asserted"*. An alert color there
would say that observing is urgent.

**Semantic color is separate from the primary**, and none of them is error red — all three are facts about
the data, not system failures:

| role | light | dark | when |
|---|---|---|---|
| `success` | `#1f6f68` | `#5cbcb2` | observed, promoted, reached |
| `warning` | `#8a5a0c` | `#d9a441` | divergence between label and structure |
| `error` | `#8c3327` | `#e08574` | refused link, count that does not add up |

**Neutrals lean toward the primary**, not toward pure grey: pure grey reads as not chosen.

Contrast checked in both themes — text above 12:1, primary above 4.5:1 (WCAG 1.4.3,
level AA).

---

## 3. Typography

Three voices, and each one has a job:

| voice | variable | where |
|---|---|---|
| grotesque, heavy weight | `font-sans` | screen title and the number that decides |
| serif | `font-serif` | what needs to be **read**: divergence, refusal, axiom |
| monospace | `font-mono` | identifier, aligned count, rule key |

The body is **serif** because this interface explains a lot, and long prose in a grotesque is tiring.

**No webfont.** A 40 KB family per weight, in three weights, for a tool opened
dozens of times a day — the system stack delivers the same hierarchy at no network cost.

A number in a column gets `tabular-nums`, always.

---

## 4. Accessibility — WCAG 2.0, level AA

| criterion | how it is met | where it lives |
|---|---|---|
| **1.4.1** color is not the only means | fill + text + `title` | `TheBandWeb.UI` |
| **1.4.3** 4.5:1 contrast | palette checked in both themes | `app.css` |
| **1.3.1** programmatic structure | a real `<table>`, `role="progressbar"` with values, `<dl>` | components |
| **2.4.7** visible focus | explicit 2px ring, never removed | `app.css` |
| **2.5.5** touch target | 44 px on a coarse pointer, without growing the button | `app.css` |
| **2.3.3** motion | the pulse stops under `prefers-reduced-motion` | `app.css` |

The screen reader label of a phase bar reads **the number**, not the color:
`"issues: 3,383 of 3,383"`.

---

## 5. Mobile-first

Stacked by default; columns from `sm:` up. **Never the other way around** — designing for the desktop and
breaking downward produces the menu that cuts in half at 360 px.

A table with more than three columns gets `stacked` and each `<td>` gets `data-label`:

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

Below 40 rem each row becomes a card and the column keeps its name. Horizontal scrolling at 360 px
is not usable.

---

## 6. Where each thing lives, and why

**Tailwind in the markup; CSS only for what Tailwind does not express.**

The grammar of evidence is a utility, **next to the component**:

```elixir
@shape == :hatched &&
  "text-success outline outline-1 -outline-offset-1 outline-current
   bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"
```

Long, and that is the price of the pattern living next to whoever uses it: whoever reads the component sees the difference
without opening another file. `currentColor` makes a single utility serve all three roles.

What stays in `app.css`, and **each block has its reason written down**:

| block | why it is not a utility |
|---|---|
| visible focus | it needs to apply to every focusable element, including what daisyUI generates |
| touch target | it depends on `@media (pointer: coarse)` and on a pseudo-element |
| reduced motion | `motion-safe:` protects the animation I write, not third-party ones |
| stacking table | `content: attr(data-label)` — no class generates attribute content |

A block of custom CSS **without** its reason written down is an invitation for someone to convert it into a utility
and break what it protected.

---

## 7. The components

`TheBandWeb.UI` — the **product's** vocabulary. `core_components` is what Phoenix generates: button,
input, table. Keeping the two separate is principle X applied to components.

| component | answers |
|---|---|
| `evidence` | which concept, and where it came from |
| `absent` | what is missing, and whose absence it is |
| `metric` | a number that decides, with its composition underneath |
| `field` | label and value; stacks on the phone |
| `notice` | `:gap`, `:divergence`, `:refused` — each with an icon besides the color |
| `empty` | which of the three empties, and what to do |
| `phase` | progress of the phase itself, hatched when derived |

`ConceptLabel` translates identifier, gap, source, confidence, divergence and refusal. It does not
**decide** anything: translating is display, deciding is `WorkItems.Routing`.

---

## 8. Voice

| situation | do not write | write |
|---|---|---|
| field without a value | `—` | `not collected` · `no type at the source` |
| an axiom contradicts the label | `invalid type` | `there is no epic without parts — the structure decided` |
| label and structure disagree | `classification error` | `the concept was kept; this is a signal about the team's process` |
| refused link | `import failed` | `decomposition cycle — both issues are still collected` |
| a resource from another tenant | `permission denied` | `not found` |

The last row is not style: saying "no permission" confirms that the resource exists.

**The interface speaks English; code, comments and documentation speak Portuguese.** A sentence that goes
to the screen is in English **even when it is born in the domain** — `Axioms.explicacao/1`, the divergence
reasons, `Client.describe_error/1` — and each one has a comment saying so, so that nobody
translates it back by mistake.

---

## 9. How to verify it is applied

"I applied the palette" is a statement about the **build**, not about the edited file: Tailwind prunes
what it does not find in the markup, and a declared token nobody uses does not reach the browser.

```bash
mix test test/the_band_web/design_tokens_test.exs
```

Nine checks: the verdigris in the compiled CSS, the purple and the orange **refused** back, the
three voices as theme variables, no webfont, and each block of custom CSS with its
justification.

---

## Prototypes

- [design system and proposal](https://claude.ai/code/artifact/9c862bee-0638-4386-bbe2-d34a5fac428e)
- [the nine screens, alternating phone and desktop](https://claude.ai/code/artifact/07a08a47-adf1-44ac-8230-3532debadd93)
