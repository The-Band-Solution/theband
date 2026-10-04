<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# RSRO — Reference Software Requirements Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **14 of 14** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Requisitos de software entendidos como objetivos a alcançar, a distinção entre requisitos funcionais e não funcionais, e como requisitos são documentados em artefatos próprios.

| | |
|---|---|
| **Id** | `rsro` |
| **Version** | 1.0.0 |
| **Layer** | Domain |
| **Network** | SEON |
| **Namespace** | `the_band.ontology.seon.rsro` |
| **Depends on** | [ufo](ufo.md), [spo](spo.md) |
| **Origin** | `pt-BR` Tese, Seção 2.2.3, Figura 22 |

## Modules

- **[Requirements](#requirements)** — `pt-BR` Distinção fundamental: o artefato de requisito descreve o requisito, mas não é o requisito. Requisito é o objetivo a ser alcançado.

---

## Requirements

<a id="requirements"></a>

`pt-BR` Distinção fundamental: o artefato de requisito descreve o requisito, mas não é o requisito. Requisito é o objetivo a ser alcançado.

*Source: `pt-BR` Tese, Seção 2.2.3, Figura 22*

### Concepts

#### `rsro.requirement` — Requirement

*pt-BR: Requisito*

`pt-BR` Objetivo a ser alcançado, representando uma condição ou capacidade necessária ao usuário.

<sub>UFO category: `goal`</sub>

Examples: `pt-BR` *criar ordem de serviço*

#### `rsro.functional_requirement` — Functional Requirement

*pt-BR: Requisito Funcional*

`pt-BR` Requisito que define uma função a ser disponibilizada no produto construído.

<sub>UFO category: `goal` · specializes `rsro.requirement`</sub>

Examples: `pt-BR` *o sistema precisa controlar pedidos de clientes*

#### `rsro.non_functional_requirement` — Non-Functional Requirement

*pt-BR: Requisito Não Funcional*

`pt-BR` Requisito que define critérios ou capacidades para o produto.

<sub>UFO category: `goal` · specializes `rsro.requirement`</sub>

Examples: `pt-BR` *estar acessível em navegadores específicos*; *executar uma função em tempo estabelecido*

#### `rsro.requirements_artifact` — Requirements Artifact

*pt-BR: Artefato de Requisitos*

`pt-BR` Artefato que descreve um ou mais requisitos. Descreve o requisito; não é o requisito.

<sub>UFO category: `social_object` · specializes `spo.information_item`</sub>

#### `rsro.requirements_document` — Requirements Document

*pt-BR: Documento de Requisitos*

`pt-BR` Documento composto de artefatos de requisitos que descrevem requisitos.

<sub>UFO category: `social_object` · specializes `spo.document`</sub>

Examples: `pt-BR` *uma Especificação de Requisitos*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `describes` | `rsro.requirements_artifact` | `rsro.requirement` | many → one_or_many | association |
| `composed of` | `rsro.requirements_document` | `rsro.requirements_artifact` | one → one_or_many | part_whole |



---

[← Ontology network](README.md)

