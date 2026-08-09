<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# CDRO — Continuous Deployment Reference Ontology

> Conceitualização da entrega e da implantação contínuas: a atividade de entrega que produz o código entregue, o processo de implantação que leva o código implantado a um ambiente produtivo, e os servidores e ambientes envolvidos.

| | |
|---|---|
| **Id** | `cdro` |
| **Versão** | 1.0.0 |
| **Camada** | Domínio |
| **Rede** | Continuum |
| **Namespace** | `the_band.ontology.continuum.cdro` |
| **Depende de** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md), [ciro](ciro.md) |
| **Origem** | Tese, Seção 3.4 (Figuras 42 a 44) |

## Módulos

- **[Continuous Delivery Activity](#continuous-delivery-activity)** — Entrega contínua é atividade, não processo: ocorre depois de um teste contínuo bem-sucedido e produz o código entregue. Distinguir entrega de implantação é o que permite medir lead time real até produção.
- **[Continuous Deployment Process](#continuous-deployment-process)** — Processo automatizado que implanta o código implantado em ambiente produtivo e comunica os stakeholders sobre sucesso ou falha.

---

## Continuous Delivery Activity

<a id="continuous-delivery-activity"></a>

Entrega contínua é atividade, não processo: ocorre depois de um teste contínuo bem-sucedido e produz o código entregue. Distinguir entrega de implantação é o que permite medir lead time real até produção.

*Fonte: Tese, Seção 3.4.1, Figura 43*

### Conceitos

#### `cdro.delivery_activity` — Delivery Activity

*Atividade de Entrega*

Atividade executada automatizada, com participação do servidor de entrega contínua, que entregou um código entregue em um ambiente de entrega, sem intervenção humana.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity` · automatizado</sub>

#### `cdro.delivered_code` — Delivered Code

*Código Entregue*

Código candidato testado com sucesso que foi criado em uma atividade de entrega.

<sub>categoria UFO: `role` · papel de `ciro.candidate_code`</sub>

#### `cdro.continuous_delivery_server` — Continuous Delivery Server

*Servidor de Entrega Contínua*

Cópia carregada de sistema de software que fornece os artefatos que participaram da atividade de entrega, permitindo executá-la automaticamente.

<sub>categoria UFO: `disposition` · especializa `sys_swo.loaded_software_system_copy`</sub>

#### `cdro.delivery_environment` — Delivery Environment

*Ambiente de Entrega*

Cópia carregada de sistema de software constituída de recursos de software e hardware de entrega, para apoiar as atividades de entrega.

<sub>categoria UFO: `disposition` · especializa `sys_swo.loaded_software_system_copy`</sub>

#### `cdro.delivery_software_resource` — Delivery Software Resource

*Recurso de Software de Entrega*

Recurso de software que compõe o ambiente de entrega.

<sub>categoria UFO: `role` · especializa `sys_swo.software_resource`</sub>

#### `cdro.delivery_hardware_resource` — Delivery Hardware Resource

*Recurso de Hardware de Entrega*

Recurso de hardware que compõe o ambiente de entrega.

<sub>categoria UFO: `role` · especializa `sys_swo.hardware_resource`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `was performed after` | `cdro.delivery_activity` | `ciro.successful_continuous_test_process` | one → one | dependency |
| `created` | `cdro.delivery_activity` | `cdro.delivered_code` | one → one | association |
| `was performed in` | `cdro.delivery_activity` | `cdro.delivery_environment` | many → one | association |
| `participated in` | `cdro.continuous_delivery_server` | `cdro.delivery_activity` | one → many | participation |



---

## Continuous Deployment Process

<a id="continuous-deployment-process"></a>

Processo automatizado que implanta o código implantado em ambiente produtivo e comunica os stakeholders sobre sucesso ou falha.

*Fonte: Tese, Seção 3.4.2, Figura 44*

### Conceitos

#### `cdro.continuous_deployment_process` — Continuous Deployment Process

*Processo de Implantação Contínua*

Processo executado específico composto e automatizado, com participação de um ou mais servidores de implantação contínua, cujo propósito é implantar um código implantado em um ambiente de implantação sem intervenção humana.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_composite_process` · automatizado</sub>

#### `cdro.deployment_activity` — Deployment Activity

*Atividade de Implantação*

Atividade executada automatizada que implantou um código implantado em um ambiente de implantação.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity` · automatizado</sub>

#### `cdro.deployed_code` — Deployed Code

*Código Implantado*

Papel do código entregue quando é implantado em um ambiente produtivo ou similar.

<sub>categoria UFO: `role` · papel de `cdro.delivered_code`</sub>

#### `cdro.continuous_deployment_feedback_activity` — Continuous Deployment Feedback Activity

*Atividade de Feedback de Implantação*

Atividade executada simples e automatizada que informou a um stakeholder de CD o status do processo de implantação.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity` · automatizado</sub>

#### `cdro.cd_stakeholder` — CD Stakeholder

*Parte Interessada de CD*

Stakeholder que participou ou foi responsável por um processo de implantação contínua, ou que tem interesse em informação sobre ele.

<sub>categoria UFO: `role` · especializa `spo.project_stakeholder`</sub>

#### `cdro.continuous_deployment_server` — Continuous Deployment Server

*Servidor de Implantação Contínua*

Cópia carregada de sistema de software que forneceu os artefatos que participaram do processo de implantação contínua.

<sub>categoria UFO: `disposition` · especializa `sys_swo.loaded_software_system_copy`</sub>

Exemplos: *uma cópia do ArgoCD carregada em um computador*

#### `cdro.deployment_environment` — Deployment Environment

*Ambiente de Implantação*

Cópia carregada de sistema de software que contém os recursos de software e hardware de implantação para apoiar as atividades de implantação.

<sub>categoria UFO: `disposition` · especializa `sys_swo.loaded_software_system_copy`</sub>

#### `cdro.deployment_software_resource` — Deployment Software Resource

*Recurso de Software de Implantação*

Recurso de software que compõe o ambiente de implantação.

<sub>categoria UFO: `role` · especializa `sys_swo.software_resource`</sub>

#### `cdro.deployment_hardware_resource` — Deployment Hardware Resource

*Recurso de Hardware de Implantação*

Recurso de hardware que compõe o ambiente de implantação.

<sub>categoria UFO: `role` · especializa `sys_swo.hardware_resource`</sub>

#### `cdro.successful_continuous_deployment_process` — Successful Continuous Deployment Process

*Processo de Implantação Bem-Sucedido*

Processo de implantação contínua em que o código implantado foi implantado sem problemas.

<sub>categoria UFO: `phase` · especializa `cdro.continuous_deployment_process`</sub>

#### `cdro.unsuccessful_continuous_deployment_process` — Unsuccessful Continuous Deployment Process

*Processo de Implantação Malsucedido*

Processo de implantação contínua que não implantou o código, devido a problema em seus processos ou atividades.

<sub>categoria UFO: `phase` · especializa `cdro.continuous_deployment_process`</sub>

Exemplos: *uma máquina sem recursos adequados para operar o código implantado*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `was composed of` | `cdro.continuous_deployment_process` | `cdro.deployment_activity` | one → one_or_many | part_whole |
| `was composed of` | `cdro.continuous_deployment_process` | `cdro.continuous_deployment_feedback_activity` | one → one_or_many | part_whole |
| `deployed` | `cdro.deployment_activity` | `cdro.deployed_code` | one → one | association |
| `was performed in` | `cdro.deployment_activity` | `cdro.deployment_environment` | many → one | association |
| `participated in` | `cdro.continuous_deployment_server` | `cdro.continuous_deployment_process` | one_or_many → many | participation |
| `informed` | `cdro.continuous_deployment_feedback_activity` | `cdro.cd_stakeholder` | many → many | participation |



---

## Perguntas de competência

Perguntas que esta ontologia precisa saber responder. São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.

| # | Pergunta | Conceitos envolvidos |
|---|---|---|
| `CQ01` | Quando uma atividade de entrega começou? | `cdro.delivery_activity` |
| `CQ02` | Quando uma atividade de entrega terminou? | `cdro.delivery_activity` |
| `CQ03` | Quais artefatos participaram de uma atividade de entrega? | `cdro.delivered_code`, `ciro.candidate_code` |
| `CQ04` | O que é um código entregue? | `cdro.delivered_code`, `ciro.successful_continuous_test_process` |
| `CQ05` | Quais recursos compuseram um ambiente de entrega? | `cdro.delivery_environment`, `cdro.delivery_software_resource`, `cdro.delivery_hardware_resource` |
| `CQ06` | Quais processos e atividades compuseram um processo de CD? | `cdro.continuous_deployment_process`, `cdro.deployment_activity`, `cdro.continuous_deployment_feedback_activity` |
| `CQ07` | No processo de CD, de quais outras atividades ou processos uma atividade dependeu? | `cdro.deployment_activity`, `cdro.delivery_activity` |
| `CQ08` | Quando um processo de CD começou? | `cdro.continuous_deployment_process` |
| `CQ09` | Quando um processo de CD terminou? | `cdro.continuous_deployment_process` |
| `CQ10` | O que é um código implantado? | `cdro.deployed_code`, `cdro.delivered_code` |
| `CQ11` | Quais artefatos participaram do processo de CD? | `cdro.deployed_code`, `cdro.delivered_code` |
| `CQ12` | Quais recursos compuseram um ambiente de implantação? | `cdro.deployment_environment`, `cdro.deployment_software_resource`, `cdro.deployment_hardware_resource` |
| `CQ13` | Quais stakeholders participaram do processo de CD? | `cdro.cd_stakeholder`, `cdro.continuous_deployment_feedback_activity` |



---

[← Rede de ontologias](README.md)

