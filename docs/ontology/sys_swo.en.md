<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# SysSwO — System and Software Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **20 of 20** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Natureza de sistema e software: produto de software, itens de software, constituição do software, execução, sistema computacional e hardware.

| | |
|---|---|
| **Id** | `sys_swo` |
| **Version** | 1.0.0 |
| **Layer** | Core |
| **Network** | SEON |
| **Namespace** | `the_band.ontology.seon.sys_swo` |
| **Depends on** | [ufo](ufo.md), [spo](spo.md) |
| **Origin** | `pt-BR` Tese, Seção 2.2.2.1, Figura 16 |

## Modules

- **[System and Software](#system-and-software)** — `pt-BR` A distinção central: código não é idêntico ao programa. O código pode mudar sem alterar a identidade do programa, que está ancorada na sua especificação pretendida.

---

## System and Software

<a id="system-and-software"></a>

`pt-BR` A distinção central: código não é idêntico ao programa. O código pode mudar sem alterar a identidade do programa, que está ancorada na sua especificação pretendida.

*Source: `pt-BR` Tese, Seção 2.2.2.1, Figura 16*

### Concepts

#### `sys_swo.software_product` — Software Product

*pt-BR: Produto de Software*

`pt-BR` Um ou mais programas de computador junto com itens auxiliares (como documentação), entregues sob um único nome e prontos para uso.

<sub>UFO category: `object` · specializes `spo.artifact`</sub>

Examples: `pt-BR` *Eclipse IDE*; *MSWord*

#### `sys_swo.software_item` — Software Item

*pt-BR: Item de Software*

`pt-BR` Peça de software considerada resultado intermediário do processo de software.

<sub>UFO category: `object` · specializes `spo.artifact`</sub>

Examples: `pt-BR` *um programa*; *um script*; *um schema de banco de dados*

#### `sys_swo.code` — Code

*pt-BR: Código*

`pt-BR` Item de software que representa um conjunto de instruções e definições de dados expressas em uma linguagem de programação ou na saída de um compilador/tradutor. Não é idêntico ao programa que constitui.

<sub>UFO category: `object` · specializes `sys_swo.software_item`</sub>

#### `sys_swo.program` — Program

*pt-BR: Programa*

`pt-BR` Item de software que visa produzir certo resultado por execução em um computador, do modo dado pela sua especificação. É constituído por código, mas sua identidade está ancorada na especificação pretendida.

<sub>UFO category: `object` · specializes `sys_swo.software_item`</sub>

#### `sys_swo.program_specification` — Program Specification

*pt-BR: Especificação de Programa*

`pt-BR` Descrição normativa do resultado pretendido de um programa; ancora sua identidade.

<sub>UFO category: `normative_description`</sub>

#### `sys_swo.software_system` — Software System

*pt-BR: Sistema de Software*

`pt-BR` Item de software composto de um ou mais programas que operam em conjunto.

<sub>UFO category: `object` · specializes `sys_swo.software_item`</sub>

#### `sys_swo.loaded_software_system_copy` — Loaded Software System Copy

*pt-BR: Cópia Carregada de Sistema de Software*

`pt-BR` Disposição que materializa um sistema de software, inerente a uma máquina. É o conceito usado para representar instâncias reais de ferramentas — um GitLab instalado em um servidor, um ambiente de build, um servidor de CI.

<sub>UFO category: `disposition`</sub>

#### `sys_swo.hardware_equipment` — Hardware Equipment

*pt-BR: Equipamento de Hardware*

`pt-BR` Equipamento físico usado no processo de software.

<sub>UFO category: `object`</sub>

#### `sys_swo.machine` — Machine

*pt-BR: Máquina*

`pt-BR` Equipamento de hardware capaz de executar sistemas de software.

<sub>UFO category: `object` · specializes `sys_swo.hardware_equipment`</sub>

#### `sys_swo.software_resource` — Software Resource

*pt-BR: Recurso de Software*

`pt-BR` Produto de software usado como recurso de alguma atividade do processo.

<sub>UFO category: `role` · specializes `spo.resource` · role of `sys_swo.software_product`</sub>

#### `sys_swo.hardware_resource` — Hardware Resource

*pt-BR: Recurso de Hardware*

`pt-BR` Equipamento de hardware usado como recurso de alguma atividade do processo.

<sub>UFO category: `role` · specializes `spo.resource` · role of `sys_swo.hardware_equipment`</sub>

Examples: `pt-BR` *um smartphone usado por uma atividade de teste*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `constituted by` | `sys_swo.program` | `sys_swo.code` | one → one_or_many | part_whole |
| `given by` | `sys_swo.program` | `sys_swo.program_specification` | one → one | association |
| `composed of` | `sys_swo.software_system` | `sys_swo.program` | one → one_or_many | part_whole |
| `materializes` | `sys_swo.loaded_software_system_copy` | `sys_swo.software_system` | many → one | materialization |
| `inheres in` | `sys_swo.loaded_software_system_copy` | `sys_swo.machine` | many → one | association |
| `composed of` | `sys_swo.software_product` | `sys_swo.software_item` | one → one_or_many | part_whole |

- **`sys_swo.program_constituted_by_code`** — `pt-BR` O código constitui o programa sem ser idêntico a ele. Trocar o código não troca o programa enquanto a especificação pretendida permanecer a mesma.


---

[← Ontology network](README.md)

