<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# UFO — Unified Foundational Ontology

> Ontologia fundacional que fornece as distinções usadas para classificar os conceitos de todas as demais ontologias da rede: objetos, eventos, agentes, papéis, relatores, disposições, situações e coletivos.

| | |
|---|---|
| **Id** | `ufo` |
| **Versão** | 1.0.0 |
| **Camada** | Fundacional |
| **Rede** | UFO |
| **Namespace** | `the_band.ontology.ufo` |
| **Depende de** | — |
| **Origem** | Tese, Seção 2.2.1 — UFO |

> **Nota.** Não reproduzimos a UFO inteira computacionalmente. Representamos apenas as categorias efetivamente usadas para classificar conceitos de SEON e Continuum.


## Módulos

- **[Foundational Categories](#foundational-categories)** — Categorias fundacionais usadas no campo classification.ufo_category dos conceitos de SEON e Continuum. Existem para impedir que o modelo trate um evento como objeto, ou um papel como tipo.

---

## Foundational Categories

<a id="foundational-categories"></a>

Categorias fundacionais usadas no campo classification.ufo_category dos conceitos de SEON e Continuum. Existem para impedir que o modelo trate um evento como objeto, ou um papel como tipo.

*Fonte: Tese, Seção 2.2.1 — UFO*

### Conceitos

#### `ufo.object` — Object

*Objeto*

Indivíduo que existe no tempo, mantendo sua identidade ao longo dele (endurante).

<sub>categoria UFO: `kind`</sub>

Exemplos: *um repositório de código*; *uma máquina*

#### `ufo.event` — Event

*Evento*

Indivíduo que ocorre no tempo (perdurante). Acontece, não persiste. Falhas, execuções de teste e atividades executadas são eventos.

<sub>categoria UFO: `event`</sub>

Exemplos: *uma falha em produção*; *a execução de um build*

#### `ufo.situation` — Situation

*Situação*

Porção da realidade que pode ser compreendida como um todo em um instante. Eventos são disparados por situações e trazem à tona novas situações.

<sub>categoria UFO: `situation`</sub>

#### `ufo.disposition` — Disposition

*Disposição*

Propriedade que só se manifesta em circunstâncias específicas. Um defeito é uma disposição: existe no programa mesmo quando nunca se manifesta.

<sub>categoria UFO: `disposition`</sub>

#### `ufo.agent` — Agent

*Agente*

Objeto capaz de ter intenções e realizar ações. Pessoas e organizações são agentes.

<sub>categoria UFO: `agent`</sub>

#### `ufo.role` — Role

*Papel*

Tipo antirrígido e relacionalmente dependente: um indivíduo assume o papel em um contexto e pode deixá-lo sem perder identidade. Uma pessoa não é desenvolvedor por natureza; ela desempenha esse papel em um time.

<sub>categoria UFO: `role`</sub>

#### `ufo.social_role` — Social Role

*Papel Social*

Papel reconhecido por uma entidade social, como uma organização.

<sub>categoria UFO: `social_role`</sub>

Exemplos: *Product Owner Role*; *Scrum Master Role*

#### `ufo.social_object` — Social Object

*Objeto Social*

Objeto cuja existência depende de convenção social. Documentos, requisitos e user stories são objetos sociais.

<sub>categoria UFO: `social_object`</sub>

#### `ufo.relator` — Relator

*Relator*

Indivíduo que fundamenta uma relação material entre outros indivíduos. Team Membership é o relator que conecta pessoa, papel e equipe.

<sub>categoria UFO: `relator`</sub>

#### `ufo.collective` — Collective

*Coletivo*

Todo cujos membros desempenham o mesmo papel em relação ao todo.

<sub>categoria UFO: `collective`</sub>

Exemplos: *uma branch, entendida como coleção de artefatos de um repositório*

#### `ufo.complex_action` — Complex Action

*Ação Complexa*

Evento intencional composto de outras ações. Um processo executado é uma ação complexa; o processo planejado é uma intenção, não uma ação.

<sub>categoria UFO: `complex_action`</sub>

#### `ufo.intention` — Intention

*Intenção*

Estado mental de comprometimento com um propósito. Fundamenta a distinção entre processo planejado (intended) e processo executado (performed).

<sub>categoria UFO: `intention`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `triggers` | `ufo.situation` | `ufo.event` | one → many | causation |
| `brings about` | `ufo.event` | `ufo.situation` | one → one | causation |
| `manifested in` | `ufo.disposition` | `ufo.event` | one → many | materialization |

- **`ufo.manifested_in`** — Uma disposição só é observável quando se manifesta em um evento. Um defeito que nunca se manifesta continua existindo.


---

[← Rede de ontologias](README.md)

