<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# OSDEF — Reference Ontology of Software Defects, Errors and Failures

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **11 of 11** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Conceitualização sobre defeitos, erros e falhas em software, incluindo a distinção entre defect, fault (defeito em tempo de execução) e failure.

| | |
|---|---|
| **Id** | `osdef` |
| **Version** | 1.0.0 |
| **Layer** | Domain |
| **Network** | SEON |
| **Namespace** | `the_band.ontology.seon.osdef` |
| **Depends on** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md), [roost](roost.md) |
| **Origin** | `pt-BR` Tese, Seção 2.2.2.5, Figura 21 |

## Modules

- **[Defects and Failures](#defects-and-failures)** — `pt-BR` Falha é evento; defeito é disposição. Um defeito pode existir por anos sem nunca se manifestar. Quando se manifesta em uma falha, chamamos aquele defeito de fault. Tratar os três como sinônimos destrói qualquer métrica de qualidade.

---

## Defects and Failures

<a id="defects-and-failures"></a>

`pt-BR` Falha é evento; defeito é disposição. Um defeito pode existir por anos sem nunca se manifestar. Quando se manifesta em uma falha, chamamos aquele defeito de fault. Tratar os três como sinônimos destrói qualquer métrica de qualidade.

*Source: `pt-BR` Tese, Seção 2.2.2.5, Figura 21*

### Concepts

#### `osdef.vulnerability` — Vulnerability

*pt-BR: Vulnerabilidade*

`pt-BR` Disposição de um programa que, em certas circunstâncias, pode se manifestar em uma falha.

<sub>UFO category: `disposition`</sub>

#### `osdef.defect` — Defect

*pt-BR: Defeito*

`pt-BR` Tipo de vulnerabilidade que pode existir em programas. Alguns defeitos podem, acidentalmente, nunca se manifestar em execuções do software.

<sub>UFO category: `disposition` · specializes `osdef.vulnerability`</sub>

#### `osdef.fault` — Fault (Runtime Defect)

*pt-BR: Fault (Defeito em Tempo de Execução)*

`pt-BR` Defeito que se manifestou em uma falha. É o defeito visto pelo seu momento de manifestação.

<sub>UFO category: `disposition` · specializes `osdef.defect`</sub>

#### `osdef.failure` — Failure

*pt-BR: Falha*

`pt-BR` Evento em que um programa não se comporta como pretendido, ferindo os objetivos dos stakeholders. É evento, não estado nem propriedade.

<sub>UFO category: `event`</sub>

#### `osdef.vulnerable_state` — Vulnerable State

*pt-BR: Estado Vulnerável*

`pt-BR` Situação anterior à ocorrência da falha, que ativa a disposição que se manifestará nela. O software está executando e o defeito ainda não se manifestou.

<sub>UFO category: `situation`</sub>

#### `osdef.failure_state` — Failure State

*pt-BR: Estado de Falha*

`pt-BR` Situação trazida à tona pela ocorrência da falha: o software não está executando suas funções como pretendido pelos stakeholders.

<sub>UFO category: `situation`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `exists in` | `osdef.defect` | `sys_swo.program` | many → one | association |
| `triggers` | `osdef.vulnerable_state` | `osdef.failure` | one → one | causation |
| `brings about` | `osdef.failure` | `osdef.failure_state` | one → one | causation |
| `manifested in` | `osdef.fault` | `osdef.failure` | one → one_or_many | materialization |
| `describes` | `roost.test_result` | `osdef.fault` | one → many | association |



---

[← Ontology network](README.md)

