# Features

What the product does, written for **those who use it**.

The rest of the site describes how The Band is built — the [architecture](../architecture/overview.md),
the [ontology network](../ontology/README.md), the [decisions](../adr/README.md) and the
[measures](../metrics/README.md). None of those pages answers the question of whoever opens the
platform: *what does this screen tell me, and what does it not tell me*.

This section answers that one.

## The pages

| Page | The screen | Features |
|---|---|---|
| [The team screen](tela-da-equipe.md) | `/teams/:id` — who is on the team, and how it is doing | [055](../../specs/055-equipes-declaradas/spec.md), [057](../../specs/057-tela-da-equipe-complexa/spec.md), [058](../../specs/058-medidas-da-equipe/spec.md), [060](../../specs/060-tela-da-equipe/spec.md) |

## The three rules that apply to every page in this section

They are not style. They are the reason the section exists, and what sets it apart from
promotional material.

1. **Only what is on the screen goes in.** The yardstick is the implementation, not the specification.
   A requirement that is written and not built is a **named gap** at the end of the page, never a
   description in the present tense. A page that describes the screen that was meant to be delivered
   teaches its reader to distrust all the others.

2. **The interface is in English; the text is in Portuguese.** When a screen label is quoted,
   it is quoted **in English** — it is what the person will look for with their eyes — and
   explained in Portuguese. Translating the label in the text would make the person look for a
   word the screen does not have. That the interface is in English is a gap recorded in
   [`portugues-na-interface`](../backlog/portugues-na-interface.md).

3. **No invented numbers.** Every numeric example comes from a document in this
   repository, and the page says where from. Where there is no measurement, the page describes it
   **without a number** instead of rounding a plausible one.
