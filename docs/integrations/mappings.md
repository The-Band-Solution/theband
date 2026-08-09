<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# Mapeamentos semânticos

Como cada entidade das ferramentas externas se relaciona com os conceitos da rede.

Nenhum dado externo entra no domínio sem um mapeamento declarado, com grau de equivalência, justificativa e limitações explícitas. Semelhança de nome nunca basta.

| Origem | Entidade | Ontologia | Conceito | Equivalência | Status |
|---|---|---|---|---|---|
| github | `commit` | `cmpo` | `cmpo.commit_artifact_copy` | partial | proposed |
| github | `deployment` | `cdro` | `cdro.deployment_activity` | partial | proposed |
| github | `issue` | `osdef` | `osdef.defect` | partial | proposed |
| github | `issue` | `sro` | `sro.epic` | derived | proposed |
| github | `issue` | `sro` | `sro.intended_scrum_development_task` | derived | proposed |
| github | `issue` | `sro` | `sro.atomic_user_story` | derived | proposed |
| github | `organization` | `eo` | `eo.organization` | partial | proposed |
| github | `pull_request` | `cmpo` | `cmpo.change_request` | partial | proposed |
| github | `pull_request_review` | `qapo` | `qapo.artifact_evaluation` | partial | proposed |
| github | `ref` | `cmpo` | `cmpo.branch` | partial | proposed |
| github | `repository` | `cmpo` | `cmpo.source_repository` | partial | proposed |
| github | `user` | `eo` | `eo.person` | partial | proposed |
| github | `workflow_run` | `ciro` | `ciro.continuous_integration_process` | partial | proposed |

## Justificativas e limitações

### `github.commit.to.cmpo.commit_artifact_copy`

**github.commit → cmpo.commit_artifact_copy** · equivalência *partial* · versão 1 · status *proposed*

Um commit do GitHub registra o envio de uma cópia de artefato sem conflito para uma branch de destino — a atividade Commit Artifact Copy de CMPO. O objeto commit da API carrega tanto o evento quanto metadados da cópia resultante.

**Limitações**

- Autor e committer podem ser pessoas diferentes; não colapsar os dois campos.
- Commits de merge não representam alteração de conteúdo por si sós.
- Rebase reescreve o oid; o mesmo trabalho pode aparecer com identidades distintas.
- Linhas adicionadas/removidas não medem esforço nem valor.

### `github.deployment.to.cdro.deployment_activity`

**github.deployment → cdro.deployment_activity** · equivalência *partial* · versão 1 · status *proposed*

Um deployment do GitHub registra a atividade automatizada que implantou um código em um ambiente. O desfecho vem do deployment status associado, não do objeto deployment em si.

**Limitações**

- O nome do ambiente é texto livre; "production" em um repositório pode não ser produção real.
- Um deployment criado não implica implantação concluída; usar o status mais recente.
- Rollbacks aparecem como novos deployments do commit anterior.

### `github.issue.bug.to.osdef.defect`

**github.issue → osdef.defect** · equivalência *partial* · versão 1 · status *proposed*

Uma issue do tipo Bug registra um defeito percebido no software — uma disposição que pode se manifestar em falha. O registro não é a falha em si: a falha é evento observado, com instante próprio. Uma issue de bug costuma descrever ambos misturados em texto livre, e apenas o defeito é derivável com segurança.

**Limitações**

- Issue de bug não é user story e nunca deve entrar no escopo do produto como tal.
- O defeito só vira fault quando há manifestação registrada em uma falha; a issue sozinha não estabelece isso.
- O instante da falha não é derivável de createdAt — a data de abertura é quando alguém reportou, não quando o software falhou.
- Bug fechado como "não reproduzível" ou duplicado não é defeito confirmado; requer regra de exclusão por tenant.

### `github.issue.epic.to.sro.epic`

**github.issue → sro.epic** · equivalência *derived* · versão 1 · status *proposed*

Uma issue promovida a épico é uma user story que compõe outras user stories. O tipo declarado na organização indica a intenção; a existência de sub-issues que também são user stories é o que efetivamente a torna épico. Épico pode compor outro épico, e a recursão é preservada: uma sub-issue que tenha suas próprias sub-issues de user story também é promovida a épico.

**Limitações**

- Issue do tipo Epic sem sub-issues não é épico; é promovida a atomic_user_story com divergência registrada (sro.rule05).
- Sub-issues do tipo Task não tornam a issue um épico — tarefas atendem user story, não a compõem (sro.rule07).
- A hierarquia precisa ser verificada contra ciclo antes de persistir; o GitHub não impede ancestralidade circular por API (sro.rule04).
- Sub-issues são recurso recente da API e podem não existir em GitHub Enterprise Server antigo; sem elas, épico não é derivável.
- Nomes de tipo são texto livre da organização; a lista de valores precisa ser confirmada por tenant.

### `github.issue.task.to.sro.intended_scrum_development_task`

**github.issue → sro.intended_scrum_development_task** · equivalência *derived* · versão 1 · status *proposed*

Uma issue do tipo Task descreve trabalho planejado para materializar uma user story — o que corresponde à tarefa pretendida da SRO, e não à executada. A tarefa executada é evento distinto, derivado do histórico de status do item e do fechamento da issue, e é ligada a esta por causação (sro.performed_task_caused_by_intended_task). Colapsar as duas em um registro só destrói a análise de aderência entre planejado e realizado, que é exatamente o que CQ29 pede.

**Limitações**

- Tarefa cujo pai é um épico viola sro.rule07; registrar divergência e não criar o vínculo direto com o épico.
- Tarefa sem pai fica sem user story atendida; é escopo órfão e deve aparecer como lacuna, não ser ligada ao sprint por proximidade.
- Esta issue é a tarefa PRETENDIDA. A tarefa executada vem de github.project_item_status e não deste mapeamento.
- Assignee indica quem foi designado, não necessariamente quem executou; a participação real vem de commits e reviews.

