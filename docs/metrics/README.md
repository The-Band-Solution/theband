<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO. -->


# Necessidades de informação e medidas

Nenhuma medida existe sem uma necessidade de informação declarada, e nenhum dashboard existe sem medida rastreável até esta página.

## Necessidades de informação

### `ci.pipeline_success_rate` — Taxa de sucesso da integração contínua

**Pergunta.** Qual a proporção de processos de integração contínua concluídos com sucesso em um repositório?

**Decisão apoiada.** Decidir sobre investimento em estabilidade do pipeline, cobertura de testes e qualidade do código integrado.

**Stakeholders.** engineering_manager, team_lead, developer

**Conceitos necessários.** `ciro.continuous_integration_process`, `ciro.successful_continuous_integration_process`, `ciro.unsuccessful_continuous_integration_process`, `cmpo.source_repository`

**Medidas candidatas.** `ci.pipeline_success_rate.ratio`

### `flow.throughput` — Vazão de tarefas concluídas

**Pergunta.** Quantas tarefas de desenvolvimento o time conclui por sprint, e essa taxa se sustenta ao longo dos sprints?

**Decisão apoiada.** Dimensionar o escopo do próximo sprint a partir do que foi concluído nos sprints anteriores, em vez de a partir do que se deseja concluir, e detectar queda ou salto de vazão que exija investigação antes de replanejar.

**Stakeholders.** product_manager, scrum_master, engineering_manager, team_lead

**Conceitos necessários.** `sro.performed_scrum_development_task`, `sro.intended_scrum_development_task`, `sro.sprint`, `sro.deliverable`, `sro.accepted_deliverable`, `spo.performed_project_activity`

**Medidas candidatas.** `flow.throughput.rate`

### `flow.work_in_progress` — Trabalho em andamento

**Pergunta.** Quantas tarefas de desenvolvimento estavam simultaneamente em execução em um sprint num dado instante, e há quanto tempo cada uma está aberta?

**Decisão apoiada.** Decidir se o time deve parar de puxar trabalho novo e concluir o que já começou, e onde intervir quando uma tarefa deixou de avançar. Sustenta também a decisão de limitar o escopo do próximo sprint, comparando o que está aberto com o que costuma ser concluído.

**Stakeholders.** product_manager, scrum_master, engineering_manager, team_lead

**Conceitos necessários.** `sro.performed_scrum_development_task`, `sro.intended_scrum_development_task`, `sro.sprint`, `sro.sprint_backlog`, `spo.performed_project_activity`

**Medidas candidatas.** `flow.wip.count`

### `people.demonstrated_domains` — Domínios técnicos demonstrados por uma pessoa, e como mudaram

**Pergunta.** Em que domínios técnicos há evidência registrada de atuação desta pessoa, desde quando, e o que mudou entre o começo e o fim do período observado?

**Decisão apoiada.** Decidir a quem oferecer uma tarefa, e em que frente apoiar o desenvolvimento de alguém, a partir de onde a evidência já existe — e não de memória de quem acompanhou de perto.
**O que esta necessidade explicitamente não responde**, e onde quem decide precisa buscar em outro lugar: qualidade do trabalho entregue, confiabilidade como traço da pessoa, esforço, e nível de senioridade. O escopo das tarefas atribuídas reflete o nível que o time já presumia, então usá-lo para inferir nível é circular.
Ausência de um domínio é lacuna do registro, nunca lacuna de competência: em 2026-08-15, 1298 de 2949 descrições de tarefa concluída foram escritas por outra pessoa que não quem executou, e 355 tarefas tinham dois ou mais designados.

**Stakeholders.** engineering_manager, team_lead, developer

**Conceitos necessários.** `eo.person`, `eo.team_member`, `spo.performed_project_activity`, `cmpo.source_repository`

**Medidas candidatas.** 

### `review.time_to_first_review` — Tempo até a primeira revisão

**Pergunta.** Quanto tempo uma solicitação de mudança aguarda até receber a primeira revisão?

**Decisão apoiada.** Identificar gargalos no processo de revisão de código e decidir sobre redistribuição de revisores ou limites de trabalho em progresso.

**Stakeholders.** engineering_manager, team_lead, scrum_master

**Conceitos necessários.** `cmpo.change_request`, `qapo.artifact_evaluation`, `eo.person`

**Medidas candidatas.** `review.time_to_first_review.duration`

