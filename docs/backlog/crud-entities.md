# Backlog de CRUD das entidades

Derivado de `priv/knowledge_base/` — 12 ontologias, 219 conceitos, 141 relações.

Este documento responde: **quais entidades precisam ser criadas, em que ordem, e o que
"pronto" significa para cada uma.**

---

## 1. A regra de derivação

219 conceitos **não** viram 219 tabelas. A categoria UFO de cada conceito determina como
ele se materializa — e boa parte dos conceitos não é entidade persistida.

| Categoria UFO | Qtd. | Materialização | Vira CRUD? |
|---|---:|---|---|
| `agent`, `social_agent` | 4 | tabela própria | ✅ |
| `object`, `social_object` | 41 | tabela própria (hierarquia por discriminador) | ✅ |
| `collective` | 8 | tabela própria | ✅ |
| `relator` | 5 | tabela própria — é o vínculo com identidade e temporalidade | ✅ |
| `goal` | 6 | tabela própria | ✅ |
| `normative_description` | 2 | tabela própria | ✅ |
| `disposition` | 14 | tabela própria (instâncias de ferramenta, ambientes, defeitos) | ✅ |
| `event` | 3 | tabela própria — **imutável**: create e read, sem update | ✅ parcial |
| `complex_action`, `action` | 64 | processos/atividades executadas, agrupados por agregado + `type` | ✅ agrupado |
| `intention` | 6 | processos/atividades planejadas | ✅ |
| `social_role` | 7 | catálogo de papéis (seed), não formulário | ✅ trivial |
| **`role`** | **39** | **coluna + FK numa relação, ou tabela de participação** | ❌ |
| **`phase`** | **16** | **coluna de estado na tabela do conceito pai** | ❌ |
| **`situation`** | **3** | **derivada dos timestamps do evento** | ❌ |
| `kind` (UFO) | 12 | metamodelo — vive só na base de conhecimento | ❌ |

### Por que papel não vira tabela

`sro.developer` é um **papel**, não um tipo de pessoa. Uma tabela `sro_developers`
implicaria que ser desenvolvedor é propriedade intrínseca de alguém — e a pessoa
deixaria de ser desenvolvedora ao trocar de time, virando um `DELETE`. O histórico
morreria.

A materialização correta é `eo_team_memberships`: pessoa + papel + equipe + período.
A mesma pessoa é Scrum Master em um time e Developer em outro, e a alocação passada
continua consultável. Vale para os 39 papéis: `code_under_integration`,
`evaluated_artifact`, `source_branch`, `delivered_code` — todos são o mesmo conceito
base em um contexto, e o contexto é a relação.

### Por que fase não vira tabela

`sro.accepted_deliverable` e `sro.not_accepted_deliverable` são **fases** do mesmo
entregável. Duas tabelas exigiriam mover a linha de uma para outra quando a avaliação
muda — perdendo id, histórico e referências. A materialização é
`sro_deliverables.acceptance_status`. Idem para `successful/unsuccessful` em CI, build,
teste, inspeção e deployment: coluna `outcome`.

### Por que situação não vira tabela

`osdef.vulnerable_state` e `osdef.failure_state` são a realidade antes e depois da
falha. São derivadas do evento (`osdef_failures.occurred_at`), não registros
independentes. Persistir as duas duplicaria informação e criaria três lugares para
discordarem entre si.

**Resultado: ~78 entidades com CRUD**, e não 219.

---

## 2. Nem todo CRUD tem formulário

Distinção que muda o tamanho do trabalho: a **maioria das entidades é populada por
ingestão**, não digitada por gente. Construir tela de cadastro para elas é trabalho
jogado fora — e pior, abre caminho para dado sem proveniência entrar no sistema.

Três níveis de entrega, marcados em cada linha do backlog:

| Nível | O que inclui | Para quê |
|---|---|---|
| **D** — Domínio | schema Ecto, migração, API pública (`commands`/`queries`), changesets, constraints de banco, testes conceituais | toda entidade |
| **A** — Acesso | queries de leitura, filtros, paginação, exposição em API/LiveView de consulta | entidades consultadas |
| **F** — Formulário | criação e edição manual pela interface | **só cadastros** |

