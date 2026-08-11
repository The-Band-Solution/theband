# Tarefas — Feature 004: issues e projetos das organizações observadas

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contratos**: [contracts/](contracts/)

Quarenta e seis tarefas em sete fases. **MVP: F0 a F3** — issues classificadas, com
a lacuna visível e uma tela que as mostra.

A ordem das fases é **dependência**, não preferência. Cada fase existe porque a
seguinte não funciona sem ela.

---

## Fase F0 — O kind referenciado

Bloqueia tudo: sem a tabela do kind, `cmpo.source_repository` não tem para onde ser
elevado, e sem repositório não existe o escopo da marca de ausência.

- [ ] T001 Anotar o kind referenciado
  - **Pronta quando**: nada além do repositório. A regra da fronteira está na
    constituição IX, e a decisão está em `research.md` R1
  - **Descrição**: em
    `priv/knowledge_base/ontology/seon/sys_swo/modules/system_and_software.yaml`,
    acrescentar `ontouml_stereotype: kind` a
    `sys_swo.loaded_software_system_copy`. **Apenas este conceito.** Os outros 10 da
    SysSwO ficam como estão — anotar a ontologia inteira para registrar um
    repositório é o pré-requisito disfarçado que o princípio IX nomeia. O conceito
    não tem `parent` declarado, logo `kind` é a única leitura possível
  - **Feita quando**: `derive_information_model.py --ontology cmpo` deixa de listar
    exigência pendente e passa a emitir a tabela do kind referenciado; a SysSwO
    continua **não** derivável, com 10 conceitos sem estereótipo
  - **Teste**: `mix gates` — o gate de derivação passa nas quatro ontologias; e
    `derive_information_model.py --ontology cmpo | grep -c "sem ontouml_stereotype"`
    devolve 0. É a V1 do quickstart

- [ ] T002 Provar que a referência é uma tabela só
  - **Pronta quando**: T001 concluída
  - **Descrição**: teste de regressão em `test/knowledge/boundary_rule_test.exs`
    conferindo que `cmpo.source_repository` contribui um valor de discriminador em
    `sys_swo.loaded_software_system_copy` e **não** ganha tabela própria de CMPO. É a
    prova de que a regra da fronteira valeu
  - **Feita quando**: o teste falha se alguém trocar o estereótipo de
    `source_repository` para `kind`, e a mensagem diz que isso fragmentaria a tabela
  - **Teste**: `test/knowledge/boundary_rule_test.exs` — a saída da derivação de CMPO
    contém `sys_swo.loaded_software_system_copy.type += {source_repository}` e não
    contém `┌─ cmpo_source_repositories   (cmpo.source_repository, kind)`

---

## Fase F1 — Semântica declarada

Antes do código, como na 002 e na 003. A regra do tenant é o que impede o antipadrão
de mapeamento por semelhança de nome.

- [ ] T003 [P] Declarar a regra do tenant
  - **Pronta quando**: T001 concluída; os mapeamentos de issue já existem na base
  - **Descrição**: criar `priv/knowledge_base/rules/tenants/the_band_solution.yaml`
    com os nomes de tipo de issue que esta organização usa — `Feature`, `Task`,
    `Bug` — e o mapeamento **campo → atributo** por `field_external_id`, nunca por
    nome. Declarar explicitamente que o quadro **não tem** campo numérico de
    importância, e que `Estimate` mapeia para `sro.user_story.complexity` — FR-024,
    FR-026, FR-027
  - **Feita quando**: a regra nomeia os três tipos observados na organização real; a
    ausência de campo de importância está escrita como declaração, não como omissão;
    nenhum mapeamento usa nome de campo como chave
  - **Teste**: `mix gates` — validador Python aceita a regra e resolve todos os
    `rule_ref`; e um teste em `test/knowledge/tenant_rules_test.exs` exige que
    `Priority` **não** apareça mapeado para `importance`

- [ ] T004 [P] Escrever a consulta de repositórios
  - **Pronta quando**: T001 concluída
  - **Descrição**: `priv/connectors/github/queries/repositories.graphql` pedindo
    `id`, `name`, `nameWithOwner`, `archivedAt`, `owner.id` e o `pageInfo` para
    cursor. Incluir `rateLimit` com `cost`, `remaining` e `resetAt` — o controle de
    consumo lê da própria resposta, e descobrir o limite por erro 403 já é tarde
  - **Feita quando**: a consulta é aceita pela API real; devolve os 14 repositórios
    de `The-Band-Solution` em uma página
  - **Teste**: teste de contrato em `test/the_band/integrations/github/queries_test.exs`
    com payload capturado, conferindo que os campos exigidos pelo mapeamento existem
    no resultado

- [ ] T005 [P] Escrever as consultas de issues
  - **Pronta quando**: T001 concluída
  - **Descrição**: `priv/connectors/github/queries/issues.graphql` e
    `sub_issues.graphql`. A de issues pede `id`, `number`, `title`, `state`,
    `issueType.name`, `parent.id`, `parent.issueType.name` e
    `subIssues.totalCount`. A de sub-issues pede os `nodes` com `id` e
    `issueType.name` — é o tipo das partes que decide épico contra atômica, e sem ele
    a distinção não é possível
  - **Feita quando**: a consulta devolve as 95 issues de `theband`; `issueType.name`
    vem nulo para issue sem tipo, em vez de a consulta falhar
  - **Teste**: `test/the_band/integrations/github/queries_test.exs` — com o payload
    real de `theband`, a contagem por tipo dá `Task: 79, Feature: 15, Bug: 1`

