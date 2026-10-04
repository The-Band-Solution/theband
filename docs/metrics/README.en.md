<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->


# Information needs and measures

!!! note "Generated from the knowledge base — part of the text is still in Portuguese"
    This page is generated from `priv/knowledge_base/`. The headings, labels and tables are in English. The texts of the base — definitions, descriptions, questions, justifications — are shown in English where the base has them in English; otherwise the Portuguese original appears, marked `pt-BR`.

    **183 of 211** texts on this page exist in the base only in Portuguese. The English text is written in the base, in the `en` field, and not on this page: the page is regenerated and would lose it.

No measure exists without a declared information need, and no dashboard exists without a measure traceable to this page.

## Information needs

### `ci.pipeline_success_rate` — `pt-BR` Taxa de sucesso da integração contínua

**Question.** `pt-BR` Qual a proporção de processos de integração contínua concluídos com sucesso em um repositório?

**Decision supported.** `pt-BR` Decidir sobre investimento em estabilidade do pipeline, cobertura de testes e qualidade do código integrado.

**Stakeholders.** engineering_manager, team_lead, developer

**Required concepts.** `ciro.continuous_integration_process`, `ciro.successful_continuous_integration_process`, `ciro.unsuccessful_continuous_integration_process`, `cmpo.source_repository`

**Candidate measures.** `ci.pipeline_success_rate.ratio`

### `flow.open_work_balance` — Balance between what opens and what closes

**Question.** Is the team closing work as fast as it arrives, and is the open work growing or shrinking over time?

**Decision supported.** Decide whether a team's problem is capacity or intake. A team that closes well and still accumulates does not need to work faster — it needs less to arrive, or someone to decide what will not be done.

**Stakeholders.** engineering_manager, team_lead, scrum_master, product_manager

**Required concepts.** `sro.intended_scrum_development_task`, `sro.performed_scrum_development_task`, `eo.team`, `eo.team_membership`, `eo.person`

**Candidate measures.** `flow.open_work.cumulative`, `flow.completion.forecast`

### `flow.throughput` — Throughput of concluded tasks

**Question.** How many development tasks does the team conclude per sprint, and does that rate hold across sprints?

**Decision supported.** `pt-BR` Dimensionar o escopo do próximo sprint a partir do que foi concluído nos sprints anteriores, em vez de a partir do que se deseja concluir, e detectar queda ou salto de vazão que exija investigação antes de replanejar.

**Stakeholders.** product_manager, scrum_master, engineering_manager, team_lead

**Required concepts.** `sro.performed_scrum_development_task`, `sro.intended_scrum_development_task`, `sro.sprint`, `sro.deliverable`, `sro.accepted_deliverable`, `spo.performed_project_activity`

**Candidate measures.** `flow.throughput.rate`

### `flow.work_in_progress` — Work in progress

**Question.** How many development tasks were simultaneously in progress in a sprint at a given instant, and how long has each one been open?

**Decision supported.** `pt-BR` Decidir se o time deve parar de puxar trabalho novo e concluir o que já começou, e onde intervir quando uma tarefa deixou de avançar. Sustenta também a decisão de limitar o escopo do próximo sprint, comparando o que está aberto com o que costuma ser concluído.

**Stakeholders.** product_manager, scrum_master, engineering_manager, team_lead

**Required concepts.** `sro.performed_scrum_development_task`, `sro.intended_scrum_development_task`, `sro.sprint`, `sro.sprint_backlog`, `spo.performed_project_activity`

**Candidate measures.** `flow.wip.count`

### `people.demonstrated_domains` — Technical domains a person has demonstrated, and how they changed

**Question.** `pt-BR` Em que domínios técnicos há evidência registrada de atuação desta pessoa, desde quando, e o que mudou entre o começo e o fim do período observado?

**Decision supported.** `pt-BR` Decidir a quem oferecer uma tarefa, e em que frente apoiar o desenvolvimento de alguém, a partir de onde a evidência já existe — e não de memória de quem acompanhou de perto.
**O que esta necessidade explicitamente não responde**, e onde quem decide precisa buscar em outro lugar: qualidade do trabalho entregue, confiabilidade como traço da pessoa, esforço, e nível de senioridade. O escopo das tarefas atribuídas reflete o nível que o time já presumia, então usá-lo para inferir nível é circular.
Ausência de um domínio é lacuna do registro, nunca lacuna de competência: em 2026-08-15, 1298 de 2949 descrições de tarefa concluída foram escritas por outra pessoa que não quem executou, e 355 tarefas tinham dois ou mais designados.

**Stakeholders.** engineering_manager, team_lead, developer

**Required concepts.** `eo.person`, `eo.team_member`, `spo.performed_project_activity`, `cmpo.source_repository`

**Candidate measures.** 

### `people.project_participation` — Who worked on this project, and when

**Question.** Who worked on this project during an interval, and through which team did each person reach it?

**Decision supported.** Know whom to ask about a past decision, and who holds context on a part of the system. Asking today's team about a choice made a year ago reaches people who were not there.

**Stakeholders.** engineering_manager, project_manager, team_lead, product_manager

**Required concepts.** `eo.person`, `eo.team`, `eo.team_membership`, `spo.project`

**Candidate measures.** 

### `review.concentration` — Concentration of code review among people

**Question.** Within a time window, is the review of an observed organisation's change requests concentrated in a few people — and are there groups of people who do not review each other?

**Decision supported.** `pt-BR` Decidir se a revisão precisa ser redistribuída **antes** que a ausência de uma ou duas pessoas pare o fluxo de integração, e onde abrir caminho de revisão entre grupos que hoje não se revisam.
**O que esta necessidade explicitamente não responde**, e onde quem decide precisa buscar em outro lugar: quem revisa bem, quem contribui mais, quem é mais produtivo, e se alguém está se omitindo. A carga de revisão depende de designação (CODEOWNERS, regra do repositório), papel, senioridade, férias e fuso — nada disso está na rede. Também não responde **quanto tempo** a revisão leva: isso é `review.time_to_first_review`, e as duas se leem lado a lado, não se combinam.
A rede é de **revisão**, e não de colaboração nem de delegação. Revisar a solicitação de alguém é um ato observado sobre um artefato; "colaborar" é julgamento sobre a relação entre pessoas, e a plataforma não o afirma.

**Stakeholders.** engineering_manager, team_lead, scrum_master