Entidades ingeridas expõem `upsert_from_source/2` idempotente em vez de `create/1` e
`update/2` manuais. Escrita manual sobre elas é vetada por construção: dado externo
entra por mapeamento, com proveniência, nunca por formulário.

Entidades com nível **F**: tenants, contas de usuário, fontes externas, papéis
organizacionais, critérios de qualidade, necessidades de informação. São ~8 de ~78.

---

## 3. Definição de pronto de um CRUD

Um CRUD só está pronto quando **todos** os itens valem:

- [ ] migração com `tenant_id`, `internal_id`, `record_version`, timestamps;
- [ ] para entidade ingerida: `source_system`, `source_instance`, `external_id`,
      `collected_at` e `unique_index [tenant_id, source_system, source_instance, external_id]`;
- [ ] constraints no banco (FK, `unique_index`, `check_constraint`) **e** validação no changeset;
- [ ] API pública no módulo raiz da ontologia via `defdelegate` — schema não vaza;
- [ ] `@spec` em toda função pública; retorno `{:ok, _} | {:error, _}`;
- [ ] teste conceitual verificando cardinalidades e restrições declaradas no YAML;
- [ ] teste de isolamento entre tenants (dois tenants, um não lê o outro);
- [ ] para entidade ingerida: teste de idempotência (executar duas vezes = mesmo estado);
- [ ] YAML da base de conhecimento e schema Ecto verificados como coerentes por teste;
- [ ] documentação regenerada quando a base mudar.

---

## 4. Fundação — pré-requisito de tudo

Sem estas entidades, nenhuma outra pode existir: toda tabela de domínio referencia
tenant e proveniência.

| # | Entidade | Tabela | Nível | Depende de | Notas |
|---|---|---|---|---|---|
| F1 | Tenant | `tenants` | D A F | — | raiz do isolamento multitenant |
| F2 | Conta de usuário | `accounts_users` | D A F | F1 | acesso à plataforma, não é `eo.person` |
| F3 | Fonte externa | `sources` | D A F | F1 | instância de ferramenta: URL, tipo, credencial por referência |
| F4 | Credencial de fonte | `source_credentials` | D F | F3 | **só referência a secret manager; nunca o segredo** |
| F5 | Entidade bruta | `raw_entities` | D A | F3 | payload original preservado, imutável |
| F6 | Registro de proveniência | `provenance_records` | D A | F5 | `source_system`, `source_instance`, `external_id`, `collected_at`, `mapping_id` |
| F7 | Execução de sincronização | `sync_runs` | D A | F3 | checkpoint, cursor, contagens, status |

**7 entidades.** Feature `001 Fundação Phoenix e governança` + `024 Cadastro de fontes externas`.

> `accounts_users` e `eo.person` são coisas diferentes. Um usuário da plataforma pode não
> ser nenhuma pessoa observada nos projetos, e a maioria das pessoas observadas nunca
> terá conta. Colapsar os dois é erro que só aparece meses depois, quando alguém tentar
> deletar um usuário e levar junto o histórico de commits de um ex-funcionário.

---

## 5. EO — organizações, pessoas, equipes

Feature `005`. Depende da fundação.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Notas |
|---|---|---|---|---|---|
| EO1 | Organização | `eo_organizations` | `organization`, `organizational_unit` | D A | auto-FK `parent_id` cobre unidade organizacional |
| EO2 | Pessoa | `eo_people` | `person` | D A | ingerida; reconciliação de identidade é regra explícita, nunca heurística de nome |
| EO3 | Papel organizacional | `eo_organizational_roles` | `organizational_role` + 7 `social_role` de SRO | D A F | catálogo com seed; papéis Scrum entram como seeds daqui |
| EO4 | Equipe | `eo_teams` | `team`, `organizational_team`, `project_team` | D A | discriminador `team_type` |
| EO5 | Alocação em equipe | `eo_team_memberships` | `team_membership` + 3 memberships de SRO | D A | **relator**: pessoa + papel + equipe + `started_at`/`ended_at` |

