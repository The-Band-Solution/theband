<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# CMPO — Configuration Management Process Ontology

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **44 of 44** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

> `pt-BR` Atividades, artefatos e stakeholders do processo de gerência de configuração. Inclui a extensão desenvolvida na tese para alinhar CMPO à filosofia do Git (branches, conflitos, commit), necessária para desenvolver CIRO.

| | |
|---|---|
| **Id** | `cmpo` |
| **Version** | 1.1.0 |
| **Layer** | Domain |
| **Network** | SEON |
| **Namespace** | `the_band.ontology.seon.cmpo` |
| **Depends on** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md) |
| **Origin** | `pt-BR` Tese, Seções 2.2.2.2 e 3.3.1 (Figuras 18, 32 e 33) |

> **Note.** `pt-BR` A versão original de CMPO é alinhada à filosofia do Subversion. A tese estendeu a ontologia para representar check-in e check-out como ocorrem no Git.
E o projeto The Band acrescentou uma terceira camada, o módulo change_traceability (2026-08-17, issue #426): as participações que ligam stakeholders aos atos — submeter, integrar, commitar. Elas faltavam, e a lacuna apareceu ao escrever o mapeamento do Pull Request, antes de qualquer coleta.


## Modules

- **[Configuration Management Process](#configuration-management-process)** — the module's concepts and relations.
- **[Checkout (Git-aligned)](#checkout)** — `pt-BR` Extensão do CMPO desenvolvida na tese para representar checkout como ocorre no Git: criação e troca de branch, e checkout de artefato.
- **[Check-in (Git-aligned)](#checkin)** — `pt-BR` Extensão do CMPO desenvolvida na tese para representar check-in no Git: verificação e resolução de conflitos, commit de cópia de artefato e remoção de branch. Branch de origem e destino são papéis, não tipos de branch.
- **[Change Traceability](#change-traceability)** — `pt-BR` Quem submeteu uma solicitação de mudança, quem a integrou e quem executou cada commit — as participações que ligam stakeholders aos atos da gerência de configuração, e as associações que ligam os atos à solicitação que os motivou. Extensão do projeto The Band, não da CMPO publicada.

---

## Configuration Management Process

<a id="configuration-management-process"></a>

*Source: `pt-BR` Tese, Seção 2.2.2.2, Figura 18*

### Concepts

#### `cmpo.configuration_management_process` — Configuration Management Process

*pt-BR: Processo de Gerência de Configuração*

`pt-BR` Processo executado específico que conduz as atividades de gerência de configuração, assegurando completude e correção dos itens de configuração.

<sub>UFO category: `complex_action` · specializes `spo.specific_performed_project_process`</sub>

#### `cmpo.configuration_item` — Configuration Item

*pt-BR: Item de Configuração*

`pt-BR` Objeto cuja configuração está sendo gerenciada: artefatos, descrições de processo e ferramentas sob gerência de configuração.

<sub>UFO category: `role` · role of `spo.artifact`</sub>

#### `cmpo.artifact_copy` — Artifact Copy

*pt-BR: Cópia de Artefato*

`pt-BR` Cópia de um artefato sob controle de versão.

<sub>UFO category: `object`</sub>

Examples: `pt-BR` *cópia de um código-fonte*; *cópia de um script de banco*

#### `cmpo.source_repository` — Source Repository

*pt-BR: Repositório de Código*

`pt-BR` Cópia carregada de sistema de software cujo propósito é tratar as mudanças de cópias de artefato.

<sub>UFO category: `disposition` · specializes `sys_swo.loaded_software_system_copy`</sub>

| Attribute | Type | Required |
|---|---|---|
| `name` | string | yes |
| `qualified_name` | string | yes |
| `url` | string | yes |
| `description` | text | no |
| `primary_language` | string | no |
| `default_branch` | string | no |
| `archived_at` | datetime | no |
| `external_created_at` | datetime | no |
| `last_pushed_at` | datetime | no |

Examples: `pt-BR` *uma instância do GitLab*; *um repositório no GitHub*

#### `cmpo.change_request` — Change Request

*pt-BR: Solicitação de Mudança*

`pt-BR` Solicitação formal para avaliar e potencialmente integrar alterações em itens de configuração. Um Pull Request é uma solicitação de mudança — não é o merge, nem a decisão de aprovação.

<sub>UFO category: `social_object` · specializes `spo.information_item`</sub>

#### `cmpo.change_control` — Change Control

*pt-BR: Controle de Mudança*

`pt-BR` Atividade executada composta para controlar formalmente a modificação de itens de configuração: solicitar, avaliar, alterar e revisar.

<sub>UFO category: `complex_action` · specializes `spo.performed_composite_activity`</sub>

#### `cmpo.change_request_closing` — Change Request Closing

*pt-BR: Fechamento da Solicitação de Mudança*

`pt-BR` Atividade executada simples para fechar uma solicitação de mudança revisada e aprovada.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

#### `cmpo.change_accomplishment` — Change Accomplishment

*pt-BR: Realização da Mudança*

`pt-BR` Atividade executada composta que realiza mudanças autorizadas em um conjunto de itens de configuração sob controle de versão.

<sub>UFO category: `complex_action` · specializes `spo.performed_composite_activity`</sub>

#### `cmpo.change_implementer` — Change Implementer

*pt-BR: Implementador da Mudança*

`pt-BR` Stakeholder responsável por implementar uma mudança nos itens de configuração.

<sub>UFO category: `role` · specializes `spo.project_stakeholder`</sub>

#### `cmpo.baseline` — Baseline

*pt-BR: Linha de Base*

`pt-BR` Item de informação que empacota um conjunto de versões de itens de configuração em um momento específico da vida do produto.

<sub>UFO category: `social_object` · specializes `spo.information_item`</sub>

#### `cmpo.baseline_establishment` — Baseline Establishment

*pt-BR: Estabelecimento de Linha de Base*

`pt-BR` Atividade executada composta que estabelece uma linha de base.

<sub>UFO category: `complex_action` · specializes `spo.performed_composite_activity`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `is grouped by` | `cmpo.source_repository` | `spo.project` | many → many | association |
| `composed of` | `cmpo.configuration_management_process` | `cmpo.change_control` | one → one_or_many | part_whole |
| `composed of` | `cmpo.change_control` | `cmpo.change_accomplishment` | one → one_or_many | part_whole |
| `is in charge of` | `cmpo.change_implementer` | `cmpo.change_accomplishment` | many → many | participation |
| `packages` | `cmpo.baseline` | `cmpo.configuration_item` | one → one_or_many | part_whole |

- **`cmpo.source_repository_grouped_by_project`** — `pt-BR` Associação **declarada por pessoa**, e nunca observada: a origem não diz a que projeto um repositório pertence, e inferir isso de nome, organização ou padrão de texto produziria agrupamento que ninguém decidiu.
Muitos-para-muitos porque um repositório pode servir a mais de um projeto — uma biblioteca compartilhada é o caso comum.
A relação mora em CMPO, e não em SPO, porque **cmpo já depende de spo**: declará-la do outro lado inverteria a hierarquia entre as ontologias e criaria um ciclo de dependência. Quem conhece os dois conceitos é o módulo mais externo.
As issues do projeto são **derivadas desta relação**, e não guardadas na issue: projeto → repositórios → issues. Uma referência a projeto na issue duplicaria o fato, e as duas fontes discordariam quando um repositório mudasse de projeto.


---

## Checkout (Git-aligned)

<a id="checkout"></a>

`pt-BR` Extensão do CMPO desenvolvida na tese para representar checkout como ocorre no Git: criação e troca de branch, e checkout de artefato.

*Source: `pt-BR` Tese, Seção 3.3.1, Figura 32*

### Concepts

#### `cmpo.checkout` — Checkout

*pt-BR: Checkout*

`pt-BR` Atividade para acessar versões definidas de um item de configuração em um repositório, normalmente para alteração, criando uma cópia de artefato em um ambiente.

<sub>UFO category: `complex_action` · specializes `spo.performed_composite_activity`</sub>

#### `cmpo.branch` — Branch

*pt-BR: Branch*

`pt-BR` Coletivo dos artefatos de um repositório de código.

<sub>UFO category: `collective`</sub>

#### `cmpo.branch_creation` — Branch Creation

*pt-BR: Criação de Branch*

`pt-BR` Atividade executada simples que cria uma branch em um repositório de código.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

#### `cmpo.branch_switch` — Branch Switch

*pt-BR: Troca de Branch*

`pt-BR` Atividade executada simples que alterna entre branches de um repositório.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

#### `cmpo.artifact_checkout` — Artifact Checkout

*pt-BR: Checkout de Artefato*

`pt-BR` Atividade executada simples que cria ou atualiza uma branch com uma cópia de artefato.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `composed of` | `cmpo.checkout` | `cmpo.branch_creation` | one → many | part_whole |
| `composed of` | `cmpo.checkout` | `cmpo.branch_switch` | one → many | part_whole |
| `composed of` | `cmpo.checkout` | `cmpo.artifact_checkout` | one → many | part_whole |
| `is in` | `cmpo.branch` | `cmpo.source_repository` | many → one | part_whole |



---

## Check-in (Git-aligned)

<a id="checkin"></a>

`pt-BR` Extensão do CMPO desenvolvida na tese para representar check-in no Git: verificação e resolução de conflitos, commit de cópia de artefato e remoção de branch. Branch de origem e destino são papéis, não tipos de branch.

*Source: `pt-BR` Tese, Seção 3.3.1, Figura 33*

### Concepts

#### `cmpo.checkin` — Check-in

*pt-BR: Check-in*

`pt-BR` Atividade para incluir novas versões de itens de configuração em um repositório de código.

<sub>UFO category: `complex_action` · specializes `spo.performed_composite_activity`</sub>

#### `cmpo.source_branch` — Source Branch

*pt-BR: Branch de Origem*

`pt-BR` Papel assumido por uma branch quando há nova versão ou nova cópia de artefato que se deseja salvar em outra branch por meio de um check-in.

<sub>UFO category: `role` · role of `cmpo.branch`</sub>

#### `cmpo.target_branch` — Target Branch

*pt-BR: Branch de Destino*

`pt-BR` Papel assumido pela branch que recebe a cópia de artefato em um check-in.

<sub>UFO category: `role` · role of `cmpo.branch`</sub>

#### `cmpo.check_conflict` — Check Conflict

*pt-BR: Verificação de Conflito*

`pt-BR` Atividade que verifica se há conflitos entre uma cópia de artefato na branch de origem e sua versão na branch de destino.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

#### `cmpo.conflict` — Conflict

*pt-BR: Conflito*

`pt-BR` Diferença de conteúdo em uma mesma região de uma cópia de artefato.

<sub>UFO category: `social_object` · specializes `spo.information_item`</sub>

#### `cmpo.artifact_copy_with_conflict` — Artifact Copy With Conflict

*pt-BR: Cópia de Artefato com Conflito*

`pt-BR` Cópia de artefato criada quando um conflito é identificado.

<sub>UFO category: `phase` · specializes `cmpo.artifact_copy`</sub>

#### `cmpo.artifact_copy_without_conflict` — Artifact Copy Without Conflict

*pt-BR: Cópia de Artefato sem Conflito*

`pt-BR` Cópia de artefato sem conflito, seja porque nenhum foi identificado, seja porque todos foram resolvidos.

<sub>UFO category: `phase` · specializes `cmpo.artifact_copy`</sub>

#### `cmpo.resolve_conflict` — Resolve Conflict

*pt-BR: Resolução de Conflito*

`pt-BR` Atividade que permite ao implementador da mudança corrigir um conflito em uma cópia de artefato.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

#### `cmpo.commit_artifact_copy` — Commit Artifact Copy

*pt-BR: Commit de Cópia de Artefato*

`pt-BR` Atividade que envia uma cópia de artefato sem conflito para a branch de destino.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

| Attribute | Type | Required |
|---|---|---|
| `sha` | string | yes |
| `message` | text | no |
| `additions` | integer | no |
| `deletions` | integer | no |

#### `cmpo.delete_branch` — Delete Branch

*pt-BR: Remoção de Branch*

`pt-BR` Atividade que remove uma branch de origem em um repositório de código.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `composed of` | `cmpo.checkin` | `cmpo.check_conflict` | one → many | part_whole |
| `composed of` | `cmpo.checkin` | `cmpo.resolve_conflict` | one → many | part_whole |
| `composed of` | `cmpo.checkin` | `cmpo.commit_artifact_copy` | one → many | part_whole |
| `composed of` | `cmpo.checkin` | `cmpo.delete_branch` | one → many | part_whole |
| `sends to` | `cmpo.commit_artifact_copy` | `cmpo.target_branch` | many → one | association |



---

## Change Traceability

<a id="change-traceability"></a>

`pt-BR` Quem submeteu uma solicitação de mudança, quem a integrou e quem executou cada commit — as participações que ligam stakeholders aos atos da gerência de configuração, e as associações que ligam os atos à solicitação que os motivou. Extensão do projeto The Band, não da CMPO publicada.

*Source: `pt-BR` Issue #426; lacuna exposta ao escrever github.pull_request.to.cmpo.change_request*

### Concepts

#### `cmpo.change_request_submission` — Change Request Submission

*pt-BR: Submissão de Solicitação de Mudança*

`pt-BR` Atividade executada simples que submete uma solicitação de mudança para avaliação, produzindo a solicitação. Existe como conceito próprio porque participação é relação entre agente e evento: sem o ato, "quem solicitou" não teria onde se ancorar — a solicitação é objeto social, e objeto social não tem participante.

<sub>UFO category: `action` · specializes `spo.performed_simple_activity`</sub>

Examples: `pt-BR` *abrir um Pull Request*; *registrar uma solicitação de alteração no processo*

### Relations

| Relation | Source | Target | Cardinality | Type |
|---|---|---|---|---|
| `submitted` | `spo.project_stakeholder` | `cmpo.change_request_submission` | one → many | participation |
| `produced` | `cmpo.change_request_submission` | `cmpo.change_request` | one → one | causation |
| `performed` | `spo.project_stakeholder` | `cmpo.checkin` | one → many | participation |
| `integrated` | `cmpo.checkin` | `cmpo.change_request` | one → zero_or_one | association |
| `performed` | `spo.project_stakeholder` | `cmpo.commit_artifact_copy` | many → many | participation |
| `produced` | `cmpo.commit_artifact_copy` | `cmpo.artifact_copy` | one → one_or_many | causation |
| `accomplished` | `cmpo.commit_artifact_copy` | `cmpo.change_request` | many → zero_or_one | association |



---

[← Ontology network](README.md)