### `rework.effort_on_not_accepted_deliverables` — Esforço gasto em entregáveis não aceitos

**Pergunta.** Quanto do trabalho executado em um sprint produziu entregáveis que não foram aceitos?

**Decisão apoiada.** Avaliar qualidade do trabalho e produtividade da equipe, e decidir sobre revisão dos critérios de aceitação ou da granularidade das user stories.

**Stakeholders.** product_owner, scrum_master, engineering_manager

**Conceitos necessários.** `sro.performed_scrum_development_task`, `sro.non_successfully_performed_scrum_development_task`, `sro.not_accepted_deliverable`, `sro.sprint`, `sro.atomic_user_story`

**Medidas candidatas.** `rework.not_accepted_deliverable_ratio`

## Medidas

### `ci.pipeline_success_rate.ratio` — Taxa de sucesso do processo de integração contínua

Responde a: `ci.pipeline_success_rate`

```text
(successful_ci_processes / total_ci_processes) * 100
```

Tipo: `percentage` · unidade: `percent` · níveis: repository, project, team

**Limitações**

- Execuções canceladas e puladas não são insucesso e devem sair do denominador.
- Repositórios com pipelines de propósitos distintos precisam de recorte por workflow.
- Reexecução manual de um pipeline que falhou pode inflar artificialmente a taxa.

**Interpretações incorretas possíveis**

- Taxa alta com poucos testes não indica qualidade; cruzar com cobertura e inspeção.

### `flow.throughput.rate` — Vazão de tarefas concluídas por sprint

Responde a: `flow.throughput`

```text
count(performed_tasks WHERE end_date IS NOT NULL AND end_date BETWEEN sprint_start_date AND sprint_end_date)

```

Tipo: `count` · unidade: `tasks_per_sprint` · níveis: sprint, project, team, person

**Limitações**

- Contar tarefa concluída ignora o tamanho da tarefa - uma de duas horas e uma de duas semanas pesam igual, e decompor mais fino eleva a vazão sem que mais trabalho tenha sido feito.
- Depende de end_date registrado. Quando o fim é derivado da transição de status do item do Projects v2, a confiança é média, e tarefa fechada fora da ferramenta não entra na contagem.
- Tarefa concluída cujo entregável foi recusado atravessou o fluxo e não entregou resultado. Ela conta na vazão; a separação entre tarefa bem-sucedida e malsucedida depende de a aceitação ter sido registrada contra os criterios de aceitação, e é ato do Product Owner.
- Tarefa reaberta e concluída de novo conta duas vezes sobre a mesma unidade de trabalho. Este projeto exige criar nova tarefa pretendida em vez de reabrir a executada; onde a regra não for seguida na ferramenta, a vazão infla sem aviso.
- Comparar sprints exige duração constante. O campo Iteration deste projeto usa 14 dias; sprint encurtado por feriado ou interrompido produz um valor menor que não é queda de vazão.
- Trabalho que não virou tarefa - revisão de solicitação de mudança, apoio a incidente, espera por terceiro - consome capacidade e não aparece na contagem, o que faz a vazão medida ser menor que o trabalho realizado.
- Tarefa que começou em um sprint e terminou no seguinte é atribuída inteira ao sprint de término, o que credita ao sprint seguinte esforço gasto no anterior.
- No nível person, a mesma tarefa aparece uma vez por participante quando há mais de um responsável, e a soma dos níveis person não é igual ao nível sprint.

**Interpretações incorretas possíveis**

- Vazão não é produtividade. Ela responde quanto trabalho atravessa o sistema, nunca se o trabalho valeu a pena; o valor entregue não se lê nesta medida.
- Vazão alta não indica time saudável. Decompor tarefas mais fino, ou concluir apenas o que é fácil, eleva o número sem mudar o resultado.
- Vazão baixa não indica time lento. Pode indicar tarefas grandes demais, bloqueio externo, ou trabalho consumido por atividade que não virou tarefa.
- Usar a vazão como meta a bater a torna alvo, e alvo deixa de ser medida - o efeito conhecido é fechar tarefa no board antes de o trabalho terminar, com o retrabalho aparecendo depois.
- Comparar vazão entre times sem normalizar pelo tamanho do time e pelo critério de decomposição transforma a medida em contagem de pessoas ou de granularidade.
- Um sprint isolado não descreve o fluxo. Vazão só sustenta dimensionamento de escopo lida como série ao longo de vários sprints, com a dispersão à vista.
- Vazão e WIP não se somam nem se substituem. Interpretadas juntas com o tempo de conclusão descrevem o fluxo; isoladas, cada uma admite explicações opostas.