**5 entidades.** `eo.team_member` não tem tabela — é EO2 + EO5.

**Ordem:** EO1 → EO2, EO3 → EO4 → EO5.

---

## 6. SPO — projetos, processos, atividades

Feature `006`. É a espinha dorsal: quase toda ontologia de domínio especializa algo daqui.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Notas |
|---|---|---|---|---|---|
| SPO1 | Projeto | `spo_projects` | `project`, `software_project` | D A | discriminador `project_type` |
| SPO2 | Stakeholder de projeto | `spo_project_stakeholders` | 3 `role` | D A | papel materializado: projeto + (pessoa\|equipe) + tipo |
| SPO3 | Processo pretendido | `spo_intended_processes` | 3 `intention` | D A | `scope` = general \| specific |
| SPO4 | Atividade pretendida | `spo_intended_activities` | `intended_project_activity` | D A | FK para SPO3 |
| SPO5 | Processo executado | `spo_performed_processes` | 5 `complex_action` | D A | `scope` + `composition` (simple\|composite); auto-FK `parent_id` |
| SPO6 | Atividade executada | `spo_performed_activities` | 3 conceitos | D A | `activity_kind` (simple\|composite); auto-FK; **tabela mais movimentada do sistema** |
| SPO7 | Dependência entre atividades | `spo_activity_dependencies` | relação `depends on` | D A | ordena a execução; grafo, exige guarda contra ciclo |
| SPO8 | Participação | `spo_participations` | relações `is in charge of`, `participates in` | D A | `participation_type` distingue responsável de participante |
| SPO9 | Artefato | `spo_artifacts` | `artifact`, `information_item`, `document` | D A | `artifact_type`; raiz da hierarquia de artefatos |
| SPO10 | Uso de artefato | `spo_artifact_usages` | `creates`, `uses`, `changes` | D A | `usage_type` |
| SPO11 | Uso de recurso | `spo_resource_usages` | `resource` + roles de recurso de 4 ontologias | D A | atividade + artefato no papel de recurso + `resource_kind` |

**11 entidades.**

> **Causação planejado → executado.** A relação `spo.intended_causes_performed` liga
> SPO4 a SPO6. É ela que sustenta toda análise de aderência entre plano e execução —
> e é a primeira coisa que se perde quando alguém decide que "tarefa é tarefa".
> Modelar como FK anulável em SPO6, não como tabela de junção: uma atividade executada
> tem no máximo uma intenção que a causou.

**Ordem:** SPO1 → SPO2, SPO3 → SPO4 → SPO5 → SPO6 → SPO7, SPO8, SPO9 → SPO10, SPO11.

---

## 7. SysSwO — sistema e software

Feature `007`.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Notas |
|---|---|---|---|---|---|
| SYS1 | Produto de software | `sysswo_software_products` | `software_product` | D A | |
| SYS2 | Item de software | `sysswo_software_items` | `software_item`, `code`, `program`, `software_system` | D A | `item_type`; auto-FK para composição |
| SYS3 | Especificação de programa | `sysswo_program_specifications` | `program_specification` | D A | ancora a identidade do programa |
| SYS4 | Cópia carregada | `sysswo_loaded_copies` | `loaded_software_system_copy` | D A | **base de repositórios, servidores e ambientes de CI/CD** |
| SYS5 | Equipamento de hardware | `sysswo_hardware_equipments` | `hardware_equipment`, `machine` | D A | `equipment_type` |

**5 entidades.**

> `code` e `program` ficam na mesma tabela com discriminador, mas a relação
> `constituted by` entre eles é explícita: trocar o código não troca o programa. Fundir
> os dois em uma linha só apagaria essa distinção — e com ela a capacidade de dizer que
> o mesmo programa mudou de implementação.

---

## 8. RSRO — requisitos