**Required concepts.** `eo.person`, `spo.project_person_stakeholder`, `qapo.artifact_evaluation`, `qapo.evaluated_artifact`, `cmpo.change_request`, `cmpo.change_request_submission`

**Candidate measures.** `review.network.reviews_given.count`, `review.network.reviews_received.count`, `review.network.unconnected_groups.count`, `review.network.concentration.top_k_share`, `review.network.reviews.count`, `review.network.reviewers.count`, `review.network.authors_reviewed.count`, `review.network.people_without_activity.count`, `review.network.excluded.count`

### `review.time_to_first_review` — `pt-BR` Tempo até a primeira revisão

**Question.** How long does a change request wait until it receives its first review?

**Decision supported.** `pt-BR` Identificar gargalos no processo de revisão de código e decidir sobre redistribuição de revisores ou limites de trabalho em progresso.

**Stakeholders.** engineering_manager, team_lead, scrum_master

**Required concepts.** `cmpo.change_request`, `qapo.artifact_evaluation`, `eo.person`

**Candidate measures.** `review.time_to_first_review.duration`

### `rework.effort_on_not_accepted_deliverables` — `pt-BR` Esforço gasto em entregáveis não aceitos

**Question.** `pt-BR` Quanto do trabalho executado em um sprint produziu entregáveis que não foram aceitos?

**Decision supported.** `pt-BR` Avaliar qualidade do trabalho e produtividade da equipe, e decidir sobre revisão dos critérios de aceitação ou da granularidade das user stories.

**Stakeholders.** product_owner, scrum_master, engineering_manager

**Required concepts.** `sro.performed_scrum_development_task`, `sro.non_successfully_performed_scrum_development_task`, `sro.not_accepted_deliverable`, `sro.sprint`, `sro.atomic_user_story`

**Candidate measures.** `rework.not_accepted_deliverable_ratio`

## Measures

### `ci.pipeline_success_rate.ratio` — `pt-BR` Taxa de sucesso do processo de integração contínua

Answers: `ci.pipeline_success_rate`

```text
(successful_ci_processes / total_ci_processes) * 100
```

Type: `percentage` · unit: `percent` · levels: repository, project, team

**Limitations**

- `pt-BR` No nível TEAM, o caminho é repositório → projeto → equipe, e NUNCA o ator da execução. `collected_verifications.actor_person_id` existe e daria uma taxa mais barata, e ela responderia outra pergunta: o ator é quem DISPAROU, não quem cuida do código. Execução agendada tem por ator quem configurou o agendamento; de push, quem empurrou. Uma equipe cujo CI roda por agendamento apareceria quase vazia (feature 058, R1).
- `pt-BR` Equipe sem projeto declarado NÃO recebe taxa. Zero diria que o pipeline falhou; a verdade é que a plataforma não sabe de quais repositórios aquela equipe cuida — e a recusa nomeia o elo que falta.
- `pt-BR` A taxa precisa vir com o NÚMERO DE EXECUÇÕES sobre o qual foi calculada. Cem por cento sobre três execuções e cem por cento sobre trezentas não são a mesma afirmação, e a cobertura do dado no nível equipe não foi medida (feature 058, R6).
- `pt-BR` Execução em andamento fica FORA do numerador e do denominador: processo que ainda não decidiu nada não é sucesso nem falha, e contá-lo como qualquer um dos dois inventaria um veredito.
- `pt-BR` Execuções canceladas e puladas não são insucesso e devem sair do denominador.
- `pt-BR` Repositórios com pipelines de propósitos distintos precisam de recorte por workflow.
- `pt-BR` Reexecução manual de um pipeline que falhou pode inflar artificialmente a taxa.

**Possible misinterpretations**

- `pt-BR` Taxa alta com poucos testes não indica qualidade; cruzar com cobertura e inspeção.

### `flow.completion.forecast` — Completion forecast by simulation, with its confidence

Answers: `flow.open_work_balance`

```text
For each of N runs: sample a weekly closed count from the observed history and subtract from remaining; under the live-scope hypothesis also sample a weekly opened count and add. Repeat until remaining <= 0 or the horizon is reached. The forecast is the distribution of run lengths, reported as the 50th, 85th and 95th percentiles, together with the proportion of runs that did not finish within the horizon.

```

Type: `duration` · unit: `weeks` · levels: team

**Limitations**

- `pt-BR` A simulação assume que o período à frente se parece com o observado — mesmas pessoas, mesmo tipo de trabalho. Uma equipe que acabou de perder alguém não tem histórico que sustente essa premissa, e a previsão continua saindo sem saber disso.
- `pt-BR` Oito semanas é histórico fino. O piso de seis períodos e dez itens fechados evita o pior caso, e não transforma histórico curto em previsão boa.
- `pt-BR` A hipótese de escopo congelado responde uma pergunta que quase nunca é a real: nada novo entrar. Ela existe para separar capacidade de entrada, e não para ser lida sozinha.
- `pt-BR` Quando a maioria das rodadas não conclui dentro do horizonte, os percentis descrevem uma MINORIA. A proporção de não conclusão é parte obrigatória do resultado, e não uma nota de rodapé.
- `pt-BR` Percentil de hipótese cujas rodadas não concluíram é NULO, nunca um número grande. Um número grande diria uma data; nulo diz desconhecido.
- `pt-BR` A amostragem trata as semanas como independentes e intercambiáveis. Férias, feriado e ciclo de release não são independentes, e a variabilidade real é maior que a simulada.
- `pt-BR` Herda todas as limitações de flow.open_work.cumulative, inclusive a de que 'fechado' é o ato da ferramenta.

**Possible misinterpretations**

- `pt-BR` Ler a faixa de 85% como uma data prometida. É a semana em que 85% das rodadas terminaram, dado o passado observado — não um compromisso, e nada nela obriga o futuro.
- `pt-BR` Assumir o p50 como previsão. Metade das rodadas passou dele; usá-lo para prometer erra metade das vezes por definição.
- `pt-BR` Concluir que a equipe precisa trabalhar mais quando a hipótese de escopo vivo não converge. Se a entrada supera a saída, nenhuma quantidade de esforço dentro das taxas atuais fecha a conta — a decisão é sobre o que entra.
- `pt-BR` Comparar a previsão de duas equipes como medida de desempenho. Elas amostram históricos diferentes, com trabalho de naturezas diferentes.
- `pt-BR` Refazer a simulação até sair um número melhor. A semente é derivada dos dados justamente para que isso não seja possível.