### `flow.wip.count` — Quantidade de tarefas em andamento

Responde a: `flow.work_in_progress`

```text
count(performed_tasks WHERE start_date <= observation_instant AND (end_date IS NULL OR end_date > observation_instant))

```

Tipo: `count` · unidade: `tasks` · níveis: sprint, project, team, person

**Limitações**

- Contar tarefa aberta ignora o tamanho da tarefa - uma de duas horas e uma de duas semanas pesam igual, e um time que decompõe grosso parece ter menos trabalho aberto do que tem.
- Depende de start_date registrado. Quando o início é derivado da transição de status do item do Projects v2, a confiança é média, e tarefa que nunca passou por "em andamento" não aparece em nenhum instante.
- Tarefa sem end_date pode estar em execução ou abandonada; a medida não distingue as duas situações e trata o abandono como trabalho ativo.
- Tarefa reaberta gera um segundo intervalo aberto sobre a mesma unidade de trabalho e conta duas vezes no mesmo instante. Este projeto exige criar nova tarefa pretendida em vez de reabrir a executada; onde a regra não for seguida na ferramenta, a contagem infla sem aviso.
- Trabalho que não virou tarefa - revisão de solicitação de mudança, apoio a incidente, espera por terceiro - consome capacidade e não entra na contagem, o que faz o WIP medido ser menor que o WIP real.
- Um valor isolado não descreve o sprint. WIP é série temporal, e o instante escolhido determina o resultado: fim de semana, feriado e véspera de review deprimem o número por motivos que nada têm a ver com fluxo.
- No nível person, o mesmo trabalho aparece uma vez por participante quando há mais de um responsável, e a soma dos níveis person não é igual ao nível sprint.

**Interpretações incorretas possíveis**

- WIP baixo não significa fluxo saudável; pode indicar time bloqueado, dependência externa, ou tarefas grandes demais para se manifestarem como várias.
- WIP alto não é sinônimo de produtividade. Costuma ser o contrário - quanto mais itens abertos ao mesmo tempo, maior o tempo de conclusão de cada um, porque o mesmo esforço se divide.
- Comparar WIP entre times sem normalizar pelo tamanho do time transforma a medida em contagem de pessoas.
- WIP não é medida de esforço nem de capacidade. Somá-lo a story points, ou convertê-lo em capacidade do sprint, mistura unidades que não se somam.
- Reduzir o número por decreto não melhora o fluxo; fecha tarefa no board sem que o trabalho tenha terminado, e o efeito aparece depois como retrabalho.

### `review.time_to_first_review.duration` — Duração até a primeira revisão

Responde a: `review.time_to_first_review`

```text
first_review_submitted_at - change_request_opened_at
```

Tipo: `duration` · unidade: `seconds` · níveis: change_request, repository, project, team

**Limitações**

- Revisões automáticas devem ser excluídas ou classificadas separadamente.
- Solicitações de mudança sem revisão não possuem valor concluído e não entram na média.
- Solicitações abertas como rascunho distorcem o início da espera.

**Interpretações incorretas possíveis**

- Um valor baixo pode indicar revisão superficial, não agilidade.
- A média esconde a cauda; usar percentis para decisão sobre gargalo.

### `rework.not_accepted_deliverable_ratio` — Proporção de tarefas que produziram entregáveis não aceitos

Responde a: `rework.effort_on_not_accepted_deliverables`

```text
non_successfully_performed_tasks / performed_tasks
```

Tipo: `ratio` · unidade: `proportion` · níveis: sprint, project, team

**Limitações**

- Depende de que a aceitação dos entregáveis tenha sido registrada contra critérios de aceitação.
- Tarefas sem entregável associado ficam fora do numerador e do denominador.
- Uma tarefa que produziu vários entregáveis conta uma vez, mesmo com apenas um não aceito.

**Interpretações incorretas possíveis**

- Retrabalho não é sinônimo de baixa produtividade; pode indicar critérios de aceitação mal definidos.
- Comparar equipes por esta medida sem normalizar complexidade das user stories induz conclusão errada.