Feature `008`.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Notas |
|---|---|---|---|---|---|
| RS1 | Requisito | `rsro_requirements` | `requirement`, `functional`, `non_functional` | D A | `requirement_type` |
| RS2 | Artefato de requisitos | `rsro_requirement_artifacts` | `requirements_artifact` | D A | especializa SPO9 |
| RS3 | Documento de requisitos | `rsro_requirement_documents` | `requirements_document` | D A | especializa SPO9 |
| RS4 | Descrição de requisito | `rsro_requirement_descriptions` | relação `describes` | D A | junção artefato × requisito |

**4 entidades.** RS4 existe porque o artefato **descreve** o requisito sem ser ele.

---

## 9. CMPO — gerência de configuração

Feature `009`. Aqui entra o grosso dos dados do GitHub.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Notas |
|---|---|---|---|---|---|
| CM1 | Repositório | `cmpo_source_repositories` | `source_repository` | D A | especializa SYS4 |
| CM2 | Branch | `cmpo_branches` | `branch` | D A | `collective` de artefatos |
| CM3 | Item de configuração | `cmpo_configuration_items` | `configuration_item` | D A | papel de artefato sob versionamento |
| CM4 | Cópia de artefato | `cmpo_artifact_copies` | `artifact_copy` + 2 `phase` | D A | `conflict_status` = with \| without |
| CM5 | Solicitação de mudança | `cmpo_change_requests` | `change_request` | D A | **Pull Request entra aqui — e não é o merge** |
| CM6 | Commit | `cmpo_commits` | `commit_artifact_copy` | D A | atividade com atributos e volume próprios; FK para SPO6 |
| CM7 | Conflito | `cmpo_conflicts` | `conflict` | D A | |
| CM8 | Linha de base | `cmpo_baselines` | `baseline` | D A | |
| CM9 | Atividades de CM | *(usa SPO6)* | 11 `action`/`complex_action` | D | `activity_type` em SPO6: checkout, checkin, branch_creation, branch_switch, artifact_checkout, check_conflict, resolve_conflict, delete_branch, change_control, change_accomplishment, change_request_closing, baseline_establishment |

**8 entidades + reuso de SPO6.**

> CM9 é a decisão de design que evita 12 tabelas quase vazias. Só `commit` ganha tabela
> própria (CM6), porque tem atributos específicos e volume alto. As demais atividades são
> linhas em `spo_performed_activities` com `activity_type` — mesma semântica, um décimo
> do esquema.

> Branch de origem e destino são **papéis**, não tabelas: viram colunas
> `source_branch_id` / `target_branch_id` em CM5 e nas atividades de check-in.

---

## 10. ROoST — testes

Feature `010`.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Notas |
|---|---|---|---|---|---|
| RO1 | Caso de teste | `roost_test_cases` | `test_case` | D A | documento, especializa SPO9 |
| RO2 | Código de teste | `roost_test_codes` | `test_code` | D A | especializa SYS2 |
| RO3 | Execução de teste | `roost_test_executions` | `performed_test_execution` | D A | FK para SPO6 |
| RO4 | Resultado de teste | `roost_test_results` | `test_result` | D A | |
| RO5 | Ambiente de teste | `roost_testing_environments` | `testing_environment` | D A | |
| RO6 | Teste por nível | *(usa SPO6)* | `level_based_testing`, unit, integration, system | D | `testing_level` em SPO6 |

**5 entidades + reuso de SPO6.** `code_to_be_tested` é papel → coluna em RO1/RO3.

---

## 11. QAPO — garantia da qualidade

Feature `011`.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Notas |
|---|---|---|---|---|---|
| QA1 | Critério de qualidade | `qapo_quality_criteria` | `quality_criterion` | D A F | catálogo — cadastrado, não ingerido |
| QA2 | Avaliação | `qapo_evaluations` | `adherence_evaluation`, `artifact_evaluation` | D A | `evaluation_type`; review de PR entra aqui |
| QA3 | Não conformidade | `qapo_noncompliances` | `noncompliance_register` | D A | **issue do Sonar entra aqui, não em OSDEF** |
| QA4 | Relatório de avaliação | `qapo_evaluation_reports` | `evaluation_report` | D A | |

