<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# CIRO — Continuous Integration Reference Ontology

> Conceitualização da Integração Contínua: o processo de CI e seus subprocessos automatizados de build, teste e inspeção, os servidores e ambientes envolvidos, e os papéis que os artefatos assumem no contexto.

| | |
|---|---|
| **Id** | `ciro` |
| **Versão** | 1.0.0 |
| **Camada** | Domínio |
| **Rede** | Continuum |
| **Namespace** | `the_band.ontology.continuum.ciro` |
| **Depende de** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md), [cmpo](cmpo.md), [roost](roost.md), [qapo](qapo.md), [osdef](osdef.md) |
| **Origem** | Tese, Seção 3.3 (Figuras 31 a 41) |

## Módulos

- **[Continuous Integration Process](#continuous-integration-process)** — Visão geral do processo de CI: um processo executado composto e automatizado, classificado pelo tipo de gatilho que o iniciou e pelo desfecho (sucesso ou insucesso). O desfecho é fase do processo, não atributo solto.
- **[Continuous Build Process](#continuous-build-process)** — Atividades, recursos e artefatos do build automatizado. Código candidato é o conceito-chave: reúne o código sob integração (novo ou alterado) e o código já integrado em processos anteriores.
- **[Continuous Test Process](#continuous-test-process)** — Teste automatizado no contexto de CI. O código candidato assume o papel de código a ser testado; o resultado de teste de CI pode descrever faults, e é isso — não a ausência de log — que caracteriza um processo malsucedido.
- **[Continuous Inspection Process](#continuous-inspection-process)** — Inspeção automatizada da aderência do código candidato a critérios de qualidade. O resultado é não conformidade (QAPO), não defeito (OSDEF): transformar uma na outra é decisão explícita, nunca automática.
- **[Interrupted Verification](#interrupted-verification)** — As fases do processo de CI que terminou sem decidir sobre a integração: interrompido por decisão de quem opera, não executado por condição não cumprida, ou encerrado por esgotamento de tempo. Nenhuma delas é malsucedida — a definição de malsucedido exige problema em componente.

---

## Continuous Integration Process

<a id="continuous-integration-process"></a>

Visão geral do processo de CI: um processo executado composto e automatizado, classificado pelo tipo de gatilho que o iniciou e pelo desfecho (sucesso ou insucesso). O desfecho é fase do processo, não atributo solto.

*Fonte: Tese, Seção 3.3.2, Figura 34*

### Conceitos

#### `ciro.continuous_integration_process` — Continuous Integration Process

*Processo de Integração Contínua*

Processo executado específico composto e automatizado que verifica se um novo artefato de software pode ser integrado sem trazer problemas ao código já aprovado, sem intervenção humana.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_composite_process` · automatizado</sub>

#### `ciro.ci_stakeholder` — CI Stakeholder

*Parte Interessada de CI*

Stakeholder interessado em informação sobre um processo de integração contínua.

<sub>categoria UFO: `role` · especializa `spo.project_stakeholder`</sub>

Exemplos: *um desenvolvedor*; *um testador*

#### `ciro.continuous_integration_server` — Continuous Integration Server

*Servidor de Integração Contínua*

Cópia carregada de sistema de software que fornece artefatos que participam do processo de CI, permitindo executá-lo automaticamente.

<sub>categoria UFO: `disposition` · especializa `sys_swo.loaded_software_system_copy`</sub>

Exemplos: *uma cópia do GitLab carregada em um computador*; *GitHub Actions*

#### `ciro.continuous_feedback_activity` — Continuous Feedback Activity

*Atividade de Feedback Contínuo*

Atividade executada simples e automatizada que informa a um stakeholder de CI o status de um processo de CI.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity` · automatizado</sub>

#### `ciro.ci_request_event` — CI Request Event

*Evento de Solicitação de CI*

Evento que ocorre quando um stakeholder executa um comando no servidor de CI para iniciar o processo.

<sub>categoria UFO: `event`</sub>

#### `ciro.check_in_triggered_continuous_integration_process` — Check-in-Triggered Continuous Integration Process

*Processo de CI Disparado por Check-in*

Processo de CI iniciado quando um novo artefato é submetido a um repositório de código.

<sub>categoria UFO: `complex_action` · especializa `ciro.continuous_integration_process`</sub>

#### `ciro.scheduled_continuous_integration_process` — Scheduled Continuous Integration Process

*Processo de CI Agendado*

Processo de CI iniciado quando uma data ou horário específico é alcançado.

<sub>categoria UFO: `complex_action` · especializa `ciro.continuous_integration_process`</sub>

#### `ciro.on_demand_continuous_integration_process` — On-Demand Continuous Integration Process

*Processo de CI Sob Demanda*

Processo de CI iniciado por um evento de solicitação de CI.

<sub>categoria UFO: `complex_action` · especializa `ciro.continuous_integration_process`</sub>

#### `ciro.successful_continuous_integration_process` — Successful Continuous Integration Process

*Processo de CI Bem-Sucedido*

Processo de CI em que o código candidato foi integrado sem problemas.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_integration_process`</sub>

#### `ciro.unsuccessful_continuous_integration_process` — Unsuccessful Continuous Integration Process

*Processo de CI Malsucedido*

Processo de CI que não integrou o código candidato, devido a problema em algum de seus processos ou atividades.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_integration_process`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `was composed of` | `ciro.continuous_integration_process` | `ciro.continuous_build_process` | one → one_or_many | part_whole |
| `was composed of` | `ciro.continuous_integration_process` | `ciro.continuous_test_process` | one → one_or_many | part_whole |
| `was composed of` | `ciro.continuous_integration_process` | `ciro.continuous_inspection_process` | one → many | part_whole |
| `was composed of` | `ciro.continuous_integration_process` | `ciro.continuous_feedback_activity` | one → one_or_many | part_whole |
| `was performed in` | `ciro.continuous_integration_process` | `ciro.continuous_integration_server` | many → one | participation |
| `was triggered by` | `ciro.check_in_triggered_continuous_integration_process` | `cmpo.checkin` | many → one | causation |
| `was triggered by` | `ciro.on_demand_continuous_integration_process` | `ciro.ci_request_event` | one → one | causation |
| `informed` | `ciro.continuous_feedback_activity` | `ciro.ci_stakeholder` | many → many | participation |

- **`ciro.ci_composed_of_inspection`** — A inspeção contínua é opcional no processo de CI.


---

## Continuous Build Process

<a id="continuous-build-process"></a>

Atividades, recursos e artefatos do build automatizado. Código candidato é o conceito-chave: reúne o código sob integração (novo ou alterado) e o código já integrado em processos anteriores.

*Fonte: Tese, Seção 3.3.3, Figuras 35 a 37*

### Conceitos

#### `ciro.continuous_build_process` — Continuous Build Process

*Processo de Build Contínuo*

Processo executado específico e automatizado, com participação do servidor de CI, que constrói uma nova versão do software a ser testada.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_process` · automatizado</sub>

#### `ciro.ci_building_environment` — CI Building Environment

*Ambiente de Build de CI*

Cópia carregada de sistema de software que contém os recursos de software e hardware de build necessários às atividades do processo de build contínuo.

<sub>categoria UFO: `disposition` · especializa `sys_swo.loaded_software_system_copy`</sub>

#### `ciro.building_software_resource` — Building Software Resource

*Recurso de Software de Build*

Produto de software que compõe o ambiente de build.

<sub>categoria UFO: `role` · especializa `sys_swo.software_resource`</sub>

Exemplos: *sistema operacional*; *compilador*; *transpilador*; *interpretador*; *biblioteca*

#### `ciro.building_hardware_resource` — Building Hardware Resource

*Recurso de Hardware de Build*

Equipamento de hardware que compõe o ambiente de build.

<sub>categoria UFO: `role` · especializa `sys_swo.hardware_resource`</sub>

#### `ciro.build_environment_creation` — Build Environment Creation

*Criação do Ambiente de Build*

Atividade que cria o ambiente de build de CI para apoiar o checkout e a construção do código candidato.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity` · automatizado</sub>

#### `ciro.code_checkout` — Code Checkout

*Checkout de Código*

Atividade que cria cópias do código-fonte e do código de teste dentro do ambiente de build de CI.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity` · automatizado</sub>

#### `ciro.source_code_copy` — Source Code Copy

*Cópia de Código-Fonte*

Cópia de um código-fonte presente em um repositório, criada no ambiente de build.

<sub>categoria UFO: `object` · especializa `cmpo.artifact_copy`</sub>

#### `ciro.test_code_copy` — Test Code Copy

*Cópia de Código de Teste*

Cópia de um código de teste presente em um repositório, criada no ambiente de build.

<sub>categoria UFO: `object` · especializa `cmpo.artifact_copy`</sub>

#### `ciro.candidate_code_building` — Candidate Code Building

*Construção do Código Candidato*

Atividade que constrói um código candidato no ambiente de build, usando os recursos de build e as cópias de código-fonte — ou descreve um problema de build.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity` · automatizado</sub>

#### `ciro.candidate_code` — Candidate Code

*Código Candidato*

Coleção de cópias de código composta por um ou mais itens de código sob integração e por nenhum, um ou mais itens de código já integrado.

<sub>categoria UFO: `collective`</sub>

#### `ciro.code_under_integration` — Code Under Integration

*Código sob Integração*

Papel do código novo ou alterado que um stakeholder de CI deseja integrar ao repositório.

<sub>categoria UFO: `role` · papel de `sys_swo.code`</sub>

#### `ciro.integrated_code` — Integrated Code

*Código Integrado*

Papel do código que já foi integrado ao repositório em um processo de CI executado no passado.

<sub>categoria UFO: `role` · papel de `sys_swo.code`</sub>

#### `ciro.build_problem` — Build Problem

*Problema de Build*

Item de informação sobre problemas ocorridos na construção do código candidato.

<sub>categoria UFO: `social_object` · especializa `spo.information_item`</sub>

Exemplos: *referência a biblioteca ausente que impede compilar o projeto*

#### `ciro.successful_continuous_build_process` — Successful Continuous Build Process

*Processo de Build Bem-Sucedido*

Processo de build contínuo que construiu o código candidato sem problemas.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_build_process`</sub>

#### `ciro.unsuccessful_continuous_build_process` — Unsuccessful Continuous Build Process

*Processo de Build Malsucedido*

Processo de build contínuo que não construiu o código candidato devido a um problema.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_build_process`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `was composed of` | `ciro.continuous_build_process` | `ciro.build_environment_creation` | one → one | part_whole |
| `was composed of` | `ciro.continuous_build_process` | `ciro.code_checkout` | one → one | part_whole |
| `was composed of` | `ciro.continuous_build_process` | `ciro.candidate_code_building` | one → one | part_whole |
| `produced` | `ciro.candidate_code_building` | `ciro.candidate_code` | one → one | association |
| `described` | `ciro.candidate_code_building` | `ciro.build_problem` | one → many | association |
| `was composed of` | `ciro.candidate_code` | `ciro.code_under_integration` | one → one_or_many | part_whole |
| `was composed of` | `ciro.candidate_code` | `ciro.integrated_code` | one → many | part_whole |
| `checked out from` | `ciro.code_checkout` | `cmpo.branch` | many → one | association |
| `used` | `ciro.continuous_build_process` | `ciro.ci_building_environment` | many → one | association |



---

## Continuous Test Process

<a id="continuous-test-process"></a>

Teste automatizado no contexto de CI. O código candidato assume o papel de código a ser testado; o resultado de teste de CI pode descrever faults, e é isso — não a ausência de log — que caracteriza um processo malsucedido.

*Fonte: Tese, Seção 3.3.4, Figura 38*

### Conceitos

#### `ciro.continuous_test_process` — Continuous Test Process

*Processo de Teste Contínuo*

Processo de teste automatizado, com participação do servidor de CI, que verifica se a nova versão do software está em conformidade com os requisitos.

<sub>categoria UFO: `complex_action` · especializa `roost.testing_process` · automatizado</sub>

#### `ciro.ci_testing_environment` — CI Testing Environment

*Ambiente de Teste de CI*

Ambiente de teste que é também uma cópia carregada de sistema de software, criada em um servidor de CI para apoiar o processo de teste contínuo.

<sub>categoria UFO: `disposition` · especializa `roost.testing_environment`</sub>

#### `ciro.ci_testing_environment_creation` — CI Testing Environment Creation

*Criação do Ambiente de Teste de CI*

Atividade automatizada que cria o ambiente de teste de CI no servidor de CI.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity` · automatizado</sub>

#### `ciro.automated_testing` — Automated Testing

*Teste Automatizado*

Atividade de teste por nível automatizada, que executa testes usando os recursos de software e hardware do ambiente de teste de CI.

<sub>categoria UFO: `complex_action` · especializa `roost.level_based_testing` · automatizado</sub>

#### `ciro.automated_test_execution` — Automated Test Execution

*Execução Automatizada de Teste*

Execução de teste que roda automaticamente os casos de teste por meio do código de teste, produzindo resultados de teste de CI.

<sub>categoria UFO: `action` · especializa `roost.performed_test_execution` · automatizado</sub>

#### `ciro.candidate_code_to_be_tested` — Candidate Code To Be Tested

*Código Candidato a Ser Testado*

Papel assumido pelo código candidato quando é alvo de um processo de teste contínuo.

<sub>categoria UFO: `role` · especializa `roost.code_to_be_tested` · papel de `ciro.candidate_code`</sub>

#### `ciro.ci_test_result` — CI Test Result

*Resultado de Teste de CI*

Resultado de teste que descreve o observado ao aplicar um caso de teste em um processo de teste contínuo. Pode identificar faults ou servir de evidência de sucesso quando nenhum é observado.

<sub>categoria UFO: `social_object` · especializa `roost.test_result`</sub>

#### `ciro.successful_continuous_test_process` — Successful Continuous Test Process

*Processo de Teste Contínuo Bem-Sucedido*

Processo de teste contínuo cuja execução automatizada produziu resultado sem faults, após aplicar todos os casos de teste.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_test_process`</sub>

#### `ciro.unsuccessful_continuous_test_process` — Unsuccessful Continuous Test Process

*Processo de Teste Contínuo Malsucedido*

Processo de teste contínuo em que um fault foi identificado em um caso de teste.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_test_process`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `was composed of` | `ciro.continuous_test_process` | `ciro.ci_testing_environment_creation` | one → one | part_whole |
| `was composed of` | `ciro.continuous_test_process` | `ciro.automated_testing` | one → one_or_many | part_whole |
| `was composed of` | `ciro.automated_testing` | `ciro.automated_test_execution` | one → one_or_many | part_whole |
| `tested` | `ciro.automated_test_execution` | `ciro.candidate_code_to_be_tested` | many → one | association |
| `produced` | `ciro.automated_test_execution` | `ciro.ci_test_result` | one → one | association |
| `described` | `ciro.ci_test_result` | `osdef.fault` | one → many | association |



---

## Continuous Inspection Process

<a id="continuous-inspection-process"></a>

Inspeção automatizada da aderência do código candidato a critérios de qualidade. O resultado é não conformidade (QAPO), não defeito (OSDEF): transformar uma na outra é decisão explícita, nunca automática.

*Fonte: Tese, Seção 3.3.5, Figuras 39 a 41*

### Conceitos

#### `ciro.continuous_inspection_process` — Continuous Inspection Process

*Processo de Inspeção Contínua*

Processo de garantia da qualidade automatizado, com participação do servidor de CI, que assegura que os artefatos estejam em conformidade com critérios de qualidade de engenharia de software.

<sub>categoria UFO: `complex_action` · especializa `qapo.quality_assurance_process` · automatizado</sub>

#### `ciro.ci_inspection_environment` — CI Inspection Environment

*Ambiente de Inspeção de CI*

Cópia carregada de sistema de software que contém os recursos de inspeção necessários às atividades do processo de inspeção contínua.

<sub>categoria UFO: `disposition` · especializa `sys_swo.loaded_software_system_copy`</sub>

#### `ciro.inspection_software_resource` — Inspection Software Resource

*Recurso de Software de Inspeção*

Produto de software que compõe o ambiente de inspeção.

<sub>categoria UFO: `role` · especializa `sys_swo.software_resource`</sub>

Exemplos: *uma ferramenta de análise estática de código*

#### `ciro.inspection_hardware_resource` — Inspection Hardware Resource

*Recurso de Hardware de Inspeção*

Equipamento de hardware que compõe o ambiente de inspeção.

<sub>categoria UFO: `role` · especializa `sys_swo.hardware_resource`</sub>

#### `ciro.static_code_analysis_tool` — Static Code Analysis Tool

*Ferramenta de Análise Estática*

Produto de software usado para sinalizar erros de programação, bugs, erros de estilo e construções suspeitas.

<sub>categoria UFO: `object` · especializa `sys_swo.software_product`</sub>

Exemplos: *SonarQube*; *Credo*; *ESLint*

#### `ciro.inspection_environment_creation` — Inspection Environment Creation

*Criação do Ambiente de Inspeção*

Atividade que cria o ambiente de inspeção de CI no servidor de CI.

<sub>categoria UFO: `action` · especializa `spo.performed_project_activity` · automatizado</sub>

#### `ciro.automated_adherence_inspection` — Automated Adherence Inspection

*Inspeção de Aderência Automatizada*

Avaliação de aderência automatizada que inspeciona a aderência do código candidato sob inspeção executando inspeções automatizadas de artefato.

<sub>categoria UFO: `complex_action` · especializa `qapo.adherence_evaluation` · automatizado</sub>

#### `ciro.automated_artifact_inspection` — Automated Artifact Inspection

*Inspeção de Artefato Automatizada*

Avaliação de artefato automatizada que usa código de critério de qualidade para inspecionar critérios em cada artefato do código candidato.

<sub>categoria UFO: `action` · especializa `qapo.artifact_evaluation` · automatizado</sub>

#### `ciro.quality_assurance_criterion_code` — Quality Assurance Criterion Code

*Código de Critério de Qualidade*

Código que materializa um critério de qualidade, tornando-o verificável automaticamente.

<sub>categoria UFO: `object` · especializa `sys_swo.code`</sub>

Exemplos: *uma regra que implementa 'uma função pode ter no máximo 100 linhas'*

#### `ciro.candidate_code_under_inspection` — Candidate Code Under Inspection

*Código Candidato sob Inspeção*

Papel do código candidato cujos artefatos são artefatos avaliados em um processo de inspeção contínua.

<sub>categoria UFO: `role` · especializa `qapo.evaluated_artifact` · papel de `ciro.candidate_code`</sub>

#### `ciro.ci_evaluation_report` — CI Evaluation Report

*Relatório de Avaliação de CI*

Relatório de avaliação que descreve os resultados da inspeção e as questões identificadas no código candidato sob inspeção.

<sub>categoria UFO: `social_object` · especializa `qapo.evaluation_report`</sub>

#### `ciro.successful_continuous_inspection_process` — Successful Continuous Inspection Process

*Processo de Inspeção Bem-Sucedido*

Processo de inspeção contínua em que nenhuma não conformidade foi identificada.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_inspection_process`</sub>

#### `ciro.unsuccessful_continuous_inspection_process` — Unsuccessful Continuous Inspection Process

*Processo de Inspeção Malsucedido*

Processo de inspeção contínua em que ao menos uma não conformidade foi identificada.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_inspection_process`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `was composed of` | `ciro.continuous_inspection_process` | `ciro.inspection_environment_creation` | one → one | part_whole |
| `was composed of` | `ciro.continuous_inspection_process` | `ciro.automated_adherence_inspection` | one → one_or_many | part_whole |
| `was composed of` | `ciro.automated_adherence_inspection` | `ciro.automated_artifact_inspection` | one → one_or_many | part_whole |
| `used` | `ciro.automated_artifact_inspection` | `ciro.quality_assurance_criterion_code` | many → one_or_many | association |
| `materialized` | `ciro.quality_assurance_criterion_code` | `qapo.quality_criterion` | one → one | materialization |
| `produced` | `ciro.automated_adherence_inspection` | `ciro.ci_evaluation_report` | one → one | association |
| `registered` | `ciro.automated_artifact_inspection` | `qapo.noncompliance_register` | one → many | association |



---

## Interrupted Verification

<a id="interrupted-verification"></a>

As fases do processo de CI que terminou sem decidir sobre a integração: interrompido por decisão de quem opera, não executado por condição não cumprida, ou encerrado por esgotamento de tempo. Nenhuma delas é malsucedida — a definição de malsucedido exige problema em componente.

*Fonte: Issue #401; decidido ao desenhar a tela de verificação contínua*

### Conceitos

#### `ciro.interrupted_continuous_integration_process` — Interrupted Continuous Integration Process

*Processo de CI Interrompido*

Processo de CI encerrado por decisão de um stakeholder antes de concluir a verificação. Não integrou o código candidato e **não encontrou problema nele** — a decisão de parar é externa ao código. Contá-lo como malsucedido atribuiria ao código uma falha que foi escolha de quem opera.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_integration_process`</sub>

Exemplos: *execução cancelada porque um commit mais novo a tornou obsoleta*; *cancelamento manual*

#### `ciro.unperformed_continuous_integration_process` — Unperformed Continuous Integration Process

*Processo de CI Não Executado*

Processo de CI que foi disparado e **não executou**, porque a condição declarada para sua execução não se cumpriu. Nada foi verificado — e é diferente de nunca ter sido disparado: o gatilho ocorreu, e é isso que esta fase registra.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_integration_process`</sub>

Exemplos: *job pulado porque o anterior falhou*; *condição `if` do workflow não satisfeita*

#### `ciro.expired_continuous_integration_process` — Expired Continuous Integration Process

*Processo de CI Expirado*

Processo de CI encerrado por esgotamento do tempo declarado, sem concluir a verificação. **É o mais ambíguo dos três e tem fase própria por isso**: pode ser problema no código (laço infinito, teste que trava) ou limite mal dimensionado — e a plataforma não sabe qual. Fase separada é o que permite contá-lo à parte em vez de escolher um lado.

<sub>categoria UFO: `phase` · especializa `ciro.continuous_integration_process`</sub>


---

## Perguntas de competência

Perguntas que esta ontologia precisa saber responder. São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.

| # | Pergunta | Conceitos envolvidos |
|---|---|---|
| `CQ01` | Quais processos e atividades compuseram um processo de CI? | `ciro.continuous_integration_process`, `ciro.continuous_build_process`, `ciro.continuous_test_process`, `ciro.continuous_inspection_process`, … |
| `CQ02` | No processo de CI, de quais outras atividades ou processos uma atividade dependeu? | `ciro.build_environment_creation`, `ciro.code_checkout`, `ciro.candidate_code_building` |
| `CQ03` | Quando um processo de CI começou? | `ciro.continuous_integration_process` |
| `CQ04` | Quando um processo de CI terminou? | `ciro.continuous_integration_process` |
| `CQ05` | Quais artefatos participaram do processo de CI? | `ciro.candidate_code`, `ciro.source_code_copy`, `ciro.test_code_copy`, `ciro.build_problem`, … |
| `CQ06` | Quais stakeholders participaram do processo de CI? | `ciro.ci_stakeholder`, `ciro.continuous_feedback_activity` |
| `CQ07` | Que tipo de evento disparou o processo de CI? | `ciro.check_in_triggered_continuous_integration_process`, `ciro.scheduled_continuous_integration_process`, `ciro.on_demand_continuous_integration_process`, `ciro.ci_request_event` |
| `CQ08` | Quais atividades compuseram um processo de build contínuo? | `ciro.continuous_build_process`, `ciro.build_environment_creation`, `ciro.code_checkout`, `ciro.candidate_code_building` |
| `CQ09` | Quais recursos foram usados para construir os artefatos durante o build contínuo? | `ciro.ci_building_environment`, `ciro.building_software_resource`, `ciro.building_hardware_resource` |
| `CQ10` | Quais artefatos foram criados durante o processo de build contínuo? | `ciro.candidate_code`, `ciro.source_code_copy`, `ciro.test_code_copy`, `ciro.build_problem` |
| `CQ11` | Quais processos e atividades compuseram um processo de teste contínuo? | `ciro.continuous_test_process`, `ciro.ci_testing_environment_creation`, `ciro.automated_testing`, `ciro.automated_test_execution` |
| `CQ12` | Quais testes automáticos foram executados? | `ciro.automated_test_execution`, `roost.test_case`, `ciro.ci_test_result` |
| `CQ13` | Quais processos e atividades compuseram um processo de inspeção contínua? | `ciro.continuous_inspection_process`, `ciro.inspection_environment_creation`, `ciro.automated_adherence_inspection`, `ciro.automated_artifact_inspection` |
| `CQ14` | Qual artefato do projeto ficou em (não) conformidade com os requisitos de qualidade? | `ciro.candidate_code_under_inspection`, `qapo.noncompliance_register`, `ciro.ci_evaluation_report` |



---

[← Rede de ontologias](README.md)

