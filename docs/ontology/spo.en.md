<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# SPO — Software Process Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **46 of 46** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Conceitualização comum sobre processos de software: projetos, stakeholders, processos e atividades planejados e executados, artefatos, recursos e participação de stakeholders.

| | |
|---|---|
| **Id** | `spo` |
| **Version** | 1.0.0 |
| **Layer** | Core |
| **Network** | SEON |
| **Namespace** | `the_band.ontology.seon.spo` |
| **Depends on** | [ufo](ufo.md), [eo](eo.md) |
| **Origin** | `pt-BR` Tese, Seção 2.2.2.1 (Figuras 16 e 17) |

## Modules

- **[Projects and Stakeholders](#projects-and-stakeholders)** — the module's concepts and relations.
- **[Processes and Activities](#processes-and-activities)** — `pt-BR` A distinção central da SPO: processo pretendido (intended) é uma intenção de executar certos tipos de ação; processo executado (performed) é uma ocorrência que pode não corresponder à intenção original. Confundi-los inviabiliza qualquer análise de aderência entre plano e execução.
- **[Artifacts and Resources](#artifacts-and-resources)** — the module's concepts and relations.
- **[Activity Start Criterion](#activity-start-criterion)** — `pt-BR` Qual evento observado marca o início de um trabalho é **convenção social**, e não fato que alguma origem forneça. Organizações diferentes reconhecem eventos diferentes como início, e nenhuma está errada.
Este módulo dá nome à declaração. Sem ele, a plataforma teria de escolher — e a `FR-007` da feature 022 proíbe exatamente isso, deixando `flow.throughput`, `flow.wip.count` e o cycle time por pessoa sem um instante de início.

---

## Projects and Stakeholders

<a id="projects-and-stakeholders"></a>

*Source: `pt-BR` Tese, Seção 2.2.2.1, Figura 16*

### Concepts

#### `spo.project` — Project

*pt-BR: Projeto*

`pt-BR` Empreendimento temporário com objetivo definido, executado por uma organização.

<sub>UFO category: `social_object`</sub>

| Attribute | Type | Required |
|---|---|---|
| `name` | string | yes |
| `started_at` | datetime | no |
| `ended_at` | datetime | no |

#### `spo.software_project` — Software Project

*pt-BR: Projeto de Software*

`pt-BR` Projeto relacionado ao desenvolvimento ou manutenção de software.

<sub>UFO category: `social_object` · specializes `spo.project`</sub>

#### `spo.simple_project` — Simple Project

*pt-BR: Projeto Simples*

`pt-BR` Projeto que não é decomposto em outros projetos.

<sub>UFO category: `social_object` · specializes `spo.project`</sub>

Examples: `pt-BR` *o projeto de um módulo com dois repositórios e nenhum subprojeto*

#### `spo.complex_project` — Complex Project

*pt-BR: Projeto Complexo*

`pt-BR` Projeto composto de outros projetos. Como o projeto componente é ele próprio um projeto, um projeto complexo pode ser parte de outro: a decomposição é recursiva e não tem profundidade fixa. Ser complexo não é rótulo atribuído, e sim consequência de ter partes — um projeto sem partes é simples, ainda que alguém o tenha cadastrado pensando em decompô-lo.

<sub>UFO category: `social_object` · specializes `spo.project`</sub>

#### `spo.project_stakeholder` — Project Stakeholder

*pt-BR: Parte Interessada do Projeto*

`pt-BR` Agente interessado em um projeto de software. A identidade vem do agente, que pode ser uma pessoa ou uma equipe — por isso a fundamentação é ufo.agent, e não eo.person: os subtipos é que fixam qual dos dois.

<sub>UFO category: `role` · role of `ufo.agent`</sub>

#### `spo.project_person_stakeholder` — Project Person Stakeholder

*pt-BR: Parte Interessada Pessoa*

`pt-BR` Pessoa interessada em um projeto de software.

<sub>UFO category: `role` · specializes `spo.project_stakeholder` · role of `eo.person`</sub>

Examples: `pt-BR` *o gerente do projeto*

#### `spo.project_team_stakeholder` — Project Team Stakeholder

*pt-BR: Parte Interessada Equipe*

`pt-BR` Equipe interessada em um projeto de software.

<sub>UFO category: `role` · specializes `spo.project_stakeholder` · role of `eo.team`</sub>

Examples: `pt-BR` *a equipe de desenvolvimento do projeto*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `was composed of` | `spo.complex_project` | `spo.project` | one → one_or_many | part_whole |
| `is interested in` | `spo.project_stakeholder` | `spo.software_project` | many → many | association |

- **`spo.complex_project_composed_of_project`** — `pt-BR` O destino é spo.project, e não spo.simple_project — e um projeto complexo é um projeto. Logo a relação é recursiva: um projeto complexo pode ter outro complexo como parte, em qualquer profundidade. Restringir o destino a projetos simples fixaria a decomposição em dois níveis, e Conecta Fapes → Backend → Pagamentos deixaria de ser expressável.
A cardinalidade da origem é **one**, e não many: um projeto tem no máximo um pai vigente. A hierarquia é árvore, e é isso que faz cada issue contar uma vez no ancestral. Trocar de pai é permitido — encerra o vínculo atual e cria outro —, o que a cardinalidade proíbe é ter dois ao mesmo tempo.


---

## Processes and Activities

<a id="processes-and-activities"></a>

`pt-BR` A distinção central da SPO: processo pretendido (intended) é uma intenção de executar certos tipos de ação; processo executado (performed) é uma ocorrência que pode não corresponder à intenção original. Confundi-los inviabiliza qualquer análise de aderência entre plano e execução.

*Source: `pt-BR` Tese, Seção 2.2.2.1, Figura 16*

### Concepts

#### `spo.intended_project_process` — Intended Project Process

*pt-BR: Processo Pretendido do Projeto*

`pt-BR` Processo planejado para ser executado no projeto — uma intenção, não uma ocorrência.

<sub>UFO category: `intention`</sub>

#### `spo.general_intended_project_process` — General Intended Project Process

*pt-BR: Processo Pretendido Geral*

`pt-BR` Processo pretendido que se refere ao processo inteiro definido para um projeto.

<sub>UFO category: `intention` · specializes `spo.intended_project_process`</sub>

#### `spo.specific_intended_project_process` — Specific Intended Project Process

*pt-BR: Processo Pretendido Específico*

`pt-BR` Processo pretendido definido com um propósito específico no projeto.

<sub>UFO category: `intention` · specializes `spo.intended_project_process`</sub>

Examples: `pt-BR` *o processo de Engenharia de Requisitos definido para um projeto*

#### `spo.intended_project_activity` — Intended Project Activity

*pt-BR: Atividade Pretendida do Projeto*

`pt-BR` Atividade planejada que compõe um processo pretendido específico.

<sub>UFO category: `intention`</sub>

#### `spo.performed_project_process` — Performed Project Process

*pt-BR: Processo Executado do Projeto*

`pt-BR` Processo como efetivamente executado no projeto. É uma ação complexa ("ocorrência") que pode não corresponder à intenção original.

<sub>UFO category: `complex_action`</sub>

| Attribute | Type | Required |
|---|---|---|
| `occurred_at` | datetime | yes |
| `start_date` | datetime | no |
| `end_date` | datetime | no |

#### `spo.general_performed_project_process` — General Performed Project Process

*pt-BR: Processo Executado Geral*

`pt-BR` Processo executado que corresponde ao processo global do projeto.

<sub>UFO category: `complex_action` · specializes `spo.performed_project_process`</sub>

#### `spo.specific_performed_project_process` — Specific Performed Project Process

*pt-BR: Processo Executado Específico*

`pt-BR` Processo executado com propósito específico, composto de atividades executadas.

<sub>UFO category: `complex_action` · specializes `spo.performed_project_process`</sub>

#### `spo.specific_performed_project_simple_process` — Specific Performed Project Simple Process

*pt-BR: Processo Executado Específico Simples*

`pt-BR` Processo executado específico que contém apenas atividades.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_process`</sub>

#### `spo.specific_performed_project_composite_process` — Specific Performed Project Composite Process

*pt-BR: Processo Executado Específico Composto*

`pt-BR` Processo executado específico que contém dois ou mais processos executados específicos.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_process`</sub>

#### `spo.performed_project_activity` — Performed Project Activity

*pt-BR: Atividade Executada do Projeto*

`pt-BR` Atividade efetivamente executada, compondo um processo executado específico.
É o kind das ocorrências de atividade em toda a rede: commits, execuções de teste, cerimônias, implantações e inspeções são todos especializações deste conceito, e compartilham o mesmo princípio de identidade. Por isso o kind mora em SPO, e as ontologias de domínio o especializam em vez de definir cada uma o seu.

<sub>UFO category: `action`</sub>

| Attribute | Type | Required |
|---|---|---|
| `occurred_at` | datetime | yes |
| `start_date` | datetime | no |
| `end_date` | datetime | no |

#### `spo.performed_simple_activity` — Performed Simple Activity

*pt-BR: Atividade Executada Simples*

`pt-BR` Atividade executada que não se decompõe em outras atividades.

<sub>UFO category: `action` · specializes `spo.performed_project_activity`</sub>

#### `spo.performed_composite_activity` — Performed Composite Activity

*pt-BR: Atividade Executada Composta*

`pt-BR` Atividade executada composta de outras atividades executadas.

<sub>UFO category: `complex_action` · specializes `spo.performed_project_activity`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `causes` | `spo.intended_project_activity` | `spo.performed_project_activity` | one → many | causation |
| `composed of` | `spo.specific_performed_project_process` | `spo.performed_project_activity` | one → one_or_many | part_whole |
| `depends on` | `spo.performed_project_activity` | `spo.performed_project_activity` | many → many | dependency |
| `is in charge of` | `spo.project_stakeholder` | `spo.performed_project_activity` | many → many | participation |
| `participates in` | `spo.project_stakeholder` | `spo.performed_project_activity` | many → many | participation |
| `performed in` | `spo.performed_project_process` | `spo.software_project` | many → one | association |

- **`spo.intended_causes_performed`** — `pt-BR` A intenção de executar uma atividade pode resultar na execução dela. Nem toda atividade pretendida é executada, e nem toda executada foi pretendida.
- **`spo.activity_depends_on_activity`** — `pt-BR` Estabelece a ordem em que as atividades ocorreram.
- **`spo.is_in_charge_of`** — `pt-BR` O stakeholder foi responsável pela execução da atividade.
- **`spo.participates_in`** — `pt-BR` O stakeholder contribuiu com a execução da atividade, sem ser o responsável. Distinguir de "is in charge of" é o que permite medir carga real de trabalho.


---

## Artifacts and Resources

<a id="artifacts-and-resources"></a>

*Source: `pt-BR` Tese, Seção 2.2.2.1, Figuras 16 e 17*

### Concepts

#### `spo.artifact` — Artifact

*pt-BR: Artefato*

`pt-BR` Objeto criado, usado ou alterado por atividades executadas do processo.

<sub>UFO category: `object`</sub>

#### `spo.information_item` — Information Item

*pt-BR: Item de Informação*

`pt-BR` Informação relevante para uso humano no contexto do processo de software.

<sub>UFO category: `social_object` · specializes `spo.artifact`</sub>

Examples: `pt-BR` *um bug reportado*; *um requisito documentado*

#### `spo.document` — Document

*pt-BR: Documento*

`pt-BR` Informação escrita ou pictórica, unicamente identificada, relacionada ao processo de software, geralmente em formato predefinido. Um documento descreve artefatos; não é o artefato descrito.

<sub>UFO category: `social_object` · specializes `spo.information_item`</sub>

Examples: `pt-BR` *uma Especificação de Projeto*

#### `spo.resource` — Resource

*pt-BR: Recurso*

`pt-BR` Papel assumido por um artefato — produto de software ou equipamento de hardware — quando é usado por uma atividade do processo. As especializações que apontam para conceitos de SysSwO vivem em SysSwO, e não aqui, para preservar a direção de dependência (SysSwO depende de SPO, não o contrário).

<sub>UFO category: `role` · role of `spo.artifact`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `creates` | `spo.performed_project_activity` | `spo.artifact` | many → many | association |
| `uses` | `spo.performed_project_activity` | `spo.artifact` | many → many | association |
| `changes` | `spo.performed_project_activity` | `spo.artifact` | many → many | association |
| `describes` | `spo.document` | `spo.artifact` | many → many | association |
| `uses resource` | `spo.performed_project_activity` | `spo.resource` | many → many | association |



---

## Activity Start Criterion

<a id="activity-start-criterion"></a>

`pt-BR` Qual evento observado marca o início de um trabalho é **convenção social**, e não fato que alguma origem forneça. Organizações diferentes reconhecem eventos diferentes como início, e nenhuma está errada.
Este módulo dá nome à declaração. Sem ele, a plataforma teria de escolher — e a `FR-007` da feature 022 proíbe exatamente isso, deixando `flow.throughput`, `flow.wip.count` e o cycle time por pessoa sem um instante de início.

*Source: `pt-BR` Issue #370; decisão da pessoa mantenedora em 2026-08-24*

### Concepts

#### `spo.activity_start_criterion` — Activity Start Criterion

*pt-BR: Critério de Início de Atividade*

`pt-BR` O tipo de evento que uma organização declara como aquele que traz à tona a situação de um trabalho ter começado.
É objeto **social** porque a resposta não está no dado observado: o mesmo evento — mover um cartão, designar alguém, abrir a tarefa — significa "começou" numa organização e não significa noutra. A plataforma não escolhe; ela registra a escolha, com quem a fez e quando.
Sem critério declarado, o instante de início fica **nulo** — ausência nomeada, e nunca a data corrente, que afirmaria que o trabalho começou agora.

<sub>UFO category: `social_object`</sub>

Examples: `pt-BR` *a mudança de status no quadro conta como início, neste projeto*; *a designação conta como início, neste outro*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `recognises` | `spo.activity_start_criterion` | `ufo.event` | many → one | association |
| `declared for` | `spo.activity_start_criterion` | `spo.project` | one → one | association |
| `determines the start of` | `spo.activity_start_criterion` | `spo.performed_project_activity` | one → many | association |



---

[← Ontology network](README.md)

