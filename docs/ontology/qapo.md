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

[← Rede de ontologias](README.md)