### `github.issue.user_story.to.sro.atomic_user_story`

**github.issue → sro.atomic_user_story** · equivalência *derived* · versão 1 · status *proposed*

Uma issue promovida a user story atômica descreve um requisito do produto e não é decomposta em outras user stories. É o nível em que tarefas de desenvolvimento se ligam ao escopo (sro.rule07) e em que entregáveis materializam requisitos — por isso a distinção entre atômica e épico não é cosmética.

**Limitações**

- Issue com sub-issues que também são user stories é épico, não atômica — a estrutura vence o tipo declarado.
- Sub-issues do tipo Task não descaracterizam a user story como atômica; tarefas a atendem, não a compõem.
- Critérios de aceitação escritos no corpo em texto livre não são sro.acceptance_criterion até serem extraídos e validados; a extração não faz parte deste mapeamento.
- Importance e complexity dependem de campos de GitHub Projects que podem não existir; ausência é nulo, nunca zero.
- Feature e User Story são tratadas como o mesmo destino, o que pode ser incorreto em organizações que usam Feature como agrupador — confirmar por tenant.

### `github.organization.to.eo.organization`

**github.organization → eo.organization** · equivalência *partial* · versão 1 · status *proposed*

Uma organização do GitHub é um agrupamento administrativo de repositórios e pessoas. Corresponde parcialmente à organização de EO: não representa a estrutura organizacional real, apenas o recorte visível na ferramenta.

**Limitações**

- Uma organização no GitHub pode representar apenas uma unidade organizacional, não a organização inteira.
- Times do GitHub não correspondem necessariamente a equipes de projeto (eo.project_team).

### `github.pull_request.to.cmpo.change_request`

**github.pull_request → cmpo.change_request** · equivalência *partial* · versão 1 · status *proposed*

Um Pull Request representa uma solicitação para avaliar e potencialmente integrar alterações presentes em uma branch de origem. Não é equivalente ao merge, nem à decisão de aprovação, nem à atividade de check-in. Cada um desses é evento distinto e possui mapeamento próprio.

**Limitações**

- O Pull Request não é equivalente ao merge; mergedAt indica que um merge ocorreu, mas o merge é outro evento.
- Reviews e decisões de aprovação são processadas separadamente (ver github.review).
- Um PR fechado sem merge não representa mudança integrada.
- Autoria da solicitação não implica autoria dos commits.

### `github.pull_request_review.to.qapo.artifact_evaluation`

**github.pull_request_review → qapo.artifact_evaluation** · equivalência *partial* · versão 1 · status *proposed*

Uma review de Pull Request é uma avaliação de artefato: alguém avalia objetivamente a aderência das alterações a critérios aplicáveis. O estado CHANGES_REQUESTED indica não conformidades identificadas; APPROVED indica conformidade na avaliação daquele revisor.

**Limitações**

- Aprovação não implica ausência de não conformidades, apenas ausência de bloqueio.
- Reviews automáticas (bots) devem ser classificadas separadamente das humanas.
- Um comentário isolado não é uma review; usar apenas eventos de review submetida.

### `github.ref.to.cmpo.branch`

**github.ref → cmpo.branch** · equivalência *partial* · versão 1 · status *proposed*

Uma ref do tipo branch é o coletivo dos artefatos de um repositório em uma linha de desenvolvimento — a Branch de CMPO. Branch de origem e de destino são papéis assumidos em um check-in, e não tipos de branch.

**Limitações**

- Tags também são refs, mas não são branches; filtrar por refs/heads.
- Branch protegida ou default é configuração da ferramenta, não distinção ontológica.

### `github.repository.to.cmpo.source_repository`

**github.repository → cmpo.source_repository** · equivalência *partial* · versão 1 · status *proposed*

Um repositório do GitHub é uma cópia carregada de sistema de software cujo propósito é tratar mudanças de cópias de artefato — exatamente o papel do Source Repository em CMPO. Não é o projeto de software (SPO) nem o produto (SysSwO); um projeto pode ter vários repositórios.

**Limitações**

- Repositório não é projeto; não derivar spo.software_project automaticamente daqui.
- Forks e mirrors representam o mesmo item de configuração em instâncias diferentes.

### `github.user.to.eo.person`

**github.user → eo.person** · equivalência *partial* · versão 1 · status *proposed*

Uma conta de usuário do GitHub identifica um agente que atuou no repositório. Não é a pessoa: uma pessoa pode ter várias contas, e uma conta pode ser um bot ou uma conta de serviço. A identidade de pessoa exige reconciliação explícita.

**Limitações**

- Contas do tipo Bot e App não são pessoas e devem ser classificadas separadamente.
- A mesma pessoa pode ter múltiplas contas; a unificação exige regra explícita, nunca heurística de nome.
- O campo email costuma ser nulo por configuração de privacidade.

### `github.workflow_run.to.ciro.continuous_integration_process`

**github.workflow_run → ciro.continuous_integration_process** · equivalência *partial* · versão 1 · status *proposed*

Uma execução de workflow do GitHub Actions é uma ocorrência automatizada de processo de integração contínua. O subtipo depende do gatilho: push/pull_request mapeiam para o processo disparado por check-in, schedule para o agendado, e workflow_dispatch para o sob demanda.

**Limitações**

- Nem todo workflow é integração contínua; workflows de release mapeiam para CDRO.
- conclusion "cancelled" e "skipped" não são insucesso do processo; classificar separadamente.
- updated_at aproxima o término, mas não é o instante exato de fim.
- Um job dentro do run pode ser build, teste ou inspeção; a distinção exige mapear check_run.

