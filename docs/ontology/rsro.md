<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# RSRO — Reference Software Requirements Ontology

> Requisitos de software entendidos como objetivos a alcançar, a distinção entre requisitos funcionais e não funcionais, e como requisitos são documentados em artefatos próprios.

| | |
|---|---|
| **Id** | `rsro` |
| **Versão** | 1.0.0 |
| **Camada** | Domínio |
| **Rede** | SEON |
| **Namespace** | `the_band.ontology.seon.rsro` |
| **Depende de** | [ufo](ufo.md), [spo](spo.md) |
| **Origem** | Tese, Seção 2.2.3, Figura 22 |

## Módulos

- **[Requirements](#requirements)** — Distinção fundamental: o artefato de requisito descreve o requisito, mas não é o requisito. Requisito é o objetivo a ser alcançado.

---

## Requirements

<a id="requirements"></a>

Distinção fundamental: o artefato de requisito descreve o requisito, mas não é o requisito. Requisito é o objetivo a ser alcançado.

*Fonte: Tese, Seção 2.2.3, Figura 22*

### Conceitos

#### `rsro.requirement` — Requirement

*Requisito*

Objetivo a ser alcançado, representando uma condição ou capacidade necessária ao usuário.

<sub>categoria UFO: `goal`</sub>

Exemplos: *criar ordem de serviço*

#### `rsro.functional_requirement` — Functional Requirement

*Requisito Funcional*

Requisito que define uma função a ser disponibilizada no produto construído.

<sub>categoria UFO: `goal` · especializa `rsro.requirement`</sub>

Exemplos: *o sistema precisa controlar pedidos de clientes*

#### `rsro.non_functional_requirement` — Non-Functional Requirement

*Requisito Não Funcional*

Requisito que define critérios ou capacidades para o produto.

<sub>categoria UFO: `goal` · especializa `rsro.requirement`</sub>

Exemplos: *estar acessível em navegadores específicos*; *executar uma função em tempo estabelecido*

#### `rsro.requirements_artifact` — Requirements Artifact

*Artefato de Requisitos*

Artefato que descreve um ou mais requisitos. Descreve o requisito; não é o requisito.

<sub>categoria UFO: `social_object` · especializa `spo.information_item`</sub>

#### `rsro.requirements_document` — Requirements Document

*Documento de Requisitos*

Documento composto de artefatos de requisitos que descrevem requisitos.

<sub>categoria UFO: `social_object` · especializa `spo.document`</sub>

Exemplos: *uma Especificação de Requisitos*

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `describes` | `rsro.requirements_artifact` | `rsro.requirement` | many → one_or_many | association |
| `composed of` | `rsro.requirements_document` | `rsro.requirements_artifact` | one → one_or_many | part_whole |



---

[← Rede de ontologias](README.md)

