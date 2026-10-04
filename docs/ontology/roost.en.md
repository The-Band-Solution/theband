<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# ROoST — Reference Ontology on Software Testing

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **19 of 19** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Atividades, artefatos e stakeholders do processo de teste de software, considerando testes dinâmicos.

| | |
|---|---|
| **Id** | `roost` |
| **Version** | 1.0.0 |
| **Layer** | Domain |
| **Network** | SEON |
| **Namespace** | `the_band.ontology.seon.roost` |
| **Depends on** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md) |
| **Origin** | `pt-BR` Tese, Seção 2.2.2.3, Figura 19 |

## Modules

- **[Testing Process](#testing-process)** — `pt-BR` Distinção central: o caso de teste é um documento planejado; a execução de teste é o evento que o aplica e produz o resultado. Contar casos de teste não é contar execuções.

---

## Testing Process

<a id="testing-process"></a>

`pt-BR` Distinção central: o caso de teste é um documento planejado; a execução de teste é o evento que o aplica e produz o resultado. Contar casos de teste não é contar execuções.

*Source: `pt-BR` Tese, Seção 2.2.2.3, Figura 19*

### Concepts

#### `roost.testing_process` — Testing Process

*pt-BR: Processo de Teste*

`pt-BR` Processo executado específico para planejar e executar as atividades de teste dinâmico.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_process`</sub>

#### `roost.level_based_testing` — Level-Based Testing

*pt-BR: Teste por Nível*

`pt-BR` Atividade executada composta que agrupa atividades de teste classificadas pelo nível em que são realizadas.

<sub>UFO category: `complex_action` · specializes `spo.performed_composite_activity`</sub>

#### `roost.unit_testing` — Unit Testing

*pt-BR: Teste de Unidade*

`pt-BR` Teste por nível focado na unidade ou componente individual, isoladamente.

<sub>UFO category: `complex_action` · specializes `roost.level_based_testing`</sub>

#### `roost.integration_testing` — Integration Testing

*pt-BR: Teste de Integração*

`pt-BR` Teste por nível focado em componentes maiores, garantindo que um conjunto de unidades funcione em conjunto.

<sub>UFO category: `complex_action` · specializes `roost.level_based_testing`</sub>

#### `roost.system_testing` — System Testing

*pt-BR: Teste de Sistema*

`pt-BR` Teste por nível focado no comportamento do sistema inteiro e sua conformidade com os requisitos.

<sub>UFO category: `complex_action` · specializes `roost.level_based_testing`</sub>

#### `roost.test_coding` — Test Coding

*pt-BR: Codificação de Teste*

`pt-BR` Atividade executada simples que implementa os casos de teste como código de teste.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

#### `roost.test_case` — Test Case

*pt-BR: Caso de Teste*

`pt-BR` Documento contendo dados de entrada, resultados esperados, passos e condições gerais para testar uma situação do código sob teste.

<sub>UFO category: `social_object` · specializes `spo.document`</sub>

#### `roost.test_code` — Test Code

*pt-BR: Código de Teste*

`pt-BR` Código produzido para implementar um caso de teste.

<sub>UFO category: `object` · specializes `sys_swo.code`</sub>

#### `roost.code_to_be_tested` — Code To Be Tested

*pt-BR: Código a Ser Testado*

`pt-BR` Papel assumido por uma porção de código quando é alvo de um caso de teste.

<sub>UFO category: `role` · role of `sys_swo.code`</sub>

#### `roost.performed_test_execution` — Performed Test Execution

*pt-BR: Execução de Teste*

`pt-BR` Atividade executada simples que efetivamente executa os casos de teste, rodando o código de teste e produzindo resultados.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

#### `roost.test_result` — Test Result

*pt-BR: Resultado de Teste*

`pt-BR` Documento com os resultados observados, que descreve faults (defeitos em tempo de execução) e questões identificadas na execução de um caso de teste.

<sub>UFO category: `social_object` · specializes `spo.document`</sub>

#### `roost.testing_environment` — Testing Environment

*pt-BR: Ambiente de Teste*

`pt-BR` Conjunto de recursos de hardware e software usados para executar as atividades de teste.

<sub>UFO category: `object`</sub>

#### `roost.test_software_resource` — Test Software Resource

*pt-BR: Recurso de Software de Teste*

`pt-BR` Recurso de software que compõe o ambiente de teste.

<sub>UFO category: `role` · specializes `sys_swo.software_resource`</sub>

#### `roost.test_hardware_resource` — Test Hardware Resource

*pt-BR: Recurso de Hardware de Teste*

`pt-BR` Recurso de hardware que compõe o ambiente de teste.

<sub>UFO category: `role` · specializes `sys_swo.hardware_resource`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `composed of` | `roost.testing_process` | `roost.level_based_testing` | one → one_or_many | part_whole |
| `composed of` | `roost.level_based_testing` | `roost.performed_test_execution` | one → many | part_whole |
| `executes` | `roost.performed_test_execution` | `roost.test_case` | many → one_or_many | association |
| `produces` | `roost.performed_test_execution` | `roost.test_result` | one → one_or_many | association |
| `implements` | `roost.test_code` | `roost.test_case` | many → one | materialization |
| `tests` | `roost.test_case` | `roost.code_to_be_tested` | many → many | association |



---

[← Ontology network](README.md)