- [ ] T006 Declarar o conector de issues
  - **Pronta quando**: T004 e T005 concluídas; T003 concluída
  - **Descrição**: `priv/connectors/github/definitions/sro_ingestion.yaml` com as
    entradas de repositório, issues e sub-issues. O `checkpoint` é **por
    repositório**, não por organização — retomar não pode recomeçar o repositório
    inteiro. `rate_limit.pause_when` igual ao das definições existentes: pausar antes
    do estouro, nunca depois
  - **Feita quando**: o runtime carrega a definição e valida sem código específico
    por entidade; o checkpoint declarado tem granularidade de repositório; **cada
    issue coletada tem o payload bruto preservado** em `raw_payloads`, com
    `mapping_id` e `mapping_version` — FR-007, e é o que torna o reprocessamento
    barato quando a regra mudar
  - **Teste**: `test/the_band/ingestion/connector_definition_test.exs` — a definição
    valida contra o schema, e o `nodes_path` de cada entrada resolve no payload
    capturado

---

## Fase F2 — Repositório observado (US3 parcial, base da US1)

Bloqueia F3: a issue pertence a um repositório, e o escopo da ausência é ele.

- [ ] T007 Migrar a tabela do kind referenciado
  - **Pronta quando**: T001 concluída
  - **Descrição**: migração criando `sys_swo_loaded_software_system_copies` a partir
    da saída do derivador — `tenant_id`, `internal_id`, `record_version`,
    discriminador `type`, e a Application Reference. No `@moduledoc`, escrever que a
    tabela é **de SysSwO** e que CMPO a referencia: a próxima ontologia que precisar
    de cópia carregada aponta para ela e acrescenta seu valor de discriminador.
    Nenhuma coluna é removida nesta feature
  - **Feita quando**: `mix ecto.migrate` e o rollback voltam ao estado anterior; o
    `check_constraint` do discriminador aceita `source_repository` e recusa valor
    fora da lista
  - **Teste**: `mix ecto.migrate && mix ecto.rollback --step 1 && mix ecto.migrate`;
    e inserir linha com `type = 'inexistente'` direto no banco tem de falhar

- [ ] T008 Migrar a extensão do repositório
  - **Pronta quando**: T007 concluída
  - **Descrição**: migração criando `cmpo_source_repositories` como extensão, com FK
    para a tabela do kind, mais `name`, `full_name`, `organization_id`,
    `archived_at`, `last_observed_at` e `no_longer_observed_at`. **`archived_at` e
    `no_longer_observed_at` são coisas diferentes** e o `@moduledoc` precisa dizer:
    arquivado é fato da origem, não mais observado é inferência da plataforma — FR-003,
    e as issues de repositório arquivado continuam consultáveis
  - **Feita quando**: apagar a linha do kind apaga a extensão; a leitura da extensão
    sem juntar com o kind não devolve o discriminador — a fronteira existe no esquema
  - **Teste**: `test/the_band/ontology/seon/cmpo/schemas_test.exs` — inserir
    repositório e conferir que ele aparece em `sys_swo_loaded_software_system_copies`
    com `type = 'source_repository'`

- [ ] T009 Migrar o repositório observado
  - **Pronta quando**: T008 concluída
  - **Descrição**: migração criando `observed_repositories` com `connected_tool_id`,
    `source_repository_id`, `excluded_at`, `excluded_by_user_id`,
    `inaccessible_since` e `inaccessible_reason`. Camada de plataforma: aqui vive o
    que **a plataforma decidiu**, e não o que o mundo é — FR-004, FR-006
  - **Feita quando**: as três situações são distinguíveis por consulta — observado,
    excluído pelo tenant, inacessível pela credencial
  - **Teste**: `test/the_band/projects/observed_repository_test.exs` — as três
    situações produzem três resultados diferentes em `list_observed/2`

- [ ] T010 Descobrir os repositórios da organização
  - **Pronta quando**: T006 e T009 concluídas; o contrato em
    `contracts/issue-ingestion.md` está escrito
  - **Descrição**: módulo raiz `lib/the_band/ontology/seon/cmpo.ex` com
    `upsert_source_repository_from_source/2`, apenas `defdelegate` (ADR 0003).
    Schemas privados em `cmpo/schemas/`. A descoberta parte da organização observada
    — FR-001, FR-002 —, sem exigir conectar repositório
  - **Feita quando**: uma coleta registra os 14 repositórios de
    `The-Band-Solution`; duas coletas idênticas não duplicam nenhum — FR-009
  - **Teste**: `test/the_band/ontology/seon/cmpo/commands_test.exs` — idempotência
    pela Application Reference, e a contagem dá 14 nas duas execuções. É a V2 do
    quickstart

- [ ] T011 Excluir repositório da observação
  - **Pronta quando**: T010 concluída
  - **Descrição**: `exclude_from_observation/3` e `include_in_observation/2` em
    `TheBand.Ontology.SEON.CMPO`. A exclusão registra **quem** e **quando** — é
    decisão, e decisão tem autor. A coleta seguinte não consulta o repositório
    excluído, e **não marca as issues dele** — FR-004, FR-005
  - **Feita quando**: o relatório da coleta não lista o repositório excluído; nenhuma
    issue dele ganha `no_longer_observed_at`
  - **Teste**: `test/the_band/work_items/absence_scope_test.exs` — depois de excluir e
    coletar, `Enum.count(issues, & &1.no_longer_observed_at)` dá **0**. É a V8, e os
    dois lados importam

- [ ] T012 Marcar repositório inacessível
  - **Pronta quando**: T010 concluída
  - **Descrição**: quando a consulta ao repositório devolver 404 ou 403, gravar
    `inaccessible_since` e `inaccessible_reason`, marcar a ferramenta conectada como
    exigindo atenção **nomeando o repositório**, e **não** marcar ausência nas issues
    — FR-006. Perder alcance não é o dado ter sumido
  - **Feita quando**: a ferramenta passa a exigir atenção com o nome do repositório
    na razão; as issues dele continuam sem marca de ausência
  - **Teste**: `test/the_band/work_items/absence_scope_test.exs` — com o Mox
    devolvendo 404 para um repositório, as issues dele seguem vigentes e
    `needs_attention_reason` contém o nome

---