**4 entidades.** `evaluated_artifact` é papel → FK em QA2.

---

## 12. OSDEF — defeitos e falhas

Feature `012`.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Notas |
|---|---|---|---|---|---|
| OS1 | Defeito | `osdef_defects` | `vulnerability`, `defect`, `fault` | D A | `defect_kind`; fault = defeito com manifestação registrada |
| OS2 | Falha | `osdef_failures` | `failure` | D A | **evento: create e read, sem update** |
| OS3 | Manifestação | `osdef_manifestations` | relação `manifested in` | D A | junção defeito × falha — é ela que promove defect a fault |

**3 entidades.** `vulnerable_state` e `failure_state` não persistem: derivam de
`osdef_failures.occurred_at`.

---

## 13. SRO — Scrum

Features `013` a `017`. Maior bloco de domínio.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Feature |
|---|---|---|---|---|---|
| SR1 | Projeto Scrum | `sro_scrum_projects` | `scrum_project` | D A | 013 |
| SR2 | Processo Scrum | `sro_scrum_processes` | `scrum_process` | D A | 013 |
| SR3 | Sprint | `sro_sprints` | `sprint` | D A | 013 |
| SR4 | Cerimônia | `sro_ceremonies` | `ceremony` + 4 subtipos | D A | 013 — `ceremony_type` |
| SR5 | Definição do product backlog | *(usa SPO5)* | `product_backlog_definition` | D | 013 |
| SR6 | Time Scrum | `sro_scrum_teams` | `scrum_team`, `development_team` | D A | 014 — `team_type`, sobre EO4 |
| SR7 | Alocação Scrum | *(usa EO5)* | 3 `relator` de membership | D | 014 — papel Scrum vem do catálogo EO3 |
| SR8 | Participação Scrum | *(usa SPO8)* | 11 relações de participação | D | 014 |
| SR9 | Product backlog | `sro_product_backlogs` | `product_backlog` | D A | 015 |
| SR10 | Sprint backlog | `sro_sprint_backlogs` | `sprint_backlog` | D A | 015 |
| SR11 | Item de sprint backlog | `sro_sprint_backlog_items` | relação user story × sprint backlog | D A | 015 — uma story pode voltar em sprints seguintes |
| SR12 | User story | `sro_user_stories` | `user_story`, `atomic`, `epic` | D A | 016 — `story_type`, auto-FK `parent_id` |
| SR13 | Critério de aceitação | `sro_acceptance_criteria` | 3 `goal` | D A | 016 — `criterion_type` |
| SR14 | Tarefa pretendida | `sro_intended_tasks` | `intended_scrum_development_task` | D A | 016 |
| SR15 | Tarefa executada | `sro_performed_tasks` | `performed_scrum_development_task` + 2 `phase` | D A | 016 — `outcome` = successful \| non_successful |
| SR16 | Entregável | `sro_deliverables` | `deliverable` + 2 `phase` + sprint/project | D A | 017 — `acceptance_status` + `deliverable_level` |
| SR17 | Avaliação de entregável | `sro_deliverable_acceptances` | relação com critérios | D A | 017 — aceitação decorre dos critérios, não de marcação manual |
| SR18 | Materialização | `sro_materializations` | relação `materialized` | D A | 017 — entregável × user story |

**14 tabelas novas + 4 reusos.**

> **SR17 não é enfeite.** Sem ela, `acceptance_status` vira campo preenchido à mão e a
> medida de retrabalho perde o lastro. O axioma da tese exige que a aceitação seja
> derivável dos critérios de aceitação — ver `priv/knowledge_base/rules/sro_axioms.yaml`.

---

## 14. CIRO — integração contínua

