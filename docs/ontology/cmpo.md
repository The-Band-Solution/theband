<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# CMPO — Configuration Management Process Ontology

> Atividades, artefatos e stakeholders do processo de gerência de configuração. Inclui a extensão desenvolvida na tese para alinhar CMPO à filosofia do Git (branches, conflitos, commit), necessária para desenvolver CIRO.

| | |
|---|---|
| **Id** | `cmpo` |
| **Versão** | 1.1.0 |
| **Camada** | Domínio |
| **Rede** | SEON |
| **Namespace** | `the_band.ontology.seon.cmpo` |
| **Depende de** | [ufo](ufo.md), [spo](spo.md), [sys_swo](sys_swo.md) |
| **Origem** | Tese, Seções 2.2.2.2 e 3.3.1 (Figuras 18, 32 e 33) |

> **Nota.** A versão original de CMPO é alinhada à filosofia do Subversion. A tese estendeu a ontologia para representar check-in e check-out como ocorrem no Git.


## Módulos

- **[Configuration Management Process](#configuration-management-process)** — conceitos e relações do módulo.
- **[Checkout (Git-aligned)](#checkout)** — Extensão do CMPO desenvolvida na tese para representar checkout como ocorre no Git: criação e troca de branch, e checkout de artefato.
- **[Check-in (Git-aligned)](#checkin)** — Extensão do CMPO desenvolvida na tese para representar check-in no Git: verificação e resolução de conflitos, commit de cópia de artefato e remoção de branch. Branch de origem e destino são papéis, não tipos de branch.

---

## Configuration Management Process

<a id="configuration-management-process"></a>

*Fonte: Tese, Seção 2.2.2.2, Figura 18*

### Conceitos

#### `cmpo.configuration_management_process` — Configuration Management Process

*Processo de Gerência de Configuração*

Processo executado específico que conduz as atividades de gerência de configuração, assegurando completude e correção dos itens de configuração.

<sub>categoria UFO: `complex_action` · especializa `spo.specific_performed_project_process`</sub>

#### `cmpo.configuration_item` — Configuration Item

*Item de Configuração*

Objeto cuja configuração está sendo gerenciada: artefatos, descrições de processo e ferramentas sob gerência de configuração.

<sub>categoria UFO: `role` · papel de `spo.artifact`</sub>

#### `cmpo.artifact_copy` — Artifact Copy

*Cópia de Artefato*

Cópia de um artefato sob controle de versão.

<sub>categoria UFO: `object`</sub>

Exemplos: *cópia de um código-fonte*; *cópia de um script de banco*

#### `cmpo.source_repository` — Source Repository

*Repositório de Código*

Cópia carregada de sistema de software cujo propósito é tratar as mudanças de cópias de artefato.

<sub>categoria UFO: `disposition` · especializa `sys_swo.loaded_software_system_copy`</sub>

Exemplos: *uma instância do GitLab*; *um repositório no GitHub*

#### `cmpo.change_request` — Change Request

*Solicitação de Mudança*

Solicitação formal para avaliar e potencialmente integrar alterações em itens de configuração. Um Pull Request é uma solicitação de mudança — não é o merge, nem a decisão de aprovação.

<sub>categoria UFO: `social_object` · especializa `spo.information_item`</sub>

#### `cmpo.change_control` — Change Control

*Controle de Mudança*

Atividade executada composta para controlar formalmente a modificação de itens de configuração: solicitar, avaliar, alterar e revisar.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_composite_activity`</sub>

#### `cmpo.change_request_closing` — Change Request Closing

*Fechamento da Solicitação de Mudança*

Atividade executada simples para fechar uma solicitação de mudança revisada e aprovada.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

#### `cmpo.change_accomplishment` — Change Accomplishment

*Realização da Mudança*

Atividade executada composta que realiza mudanças autorizadas em um conjunto de itens de configuração sob controle de versão.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_composite_activity`</sub>

#### `cmpo.change_implementer` — Change Implementer

*Implementador da Mudança*

Stakeholder responsável por implementar uma mudança nos itens de configuração.

<sub>categoria UFO: `role` · especializa `spo.project_stakeholder`</sub>

#### `cmpo.baseline` — Baseline

*Linha de Base*

Item de informação que empacota um conjunto de versões de itens de configuração em um momento específico da vida do produto.

<sub>categoria UFO: `social_object` · especializa `spo.information_item`</sub>

#### `cmpo.baseline_establishment` — Baseline Establishment

*Estabelecimento de Linha de Base*

Atividade executada composta que estabelece uma linha de base.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_composite_activity`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `composed of` | `cmpo.configuration_management_process` | `cmpo.change_control` | one → one_or_many | part_whole |
| `composed of` | `cmpo.change_control` | `cmpo.change_accomplishment` | one → one_or_many | part_whole |
| `is in charge of` | `cmpo.change_implementer` | `cmpo.change_accomplishment` | many → many | participation |
| `packages` | `cmpo.baseline` | `cmpo.configuration_item` | one → one_or_many | part_whole |



---

## Checkout (Git-aligned)

<a id="checkout"></a>

Extensão do CMPO desenvolvida na tese para representar checkout como ocorre no Git: criação e troca de branch, e checkout de artefato.

*Fonte: Tese, Seção 3.3.1, Figura 32*

### Conceitos

#### `cmpo.checkout` — Checkout

*Checkout*

Atividade para acessar versões definidas de um item de configuração em um repositório, normalmente para alteração, criando uma cópia de artefato em um ambiente.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_composite_activity`</sub>

#### `cmpo.branch` — Branch

*Branch*

Coletivo dos artefatos de um repositório de código.

<sub>categoria UFO: `collective`</sub>

#### `cmpo.branch_creation` — Branch Creation

*Criação de Branch*

Atividade executada simples que cria uma branch em um repositório de código.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

#### `cmpo.branch_switch` — Branch Switch

*Troca de Branch*

Atividade executada simples que alterna entre branches de um repositório.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

#### `cmpo.artifact_checkout` — Artifact Checkout

*Checkout de Artefato*

Atividade executada simples que cria ou atualiza uma branch com uma cópia de artefato.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `composed of` | `cmpo.checkout` | `cmpo.branch_creation` | one → many | part_whole |
| `composed of` | `cmpo.checkout` | `cmpo.branch_switch` | one → many | part_whole |
| `composed of` | `cmpo.checkout` | `cmpo.artifact_checkout` | one → many | part_whole |
| `is in` | `cmpo.branch` | `cmpo.source_repository` | many → one | part_whole |



---

## Check-in (Git-aligned)

<a id="checkin"></a>

Extensão do CMPO desenvolvida na tese para representar check-in no Git: verificação e resolução de conflitos, commit de cópia de artefato e remoção de branch. Branch de origem e destino são papéis, não tipos de branch.

*Fonte: Tese, Seção 3.3.1, Figura 33*

### Conceitos

#### `cmpo.checkin` — Check-in

*Check-in*

Atividade para incluir novas versões de itens de configuração em um repositório de código.

<sub>categoria UFO: `complex_action` · especializa `spo.performed_composite_activity`</sub>

#### `cmpo.source_branch` — Source Branch

*Branch de Origem*

Papel assumido por uma branch quando há nova versão ou nova cópia de artefato que se deseja salvar em outra branch por meio de um check-in.

<sub>categoria UFO: `role` · papel de `cmpo.branch`</sub>

#### `cmpo.target_branch` — Target Branch

*Branch de Destino*

Papel assumido pela branch que recebe a cópia de artefato em um check-in.

<sub>categoria UFO: `role` · papel de `cmpo.branch`</sub>

#### `cmpo.check_conflict` — Check Conflict

*Verificação de Conflito*

Atividade que verifica se há conflitos entre uma cópia de artefato na branch de origem e sua versão na branch de destino.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

#### `cmpo.conflict` — Conflict

*Conflito*

Diferença de conteúdo em uma mesma região de uma cópia de artefato.

<sub>categoria UFO: `social_object` · especializa `spo.information_item`</sub>

#### `cmpo.artifact_copy_with_conflict` — Artifact Copy With Conflict

*Cópia de Artefato com Conflito*

Cópia de artefato criada quando um conflito é identificado.

<sub>categoria UFO: `phase` · especializa `cmpo.artifact_copy`</sub>

#### `cmpo.artifact_copy_without_conflict` — Artifact Copy Without Conflict

*Cópia de Artefato sem Conflito*

Cópia de artefato sem conflito, seja porque nenhum foi identificado, seja porque todos foram resolvidos.

<sub>categoria UFO: `phase` · especializa `cmpo.artifact_copy`</sub>

#### `cmpo.resolve_conflict` — Resolve Conflict

*Resolução de Conflito*

Atividade que permite ao implementador da mudança corrigir um conflito em uma cópia de artefato.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

#### `cmpo.commit_artifact_copy` — Commit Artifact Copy

*Commit de Cópia de Artefato*

Atividade que envia uma cópia de artefato sem conflito para a branch de destino.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

#### `cmpo.delete_branch` — Delete Branch

*Remoção de Branch*

Atividade que remove uma branch de origem em um repositório de código.

<sub>categoria UFO: `action` · especializa `spo.performed_simple_activity`</sub>

### Relações

| Relação | Origem | Destino | Cardinalidade | Tipo |
|---|---|---|---|---|
| `composed of` | `cmpo.checkin` | `cmpo.check_conflict` | one → many | part_whole |
| `composed of` | `cmpo.checkin` | `cmpo.resolve_conflict` | one → many | part_whole |
| `composed of` | `cmpo.checkin` | `cmpo.commit_artifact_copy` | one → many | part_whole |
| `composed of` | `cmpo.checkin` | `cmpo.delete_branch` | one → many | part_whole |
| `sends to` | `cmpo.commit_artifact_copy` | `cmpo.target_branch` | many → one | association |



---

[← Rede de ontologias](README.md)