## Fase F3 — Issues, promoção e recusa (US1, P1)

O núcleo. **Objetivo da história**: saber quais issues existem e o que elas são, com
a lacuna visível.

**Teste independente da história**: coletar `The-Band-Solution` e conferir que a soma
de promovidas e não promovidas bate com o total, que os seis casos estruturais reais
classificam certo, e que a tarefa sem pai aparece como divergência.

- [ ] T013 [US1] Migrar a issue coletada
  - **Pronta quando**: T009 concluída; `contracts/issue-ingestion.md` escrito
  - **Descrição**: migração criando `collected_issues` com
    `observed_repository_id` **não anulável** — é o escopo da ausência —, `issue_type`
    anulável e **cru**, `number`, `title`, `state`, Application Reference, e o par
    `last_observed_at` / `no_longer_observed_at`. Índice único por
    `(tenant_id, source_system, source_instance, external_id)`. `number` **não** entra
    no índice: mover a issue entre repositórios cria outro número — FR-008
  - **Feita quando**: o índice único recusa a segunda inserção da mesma issue; uma
    issue com `issue_type` nulo é gravada sem erro
  - **Teste**: `mix ecto.migrate` e rollback; e inserir duas vezes a mesma
    Application Reference tem de violar o índice

- [ ] T014 [US1] Migrar a promoção da issue
  - **Pronta quando**: T013 concluída
  - **Descrição**: migração criando `issue_promotions` com `declared_concept`,
    `derived_concept`, `target_table`, `target_id`, `rule_id`, `rule_version`,
    `divergence_reason` e `skip_reason`. `rule_version` é **não anulável**: é o que
    permite responder por que uma issue foi classificada assim depois de a regra
    mudar — FR-012. **A migração NÃO cria `sro_user_stories.status`**, e o
    `@moduledoc` precisa dizer isso por extenso, senão a próxima pessoa a acrescenta
    achando que faltava
  - **Feita quando**: os três estados são distinguíveis — promovida, não promovida com
    motivo, promovida contra o rótulo declarado; nenhuma migração desta fase cria
    coluna de classificação
  - **Teste**: `mix ecto.migrate` e rollback; e
    `grep -c "status" priv/repo/migrations/*issue_promotions*` não encontra criação de
    coluna de status em `sro_user_stories`

- [ ] T015 [US1] Migrar vínculos e recusas
  - **Pronta quando**: T013 concluída
  - **Descrição**: migração criando `decomposition_links` — par pai/parte com o trio
    de observação — e `refused_links`, com `reason` (`cycle` ou `out_of_scope`) e
    `cycle_path`. **Sem `check_constraint` de aciclicidade**: o axioma `sro.rule04`
    diz que constraint de banco não pega ciclo transitivo em auto-relacionamento, e o
    `@moduledoc` cita isso para ninguém a acrescentar depois
  - **Feita quando**: um vínculo recusado sobrevive à transação que o recusou; o
    `cycle_path` guarda o caminho em ordem
  - **Teste**: `mix ecto.migrate` e rollback; e inserir um ciclo direto no banco
    **passa** — a proteção não é do banco, e o teste registra isso

- [ ] T016 [US1] Gravar a issue coletada
  - **Pronta quando**: T013 concluída; `contracts/issue-ingestion.md` escrito
  - **Descrição**: `lib/the_band/work_items.ex` como módulo raiz com apenas
    `defdelegate`; schemas privados em `work_items/schemas/`.
    `record_collected_issue/2` idempotente pela Application Reference. **`issue_type`
    não é normalizado** — normalizar destrói o dado que a lacuna precisa mostrar
    (FR-034)
  - **Feita quando**: duas chamadas idênticas devolvem a mesma linha e nenhuma
    contagem muda; `issue_type` gravado é exatamente o que a origem devolveu
  - **Teste**: `test/the_band/work_items/commands_test.exs` — idempotência; uma issue
    de tipo `Spike` é gravada com `issue_type: "Spike"`, sem tradução; e uma issue que
    muda de repositório e de `number`, com o mesmo `external_id`, continua **uma**
    linha — edge case 2, e é o que o índice sem `number` existe para garantir

- [ ] T017 [US1] Promover pela regra versionada
  - **Pronta quando**: T014 e T016 concluídas; T003 concluída
  - **Descrição**: aplicar `github.issue_type_routing` no
    `lib/the_band/semantic_integration/mapper.ex`, chamando a API pública do módulo
    ontológico de destino. **Nenhum `case` sobre nome de tipo em código Elixir**: a
    regra é semântica e vive em YAML versionado (princípio IV). `record_promotion/2`
    é chamada **sempre**, inclusive quando não promove — issue sem registro de
    promoção é indistinguível de issue não processada
  - **Feita quando**: toda issue coletada tem exatamente um registro de promoção;
    `rule_id` e `rule_version` gravados batem com a regra em disco — SC-004, 100% das
    promovidas com a regra e a versão
  - **Teste**: `test/the_band/semantic_integration/issue_promotion_test.exs` — `Bug`
    vira `osdef.defect`, `Task` com pai atômico vira tarefa pretendida, e a contagem
    de promoções é igual à de issues coletadas

- [ ] T018 [US1] Gravar a divergência entre declarado e derivado
  - **Pronta quando**: T017 concluída
  - **Descrição**: ao promover, comparar o conceito que o **tipo declarado** indicava
    com o que a **estrutura** decidiu, e gravar `divergence_reason` quando
    diferirem — FR-013. A análise achou que nenhuma tarefa preenchia essa coluna:
    T017 gravava a promoção, T019 derivava a classificação, e a tela leria coluna
    vazia. Casos reais na organização: issue tipada `Feature` **com** sub-issues que
    são user stories, promovida a épico contra o rótulo
  - **Feita quando**: uma issue `Epic` sem partes tem `declared_concept: sro.epic`,
    `derived_concept: sro.atomic_user_story` e a razão por extenso; uma issue sem
    divergência tem `divergence_reason` nulo, não vazio
  - **Teste**: `test/the_band/semantic_integration/divergence_test.exs` — com os seis
    casos estruturais reais, a contagem de divergências é a esperada, e nenhuma issue
    concordante aparece como divergente

