<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# SRO — Scrum Reference Ontology

> Conceitualização do desenvolvimento ágil com Scrum: eventos e cerimônias do processo, times e papéis, participação dos stakeholders, product e sprint backlog, e entregáveis produzidos.

| | |
|---|---|
| **Id** | `sro` |
| **Versão** | 1.0.0 |
| **Camada** | Domínio |
| **Rede** | Continuum |
| **Namespace** | `the_band.ontology.continuum.sro` |
| **Depende de** | [ufo](ufo.md), [eo](eo.md), [spo](spo.md), [sys_swo](sys_swo.md), [rsro](rsro.md) |
| **Origem** | Tese, Seção 3.2 (Figuras 25 a 30) |

> **Nota.** Os verbos das relações estão no passado: Continuum descreve eventos que já ocorreram nos projetos, não intenções.


## Módulos

- **[Scrum Process](#scrum-process)** — Eventos que ocorrem em um projeto que adota Scrum: o processo, os sprints e as cerimônias, com as relações de dependência que estabelecem a ordem em que ocorreram.
- **[Scrum Stakeholders](#scrum-stakeholders)** — Times, agentes e papéis de um projeto Scrum. Papel (Developer Role) e agente no papel (Developer) são conceitos distintos, e a alocação é feita por uma Team Membership de EO — não por um atributo na pessoa.
- **[Scrum Stakeholder Participation](#scrum-stakeholder-participation)** — Quem foi responsável e quem participou de cada processo e cerimônia do projeto Scrum. Baseia-se nas relações "is in charge of" e "participates in" de SPO — distinguir as duas é o que permite medir responsabilidade real, e não apenas presença.
- **[Product and Sprint Backlog](#product-and-sprint-backlog)** — Requisitos estabelecidos no projeto Scrum e as tarefas planejadas para materializá-los. A tarefa pretendida (intended) e a executada (performed) são conceitos distintos ligados por causação — é isso que permite medir aderência entre planejado e realizado.
- **[Scrum Deliverables](#scrum-deliverables)** — Resultados produzidos no projeto Scrum. Entregável aceito e não aceito são fases distintas do entregável, e a tarefa que produziu apenas entregáveis aceitos é distinguida da que produziu algum não aceito — é assim que se mede retrabalho sem inventar heurística.

---

## Scrum Process

<a id="scrum-process"></a>

Eventos que ocorrem em um projeto que adota Scrum: o processo, os sprints e as cerimônias, com as relações de dependência que estabelecem a ordem em que ocorreram.

*Fonte: Tese, Seção 3.2.1, Figura 26*

### Conceitos

#### `sro.scrum_project` — Scrum Project

*Projeto Scrum*

Projeto de software que adota Scrum em seu processo.

<sub>categoria UFO: `social_object` · especializa `spo.software_project`</sub>

#### `sro.scrum_process` — Scrum Process

*Processo Scrum*

Processo executado geral do projeto, composto da Definição do Product Backlog e de dois ou mais Sprints.

<sub>categoria UFO: `complex_action` · especializa `spo.general_performed_project_process`</sub>

#### `sro.product_backlog_definition` — Product Backlog Definition

*Definição do Product Backlog*

Processo executado específico que define e prioriza as funcionalidades a serem produzidas no projeto Scrum.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_process`</sub>

#### `sro.sprint` — Sprint

*Sprint*

Processo executado específico que ocorre após a Definição do Product Backlog e visa desenvolver o produto.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_process`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `start_date` | datetime | não |
| `end_date` | datetime | não |

#### `sro.ceremony` — Ceremony

*Cerimônia*

Atividade executada do projeto que compõe um Sprint, correspondendo aos eventos do Scrum.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity`</sub>

#### `sro.planning_meeting` — Planning Meeting

*Reunião de Planejamento*

Cerimônia em que as user stories do sprint são selecionadas e as tarefas planejadas.

<sub>categoria UFO: `action` · especializa `sro.ceremony`</sub>

#### `sro.daily_standup_meeting` — Daily Standup Meeting

*Reunião Diária*

Cerimônia diária que ocorre após a execução das tarefas de desenvolvimento discutidas nela.

<sub>categoria UFO: `action` · especializa `sro.ceremony`</sub>

#### `sro.review_meeting` — Review Meeting

*Reunião de Revisão*

Cerimônia de revisão dos resultados produzidos no sprint.

<sub>categoria UFO: `action` · especializa `sro.ceremony`</sub>

#### `sro.retrospective_meeting` — Retrospective Meeting

*Reunião de Retrospectiva*

Cerimônia de avaliação do processo executado no sprint.

<sub>categoria UFO: `action` · especializa `sro.ceremony`</sub>

#### `sro.performed_scrum_development_task` — Performed Scrum Development Task

*Tarefa de Desenvolvimento Executada*

Atividade executada do projeto realizada em um sprint para materializar user stories. Corresponde à execução de uma tarefa planejada na Reunião de Planejamento.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
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

- **`sro.development_task_depends_on_planning_meeting`** — A tarefa executada refere-se à execução de uma tarefa planejada na Reunião de Planejamento.


---

## Scrum Stakeholders

<a id="scrum-stakeholders"></a>

Times, agentes e papéis de um projeto Scrum. Papel (Developer Role) e agente no papel (Developer) são conceitos distintos, e a alocação é feita por uma Team Membership de EO — não por um atributo na pessoa.

*Fonte: Tese, Seção 3.2.2, Figura 27*

### Conceitos

#### `sro.scrum_role` — Scrum Role

*Papel Scrum*

Papel organizacional reconhecido no contexto de um projeto Scrum.

<sub>categoria UFO: `social_role` · especializa `eo.organizational_role`</sub>

#### `sro.product_owner_role` — Product Owner Role

*Papel de Product Owner*

Papel Scrum responsável por representar os interesses do cliente e priorizar o backlog.

<sub>categoria UFO: `social_role` · especializa `sro.scrum_role`</sub>

#### `sro.scrum_master_role` — Scrum Master Role

*Papel de Scrum Master*

Papel Scrum responsável por facilitar o processo e remover impedimentos.

<sub>categoria UFO: `social_role` · especializa `sro.scrum_role`</sub>

#### `sro.developer_role` — Developer Role

*Papel de Desenvolvedor*

Papel Scrum responsável por desenvolver o produto e os resultados intermediários.

<sub>categoria UFO: `social_role` · especializa `sro.scrum_role`</sub>

#### `sro.client_role` — Client Role

*Papel de Cliente*

Papel Scrum de quem demanda o produto e participa da definição do product backlog.

<sub>categoria UFO: `social_role` · especializa `sro.scrum_role`</sub>

#### `sro.scrum_team_member` — Scrum Team Member

*Membro do Time Scrum*

Pessoa interessada em um projeto Scrum e alocada a um time Scrum para desempenhar um papel Scrum.

<sub>categoria UFO: `role` · especializa `spo.project_person_stakeholder`</sub>

#### `sro.product_owner` — Product Owner

*Product Owner*

Membro do time Scrum que desempenha o Papel de Product Owner no time.

<sub>categoria UFO: `role` · especializa `sro.scrum_team_member`</sub>

#### `sro.product_owner_client` — Product Owner Client

*Product Owner Cliente*

Ocorre quando o próprio cliente é membro do time Scrum e desempenha o Papel de Product Owner.

<sub>categoria UFO: `role` · especializa `sro.product_owner`</sub>

#### `sro.product_owner_project_stakeholder` — Product Owner Project Stakeholder

*Product Owner Representante*

Ocorre quando outra pessoa representa os interesses do cliente desempenhando o Papel de Product Owner.

<sub>categoria UFO: `role` · especializa `sro.product_owner`</sub>

#### `sro.scrum_master` — Scrum Master

*Scrum Master*

Membro do time Scrum que desempenha o Papel de Scrum Master.

<sub>categoria UFO: `role` · especializa `sro.scrum_team_member`</sub>

#### `sro.developer` — Developer

*Desenvolvedor*

Membro do time Scrum que desempenha o Papel de Desenvolvedor no time de desenvolvimento.

<sub>categoria UFO: `role` · especializa `sro.scrum_team_member`</sub>

#### `sro.client` — Client

*Cliente*

Membro do time Scrum que desempenha o Papel de Cliente.

<sub>categoria UFO: `role` · especializa `sro.scrum_team_member`</sub>

#### `sro.scrum_team` — Scrum Team

*Time Scrum*

Equipe interessada em um projeto Scrum, composta pelos membros do time Scrum.

<sub>categoria UFO: `collective` · especializa `spo.project_team_stakeholder`</sub>

#### `sro.development_team` — Development Team

*Time de Desenvolvimento*

Parte do time Scrum responsável por desenvolver o produto e os resultados intermediários.

<sub>categoria UFO: `collective` · especializa `spo.project_team_stakeholder`</sub>

#### `sro.product_owner_membership` — Product Owner Membership

*Alocação de Product Owner*

Alocação que faz um membro do time desempenhar o Papel de Product Owner em um time Scrum.

<sub>categoria UFO: `relator` · especializa `eo.team_membership`</sub>

#### `sro.scrum_master_membership` — Scrum Master Membership

*Alocação de Scrum Master*

Alocação que faz um membro do time desempenhar o Papel de Scrum Master em um time de desenvolvimento.

<sub>categoria UFO: `relator` · especializa `eo.team_membership`</sub>

#### `sro.developer_membership` — Developer Membership

*Alocação de Desenvolvedor*

Alocação que faz um membro do time desempenhar o Papel de Desenvolvedor em um time de desenvolvimento.

<sub>categoria UFO: `relator` · especializa `eo.team_membership`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `was interested in` | `sro.scrum_team` | `sro.scrum_project` | many → one | association |
| `was part of` | `sro.development_team` | `sro.scrum_team` | one → one | part_whole |
| `was composed of` | `sro.scrum_team` | `sro.scrum_team_member` | one → one_or_many | part_whole |
| `allocated to play` | `sro.product_owner_membership` | `sro.product_owner_role` | many → one | association |



---

## Scrum Stakeholder Participation

<a id="scrum-stakeholder-participation"></a>

Quem foi responsável e quem participou de cada processo e cerimônia do projeto Scrum. Baseia-se nas relações "is in charge of" e "participates in" de SPO — distinguir as duas é o que permite medir responsabilidade real, e não apenas presença.

*Fonte: Tese, Seção 3.2.3, Figura 28*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
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

Requisitos estabelecidos no projeto Scrum e as tarefas planejadas para materializá-los. A tarefa pretendida (intended) e a executada (performed) são conceitos distintos ligados por causação — é isso que permite medir aderência entre planejado e realizado.

*Fonte: Tese, Seção 3.2.4, Figura 29*

### Conceitos

#### `sro.product_backlog` — Product Backlog

*Product Backlog*

Documento criado durante a Definição do Product Backlog, que contém os requisitos do produto a ser desenvolvido, descritos por user stories.

<sub>categoria UFO: `social_object` · especializa `spo.document`</sub>

#### `sro.user_story` — User Story

*História de Usuário*

Artefato de requisito que descreve requisitos em um projeto Scrum.

<sub>categoria UFO: `social_object` · especializa `rsro.requirements_artifact`</sub>

| Atributo | Tipo | Obrigatório |
|---|---|---|
| `title` | string | sim |
| `importance` | decimal | não |
| `complexity` | decimal | não |

Exemplos: *US1: Eu, como viajante, quero pagar minha passagem.*; *US65: Eu, como servidor público, quero visualizar meus contracheques.*

#### `sro.atomic_user_story` — Atomic User Story

*História de Usuário Atômica*

User story que não é decomposta em outras.

<sub>categoria UFO: `social_object` · especializa `sro.user_story`</sub>

Exemplos: *US1.1: Eu, como viajante, quero pagar minha passagem com cartão de crédito.*

#### `sro.epic` — Epic

*Épico*

User story composta de outras user stories. Como o épico é ele próprio uma user story, um épico pode ser parte de outro épico: a decomposição é recursiva e não tem profundidade fixa. Ser épico não é rótulo atribuído, e sim consequência de ter partes — uma user story sem partes não é épico, ainda que a ferramenta a chame assim.

<sub>categoria UFO: `social_object` · especializa `sro.user_story`</sub>

Exemplos: *US1 (épico) composto por US1.1 e US1.2 (atômicas).*; *US0 (épico) composto por US1 (épico) e US2 (atômica) — aninhamento válido.*

#### `sro.acceptance_criterion` — Acceptance Criterion

*Critério de Aceitação*

Requisito usado para verificar se a user story foi desenvolvida corretamente e atende às necessidades do cliente.

<sub>categoria UFO: `goal` · especializa `rsro.requirement`</sub>

#### `sro.functional_acceptance_criterion` — Functional Acceptance Criterion

*Critério de Aceitação Funcional*

Requisito funcional usado para verificar se a funcionalidade da user story foi desenvolvida corretamente.

<sub>categoria UFO: `goal` · especializa `sro.acceptance_criterion`</sub>

Exemplos: *AC1: O cartão de crédito deve ser válido.*

#### `sro.non_functional_acceptance_criterion` — Non-Functional Acceptance Criterion

*Critério de Aceitação Não Funcional*

Requisito não funcional que estabelece critério de qualidade relacionado a características do produto.

<sub>categoria UFO: `goal` · especializa `sro.acceptance_criterion`</sub>

Exemplos: *AC2: A autenticação do pagamento é feita em menos de 10ms.*

#### `sro.sprint_backlog` — Sprint Backlog

*Sprint Backlog*

Documento que descreve o planejamento do sprint: as user stories selecionadas e as tarefas de desenvolvimento pretendidas para materializá-las.

<sub>categoria UFO: `social_object` · especializa `spo.document`</sub>

#### `sro.intended_scrum_development_task` — Intended Scrum Development Task

*Tarefa de Desenvolvimento Pretendida*

Atividade pretendida que descreve o que é necessário para materializar uma user story. Tarefas pretendidas não executadas no sprint podem ser associadas ao sprint backlog de sprints seguintes.

<sub>categoria UFO: `intention` · especializa `spo.intended_project_activity`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
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

- **`sro.epic_composed_of_user_story`** — O destino é sro.user_story, e não sro.atomic_user_story — e um épico é uma user story. Logo a relação é recursiva: um épico pode ter outro épico como parte, em qualquer profundidade. Restringir o destino a user stories atômicas impediria a decomposição em níveis, que é justamente o uso comum de épico em projetos grandes.
Três restrições delimitam a recursão: a hierarquia é acíclica (sro.rule04), todo épico tem ao menos uma parte (sro.rule05), e toda cadeia de decomposição termina em user stories atômicas (sro.rule06). Sem elas, a relação admitiria um épico que é parte de si mesmo e uma decomposição infinita.
- **`sro.sprint_backlog_specifies_intended_task`** — Uma tarefa pretendida pode estar relacionada a vários sprint backlogs quando não foi executada no sprint em que foi planejada.


---

## Scrum Deliverables

<a id="scrum-deliverables"></a>

Resultados produzidos no projeto Scrum. Entregável aceito e não aceito são fases distintas do entregável, e a tarefa que produziu apenas entregáveis aceitos é distinguida da que produziu algum não aceito — é assim que se mede retrabalho sem inventar heurística.

*Fonte: Tese, Seção 3.2.5, Figura 30*

### Conceitos

#### `sro.deliverable` — Deliverable

*Entregável*

Item de software que materializa user stories tratadas em um sprint.

<sub>categoria UFO: `object` · especializa `sys_swo.software_item`</sub>

Exemplos: *a funcionalidade de pagar a passagem com cartão de crédito*

#### `sro.accepted_deliverable` — Accepted Deliverable

*Entregável Aceito*

Entregável em conformidade com os critérios de aceitação das user stories que materializa. Significa que está "done".

<sub>categoria UFO: `phase` · especializa `sro.deliverable`</sub>

#### `sro.not_accepted_deliverable` — Not Accepted Deliverable

*Entregável Não Aceito*

Entregável que não está em conformidade com ao menos um critério de aceitação. As user stories relacionadas podem retornar ao product backlog.

<sub>categoria UFO: `phase` · especializa `sro.deliverable`</sub>

#### `sro.successfully_performed_scrum_development_task` — Successfully Performed Scrum Development Task

*Tarefa Executada com Sucesso*

Tarefa de desenvolvimento executada que produziu apenas entregáveis aceitos.

<sub>categoria UFO: `phase` · especializa `sro.performed_scrum_development_task`</sub>

#### `sro.non_successfully_performed_scrum_development_task` — Non-Successfully Performed Scrum Development Task

*Tarefa Executada sem Sucesso*

Tarefa de desenvolvimento executada que produziu um ou mais entregáveis não aceitos.

<sub>categoria UFO: `phase` · especializa `sro.performed_scrum_development_task`</sub>

#### `sro.sprint_deliverable` — Sprint Deliverable

*Entregável do Sprint*

Item de software mais completo, formado pela integração dos entregáveis aceitos produzidos em um sprint. É o resultado do sprint entregue ao cliente.

<sub>categoria UFO: `object` · especializa `sro.deliverable`</sub>

#### `sro.scrum_project_deliverable` — Scrum Project Deliverable

*Entregável do Projeto Scrum*

Produto de software formado pelo conjunto dos entregáveis de sprint produzidos no projeto. É o entregável final do processo Scrum.

<sub>categoria UFO: `object` · especializa `sys_swo.software_product`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
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

## Perguntas de competência

Perguntas que esta ontologia precisa saber responder. São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.

| # | Pergunta | Conceitos envolvidos |
|---|---|---|
| `CQ01` | Quais processos e atividades compuseram um processo Scrum? | `sro.scrum_process`, `sro.sprint`, `sro.product_backlog_definition`, `sro.ceremony` |
| `CQ02` | Em um projeto Scrum, de quais outras atividades ou processos uma atividade dependeu? | `sro.sprint`, `sro.ceremony`, `sro.performed_scrum_development_task` |
| `CQ03` | Quantos sprints foram executados em um projeto Scrum? | `sro.scrum_process`, `sro.sprint`, `sro.scrum_project` |
| `CQ04` | Quais cerimônias foram executadas em um sprint? | `sro.sprint`, `sro.planning_meeting`, `sro.daily_standup_meeting`, `sro.review_meeting`, … |
| `CQ05` | Quais tarefas de desenvolvimento foram executadas em um sprint? | `sro.sprint`, `sro.performed_scrum_development_task` |
| `CQ06` | Quando um projeto Scrum começou? | `sro.scrum_process`, `sro.scrum_project` |
| `CQ07` | Quando um projeto Scrum terminou? | `sro.scrum_process`, `sro.scrum_project` |
| `CQ08` | Quando um processo Scrum começou? | `sro.scrum_process` |
| `CQ09` | Quando um processo Scrum terminou? | `sro.scrum_process` |
| `CQ10` | Quando uma atividade do projeto Scrum começou? | `sro.ceremony`, `sro.performed_scrum_development_task` |
| `CQ11` | Quando uma atividade do projeto Scrum terminou? | `sro.ceremony`, `sro.performed_scrum_development_task` |
| `CQ12` | Quais papéis estiveram envolvidos em um projeto Scrum? | `sro.scrum_role`, `sro.developer_role`, `sro.scrum_master_role`, `sro.product_owner_role`, … |
| `CQ13` | Quais times estiveram envolvidos em um projeto Scrum? | `sro.scrum_team`, `sro.development_team` |
| `CQ14` | Quais papéis estiveram envolvidos em um time de um projeto Scrum? | `sro.scrum_team`, `sro.development_team`, `sro.scrum_role` |
| `CQ15` | Quem são os membros de um time em um projeto Scrum? | `sro.scrum_team_member`, `sro.developer`, `sro.scrum_master`, `sro.product_owner`, … |
| `CQ16` | Qual papel é desempenhado por um membro de time em um projeto Scrum? | `sro.scrum_team_member`, `sro.scrum_role`, `sro.product_owner_membership`, `sro.scrum_master_membership`, … |
| `CQ17` | Quais stakeholders foram responsáveis pelas cerimônias de um projeto Scrum? | `sro.product_owner`, `sro.scrum_master`, `sro.ceremony` |
| `CQ18` | Quais stakeholders participaram das cerimônias de um projeto Scrum? | `sro.scrum_team`, `sro.development_team`, `sro.client`, `sro.ceremony` |
| `CQ19` | Quais stakeholders foram responsáveis pelas tarefas de desenvolvimento de um projeto Scrum? | `sro.developer`, `sro.performed_scrum_development_task` |
| `CQ20` | Quais stakeholders participaram das tarefas de desenvolvimento de um projeto Scrum? | `sro.developer`, `sro.performed_scrum_development_task` |
| `CQ21` | Quais stakeholders foram responsáveis pelos processos de um projeto Scrum? | `sro.product_owner`, `sro.product_backlog_definition` |
| `CQ22` | Quais stakeholders participaram dos processos de um projeto Scrum? | `sro.client`, `sro.product_backlog_definition`, `sro.performed_scrum_development_task` |
| `CQ23` | Quais user stories foram definidas no product backlog de um projeto Scrum? | `sro.product_backlog`, `sro.user_story`, `sro.epic`, `sro.atomic_user_story` |
| `CQ24` | Qual é a prioridade de uma user story no product backlog de um projeto Scrum? | `sro.user_story` |
| `CQ25` | Como uma user story foi decomposta em outras? | `sro.epic`, `sro.user_story`, `sro.atomic_user_story` |
| `CQ26` | Quais critérios de aceitação foram estabelecidos para uma user story? | `sro.user_story`, `sro.acceptance_criterion`, `sro.functional_acceptance_criterion`, `sro.non_functional_acceptance_criterion` |
| `CQ27` | Quais user stories foram selecionadas para um sprint backlog? | `sro.sprint_backlog`, `sro.user_story` |
| `CQ28` | Quais tarefas de desenvolvimento foram planejadas para materializar uma user story? | `sro.sprint_backlog`, `sro.user_story`, `sro.intended_scrum_development_task` |
| `CQ29` | Quais tarefas de desenvolvimento foram executadas para materializar uma user story? | `sro.performed_scrum_development_task`, `sro.intended_scrum_development_task`, `sro.atomic_user_story` |
| `CQ30` | Quais tarefas de desenvolvimento foram planejadas para um sprint? | `sro.sprint`, `sro.sprint_backlog`, `sro.intended_scrum_development_task` |
| `CQ31` | Quais tarefas de desenvolvimento foram executadas em um sprint? | `sro.sprint`, `sro.performed_scrum_development_task` |
| `CQ32` | Quais tipos de entregáveis foram produzidos em um projeto Scrum? | `sro.deliverable`, `sro.sprint_deliverable`, `sro.accepted_deliverable`, `sro.not_accepted_deliverable` |
| `CQ33` | Quais entregáveis foram produzidos em um sprint? | `sro.sprint`, `sro.performed_scrum_development_task`, `sro.deliverable`, `sro.sprint_deliverable` |
| `CQ34` | Quais entregáveis foram produzidos em um projeto Scrum? | `sro.scrum_process`, `sro.sprint`, `sro.sprint_deliverable`, `sro.scrum_project_deliverable` |
| `CQ35` | Quais user stories um entregável materializou? | `sro.deliverable`, `sro.atomic_user_story` |
| `CQ36` | Quais entregáveis foram aceitos em um sprint? | `sro.accepted_deliverable`, `sro.successfully_performed_scrum_development_task` |
| `CQ37` | Quais tarefas de desenvolvimento produziram entregáveis aceitos? | `sro.successfully_performed_scrum_development_task`, `sro.accepted_deliverable` |

- **CQ04** — Permite ao Scrum Master identificar cerimônia não realizada em um sprint e investigar a causa.
- **CQ15** — Permite identificar alocação e evitar superalocação da mesma pessoa em múltiplos times.
- **CQ37** — Cruzada com CQ31 e CQ33, permite quantificar esforço gasto em entregáveis que não foram aceitos — isto é, retrabalho.


---

[← Rede de ontologias](README.md)