Features `018` a `021`.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Feature |
|---|---|---|---|---|---|
| CI1 | Processo de CI | `ciro_processes` | CI process + 3 trigger + 2 `phase` | D A | 018 — `trigger_type` + `outcome` |
| CI2 | Servidor de CI | `ciro_servers` | `continuous_integration_server` | D A | 018 — especializa SYS4 |
| CI3 | Atividade de feedback | `ciro_feedback_activities` | `continuous_feedback_activity` | D A | 018 |
| CI4 | Evento de solicitação | `ciro_request_events` | `ci_request_event` | D A | 018 — evento, sem update |
| CI5 | Processo de build | `ciro_build_processes` | build + 2 `phase` | D A | 019 — `outcome` |
| CI6 | Ambiente de build | `ciro_build_environments` | `ci_building_environment` | D A | 019 |
| CI7 | Código candidato | `ciro_candidate_codes` | `candidate_code` | D A | 019 — `collective` |
| CI8 | Composição do candidato | `ciro_candidate_code_items` | roles `code_under_integration`, `integrated_code` | D A | 019 — junção com `code_role` |
| CI9 | Cópia de código | `ciro_code_copies` | `source_code_copy`, `test_code_copy` | D A | 019 — `copy_type`, especializa CM4 |
| CI10 | Problema de build | `ciro_build_problems` | `build_problem` | D A | 019 |
| CI11 | Processo de teste | `ciro_test_processes` | test + 2 `phase` | D A | 020 — `outcome` |
| CI12 | Ambiente de teste de CI | `ciro_testing_environments` | `ci_testing_environment` | D A | 020 — especializa RO5 |
| CI13 | Execução automatizada | `ciro_test_executions` | `automated_test_execution` | D A | 020 — especializa RO3 |
| CI14 | Resultado de teste de CI | `ciro_test_results` | `ci_test_result` | D A | 020 — especializa RO4 |
| CI15 | Processo de inspeção | `ciro_inspection_processes` | inspection + 2 `phase` | D A | 021 — `outcome` |
| CI16 | Ambiente de inspeção | `ciro_inspection_environments` | `ci_inspection_environment` | D A | 021 |
| CI17 | Inspeção de artefato | `ciro_artifact_inspections` | `automated_artifact_inspection` | D A | 021 — especializa QA2 |
| CI18 | Relatório de CI | `ciro_evaluation_reports` | `ci_evaluation_report` | D A | 021 — especializa QA4 |
| CI19 | Código de critério | `ciro_criterion_codes` | `quality_assurance_criterion_code` | D A | 021 — materializa QA1 |
| CI20 | Ferramenta de análise estática | `ciro_analysis_tools` | `static_code_analysis_tool` | D A F | 021 — catálogo |

**20 entidades.** As criações de ambiente (`build_environment_creation`,
`ci_testing_environment_creation`, `inspection_environment_creation`) e
`code_checkout`/`candidate_code_building` usam SPO6 com `activity_type`.

> **`outcome` é coluna, nunca tabela.** Oito conceitos de fase em CIRO viram três
> colunas. Um processo que falhou e foi reexecutado é a mesma entidade com histórico,
> não uma linha nova em outra tabela.

---

## 15. CDRO — entrega e implantação contínuas

Features `022` e `023`.

| # | Entidade | Tabela | Conceitos cobertos | Nível | Feature |
|---|---|---|---|---|---|
| CD1 | Atividade de entrega | `cdro_delivery_activities` | `delivery_activity` | D A | 022 |
| CD2 | Servidor de entrega | `cdro_delivery_servers` | `continuous_delivery_server` | D A | 022 |
| CD3 | Ambiente de entrega | `cdro_delivery_environments` | `delivery_environment` | D A | 022 |
| CD4 | Processo de implantação | `cdro_deployment_processes` | CD process + 2 `phase` | D A | 023 — `outcome` |
| CD5 | Atividade de implantação | `cdro_deployment_activities` | `deployment_activity` | D A | 023 |
| CD6 | Servidor de implantação | `cdro_deployment_servers` | `continuous_deployment_server` | D A | 023 |
| CD7 | Ambiente de implantação | `cdro_deployment_environments` | `deployment_environment` | D A | 023 |
| CD8 | Feedback de implantação | `cdro_feedback_activities` | `continuous_deployment_feedback_activity` | D A | 023 |

