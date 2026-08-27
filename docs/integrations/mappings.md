<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# Mapeamentos semânticos

Como cada entidade das ferramentas externas se relaciona com os conceitos da rede.

Nenhum dado externo entra no domínio sem um mapeamento declarado, com grau de equivalência, justificativa e limitações explícitas. Semelhança de nome nunca basta.

| Origem | Entidade | Ontologia | Conceito | Equivalência | Status |
|---|---|---|---|---|---|
| github | `commit` | `cmpo` | `cmpo.commit_artifact_copy` | total | proposed |
| github | `commit_file` | `cmpo` | `cmpo.artifact_copy` | partial | proposed |
| github | `deployment` | `cdro` | `cdro.deployment_activity` | partial | proposed |
| github | `issue` | `osdef` | `osdef.defect` | partial | proposed |
| github | `issue` | `sro` | `sro.intended_scrum_development_task` | derived | proposed |
| github | `issue` | `osdef` | `osdef.defect` | derived | proposed |
| github | `issue` | `sro` | `sro.epic` | derived | proposed |
| github | `issue` | `sro` | `sro.atomic_user_story` | derived | proposed |
| github | `issue_comment` | `cmo` | `cmo.comment` | total | proposed |
| github | `organization` | `eo` | `eo.organization` | partial | proposed |
| github | `project_v2_item` | `sro` | `sro.product_backlog` | derived | proposed |
| github | `project_v2_iteration` | `spo` | `spo.specific_intended_project_process` | derived | proposed |
| github | `project_v2_iteration` | `sro` | `sro.sprint` | derived | proposed |
| github | `pull_request` | `cmpo` | `cmpo.change_request` | total | proposed |
| github | `pull_request_review` | `qapo` | `qapo.artifact_evaluation` | partial | proposed |
| github | `ref` | `cmpo` | `cmpo.branch` | partial | proposed |
| github | `repository` | `cmpo` | `cmpo.source_repository` | partial | proposed |
| github | `team` | `eo` | `eo.organizational_team` | partial | proposed |
| github | `team_member` | `eo` | `eo.person` | partial | proposed |
| github | `user` | `eo` | `eo.person` | partial | proposed |
| github | `workflow_job` | `ciro` | `ciro.continuous_build_process` | partial | proposed |
| github | `workflow_run` | `ciro` | `ciro.continuous_integration_process` | partial | proposed |

## Justificativas e limitações

### `github.commit.to.cmpo.commit_artifact_copy`

**github.commit → cmpo.commit_artifact_copy** · equivalência *total* · versão 1 · status *proposed*

Um commit do Git é o ato que envia cópias de artefato para uma branch de destino, com autor, instante e mensagem — a definição de cmpo.commit_artifact_copy, que é atividade (ufo action) e não objeto. A equivalência é total para o ATO; a cópia de artefato que ele produz é outro conceito, e está fora deste mapeamento.

**Limitações**

