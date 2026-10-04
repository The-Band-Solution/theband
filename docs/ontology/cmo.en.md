<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# CMO — Communication Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **12 of 16** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Conceitualização da comunicação sobre artefatos do projeto: o ato de comentar, o comentário que ele publica, a discussão que os comentários de um artefato compõem, e a participação dos agentes nela. Existe para responder o que execução nenhuma responde: quem destrava, quem revisa, quem responde — o trabalho que acontece na conversa e não vira tarefa.

| | |
|---|---|
| **Id** | `cmo` |
| **Version** | 0.1.0 |
| **Layer** | Domain |
| **Network** | Continuum |
| **Namespace** | `the_band.ontology.continuum.cmo` |
| **Depends on** | [ufo](ufo.md), [eo](eo.md), [spo](spo.md) |
| **Origin** | `pt-BR` Issues #318 (a lacuna, 2026-08-14) e #400 (a decisão, 2026-08-17) |

> **Note.** `pt-BR` Extensão do continuum da tese, não parte dela: a tese cobre execução (SPO/SRO) e integração/entrega contínuas (CIRO/CDRO); comunicação sobre artefato é lacuna documentada. Verbos no passado, como em todo o continuum: descreve-se o que ocorreu, nunca intenção.


## Modules

- **[Artifact Communication](#artifact-communication)** — `pt-BR` O ato de comentar um artefato do projeto, o comentário publicado, a discussão que os comentários compõem e a participação dos agentes nela. A cadeia é deliberada: participação é relação entre agente e EVENTO — artefato não tem participante. É o ato, e não o texto, que dá lugar ontológico para "quem participou".

---

## Artifact Communication

<a id="artifact-communication"></a>

`pt-BR` O ato de comentar um artefato do projeto, o comentário publicado, a discussão que os comentários compõem e a participação dos agentes nela. A cadeia é deliberada: participação é relação entre agente e EVENTO — artefato não tem participante. É o ato, e não o texto, que dá lugar ontológico para "quem participou".

*Source: `pt-BR` Issue #400; a lacuna está documentada na #318*

### Concepts

#### `cmo.commenting_act` — Commenting Act

*pt-BR: Ato de Comentar*

`pt-BR` Ato comunicativo de um agente sobre um artefato do projeto, que publica um comentário no fio de discussão desse artefato. É evento: acontece num instante, tem autor, e não muda depois de ocorrido.

<sub>UFO category: `action`</sub>

Examples: `pt-BR` *responder uma dúvida numa issue*; *registrar um bloqueio no fio*

#### `cmo.comment` — Comment

*pt-BR: Comentário*

`pt-BR` Manifestação escrita, unicamente identificada, publicada por um ato de comentar no fio de discussão de um artefato. NÃO é artefato do processo (spo.artifact): não é produzido para ser entregue nem consumido por atividade — é comunicação sobre o artefato. A distinção é a razão de este módulo existir (#318).

<sub>UFO category: `social_object`</sub>

Examples: `pt-BR` *'isso quebrou no staging?'*; *'bloqueado pela credencial do tenant'*

#### `cmo.discussion` — Discussion

*pt-BR: Discussão*

`pt-BR` O coletivo dos comentários publicados sobre um mesmo artefato. Existe a partir do primeiro comentário; artefato sem comentário não tem discussão — e "sem discussão" é fato distinto de "discussão não coletada", como sempre.

<sub>UFO category: `collective`</sub>

#### `cmo.discussion_participation` — Discussion Participation

*pt-BR: Participação na Discussão*

`pt-BR` Relator que conecta um agente à discussão de um artefato, fundado nos atos de comentar dele ali. Nunca um booleano: a participação desce até os comentários que a evidenciam — quantos, de quando a quando. É o conceito que permite afirmar colaboração sem fingir que ela é tarefa executada.

<sub>UFO category: `relator`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `performed` | `ufo.agent` | `cmo.commenting_act` | one → many | participation |
| `published` | `cmo.commenting_act` | `cmo.comment` | one → one | causation |
| `commented on` | `cmo.commenting_act` | `spo.artifact` | many → one | association |
| `belonged to` | `cmo.comment` | `cmo.discussion` | many → one | part_whole |
| `was about` | `cmo.discussion` | `spo.artifact` | one → one | association |
| `mediated` | `cmo.discussion_participation` | `ufo.agent` | many → one | materialization |
| `mediated` | `cmo.discussion_participation` | `cmo.discussion` | many → one | materialization |
| `was derived from` | `cmo.discussion_participation` | `cmo.commenting_act` | one → one_or_many | derivation |



---

## Competency questions

Questions this ontology must be able to answer. They are the model's functional requirements, checked by `mix knowledge.test`.

| # | Question | Concepts involved |
|---|---|---|
| `CQ01` | Who participated in an artifact's discussion, how many times, from when to when? | `cmo.discussion_participation`, `cmo.discussion`, `cmo.commenting_act` |
| `CQ02` | Which discussions did an agent take part in over a period — including on artifacts never assigned to them? | `cmo.discussion_participation`, `cmo.commenting_act` |
| `CQ03` | Does a stalled artifact have recent discussion? (Silently stalled and stalled-but-debated demand opposite actions.) | `cmo.discussion`, `cmo.commenting_act` |
| `CQ04` | When did the last commenting act on an artifact occur, and whose was it? | `cmo.commenting_act` |



---

[← Ontology network](README.md)

