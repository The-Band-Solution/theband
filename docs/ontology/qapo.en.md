<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# QAPO — Quality Assurance Process Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **30 of 34** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Atividades, artefatos e stakeholders do processo de garantia da qualidade, avaliando a aderência de processos e produtos aos requisitos aplicáveis.

| | |
|---|---|
| **Id** | `qapo` |
| **Version** | 1.0.0 |
| **Layer** | Domain |
| **Network** | SEON |
| **Namespace** | `the_band.ontology.seon.qapo` |
| **Depends on** | [ufo](ufo.md), [spo](spo.md) |
| **Origin** | `pt-BR` Tese, Seção 2.2.2.4, Figura 20 |

## Modules

- **[Quality Assurance Process](#quality-assurance-process)** — `pt-BR` Uma não conformidade é o registro de desvio em relação a um requisito aplicável. Não é automaticamente um defeito: transformar code smell em defeito é decisão de engenharia, e deve ser explícita.
- **[Evaluation Participation](#evaluation-participation)** — `pt-BR` Quem executou uma avaliação de artefato, e qual artefato foi avaliado — as duas relações que a QAPO publicada deixa implícitas e que o rastreio de revisão atravessa. Extensão do projeto The Band, não da QAPO publicada.
- **[Evaluation Verdict](#evaluation-verdict)** — `pt-BR` A posição que o avaliador tomou sobre o artefato, e o estado de ciclo de vida da avaliação. Existe para que a plataforma tenha vocabulário próprio de revisão — sem ele, toda medida dependeria do enum de um forjador específico. Extensão do projeto The Band, não da QAPO publicada.

---

## Quality Assurance Process

<a id="quality-assurance-process"></a>

`pt-BR` Uma não conformidade é o registro de desvio em relação a um requisito aplicável. Não é automaticamente um defeito: transformar code smell em defeito é decisão de engenharia, e deve ser explícita.

*Source: `pt-BR` Tese, Seção 2.2.2.4, Figura 20*

### Concepts

#### `qapo.quality_assurance_process` — Quality Assurance Process

*pt-BR: Processo de Garantia da Qualidade*

`pt-BR` Processo executado específico que avalia e assegura a aderência dos processos executados e artefatos produzidos aos requisitos aplicáveis.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_process`</sub>

#### `qapo.adherence_evaluation` — Adherence Evaluation

*pt-BR: Avaliação de Aderência*

`pt-BR` Atividade que avalia objetivamente a aderência de processos e produtos aos requisitos aplicáveis, registrando as questões identificadas.

<sub>UFO category: `complex_action` · specializes `spo.performed_composite_activity`</sub>

#### `qapo.artifact_evaluation` — Artifact Evaluation

*pt-BR: Avaliação de Artefato*

`pt-BR` Atividade que avalia objetivamente a aderência de produtos e entregáveis aos requisitos aplicáveis.

<sub>UFO category: `action` · specializes `spo.performed_project_activity`</sub>

#### `qapo.evaluated_artifact` — Evaluated Artifact

*pt-BR: Artefato Avaliado*

`pt-BR` Papel assumido por um artefato quando é alvo de uma avaliação de artefato.

<sub>UFO category: `role` · role of `spo.artifact`</sub>

#### `qapo.quality_criterion` — Quality Criterion

*pt-BR: Critério de Qualidade*

`pt-BR` Critério aplicável usado para avaliar a aderência de um artefato ou processo.

<sub>UFO category: `normative_description`</sub>

Examples: `pt-BR` *uma função não pode ter mais de 100 linhas de código*

#### `qapo.noncompliance_identification` — Noncompliance Identification

*pt-BR: Identificação de Não Conformidade*

`pt-BR` Atividade que registra as não conformidades identificadas em processos e artefatos.

<sub>UFO category: `action` · specializes `spo.performed_project_activity`</sub>

#### `qapo.noncompliance_register` — Noncompliance Register

*pt-BR: Registro de Não Conformidade*

`pt-BR` Item de informação que descreve uma não conformidade — falha ou recusa em atender a um requisito aplicável — em um processo ou artefato, com as informações necessárias para resolvê-la.

<sub>UFO category: `social_object` · specializes `spo.information_item`</sub>

Examples: `pt-BR` *uma atividade negligenciada em um processo*; *um documento especificado incorretamente*

#### `qapo.evaluation_report` — Evaluation Report

*pt-BR: Relatório de Avaliação*

`pt-BR` Documento que descreve os resultados da avaliação e as questões identificadas.

<sub>UFO category: `social_object` · specializes `spo.document`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `composed of` | `qapo.quality_assurance_process` | `qapo.adherence_evaluation` | one → one_or_many | part_whole |
| `composed of` | `qapo.adherence_evaluation` | `qapo.artifact_evaluation` | one → many | part_whole |
| `composed of` | `qapo.adherence_evaluation` | `qapo.noncompliance_identification` | one → many | part_whole |
| `creates` | `qapo.adherence_evaluation` | `qapo.evaluation_report` | one → one | association |
| `registers` | `qapo.noncompliance_identification` | `qapo.noncompliance_register` | one → one_or_many | association |
| `uses` | `qapo.artifact_evaluation` | `qapo.quality_criterion` | many → one_or_many | association |



---

## Evaluation Participation

<a id="evaluation-participation"></a>

`pt-BR` Quem executou uma avaliação de artefato, e qual artefato foi avaliado — as duas relações que a QAPO publicada deixa implícitas e que o rastreio de revisão atravessa. Extensão do projeto The Band, não da QAPO publicada.

*Source: `pt-BR` Issue #440; lacuna declarada em github.pull_request_review.to.qapo.artifact_evaluation*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `performed` | `spo.project_stakeholder` | `qapo.artifact_evaluation` | one → many | participation |
| `evaluates` | `qapo.artifact_evaluation` | `qapo.evaluated_artifact` | many → one | association |
| `identified` | `qapo.artifact_evaluation` | `qapo.noncompliance_identification` | one → many | causation |



---

## Evaluation Verdict

<a id="evaluation-verdict"></a>

`pt-BR` A posição que o avaliador tomou sobre o artefato, e o estado de ciclo de vida da avaliação. Existe para que a plataforma tenha vocabulário próprio de revisão — sem ele, toda medida dependeria do enum de um forjador específico. Extensão do projeto The Band, não da QAPO publicada.

*Source: `pt-BR` Decisão da pessoa mantenedora em 2026-08-27: mapear o estado para a ontologia, para ser universal*

### Concepts

#### `qapo.evaluation_verdict` — Evaluation Verdict

*pt-BR: Veredito da Avaliação*

`pt-BR` A posição que o avaliador assume sobre o artefato avaliado. É proposição, e não medida: descreve o que aquela pessoa afirmou, e não o estado do artefato.

<sub>UFO category: `social_object` · specializes `spo.information_item`</sub>

Examples: `pt-BR` *endossa*; *objeta*; *abstém*

#### `qapo.endorsing_verdict` — Endorsing Verdict

*pt-BR: Veredito de Endosso*

`pt-BR` O avaliador considera o artefato apto a seguir. NÃO afirma ausência de não conformidade: endossar é não bloquear, e a ressalva registrada continua registrada.

<sub>UFO category: `social_object` · specializes `qapo.evaluation_verdict`</sub>

#### `qapo.objecting_verdict` — Objecting Verdict

*pt-BR: Veredito de Objeção*

`pt-BR` O avaliador identifica não conformidade que deve ser resolvida antes de o artefato seguir. É a única posição que implica `qapo.noncompliance_identification`.

<sub>UFO category: `social_object` · specializes `qapo.evaluation_verdict`</sub>

#### `qapo.abstaining_verdict` — Abstaining Verdict

*pt-BR: Veredito de Abstenção*

`pt-BR` O avaliador participou da avaliação e não tomou posição. É diferente de não ter avaliado: a avaliação aconteceu, e contá-la como ausência apagaria o trabalho de quem leu o artefato e comentou.

<sub>UFO category: `social_object` · specializes `qapo.evaluation_verdict`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `reached` | `qapo.artifact_evaluation` | `qapo.evaluation_verdict` | one → one | association |



---

## Competency questions

Questions this ontology must be able to answer. They are the model's functional requirements, checked by `mix knowledge.test`.

| # | Question | Concepts involved |
|---|---|---|
| `CQ01` | Which people evaluated an artifact created by an activity another person took part in, within a time window? (In The Band: who reviewed a change request submitted by another person.) | `spo.project_person_stakeholder`, `qapo.artifact_evaluation`, `qapo.evaluated_artifact`, `spo.artifact`, … |
| `CQ02` | How many distinct artifacts created by an activity of one person were evaluated by another, within a time window? | `spo.project_person_stakeholder`, `qapo.artifact_evaluation`, `spo.artifact` |
| `CQ03` | Which artifact evaluations do not link two distinct people — the evaluator and a participant in the artifact's creation —, and for what reason? | `spo.project_person_stakeholder`, `qapo.artifact_evaluation`, `spo.artifact` |
| `CQ04` | Among the people who evaluated, or took part in creating an evaluated artifact, in a window, which sets are not linked by evaluation in either direction? | `spo.project_person_stakeholder`, `qapo.artifact_evaluation`, `spo.artifact` |

- **CQ01** — `pt-BR` É a pergunta que define a aresta. Se a rede de ontologias não a responde, a aresta revisor → autor é invenção do código, e não leitura da base. A resposta exige os dois lados: quem participou da avaliação e quem participou da atividade que CRIOU o artefato — a submissão, e não a integração, porque Pull Request não é merge (a integração é `cmpo.checkin`, que não cria a solicitação).
- **CQ02** — `pt-BR` É o peso da aresta. Artefatos (solicitações) DISTINTOS, e não avaliações: várias rodadas da mesma pessoa sobre o mesmo artefato são uma contribuição só. Sem esta pergunta, o peso vira contagem de eventos e infla quem comenta muito em poucas solicitações.
- **CQ03** — `pt-BR` As exclusões precisam ser respondíveis pela base, e não só pelo cálculo: auto-revisão (a mesma pessoa nas duas pontas), conta de máquina, e conta sem pessoa ligada. Sem a pergunta, uma revisão excluída some — e a soma das arestas deixa de fechar com o total de revisões, que é o que permite conferir a leitura contra a origem (SC-001).
- **CQ04** — `pt-BR` É a pergunta dos grupos (US3). Declara a população — só pessoas com ao menos uma aresta — e o critério — sentido nenhum, isto é, componente fraco. Pessoa sem aresta não é grupo de tamanho 1, e sem essa restrição todo grupo de 1 seria uma pessoa apontada (seguranca.md R2 item 4).


---

[← Ontology network](README.md)