### `flow.open_work.cumulative` — Cumulative opened and closed, and what remains between them

Answers: `flow.open_work_balance`

```text
opened_cumulative(t) = open_at(window_start)
  + count(items WHERE created_at IN [window_start, t]);
closed_cumulative(t) = count(items WHERE closed_at IN [window_start, t]); still_open(t) = opened_cumulative(t) - closed_cumulative(t)

```

Type: `count` · unit: `work_items` · levels: team, project

**Limitations**

- `pt-BR` NÃO existe escopo comprometido. A medida não responde se um sprint termina — não há compromisso declarado contra o qual comparar, e o escopo aqui é simplesmente tudo o que foi aberto.
- `pt-BR` 'Fechado' é o ato registrado na ferramenta, e não um critério de término declarado. Item abandonado e item concluído entram iguais, e a medida não distingue os dois. O critério de fim continua sendo a lacuna da issue #506.
- `pt-BR` O acumulado PRECISA partir da contagem de itens já em aberto no início da janela. Partindo de zero, a distância entre as curvas mede apenas os itens nascidos dentro da janela: uma equipe com quarenta itens abertos há meses e nenhuma abertura recente apareceria com distância zero.
- `pt-BR` Item reaberto acrescenta uma abertura na semana em que foi reaberto e mantém o fechamento anterior na semana em que ocorreu. A mesma unidade de trabalho aparece duas vezes na série de abertas.
- `pt-BR` Trabalho que não virou item — revisão, apoio a incidente, espera por terceiro — não entra em nenhuma das duas curvas, e o saldo medido é menor que o real nas duas pontas.
- `pt-BR` A janela padrão é de oito semanas. Oito semanas é histórico curto, e uma equipe que mudou de composição no meio dela tem duas realidades numa série só.
- `pt-BR` O que resta é DERIVADO das duas séries, e não observado. Apresentá-lo com o mesmo peso visual das curvas afirmaria observação que não houve.

**Possible misinterpretations**

- `pt-BR` Ler a distância entre as curvas como atraso. Ela é trabalho em aberto, e trabalho em aberto é o estado normal de uma equipe que existe — o que informa é se ela alarga ou estreita.
- `pt-BR` Concluir que a equipe está lenta quando a faixa alarga. Alargar significa que entra mais do que sai; pode ser inteiramente entrada, com a saída inalterada.
- `pt-BR` Somar as curvas de duas equipes. A mesma pessoa pode pertencer às duas e o mesmo item aparecer nas duas — o total contaria duas vezes.
- `pt-BR` Tratar a curva de fechadas como entrega de valor. Ela conta itens fechados na ferramenta, incluindo os abandonados.
- `pt-BR` Comparar a distância entre equipes de tamanhos diferentes sem normalizar. A medida vira contagem de pessoas.

### `flow.per_person.readings` — The two readings of the per-person table — the direction of the stock, and the regularity of closing

Answers: `flow.open_work_balance`, `flow.throughput`

```text
LÊ flow.open_work.cumulative:
  change_across_window = still_open(last_sample) - still_open(first_sample);
LÊ flow.throughput.rate:
  periods_with_a_close  = count(periods WHERE closed(period) > 0)

```

Type: `count` · unit: `work_items` · levels: person

**Limitations**

- `pt-BR` A VARIAÇÃO NÃO É SALDO DE TRABALHO. É a diferença entre dois estados amostrados, e um item aberto e fechado DENTRO de um mesmo período não aparece em nenhuma das duas pontas — a variação é zero e houve movimento.
- `pt-BR` A variação pode ser negativa por efeito da JANELA, e não do fechamento: item aberto antes da janela e fechado dentro dela entra na série de fechadas e nunca entrou na de abertas. O piso apresentado é zero, e é o piso do que a coluna afirma — não uma correção da medida.
- `pt-BR` A REGULARIDADE NÃO É RITMO. Diz em quantos períodos houve ao menos um fechamento, e não quantos itens fecharam: um período com um fechamento e outro com trinta contam igual. Quem quer o volume lê a coluna de fechadas, ao lado.
- `pt-BR` Nenhuma das duas se converte em média ou taxa por pessoa, e a tela não as apresenta assim: um número único por pessoa é a figura de produtividade que a plataforma não guarda.
- `pt-BR` As duas herdam TODAS as limitações das medidas que leem — inclusive a que mais importa: 'fechado' é o ato registrado na ferramenta, e não um critério de término declarado. Item abandonado e item concluído entram iguais, e a lacuna do critério de fim continua sendo a issue #506.
- `pt-BR` Sem data de designação — a origem não a fornece —, o item é da pessoa e o período dele é o do próprio item (decisão de 2026-08-27). A variação e a regularidade descrevem os itens DA pessoa, e não o que ela fez naquele período.

**Possible misinterpretations**

- `pt-BR` Ler a variação como produtividade ou como esforço. Ela é a direção de um estoque: cresce quando entra mais do que sai, e pode crescer inteiramente por entrada, com a saída inalterada.
- `pt-BR` Ler `no change` como ausência de trabalho. Significa que se conferiu e o estoque terminou onde começou — o que é compatível com muito movimento dentro da janela.
- `pt-BR` Ordenar as pessoas por qualquer uma das duas. É a comparação que a tabela recusa: as linhas não compartilham denominador, e o maior número da tela conta trabalho que NÃO se moveu. Nenhuma coluna de medida ordena a tabela, e nenhuma se oferece para ordenar.
- `pt-BR` Somar a regularidade de duas pessoas. Duas pessoas com fechamento na mesma semana não somam duas semanas — é a mesma semana.
- `pt-BR` Ler a regularidade baixa como irregularidade da pessoa. O denominador é a janela coletada, e quem entrou no meio dela tem menos períodos possíveis — a coluna reduz o denominador e diz qual é.

### `flow.throughput.rate` — Concluded task throughput per sprint

Answers: `flow.throughput`

```text
count(performed_tasks WHERE end_date IS NOT NULL AND end_date BETWEEN sprint_start_date AND sprint_end_date)

```

Type: `count` · unit: `tasks_per_sprint` · levels: sprint, project, team, person

**Limitations**