- [ ] T019 [US1] Relatar por repositório o que foi promovido
  - **Pronta quando**: T017 e T018 concluídas
  - **Descrição**: o relatório da coleta passa a registrar, **por repositório**,
    quantas issues foram encontradas, quantas promovidas e quantas não promovidas —
    FR-011. Os contadores de `syncs` são globais e não respondem isso. É o que
    sustenta a seção de contagens da tela
  - **Feita quando**: coletar dois repositórios produz dois conjuntos de contagens
    distintos; a soma dos promovidos e não promovidos de cada um bate com o total dele
  - **Teste**: `test/the_band/ingestion/repository_report_test.exs` — com 19 e 11
    issues em dois repositórios, o relatório traz `19 = p + np` e `11 = p + np`,
    separadamente

- [ ] T020 [US1] Registrar mudança de classificação entre coletas
  - **Pronta quando**: T018 concluída
  - **Descrição**: quando a coleta seguinte derivar conceito diferente para a mesma
    issue, gravar **nova** linha de promoção em vez de atualizar a anterior, e a
    vigente é a mais recente — FR-019, edge case 12. Append-only pelo mesmo motivo dos
    eventos de observação: atualizar reescreveria o passado, e a pergunta "como esta
    issue estava classificada em março" desapareceria
  - **Feita quando**: duas coletas com estrutura diferente produzem duas linhas de
    promoção para a mesma issue; a consulta devolve a última; a anterior continua
    consultável
  - **Teste**: `test/the_band/work_items/promotion_history_test.exs` — issue atômica
    que ganha sub-issue de user story passa a épico, e as duas linhas existem com a
    ordem definida

- [ ] T021 [US1] Consultas de issues, promoções e lacunas
  - **Pronta quando**: T018 e T019 concluídas; `contracts/issue-ingestion.md` escrito
  - **Descrição**: `count_collected/2`, `list_issues/2`, `count_by_promotion/2`,
    `count_gaps_by_reason/2` e `list_divergences/2` em
    `lib/the_band/work_items/queries.ex`, expostas por `defdelegate`. Todas aceitam
    `repository_id` e `organization_id`. SC-001 e SC-003 são verificados por elas.
    **Nenhuma devolve `Ecto.Query`**: quem recebe
    query compõe e, ao compor, contorna o filtro de tenant
  - **Feita quando**: as cinco existem e são as usadas pela tela; a invariante de
    SC-001 vale — coletadas igual a promovidas mais lacunas — sob qualquer filtro
  - **Teste**: `test/the_band/work_items/queries_test.exs` — a invariante conferida
    com filtro por repositório e sem filtro, e nenhuma função devolvendo `%Ecto.Query{}`

- [ ] T022 [US1] Registrar a lacuna com o nome do tipo
  - **Pronta quando**: T017 concluída
  - **Descrição**: `skip_reason` em `:type_absent`, `:type_unknown` ou
    `:sub_issues_unavailable`, e `skip_detail` com **o nome do tipo encontrado** —
    FR-014, FR-034. `count_gaps_by_reason/2` agrupa por motivo
  - **Feita quando**: uma issue de tipo desconhecido não tem `derived_concept`, e
    aparece contada com o nome do tipo; nenhuma issue sem tipo aparece promovida
  - **Teste**: `test/the_band/work_items/promotion_gap_test.exs` — pela violação:
    `derived_concept` é `nil` e `skip_detail` é `"Spike"`. SC-005, e é a V6 do
    quickstart

- [ ] T023 [US1] Derivar épico de atômica
  - **Pronta quando**: T015 e T022 concluídas
  - **Descrição**: `classification/2` em
    `lib/the_band/ontology/continuum/sro/queries.ex`, derivando da existência de
    partes que **são user stories** — FR-015, FR-016. Sub-issues do tipo tarefa
    **não** tornam a issue épica: tarefa atende, não compõe. **Um caminho só**: a
    tela, a consulta de escopo e o teste usam esta função, como
    `observation_ended?/1`. Não criar `set_classification/3`
  - **Feita quando**: os seis casos reais classificam certo; nenhuma coluna guarda a
    classificação; `list_epics/2` e `list_atomic/2` usam `classification/2` e não uma
    segunda consulta; **nenhuma folha da decomposição é épico** — `sro.rule06` e
    SC-006, sem os quais existiria ramo de escopo que nunca vira trabalho
  - **Teste**: `test/the_band/ontology/continuum/sro/classification_test.exs` com os
    dados reais — `#1 :epic`, **`#3 :atomic_user_story` com nove sub-issues Task**,
    `#4` e `#5` atômicas, `#79` e `#98` épicos. É a V4, e a segunda asserção é a que
    não pode passar por acidente

- [ ] T024 [US1] Recusar ciclo no comando
  - **Pronta quando**: T015 e T023 concluídas
  - **Descrição**: `record_decomposition_link/2` verificando o caminho até a raiz
    **antes** de persistir, e devolvendo `{:error, {:cycle, caminho}}`. O vínculo
    recusado **é gravado** em `refused_links` com o caminho — FR-017. **As duas
    issues permanecem coletadas**: recusa-se o vínculo, nunca a issue
  - **Feita quando**: SC-007 vale — nenhum ciclo existe, e cada recusa traz o
    caminho. Um ciclo de três issues é recusado nomeando o caminho na ordem;
    as três continuam em `collected_issues`; o vínculo recusado é consultável depois
    da transação
  - **Teste**: `test/the_band/work_items/decomposition_test.exs` — A→B→C→A devolve
    `{:error, {:cycle, ["A","B","C","A"]}}`, e `count_collected/2` continua 3

