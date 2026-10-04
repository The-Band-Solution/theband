<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# UFO — Unified Foundational Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **22 of 23** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> Foundational ontology providing the distinctions used to classify concepts of all networked ontologies.

| | |
|---|---|
| **Id** | `ufo` |
| **Version** | 1.0.0 |
| **Layer** | Foundational |
| **Network** | UFO |
| **Namespace** | `the_band.ontology.ufo` |
| **Depends on** | — |
| **Origin** | `pt-BR` Tese, Seção 2.2.1 — UFO |

> **Note.** `pt-BR` Não reproduzimos a UFO inteira computacionalmente. Representamos apenas as categorias efetivamente usadas para classificar conceitos de SEON e Continuum.


## Modules

- **[Foundational Categories](#foundational-categories)** — `pt-BR` Categorias fundacionais usadas no campo classification.ufo_category dos conceitos de SEON e Continuum. Existem para impedir que o modelo trate um evento como objeto, ou um papel como tipo.

---

## Foundational Categories

<a id="foundational-categories"></a>

`pt-BR` Categorias fundacionais usadas no campo classification.ufo_category dos conceitos de SEON e Continuum. Existem para impedir que o modelo trate um evento como objeto, ou um papel como tipo.

*Source: `pt-BR` Tese, Seção 2.2.1 — UFO*

### Concepts

#### `ufo.object` — Object

*pt-BR: Objeto*

`pt-BR` Indivíduo que existe no tempo, mantendo sua identidade ao longo dele (endurante).

<sub>UFO category: `kind`</sub>

Examples: `pt-BR` *um repositório de código*; *uma máquina*

#### `ufo.event` — Event

*pt-BR: Evento*

`pt-BR` Indivíduo que ocorre no tempo (perdurante). Acontece, não persiste. Falhas, execuções de teste e atividades executadas são eventos.

<sub>UFO category: `event`</sub>

Examples: `pt-BR` *uma falha em produção*; *a execução de um build*

#### `ufo.situation` — Situation

*pt-BR: Situação*

`pt-BR` Porção da realidade que pode ser compreendida como um todo em um instante. Eventos são disparados por situações e trazem à tona novas situações.

<sub>UFO category: `situation`</sub>

#### `ufo.disposition` — Disposition

*pt-BR: Disposição*

`pt-BR` Propriedade que só se manifesta em circunstâncias específicas. Um defeito é uma disposição: existe no programa mesmo quando nunca se manifesta.

<sub>UFO category: `disposition`</sub>

#### `ufo.agent` — Agent

*pt-BR: Agente*

`pt-BR` Objeto capaz de ter intenções e realizar ações. Pessoas e organizações são agentes.

<sub>UFO category: `agent`</sub>

#### `ufo.role` — Role

*pt-BR: Papel*

`pt-BR` Tipo antirrígido e relacionalmente dependente: um indivíduo assume o papel em um contexto e pode deixá-lo sem perder identidade. Uma pessoa não é desenvolvedor por natureza; ela desempenha esse papel em um time.

<sub>UFO category: `role`</sub>

#### `ufo.social_role` — Social Role

*pt-BR: Papel Social*

`pt-BR` Papel reconhecido por uma entidade social, como uma organização.

<sub>UFO category: `social_role`</sub>

Examples: `pt-BR` *Product Owner Role*; *Scrum Master Role*

#### `ufo.social_object` — Social Object

*pt-BR: Objeto Social*

`pt-BR` Objeto cuja existência depende de convenção social. Documentos, requisitos e user stories são objetos sociais.

<sub>UFO category: `social_object`</sub>

#### `ufo.relator` — Relator

*pt-BR: Relator*

`pt-BR` Indivíduo que fundamenta uma relação material entre outros indivíduos. Team Membership é o relator que conecta pessoa, papel e equipe.

<sub>UFO category: `relator`</sub>

#### `ufo.collective` — Collective

*pt-BR: Coletivo*

`pt-BR` Todo cujos membros desempenham o mesmo papel em relação ao todo.

<sub>UFO category: `collective`</sub>

Examples: `pt-BR` *uma branch, entendida como coleção de artefatos de um repositório*

#### `ufo.complex_action` — Complex Action

*pt-BR: Ação Complexa*

`pt-BR` Evento intencional composto de outras ações. Um processo executado é uma ação complexa; o processo planejado é uma intenção, não uma ação.

<sub>UFO category: `complex_action`</sub>

#### `ufo.intention` — Intention

*pt-BR: Intenção*

`pt-BR` Estado mental de comprometimento com um propósito. Fundamenta a distinção entre processo planejado (intended) e processo executado (performed).

<sub>UFO category: `intention`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `triggers` | `ufo.situation` | `ufo.event` | one → many | causation |
| `brings about` | `ufo.event` | `ufo.situation` | one → one | causation |
| `manifested in` | `ufo.disposition` | `ufo.event` | one → many | materialization |

- **`ufo.manifested_in`** — `pt-BR` Uma disposição só é observável quando se manifesta em um evento. Um defeito que nunca se manifesta continua existindo.


---

[← Ontology network](README.md)