- `pt-BR` Contar tarefa concluída ignora o tamanho da tarefa - uma de duas horas e uma de duas semanas pesam igual, e decompor mais fino eleva a vazão sem que mais trabalho tenha sido feito.
- `pt-BR` Depende de end_date registrado. Quando o fim é derivado da transição de status do item do Projects v2, a confiança é média, e tarefa fechada fora da ferramenta não entra na contagem.
- `pt-BR` Tarefa concluída cujo entregável foi recusado atravessou o fluxo e não entregou resultado. Ela conta na vazão; a separação entre tarefa bem-sucedida e malsucedida depende de a aceitação ter sido registrada contra os criterios de aceitação, e é ato do Product Owner.
- `pt-BR` Tarefa reaberta e concluída de novo conta duas vezes sobre a mesma unidade de trabalho. Este projeto exige criar nova tarefa pretendida em vez de reabrir a executada; onde a regra não for seguida na ferramenta, a vazão infla sem aviso.
- `pt-BR` Comparar sprints exige duração constante. O campo Iteration deste projeto usa 14 dias; sprint encurtado por feriado ou interrompido produz um valor menor que não é queda de vazão.
- `pt-BR` Esta limitação previa feriado, e não previa uma caixa seis vezes maior. Medido em 2026-08-26, 669 dos 2.685 vínculos de issue - 25% - apontavam para campo Quarter de 84 dias de média promovido ao mesmo sro.sprint de 13 dias, e a vazão do trimestre parecia seis vezes maior sem que mais trabalho tivesse atravessado nada. A issue #514 separou os dois pela declaração da organização; enquanto o campo não for declarado, a leitura segue tratando como sprint, e esta medida continua misturando as granularidades naquele quadro.
- `pt-BR` Trabalho que não virou tarefa - revisão de solicitação de mudança, apoio a incidente, espera por terceiro - consome capacidade e não aparece na contagem, o que faz a vazão medida ser menor que o trabalho realizado.
- `pt-BR` Tarefa que começou em um sprint e terminou no seguinte é atribuída inteira ao sprint de término, o que credita ao sprint seguinte esforço gasto no anterior.
- `pt-BR` No nível person, a mesma tarefa aparece uma vez por participante quando há mais de um responsável, e a soma dos níveis person não é igual ao nível sprint.

**Possible misinterpretations**

- `pt-BR` Vazão não é produtividade. Ela responde quanto trabalho atravessa o sistema, nunca se o trabalho valeu a pena; o valor entregue não se lê nesta medida.
- `pt-BR` Vazão alta não indica time saudável. Decompor tarefas mais fino, ou concluir apenas o que é fácil, eleva o número sem mudar o resultado.
- `pt-BR` Vazão baixa não indica time lento. Pode indicar tarefas grandes demais, bloqueio externo, ou trabalho consumido por atividade que não virou tarefa.
- `pt-BR` Usar a vazão como meta a bater a torna alvo, e alvo deixa de ser medida - o efeito conhecido é fechar tarefa no board antes de o trabalho terminar, com o retrabalho aparecendo depois.
- `pt-BR` Comparar vazão entre times sem normalizar pelo tamanho do time e pelo critério de decomposição transforma a medida em contagem de pessoas ou de granularidade.
- `pt-BR` Um sprint isolado não descreve o fluxo. Vazão só sustenta dimensionamento de escopo lida como série ao longo de vários sprints, com a dispersão à vista.
- `pt-BR` Vazão e WIP não se somam nem se substituem. Interpretadas juntas com o tempo de conclusão descrevem o fluxo; isoladas, cada uma admite explicações opostas.

### `flow.wip.count` — Work in progress count

Answers: `flow.work_in_progress`

```text
count(performed_tasks WHERE start_date <= observation_instant AND (end_date IS NULL OR end_date > observation_instant))

```

Type: `count` · unit: `tasks` · levels: sprint, project, team, person

**Limitations**

- `pt-BR` O período é semanal por decisão da pessoa mantenedora em 2026-08-26, e a medida continua sendo instantânea por definição: WIP é o que estava aberto NUM instante, e semanal diz de quanto em quanto tempo esse instante é amostrado. O painel da equipe da issue #506 lê a série, e nunca um valor solto.
- `pt-BR` Contar tarefa aberta ignora o tamanho da tarefa - uma de duas horas e uma de duas semanas pesam igual, e um time que decompõe grosso parece ter menos trabalho aberto do que tem.
- `pt-BR` Depende de start_date registrado. Quando o início é derivado da transição de status do item do Projects v2, a confiança é média, e tarefa que nunca passou por "em andamento" não aparece em nenhum instante.
- `pt-BR` Tarefa sem end_date pode estar em execução ou abandonada; a medida não distingue as duas situações e trata o abandono como trabalho ativo.
- `pt-BR` Tarefa reaberta gera um segundo intervalo aberto sobre a mesma unidade de trabalho e conta duas vezes no mesmo instante. Este projeto exige criar nova tarefa pretendida em vez de reabrir a executada; onde a regra não for seguida na ferramenta, a contagem infla sem aviso.
- `pt-BR` Trabalho que não virou tarefa - revisão de solicitação de mudança, apoio a incidente, espera por terceiro - consome capacidade e não entra na contagem, o que faz o WIP medido ser menor que o WIP real.
- `pt-BR` Um valor isolado não descreve o sprint. WIP é série temporal, e o instante escolhido determina o resultado: fim de semana, feriado e véspera de review deprimem o número por motivos que nada têm a ver com fluxo.
- `pt-BR` No nível person, o mesmo trabalho aparece uma vez por participante quando há mais de um responsável, e a soma dos níveis person não é igual ao nível sprint.
- `pt-BR` Amostrar semanalmente não elimina o efeito do dia escolhido, apenas o torna constante: se a amostra cai sempre na segunda, ela sempre mede o pior momento da semana anterior. O que a série semanal permite é comparar semana com semana, e nunca ler um ponto como o WIP do time.
- `pt-BR` A medida exige start_date E end_date, e o segundo é a lacuna que a issue #506 registrou. O critério de início veio da feature 042 e há quatro declarados; o critério de FIM não existe, e sem ele toda tarefa iniciada parece aberta para sempre. Enquanto isso não for declarado, a série semanal cresce monotonicamente e o crescimento não é acúmulo de trabalho: é ausência de fim.

**Possible misinterpretations**

