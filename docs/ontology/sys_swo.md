<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# SysSwO — System and Software Ontology

> Natureza de sistema e software: produto de software, itens de software, constituição do software, execução, sistema computacional e hardware.

| | |
|---|---|
| **Id** | `sys_swo` |
| **Versão** | 1.0.0 |
| **Camada** | Core |
| **Rede** | SEON |
| **Namespace** | `the_band.ontology.seon.sys_swo` |
| **Depende de** | [ufo](ufo.md), [spo](spo.md) |
| **Origem** | Tese, Seção 2.2.2.1, Figura 16 |

## Módulos

- **[System and Software](#system-and-software)** — A distinção central: código não é idêntico ao programa. O código pode mudar sem alterar a identidade do programa, que está ancorada na sua especificação pretendida.

---

## System and Software

<a id="system-and-software"></a>

A distinção central: código não é idêntico ao programa. O código pode mudar sem alterar a identidade do programa, que está ancorada na sua especificação pretendida.

*Fonte: Tese, Seção 2.2.2.1, Figura 16*

### Conceitos

#### `sys_swo.software_product` — Software Product

*Produto de Software*

Um ou mais programas de computador junto com itens auxiliares (como documentação), entregues sob um único nome e prontos para uso.

<sub>categoria UFO: `object` · especializa `spo.artifact`</sub>

Exemplos: *Eclipse IDE*; *MSWord*

#### `sys_swo.software_item` — Software Item

*Item de Software*

Peça de software considerada resultado intermediário do processo de software.

<sub>categoria UFO: `object` · especializa `spo.artifact`</sub>

Exemplos: *um programa*; *um script*; *um schema de banco de dados*

#### `sys_swo.code` — Code

*Código*

Item de software que representa um conjunto de instruções e definições de dados expressas em uma linguagem de programação ou na saída de um compilador/tradutor. Não é idêntico ao programa que constitui.

<sub>categoria UFO: `object` · especializa `sys_swo.software_item`</sub>

#### `sys_swo.program` — Program

*Programa*

Item de software que visa produzir certo resultado por execução em um computador, do modo dado pela sua especificação. É constituído por código, mas sua identidade está ancorada na especificação pretendida.

<sub>categoria UFO: `object` · especializa `sys_swo.software_item`</sub>

#### `sys_swo.program_specification` — Program Specification

*Especificação de Programa*

Descrição normativa do resultado pretendido de um programa; ancora sua identidade.

<sub>categoria UFO: `normative_description`</sub>

#### `sys_swo.software_system` — Software System

*Sistema de Software*

Item de software composto de um ou mais programas que operam em conjunto.

<sub>categoria UFO: `object` · especializa `sys_swo.software_item`</sub>

#### `sys_swo.loaded_software_system_copy` — Loaded Software System Copy

*Cópia Carregada de Sistema de Software*

Disposição que materializa um sistema de software, inerente a uma máquina. É o conceito usado para representar instâncias reais de ferramentas — um GitLab instalado em um servidor, um ambiente de build, um servidor de CI.

<sub>categoria UFO: `disposition`</sub>

#### `sys_swo.hardware_equipment` — Hardware Equipment

*Equipamento de Hardware*

Equipamento físico usado no processo de software.

<sub>categoria UFO: `object`</sub>

#### `sys_swo.machine` — Machine

*Máquina*

Equipamento de hardware capaz de executar sistemas de software.

<sub>categoria UFO: `object` · especializa `sys_swo.hardware_equipment`</sub>

#### `sys_swo.software_resource` — Software Resource

*Recurso de Software*

Produto de software usado como recurso de alguma atividade do processo.

<sub>categoria UFO: `role` · especializa `spo.resource` · papel de `sys_swo.software_product`</sub>

#### `sys_swo.hardware_resource` — Hardware Resource

*Recurso de Hardware*

Equipamento de hardware usado como recurso de alguma atividade do processo.

<sub>categoria UFO: `role` · especializa `spo.resource` · papel de `sys_swo.hardware_equipment`</sub>

Exemplos: *um smartphone usado por uma atividade de teste*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `constituted by` | `sys_swo.program` | `sys_swo.code` | one → one_or_many | part_whole |
| `given by` | `sys_swo.program` | `sys_swo.program_specification` | one → one | association |
| `composed of` | `sys_swo.software_system` | `sys_swo.program` | one → one_or_many | part_whole |
| `materializes` | `sys_swo.loaded_software_system_copy` | `sys_swo.software_system` | many → one | materialization |
| `inheres in` | `sys_swo.loaded_software_system_copy` | `sys_swo.machine` | many → one | association |
| `composed of` | `sys_swo.software_product` | `sys_swo.software_item` | one → one_or_many | part_whole |

- **`sys_swo.program_constituted_by_code`** — O código constitui o programa sem ser idêntico a ele. Trocar o código não troca o programa enquanto a especificação pretendida permanecer a mesma.


---

[← Rede de ontologias](README.md)

