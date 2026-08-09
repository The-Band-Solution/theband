<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# ROoST — Reference Ontology on Software Testing

> Atividades, artefatos e stakeholders do processo de teste de software, considerando testes dinâmicos.

| | |
|---|---|
| **Id** | `roost` |
| **Versão** | 1.0.0 |
| **Camada** | Domínio |
| **Rede** | SEON |
| **Namespace** | `the_band.ontology.seon.roost` |
| **Depende de** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md) |
| **Origem** | Tese, Seção 2.2.2.3, Figura 19 |

## Módulos

- **[Testing Process](#testing-process)** — Distinção central: o caso de teste é um documento planejado; a execução de teste é o evento que o aplica e produz o resultado. Contar casos de teste não é contar execuções.

---

## Testing Process

<a id="testing-process"></a>

Distinção central: o caso de teste é um documento planejado; a execução de teste é o evento que o aplica e produz o resultado. Contar casos de teste não é contar execuções.

*Fonte: Tese, Seção 2.2.2.3, Figura 19*

### Conceitos

#### `roost.testing_process` — Testing Process

*Processo de Teste*

Processo executado específico para planejar e executar as atividades de teste dinâmico.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_process`</sub>

#### `roost.level_based_testing` — Level-Based Testing

*Teste por Nível*

Atividade executada composta que agrupa atividades de teste classificadas pelo nível em que são realizadas.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_composite_activity`</sub>

#### `roost.unit_testing` — Unit Testing

*Teste de Unidade*

Teste por nível focado na unidade ou componente individual, isoladamente.

<sub>categoria UFO: `complex_action` · especializa `roost.level_based_testing`</sub>

#### `roost.integration_testing` — Integration Testing

*Teste de Integração*

Teste por nível focado em componentes maiores, garantindo que um conjunto de unidades funcione em conjunto.

<sub>categoria UFO: `complex_action` · especializa `roost.level_based_testing`</sub>

#### `roost.system_testing` — System Testing

*Teste de Sistema*

Teste por nível focado no comportamento do sistema inteiro e sua conformidade com os requisitos.

<sub>categoria UFO: `complex_action` · especializa `roost.level_based_testing`</sub>

#### `roost.test_coding` — Test Coding

*Codificação de Teste*

Atividade executada simples que implementa os casos de teste como código de teste.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

#### `roost.test_case` — Test Case

*Caso de Teste*

Documento contendo dados de entrada, resultados esperados, passos e condições gerais para testar uma situação do código sob teste.

<sub>categoria UFO: `social_object` · especializa `spo.document`</sub>

#### `roost.test_code` — Test Code

*Código de Teste*

Código produzido para implementar um caso de teste.

<sub>categoria UFO: `object` · especializa `sys_swo.code`</sub>

#### `roost.code_to_be_tested` — Code To Be Tested

*Código a Ser Testado*

Papel assumido por uma porção de código quando é alvo de um caso de teste.

<sub>categoria UFO: `role` · papel de `sys_swo.code`</sub>

#### `roost.performed_test_execution` — Performed Test Execution

*Execução de Teste*

Atividade executada simples que efetivamente executa os casos de teste, rodando o código de teste e produzindo resultados.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

#### `roost.test_result` — Test Result

*Resultado de Teste*

Documento com os resultados observados, que descreve faults (defeitos em tempo de execução) e questões identificadas na execução de um caso de teste.

<sub>categoria UFO: `social_object` · especializa `spo.document`</sub>

#### `roost.testing_environment` — Testing Environment

*Ambiente de Teste*

Conjunto de recursos de hardware e software usados para executar as atividades de teste.

<sub>categoria UFO: `object`</sub>

#### `roost.test_software_resource` — Test Software Resource

*Recurso de Software de Teste*

Recurso de software que compõe o ambiente de teste.

<sub>categoria UFO: `role` · especializa `sys_swo.software_resource`</sub>

#### `roost.test_hardware_resource` — Test Hardware Resource

*Recurso de Hardware de Teste*

Recurso de hardware que compõe o ambiente de teste.

<sub>categoria UFO: `role` · especializa `sys_swo.hardware_resource`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `composed of` | `roost.testing_process` | `roost.level_based_testing` | one → one_or_many | part_whole |
| `composed of` | `roost.level_based_testing` | `roost.performed_test_execution` | one → many | part_whole |
| `executes` | `roost.performed_test_execution` | `roost.test_case` | many → one_or_many | association |
| `produces` | `roost.performed_test_execution` | `roost.test_result` | one → one_or_many | association |
| `implements` | `roost.test_code` | `roost.test_case` | many → one | materialization |
| `tests` | `roost.test_case` | `roost.code_to_be_tested` | many → many | association |



---

[← Rede de ontologias](README.md)