- `pt-BR` WIP baixo não significa fluxo saudável; pode indicar time bloqueado, dependência externa, ou tarefas grandes demais para se manifestarem como várias.
- `pt-BR` WIP alto não é sinônimo de produtividade. Costuma ser o contrário - quanto mais itens abertos ao mesmo tempo, maior o tempo de conclusão de cada um, porque o mesmo esforço se divide.
- `pt-BR` Comparar WIP entre times sem normalizar pelo tamanho do time transforma a medida em contagem de pessoas.
- `pt-BR` WIP não é medida de esforço nem de capacidade. Somá-lo a story points, ou convertê-lo em capacidade do sprint, mistura unidades que não se somam.
- `pt-BR` Reduzir o número por decreto não melhora o fluxo; fecha tarefa no board sem que o trabalho tenha terminado, e o efeito aparece depois como retrabalho.

### `review.network.authors_reviewed.count` — People reviewed, within the reader's reach

Answers: `review.concentration`

```text
authors = |{ a em P : existe aresta p → a com p em P }| na janela W da organização O (pessoas com ao menos uma solicitação revisada por outra pessoa do recorte; D10). Se não há aresta no recorte: AUSENTE com o motivo `no_review_in_window`.

```

Type: `count` · unit: `people` · levels: observed_organization

**Limitations**

- `pt-BR` Não distingue quem não abriu solicitação de quem abriu e não teve revisão (D3 do protótipo); as duas pessoas ficam fora desta contagem.

**Possible misinterpretations**

- `pt-BR` Ler como 'pessoas cujo trabalho foi aprovado'. Revisão não é aprovação, e Pull Request não é merge.
- `pt-BR` A MEDIDA NÃO AVALIA A PESSOA. Ela descreve a forma da revisão na organização; usá-la em avaliação de desempenho é o uso que a plataforma recusa (FR-018a, R5).
- `pt-BR` Revisar muito não é qualidade nem esforço; revisar pouco não é omissão.
- `pt-BR` A revisão só é visível quando passa pela ferramenta observada: revisão em par, em chamada ou em repositório não observado não existe aqui.

### `review.network.concentration.top_k_share` — Share of reviews given by the k people who reviewed most, without saying who

Answers: `review.concentration`

```text
Seja P o conjunto de pessoas no alcance de quem consulta (para quem administra, todas as pessoas da organização observada O). Considere só as arestas revisor → autor com revisor E autor em P, na janela W (R1).
  r(p)   = soma de weight(p → a), a em P          (pares solicitação–revisor de p)
  R      = soma de r(p), p em P                    (o denominador: revisões, e não solicitações)
  s_1 >= s_2 >= ... os valores r(p) em ordem decrescente — só os VALORES
  share_k = 100 * (s_1 + ... + s_k) / R,  para k em review.network.parameters.k_values
Empate não muda o valor: share_k é a soma dos k maiores valores, e não depende de qual pessoa ocupa qual posição. A lista ordenada NÃO sai do cálculo — só os k números. Se R = 0: AUSENTE com o motivo `no_review_in_window`. Se R for menor que review.network.parameters.min_reviews (em REVISÕES, a mesma unidade do denominador; decidido em 2026-10-03): AUSENTE com o motivo `sample_below_minimum`, e a tela diz o mínimo. As contagens continuam. Se k for maior que o número de revisores em P: share_k é AUSENTE com o motivo `fewer_reviewers_than_k` (100% com dois revisores não diz nada sobre k = 3).

```

Type: `percentage` · unit: `percent` · levels: observed_organization

**Limitations**

- `pt-BR` O denominador é REVISÕES (pares solicitação–revisor), e não solicitações. Com uma revisão por solicitação as duas coincidem — é o caso do exemplo da spec, 30 de 40. Com várias revisões por solicitação, '75% das revisões' não é '75% das solicitações passaram por essa pessoa'. A segunda pergunta é de dependência, e pertence à fatia 3.
- `pt-BR` Para quem tem alcance parcial a fração é sobre outra população que a de quem administra, e as duas NÃO se comparam: a mesma organização tem uma concentração por alcance.
- `pt-BR` Não diz se a concentração é desejada. Uma equipe com um revisor designado por regra terá share_1 alto por desenho.
- `pt-BR` Abaixo da amostra mínima a medida é ausente, e não 'baixa' nem 'alta': com poucas revisões, uma a mais muda a fração em dez pontos ou mais (ver review.network.parameters.min_reviews).
- `pt-BR` Herda as limitações de review.network.reviews_given.count: solicitação revisada não é esforço, só o que passa pela ferramenta observada existe, e revisão descartada conta.
- `pt-BR` Revisões excluídas (auto-revisão, bot/app, sem pessoa ligada) não estão no numerador nem no denominador. A contagem delas é da leitura, e para quem tem alcance parcial não é mostrada (R2).

**Possible misinterpretations**

- `pt-BR` A MEDIDA NÃO AVALIA A PESSOA. 'A pessoa que mais revisou fez 75%' descreve a organização, e não elogia nem acusa ninguém.
- `pt-BR` Tentar descobrir quem é a primeira posição cruzando com a lista por pessoa e chamar isso de leitura da medida. A lista não é ordenada por medida justamente para que isso não seja o caminho natural (FR-018a); quem faz o cruzamento está produzindo o ranking que a plataforma recusa.
- `pt-BR` Revisar muito não é qualidade nem esforço; revisar pouco não é omissão.
- `pt-BR` Ler share_1 alto como gargalo confirmado. Gargalo é espera: a medida que a mede é review.time_to_first_review.duration, e as duas se leem lado a lado.
- `pt-BR` Comparar a concentração de duas organizações, ou de duas contas com alcances diferentes, como se fosse a mesma escala. Número de revisores e designação diferem.
- `pt-BR` Ler a ausência por amostra mínima como 'sem concentração'. É 'não se pode falar em concentração com esta amostra'.

### `review.network.excluded.count` — Reviews left out of the network, by reason

Answers: `review.concentration`

```text
Para cada motivo m em review.network.edge.exclusions.order (bot_or_app, unlinked_person, self_review):
  excluded(m) = número de pares (conta revisora, solicitação) da janela W, na organização O,
                cujo primeiro motivo aplicável é m.
Invariante: soma dos pesos das arestas + excluded(bot_or_app) + excluded(unlinked_person) + excluded(self_review) = pares contáveis da janela (estado em review.network.edge.counted_states, enviados em W), com os pares de aresta deduplicados por pessoa: duas contas ligadas à mesma pessoa sobre a mesma solicitação são um par (review.network.edge, `unit`).

```