- [ ] T025 [US1] Registrar referência fora do escopo
  - **Pronta quando**: T028 concluída
  - **Descrição**: sub-issue em repositório fora do escopo observado é gravada em
    `refused_links` com `reason: :out_of_scope`, e a parte **não** é promovida —
    FR-018. Edge case 3 da spec
  - **Feita quando**: a relação é consultável; nenhuma issue foi criada para a parte
    externa
  - **Teste**: `test/the_band/work_items/decomposition_test.exs` — a parte externa
    não aparece em `collected_issues`, e o vínculo aparece em `refused_links`

- [ ] T026 [US1] Marcar ausência por repositório
  - **Pronta quando**: T016 concluída; T011 concluída
  - **Descrição**: `mark_issues_no_longer_observed/3` em `TheBand.WorkItems`,
    **exigindo `repository_id`** na assinatura. **Não criar versão de aridade 2** —
    FR-010. É a L19 impedida no tipo: o defeito original atingiu 3 organizações, e
    numa organização de 14 repositórios atingiria 13
  - **Feita quando**: coletar um repositório não marca as issues de outro; a função de
    aridade 2 não existe no módulo
  - **Teste**: `test/the_band/work_items/absence_scope_test.exs` — dois repositórios e
    duas coletas em sequência; depois de coletar B, as issues de A têm **0** marcas. É
    a V7, e sem ela o defeito volta em volume quatro vezes maior

- [ ] T027 [US1] Interromper coleta pelo limite de consumo
  - **Pronta quando**: T006 e T016 concluídas
  - **Descrição**: pausar quando `remaining < cost * 2`, gravar o checkpoint **por
    repositório** e retomar de onde parou — FR-038, FR-039. Gravar o checkpoint
    **depois** de processar a página, nunca antes
  - **Feita quando**: a coleta interrompida retoma sem recoletar nenhuma página —
    SC-011; o progresso parcial permanece gravado
  - **Teste**: `test/the_band/ingestion/rate_limit_test.exs` — com o Mox devolvendo
    `remaining` baixo na terceira página, a retomada começa na terceira e as duas
    primeiras não são pedidas de novo. É a V11 do quickstart

- [ ] T028 [US1] Tela de issues com lacunas
  - **Pronta quando**: T018, T023 e T030 concluídas; `contracts/screens.md` escrito
  - **Descrição**: LiveView em `lib/the_band_web/live/work_item_live/index.ex`
    mostrando, por organização: repositórios observados, total coletado, promovidas
    por conceito, **não promovidas por motivo com o nome do tipo**, e as divergências
    — FR-033 a FR-035. Distinguir repositório coletado-e-vazio de não-coletado
    (FR-036). **Não** exibir soma de épicos com atômicas: são coisas diferentes, e a
    soma seria contagem dupla
  - **Feita quando**: as seções somam o total coletado; os três estados vazios têm
    textos diferentes — SC-010; a divergência aparece com o conceito declarado e o derivado
  - **Teste**: `test/the_band_web/live/work_item_live_test.exs` — o HTML contém
    `tipo desconhecido` com o nome, e **não** contém nenhum rótulo somando épicos e
    atômicas

- [ ] T029 [US1] Provar o isolamento entre tenants
  - **Pronta quando**: T028 concluída
  - **Descrição**: teste com **dois** tenants povoados, conferindo que nenhum dado de
    um aparece para o outro por nenhum caminho — SC-012. Recurso de outro tenant
    devolve `:not_found`, nunca "sem permissão": dizer "sem permissão" já entrega que
    o recurso existe
  - **Feita quando**: a listagem do vizinho é vazia; o `fetch` por id devolve
    `{:error, :not_found}`; o dono continua alcançando — a contraprova evita o teste
    que passa com tudo quebrado
  - **Teste**: `test/the_band/work_items/isolation_test.exs` — três asserções, sendo
    a terceira a contraprova

---

## Fase F4 — Projetos, campos e iterações (US2, P2)

**Objetivo da história**: enxergar os quadros e o que cada item carrega, sabendo o
que a plataforma interpreta e o que ela apenas guarda.

**Teste independente**: coletar o quadro real e conferir que a soma dos backlogs dá
107, que `Priority` fica não interpretado, e que nenhuma iteração futura aparece como
sprint.

- [ ] T030 [US2] Escrever as consultas de quadro
  - **Pronta quando**: T006 concluída
  - **Descrição**: `projects_v2.graphql` e `project_items.graphql` em
    `priv/connectors/github/queries/`. Pedir projeto, definições de campo com
    `id` — **nunca só o nome** —, itens com `content.id` e valores de campo. **Não**
    pedir histórico de item: é o que custa centenas de pontos de consumo, e está fora
    de escopo por decisão (FR-028)
  - **Feita quando**: a consulta devolve os 107 itens e 17 campos do quadro real; não
    há nenhum campo de histórico na consulta
  - **Teste**: `test/the_band/integrations/github/queries_test.exs` — o payload
    capturado tem `field.id` para todos os 17 campos, e nenhuma chave de histórico

- [ ] T031 [US2] Migrar quadro, campos e itens
  - **Pronta quando**: T030 concluída; `contracts/project-ingestion.md` escrito
  - **Descrição**: migração criando `observed_projects`, `project_field_definitions`,
    `project_items`, `item_field_values` e `project_iterations`. A identidade do campo
    é `field_external_id`, e `name` é atributo mutável — FR-027. `observed_projects`
    **não tem coluna apontando para conceito nenhum**: o quadro não é promovido, e o
    `@moduledoc` diz por quê
  - **Feita quando**: renomear um campo atualiza `name` da mesma linha, sem criar
    outra; `observed_projects` não tem FK para tabela de domínio
  - **Teste**: `mix ecto.migrate` e rollback; e um teste que coleta duas vezes com o
    nome do campo mudado e exige **uma** linha em `project_field_definitions`