- **As duas relações que faltavam foram declaradas** (issue #426): a participação cmpo.stakeholder_performed_commit e a associação cmpo.commit_accomplished_change_request, no módulo cmpo.change_traceability.

- `mentions_issues` aponta para sro.user_story (ou o destino que o roteamento tiver decidido) por padrão de TEXTO, e continua sem relação própria: o caminho declarado é commit → change_request → item de escopo, e a menção é atalho de confiança baixa. Quando os dois discordam, a estrutura vence — com a divergência registrada.

- **O commit não sabe em qual branch está.** O mesmo `oid` existe em quantas branches o tiverem; a branch de destino pertence ao cmpo.checkin, não ao ato isolado. O campo grava a branch em que o commit foi OBSERVADO na coleta, e nada mais se afirma.

- `cmpo.artifact_copy` (a cópia versionada de cada arquivo) NÃO é coletada: exigiria o diff por arquivo em todo commit, e nada na plataforma o consome. Sem ela, `cmpo.commit_sends_copy_to_target_branch` fica com o alvo declarado e a cópia ausente — dito, não silenciado.

- `cmpo.checkin` (o ato composto que inclui verificação de conflito, resolução e remoção de branch) não é derivável de commits isolados: precisaria do PR e do evento de merge juntos. Fica para quando o consumidor existir.

- Commit de autor sem conta no GitHub (`user: null`, comum em commits antigos e importados) fica com nome e e-mail preservados e sem vínculo com pessoa — a mesma regra dos designados e dos comentários. E-mail é dado pessoal: não vai para tela.

- Menção de issue por padrão de texto tem confiança BAIXA e nunca substitui o caminho commit → PR → issue. Quando os dois discordam, a estrutura vence, com a divergência registrada.


### `github.commit_file.to.cmpo.artifact_copy`

**github.commit_file → cmpo.artifact_copy** · equivalência *partial* · versão 1 · status *proposed*

Um arquivo alterado por um commit é a cópia daquele artefato na versão que o commit produziu — a definição de cmpo.artifact_copy. A equivalência é PARCIAL, e a palavra é escolhida: a plataforma guarda QUE arquivo mudou e quantas linhas, nunca o CONTEÚDO da cópia. A cópia existe no repositório; aqui existe o registro de que ela passou a existir.

**Limitações**

- **O conteúdo não é coletado, e isso é postura, não limitação técnica.** A plataforma registra que o arquivo mudou e quanto; o código vive no repositório. Guardar o diff faria dela um espelho de código, e nada no produto consome isso.

- **A coleta percorre TODOS os commits, e a limitação que existia era nossa.** A primeira versão coletava só dos commits de solicitações com vínculo a issue — 3.558 de 16.416 — por causa do rate limit, e a tela ia declarar "não coletado" para o resto. A REST entrega os arquivos de qualquer commit: o que faltava era esperar a janela. Agora a coleta pausa até ela reabrir, e o checkpoint por commit faz cada execução continuar de onde a anterior parou. Enquanto a primeira passada não termina, o que falta aparece como NÃO COLETADO — nunca como ausência de mudança.

- **Renomeação é delete+add no Git**, e a CMPO trata cópia de artefato, não identidade de arquivo. `previous_filename` é preservado quando a origem o informa, mas a plataforma NÃO afirma que as duas cópias são do mesmo artefato: afirmar exigiria decidir identidade a partir de heurística de similaridade.

- `status: removed` registra que a cópia deixou de existir naquele commit — e o registro fica, como toda marca desta casa. Arquivo apagado é fato sobre a mudança.


### `github.deployment.to.cdro.deployment_activity`

**github.deployment → cdro.deployment_activity** · equivalência *partial* · versão 1 · status *proposed*

Um deployment do GitHub registra a atividade automatizada que implantou um código em um ambiente. O desfecho vem do deployment status associado, não do objeto deployment em si.

**Limitações**

- O código implantado aponta para ciro.candidate_code, e CDRO não declara relação entre cdro.deployment_activity e ciro.candidate_code - a relação existente é com cdro.deployed_code. Nada materializa o vínculo como declarado.

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

### `github.issue.task.to.sro.intended_scrum_development_task`

**github.issue → sro.intended_scrum_development_task** · equivalência *derived* · versão 1 · status *proposed*

Uma issue do tipo Task descreve trabalho planejado para materializar uma user story — o que corresponde à tarefa pretendida da SRO, e não à executada. A tarefa executada é evento distinto, derivado do histórico de status do item e do fechamento da issue, e é ligada a esta por causação (sro.performed_task_caused_by_intended_task). Colapsar as duas em um registro só destrói a análise de aderência entre planejado e realizado, que é exatamente o que CQ29 pede.

**Limitações**

- Tarefa cujo pai é um épico viola sro.rule07; registrar divergência e não criar o vínculo direto com o épico.
- Tarefa sem pai fica sem user story atendida; é escopo órfão e deve aparecer como lacuna, não ser ligada ao sprint por proximidade.
- Esta issue é a tarefa PRETENDIDA. A tarefa executada vem de github.project_item_status e não deste mapeamento.
- Assignee indica quem foi designado, não necessariamente quem executou; a participação real vem de commits e reviews.

### `github.issue.to.osdef.defect`

**github.issue → osdef.defect** · equivalência *derived* · versão 1 · status *proposed*

Issue do tipo Bug é um defeito — não uma user story. Promover toda issue a user story inflaria o product backlog com correção, e o erro só apareceria quando alguém perguntasse por que o backlog cresce sem funcionalidade nova.
Este mapeamento NÃO tem `structural_requirements`. Ao contrário de épico e atômica, ser defeito não depende de composição: um bug com sub-issues continua sendo um bug. A ausência do bloco é decisão, não esquecimento.

**Limitações**

- Defeito NÃO é falta nem falha. OSDEF distingue defect, fault e failure, e o GitHub não dá base para separá-los: uma issue de bug descreve o que alguém observou, sem dizer se é a causa no artefato, o estado errado em execução, ou o desvio percebido. Só `defect` é afirmável.

- Severidade não é coletada. O que existe é label de texto livre, e mapear label para severidade por semelhança de nome é o antipadrão declarado.

- Um bug pode ser tipado como Task por times que não usam o tipo Bug. A regra é sobrescrita por tenant, e a lacuna aparece contada em vez de suposta.


### `github.issue.to.sro.epic`

**github.issue → sro.epic** · equivalência *derived* · versão 1 · status *proposed*

Épico é uma user story que TEM PARTES — sro.rule05. Não é um rótulo: é consequência da composição. Por isso `values` aqui inclui tanto os nomes de tipo "Epic" quanto os de "User Story": o que decide é `structural_requirements`, e o tipo declarado apenas informa a intenção do time.
`children_of_concept: sro.user_story` é a parte que não se pode omitir. As partes têm de ser user stories para haver composição. Se as sub-issues são todas do tipo `Task`, elas ATENDEM a user story em vez de compô-la, e a issue permanece atômica.
Quando declaração e estrutura divergem, a estrutura vence e a divergência é registrada. Ela normalmente significa uma de duas coisas, e as duas interessam a quem administra o processo: épico abandonado sem decomposição, ou user story que cresceu e virou épico sem ninguém retipar.

**Limitações**

- Um vínculo de composição que fecharia CICLO é recusado, e a recusa nomeia o caminho — sro.rule04. As duas issues permanecem coletadas: a issue existe no GitHub, e esconder dado observado por causa de relação inválida seria pior.

- Sub-issue em repositório fora do escopo observado é registrada como referência externa. A relação existe; a parte não é promovida.

- A classificação como épico é derivada da coleta, e não materializada em coluna. Uma issue que perde todas as partes deixa de ser épico — gravar o valor faria o registro divergir da estrutura no instante seguinte (ADR 0004 D7).

- `importance` e `complexity` ficam nulas, pela mesma razão do mapeamento da user story atômica.


### `github.issue.user_story.to.sro.atomic_user_story`

**github.issue → sro.atomic_user_story** · equivalência *derived* · versão 2 · status *proposed*

Uma issue promovida a user story atômica descreve um requisito do produto e não é decomposta em outras user stories. É o nível em que tarefas de desenvolvimento se ligam ao escopo (sro.rule07) e em que entregáveis materializam requisitos — por isso a distinção entre atômica e épico não é cosmética.

**Limitações**

- Issue com sub-issues que também são user stories é épico, não atômica — a estrutura vence o tipo declarado.
- Sub-issues do tipo Task não descaracterizam a user story como atômica; tarefas a atendem, não a compõem.
- Critérios de aceitação escritos no corpo em texto livre não são sro.acceptance_criterion até serem extraídos e validados; a extração não faz parte deste mapeamento.
- `importance` e `complexity` ficam NULAS, e a versão 1 deste mapeamento as lia de `fieldValueByName(Priority)` e `fieldValueByName(Estimate)`. Duas coisas erradas ali, corrigidas na versão 2.
A primeira: `Priority` NÃO é `importance`. Importance é decimal com escala declarada — "quão valiosa a user story é para a organização" —, e Priority é seleção única cujos valores o tenant inventou (P0, P1, P2). Converter um no outro é mapeamento por semelhança de nome, que o princípio I proíbe e o AGENTS.md §7.7 nomeia como antipadrão. O quadro real deste tenant não tem campo numérico de importância, e a ausência fica declarada em vez de substituída.
A segunda: `fieldValueByName` identifica o campo pelo NOME. Renomear "Priority" para "Prioridade" quebraria o mapeamento em silêncio. A identidade de um campo configurável é o identificador dele — FR-027 da feature 004 —, e o mapeamento campo→atributo passa a ser declarado por tenant em `rules/tenants/`.

- Uma issue marcada `Epic` SEM sub-issues cai aqui, e a divergência entre tipo declarado e conceito derivado fica registrada. Não existe épico sem partes (sro.rule05), e a divergência costuma significar épico abandonado sem decomposição.

- Sub-issues do tipo `Task` NÃO tornam a issue épica: tarefa ATENDE user story (sro.intended_task_planned_to_meet_user_story), não a compõe. É o erro mais fácil de cometer nesta regra.

- Sem a API de sub-issues — GitHub Enterprise Server antigo — a distinção épico/atômica NÃO é feita, e isso é declarado em vez de suprido por heurística de lista em markdown.

- Critério de aceitação não é extraído do corpo. `sro.acceptance_criterion` consta como não observável na matriz de cobertura; extrair por heurística produziria critério plausível e errado.

- Feature e User Story são tratadas como o mesmo destino, o que pode ser incorreto em organizações que usam Feature como agrupador — confirmar por tenant.

### `github.issue_comment.to.cmo.comment`

**github.issue_comment → cmo.comment** · equivalência *total* · versão 1 · status *proposed*

Um IssueComment do GitHub é exatamente uma manifestação escrita, unicamente identificada, publicada por um agente no fio de discussão de um artefato do projeto — a definição de cmo.comment. A equivalência é total porque o conceito foi criado reconhecendo esta classe de coisa, e não o contrário: a CMO nasceu da lacuna que este dado expôs.

**Limitações**

- relations.author liga o comentário a eo.person como ATALHO materializado da cadeia ontológica agente → ato de comentar → comentário (cmo.agent_performed_commenting_act + cmo.commenting_act_published_comment): a origem entrega o comentário com autor, não o ato — o ato é derivado deste registro, um por comentário, no published_at.

- relations.discussion_of liga o comentário a spo.artifact como atalho da cadeia comentário → discussão → artefato (cmo.comment_belonged_to_discussion + cmo.discussion_was_about_artifact): a discussão não é gravada como entidade — ela É o conjunto dos comentários do artefato.

- Edição e apagamento na origem: o GitHub entrega o corpo ATUAL e lastEditedAt, não o histórico de versões — o que se afirma é "o texto como estava na coleta". Comentário apagado na origem some da API; a marca no coletado é no_longer_observed_at, nunca DELETE (marca, nunca apaga).

- Reações (👍 etc.) ficam fora desta versão: são outro ato comunicativo, mais fraco, e entrariam como conceito próprio se um dia sustentarem decisão.

- Comentário de pull request review NÃO entra aqui: é outro fio (review thread), com âncora em código, e exigiria conceito próprio — registrado como lacuna.

- bodyText é texto plano: formatação, menções e links do markdown são achatados. Menção (@pessoa) como relação é derivação futura possível, não afirmada.


### `github.organization.to.eo.organization`

**github.organization → eo.organization** · equivalência *partial* · versão 1 · status *proposed*

Uma organização do GitHub é um agrupamento administrativo de repositórios e pessoas. Corresponde parcialmente à organização de EO: não representa a estrutura organizacional real, apenas o recorte visível na ferramenta.

**Limitações**

- Uma organização no GitHub pode representar apenas uma unidade organizacional, não a organização inteira.
- Times do GitHub não correspondem necessariamente a equipes de projeto (eo.project_team).

### `github.project_items.to.sro.backlogs`

**github.project_v2_item → sro.product_backlog** · equivalência *derived* · versão 1 · status *proposed*

Nem o product backlog nem o sprint backlog são objetos que o GitHub tenha. Os dois são CONJUNTOS de itens, e o que separa um do outro é uma única coisa: a atribuição de iteração.

  sem iteração atribuída          → product backlog
  iteração atribuída, já iniciada → sprint backlog daquele sprint

A composição é derivada da atribuição, e NUNCA gravada como pertencimento escolhido por quem coleta. Gravá-la seria o mesmo erro que materializar a classificação épico/atômica: no instante em que alguém arrastasse um item no quadro, o registro divergiria da origem.
Consequência verificável: a soma dos itens no product backlog e nos sprint backlogs de um projeto é igual ao total de itens dele. Nenhum item nos dois conjuntos, nenhum fora dos dois.

**Limitações**

- Item RASCUNHO não tem issue por trás, e não é promovido a nada. Ele é registrado como item sem trabalho associado — um rascunho no quadro é intenção de alguém, não escopo do produto.

- A ordem DENTRO do backlog não é coletada como ordem. sro.user_story.importance é decimal, e o quadro deste tenant não tem campo numérico — a ausência fica declarada, e nenhum outro campo é usado como substituto.

- O MOMENTO em que o item entrou na iteração não é coletado, e é ele que a matriz de cobertura pede para derivar sro.intended_scrum_development_task com confiança baixa. Exigiria o histórico de itens, fora de escopo por custo.

- Um item pode estar em mais de um quadro. Nesse caso a mesma user story aparece em mais de um backlog, o que a SRO não proíbe e ninguém deveria interpretar como duplicação.

- Iteração removida da configuração deixa seus itens sem iteração vigente. Eles NÃO voltam ao product backlog automaticamente: voltar afirmaria uma decisão de replanejamento que ninguém tomou.


### `github.project_iteration.to.spo.specific_intended_project_process`

**github.project_v2_iteration → spo.specific_intended_project_process** · equivalência *derived* · versão 1 · status *proposed*

Decisão da pessoa mantenedora, 2026-08-11: "interações futuras são plannings que não foram feitas".
Uma iteração cuja data de início ainda não chegou é intenção, não ocorrência — e é exatamente o que `spo.intended_project_process` define: "processo planejado para ser executado no projeto — uma intenção, não uma ocorrência". A categoria UFO é `intention`, e não `complex_action`.
O par é simétrico e é o que dá sentido aos dois mapeamentos:

  iteração já iniciada  → sro.sprint                            ocorreu
  iteração futura       → spo.specific_intended_project_process pretendida

Sem este mapeamento, a iteração futura ficaria só no payload, e a pergunta "o que este time planejou e ainda não executou" não teria resposta. Com ele, a resposta existe e é honesta sobre o que é: plano, não fato.

**Limitações**

- A transição de pretendida para ocorrida acontece na COLETA seguinte ao início, não no instante do início. Uma iteração que começou hoje e cuja coleta rodou ontem continua registrada como pretendida até a próxima coleta. A plataforma afirma o que observou.

- `spo.specific_intended_project_process` não é `sro.planning_meeting`. A cerimônia de planejamento é `action` — ocorreu, com pessoas, num instante — e o GitHub não a registra. Uma iteração pretendida é o RESULTADO planejado, não a reunião.

- Iteração pretendida não tem itens contados como sprint backlog. Itens atribuídos a ela permanecem no product backlog, porque o sprint dela não existe — regra github.item_iteration_assignment.

- Iteração excluída da configuração antes de começar desaparece da origem sem ter ocorrido. Ela permanece consultável, marcada como não mais presente: o plano existiu, e foi abandonado. Apagar destruiria a resposta a "o que foi planejado e nunca aconteceu".


### `github.project_iteration.to.sro.sprint`

**github.project_v2_iteration → sro.sprint** · equivalência *derived* · versão 1 · status *proposed*

A iteração do Projects v2 é o que mais se aproxima de um sprint, e não é a mesma coisa. Iteração é CONFIGURAÇÃO do quadro; sprint é processo EXECUTADO — sro.sprint é complex_action, algo que ocorreu.
Daí a condição: só iteração cuja data de início já passou é promovida. Promover uma iteração futura afirmaria um sprint que não aconteceu, e toda medida de vazão passaria a incluir sprints com zero entregas.
A promoção é derivada, não observada, e a proveniência diz isso: a origem é configuração de projeto.

**Limitações**

- Só iteração JÁ INICIADA vem para cá. A futura é pretendida, e tem mapeamento próprio para spo.specific_intended_project_process — "interações futuras são plannings que não foram feitas". A mesma iteração troca de registro ao começar.

- A data de início é PLANEJAMENTO, não observação. Um sprint que começou atrasado terá a data que o quadro dizia. Este repositório já produziu essa divergência duas vezes: sprints declarados de sete dias, aceitos no primeiro. A data ocorrida exigiria o histórico de itens, fora de escopo por custo de consumo.

- `end_date` é calculada de `startDate + duration`, e é a data PREVISTA de término. O GitHub não registra quando a iteração de fato terminou.

- Iteração removida da configuração depois de ter tido itens permanece consultável, marcada como não mais presente na origem — apagar destruiria a resposta a "o que foi feito naquele sprint".

- Iteração NÃO é release. O mesmo campo é usado por times para as duas coisas, e distinguir exigiria declaração do tenant.

- sro.scrum_process, que a matriz de cobertura lista como derivável da existência de sprints, NÃO é derivado aqui. A confiança declarada é baixa, e inferir processo a partir de configuração de quadro seria afirmar demais.


### `github.pull_request.to.cmpo.change_request`

**github.pull_request → cmpo.change_request** · equivalência *total* · versão 1 · status *proposed*

Um Pull Request é a solicitação formal de que alterações em cópias de artefato sob controle de versão sejam avaliadas e integradas a uma branch de destino — a definição literal de cmpo.change_request, que cita o Pull Request como o exemplo. A equivalência é total porque o conceito foi escrito reconhecendo esta classe de coisa.

**Limitações**

- **As relações que faltavam foram declaradas** (2026-08-17, issue #426): o módulo cmpo.change_traceability traz as participações (submeter, integrar, commitar) e o módulo sro.scope_traceability traz o atendimento ao item de escopo. Antes disso este mapeamento afirmava os vínculos sem lastro; agora cada um materializa relação declarada, e a nota de cada campo diz qual.

- `requested_by` liga a solicitação a eo.person como ATALHO materializado da cadeia declarada — spo.project_stakeholder → cmpo.change_request_submission (participação) → cmpo.change_request (causação). Não há, e não deve haver, relação direta entre cmpo.change_request e eo.person: participação é entre agente e EVENTO, e a solicitação é objeto social. O atalho existe porque a origem entrega o PR com autor, não o ato de submeter.

- `integrated_by` liga a solicitação a eo.person pelo mesmo tipo de atalho, sobre outra cadeia — spo.project_stakeholder → cmpo.checkin (participação) → cmpo.change_request (associação). Guardar os dois como atributos da solicitação é decisão de coleta, e a derivação dos atos fica para quando algo os consumir.

- **Continua sem relação entre cmpo.change_request e as branches** (cmpo.source_branch, cmpo.target_branch): a única declarada é cmpo.commit_sends_copy_to_target_branch, que parte do ato de commitar e não da solicitação. Os dois nomes ficam como atributos com o papel nomeado — não foi declarada porque nada na plataforma consome o vínculo, e declarar relação sem consumidor é infraestrutura sem consumidor visível.

- **PR mergeado não é cmpo.change_request "concluída": o merge é outra coisa.** O ato de integrar é cmpo.checkin (composto de cmpo.commit_artifact_copy e, quando a branch é apagada, cmpo.delete_branch), e o fechamento aprovado é cmpo.change_request_closing. Este mapeamento grava `merged_at` e `integrated_by` como atributos da solicitação, e a derivação dos dois atos fica para quando algo os consumir — declarar isso é o que impede tratar "mergeado" como propriedade do pedido.

- Revisões (approvals, change requests, review threads) NÃO entram: são `cmpo.change_control` em outra atividade, e review thread tem âncora em código — a mesma lacuna já declarada no mapeamento de comentário.

- Conflito (cmpo.conflict, cmpo.artifact_copy_with_conflict) não é coletável pela API de PR: o GitHub expõe `mergeable`, que é o estado de AGORA, não o histórico de conflitos resolvidos. Afirmar cmpo.resolve_conflict a partir dele seria inventar.

- `closingIssuesReferences` só existe no GraphQL. A API REST de PR não traz o vínculo com issue — quem coletar por REST fica sem o elo, e a ausência precisa ser dita em vez de virar "PR sem issue".

- Menção de issue no corpo sem closing keyword (`Refs #318`) é vínculo mais fraco e fica FORA: promovê-lo ao mesmo conceito faria "mencionou" e "atende" a mesma coisa. Se um dia sustentar decisão, é conceito próprio.


### `github.pull_request_review.to.qapo.artifact_evaluation`

**github.pull_request_review → qapo.artifact_evaluation** · equivalência *partial* · versão 3 · status *proposed*

Uma review de Pull Request é uma avaliação de artefato: alguém avalia objetivamente a aderência das alterações a critérios aplicáveis. O estado CHANGES_REQUESTED indica não conformidades identificadas; APPROVED indica conformidade na avaliação daquele revisor.

**Limitações**

- RESOLVIDA na versão 2 — "a participação de agente em avaliação ainda não é modelada": o módulo de projeto `qapo.evaluation_participation` declara `qapo.stakeholder_performed_artifact_evaluation` e `qapo.artifact_evaluation_evaluates`. A relação aponta para `spo.project_stakeholder` e para o papel `qapo.evaluated_artifact`, e não para `eo.person` nem para `cmpo.change_request` — é o que a mantém dentro das dependências declaradas da QAPO (`[ufo, spo]`), sem inverter a rede.

- Aprovação não implica ausência de não conformidades, apenas ausência de bloqueio. O `state` é preservado CRU **e** interpretado por `value_map`; nenhuma das duas colunas afirma conformidade. `qapo.endorsing_verdict` é definido como "apto a seguir", e não como "sem problema" — a relação `artifact_evaluation_identified_noncompliance` declara `many` no destino justamente porque inclui zero e não o exige.

- O veredito é a posição de UM avaliador, e não o estado da solicitação. Três endossos e uma objeção são quatro avaliações com quatro vereditos; se a mudança entrou ou não é outra pergunta, e quem a responde é `cmpo.stakeholder_performed_checkin`.

- RESOLVIDA na versão 2 — "reviews automáticas devem ser classificadas separadamente": `author_type` guarda o `__typename` da origem, e toda contagem separa `User` de `Bot`. Sem isso a medida de tempo até a primeira revisão mediria o robô.

- RESOLVIDA na versão 2 — "um comentário isolado não é uma review": a coleta usa a conexão `reviews`, e não `reviewThreads`. Só evento de review submetida entra.

- Review em rascunho (`PENDING`) vem sem `submittedAt`. É gravada com nulo — existe e não foi submetida —, e a medida de tempo até a primeira revisão a exclui.

- `reviews.totalCount` é comparado com o que chegou, e o total fica em `collected_change_requests.reviews_total`: truncamento nunca é silencioso.


### `github.ref.to.cmpo.branch`

**github.ref → cmpo.branch** · equivalência *partial* · versão 2 · status *proposed*

Uma ref do tipo branch é o coletivo dos artefatos de um repositório em uma linha de desenvolvimento — a Branch de CMPO. Branch de origem e de destino são papéis assumidos em um check-in, e não tipos de branch.

**Limitações**

- RESOLVIDA na versão 2 — "tags também são refs": a consulta usa `refPrefix: "refs/heads/"`, e tag não entra.

- Branch protegida ou default é configuração da ferramenta, não distinção ontológica. As duas são guardadas porque descrevem POLÍTICA, e política é o que se compara com o que de fato aconteceu — não porque criem subtipos de branch.

- `branchProtectionRule` exige escopo de administração. Sem ele o campo não vem, e a coleta grava `false` **contando separadamente** em `branch_protection_unknown`: "não soubemos dizer" nunca vira "não protegida".

- **Esta coleta não é incremental**, ao contrário das demais. A pergunta é "que branches existem agora", e responder exige o conjunto inteiro para saber o que deixou de existir.

- Branch mergeada é APAGADA na origem, e o histórico dela não está aqui: está no `source_branch` das solicitações de mudança. Medido em 2026-08-19, 2.461 nomes de branch de origem distintos contra 6, 63 e 47 branches vivas nos repositórios do piloto. A solicitação aponta para um nome que pode não ter entidade, e a tela precisa dizer isso.

- Branch que sumiu é MARCADA, nunca removida: ela existiu, e o check-in que aconteceu nela continua sendo fato sobre o processo.


### `github.repository.to.cmpo.source_repository`

**github.repository → cmpo.source_repository** · equivalência *partial* · versão 3 · status *proposed*

Um repositório do GitHub é uma cópia carregada de sistema de software cujo propósito é tratar mudanças de cópias de artefato — exatamente o papel do Source Repository em CMPO. Não é o projeto de software (SPO) nem o produto (SysSwO); um projeto pode ter vários repositórios.
Parcial, e não total: um repositório do GitHub também hospeda issues, wiki e execuções de CI, que estão fora do que o conceito cobre. O que sobra é mapeado por outros mapeamentos — issue vai para SRO —, e o que não é mapeado por nenhum permanece só no payload preservado.
Atravessa a fronteira de ontologia: cmpo.source_repository é subkind de sys_swo.loaded_software_system_copy, logo materializa por REFERÊNCIA — valor de discriminador na tabela daquele kind, com extensão em CMPO para os atributos próprios. Constituição IX, a regra da fronteira.

**Limitações**

- O proprietário aponta para eo.organization, e a relação entre cmpo.source_repository e eo.organization AINDA não está declarada na base. A direção CMPO → EO é permitida — vai do específico para o geral —, mas declarar a relação é passo próprio, como foi eo.organizational_team_belongs_to_organization na feature 002. Até lá o vínculo existe no mapeamento e não no modelo derivado.

- Repositório NÃO é projeto; não derivar spo.software_project automaticamente daqui. O projeto de software vem do Projects v2, por mapeamento próprio — um projeto pode ter vários repositórios, e um repositório pode servir a vários projetos.

- Forks e mirrors representam o mesmo item de configuração em instâncias diferentes.
- `isFork` NÃO é coletado como booleano, de propósito. Ser fork é dizer que esta cópia deriva de OUTRA cópia — é relação, não propriedade. Um booleano seria o antipadrão "booleano no lugar do relator" nomeado no AGENTS.md §7.7: guardaria que existe origem e perderia qual é. Fica pendente até a relação cópia-deriva-de-cópia ser declarada em CMPO.

- `languages` — a lista com todas as linguagens — não é coletada. Só `primaryLanguage` é, e como atributo do repositório. A lista completa exigiria um conceito próprio para linguagem, e uma relação com peso por linguagem; sem isso seria um array sem semântica declarada.

- `primary_language` é calculada pela ORIGEM sobre o código, e não é propriedade da cópia carregada em si. Registrada no repositório porque é onde a origem a fornece, com a atribuição declarada aqui em vez de presumida.

- `licenseInfo` e `diskUsage` não são coletados: licença é conceito de outra ontologia, e tamanho em disco é métrica da hospedagem, não do item de configuração.

- `default_branch` guarda o NOME do ramo, não uma referência a `cmpo.branch`. A relação existiria — `cmpo.branch_belongs_to_repository` já está declarada —, mas apontar para ela exigiria coletar ramos, que está fora do escopo desta feature.

- `archivedAt` diz que a ORIGEM arquivou, e isso não é ausência. Repositório arquivado continua observado, e suas issues continuam consultáveis. Confundir os dois faria a plataforma marcar como não mais observado o que ela vê muito bem — e a exclusão decidida pelo tenant é uma TERCEIRA coisa, que vive na camada de plataforma porque é decisão e não fato do mundo.


### `github.team.to.eo.organizational_team`

**github.team → eo.organizational_team** · equivalência *partial* · versão 1 · status *proposed*

Um time do GitHub é um coletivo de pessoas mantido pela organização, com acesso comum a um conjunto de repositórios. Corresponde a eo.organizational_team, que é a equipe ligada à organização — e não a eo.project_team, que é ligada a um projeto.
A API oferece os campos repositories e projectsV2 no time, o que permitiria derivar eo.project_team quando houver vínculo. Mas o vínculo é opcional e frequentemente não é usado: na organização verificada, os dois times têm zero repositórios e zero projetos associados, servindo apenas para agrupar pessoas. Por isso o alvo padrão é eo.organizational_team, e a promoção a eo.project_team exige vínculo efetivamente presente ou declaração do tenant.

**Limitações**

- Este mapeamento cobre apenas equipe OBSERVADA no GitHub. A equipe derivada, que a plataforma cria com o nome da organização para acolher quem não está em time algum, não vem de payload nenhum e por isso não tem mapeamento: é produzida pela regra github.default_team. Declarar aquela regra aqui, em derivation.rule_id, marcaria toda equipe observada como derivada.

- Os repositórios concedidos apontam para cmpo.source_repository, e EO não declara relação entre eo.organizational_team e cmpo.source_repository. EO não depende de CMPO, e criar a relação inverteria a direção de dependência entre as ontologias - decisão que precede a coluna.

- Time do GitHub é agrupamento de permissão de acesso; não implica que seus membros trabalhem juntos em um projeto.
- Os campos repositories e projectsV2 existem mas são opcionais; quando vazios, não há como distinguir equipe de projeto de equipe organizacional pelos dados.
- A correspondência entre um time e um projeto de software precisa ser declarada pelo tenant quando o vínculo não existe na API; nomes coincidentes não bastam.
- A hierarquia de times (parentTeam, childTeams, ancestors) existe na API, mas EO não define composição entre equipes; a hierarquia é registrada como atributo e não como relação ontológica.
- Uma pessoa pode integrar vários times, e os conjuntos de membros de time, de organização e de colaboradores de repositório são distintos entre si.

### `github.team_member.to.eo.person`

**github.team_member → eo.person** · equivalência *partial* · versão 1 · status *proposed*

A associação entre um time do GitHub e uma conta identifica a pessoa que integra aquele time. É por isso que este mapeamento tem como alvo eo.person, e não eo.team_membership: a alocação exige um papel organizacional, que o GitHub não fornece.
O vínculo pessoa-time observado é preservado como evidência, com o nível de acesso na plataforma (MAINTAINER ou MEMBER) registrado como atributo do vínculo — não como papel. A promoção a eo.team_membership ocorre quando o tenant atribui o papel organizacional, conforme github.team_membership_evidence.

**Limitações**

- MAINTAINER e MEMBER são níveis de acesso na plataforma, não papéis organizacionais; não devem virar eo.organizational_role.
- Sem papel atribuído pelo tenant, o vínculo não é promovido a eo.team_membership e CQ14 e CQ16 permanecem sem resposta.
- A API não informa quando a pessoa entrou no time; started_at e ended_at ficam nulos e o histórico de alocação não é reconstituível.
- Contas do tipo Bot podem integrar times e não são pessoas; devem ser classificadas separadamente.
- Um vínculo deixa de ser vigente por DUAS causas, e elas significam coisas diferentes. PRIMEIRA - a origem mudou: remoção de uma pessoa do time no GitHub não gera evento, e só é detectável por comparação entre coletas. SEGUNDA - a plataforma parou de olhar: o tenant encerrou a observação daquela organização, e a decisão é da plataforma, não fato sobre a origem.

- A distinção decide o que a retomada faz. Vínculo marcado pela SEGUNDA causa volta a ser vigente na coleta seguinte, se a origem ainda o mostrar. Vínculo marcado pela PRIMEIRA só volta se a origem passar a mostrá-lo de novo. Tratar as duas iguais faria a retomada ressuscitar vínculo que a origem já não tem, e a plataforma afirmaria observação que não ocorreu.

- A causa não é coluna: é derivável. Registro marcado cuja ferramenta tem evento de encerramento posterior à última coleta foi marcado pela segunda causa; os demais, pela primeira. Acrescentar coluna em pessoas, equipes e vínculos criaria três lugares para discordarem sobre o mesmo fato.

- O e-mail não é coletado, pela mesma razão declarada em github.user.to.eo.person - exigiria escopo mais amplo do que a coleta precisa.

### `github.user.to.eo.person`

**github.user → eo.person** · equivalência *partial* · versão 1 · status *proposed*

Uma conta de usuário do GitHub identifica um agente que atuou no repositório. Não é a pessoa: uma pessoa pode ter várias contas, e uma conta pode ser um bot ou uma conta de serviço. A identidade de pessoa exige reconciliação explícita.

**Limitações**

- Não existe vínculo direto entre pessoa e organização, e este mapeamento não o declara. A versão anterior declarava relations.organization apontando para eo.organization, e EO não tem nem deve ter essa relação - o vínculo com organização passaria por papel organizacional, que o GitHub não fornece. O caminho respondível é pessoa -> equipe -> organização, e quem não está em equipe alguma não aparece em organização alguma. Ver eo.cq02.

- O caminho organization.id não existe no payload de um membro - a organização é o pai da consulta, não campo do nó. Declará-lo produziu eo_people.organization_id nula em 100% dos registros. Achados F3 e F6 da feature 002.

- Contas do tipo Bot e App não são pessoas e devem ser classificadas separadamente.
- A mesma pessoa pode ter múltiplas contas; a unificação exige regra explícita, nunca heurística de nome.
- O e-mail não é coletado. O campo existe na API, mas exige o escopo read:user ou user:email, mais amplo do que a coleta precisa, e costuma vir nulo por configuração de privacidade. Pedir escopo maior por um campo quase sempre vazio amplia a superfície de acesso sem contrapartida. Consequência - eo.person.email permanece nulo quando a fonte é o GitHub, e qualquer análise que dependa de e-mail não é respondível a partir dela.

### `github.workflow_job.to.ciro.ci_component_process`

**github.workflow_job → ciro.continuous_build_process** · equivalência *partial* · versão 1 · status *proposed*

Um job é um processo automatizado com participação do servidor de CI, executado como parte do processo de CI — a forma dos três componentes da CIRO. A equivalência é PARCIAL, e a palavra é escolhida: qual dos três um job é depende de regra sobre o nome e as etapas, e um job pode materializar mais de um. O `target.concept` acima é o padrão da regra; a classificação real vai no registro, com a confiança.

**Limitações**

- **A granularidade da origem é mais grossa que a da ontologia, e isso virou antipadrão** (`ci.ap01.monolithic_job`, decidido em 2026-08-18). A CIRO distingue build, teste e inspeção; um job do GitHub pode ser os três — o `quality-gates` deste repositório roda formatação, Credo, Sobelow, Dialyzer e os testes numa etapa só. A classificação registra TODOS os componentes reconhecidos, nunca escolhe um; e o agrupamento é REPORTADO, porque o custo dele é "quebrou" deixar de dizer o quê.

- A confiança é `low` de propósito: o nome do job é convenção de quem escreveu o workflow, não tipo declarado. Nome irreconhecível NÃO vira build por padrão — o job fica coletado sem classificação, e isso também é antipadrão nomeado (`ci.ap02.unnamed_components`): a verificação existe e a plataforma não sabe o que ela verifica.

- As fases do job seguem as do processo, incluindo as três de `ciro.interrupted_verification`: job `skipped` é ciro.unperformed_continuous_integration_process, e é comum — pular porque o anterior falhou é fato sobre o processo, não sobre a qualidade do código.

- ciro.build_problem e ciro.ci_test_result exigem os logs, que não são coletados aqui — job que falhou é malsucedido sem o problema descrito, e a tela diz isso em vez de inventar a causa.

- Etapas (steps) NÃO são mapeadas para ciro.build_composed_of_code_checkout / _environment_creation / _candidate_code_building, embora a CIRO os tenha: a correspondência exigiria reconhecer semanticamente cada etapa, e nada consome isso hoje. Os nomes ficam preservados para quando consumir.


### `github.workflow_run.to.ciro.continuous_integration_process`

**github.workflow_run → ciro.continuous_integration_process** · equivalência *partial* · versão 2 · status *proposed*

Uma execução de workflow do GitHub Actions **pode ser** uma ocorrência automatizada de processo de integração contínua — e a versão 1 deste mapeamento afirmava que sempre é. O dado desmentiu: das 1.051 execuções coletadas em 2026-08-18, 399 não são nem verificação nem implantação (`Sync to GitLab`, `Sprint Rollover`, `Card de promoção`).
O tipo é **derivado dos componentes dos jobs**, nunca assumido pela entidade de origem. Sem componente reconhecido, a execução fica sem tipo — a rede não tem conceito para automação de quadro, e dizê-lo é mais honesto que forçá-la num de verificação.
O gatilho decide o SUBTIPO (check-in, agendado, sob demanda) e é eixo independente do tipo e da fase.

**Limitações**

- A execução aponta para cmpo.source_repository, e CIRO não declara relação entre ciro.continuous_integration_process e cmpo.source_repository. Nada materializa o vínculo.

- RESOLVIDA na versão 2 — "nem todo workflow é integração contínua": o tipo passou a ser derivado dos componentes, e `cdro.continuous_deployment_process` é um dos resultados. A limitação estava declarada aqui desde a versão 1 e o código a ignorava; foi o dado real que a cobrou.

- RESOLVIDA na versão 2 — "cancelled e skipped não são insucesso": viraram `ciro.interrupted_*` e `ciro.unperformed_*`, e `timed_out` virou `ciro.expired_*`.

- A execução sem componente reconhecido fica **sem tipo**. Isso é ausência nomeada, não falha de coleta — e a tela nunca as escreve com a mesma frase.

- updated_at aproxima o término, mas não é o instante exato de fim.
- RESOLVIDA na versão 2 — o job vem da rota `/actions/runs/{id}/jobs`, com as etapas, e `github.ci_job_routing` o classifica. Não exigiu `check_run`.