Type: `count` · unit: `reviews` · levels: observed_organization

**Limitations**

- `pt-BR` A conta apagada na origem entra em 'sem pessoa ligada', e não em bot (decidido em 2026-10-03); a coleta foi alinhada na T030 da 073.
- `pt-BR` Contas apagadas sobre a mesma solicitação são indistinguíveis entre si e contam UM par: o número de 'sem pessoa ligada' pode ficar abaixo do número de revisões de contas apagadas na origem.
- `pt-BR` Autor ligado a uma pessoa depois da coleta continua 'sem pessoa ligada' até a solicitação ser coletada de novo.

**Possible misinterpretations**

- `pt-BR` Ler 'sem pessoa ligada' como bot. É pessoa que a plataforma não reconheceu, muitas vezes real.
- `pt-BR` Ler a auto-revisão como falta. Ela é contada no agregado, nunca por pessoa, e pode ser regra do repositório.
- `pt-BR` A MEDIDA NÃO AVALIA A PESSOA. Ela descreve a forma da revisão na organização; usá-la em avaliação de desempenho é o uso que a plataforma recusa (FR-018a, R5).
- `pt-BR` Revisar muito não é qualidade nem esforço; revisar pouco não é omissão.
- `pt-BR` A revisão só é visível quando passa pela ferramenta observada: revisão em par, em chamada ou em repositório não observado não existe aqui.

### `review.network.people_without_activity.count` — People with no review activity in the window

Answers: `review.concentration`

```text
without_activity = |{ q pessoa (account_type = person) da organização O, alcançada por quem consulta : q não revisou nem teve solicitação revisada na janela W, e não abriu solicitação na janela }|. Pessoa da organização é a que EO liga a ela pela evidência de vínculo com uma equipe da organização.

```

Type: `count` · unit: `people` · levels: observed_organization

**Limitations**

- `pt-BR` Pessoa da organização é quem EO liga a ela por equipe observada; quem revisa nos repositórios da organização sem estar numa equipe dela entra na rede mas não nesta contagem.
- `pt-BR` 'Sem atividade' é sem atividade QUE VIROU ARESTA: quem só revisou solicitações de bot ou de conta sem pessoa ligada revisou de fato, e entra nesta contagem. O total dessas revisões está em review.network.excluded.count, por motivo.

**Possible misinterpretations**

- `pt-BR` Ler como 'pessoas inativas'. Elas podem trabalhar em repositório não observado, estar de férias, ou não ter papel de revisão.
- `pt-BR` A MEDIDA NÃO AVALIA A PESSOA. Ela descreve a forma da revisão na organização; usá-la em avaliação de desempenho é o uso que a plataforma recusa (FR-018a, R5).
- `pt-BR` Revisar muito não é qualidade nem esforço; revisar pouco não é omissão.
- `pt-BR` A revisão só é visível quando passa pela ferramenta observada: revisão em par, em chamada ou em repositório não observado não existe aqui.

### `review.network.reviewers.count` — People who reviewed, within the reader's reach

Answers: `review.concentration`

```text
reviewers = |{ p em P : existe aresta p → a com a em P }| na janela W da organização O. Se não há aresta no recorte: AUSENTE com o motivo `no_review_in_window`.

```

Type: `count` · unit: `people` · levels: observed_organization

**Limitations**

- `pt-BR` Conta pessoas com ao menos uma revisão contável; quem só revisou as próprias solicitações (auto-revisão) não entra.

**Possible misinterpretations**

- `pt-BR` Ler um número baixo como 'poucos revisam': quem revisa fora da ferramenta observada não aparece.
- `pt-BR` A MEDIDA NÃO AVALIA A PESSOA. Ela descreve a forma da revisão na organização; usá-la em avaliação de desempenho é o uso que a plataforma recusa (FR-018a, R5).
- `pt-BR` Revisar muito não é qualidade nem esforço; revisar pouco não é omissão.
- `pt-BR` A revisão só é visível quando passa pela ferramenta observada: revisão em par, em chamada ou em repositório não observado não existe aqui.

### `review.network.reviews.count` — Reviews in the network, within the reader's reach

Answers: `review.concentration`

```text
R = soma de weight(p → a) sobre as arestas com p e a no alcance P de quem consulta, na janela W da organização observada O. Uma revisão é um par (revisor, solicitação): uma solicitação com dois revisores conta duas revisões. Se não há aresta no recorte: AUSENTE com o motivo `no_review_in_window`, nunca 0.

```

Type: `count` · unit: `reviews` · levels: observed_organization

**Limitations**

- `pt-BR` É o denominador da concentração, e não o número de solicitações revisadas: as duas contagens divergem quando uma solicitação tem mais de um revisor.
- `pt-BR` Para alcance parcial é o total entre pessoas alcançadas, e não o da organização; a tela não diz quantas ficaram fora (R2).

**Possible misinterpretations**

- `pt-BR` Ler como 'quantas solicitações foram revisadas'. É quantos pares revisor–solicitação houve.
- `pt-BR` Comparar o total de duas contas com alcances diferentes: são populações diferentes.
- `pt-BR` A MEDIDA NÃO AVALIA A PESSOA. Ela descreve a forma da revisão na organização; usá-la em avaliação de desempenho é o uso que a plataforma recusa (FR-018a, R5).
- `pt-BR` Revisar muito não é qualidade nem esforço; revisar pouco não é omissão.
- `pt-BR` A revisão só é visível quando passa pela ferramenta observada: revisão em par, em chamada ou em repositório não observado não existe aqui.

### `review.network.reviews_given.count` — Reviews a person gave, and of how many distinct people

Answers: `review.concentration`

```text
Sobre as arestas da leitura (organização observada O, janela W), regidas por review.network.edge:
  reviews_given(p)  = soma de weight(p → a) para todo autor a      [revisões]
                    = |{ solicitação c : existe revisão de p sobre c, enviada em W }|
  reviewed_people(p) = |{ a : weight(p → a) > 0 }|                  [pessoas]
weight(p → a) = número de solicitações DISTINTAS de a que p revisou em W. Se não existe aresta saindo de p: as duas são AUSENTES com o motivo `did_not_review_in_window`, nunca 0.

```

Type: `count` · unit: `reviews` · levels: person

