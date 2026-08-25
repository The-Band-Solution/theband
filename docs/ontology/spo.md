<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# SPO — Software Process Ontology

> Conceitualização comum sobre processos de software: projetos, stakeholders, processos e atividades planejados e executados, artefatos, recursos e participação de stakeholders.

| | |
|---|---|
| **Id** | `spo` |
| **Versão** | 1.0.0 |
| **Camada** | Core |
| **Rede** | SEON |
| **Namespace** | `the_band.ontology.seon.spo` |
| **Depende de** | [ufo](ufo.md), [eo](eo.md) |
| **Origem** | Tese, Seção 2.2.2.1 (Figuras 16 e 17) |

## Módulos

- **[Projects and Stakeholders](#projects-and-stakeholders)** — conceitos e relações do módulo.
- **[Processes and Activities](#processes-and-activities)** — A distinção central da SPO: processo pretendido (intended) é uma intenção de executar certos tipos de ação; processo executado (performed) é uma ocorrência que pode não corresponder à intenção original. Confundi-los inviabiliza qualquer análise de aderência entre plano e execução.
- **[Artifacts and Resources](#artifacts-and-resources)** — conceitos e relações do módulo.
- **[Activity Start Criterion](#activity-start-criterion)** — Qual evento observado marca o início de um trabalho é **convenção social**, e não fato que alguma origem forneça. Organizações diferentes reconhecem eventos diferentes como início, e nenhuma está errada.
Este módulo dá nome à declaração. Sem ele, a plataforma teria de escolher — e a `FR-007` da feature 022 proíbe exatamente isso, deixando `flow.throughput`, `flow.wip.count` e o cycle time por pessoa sem um instante de início.

---

## Projects and Stakeholders

<a id="projects-and-stakeholders"></a>

*Fonte: Tese, Seção 2.2.2.1, Figura 16*

### Conceitos

#### `spo.project` — Project

*Projeto*

Empreendimento temporário com objetivo definido, executado por uma organização.

<sub>categoria UFO: `social_object`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `name` | string | sim |
| `started_at` | datetime | não |
| `ended_at` | datetime | não |

#### `spo.software_project` — Software Project

*Projeto de Software*

Projeto relacionado ao desenvolvimento ou manutenção de software.

<sub>categoria UFO: `social_object` · especializa `spo.project`</sub>

#### `spo.simple_project` — Simple Project

*Projeto Simples*

Projeto que não é decomposto em outros projetos.

<sub>categoria UFO: `social_object` · especializa `spo.project`</sub>

Exemplos: *o projeto de um módulo com dois repositórios e nenhum subprojeto*

#### `spo.complex_project` — Complex Project

*Projeto Complexo*

Projeto composto de outros projetos. Como o projeto componente é ele próprio um projeto, um projeto complexo pode ser parte de outro: a decomposição é recursiva e não tem profundidade fixa. Ser complexo não é rótulo atribuído, e sim consequência de ter partes — um projeto sem partes é simples, ainda que alguém o tenha cadastrado pensando em decompô-lo.

<sub>categoria UFO: `social_object` · especializa `spo.project`</sub>

#### `spo.project_stakeholder` — Project Stakeholder

*Parte Interessada do Projeto*

Agente interessado em um projeto de software. A identidade vem do agente, que pode ser uma pessoa ou uma equipe — por isso a fundamentação é ufo.agent, e não eo.person: os subtipos é que fixam qual dos dois.

<sub>categoria UFO: `role` · papel de `ufo.agent`</sub>

#### `spo.project_person_stakeholder` — Project Person Stakeholder

*Parte Interessada Pessoa*

Pessoa interessada em um projeto de software.

<sub>categoria UFO: `role` · especializa `spo.project_stakeholder` · papel de `eo.person`</sub>

Exemplos: *o gerente do projeto*

#### `spo.project_team_stakeholder` — Project Team Stakeholder

*Parte Interessada Equipe*

Equipe interessada em um projeto de software.

<sub>categoria UFO: `role` · especializa `spo.project_stakeholder` · papel de `eo.team`</sub>

Exemplos: *a equipe de desenvolvimento do projeto*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `was composed of` | `spo.complex_project` | `spo.project` | one → one_or_many | part_whole |
| `is interested in` | `spo.project_stakeholder` | `spo.software_project` | many → many | association |

- **`spo.complex_project_composed_of_project`** — O destino é spo.project, e não spo.simple_project — e um projeto complexo é um projeto. Logo a relação é recursiva: um projeto complexo pode ter outro complexo como parte, em qualquer profundidade. Restringir o destino a projetos simples fixaria a decomposição em dois níveis, e Conecta Fapes → Backend → Pagamentos deixaria de ser expressável.
A cardinalidade da origem é **one**, e não many: um projeto tem no máximo um pai vigente. A hierarquia é árvore, e é isso que faz cada issue contar uma vez no ancestral. Trocar de pai é permitido — encerra o vínculo atual e cria outro —, o que a cardinalidade proíbe é ter dois ao mesmo tempo.


---

## Processes and Activities

<a id="processes-and-activities"></a>

A distinção central da SPO: processo pretendido (intended) é uma intenção de executar certos tipos de ação; processo executado (performed) é uma ocorrência que pode não corresponder à intenção original. Confundi-los inviabiliza qualquer análise de aderência entre plano e execução.

*Fonte: Tese, Seção 2.2.2.1, Figura 16*

### Conceitos

#### `spo.intended_project_process` — Intended Project Process

*Processo Pretendido do Projeto*

Processo planejado para ser executado no projeto — uma intenção, não uma ocorrência.

<sub>categoria UFO: `intention`</sub>

#### `spo.general_intended_project_process` — General Intended Project Process

*Processo Pretendido Geral*

Processo pretendido que se refere ao processo inteiro definido para um projeto.

<sub>categoria UFO: `intention` · especializa `spo.intended_project_process`</sub>

#### `spo.specific_intended_project_process` — Specific Intended Project Process

*Processo Pretendido Específico*

Processo pretendido definido com um propósito específico no projeto.

<sub>categoria UFO: `intention` · especializa `spo.intended_project_process`</sub>

Exemplos: *o processo de Engenharia de Requisitos definido para um projeto*

#### `spo.intended_project_activity` — Intended Project Activity

*Atividade Pretendida do Projeto*

Atividade planejada que compõe um processo pretendido específico.

<sub>categoria UFO: `intention`</sub>

#### `spo.performed_project_process` — Performed Project Process

*Processo Executado do Projeto*

Processo como efetivamente executado no projeto. É uma ação complexa ("ocorrência") que pode não corresponder à intenção original.

<sub>categoria UFO: `complex_action`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `occurred_at` | datetime | sim |
| `start_date` | datetime | não |
| `end_date` | datetime | não |

#### `spo.general_performed_project_process` — General Performed Project Process

*Processo Executado Geral*

Processo executado que corresponde ao processo global do projeto.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_project_process`</sub>

#### `spo.specific_performed_project_process` — Specific Performed Project Process

*Processo Executado Específico*

Processo executado com propósito específico, composto de atividades executadas.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_project_process`</sub>

#### `spo.specific_performed_project_simple_process` — Specific Performed Project Simple Process

*Processo Executado Específico Simples*

Processo executado específico que contém apenas atividades.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_process`</sub>

#### `spo.specific_performed_project_composite_process` — Specific Performed Project Composite Process

*Processo Executado Específico Composto*

Processo executado específico que contém dois ou mais processos executados específicos.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_process`</sub>

#### `spo.performed_project_activity` — Performed Project Activity

*Atividade Executada do Projeto*

Atividade efetivamente executada, compondo um processo executado específico.
É o kind das ocorrências de atividade em toda a rede: commits, execuções de teste, cerimônias, implantações e inspeções são todos especializações deste conceito, e compartilham o mesmo princípio de identidade. Por isso o kind mora em SPO, e as ontologias de domínio o especializam em vez de definir cada uma o seu.

<sub>categoria UFO: `action`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `occurred_at` | datetime | sim |
| `start_date` | datetime | não |
| `end_date` | datetime | não |

#### `spo.performed_simple_activity` — Performed Simple Activity

*Atividade Executada Simples*

Atividade executada que não se decompõe em outras atividades.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity`</sub>

#### `spo.performed_composite_activity` — Performed Composite Activity

*Atividade Executada Composta*

Atividade executada composta de outras atividades executadas.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_project_activity`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `causes` | `spo.intended_project_activity` | `spo.performed_project_activity` | one → many | causation |
| `composed of` | `spo.specific_performed_project_process` | `spo.performed_project_activity` | one → one_or_many | part_whole |
| `depends on` | `spo.performed_project_activity` | `spo.performed_project_activity` | many → many | dependency |
| `is in charge of` | `spo.project_stakeholder` | `spo.performed_project_activity` | many → many | participation |
| `participates in` | `spo.project_stakeholder` | `spo.performed_project_activity` | many → many | participation |
| `performed in` | `spo.performed_project_process` | `spo.software_project` | many → one | association |

- **`spo.intended_causes_performed`** — A intenção de executar uma atividade pode resultar na execução dela. Nem toda atividade pretendida é executada, e nem toda executada foi pretendida.
- **`spo.activity_depends_on_activity`** — Estabelece a ordem em que as atividades ocorreram.
- **`spo.is_in_charge_of`** — O stakeholder foi responsável pela execução da atividade.
- **`spo.participates_in`** — O stakeholder contribuiu com a execução da atividade, sem ser o responsável. Distinguir de "is in charge of" é o que permite medir carga real de trabalho.


---

## Artifacts and Resources

<a id="artifacts-and-resources"></a>

*Fonte: Tese, Seção 2.2.2.1, Figuras 16 e 17*

### Conceitos

#### `spo.artifact` — Artifact

*Artefato*

Objeto criado, usado ou alterado por atividades executadas do processo.

<sub>categoria UFO: `object`</sub>

#### `spo.information_item` — Information Item

*Item de Informação*

Informação relevante para uso humano no contexto do processo de software.

<sub>categoria UFO: `social_object` · especializa `spo.artifact`</sub>

Exemplos: *um bug reportado*; *um requisito documentado*

#### `spo.document` — Document

*Documento*

Informação escrita ou pictórica, unicamente identificada, relacionada ao processo de software, geralmente em formato predefinido. Um documento descreve artefatos; não é o artefato descrito.

<sub>categoria UFO: `social_object` · especializa `spo.information_item`</sub>

Exemplos: *uma Especificação de Projeto*

#### `spo.resource` — Resource

*Recurso*

Papel assumido por um artefato — produto de software ou equipamento de hardware — quando é usado por uma atividade do processo. As especializações que apontam para conceitos de SysSwO vivem em SysSwO, e não aqui, para preservar a direção de dependência (SysSwO depende de SPO, não o contrário).

<sub>categoria UFO: `role` · papel de `spo.artifact`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `creates` | `spo.performed_project_activity` | `spo.artifact` | many → many | association |
| `uses` | `spo.performed_project_activity` | `spo.artifact` | many → many | association |
| `changes` | `spo.performed_project_activity` | `spo.artifact` | many → many | association |
| `describes` | `spo.document` | `spo.artifact` | many → many | association |
| `uses resource` | `spo.performed_project_activity` | `spo.resource` | many → many | association |



---

## Activity Start Criterion

<a id="activity-start-criterion"></a>

Qual evento observado marca o início de um trabalho é **convenção social**, e não fato que alguma origem forneça. Organizações diferentes reconhecem eventos diferentes como início, e nenhuma está errada.
Este módulo dá nome à declaração. Sem ele, a plataforma teria de escolher — e a `FR-007` da feature 022 proíbe exatamente isso, deixando `flow.throughput`, `flow.wip.count` e o cycle time por pessoa sem um instante de início.

*Fonte: Issue #370; decisão da pessoa mantenedora em 2026-08-24*

### Conceitos

#### `spo.activity_start_criterion` — Activity Start Criterion

*Critério de Início de Atividade*

O tipo de evento que uma organização declara como aquele que traz à tona a situação de um trabalho ter começado.
É objeto **social** porque a resposta não está no dado observado: o mesmo evento — mover um cartão, designar alguém, abrir a tarefa — significa "começou" numa organização e não significa noutra. A plataforma não escolhe; ela registra a escolha, com quem a fez e quando.
Sem critério declarado, o instante de início fica **nulo** — ausência nomeada, e nunca a data corrente, que afirmaria que o trabalho começou agora.

<sub>categoria UFO: `social_object`</sub>

Exemplos: *a mudança de status no quadro conta como início, neste projeto*; *a designação conta como início, neste outro*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `recognises` | `spo.activity_start_criterion` | `ufo.event` | many → one | association |
| `declared for` | `spo.activity_start_criterion` | `spo.project` | one → one | association |
| `determines the start of` | `spo.activity_start_criterion` | `spo.performed_project_activity` | one → many | association |



---

[← Rede de ontologias](README.md)

