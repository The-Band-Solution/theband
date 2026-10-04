<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# CDRO — Continuous Deployment Reference Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **40 of 40** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Conceitualização da entrega e da implantação contínuas: a atividade de entrega que produz o código entregue, o processo de implantação que leva o código implantado a um ambiente produtivo, e os servidores e ambientes envolvidos.

| | |
|---|---|
| **Id** | `cdro` |
| **Version** | 1.0.0 |
| **Layer** | Domain |
| **Network** | Continuum |
| **Namespace** | `the_band.ontology.continuum.cdro` |
| **Depends on** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md), [ciro](ciro.md) |
| **Origin** | `pt-BR` Tese, Seção 3.4 (Figuras 42 a 44) |

## Modules

- **[Continuous Delivery Activity](#continuous-delivery-activity)** — `pt-BR` Entrega contínua é atividade, não processo: ocorre depois de um teste contínuo bem-sucedido e produz o código entregue. Distinguir entrega de implantação é o que permite medir lead time real até produção.
- **[Continuous Deployment Process](#continuous-deployment-process)** — `pt-BR` Processo automatizado que implanta o código implantado em ambiente produtivo e comunica os stakeholders sobre sucesso ou falha.

---

## Continuous Delivery Activity

<a id="continuous-delivery-activity"></a>

`pt-BR` Entrega contínua é atividade, não processo: ocorre depois de um teste contínuo bem-sucedido e produz o código entregue. Distinguir entrega de implantação é o que permite medir lead time real até produção.

*Source: `pt-BR` Tese, Seção 3.4.1, Figura 43*

### Concepts

#### `cdro.delivery_activity` — Delivery Activity

*pt-BR: Atividade de Entrega*

`pt-BR` Atividade executada automatizada, com participação do servidor de entrega contínua, que entregou um código entregue em um ambiente de entrega, sem intervenção humana.

<sub>UFO category: `action` · specializes `spo.performed_project_activity` · automated</sub>

#### `cdro.delivered_code` — Delivered Code

*pt-BR: Código Entregue*

`pt-BR` Código candidato testado com sucesso que foi criado em uma atividade de entrega.

<sub>UFO category: `role` · role of `ciro.candidate_code`</sub>

#### `cdro.continuous_delivery_server` — Continuous Delivery Server

*pt-BR: Servidor de Entrega Contínua*

`pt-BR` Cópia carregada de sistema de software que fornece os artefatos que participaram da atividade de entrega, permitindo executá-la automaticamente.

<sub>UFO category: `disposition` · specializes `sys_swo.loaded_software_system_copy`</sub>

#### `cdro.delivery_environment` — Delivery Environment

*pt-BR: Ambiente de Entrega*

`pt-BR` Cópia carregada de sistema de software constituída de recursos de software e hardware de entrega, para apoiar as atividades de entrega.

<sub>UFO category: `disposition` · specializes `sys_swo.loaded_software_system_copy`</sub>

#### `cdro.delivery_software_resource` — Delivery Software Resource

*pt-BR: Recurso de Software de Entrega*

`pt-BR` Recurso de software que compõe o ambiente de entrega.

<sub>UFO category: `role` · specializes `sys_swo.software_resource`</sub>

#### `cdro.delivery_hardware_resource` — Delivery Hardware Resource

*pt-BR: Recurso de Hardware de Entrega*

`pt-BR` Recurso de hardware que compõe o ambiente de entrega.

<sub>UFO category: `role` · specializes `sys_swo.hardware_resource`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `was performed after` | `cdro.delivery_activity` | `ciro.successful_continuous_test_process` | one → one | dependency |
| `created` | `cdro.delivery_activity` | `cdro.delivered_code` | one → one | association |
| `was performed in` | `cdro.delivery_activity` | `cdro.delivery_environment` | many → one | association |
| `participated in` | `cdro.continuous_delivery_server` | `cdro.delivery_activity` | one → many | participation |



---

## Continuous Deployment Process

<a id="continuous-deployment-process"></a>

`pt-BR` Processo automatizado que implanta o código implantado em ambiente produtivo e comunica os stakeholders sobre sucesso ou falha.

*Source: `pt-BR` Tese, Seção 3.4.2, Figura 44*

### Concepts

#### `cdro.continuous_deployment_process` — Continuous Deployment Process

*pt-BR: Processo de Implantação Contínua*

`pt-BR` Processo executado específico composto e automatizado, com participação de um ou mais servidores de implantação contínua, cujo propósito é implantar um código implantado em um ambiente de implantação sem intervenção humana.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_composite_process` · automated</sub>

#### `cdro.deployment_activity` — Deployment Activity

*pt-BR: Atividade de Implantação*

`pt-BR` Atividade executada automatizada que implantou um código implantado em um ambiente de implantação.

<sub>UFO category: `action` · specializes `spo.performed_project_activity` · automated</sub>

#### `cdro.deployed_code` — Deployed Code

*pt-BR: Código Implantado*

`pt-BR` Papel do código entregue quando é implantado em um ambiente produtivo ou similar.

<sub>UFO category: `role` · role of `cdro.delivered_code`</sub>

#### `cdro.continuous_deployment_feedback_activity` — Continuous Deployment Feedback Activity

*pt-BR: Atividade de Feedback de Implantação*

`pt-BR` Atividade executada simples e automatizada que informou a um stakeholder de CD o status do processo de implantação.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity` · automated</sub>

#### `cdro.cd_stakeholder` — CD Stakeholder

*pt-BR: Parte Interessada de CD*

`pt-BR` Stakeholder que participou ou foi responsável por um processo de implantação contínua, ou que tem interesse em informação sobre ele.

<sub>UFO category: `role` · specializes `spo.project_stakeholder`</sub>

#### `cdro.continuous_deployment_server` — Continuous Deployment Server

*pt-BR: Servidor de Implantação Contínua*

`pt-BR` Cópia carregada de sistema de software que forneceu os artefatos que participaram do processo de implantação contínua.

<sub>UFO category: `disposition` · specializes `sys_swo.loaded_software_system_copy`</sub>

Examples: `pt-BR` *uma cópia do ArgoCD carregada em um computador*

#### `cdro.deployment_environment` — Deployment Environment

*pt-BR: Ambiente de Implantação*

`pt-BR` Cópia carregada de sistema de software que contém os recursos de software e hardware de implantação para apoiar as atividades de implantação.

<sub>UFO category: `disposition` · specializes `sys_swo.loaded_software_system_copy`</sub>

#### `cdro.deployment_software_resource` — Deployment Software Resource

*pt-BR: Recurso de Software de Implantação*

`pt-BR` Recurso de software que compõe o ambiente de implantação.

<sub>UFO category: `role` · specializes `sys_swo.software_resource`</sub>

#### `cdro.deployment_hardware_resource` — Deployment Hardware Resource

*pt-BR: Recurso de Hardware de Implantação*

`pt-BR` Recurso de hardware que compõe o ambiente de implantação.

<sub>UFO category: `role` · specializes `sys_swo.hardware_resource`</sub>

#### `cdro.successful_continuous_deployment_process` — Successful Continuous Deployment Process

*pt-BR: Processo de Implantação Bem-Sucedido*

`pt-BR` Processo de implantação contínua em que o código implantado foi implantado sem problemas.

<sub>UFO category: `phase` · specializes `cdro.continuous_deployment_process`</sub>

#### `cdro.unsuccessful_continuous_deployment_process` — Unsuccessful Continuous Deployment Process

*pt-BR: Processo de Implantação Malsucedido*

`pt-BR` Processo de implantação contínua que não implantou o código, devido a problema em seus processos ou atividades.

<sub>UFO category: `phase` · specializes `cdro.continuous_deployment_process`</sub>

Examples: `pt-BR` *uma máquina sem recursos adequados para operar o código implantado*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `was composed of` | `cdro.continuous_deployment_process` | `cdro.deployment_activity` | one → one_or_many | part_whole |
| `was composed of` | `cdro.continuous_deployment_process` | `cdro.continuous_deployment_feedback_activity` | one → one_or_many | part_whole |
| `deployed` | `cdro.deployment_activity` | `cdro.deployed_code` | one → one | association |
| `was performed in` | `cdro.deployment_activity` | `cdro.deployment_environment` | many → one | association |
| `participated in` | `cdro.continuous_deployment_server` | `cdro.continuous_deployment_process` | one_or_many → many | participation |
| `informed` | `cdro.continuous_deployment_feedback_activity` | `cdro.cd_stakeholder` | many → many | participation |



---

## Competency questions

Questions this ontology must be able to answer. They are the model's functional requirements, checked by `mix knowledge.test`.

| # | Question | Concepts involved |
|---|---|---|
| `CQ01` | `pt-BR` Quando uma atividade de entrega começou? | `cdro.delivery_activity` |
| `CQ02` | `pt-BR` Quando uma atividade de entrega terminou? | `cdro.delivery_activity` |
| `CQ03` | `pt-BR` Quais artefatos participaram de uma atividade de entrega? | `cdro.delivered_code`, `ciro.candidate_code` |
| `CQ04` | `pt-BR` O que é um código entregue? | `cdro.delivered_code`, `ciro.successful_continuous_test_process` |
| `CQ05` | `pt-BR` Quais recursos compuseram um ambiente de entrega? | `cdro.delivery_environment`, `cdro.delivery_software_resource`, `cdro.delivery_hardware_resource` |
| `CQ06` | `pt-BR` Quais processos e atividades compuseram um processo de CD? | `cdro.continuous_deployment_process`, `cdro.deployment_activity`, `cdro.continuous_deployment_feedback_activity` |
| `CQ07` | `pt-BR` No processo de CD, de quais outras atividades ou processos uma atividade dependeu? | `cdro.deployment_activity`, `cdro.delivery_activity` |
| `CQ08` | `pt-BR` Quando um processo de CD começou? | `cdro.continuous_deployment_process` |
| `CQ09` | `pt-BR` Quando um processo de CD terminou? | `cdro.continuous_deployment_process` |
| `CQ10` | `pt-BR` O que é um código implantado? | `cdro.deployed_code`, `cdro.delivered_code` |
| `CQ11` | `pt-BR` Quais artefatos participaram do processo de CD? | `cdro.deployed_code`, `cdro.delivered_code` |
| `CQ12` | `pt-BR` Quais recursos compuseram um ambiente de implantação? | `cdro.deployment_environment`, `cdro.deployment_software_resource`, `cdro.deployment_hardware_resource` |
| `CQ13` | `pt-BR` Quais stakeholders participaram do processo de CD? | `cdro.cd_stakeholder`, `cdro.continuous_deployment_feedback_activity` |



---

[← Ontology network](README.md)