- [ ] T032 [US2] Coletar o quadro sem promover
  - **Pronta quando**: T027 concluída
  - **Descrição**: `lib/the_band/projects.ex` com `record_observed_project/2`. **A
    assinatura não aceita campo de promoção** — é isso que impede promover por
    engano. O quadro é planejamento e visualização, decisão registrada em
    `rules/github_project_board.yaml` — FR-020, FR-020a
  - **Feita quando**: SC-009a vale — nenhum quadro coletado tem registro em tabela de
    domínio, de software nem Scrum; a
    função rejeita `attrs` com chave de promoção em vez de ignorá-la em silêncio; um
    item que referencia issue já coletada aponta para ela **sem criar segunda linha de
    issue** (FR-021); item de rascunho é gravado com `is_draft` e sem promoção (FR-022)
  - **Teste**: `test/the_band/projects/board_test.exs` — depois de coletar, a
    contagem de `spo`-qualquer-coisa ligada ao quadro é 0; e passar
    `spo_project_id` devolve erro

- [ ] T033 [US2] Guardar valor de campo não interpretado
  - **Pronta quando**: T031 e T003 concluídas
  - **Descrição**: `record_item_field_value/2` sempre grava `raw_value`; preenche
    `interpreted_as` **apenas** com mapeamento declarado para aquele
    `field_external_id` — FR-025. `Priority` **não** é `importance`
  - **Feita quando**: `Priority` fica com `interpreted_as: nil` e `raw_value`
    preenchido; `Estimate` fica interpretado como `sro.user_story.complexity`. SC-008 e
    FR-023 — definição e valor, ambos coletados
  - **Teste**: `test/the_band/projects/field_value_test.exs` — as duas asserções, e a
    segunda é a contraprova sem a qual o teste passaria com a interpretação quebrada
    para todos os campos. É a V12

- [ ] T034 [US2] Promover iteração conforme o início
  - **Pronta quando**: T031 concluída; a regra `github.iteration_started` existe
  - **Descrição**: `record_iteration/2` devolvendo `{:sprint, id}` ou
    `{:intended_process, id}` — quem chama precisa saber qual foi, e descobrir
    relendo a linha seria um segundo caminho de derivação. Iteração futura promove a
    `spo.specific_intended_project_process`; iniciada, a `sro.sprint` — FR-029,
    FR-030
  - **Feita quando**: toda iteração tem exatamente um dos dois preenchido — SC-009c;
    nenhuma iteração futura aparece em `list_sprints/2` — SC-009
  - **Teste**: `test/the_band/projects/iteration_test.exs` — o predicado
    `(sro_sprint_id != nil) != (spo_intended_process_id != nil)` vale para todas. É a
    V9, e cobre SC-009c

- [ ] T035 [US2] Derivar os dois backlogs
  - **Pronta quando**: T034 concluída
  - **Descrição**: `product_backlog/2` pelo id do **quadro**, `sprint_backlog/2` pelo
    id do **sprint**, ambos derivados da atribuição de iteração — FR-032, FR-032a,
    FR-032b. **Não gravar pertencimento**: arrastar um item no quadro faria o registro
    divergir da origem
  - **Feita quando**: a soma dos dois conjuntos é igual ao total de itens do quadro;
    nenhum item aparece nos dois; item de rascunho não aparece em nenhum
  - **Teste**: `test/the_band/ontology/continuum/sro/backlog_test.exs` — com o quadro
    real, `6 + 73 + 28 == 107`. É a V10 e cobre SC-009b

- [ ] T036 [US2] Passar de pretendida a sprint na coleta seguinte
  - **Pronta quando**: T034 concluída
  - **Descrição**: quando a coleta encontrar iteração já iniciada que estava
    registrada como pretendida, criar o registro de sprint e **manter** o de processo
    pretendido como histórico — FR-030a. A troca acontece **na coleta**, nunca no
    instante do início: a plataforma afirma o que observou, não o que o calendário
    implica. A análise achou que T034 promovia na primeira coleta e nada tratava a
    segunda
  - **Feita quando**: a iteração passa a ter sprint e deixa de ser a pretendida
    vigente; o registro anterior continua consultável; a identidade externa é a mesma
    nos dois
  - **Teste**: `test/the_band/projects/iteration_transition_test.exs` — duas coletas
    com a data cruzando o início, e o predicado de SC-009c continua valendo nas duas

- [ ] T037 [US2] Marcar iteração ausente da configuração
  - **Pronta quando**: T034 concluída
  - **Descrição**: iteração removida da configuração do quadro é marcada como não mais
    presente na origem, **nunca apagada** — FR-031, edge case 8. Apagar destruiria a
    resposta a "o que foi feito naquele sprint" e a "o que foi planejado e nunca
    aconteceu". **Os itens dela NÃO voltam ao product backlog**: voltar afirmaria um
    replanejamento que ninguém decidiu
  - **Feita quando**: a iteração removida continua consultável com a marca; o sprint
    dela continua existindo; os itens que a tinham não aparecem no product backlog
  - **Teste**: `test/the_band/projects/iteration_test.exs` — depois de a iteração sumir
    da configuração, `sprint_backlog/2` dela ainda responde, e
    `product_backlog/2` do quadro **não** cresceu

- [ ] T038 [US2] Declarar organização sem quadros
  - **Pronta quando**: T032 concluída; `contracts/project-ingestion.md` escrito
  - **Descrição**: `projects_available?/2` verificado no **início** da coleta de
    projetos, com o resultado no relatório do `sync` — FR-040. Organização que não usa
    Projects v2 não produz sprint nem backlog, e isso precisa aparecer como
    **declarado**: descobrir depois de três dias de sincronização sem resultado é o
    risco que o backlog do GitHub → SRO já registrava
  - **Feita quando**: o relatório distingue "nenhum quadro na organização" de "coleta
    de quadros falhou"; a tela mostra a primeira como declaração e não como vazio
  - **Teste**: `test/the_band/projects/availability_test.exs` — com o Mox devolvendo
    zero projetos, o relatório traz o motivo declarado, e nenhum erro é registrado

