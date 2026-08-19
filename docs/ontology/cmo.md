<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# CMO — Communication Ontology

> Conceitualização da comunicação sobre artefatos do projeto: o ato de comentar, o comentário que ele publica, a discussão que os comentários de um artefato compõem, e a participação dos agentes nela. Existe para responder o que execução nenhuma responde: quem destrava, quem revisa, quem responde — o trabalho que acontece na conversa e não vira tarefa.

| | |
|---|---|
| **Id** | `cmo` |
| **Versão** | 0.1.0 |
| **Camada** | Domínio |
| **Rede** | Continuum |
| **Namespace** | `the_band.ontology.continuum.cmo` |
| **Depende de** | [ufo](ufo.md), [eo](eo.md), [spo](spo.md) |
| **Origem** | Issues #318 (a lacuna, 2026-08-14) e #400 (a decisão, 2026-08-17) |

> **Nota.** Extensão do continuum da tese, não parte dela: a tese cobre execução (SPO/SRO) e integração/entrega contínuas (CIRO/CDRO); comunicação sobre artefato é lacuna documentada. Verbos no passado, como em todo o continuum: descreve-se o que ocorreu, nunca intenção.


## Módulos

- **[Artifact Communication](#artifact-communication)** — O ato de comentar um artefato do projeto, o comentário publicado, a discussão que os comentários compõem e a participação dos agentes nela. A cadeia é deliberada: participação é relação entre agente e EVENTO — artefato não tem participante. É o ato, e não o texto, que dá lugar ontológico para "quem participou".

---

## Artifact Communication

<a id="artifact-communication"></a>

O ato de comentar um artefato do projeto, o comentário publicado, a discussão que os comentários compõem e a participação dos agentes nela. A cadeia é deliberada: participação é relação entre agente e EVENTO — artefato não tem participante. É o ato, e não o texto, que dá lugar ontológico para "quem participou".

*Fonte: Issue #400; a lacuna está documentada na #318*

### Conceitos

#### `cmo.commenting_act` — Commenting Act

*Ato de Comentar*

Ato comunicativo de um agente sobre um artefato do projeto, que publica um comentário no fio de discussão desse artefato. É evento: acontece num instante, tem autor, e não muda depois de ocorrido.

<sub>categoria UFO: `action`</sub>

Exemplos: *responder uma dúvida numa issue*; *registrar um bloqueio no fio*

#### `cmo.comment` — Comment

*Comentário*

Manifestação escrita, unicamente identificada, publicada por um ato de comentar no fio de discussão de um artefato. NÃO é artefato do processo (spo.artifact): não é produzido para ser entregue nem consumido por atividade — é comunicação sobre o artefato. A distinção é a razão de este módulo existir (#318).

<sub>categoria UFO: `social_object`</sub>

Exemplos: *'isso quebrou no staging?'*; *'bloqueado pela credencial do tenant'*

#### `cmo.discussion` — Discussion

*Discussão*

O coletivo dos comentários publicados sobre um mesmo artefato. Existe a partir do primeiro comentário; artefato sem comentário não tem discussão — e "sem discussão" é fato distinto de "discussão não coletada", como sempre.

<sub>categoria UFO: `collective`</sub>

#### `cmo.discussion_participation` — Discussion Participation

*Participação na Discussão*

Relator que conecta um agente à discussão de um artefato, fundado nos atos de comentar dele ali. Nunca um booleano: a participação desce até os comentários que a evidenciam — quantos, de quando a quando. É o conceito que permite afirmar colaboração sem fingir que ela é tarefa executada.

<sub>categoria UFO: `relator`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
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

## Perguntas de competência

Perguntas que esta ontologia precisa saber responder. São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.

| # | Pergunta | Conceitos envolvidos |
|---|---|---|
| `CQ01` | Quem participou da discussão de um artefato, quantas vezes, de quando a quando? | `cmo.discussion_participation`, `cmo.discussion`, `cmo.commenting_act` |
| `CQ02` | De quais discussões um agente participou num período — inclusive as de artefatos que nunca lhe foram designados? | `cmo.discussion_participation`, `cmo.commenting_act` |
| `CQ03` | Um artefato parado tem discussão recente? (Parado em silêncio e parado com conversa ativa pedem ações opostas.) | `cmo.discussion`, `cmo.commenting_act` |
| `CQ04` | Quando ocorreu o último ato de comentar sobre um artefato, e de quem foi? | `cmo.commenting_act` |



---

[← Rede de ontologias](README.md)