**8 entidades.** `delivered_code` e `deployed_code` são papéis do código candidato →
colunas `delivered_candidate_code_id` / `deployed_candidate_code_id` em CD1/CD5.

---

## 16. Totais e ordem de execução

| Bloco | Entidades | Feature |
|---|---:|---|
| Fundação | 7 | 001, 024 |
| EO | 5 | 005 |
| SPO | 11 | 006 |
| SysSwO | 5 | 007 |
| RSRO | 4 | 008 |
| CMPO | 8 | 009 |
| ROoST | 5 | 010 |
| QAPO | 4 | 011 |
| OSDEF | 3 | 012 |
| SRO | 14 | 013–017 |
| CIRO | 20 | 018–021 |
| CDRO | 8 | 022–023 |
| **Total** | **94** | |

Dos 94, **8 precisam de formulário** (nível F). Os outros 86 são populados por ingestão
e expõem `upsert_from_source/2` idempotente.

### Ordem obrigatória

Segue a direção de dependência da rede — o inverso quebra por FK inexistente:

```text
Fundação (F1–F7)
  → EO (5)
    → SPO (11)          ← espinha dorsal: quase tudo depois especializa daqui
      → SysSwO (5)
        → RSRO (4)  ·  CMPO (8)  ·  ROoST (5)  ·  QAPO (4)
          → OSDEF (3)
            → SRO (14)   ← precisa de EO, SPO, SysSwO, RSRO
            → CIRO (20)  ← precisa de SPO, SysSwO, CMPO, ROoST, QAPO, OSDEF
              → CDRO (8) ← precisa de SPO, SysSwO, CIRO
```

SRO e CIRO são independentes entre si e podem ser feitos em paralelo por times distintos.

### Caminho até o primeiro valor entregue

Se o objetivo é ver o sistema respondendo alguma pergunta real o quanto antes, a fatia
mínima é:

```text
Fundação (F1, F3, F5, F6) → EO1, EO2 → SPO1, SPO6, SPO8 → SYS4 → CM1, CM2, CM5, CM6
```

**13 entidades** — suficiente para ingerir repositórios, commits e Pull Requests do
GitHub e responder as perguntas de tempo de revisão e volume de mudança. O resto da rede
entra depois, sem retrabalho, porque a fronteira já está no lugar certo.

---

## 17. Riscos conhecidos

**SPO6 é o gargalo.** `spo_performed_activities` recebe atividade de CM, teste,
inspeção, Scrum e CD. Vai ser a maior tabela do sistema. Particionamento por `tenant_id`
e por período precisa ser avaliado já na feature 006 — depois fica caro.

**Discriminadores viram lixeira.** `activity_type` em SPO6 acumula valores de cinco
ontologias. Sem enum validado contra a base de conhecimento, em seis meses haverá
`"commit"`, `"Commit"` e `"commit_artifact_copy"` convivendo. O valor deve ser derivado
do id do conceito no YAML, não digitado.

**Reconciliação de identidade de pessoa (EO2).** Uma pessoa com contas em GitHub, Jira e
Sonar precisa virar uma linha só. Fazer isso por similaridade de nome ou e-mail produz
erro silencioso que contamina toda métrica por pessoa. Precisa de feature própria, com
regra explícita e revisão humana — não resolver no CRUD de EO2.

**Aceitação de entregável (SR17).** Se a feature 017 entregar `acceptance_status` como
campo livre, a medida de retrabalho nasce sem lastro. O axioma exige derivação a partir
dos critérios.

---

## 18. Próximo passo

Este backlog não é especificação. Cada bloco precisa do ciclo do Spec Kit — ver
[processo por feature](../processes/feature-workflow.md).

Sugestão de primeira feature a especificar:

```text
/speckit-specify Fundação de persistência multitenant com proveniência:
tenants, fontes externas, entidades brutas e registros de proveniência,
mais o esqueleto de módulo ontológico com API pública, exemplificado por EO.
```
