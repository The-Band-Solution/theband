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