- [ ] T039 [US2] Provar idempotência de quadro e itens
  - **Pronta quando**: T032, T033 e T035 concluídas
  - **Descrição**: teste de segunda coleta sem mudança na origem, conferindo contagens
    idênticas de **projetos, itens e valores de campo** — SC-002. A análise achou que
    a idempotência estava testada só para issue e repositório, e é justamente nos
    valores de campo que o risco existe: um `upsert` pela chave errada duplicaria um
    valor por coleta
  - **Feita quando**: as três contagens são idênticas antes e depois; nenhum valor de
    campo é duplicado
  - **Teste**: `test/the_band/projects/idempotency_test.exs` — 107 itens, 17 campos e
    os valores, iguais nas duas execuções. Com um quadro compartilhando issue entre
    duas organizações, a issue continua **uma** — edge case 4

- [ ] T040 [US2] Tela de quadros e backlogs
  - **Pronta quando**: T033, T034, T035 e T039 concluídas; `contracts/screens.md` escrito
  - **Descrição**: LiveView em `lib/the_band_web/live/project_live/index.ex`. Mostrar
    `quadro · não é um projeto` ao lado do nome, os campos interpretados e não
    interpretados, e **a ausência de campo de importância por extenso** — FR-026.
    Iteração futura aparece como *planejada, ainda não ocorrida*, nunca como sprint
  - **Feita quando**: o HTML não contém `projeto Scrum`; a frase sobre a ausência de
    importância aparece; iteração futura não aparece sob o rótulo sprint
  - **Teste**: `test/the_band_web/live/project_live_test.exs` — pela violação:
    `refute html =~ "projeto Scrum"`, `assert html =~ "não é derivável"`, e com dois
    tenants povoados nenhum quadro de um aparece na tela do outro — FR-037

---

## Fase F6 — Mapeamento por organização (US3, P2)

**Objetivo da história**: quem conecta uma organização configura, na mesma tela, como
os conceitos dela correspondem aos da ontologia.

**Teste independente**: conectar uma organização que usa `Feature`, `Task` e `Bug`, e
conferir que os três aparecem com destino sugerido, que `Epic` e `User Story` aparecem
como não usados aqui, e que a primeira coleta já classifica pelo configurado.

**Fora do sprint 004**, com o custo declarado: a regra fica em YAML, e ajustá-la exige
editar o repositório.

- [ ] T041 [US3] Migrar o mapeamento por organização
  - **Pronta quando**: T031 concluída; `contracts/screens.md` escrito
  - **Descrição**: migração criando `tool_concept_mappings` com `connected_tool_id`
    como escopo — **não** `tenant_id` sozinho —, `kind`, `source_name`,
    `source_external_id`, `target_concept`, `decided_by` e `declared_by_user_id`
    **não anulável**. FR-041a. Índice único por
    `(connected_tool_id, kind, source_name)`: duas organizações mapeiam o mesmo nome
    para conceitos diferentes sem colidir
  - **Feita quando**: duas ferramentas do mesmo tenant gravam `Feature` com destinos
    diferentes, e nenhuma sobrescreve a outra; `declared_by_user_id` nulo é recusado
    pelo banco
  - **Teste**: `mix ecto.migrate` e rollback; e inserir dois mapeamentos de `Feature`
    para ferramentas diferentes tem de passar, e para a mesma ferramenta tem de violar
    o índice

- [ ] T042 [US3] Descobrir os tipos da organização
  - **Pronta quando**: T043 concluída
  - **Descrição**: consulta que lista os tipos de issue **em uso** naquela
    organização, chamada depois de a credencial ser validada — FR-041. Antes da
    validação não há como consultar, e a tela exibiria campos vazios
  - **Feita quando**: a consulta devolve `Feature`, `Task` e `Bug` para
    `The-Band-Solution`, com a contagem de cada um; um tipo previsto pela regra global
    e ausente na organização vem marcado como não usado
  - **Teste**: `test/the_band/sources/type_discovery_test.exs` — com o payload real,
    os três tipos usados e os dois não usados aparecem separados

- [ ] T043 [US3] Gravar o mapeamento, recusando o inválido
  - **Pronta quando**: T044 concluída
  - **Descrição**: `record_concept_mapping/3` em `TheBand.Sources`. **Recusa** três
    coisas, nomeando a causa: campo de seleção única para atributo numérico (FR-046),
    declaração que contraria axioma (FR-045), e criação de tipo na organização.
    Precedência: regra global, regra do tenant, configuração da ferramenta — FR-049
  - **Feita quando**: `Priority → importance` é recusado explicando a diferença de
    escala; `Chore → sro.epic` é recusado nomeando `sro.rule05`; um mapeamento válido
    grava com autor e data
  - **Teste**: `test/the_band/sources/concept_mapping_test.exs` — as duas recusas pela
    violação, e a mensagem de cada uma contendo a causa e não só "inválido"

- [ ] T044 [US3] Mapeamento no fluxo de conexão
  - **Pronta quando**: T045 concluída
  - **Descrição**: passo novo em `lib/the_band_web/live/source_live/`, **depois** da
    credencial e antes de confirmar. Mostra os tipos descobertos, o destino sugerido,
    e para `Feature` que **a estrutura decide**. "Usar o padrão" é saída legítima —
    conectar não é bloqueado por mapeamento pendente (FR-041c). A mesma tela é
    acessível depois, pela ferramenta (FR-041b)
  - **Feita quando**: conectar sem configurar funciona e usa o padrão; `Epic` e
    `User Story` aparecem como não usados aqui, não como erro; a tela é alcançável
    pela ferramenta já conectada
  - **Teste**: `test/the_band_web/live/source_live_mapping_test.exs` — o HTML contém
    `não usados aqui`, e conectar com "usar o padrão" grava a ferramenta sem nenhuma
    linha de mapeamento

