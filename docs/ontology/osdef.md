<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# OSDEF — Reference Ontology of Software Defects, Errors and Failures

> Conceitualização sobre defeitos, erros e falhas em software, incluindo a distinção entre defect, fault (defeito em tempo de execução) e failure.

| | |
|---|---|
| **Id** | `osdef` |
| **Versão** | 1.0.0 |
| **Camada** | Domínio |
| **Rede** | SEON |
| **Namespace** | `the_band.ontology.seon.osdef` |
| **Depende de** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md), [roost](roost.md) |
| **Origem** | Tese, Seção 2.2.2.5, Figura 21 |

## Módulos

- **[Defects and Failures](#defects-and-failures)** — Falha é evento; defeito é disposição. Um defeito pode existir por anos sem nunca se manifestar. Quando se manifesta em uma falha, chamamos aquele defeito de fault. Tratar os três como sinônimos destrói qualquer métrica de qualidade.

---

## Defects and Failures

<a id="defects-and-failures"></a>

Falha é evento; defeito é disposição. Um defeito pode existir por anos sem nunca se manifestar. Quando se manifesta em uma falha, chamamos aquele defeito de fault. Tratar os três como sinônimos destrói qualquer métrica de qualidade.

*Fonte: Tese, Seção 2.2.2.5, Figura 21*

### Conceitos

#### `osdef.vulnerability` — Vulnerability

*Vulnerabilidade*

Disposição de um programa que, em certas circunstâncias, pode se manifestar em uma falha.

<sub>categoria UFO: `disposition`</sub>

#### `osdef.defect` — Defect

*Defeito*

Tipo de vulnerabilidade que pode existir em programas. Alguns defeitos podem, acidentalmente, nunca se manifestar em execuções do software.

<sub>categoria UFO: `disposition` · especializa `osdef.vulnerability`</sub>

#### `osdef.fault` — Fault (Runtime Defect)

*Fault (Defeito em Tempo de Execução)*

Defeito que se manifestou em uma falha. É o defeito visto pelo seu momento de manifestação.

<sub>categoria UFO: `disposition` · especializa `osdef.defect`</sub>

#### `osdef.failure` — Failure

*Falha*

Evento em que um programa não se comporta como pretendido, ferindo os objetivos dos stakeholders. É evento, não estado nem propriedade.

<sub>categoria UFO: `event`</sub>

#### `osdef.vulnerable_state` — Vulnerable State

*Estado Vulnerável*

Situação anterior à ocorrência da falha, que ativa a disposição que se manifestará nela. O software está executando e o defeito ainda não se manifestou.

<sub>categoria UFO: `situation`</sub>

#### `osdef.failure_state` — Failure State

*Estado de Falha*

Situação trazida à tona pela ocorrência da falha: o software não está executando suas funções como pretendido pelos stakeholders.

<sub>categoria UFO: `situation`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `exists in` | `osdef.defect` | `sys_swo.program` | many → one | association |
| `triggers` | `osdef.vulnerable_state` | `osdef.failure` | one → one | causation |
| `brings about` | `osdef.failure` | `osdef.failure_state` | one → one | causation |
| `manifested in` | `osdef.fault` | `osdef.failure` | one → one_or_many | materialization |
| `describes` | `roost.test_result` | `osdef.fault` | one → many | association |



---

[← Rede de ontologias](README.md)

