<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# SRO — Scrum Reference Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **111 of 113** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Conceitualização do desenvolvimento ágil com Scrum: eventos e cerimônias do processo, times e papéis, participação dos stakeholders, product e sprint backlog, e entregáveis produzidos.

| | |
|---|---|
| **Id** | `sro` |
| **Version** | 1.0.0 |
| **Layer** | Domain |
| **Network** | Continuum |
| **Namespace** | `the_band.ontology.continuum.sro` |
| **Depends on** | [ufo](ufo.md), [eo](eo.md), [spo](spo.md), [sys_swo](sys_swo.md), [rsro](rsro.md), [cmpo](cmpo.md) |
| **Origin** | `pt-BR` Tese, Seção 3.2 (Figuras 25 a 30) |

> **Note.** `pt-BR` Os verbos das relações estão no passado: Continuum descreve eventos que já ocorreram nos projetos, não intenções.


## Modules

- **[Scrum Process](#scrum-process)** — `pt-BR` Eventos que ocorrem em um projeto que adota Scrum: o processo, os sprints e as cerimônias, com as relações de dependência que estabelecem a ordem em que ocorreram.
- **[Scrum Stakeholders](#scrum-stakeholders)** — `pt-BR` Times, agentes e papéis de um projeto Scrum. Papel (Developer Role) e agente no papel (Developer) são conceitos distintos, e a alocação é feita por uma Team Membership de EO — não por um atributo na pessoa.
- **[Scrum Stakeholder Participation](#scrum-stakeholder-participation)** — `pt-BR` Quem foi responsável e quem participou de cada processo e cerimônia do projeto Scrum. Baseia-se nas relações "is in charge of" e "participates in" de SPO — distinguir as duas é o que permite medir responsabilidade real, e não apenas presença.
- **[Product and Sprint Backlog](#product-and-sprint-backlog)** — `pt-BR` Requisitos estabelecidos no projeto Scrum e as tarefas planejadas para materializá-los. A tarefa pretendida (intended) e a executada (performed) são conceitos distintos ligados por causação — é isso que permite medir aderência entre planejado e realizado.
- **[Scrum Deliverables](#scrum-deliverables)** — `pt-BR` Resultados produzidos no projeto Scrum. Entregável aceito e não aceito são fases distintas do entregável, e a tarefa que produziu apenas entregáveis aceitos é distinguida da que produziu algum não aceito — é assim que se mede retrabalho sem inventar heurística.
- **[Scope Traceability](#scope-traceability)** — `pt-BR` Qual item de escopo uma solicitação de mudança atende. Fecha o rastreio que começa na pessoa e passa pelo commit e pela solicitação, ligando trabalho de gerência de configuração ao escopo que o motivou.

---

## Scrum Process

<a id="scrum-process"></a>

`pt-BR` Eventos que ocorrem em um projeto que adota Scrum: o processo, os sprints e as cerimônias, com as relações de dependência que estabelecem a ordem em que ocorreram.

*Source: `pt-BR` Tese, Seção 3.2.1, Figura 26*

### Concepts

#### `sro.scrum_project` — Scrum Project

*pt-BR: Projeto Scrum*

`pt-BR` Projeto de software que adota Scrum em seu processo.

<sub>UFO category: `social_object` · specializes `spo.software_project`</sub>

#### `sro.scrum_process` — Scrum Process

*pt-BR: Processo Scrum*

`pt-BR` Processo executado geral do projeto, composto da Definição do Product Backlog e de dois ou mais Sprints.

<sub>UFO category: `complex_action` · specializes `spo.general_performed_project_process`</sub>

#### `sro.product_backlog_definition` — Product Backlog Definition

*pt-BR: Definição do Product Backlog*

`pt-BR` Processo executado específico que define e prioriza as funcionalidades a serem produzidas no projeto Scrum.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_process`</sub>

#### `sro.sprint` — Sprint

*pt-BR: Sprint*

`pt-BR` Processo executado específico que ocorre após a Definição do Product Backlog e visa desenvolver o produto.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_process`</sub>

| Attribute | Type | Required |
|---|---|---|
| `start_date` | datetime | no |
| `end_date` | datetime | no |

#### `sro.ceremony` — Ceremony

*pt-BR: Cerimônia*

`pt-BR` Atividade executada do projeto que compõe um Sprint, correspondendo aos eventos do Scrum.

<sub>UFO category: `action` · specializes `spo.performed_project_activity`</sub>

#### `sro.planning_meeting` — Planning Meeting

*pt-BR: Reunião de Planejamento*

`pt-BR` Cerimônia em que as user stories do sprint são selecionadas e as tarefas planejadas.

<sub>UFO category: `action` · specializes `sro.ceremony`</sub>

#### `sro.daily_standup_meeting` — Daily Standup Meeting

*pt-BR: Reunião Diária*

`pt-BR` Cerimônia diária que ocorre após a execução das tarefas de desenvolvimento discutidas nela.

<sub>UFO category: `action` · specializes `sro.ceremony`</sub>

#### `sro.review_meeting` — Review Meeting

*pt-BR: Reunião de Revisão*

`pt-BR` Cerimônia de revisão dos resultados produzidos no sprint.

<sub>UFO category: `action` · specializes `sro.ceremony`</sub>

#### `sro.retrospective_meeting` — Retrospective Meeting

*pt-BR: Reunião de Retrospectiva*

`pt-BR` Cerimônia de avaliação do processo executado no sprint.

<sub>UFO category: `action` · specializes `sro.ceremony`</sub>

#### `sro.performed_scrum_development_task` — Performed Scrum Development Task

*pt-BR: Tarefa de Desenvolvimento Executada*

`pt-BR` Atividade executada do projeto realizada em um sprint para materializar user stories. Corresponde à execução de uma tarefa planejada na Reunião de Planejamento.

<sub>UFO category: `action` · specializes `spo.performed_project_activity`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `was performed in` | `sro.scrum_process` | `sro.scrum_project` | one → one | association |
| `was composed of` | `sro.scrum_process` | `sro.product_backlog_definition` | one → one | part_whole |
| `was composed of` | `sro.scrum_process` | `sro.sprint` | one → one_or_many | part_whole |
| `depended on` | `sro.sprint` | `sro.product_backlog_definition` | many → one | dependency |
| `was composed of` | `sro.sprint` | `sro.ceremony` | one → one_or_many | part_whole |
| `was composed of` | `sro.sprint` | `sro.performed_scrum_development_task` | one → many | part_whole |
| `depended on` | `sro.performed_scrum_development_task` | `sro.planning_meeting` | many → one | dependency |
| `depended on` | `sro.daily_standup_meeting` | `sro.performed_scrum_development_task` | many → many | dependency |
| `depended on` | `sro.review_meeting` | `sro.daily_standup_meeting` | one → many | dependency |
| `depended on` | `sro.retrospective_meeting` | `sro.review_meeting` | one → one | dependency |

- **`sro.development_task_depends_on_planning_meeting`** — `pt-BR` A tarefa executada refere-se à execução de uma tarefa planejada na Reunião de Planejamento.


---

## Scrum Stakeholders

<a id="scrum-stakeholders"></a>

`pt-BR` Times, agentes e papéis de um projeto Scrum. Papel (Developer Role) e agente no papel (Developer) são conceitos distintos, e a alocação é feita por uma Team Membership de EO — não por um atributo na pessoa.

*Source: `pt-BR` Tese, Seção 3.2.2, Figura 27*

### Concepts

#### `sro.scrum_role` — Scrum Role

*pt-BR: Papel Scrum*

`pt-BR` Papel organizacional reconhecido no contexto de um projeto Scrum.

<sub>UFO category: `social_role` · specializes `eo.organizational_role`</sub>

#### `sro.product_owner_role` — Product Owner Role

*pt-BR: Papel de Product Owner*

`pt-BR` Papel Scrum responsável por representar os interesses do cliente e priorizar o backlog.

<sub>UFO category: `social_role` · specializes `sro.scrum_role`</sub>

#### `sro.scrum_master_role` — Scrum Master Role

*pt-BR: Papel de Scrum Master*

`pt-BR` Papel Scrum responsável por facilitar o processo e remover impedimentos.

<sub>UFO category: `social_role` · specializes `sro.scrum_role`</sub>

#### `sro.developer_role` — Developer Role

*pt-BR: Papel de Desenvolvedor*

`pt-BR` Papel Scrum responsável por desenvolver o produto e os resultados intermediários.

<sub>UFO category: `social_role` · specializes `sro.scrum_role`</sub>

#### `sro.client_role` — Client Role

*pt-BR: Papel de Cliente*

`pt-BR` Papel Scrum de quem demanda o produto e participa da definição do product backlog.

<sub>UFO category: `social_role` · specializes `sro.scrum_role`</sub>

#### `sro.scrum_team_member` — Scrum Team Member

*pt-BR: Membro do Time Scrum*

`pt-BR` Pessoa interessada em um projeto Scrum e alocada a um time Scrum para desempenhar um papel Scrum.

<sub>UFO category: `role` · specializes `spo.project_person_stakeholder`</sub>

#### `sro.product_owner` — Product Owner

*pt-BR: Product Owner*

`pt-BR` Membro do time Scrum que desempenha o Papel de Product Owner no time.

<sub>UFO category: `role` · specializes `sro.scrum_team_member`</sub>

#### `sro.product_owner_client` — Product Owner Client

*pt-BR: Product Owner Cliente*

`pt-BR` Ocorre quando o próprio cliente é membro do time Scrum e desempenha o Papel de Product Owner.

<sub>UFO category: `role` · specializes `sro.product_owner`</sub>

#### `sro.product_owner_project_stakeholder` — Product Owner Project Stakeholder

*pt-BR: Product Owner Representante*

`pt-BR` Ocorre quando outra pessoa representa os interesses do cliente desempenhando o Papel de Product Owner.

<sub>UFO category: `role` · specializes `sro.product_owner`</sub>

#### `sro.scrum_master` — Scrum Master

*pt-BR: Scrum Master*

`pt-BR` Membro do time Scrum que desempenha o Papel de Scrum Master.

<sub>UFO category: `role` · specializes `sro.scrum_team_member`</sub>

#### `sro.developer` — Developer

*pt-BR: Desenvolvedor*

`pt-BR` Membro do time Scrum que desempenha o Papel de Desenvolvedor no time de desenvolvimento.

<sub>UFO category: `role` · specializes `sro.scrum_team_member`</sub>

#### `sro.client` — Client

*pt-BR: Cliente*

`pt-BR` Membro do time Scrum que desempenha o Papel de Cliente.

<sub>UFO category: `role` · specializes `sro.scrum_team_member`</sub>

#### `sro.scrum_team` — Scrum Team

*pt-BR: Time Scrum*

`pt-BR` Equipe interessada em um projeto Scrum, composta pelos membros do time Scrum.

<sub>UFO category: `collective` · specializes `spo.project_team_stakeholder`</sub>

#### `sro.development_team` — Development Team

*pt-BR: Time de Desenvolvimento*

`pt-BR` Parte do time Scrum responsável por desenvolver o produto e os resultados intermediários.

<sub>UFO category: `collective` · specializes `spo.project_team_stakeholder`</sub>

#### `sro.product_owner_membership` — Product Owner Membership

*pt-BR: Alocação de Product Owner*

`pt-BR` Alocação que faz um membro do time desempenhar o Papel de Product Owner em um time Scrum.

<sub>UFO category: `relator` · specializes `eo.team_membership`</sub>

#### `sro.scrum_master_membership` — Scrum Master Membership

*pt-BR: Alocação de Scrum Master*

`pt-BR` Alocação que faz um membro do time desempenhar o Papel de Scrum Master em um time de desenvolvimento.

<sub>UFO category: `relator` · specializes `eo.team_membership`</sub>

#### `sro.developer_membership` — Developer Membership

*pt-BR: Alocação de Desenvolvedor*

`pt-BR` Alocação que faz um membro do time desempenhar o Papel de Desenvolvedor em um time de desenvolvimento.

<sub>UFO category: `relator` · specializes `eo.team_membership`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `was interested in` | `sro.scrum_team` | `sro.scrum_project` | many → one | association |
| `was part of` | `sro.development_team` | `sro.scrum_team` | one → one | part_whole |
| `was composed of` | `sro.scrum_team` | `sro.scrum_team_member` | one → one_or_many | part_whole |
| `allocated to play` | `sro.product_owner_membership` | `sro.product_owner_role` | many → one | association |



---

## Scrum Stakeholder Participation

<a id="scrum-stakeholder-participation"></a>

`pt-BR` Quem foi responsável e quem participou de cada processo e cerimônia do projeto Scrum. Baseia-se nas relações "is in charge of" e "participates in" de SPO — distinguir as duas é o que permite medir responsabilidade real, e não apenas presença.

*Source: `pt-BR` Tese, Seção 3.2.3, Figura 28*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `was in charge of` | `sro.product_owner` | `sro.product_backlog_definition` | one → one | participation |
| `was in charge of` | `sro.product_owner` | `sro.planning_meeting` | one → many | participation |
| `was in charge of` | `sro.product_owner` | `sro.review_meeting` | one → many | participation |
| `was in charge of` | `sro.product_owner` | `sro.retrospective_meeting` | one → many | participation |
| `was in charge of` | `sro.scrum_master` | `sro.daily_standup_meeting` | one → many | participation |
| `was in charge of` | `sro.developer` | `sro.performed_scrum_development_task` | one → many | participation |
| `participated in` | `sro.developer` | `sro.performed_scrum_development_task` | many → many | participation |
| `participated in` | `sro.development_team` | `sro.daily_standup_meeting` | one → many | participation |
| `participated in` | `sro.scrum_team` | `sro.ceremony` | one → many | participation |
| `participated in` | `sro.client` | `sro.product_backlog_definition` | many → one | participation |



---

## Product and Sprint Backlog

<a id="product-and-sprint-backlog"></a>

`pt-BR` Requisitos estabelecidos no projeto Scrum e as tarefas planejadas para materializá-los. A tarefa pretendida (intended) e a executada (performed) são conceitos distintos ligados por causação — é isso que permite medir aderência entre planejado e realizado.

*Source: `pt-BR` Tese, Seção 3.2.4, Figura 29*

### Concepts

#### `sro.product_backlog` — Product Backlog

*pt-BR: Product Backlog*

`pt-BR` Documento criado durante a Definição do Product Backlog, que contém os requisitos do produto a ser desenvolvido, descritos por user stories.

<sub>UFO category: `social_object` · specializes `spo.document`</sub>

#### `sro.user_story` — User Story

*pt-BR: História de Usuário*

`pt-BR` Artefato de requisito que descreve requisitos em um projeto Scrum.

<sub>UFO category: `social_object` · specializes `rsro.requirements_artifact`</sub>

| Attribute | Type | Required |
|---|---|---|
| `title` | string | yes |
| `importance` | decimal | no |
| `complexity` | decimal | no |

Examples: `pt-BR` *US1: Eu, como viajante, quero pagar minha passagem.*; *US65: Eu, como servidor público, quero visualizar meus contracheques.*

#### `sro.atomic_user_story` — Atomic User Story

*pt-BR: História de Usuário Atômica*

`pt-BR` User story que não é decomposta em outras.

<sub>UFO category: `social_object` · specializes `sro.user_story`</sub>

Examples: `pt-BR` *US1.1: Eu, como viajante, quero pagar minha passagem com cartão de crédito.*

#### `sro.epic` — Epic

*pt-BR: Épico*

`pt-BR` User story composta de outras user stories. Como o épico é ele próprio uma user story, um épico pode ser parte de outro épico: a decomposição é recursiva e não tem profundidade fixa. Ser épico não é rótulo atribuído, e sim consequência de ter partes — uma user story sem partes não é épico, ainda que a ferramenta a chame assim.

<sub>UFO category: `social_object` · specializes `sro.user_story`</sub>

Examples: `pt-BR` *US1 (épico) composto por US1.1 e US1.2 (atômicas).*; *US0 (épico) composto por US1 (épico) e US2 (atômica) — aninhamento válido.*

#### `sro.acceptance_criterion` — Acceptance Criterion

*pt-BR: Critério de Aceitação*

`pt-BR` Requisito usado para verificar se a user story foi desenvolvida corretamente e atende às necessidades do cliente.

<sub>UFO category: `goal` · specializes `rsro.requirement`</sub>

#### `sro.functional_acceptance_criterion` — Functional Acceptance Criterion

*pt-BR: Critério de Aceitação Funcional*

`pt-BR` Requisito funcional usado para verificar se a funcionalidade da user story foi desenvolvida corretamente.

<sub>UFO category: `goal` · specializes `sro.acceptance_criterion`</sub>

Examples: `pt-BR` *AC1: O cartão de crédito deve ser válido.*

#### `sro.non_functional_acceptance_criterion` — Non-Functional Acceptance Criterion

*pt-BR: Critério de Aceitação Não Funcional*

`pt-BR` Requisito não funcional que estabelece critério de qualidade relacionado a características do produto.

<sub>UFO category: `goal` · specializes `sro.acceptance_criterion`</sub>

Examples: `pt-BR` *AC2: A autenticação do pagamento é feita em menos de 10ms.*

#### `sro.sprint_backlog` — Sprint Backlog

*pt-BR: Sprint Backlog*

`pt-BR` Documento que descreve o planejamento do sprint: as user stories selecionadas e as tarefas de desenvolvimento pretendidas para materializá-las.

<sub>UFO category: `social_object` · specializes `spo.document`</sub>

#### `sro.intended_scrum_development_task` — Intended Scrum Development Task

*pt-BR: Tarefa de Desenvolvimento Pretendida*

`pt-BR` Atividade pretendida que descreve o que é necessário para materializar uma user story. Tarefas pretendidas não executadas no sprint podem ser associadas ao sprint backlog de sprints seguintes.

<sub>UFO category: `intention` · specializes `spo.intended_project_activity`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `created` | `sro.product_backlog_definition` | `sro.product_backlog` | one → one | association |
| `was part of` | `sro.user_story` | `sro.product_backlog` | many → one | part_whole |
| `was composed of` | `sro.epic` | `sro.user_story` | one → one_or_many | part_whole |
| `had` | `sro.user_story` | `sro.acceptance_criterion` | one → many | association |
| `was part of` | `sro.user_story` | `sro.sprint_backlog` | many → many | part_whole |
| `had` | `sro.sprint` | `sro.sprint_backlog` | one → one | association |
| `specified` | `sro.sprint_backlog` | `sro.intended_scrum_development_task` | one → many | association |
| `was planned to meet` | `sro.intended_scrum_development_task` | `sro.atomic_user_story` | many → one | association |
| `was caused by` | `sro.performed_scrum_development_task` | `sro.intended_scrum_development_task` | one → one | causation |
| `was performed to meet` | `sro.performed_scrum_development_task` | `sro.atomic_user_story` | many → one | association |
| `was performed in` | `sro.performed_scrum_development_task` | `sro.sprint` | many → one_or_many | association |

- **`sro.epic_composed_of_user_story`** — `pt-BR` O destino é sro.user_story, e não sro.atomic_user_story — e um épico é uma user story. Logo a relação é recursiva: um épico pode ter outro épico como parte, em qualquer profundidade. Restringir o destino a user stories atômicas impediria a decomposição em níveis, que é justamente o uso comum de épico em projetos grandes.
Três restrições delimitam a recursão: a hierarquia é acíclica (sro.rule04), todo épico tem ao menos uma parte (sro.rule05), e toda cadeia de decomposição termina em user stories atômicas (sro.rule06). Sem elas, a relação admitiria um épico que é parte de si mesmo e uma decomposição infinita.
- **`sro.sprint_backlog_specifies_intended_task`** — `pt-BR` Uma tarefa pretendida pode estar relacionada a vários sprint backlogs quando não foi executada no sprint em que foi planejada.


---

## Scrum Deliverables

<a id="scrum-deliverables"></a>

`pt-BR` Resultados produzidos no projeto Scrum. Entregável aceito e não aceito são fases distintas do entregável, e a tarefa que produziu apenas entregáveis aceitos é distinguida da que produziu algum não aceito — é assim que se mede retrabalho sem inventar heurística.

*Source: `pt-BR` Tese, Seção 3.2.5, Figura 30*

### Concepts

#### `sro.deliverable` — Deliverable

*pt-BR: Entregável*

`pt-BR` Item de software que materializa user stories tratadas em um sprint.

<sub>UFO category: `object` · specializes `sys_swo.software_item`</sub>

Examples: `pt-BR` *a funcionalidade de pagar a passagem com cartão de crédito*

#### `sro.accepted_deliverable` — Accepted Deliverable

*pt-BR: Entregável Aceito*

`pt-BR` Entregável em conformidade com os critérios de aceitação das user stories que materializa. Significa que está "done".

<sub>UFO category: `phase` · specializes `sro.deliverable`</sub>

#### `sro.not_accepted_deliverable` — Not Accepted Deliverable

*pt-BR: Entregável Não Aceito*

`pt-BR` Entregável que não está em conformidade com ao menos um critério de aceitação. As user stories relacionadas podem retornar ao product backlog.

<sub>UFO category: `phase` · specializes `sro.deliverable`</sub>

#### `sro.successfully_performed_scrum_development_task` — Successfully Performed Scrum Development Task

*pt-BR: Tarefa Executada com Sucesso*

`pt-BR` Tarefa de desenvolvimento executada que produziu apenas entregáveis aceitos.

<sub>UFO category: `phase` · specializes `sro.performed_scrum_development_task`</sub>

#### `sro.non_successfully_performed_scrum_development_task` — Non-Successfully Performed Scrum Development Task

*pt-BR: Tarefa Executada sem Sucesso*

`pt-BR` Tarefa de desenvolvimento executada que produziu um ou mais entregáveis não aceitos.

<sub>UFO category: `phase` · specializes `sro.performed_scrum_development_task`</sub>

#### `sro.sprint_deliverable` — Sprint Deliverable

*pt-BR: Entregável do Sprint*

`pt-BR` Item de software mais completo, formado pela integração dos entregáveis aceitos produzidos em um sprint. É o resultado do sprint entregue ao cliente.

<sub>UFO category: `object` · specializes `sro.deliverable`</sub>

#### `sro.scrum_project_deliverable` — Scrum Project Deliverable

*pt-BR: Entregável do Projeto Scrum*

`pt-BR` Produto de software formado pelo conjunto dos entregáveis de sprint produzidos no projeto. É o entregável final do processo Scrum.

<sub>UFO category: `object` · specializes `sys_swo.software_product`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `produced` | `sro.performed_scrum_development_task` | `sro.deliverable` | many → one_or_many | association |
| `produced` | `sro.successfully_performed_scrum_development_task` | `sro.accepted_deliverable` | one → one_or_many | association |
| `produced` | `sro.non_successfully_performed_scrum_development_task` | `sro.not_accepted_deliverable` | one → one_or_many | association |
| `materialized` | `sro.deliverable` | `sro.atomic_user_story` | many → many | materialization |
| `produced` | `sro.sprint` | `sro.sprint_deliverable` | one → one | association |
| `was composed of` | `sro.sprint_deliverable` | `sro.accepted_deliverable` | one → one_or_many | part_whole |
| `was composed of` | `sro.scrum_project_deliverable` | `sro.sprint_deliverable` | one → one_or_many | part_whole |
| `created` | `sro.scrum_process` | `sro.scrum_project_deliverable` | one → one | association |



---

## Scope Traceability

<a id="scope-traceability"></a>

`pt-BR` Qual item de escopo uma solicitação de mudança atende. Fecha o rastreio que começa na pessoa e passa pelo commit e pela solicitação, ligando trabalho de gerência de configuração ao escopo que o motivou.

*Source: `pt-BR` Issue #426; complementa cmpo.change_traceability*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `attended` | `cmpo.change_request` | `sro.user_story` | many → many | association |
| `attended` | `cmpo.change_request` | `sro.performed_scrum_development_task` | many → many | association |
| `attended` | `cmpo.change_request` | `sro.epic` | many → many | association |



---

## Competency questions

Questions this ontology must be able to answer. They are the model's functional requirements, checked by `mix knowledge.test`.

| # | Question | Concepts involved |
|---|---|---|
| `CQ01` | Which processes and activities make up a Scrum process? | `sro.scrum_process`, `sro.sprint`, `sro.product_backlog_definition`, `sro.ceremony` |
| `CQ02` | `pt-BR` Em um projeto Scrum, de quais outras atividades ou processos uma atividade dependeu? | `sro.sprint`, `sro.ceremony`, `sro.performed_scrum_development_task` |
| `CQ03` | `pt-BR` Quantos sprints foram executados em um projeto Scrum? | `sro.scrum_process`, `sro.sprint`, `sro.scrum_project` |
| `CQ04` | `pt-BR` Quais cerimônias foram executadas em um sprint? | `sro.sprint`, `sro.planning_meeting`, `sro.daily_standup_meeting`, `sro.review_meeting`, … |
| `CQ05` | `pt-BR` Quais tarefas de desenvolvimento foram executadas em um sprint? | `sro.sprint`, `sro.performed_scrum_development_task` |
| `CQ06` | `pt-BR` Quando um projeto Scrum começou? | `sro.scrum_process`, `sro.scrum_project` |
| `CQ07` | `pt-BR` Quando um projeto Scrum terminou? | `sro.scrum_process`, `sro.scrum_project` |
| `CQ08` | `pt-BR` Quando um processo Scrum começou? | `sro.scrum_process` |
| `CQ09` | `pt-BR` Quando um processo Scrum terminou? | `sro.scrum_process` |
| `CQ10` | `pt-BR` Quando uma atividade do projeto Scrum começou? | `sro.ceremony`, `sro.performed_scrum_development_task` |
| `CQ11` | `pt-BR` Quando uma atividade do projeto Scrum terminou? | `sro.ceremony`, `sro.performed_scrum_development_task` |
| `CQ12` | `pt-BR` Quais papéis estiveram envolvidos em um projeto Scrum? | `sro.scrum_role`, `sro.developer_role`, `sro.scrum_master_role`, `sro.product_owner_role`, … |
| `CQ13` | `pt-BR` Quais times estiveram envolvidos em um projeto Scrum? | `sro.scrum_team`, `sro.development_team` |
| `CQ14` | `pt-BR` Quais papéis estiveram envolvidos em um time de um projeto Scrum? | `sro.scrum_team`, `sro.development_team`, `sro.scrum_role` |
| `CQ15` | `pt-BR` Quem são os membros de um time em um projeto Scrum? | `sro.scrum_team_member`, `sro.developer`, `sro.scrum_master`, `sro.product_owner`, … |
| `CQ16` | `pt-BR` Qual papel é desempenhado por um membro de time em um projeto Scrum? | `sro.scrum_team_member`, `sro.scrum_role`, `sro.product_owner_membership`, `sro.scrum_master_membership`, … |
| `CQ17` | `pt-BR` Quais stakeholders foram responsáveis pelas cerimônias de um projeto Scrum? | `sro.product_owner`, `sro.scrum_master`, `sro.ceremony` |
| `CQ18` | `pt-BR` Quais stakeholders participaram das cerimônias de um projeto Scrum? | `sro.scrum_team`, `sro.development_team`, `sro.client`, `sro.ceremony` |
| `CQ19` | `pt-BR` Quais stakeholders foram responsáveis pelas tarefas de desenvolvimento de um projeto Scrum? | `sro.developer`, `sro.performed_scrum_development_task` |
| `CQ20` | `pt-BR` Quais stakeholders participaram das tarefas de desenvolvimento de um projeto Scrum? | `sro.developer`, `sro.performed_scrum_development_task` |
| `CQ21` | `pt-BR` Quais stakeholders foram responsáveis pelos processos de um projeto Scrum? | `sro.product_owner`, `sro.product_backlog_definition` |
| `CQ22` | `pt-BR` Quais stakeholders participaram dos processos de um projeto Scrum? | `sro.client`, `sro.product_backlog_definition`, `sro.performed_scrum_development_task` |
| `CQ23` | Which user stories were defined in the product backlog of a Scrum project? | `sro.product_backlog`, `sro.user_story`, `sro.epic`, `sro.atomic_user_story` |
| `CQ24` | `pt-BR` Qual é a prioridade de uma user story no product backlog de um projeto Scrum? | `sro.user_story` |
| `CQ25` | `pt-BR` Como uma user story foi decomposta em outras? | `sro.epic`, `sro.user_story`, `sro.atomic_user_story` |
| `CQ26` | `pt-BR` Quais critérios de aceitação foram estabelecidos para uma user story? | `sro.user_story`, `sro.acceptance_criterion`, `sro.functional_acceptance_criterion`, `sro.non_functional_acceptance_criterion` |
| `CQ27` | `pt-BR` Quais user stories foram selecionadas para um sprint backlog? | `sro.sprint_backlog`, `sro.user_story` |
| `CQ28` | `pt-BR` Quais tarefas de desenvolvimento foram planejadas para materializar uma user story? | `sro.sprint_backlog`, `sro.user_story`, `sro.intended_scrum_development_task` |
| `CQ29` | `pt-BR` Quais tarefas de desenvolvimento foram executadas para materializar uma user story? | `sro.performed_scrum_development_task`, `sro.intended_scrum_development_task`, `sro.atomic_user_story` |
| `CQ30` | `pt-BR` Quais tarefas de desenvolvimento foram planejadas para um sprint? | `sro.sprint`, `sro.sprint_backlog`, `sro.intended_scrum_development_task` |
| `CQ31` | `pt-BR` Quais tarefas de desenvolvimento foram executadas em um sprint? | `sro.sprint`, `sro.performed_scrum_development_task` |
| `CQ32` | `pt-BR` Quais tipos de entregáveis foram produzidos em um projeto Scrum? | `sro.deliverable`, `sro.sprint_deliverable`, `sro.accepted_deliverable`, `sro.not_accepted_deliverable` |
| `CQ33` | `pt-BR` Quais entregáveis foram produzidos em um sprint? | `sro.sprint`, `sro.performed_scrum_development_task`, `sro.deliverable`, `sro.sprint_deliverable` |
| `CQ34` | `pt-BR` Quais entregáveis foram produzidos em um projeto Scrum? | `sro.scrum_process`, `sro.sprint`, `sro.sprint_deliverable`, `sro.scrum_project_deliverable` |
| `CQ35` | `pt-BR` Quais user stories um entregável materializou? | `sro.deliverable`, `sro.atomic_user_story` |
| `CQ36` | `pt-BR` Quais entregáveis foram aceitos em um sprint? | `sro.accepted_deliverable`, `sro.successfully_performed_scrum_development_task` |
| `CQ37` | `pt-BR` Quais tarefas de desenvolvimento produziram entregáveis aceitos? | `sro.successfully_performed_scrum_development_task`, `sro.accepted_deliverable` |

- **CQ04** — `pt-BR` Permite ao Scrum Master identificar cerimônia não realizada em um sprint e investigar a causa.
- **CQ15** — `pt-BR` Permite identificar alocação e evitar superalocação da mesma pessoa em múltiplos times.
- **CQ37** — `pt-BR` Cruzada com CQ31 e CQ33, permite quantificar esforço gasto em entregáveis que não foram aceitos — isto é, retrabalho.


---

[← Ontology network](README.md)