---

## Fase F5 — Fechamento

- [ ] T045 Executar o quickstart no dado real
  - **Pronta quando**: as fases do MVP concluídas — T001 a T029
  - **Descrição**: rodar V1 a V12 de [quickstart.md](quickstart.md) contra o banco de
    desenvolvimento e a organização real, registrando cada número obtido ao lado do
    esperado. **V4 e V7 são as que não podem passar por acidente**. Registrar também
    quantas linhas `refused_links` tem: o plano declarou o padrão P2 como **previsão**,
    com o critério de reversão escrito — vazia depois de duas coletas reais em todos os
    tenants, o registro vira contagem no relatório em vez de tabela
  - **Feita quando**: cada verificação tem o número medido registrado; qualquer
    divergência está explicada ou corrigida, nunca omitida
  - **Teste**: o próprio quickstart, com a saída colada no `sprint-review.md` — e a
    aplicação no ar mostrando as duas telas

- [ ] T046 Abrir o PR com a tabela de mapeamentos
  - **Pronta quando**: T037 concluída; `mix gates` verde
  - **Descrição**: PR com a tabela origem→conceito de cada mapeamento novo, as
    limitações declaradas, e o que **não** foi promovido com o motivo. Revisor: a
    equipe `the-band`. A lacuna de aprovação registrada é declarada, nunca marcada
    como cumprida
  - **Feita quando**: o PR nasce com revisor pedido; o corpo lista os nove gates com
    o resultado; a lacuna de aprovação está declarada
  - **Teste**: `mix gates` verde localmente e no CI, e `gh pr view` mostrando o
    revisor de equipe pedido

---

## Dependências entre fases

```
F0 ─▶ F1 ─▶ F2 ─▶ F3 ─▶ F5
                   │
                   ├▶ F4 ─▶ F5
                   │
                   └▶ F6 ─▶ F5     mapeamento por organização
```

**F6 depende de F3 e não o contrário**, e é uma escolha discutível registrada como
tal: configurar o mapeamento antes de coletar seria a ordem ideal, e é o que a tela
faz em produção. Mas construir a tela antes de haver promoção deixaria a configuração
sem efeito observável — e a L21 diz que função sem consumidor não é entrega. F3
primeiro dá à F6 um efeito que se pode medir na coleta seguinte.

**F0 bloqueia tudo**: sem a tabela do kind referenciado, o repositório não existe.
**F2 bloqueia F3**: a issue pertence a um repositório, e o escopo da ausência é ele.
**F3 bloqueia F4**: um item de quadro aponta para uma issue.

## Paralelismo

| Podem ir juntas | Por quê |
|---|---|
| T003, T004, T005 | arquivos diferentes, só dependem de T001 |
| T013, T014, T015 | três migrações independentes, depois de T009 |
| T024, T025 | ramos distintos do mesmo comando |
| T033, T034 | tabelas diferentes, depois de T031 |
| T044, T045 | descoberta e gravação são módulos distintos |

## Estratégia de entrega

**MVP: F0, F1, F2 e F3 — T001 a T029.** Ao fim dele existe uma tela que mostra as
issues classificadas e as lacunas, com a promoção rastreável até a regra e a versão.

**F4 depois, e não junto**: um sprint sem issues não responde nada. A dependência é
nessa direção, e inverter produziria quadros com backlogs vazios.

**F6 depois de F3**, pelo mesmo tipo de razão: a configuração do mapeamento precisa de
um efeito observável, e o efeito é a classificação da coleta seguinte.

**F5 fecha**: o quickstart no dado real é o que separa "os testes passam" de "a
plataforma faz o que a spec disse".

---

## O que a análise achou, e onde entrou

`/speckit-analyze` rodou sobre as 34 tarefas iniciais e achou **duas lacunas
críticas e onze menores**. As correções estão nas tarefas acima; a tabela registra o
que faltava, porque uma lacuna corrigida sem registro reaparece na feature seguinte.

| Achado | O que faltava | Onde entrou |
|---|---|---|
| **C1** | **a divergência nunca era gravada** — T017 gravava a promoção, T023 derivava a classificação, e a tela leria `divergence_reason` que ninguém preenchia | T018, nova |
| **C2** | relatório por repositório de encontradas / promovidas / não promovidas (FR-011); `syncs` só tinha contadores globais | T019, nova |
| **H1** | reclassificação entre coletas (FR-019, edge case 12) | T020, nova |
| **H2** | transição pretendida→sprint (FR-030a) e iteração removida (FR-031, edge case 8) | T036 e T037, novas |
| **H3** | `projects_available?/2` declarado no contrato e sem tarefa (FR-040) | T038, nova |
| **H4** | idempotência de projeto, itens e valores de campo (SC-002) | T039, nova |
| **H5** | preservação do payload bruto de issue não era afirmada por nenhuma tarefa (FR-007) | T006, estendida |
| **M1** | `sro.rule06` — nenhuma folha é épico (SC-006) | T023, estendida |
| **M2** | issue movida entre repositórios (edge case 2) | T016, estendida |
| **M3** | quadros de duas organizações compartilhando issue (edge case 4) | T039, incluída |
| **M4** | isolamento nas telas de quadro (FR-037) | T040, estendida |
| **M5** | cinco funções de consulta do contrato sem tarefa que as implemente | T021, nova |
| **M6** | item ligado sem duplicar (FR-021) e rascunho não promovido (FR-022) | T032, estendida |
| **L1** | o critério de reversão de P2 não era verificado em lugar nenhum | T041, nota |

**Cobertura depois das correções: 59 de 59 requisitos citados por ao menos uma
tarefa** — 44 FR e 15 SC.

**A C1 é a que valia a análise inteira.** Ela não apareceria em teste de unidade: cada
peça funcionaria, e a tela mostraria zero divergências num dado real que tem seis. O
defeito só apareceria quando alguém confiasse no número.
