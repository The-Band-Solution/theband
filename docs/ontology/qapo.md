<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# QAPO — Quality Assurance Process Ontology

> Atividades, artefatos e stakeholders do processo de garantia da qualidade, avaliando a aderência de processos e produtos aos requisitos aplicáveis.

| | |
|---|---|
| **Id** | `qapo` |
| **Versão** | 1.0.0 |
| **Camada** | Domínio |
| **Rede** | SEON |
| **Namespace** | `the_band.ontology.seon.qapo` |
| **Depende de** | [ufo](ufo.md), [spo](spo.md) |
| **Origem** | Tese, Seção 2.2.2.4, Figura 20 |

## Módulos

- **[Quality Assurance Process](#quality-assurance-process)** — Uma não conformidade é o registro de desvio em relação a um requisito aplicável. Não é automaticamente um defeito: transformar code smell em defeito é decisão de engenharia, e deve ser explícita.
- **[Evaluation Participation](#evaluation-participation)** — Quem executou uma avaliação de artefato, e qual artefato foi avaliado — as duas relações que a QAPO publicada deixa implícitas e que o rastreio de revisão atravessa. Extensão do projeto The Band, não da QAPO publicada.
- **[Evaluation Verdict](#evaluation-verdict)** — A posição que o avaliador tomou sobre o artefato, e o estado de ciclo de vida da avaliação. Existe para que a plataforma tenha vocabulário próprio de revisão — sem ele, toda medida dependeria do enum de um forjador específico. Extensão do projeto The Band, não da QAPO publicada.

---

## Quality Assurance Process

<a id="quality-assurance-process"></a>

Uma não conformidade é o registro de desvio em relação a um requisito aplicável. Não é automaticamente um defeito: transformar code smell em defeito é decisão de engenharia, e deve ser explícita.

*Fonte: Tese, Seção 2.2.2.4, Figura 20*

### Conceitos

#### `qapo.quality_assurance_process` — Quality Assurance Process

*Processo de Garantia da Qualidade*

Processo executado específico que avalia e assegura a aderência dos processos executados e artefatos produzidos aos requisitos aplicáveis.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_process`</sub>

#### `qapo.adherence_evaluation` — Adherence Evaluation

*Avaliação de Aderência*

Atividade que avalia objetivamente a aderência de processos e produtos aos requisitos aplicáveis, registrando as questões identificadas.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_composite_activity`</sub>

#### `qapo.artifact_evaluation` — Artifact Evaluation

*Avaliação de Artefato*

Atividade que avalia objetivamente a aderência de produtos e entregáveis aos requisitos aplicáveis.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity`</sub>

#### `qapo.evaluated_artifact` — Evaluated Artifact

*Artefato Avaliado*

Papel assumido por um artefato quando é alvo de uma avaliação de artefato.

<sub>categoria UFO: `role` · papel de `spo.artifact`</sub>

#### `qapo.quality_criterion` — Quality Criterion

*Critério de Qualidade*

Critério aplicável usado para avaliar a aderência de um artefato ou processo.

<sub>categoria UFO: `normative_description`</sub>

Exemplos: *uma função não pode ter mais de 100 linhas de código*

#### `qapo.noncompliance_identification` — Noncompliance Identification

*Identificação de Não Conformidade*

Atividade que registra as não conformidades identificadas em processos e artefatos.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity`</sub>

#### `qapo.noncompliance_register` — Noncompliance Register

*Registro de Não Conformidade*

Item de informação que descreve uma não conformidade — falha ou recusa em atender a um requisito aplicável — em um processo ou artefato, com as informações necessárias para resolvê-la.

<sub>categoria UFO: `social_object` · especializa `spo.information_item`</sub>

Exemplos: *uma atividade negligenciada em um processo*; *um documento especificado incorretamente*

#### `qapo.evaluation_report` — Evaluation Report

*Relatório de Avaliação*

Documento que descreve os resultados da avaliação e as questões identificadas.

<sub>categoria UFO: `social_object` · especializa `spo.document`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
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

Quem executou uma avaliação de artefato, e qual artefato foi avaliado — as duas relações que a QAPO publicada deixa implícitas e que o rastreio de revisão atravessa. Extensão do projeto The Band, não da QAPO publicada.

*Fonte: Issue #440; lacuna declarada em github.pull_request_review.to.qapo.artifact_evaluation*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `performed` | `spo.project_stakeholder` | `qapo.artifact_evaluation` | one → many | participation |
| `evaluates` | `qapo.artifact_evaluation` | `qapo.evaluated_artifact` | many → one | association |
| `identified` | `qapo.artifact_evaluation` | `qapo.noncompliance_identification` | one → many | causation |



---

## Evaluation Verdict

<a id="evaluation-verdict"></a>

A posição que o avaliador tomou sobre o artefato, e o estado de ciclo de vida da avaliação. Existe para que a plataforma tenha vocabulário próprio de revisão — sem ele, toda medida dependeria do enum de um forjador específico. Extensão do projeto The Band, não da QAPO publicada.

*Fonte: Decisão da pessoa mantenedora em 2026-08-27: mapear o estado para a ontologia, para ser universal*

### Conceitos

#### `qapo.evaluation_verdict` — Evaluation Verdict

*Veredito da Avaliação*

A posição que o avaliador assume sobre o artefato avaliado. É proposição, e não medida: descreve o que aquela pessoa afirmou, e não o estado do artefato.

<sub>categoria UFO: `social_object` · especializa `spo.information_item`</sub>

Exemplos: *endossa*; *objeta*; *abstém*

#### `qapo.endorsing_verdict` — Endorsing Verdict

*Veredito de Endosso*

O avaliador considera o artefato apto a seguir. NÃO afirma ausência de não conformidade: endossar é não bloquear, e a ressalva registrada continua registrada.

<sub>categoria UFO: `social_object` · especializa `qapo.evaluation_verdict`</sub>

#### `qapo.objecting_verdict` — Objecting Verdict

*Veredito de Objeção*

O avaliador identifica não conformidade que deve ser resolvida antes de o artefato seguir. É a única posição que implica `qapo.noncompliance_identification`.

<sub>categoria UFO: `social_object` · especializa `qapo.evaluation_verdict`</sub>

#### `qapo.abstaining_verdict` — Abstaining Verdict

*Veredito de Abstenção*

O avaliador participou da avaliação e não tomou posição. É diferente de não ter avaliado: a avaliação aconteceu, e contá-la como ausência apagaria o trabalho de quem leu o artefato e comentou.

<sub>categoria UFO: `social_object` · especializa `qapo.evaluation_verdict`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `reached` | `qapo.artifact_evaluation` | `qapo.evaluation_verdict` | one → one | association |



---

## Perguntas de competência

Perguntas que esta ontologia precisa saber responder. São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.

| # | Pergunta | Conceitos envolvidos |
|---|---|---|
| `CQ01` | Quais pessoas avaliaram um artefato criado em atividade de que participou outra pessoa, numa janela de tempo? (No The Band: quem revisou a solicitação de mudança submetida por outra pessoa.) | `spo.project_person_stakeholder`, `qapo.artifact_evaluation`, `qapo.evaluated_artifact`, `spo.artifact`, … |
| `CQ02` | Quantos artefatos distintos criados em atividade de uma pessoa foram avaliados por outra, numa janela de tempo? | `spo.project_person_stakeholder`, `qapo.artifact_evaluation`, `spo.artifact` |
| `CQ03` | Quais avaliações de artefato não ligam duas pessoas distintas — a que avaliou e a que participou da criação do artefato —, e por qual motivo? | `spo.project_person_stakeholder`, `qapo.artifact_evaluation`, `spo.artifact` |
| `CQ04` | Entre as pessoas que avaliaram, ou participaram da criação de artefato avaliado, numa janela, quais conjuntos não estão ligados por avaliação em sentido nenhum? | `spo.project_person_stakeholder`, `qapo.artifact_evaluation`, `spo.artifact` |

- **CQ01** — É a pergunta que define a aresta. Se a rede de ontologias não a responde, a aresta revisor → autor é invenção do código, e não leitura da base. A resposta exige os dois lados: quem participou da avaliação e quem participou da atividade que CRIOU o artefato — a submissão, e não a integração, porque Pull Request não é merge (a integração é `cmpo.checkin`, que não cria a solicitação).
- **CQ02** — É o peso da aresta. Artefatos (solicitações) DISTINTOS, e não avaliações: várias rodadas da mesma pessoa sobre o mesmo artefato são uma contribuição só. Sem esta pergunta, o peso vira contagem de eventos e infla quem comenta muito em poucas solicitações.
- **CQ03** — As exclusões precisam ser respondíveis pela base, e não só pelo cálculo: auto-revisão (a mesma pessoa nas duas pontas), conta de máquina, e conta sem pessoa ligada. Sem a pergunta, uma revisão excluída some — e a soma das arestas deixa de fechar com o total de revisões, que é o que permite conferir a leitura contra a origem (SC-001).
- **CQ04** — É a pergunta dos grupos (US3). Declara a população — só pessoas com ao menos uma aresta — e o critério — sentido nenhum, isto é, componente fraco. Pessoa sem aresta não é grupo de tamanho 1, e sem essa restrição todo grupo de 1 seria uma pessoa apontada (seguranca.md R2 item 4).


---

[← Rede de ontologias](README.md)

