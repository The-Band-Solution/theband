<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# CIRO — Continuous Integration Reference Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **91 of 91** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Conceitualização da Integração Contínua: o processo de CI e seus subprocessos automatizados de build, teste e inspeção, os servidores e ambientes envolvidos, e os papéis que os artefatos assumem no contexto.

| | |
|---|---|
| **Id** | `ciro` |
| **Version** | 1.0.0 |
| **Layer** | Domain |
| **Network** | Continuum |
| **Namespace** | `the_band.ontology.continuum.ciro` |
| **Depends on** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md), [cmpo](cmpo.md), [roost](roost.md), [qapo](qapo.md), [osdef](osdef.md) |
| **Origin** | `pt-BR` Tese, Seção 3.3 (Figuras 31 a 41) |

## Modules

- **[Continuous Integration Process](#continuous-integration-process)** — `pt-BR` Visão geral do processo de CI: um processo executado composto e automatizado, classificado pelo tipo de gatilho que o iniciou e pelo desfecho (sucesso ou insucesso). O desfecho é fase do processo, não atributo solto.
- **[Continuous Build Process](#continuous-build-process)** — `pt-BR` Atividades, recursos e artefatos do build automatizado. Código candidato é o conceito-chave: reúne o código sob integração (novo ou alterado) e o código já integrado em processos anteriores.
- **[Continuous Test Process](#continuous-test-process)** — `pt-BR` Teste automatizado no contexto de CI. O código candidato assume o papel de código a ser testado; o resultado de teste de CI pode descrever faults, e é isso — não a ausência de log — que caracteriza um processo malsucedido.
- **[Continuous Inspection Process](#continuous-inspection-process)** — `pt-BR` Inspeção automatizada da aderência do código candidato a critérios de qualidade. O resultado é não conformidade (QAPO), não defeito (OSDEF): transformar uma na outra é decisão explícita, nunca automática.
- **[Interrupted Verification](#interrupted-verification)** — `pt-BR` As fases do processo de CI que terminou sem decidir sobre a integração: interrompido por decisão de quem opera, não executado por condição não cumprida, ou encerrado por esgotamento de tempo. Nenhuma delas é malsucedida — a definição de malsucedido exige problema em componente.

---

## Continuous Integration Process

<a id="continuous-integration-process"></a>

`pt-BR` Visão geral do processo de CI: um processo executado composto e automatizado, classificado pelo tipo de gatilho que o iniciou e pelo desfecho (sucesso ou insucesso). O desfecho é fase do processo, não atributo solto.

*Source: `pt-BR` Tese, Seção 3.3.2, Figura 34*

### Concepts

#### `ciro.continuous_integration_process` — Continuous Integration Process

*pt-BR: Processo de Integração Contínua*

`pt-BR` Processo executado específico composto e automatizado que verifica se um novo artefato de software pode ser integrado sem trazer problemas ao código já aprovado, sem intervenção humana.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_composite_process` · automated</sub>

#### `ciro.ci_stakeholder` — CI Stakeholder

*pt-BR: Parte Interessada de CI*

`pt-BR` Stakeholder interessado em informação sobre um processo de integração contínua.

<sub>UFO category: `role` · specializes `spo.project_stakeholder`</sub>

Examples: `pt-BR` *um desenvolvedor*; *um testador*

#### `ciro.continuous_integration_server` — Continuous Integration Server

*pt-BR: Servidor de Integração Contínua*

`pt-BR` Cópia carregada de sistema de software que fornece artefatos que participam do processo de CI, permitindo executá-lo automaticamente.

<sub>UFO category: `disposition` · specializes `sys_swo.loaded_software_system_copy`</sub>

Examples: `pt-BR` *uma cópia do GitLab carregada em um computador*; *GitHub Actions*

#### `ciro.continuous_feedback_activity` — Continuous Feedback Activity

*pt-BR: Atividade de Feedback Contínuo*

`pt-BR` Atividade executada simples e automatizada que informa a um stakeholder de CI o status de um processo de CI.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity` · automated</sub>

#### `ciro.ci_request_event` — CI Request Event

*pt-BR: Evento de Solicitação de CI*

`pt-BR` Evento que ocorre quando um stakeholder executa um comando no servidor de CI para iniciar o processo.

<sub>UFO category: `event`</sub>

#### `ciro.check_in_triggered_continuous_integration_process` — Check-in-Triggered Continuous Integration Process

*pt-BR: Processo de CI Disparado por Check-in*

`pt-BR` Processo de CI iniciado quando um novo artefato é submetido a um repositório de código.

<sub>UFO category: `complex_action` · specializes `ciro.continuous_integration_process`</sub>

#### `ciro.scheduled_continuous_integration_process` — Scheduled Continuous Integration Process

*pt-BR: Processo de CI Agendado*

`pt-BR` Processo de CI iniciado quando uma data ou horário específico é alcançado.

<sub>UFO category: `complex_action` · specializes `ciro.continuous_integration_process`</sub>

#### `ciro.on_demand_continuous_integration_process` — On-Demand Continuous Integration Process

*pt-BR: Processo de CI Sob Demanda*

`pt-BR` Processo de CI iniciado por um evento de solicitação de CI.

<sub>UFO category: `complex_action` · specializes `ciro.continuous_integration_process`</sub>

#### `ciro.successful_continuous_integration_process` — Successful Continuous Integration Process

*pt-BR: Processo de CI Bem-Sucedido*

`pt-BR` Processo de CI em que o código candidato foi integrado sem problemas.

<sub>UFO category: `phase` · specializes `ciro.continuous_integration_process`</sub>

#### `ciro.unsuccessful_continuous_integration_process` — Unsuccessful Continuous Integration Process

*pt-BR: Processo de CI Malsucedido*

`pt-BR` Processo de CI que não integrou o código candidato, devido a problema em algum de seus processos ou atividades.

<sub>UFO category: `phase` · specializes `ciro.continuous_integration_process`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `was composed of` | `ciro.continuous_integration_process` | `ciro.continuous_build_process` | one → one_or_many | part_whole |
| `was composed of` | `ciro.continuous_integration_process` | `ciro.continuous_test_process` | one → one_or_many | part_whole |
| `was composed of` | `ciro.continuous_integration_process` | `ciro.continuous_inspection_process` | one → many | part_whole |
| `was composed of` | `ciro.continuous_integration_process` | `ciro.continuous_feedback_activity` | one → one_or_many | part_whole |
| `was performed in` | `ciro.continuous_integration_process` | `ciro.continuous_integration_server` | many → one | participation |
| `was triggered by` | `ciro.check_in_triggered_continuous_integration_process` | `cmpo.checkin` | many → one | causation |
| `was triggered by` | `ciro.on_demand_continuous_integration_process` | `ciro.ci_request_event` | one → one | causation |
| `informed` | `ciro.continuous_feedback_activity` | `ciro.ci_stakeholder` | many → many | participation |

- **`ciro.ci_composed_of_inspection`** — `pt-BR` A inspeção contínua é opcional no processo de CI.


---

## Continuous Build Process

<a id="continuous-build-process"></a>

`pt-BR` Atividades, recursos e artefatos do build automatizado. Código candidato é o conceito-chave: reúne o código sob integração (novo ou alterado) e o código já integrado em processos anteriores.

*Source: `pt-BR` Tese, Seção 3.3.3, Figuras 35 a 37*

### Concepts

#### `ciro.continuous_build_process` — Continuous Build Process

*pt-BR: Processo de Build Contínuo*

`pt-BR` Processo executado específico e automatizado, com participação do servidor de CI, que constrói uma nova versão do software a ser testada.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_process` · automated</sub>

#### `ciro.ci_building_environment` — CI Building Environment

*pt-BR: Ambiente de Build de CI*

`pt-BR` Cópia carregada de sistema de software que contém os recursos de software e hardware de build necessários às atividades do processo de build contínuo.

<sub>UFO category: `disposition` · specializes `sys_swo.loaded_software_system_copy`</sub>

#### `ciro.building_software_resource` — Building Software Resource

*pt-BR: Recurso de Software de Build*

`pt-BR` Produto de software que compõe o ambiente de build.

<sub>UFO category: `role` · specializes `sys_swo.software_resource`</sub>

Examples: `pt-BR` *sistema operacional*; *compilador*; *transpilador*; *interpretador*; *biblioteca*

#### `ciro.building_hardware_resource` — Building Hardware Resource

*pt-BR: Recurso de Hardware de Build*

`pt-BR` Equipamento de hardware que compõe o ambiente de build.

<sub>UFO category: `role` · specializes `sys_swo.hardware_resource`</sub>

#### `ciro.build_environment_creation` — Build Environment Creation

*pt-BR: Criação do Ambiente de Build*

`pt-BR` Atividade que cria o ambiente de build de CI para apoiar o checkout e a construção do código candidato.

<sub>UFO category: `action` · specializes `spo.performed_project_activity` · automated</sub>

#### `ciro.code_checkout` — Code Checkout

*pt-BR: Checkout de Código*

`pt-BR` Atividade que cria cópias do código-fonte e do código de teste dentro do ambiente de build de CI.

<sub>UFO category: `action` · specializes `spo.performed_project_activity` · automated</sub>

#### `ciro.source_code_copy` — Source Code Copy

*pt-BR: Cópia de Código-Fonte*

`pt-BR` Cópia de um código-fonte presente em um repositório, criada no ambiente de build.

<sub>UFO category: `object` · specializes `cmpo.artifact_copy`</sub>

#### `ciro.test_code_copy` — Test Code Copy

*pt-BR: Cópia de Código de Teste*

`pt-BR` Cópia de um código de teste presente em um repositório, criada no ambiente de build.

<sub>UFO category: `object` · specializes `cmpo.artifact_copy`</sub>

#### `ciro.candidate_code_building` — Candidate Code Building

*pt-BR: Construção do Código Candidato*

`pt-BR` Atividade que constrói um código candidato no ambiente de build, usando os recursos de build e as cópias de código-fonte — ou descreve um problema de build.

<sub>UFO category: `action` · specializes `spo.performed_project_activity` · automated</sub>

#### `ciro.candidate_code` — Candidate Code

*pt-BR: Código Candidato*

`pt-BR` Coleção de cópias de código composta por um ou mais itens de código sob integração e por nenhum, um ou mais itens de código já integrado.

<sub>UFO category: `collective`</sub>

#### `ciro.code_under_integration` — Code Under Integration

*pt-BR: Código sob Integração*

`pt-BR` Papel do código novo ou alterado que um stakeholder de CI deseja integrar ao repositório.

<sub>UFO category: `role` · role of `sys_swo.code`</sub>

#### `ciro.integrated_code` — Integrated Code

*pt-BR: Código Integrado*

`pt-BR` Papel do código que já foi integrado ao repositório em um processo de CI executado no passado.

<sub>UFO category: `role` · role of `sys_swo.code`</sub>

#### `ciro.build_problem` — Build Problem

*pt-BR: Problema de Build*

`pt-BR` Item de informação sobre problemas ocorridos na construção do código candidato.

<sub>UFO category: `social_object` · specializes `spo.information_item`</sub>

Examples: `pt-BR` *referência a biblioteca ausente que impede compilar o projeto*

#### `ciro.successful_continuous_build_process` — Successful Continuous Build Process

*pt-BR: Processo de Build Bem-Sucedido*

`pt-BR` Processo de build contínuo que construiu o código candidato sem problemas.

<sub>UFO category: `phase` · specializes `ciro.continuous_build_process`</sub>

#### `ciro.unsuccessful_continuous_build_process` — Unsuccessful Continuous Build Process

*pt-BR: Processo de Build Malsucedido*

`pt-BR` Processo de build contínuo que não construiu o código candidato devido a um problema.

<sub>UFO category: `phase` · specializes `ciro.continuous_build_process`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
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

`pt-BR` Teste automatizado no contexto de CI. O código candidato assume o papel de código a ser testado; o resultado de teste de CI pode descrever faults, e é isso — não a ausência de log — que caracteriza um processo malsucedido.

*Source: `pt-BR` Tese, Seção 3.3.4, Figura 38*

### Concepts

#### `ciro.continuous_test_process` — Continuous Test Process

*pt-BR: Processo de Teste Contínuo*

`pt-BR` Processo de teste automatizado, com participação do servidor de CI, que verifica se a nova versão do software está em conformidade com os requisitos.

<sub>UFO category: `complex_action` · specializes `roost.testing_process` · automated</sub>

#### `ciro.ci_testing_environment` — CI Testing Environment

*pt-BR: Ambiente de Teste de CI*

`pt-BR` Ambiente de teste que é também uma cópia carregada de sistema de software, criada em um servidor de CI para apoiar o processo de teste contínuo.

<sub>UFO category: `disposition` · specializes `roost.testing_environment`</sub>

#### `ciro.ci_testing_environment_creation` — CI Testing Environment Creation

*pt-BR: Criação do Ambiente de Teste de CI*

`pt-BR` Atividade automatizada que cria o ambiente de teste de CI no servidor de CI.

<sub>UFO category: `action` · specializes `spo.performed_project_activity` · automated</sub>

#### `ciro.automated_testing` — Automated Testing

*pt-BR: Teste Automatizado*

`pt-BR` Atividade de teste por nível automatizada, que executa testes usando os recursos de software e hardware do ambiente de teste de CI.

<sub>UFO category: `complex_action` · specializes `roost.level_based_testing` · automated</sub>

#### `ciro.automated_test_execution` — Automated Test Execution

*pt-BR: Execução Automatizada de Teste*

`pt-BR` Execução de teste que roda automaticamente os casos de teste por meio do código de teste, produzindo resultados de teste de CI.

<sub>UFO category: `action` · specializes `roost.performed_test_execution` · automated</sub>

#### `ciro.candidate_code_to_be_tested` — Candidate Code To Be Tested

*pt-BR: Código Candidato a Ser Testado*

`pt-BR` Papel assumido pelo código candidato quando é alvo de um processo de teste contínuo.

<sub>UFO category: `role` · specializes `roost.code_to_be_tested` · role of `ciro.candidate_code`</sub>

#### `ciro.ci_test_result` — CI Test Result

*pt-BR: Resultado de Teste de CI*

`pt-BR` Resultado de teste que descreve o observado ao aplicar um caso de teste em um processo de teste contínuo. Pode identificar faults ou servir de evidência de sucesso quando nenhum é observado.

<sub>UFO category: `social_object` · specializes `roost.test_result`</sub>

#### `ciro.successful_continuous_test_process` — Successful Continuous Test Process

*pt-BR: Processo de Teste Contínuo Bem-Sucedido*

`pt-BR` Processo de teste contínuo cuja execução automatizada produziu resultado sem faults, após aplicar todos os casos de teste.

<sub>UFO category: `phase` · specializes `ciro.continuous_test_process`</sub>

#### `ciro.unsuccessful_continuous_test_process` — Unsuccessful Continuous Test Process

*pt-BR: Processo de Teste Contínuo Malsucedido*

`pt-BR` Processo de teste contínuo em que um fault foi identificado em um caso de teste.

<sub>UFO category: `phase` · specializes `ciro.continuous_test_process`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
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

`pt-BR` Inspeção automatizada da aderência do código candidato a critérios de qualidade. O resultado é não conformidade (QAPO), não defeito (OSDEF): transformar uma na outra é decisão explícita, nunca automática.

*Source: `pt-BR` Tese, Seção 3.3.5, Figuras 39 a 41*

### Concepts

#### `ciro.continuous_inspection_process` — Continuous Inspection Process

*pt-BR: Processo de Inspeção Contínua*

`pt-BR` Processo de garantia da qualidade automatizado, com participação do servidor de CI, que assegura que os artefatos estejam em conformidade com critérios de qualidade de engenharia de software.

<sub>UFO category: `complex_action` · specializes `qapo.quality_assurance_process` · automated</sub>

#### `ciro.ci_inspection_environment` — CI Inspection Environment

*pt-BR: Ambiente de Inspeção de CI*

`pt-BR` Cópia carregada de sistema de software que contém os recursos de inspeção necessários às atividades do processo de inspeção contínua.

<sub>UFO category: `disposition` · specializes `sys_swo.loaded_software_system_copy`</sub>

#### `ciro.inspection_software_resource` — Inspection Software Resource

*pt-BR: Recurso de Software de Inspeção*

`pt-BR` Produto de software que compõe o ambiente de inspeção.

<sub>UFO category: `role` · specializes `sys_swo.software_resource`</sub>

Examples: `pt-BR` *uma ferramenta de análise estática de código*

#### `ciro.inspection_hardware_resource` — Inspection Hardware Resource

*pt-BR: Recurso de Hardware de Inspeção*

`pt-BR` Equipamento de hardware que compõe o ambiente de inspeção.

<sub>UFO category: `role` · specializes `sys_swo.hardware_resource`</sub>

#### `ciro.static_code_analysis_tool` — Static Code Analysis Tool

*pt-BR: Ferramenta de Análise Estática*

`pt-BR` Produto de software usado para sinalizar erros de programação, bugs, erros de estilo e construções suspeitas.

<sub>UFO category: `object` · specializes `sys_swo.software_product`</sub>

Examples: `pt-BR` *SonarQube*; *Credo*; *ESLint*

#### `ciro.inspection_environment_creation` — Inspection Environment Creation

*pt-BR: Criação do Ambiente de Inspeção*

`pt-BR` Atividade que cria o ambiente de inspeção de CI no servidor de CI.

<sub>UFO category: `action` · specializes `spo.performed_project_activity` · automated</sub>

#### `ciro.automated_adherence_inspection` — Automated Adherence Inspection

*pt-BR: Inspeção de Aderência Automatizada*

`pt-BR` Avaliação de aderência automatizada que inspeciona a aderência do código candidato sob inspeção executando inspeções automatizadas de artefato.

<sub>UFO category: `complex_action` · specializes `qapo.adherence_evaluation` · automated</sub>

#### `ciro.automated_artifact_inspection` — Automated Artifact Inspection

*pt-BR: Inspeção de Artefato Automatizada*

`pt-BR` Avaliação de artefato automatizada que usa código de critério de qualidade para inspecionar critérios em cada artefato do código candidato.

<sub>UFO category: `action` · specializes `qapo.artifact_evaluation` · automated</sub>

#### `ciro.quality_assurance_criterion_code` — Quality Assurance Criterion Code

*pt-BR: Código de Critério de Qualidade*

`pt-BR` Código que materializa um critério de qualidade, tornando-o verificável automaticamente.

<sub>UFO category: `object` · specializes `sys_swo.code`</sub>

Examples: `pt-BR` *uma regra que implementa 'uma função pode ter no máximo 100 linhas'*

#### `ciro.candidate_code_under_inspection` — Candidate Code Under Inspection

*pt-BR: Código Candidato sob Inspeção*

`pt-BR` Papel do código candidato cujos artefatos são artefatos avaliados em um processo de inspeção contínua.

<sub>UFO category: `role` · specializes `qapo.evaluated_artifact` · role of `ciro.candidate_code`</sub>

#### `ciro.ci_evaluation_report` — CI Evaluation Report

*pt-BR: Relatório de Avaliação de CI*

`pt-BR` Relatório de avaliação que descreve os resultados da inspeção e as questões identificadas no código candidato sob inspeção.

<sub>UFO category: `social_object` · specializes `qapo.evaluation_report`</sub>

#### `ciro.successful_continuous_inspection_process` — Successful Continuous Inspection Process

*pt-BR: Processo de Inspeção Bem-Sucedido*

`pt-BR` Processo de inspeção contínua em que nenhuma não conformidade foi identificada.

<sub>UFO category: `phase` · specializes `ciro.continuous_inspection_process`</sub>

#### `ciro.unsuccessful_continuous_inspection_process` — Unsuccessful Continuous Inspection Process

*pt-BR: Processo de Inspeção Malsucedido*

`pt-BR` Processo de inspeção contínua em que ao menos uma não conformidade foi identificada.

<sub>UFO category: `phase` · specializes `ciro.continuous_inspection_process`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
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

`pt-BR` As fases do processo de CI que terminou sem decidir sobre a integração: interrompido por decisão de quem opera, não executado por condição não cumprida, ou encerrado por esgotamento de tempo. Nenhuma delas é malsucedida — a definição de malsucedido exige problema em componente.

*Source: `pt-BR` Issue #401; decidido ao desenhar a tela de verificação contínua*

### Concepts

#### `ciro.interrupted_continuous_integration_process` — Interrupted Continuous Integration Process

*pt-BR: Processo de CI Interrompido*

`pt-BR` Processo de CI encerrado por decisão de um stakeholder antes de concluir a verificação. Não integrou o código candidato e **não encontrou problema nele** — a decisão de parar é externa ao código. Contá-lo como malsucedido atribuiria ao código uma falha que foi escolha de quem opera.

<sub>UFO category: `phase` · specializes `ciro.continuous_integration_process`</sub>

Examples: `pt-BR` *execução cancelada porque um commit mais novo a tornou obsoleta*; *cancelamento manual*

#### `ciro.unperformed_continuous_integration_process` — Unperformed Continuous Integration Process

*pt-BR: Processo de CI Não Executado*

`pt-BR` Processo de CI que foi disparado e **não executou**, porque a condição declarada para sua execução não se cumpriu. Nada foi verificado — e é diferente de nunca ter sido disparado: o gatilho ocorreu, e é isso que esta fase registra.

<sub>UFO category: `phase` · specializes `ciro.continuous_integration_process`</sub>

Examples: `pt-BR` *job pulado porque o anterior falhou*; *condição `if` do workflow não satisfeita*

#### `ciro.expired_continuous_integration_process` — Expired Continuous Integration Process

*pt-BR: Processo de CI Expirado*

`pt-BR` Processo de CI encerrado por esgotamento do tempo declarado, sem concluir a verificação. **É o mais ambíguo dos três e tem fase própria por isso**: pode ser problema no código (laço infinito, teste que trava) ou limite mal dimensionado — e a plataforma não sabe qual. Fase separada é o que permite contá-lo à parte em vez de escolher um lado.

<sub>UFO category: `phase` · specializes `ciro.continuous_integration_process`</sub>


---

## Competency questions

Questions this ontology must be able to answer. They are the model's functional requirements, checked by `mix knowledge.test`.

| # | Question | Concepts involved |
|---|---|---|
| `CQ01` | `pt-BR` Quais processos e atividades compuseram um processo de CI? | `ciro.continuous_integration_process`, `ciro.continuous_build_process`, `ciro.continuous_test_process`, `ciro.continuous_inspection_process`, … |
| `CQ02` | `pt-BR` No processo de CI, de quais outras atividades ou processos uma atividade dependeu? | `ciro.build_environment_creation`, `ciro.code_checkout`, `ciro.candidate_code_building` |
| `CQ03` | `pt-BR` Quando um processo de CI começou? | `ciro.continuous_integration_process` |
| `CQ04` | `pt-BR` Quando um processo de CI terminou? | `ciro.continuous_integration_process` |
| `CQ05` | `pt-BR` Quais artefatos participaram do processo de CI? | `ciro.candidate_code`, `ciro.source_code_copy`, `ciro.test_code_copy`, `ciro.build_problem`, … |
| `CQ06` | `pt-BR` Quais stakeholders participaram do processo de CI? | `ciro.ci_stakeholder`, `ciro.continuous_feedback_activity` |
| `CQ07` | `pt-BR` Que tipo de evento disparou o processo de CI? | `ciro.check_in_triggered_continuous_integration_process`, `ciro.scheduled_continuous_integration_process`, `ciro.on_demand_continuous_integration_process`, `ciro.ci_request_event` |
| `CQ08` | `pt-BR` Quais atividades compuseram um processo de build contínuo? | `ciro.continuous_build_process`, `ciro.build_environment_creation`, `ciro.code_checkout`, `ciro.candidate_code_building` |
| `CQ09` | `pt-BR` Quais recursos foram usados para construir os artefatos durante o build contínuo? | `ciro.ci_building_environment`, `ciro.building_software_resource`, `ciro.building_hardware_resource` |
| `CQ10` | `pt-BR` Quais artefatos foram criados durante o processo de build contínuo? | `ciro.candidate_code`, `ciro.source_code_copy`, `ciro.test_code_copy`, `ciro.build_problem` |
| `CQ11` | `pt-BR` Quais processos e atividades compuseram um processo de teste contínuo? | `ciro.continuous_test_process`, `ciro.ci_testing_environment_creation`, `ciro.automated_testing`, `ciro.automated_test_execution` |
| `CQ12` | `pt-BR` Quais testes automáticos foram executados? | `ciro.automated_test_execution`, `roost.test_case`, `ciro.ci_test_result` |
| `CQ13` | `pt-BR` Quais processos e atividades compuseram um processo de inspeção contínua? | `ciro.continuous_inspection_process`, `ciro.inspection_environment_creation`, `ciro.automated_adherence_inspection`, `ciro.automated_artifact_inspection` |
| `CQ14` | `pt-BR` Qual artefato do projeto ficou em (não) conformidade com os requisitos de qualidade? | `ciro.candidate_code_under_inspection`, `qapo.noncompliance_register`, `ciro.ci_evaluation_report` |



---

[← Ontology network](README.md)