**Limitations**

- `pt-BR` Conta SOLICITAÇÕES revisadas, e não eventos de revisão nem esforço. Uma aprovação sem comentário e três rodadas de revisão longa sobre a mesma solicitação contam igual: um. É deliberado — rodadas inflariam quem comenta muito em poucas solicitações —, e é por isso mesmo que o número não diz nada sobre o trabalho que a revisão deu.
- `pt-BR` Só existe o que passou pela ferramenta observada. Revisão em par, em chamada, ou em repositório que a organização não coleta não aparece — e quem trabalha sobretudo ali aparece como quem não revisa.
- `pt-BR` Revisão descartada depois de enviada (DISMISSED) CONTA: o ato de revisar aconteceu, e o descarte é decisão posterior sobre ela, frequentemente de outra pessoa ou de uma regra do repositório.
- `pt-BR` Comentário (COMMENTED) conta como revisão. A posição da revisão (endosso, objeção, abstenção, ver `qapo.evaluation_verdict`) NÃO entra nesta medida, e a rede não distingue quem aprova de quem pede mudança.
- `pt-BR` A carga de revisão depende de designação (CODEOWNERS, revisor obrigatório, regra do repositório), papel, senioridade, férias e fuso. Nenhum desses fatores está na rede, e todos movem o número.
- `pt-BR` Pessoa sem revisão na janela tem a medida AUSENTE com motivo, e não zero. Ausência aqui é fato da origem sobre a janela — e não omissão da pessoa.
- `pt-BR` O autor da solicitação é resolvido na coleta. Solicitação cujo autor só foi ligado a uma pessoa depois de integrada fica como 'sem pessoa ligada' até ser coletada de novo (seguranca.md, 'O que eu NÃO verifiquei'). O total de exclusões por esse motivo está na leitura.

**Possible misinterpretations**

- `pt-BR` A MEDIDA NÃO AVALIA A PESSOA. Ela descreve a forma da revisão na organização; usá-la em avaliação de desempenho é o uso que a plataforma recusa, e a tela diz isso ao lado da lista (FR-018a, R5).
- `pt-BR` Revisar muito não é qualidade nem esforço. O número não distingue revisão cuidadosa de aprovação automática feita por gente.
- `pt-BR` Revisar pouco não é omissão. A pessoa pode não ser designada, estar em outro repositório, de férias, ou revisar fora da ferramenta.
- `pt-BR` Ordenar as pessoas por esta medida. As linhas não compartilham denominador — designação e repositório diferem — e o primeiro colocado de uma lista ordenada é um rótulo de 'hub' com outro nome. Nenhuma coluna de medida ordena a lista, e nenhuma se oferece para ordenar.
- `pt-BR` Ler 'de 4 pessoas' como alcance social ou influência. É quantas pessoas distintas abriram as solicitações que ela revisou na janela — nada sobre importância.
- `pt-BR` Somar as linhas e chamar de número de solicitações revisadas. Uma solicitação revisada por duas pessoas aparece nas duas linhas: a soma das linhas é o total de REVISÕES (review.network.reviews.count, para quem alcança todos), e o de solicitações revisadas é outra contagem. Para alcance parcial a soma das linhas visíveis não é nem uma nem outra, porque cada linha traz o total verdadeiro da pessoa, inclusive pares fora do recorte.

### `review.network.reviews_received.count` — A person's change requests that were reviewed, and by how many distinct people

Answers: `review.concentration`

```text
Sobre as arestas da leitura (organização observada O, janela W):
  reviewed_change_requests(a) = |{ solicitação c de a : existe revisão de outra
                                   pessoa sobre c, enviada em W }|   [solicitações]
  reviewers(a) = |{ p : weight(p → a) > 0 }|                         [pessoas]
Se a abriu solicitação e nenhuma foi revisada em W: as duas são AUSENTES com o motivo `no_change_request_reviewed_in_window`, nunca 0. NÃO é a soma de weight(p → a): uma solicitação revisada por três pessoas conta UMA vez aqui e três vezes na soma dos pesos.

```

Type: `count` · unit: `change_requests` · levels: person

**Limitations**

- `pt-BR` Mede revisão RECEBIDA, e não integração. Solicitação revisada não é solicitação integrada: Pull Request não é merge, e quem integrou é outra relação (`cmpo.stakeholder_performed_checkin`).
- `pt-BR` Solicitação aberta e não revisada na janela não está aqui — está na ausência com motivo. A medida não diz quantas solicitações a pessoa abriu; abrir e ser revisado são duas perguntas.
- `pt-BR` Só existe o que passou pela ferramenta observada; revisão fora dela não existe para a plataforma.
- `pt-BR` Revisão descartada (DISMISSED) conta: a solicitação foi revisada, ainda que a revisão tenha sido retirada depois.
- `pt-BR` Revisão de bot ou aplicativo não conta. Uma solicitação revisada só por robô aparece como não revisada — o que é correto para a pergunta (ninguém a leu), e precisa ser dito, porque a página da solicitação na origem mostra uma revisão.
- `pt-BR` Revisão de conta sem pessoa ligada também não conta: a solicitação revisada só por uma conta que a plataforma não reconheceu aparece como não revisada, ainda que uma pessoa real a tenha lido. A contagem dessas revisões está em review.network.excluded.count.

**Possible misinterpretations**

- `pt-BR` A MEDIDA NÃO AVALIA A PESSOA — nem quem abriu, nem quem revisou.
- `pt-BR` Ser revisado por poucas pessoas não diz nada sobre a qualidade do trabalho de quem abriu. Pode ser o único revisor designado do repositório.
- `pt-BR` Ter poucas solicitações revisadas não é sinal de pouco trabalho: a pessoa pode abrir poucas solicitações grandes, integrar sem revisão por regra do repositório, ou trabalhar fora da ferramenta.
- `pt-BR` Ordenar as pessoas por esta medida. Mesma recusa de review.network.reviews_given.count: as linhas não compartilham denominador, e nenhuma coluna de medida ordena a lista.
- `pt-BR` Ler a ausência ('nenhuma solicitação revisada na janela') como descaso de quem deveria revisar. A ausência é da janela e da origem; designação e disponibilidade não estão na rede.

### `review.network.unconnected_groups.count` — Groups of people who do not review each other, and the size of each

Answers: `review.concentration`

```text
Seja P o conjunto de pessoas no alcance de quem consulta (para quem administra, todas as pessoas da organização observada O). Seja G o grafo dirigido da leitura (O, janela W) RECORTADO por P, como a concentração (decidido em 2026-10-03, Q4): nós = pessoas de P com AO MENOS UMA aresta para outra pessoa de P, e arestas = revisor → autor com weight > 0, as duas pontas em P. Ignora-se a direção (componentes FRACAMENTE conexos):
  groups      = número de componentes fracamente conexos de G     [grupos]
  size(g)     = número de pessoas no componente g                 [pessoas]
Pessoa sem aresta NÃO é nó, e por isso não é grupo de tamanho 1 (R2 item 4). Todo componente tem ao menos 2 pessoas. Se G não tem aresta: AUSENTE com o motivo `no_review_in_window`, nunca 0. Quem está fora do alcance não entra em grupo nenhum, e por isso nenhum tamanho fala de quem quem consulta não alcança. O mínimo de grupo (review.network.parameters.min_group_size_shown) não tem caso nesta fatia.

```

Type: `count` · unit: `groups` · levels: observed_organization

**Limitations**

- `pt-BR` Componente FRACO, e não forte: A revisou B e B nunca revisou A já os põe no mesmo grupo. A pergunta é 'há caminho de revisão entre os dois grupos, em qualquer sentido?', e não 'há reciprocidade?'.
- `pt-BR` A janela decide o grupo. Dois grupos separados em 30 dias podem estar ligados em 90; a leitura vale para a janela que declara, e a tela a escreve ao lado.
- `pt-BR` Grupo não é equipe e não é comunidade. É só o conjunto de pessoas ligadas por revisão na janela; comparar com as equipes declaradas é a fatia 2, e não esta medida (FR-019).
- `pt-BR` Para quem tem alcance parcial, dois colegas podem aparecer em grupos separados só porque a pessoa que os liga está fora do alcance. O grupo é da rede que quem consulta alcança, e não da organização.
- `pt-BR` Pessoas sem aresta na janela não estão em grupo nenhum. A contagem delas, quando aparece, é sobre as pessoas alcançáveis por quem consulta (R2 item 5).

**Possible misinterpretations**

- `pt-BR` Ler grupo isolado como silo, ou como problema. Pode ser um produto separado de propósito, um repositório com equipe própria, ou um projeto que acabou.
- `pt-BR` Ler um grupo só como 'todos se revisam'. Um grupo de 14 pode ser uma estrela: uma pessoa revisando 13 que não se revisam entre si. A concentração diz isso; o número de grupos, não.
- `pt-BR` A medida não avalia nenhuma pessoa, e estar num grupo pequeno não é isolamento da pessoa.
- `pt-BR` Comparar o número de grupos entre janelas de tamanhos diferentes como tendência. Janela maior junta mais arestas e tende a ter menos grupos sem que nada tenha mudado.

### `review.time_to_first_review.duration` — `pt-BR` Duração até a primeira revisão

Answers: `review.time_to_first_review`

```text
first_review_submitted_at - change_request_opened_at
```

Type: `duration` · unit: `seconds` · levels: change_request, repository, project, team

**Limitations**

- `pt-BR` No nível TEAM, a solicitação conta para a equipe quando quem a ABRIU pertencia a ela na data de abertura — e não na data da consulta, nem pela equipe de quem revisou. Recortar pela revisão mediria a equipe de quem revisa, e esta é uma espera de quem abriu (feature 058, R3).
- `pt-BR` Solicitação ainda sem revisão humana NÃO tem tempo: tem espera em curso. Omiti-la faria a mediana melhorar quanto pior a equipe estivesse, porque as que mais interessam são justamente as que ninguém revisou (feature 058, R5).
- `pt-BR` A mediana por pessoa e a da equipe respondem perguntas diferentes e não devem ser reconciliadas. Cada solicitação tem um autor, então não há dupla contagem — mas os dois números medem coisas distintas.
- `pt-BR` Solicitação aberta por quem nunca teve vínculo declarado não conta para equipe nenhuma. Ela é nomeada no que ficou de fora, e não some.
- `pt-BR` Revisões automáticas devem ser excluídas ou classificadas separadamente.
- `pt-BR` Solicitações de mudança sem revisão não possuem valor concluído e não entram na média.
- `pt-BR` Solicitações abertas como rascunho distorcem o início da espera.

**Possible misinterpretations**

- `pt-BR` Um valor baixo pode indicar revisão superficial, não agilidade.
- `pt-BR` A média esconde a cauda; usar percentis para decisão sobre gargalo.

### `rework.not_accepted_deliverable_ratio` — `pt-BR` Proporção de tarefas que produziram entregáveis não aceitos

Answers: `rework.effort_on_not_accepted_deliverables`

```text
non_successfully_performed_tasks / performed_tasks
```

Type: `ratio` · unit: `proportion` · levels: sprint, project, team

**Limitations**

- `pt-BR` Depende de que a aceitação dos entregáveis tenha sido registrada contra critérios de aceitação.
- `pt-BR` As aproximações declaradas em `proxies` NÃO substituem a medida. Elas respondem "o que não passou pela ferramenta", enquanto a medida responde "o que foi avaliado e recusado" - e um entregável pode ser recusado na review de sprint sem que solicitação alguma tenha sido fechada nem verificação alguma ter quebrado.
- `pt-BR` O denominador da aproximação por verificação é incompleto e o buraco é grande: 2.024 das solicitações integradas - 41% - não têm estado de verificação registrado. Calcular a razão sobre as que têm excluiria essas em silêncio, e o denominador mentiria para baixo. A parcela sem verificação MUST ser reportada ao lado do número, nunca descontada dele.
- `pt-BR` Solicitação fechada sem integrar mistura recusa com desistência. O estado de revisão que separaria as duas - mudanças solicitadas contra aprovada - não é coletado hoje, e enquanto não for, o número é teto e não medida.
- `pt-BR` Tarefas sem entregável associado ficam fora do numerador e do denominador.
- `pt-BR` Uma tarefa que produziu vários entregáveis conta uma vez, mesmo com apenas um não aceito.

**Possible misinterpretations**

- `pt-BR` Retrabalho não é sinônimo de baixa produtividade; pode indicar critérios de aceitação mal definidos.
- `pt-BR` Comparar equipes por esta medida sem normalizar complexidade das user stories induz conclusão errada.

