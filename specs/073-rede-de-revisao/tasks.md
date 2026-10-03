# Tasks: Rede de revisão

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md), [seguranca.md](seguranca.md)

**Épico**: [#1182](https://github.com/The-Band-Solution/theband/issues/1182)

**Duas esperas que este arquivo respeita, e não contorna**:

- **a base**: os YAMLs vêm de [`proposta-base/`](proposta-base/), escritos por outro agente. Nada entra
  em `priv/knowledge_base/` antes da revisão semântica (T003) e da aprovação da pessoa mantenedora.
  Toda tarefa que lê k, janelas, amostra, grupo mínimo ou os estados que contam depende de T013, e
  T013 depende da base. **Nenhuma tarefa escreve esses valores no código para não esperar**;
- **a tela**: o protótipo de [`prototipo/`](prototipo/) **foi aprovado em 2026-10-03** (D1–D10; Q1 sem
  desenho da rede, Q3, Q4, Q5). As tarefas de tela não esperam mais o protótipo; esperam o backend e
  a fachada (T017), e seguem `prototipo/PROMPT.md` §3, versão 2, como régua (FR-017).

**Decisões de 2026-10-03 que estas tarefas já carregam**: amostra mínima de 10 **revisões** e
concentração **ausente** abaixo dela; grupos e exclusões pelo recorte (Q4, Q5, bot inclusive); conta
apagada é *sem pessoa ligada* (T030); grupo mínimo 3, declarado e não lido nesta fatia; a linha de
coleta mais nova que a leitura (Q3).

O que **não** espera nenhuma das duas: a migração, as leituras pelas fronteiras, a matemática pura,
o recorte e a leitura com os parâmetros recebidos como argumento, as conferências do job e a remoção
de `Quality.by_reviewer/2`. A fachada é que liga essas peças aos parâmetros da base (T017).

**Cenários de ataque**: A1–A18 de [seguranca.md](seguranca.md#cenários-de-ataque-para-o-qa), cada um
no `Teste` da tarefa que fecha o achado. A9 não se aplica: a decisão de 2026-10-03 (R6) tirou o
recálculo pedido pela tela, e o que a A9 guardava passa a ser guardado por T020 (a camada web não
enfileira). Regra de todos: **a guarda é vista reprovando** com o defeito injetado, com cópia do
arquivo antes de injetar e `diff` depois de restaurar.

**Tarefas humanas** são marcadas **👤 pessoa mantenedora**.

**Andamento em 2026-10-03** (sprint 037): **feitas** T001, T003–T021, T023–T030 menos T022, cada
uma com o defeito injetado visto reprovando (a evidência está na issue). T003 foi a revisão do
agente semântico (`revisao-semantica.md`, aprovada com emendas). **Abertas**: T002 e T022, da
pessoa mantenedora (medir em produção; aceitar contra a origem). Desvios da execução, todos
registrados no contrato: a unicidade do job é `:incomplete`; tirar **um** filtro de tenant de
`review_pairs/3` não reprova nada (a igualdade do join segura o outro); o aviso de leitura pronta é
emitido por `ReviewNetwork.compute/3`, e não pelo job; T028 já existia como #1185.

## Fase 1: Setup

- [x] T001 Integrar `development`, com a #1181
  - **Pronta quando**: PR #1183 mergeado em `development`
  - **Descrição**: `git merge --no-ff origin/development` na branch (merge, e não rebase: a branch já
    está no remoto). Traz `2535f6d`, `pessoas_alcancadas/2` comparando o tenant antes de `:todas`
    (R11). Plano, passo 1.
  - **Feita quando**: `git merge-base --is-ancestor 2535f6d HEAD` sai com `0`; o merge está na branch
    com a mensagem dizendo o que trouxe
  - **Teste**: `test/the_band/tenants/pessoas_alcancadas_tenant_test.exs` (o A18, que veio com a
    #1181) passa na branch. **Defeito a injetar**: tirar `user.tenant_id == tenant.id` da cláusula de
    `:todas` em `lib/the_band/tenants/access.ex`; o teste reprova

- [ ] T002 Medir o volume de 180 dias na maior organização de produção 👤 pessoa mantenedora
  - **Pronta quando**: nada; precisa só de acesso de leitura à produção
  - **Descrição**: contar, na maior organização observada de produção, os pares (revisor,
    solicitação) com avaliação enviada nos últimos 180 dias, os revisores distintos e o tempo da
    consulta de `Quality.review_pairs/3`. **Só agregados**: nenhum nome, login ou id sai da consulta.
    Escrever os números em `research.md` R10, ao lado dos de desenvolvimento (R6 da segurança)
  - **Feita quando**: `research.md` R10 tem o número de produção, a data e quem mediu; se passar de
    dez vezes o de desenvolvimento, o plano é reaberto antes do merge da US1
  - **Teste**: a revisão do PR compara o número escrito com a consulta registrada na issue

## Fase 2: Fundação

- [x] T003 Revisar a semântica da proposta da base — agente de ontologia e integração semântica
  - **Pronta quando**: `proposta-base/` com as quatro decisões da pessoa mantenedora de 2026-10-03
    registradas no README dela e as cinco medidas novas que o protótipo pede
    (`review.network.reviews.count`, `.reviewers.count`, `.authors_reviewed.count`,
    `.people_without_activity.count`, `.excluded.count`)
  - **Descrição**: revisão pelo agente semântico (que pode bloquear, §13), e não por quem escreveu a
    proposta. Decidir, por escrito, as questões que o plano deixou para a revisão semântica (§8):
    - a aresta como `mapping:` (como a proposta a escreve, `mappings/github/qapo/review_edge.yaml`)
      ou como `derivation_rule:` (D10, research.md R11);
    - a unidade "par (revisor, solicitação)" (R2), e a limitação *"uma solicitação com dois revisores
      conta duas revisões"* na medida de concentração;
    - `version` opcional no schema de medida (FR-011);
    - os **estados que contam** como lista legível pela máquina (na proposta estão em texto livre,
      em `review_edge.yaml`, `attributes...derived_from`), sem o que `Parameters` não tem de onde
      lê-los.

    Registrar o vencedor em `research.md` R11 e corrigir `data-model.md` §3 com os **nomes de chave**
    da proposta aceita (a proposta usa uma regra só, `review.network.parameters`, com
    `window_days.values.allowed`/`default`, e não as duas do plano)
  - **Feita quando**: as três decisões estão escritas com data e quem decidiu; `data-model.md` §3 e
    `contracts/review-network.md` usam os nomes de chave aceitos
  - **Teste**: `/speckit-analyze` não reporta divergência entre a proposta aceita, o modelo e o
    contrato

- [x] T004 Levar os YAMLs aceitos para a base
  - **Pronta quando**: T003
  - **Descrição**: copiar de `proposta-base/` para `priv/knowledge_base/` os arquivos da tabela do
    `README.md` da proposta; acrescentar `version` opcional (inteiro ≥ 1) a
    `priv/knowledge_base/schemas/measurement.schema.yaml` se T003 decidiu assim; acrescentar ao
    `mix knowledge.test` a conferência das chaves obrigatórias da regra de parâmetros e da aresta
    (data-model.md §3). FR-005 a FR-008
  - **Feita quando**: `mix knowledge.validate`, `mix knowledge.graph` e `mix knowledge.test` saem com
    `0`; as quatro medidas respondem a `review.concentration`; cada medida tem as quatro
    interpretações incorretas mínimas da FR-007
  - **Teste**: os três comandos, códigos de saída lidos sem pipe. **Defeito a injetar**: apagar
    `minimum_sample` (ou o nome aceito) da regra; `mix knowledge.test` reprova

- [x] T005 Criar a tabela da leitura vigente
  - **Pronta quando**: `data-model.md` §1
  - **Descrição**: `priv/repo/migrations/<ts>_create_review_network_readings.exs`, `change/0`:
    - `review_network_readings` com as colunas de data-model.md §1.1, `tenant_id` com
      `on_delete: :delete_all`, FK composta `(organization_id, tenant_id)` →
      `eo_organizations(id, tenant_id)`;
    - `unique_index(:eo_organizations, [:id, :tenant_id])`, só para a FK composta;
    - `unique_index [:tenant_id, :organization_id, :window_days]` (uma vigente, R7);
    - os dois `check` (contagens ≥ 0; `window_end > window_start`) e `window_days > 0`;
    - `index(:collected_artifact_evaluations, [:tenant_id, :external_submitted_at])` (D8, R10).
  - **Feita quando**: migrar, desfazer e migrar de novo saem com `0`; uma linha com organização de
    T1 e `tenant_id` de T2 é recusada pelo banco; uma segunda linha da mesma
    `(tenant, organização, janela)` é recusada
  - **Teste**: o ida e volta com `MIX_TEST_PARTITION=73`; e
    `test/the_band/review_network/reading_constraints_test.exs` com os dois `assert_raise` (FK
    composta, índice único). **Defeito a injetar**: FK simples em `organization_id`; o teste da FK
    composta reprova

- [x] T006 [P] Dar a EO as três leituras que a rede pede
  - **Pronta quando**: `contracts/fronteiras.md`, seção EO
  - **Descrição**: em `lib/the_band/ontology/seon/eo/queries.ex`, delegadas em `eo.ex`:
    - `fetch_organization/2`, por id **e** tenant, id malformado é `{:error, :not_found}` (R4);
    - `account_types/2`, `%{person_id => "person" | "bot" | "app"}`, `p.tenant_id` filtrado;
    - `organization_person_ids/2`, as pessoas `person` da organização, pelo caminho de
      `filter_organization/2`.
  - **Feita quando**: organização de outro tenant e id malformado devolvem `{:error, :not_found}`;
    id de pessoa de outro tenant não aparece em `account_types/2`; `organization_person_ids/2` não
    devolve pessoa só de outra organização nem bot
  - **Teste**: `test/the_band/ontology/seon/eo/review_network_reads_test.exs`, dois tenants e duas
    organizações. **Defeito a injetar**: tirar o filtro de tenant de `fetch_organization/2`; o caso de
    organização de outro tenant reprova

- [x] T007 [P] Filtrar os repositórios observados por organização
  - **Pronta quando**: `contracts/fronteiras.md`, seção CMPO
  - **Descrição**: opção `organization_id:` em `CMPO.list_observed/2`
    (`lib/the_band/ontology/seon/cmpo/queries.ex`), filtrando `r.organization_id` no banco (§7.2)
  - **Feita quando**: com `organization_id: a`, nenhum repositório de B volta; sem a opção, o
    resultado é o de hoje
  - **Teste**: `test/the_band/ontology/seon/cmpo/list_observed_organization_test.exs`. **Defeito a
    injetar**: ignorar a opção; o caso de B reprova

- [x] T008 [P] Ler os pares revisor–solicitação da janela, com tenant nas duas pontas
  - **Pronta quando**: `contracts/fronteiras.md`, seção `Quality.review_pairs/3`
  - **Descrição**: `Quality.review_pairs/3` em `lib/the_band/quality.ex`, uma consulta agrupada por
    (conta revisora, solicitação) com `max(external_submitted_at)`; `a.tenant_id` **e** `c.tenant_id`
    no `where`, e `a.tenant_id == c.tenant_id` no join; lista de estados **de inclusão** recebida do
    chamador; `external_submitted_at` não nulo e `>= since`; `no_longer_observed_at` nulo nos dois
    lados; lista de repositórios vazia devolve `[]` sem consultar. R3, R4, R12 da segurança
  - **Feita quando**: avaliação de T2 apontando para solicitação de T1 não entra (A2); nada de T2
    entra na leitura de T1 (A1); avaliação com estado fora da lista e pendente (sem envio) não entram;
    três avaliações da mesma conta na mesma solicitação são **um** par
  - **Teste**: `test/the_band/quality/review_pairs_test.exs`, com `assert` de que mediu antes de cada
    `refute`. **Defeitos a injetar**, um por vez: tirar `a.tenant_id` do `where` e do join (A2
    reprova); tirar `c.tenant_id` do `where` e do join (A1 reprova). Cada filtro sozinho é
    redundante com a igualdade do join, e o contrato diz isso

- [x] T009 [P] Ler quem abriu solicitação na janela
  - **Pronta quando**: `contracts/fronteiras.md`, seção `Changes.change_request_authors/3`
  - **Descrição**: `Changes.change_request_authors/3` em `lib/the_band/changes.ex`: autores com
    pessoa ligada, `c.tenant_id` filtrado, `no_longer_observed_at` nulo, `external_created_at >=
    since`, agrupados por pessoa com `max(external_created_at)`. Não expõe quais solicitações
  - **Feita quando**: o autor sem revisão aparece (é o Caio da US2); autor de T2 não aparece em T1;
    autor sem pessoa ligada não aparece
  - **Teste**: `test/the_band/changes/change_request_authors_test.exs`. **Defeito a injetar**: tirar o
    filtro de tenant; o caso de T2 reprova

- [x] T010 Remover o ranking de revisores sem alcance
  - **Pronta quando**: nada; **em commit próprio** (research.md R13)
  - **Descrição**: apagar `Quality.by_reviewer/2` de `lib/the_band/quality.ex` e os testes dela em
    `test/the_band/quality_test.exs`. O isolamento entre tenants que um deles provava passa a T008
    (A1, A2). R12 da segurança, FR-018a
  - **Feita quando**: `grep -rn by_reviewer lib test` não encontra nada; a suíte de `Quality` passa
  - **Teste**: `mix compile --warnings-as-errors` e `mix test test/the_band/quality_test.exs`, com o
    código de saída. O teste que guarda é T008, que prova o isolamento na consulta nova

- [x] T011 [P] Classificar cada par num destino só
  - **Pronta quando**: data-model.md §2.1; research.md R3
  - **Descrição**: `lib/the_band/review_network/classification.ex`, puro. Recebe os pares de T008 e o
    mapa de `EO.account_types/2`; devolve `{:aresta, revisor, autor} | :self_review |
    :bot_or_app | :unlinked_person`, nesta ordem: bot ou aplicativo (pessoa ligada pelo
    `account_type`; conta não ligada por `Mapper.account_type/1`, **chamado e nunca reimplementado**)
    → não ligada (inclusive a conta apagada, `author` nulo) → auto-revisão → aresta. Pessoa ligada
    ausente do mapa (outro tenant) é **não ligada**. Os logins não saem do módulo. R9 da segurança
  - **Feita quando**: conta `User` ligada a pessoa `bot` vira bot e não nó (A14); conta apagada vira
    não ligada e não bot; cada par cai em exatamente um destino
  - **Teste**: `test/the_band/review_network/classification_test.exs`. **Defeito a injetar**: decidir
    bot por `reviewer_type == "Bot"` (o filtro de `Quality`); A14 reprova

- [x] T012 [P] Calcular arestas, totais, grupos e concentração em Elixir puro
  - **Pronta quando**: `contracts/review-network.md`, seção `Graph`; research.md R2 e R5
  - **Descrição**: `lib/the_band/review_network/graph.ex`, sem `Repo`, relógio nem `Logger`:
    `build/2` (arestas por frequência de `{revisor, autor}` dos pares da janela, e as solicitações
    revisadas de cada autor), `totals_by_person/1`, `groups/1` (componentes
    fracos por busca em largura, só nós com aresta, ordenados por tamanho e menor id),
    `concentration/2` (k recebidos como argumento, prefixos de soma, `:no_review_in_window` quando o total é
    zero) e `induced/2`. Toda saída ordenada (FR-012)
  - **Feita quando**: as frações são crescentes em k e nunca passam do total; total zero é
    `:no_review_in_window`, e não 0; k maior que o número de revisores não inventa revisor; dois grupos sem
    aresta entre eles dão dois tamanhos; a mesma entrada embaralhada dá a mesma saída
  - **Teste**: `test/the_band/review_network/graph_test.exs`, com o cenário 1 da US1 (30 de 40 →
    `%{k: 1, reviews: 30, of: 40}`) e a entrada embaralhada dez vezes. **Defeito a injetar**: devolver
    `0` no lugar de `:no_review_in_window`; o caso de rede vazia reprova

- [x] T013 Ler os parâmetros da base, e levantar se faltar
  - **Pronta quando**: T004 (os YAMLs estão em `priv/knowledge_base/`)
  - **Descrição**: `lib/the_band/review_network/parameters.ex` lê, pelo `KnowledgeBase`, a regra de
    parâmetros e a da aresta, com os nomes de chave aceitos em T003: janelas e padrão, k, amostra
    mínima, grupo mínimo, estados que contam, versões. Valida (inteiros positivos, k crescente,
    padrão dentro da lista) e **levanta** se faltar chave (princípio IV; precedente
    `quality.ex:305-310`). Nenhum valor de reserva no código
  - **Feita quando**: com a base real, devolve os valores da regra; com a regra sem uma chave, levanta
    dizendo qual
  - **Teste**: `test/the_band/review_network/parameters_test.exs` sobre a função pura de validação, um
    caso por chave. **Defeito a injetar**: `Map.get(regra, "k", [1, 2, 3])`; o caso sem k reprova

## Fase 3: US1 — ver se a revisão está concentrada (P1) 🎯 MVP

**Objetivo**: quem coordena lê o total, os revisores e a concentração das k primeiras, sem nome,
recortada pelo alcance, numa janela de 30, 90 ou 180 dias.

**Teste independente**: com revisões coletadas de uma organização, a tela mostra total, revisores e
concentração, e os números batem com a contagem manual (SC-001).

- [x] T014 [US1] Substituir as três leituras da organização numa transação
  - **Pronta quando**: T005, T006, T007, T008, T009, T011, T012
  - **Descrição**: `lib/the_band/review_network/schemas/reading.ex` (privado) e
    `lib/the_band/review_network/commands.ex`. `Commands.compute/4` recebe `(tenant, organização,
    now, parâmetros)`: lê os repositórios da organização (T007, sem os `excluded_at`), os pares da
    maior janela uma vez (T008), os autores (T009) e os tipos de conta (T006); classifica (T011);
    para cada janela filtra por `last_submitted_at >= window_start`, calcula pelo `Graph` e **apaga e
    insere** as linhas da organização numa transação. Grava só ids de pessoa, nunca nome nem login.
    Devolve o relator `{:ok, %{readings: [...]}}` com contagens, sem pares. FR-011, FR-012, R3, R7
  - **Feita quando**: rodar duas vezes deixa **uma** linha por janela, com ids novos (A12); o JSON da
    leitura não tem nome nem login (A12); pares da janela = revisões na rede + as três exclusões
    (invariante); o mesmo `now` dez vezes dá dez leituras iguais, exceto `id` e `inserted_at`
    (SC-005); falha no meio não deixa leitura parcial
  - **Teste**: `test/the_band/review_network/commands_test.exs`, com parâmetros explícitos e dois
    tenants. **Defeitos a injetar**, um por vez: inserir sem apagar (A12 reprova pelo índice único ou
    pela contagem); gravar `name` em `people` (A12 reprova); contar a auto-revisão como aresta (o
    invariante reprova)

- [x] T015 [US1] Recortar a concentração e as exclusões pelo alcance
  - **Pronta quando**: T012
  - **Descrição**: `lib/the_band/review_network/slice.ex`, puro. Recebe a leitura, o alcance
    (`:todas` ou `{:algumas, MapSet}`) e os parâmetros; devolve a `view()` sem nomes:
    - revisões, revisores, pessoas revisadas (`authors`, D10) e concentração sobre o **subgrafo
      induzido** pelas pessoas alcançadas (R1);
    - `{:ausente, :no_review_in_window}` quando o recorte não tem revisão;
      `{:ausente, {:sample_below_minimum, m}}` abaixo de `m` **revisões** do recorte (decidido em
      2026-10-03); `{:ausente, :fewer_reviewers_than_k}` no k maior que o número de revisores;
    - exclusões, as três, só com `:todas`; com alcance parcial, `{:recortado, :regra}` (R12, Q5);
    - **nenhum** número sobre o que ficou fora do alcance (R2).
  - **Feita quando**: com Ana fora do alcance, a concentração não conta as revisões dela nem carrega
    id de ninguém; com 9 revisões no recorte a concentração é ausente e as contagens aparecem; com 2
    revisores, k = 3 é ausente e não 100%; a `view()` de alcance parcial não tem campo que conte revisões fora (A7); com
    `:todas`, os números são os da rede inteira
  - **Teste**: `test/the_band/review_network/slice_test.exs`. **Defeitos a injetar**: calcular a
    concentração sobre a rede inteira (o caso de Ana reprova); acrescentar `outside_reach_reviews` à
    view (A7 reprova)

- [x] T016 [US1] Ler a rede de uma organização com o alcance recalculado a cada leitura
  - **Pronta quando**: T006, T014, T015; `development` com a #1181 (T001)
  - **Descrição**: `lib/the_band/review_network/queries.ex` (a leitura vigente por tenant,
    organização e janela) e `Reader.read/5` em `lib/the_band/review_network/reader.ex`, que recebe os
    parâmetros explícitos: (1) janela contra a lista fechada, aceitando o inteiro ou o texto decimal
    exato, nunca `String.to_atom/1`; (2) `EO.fetch_organization/2`; (3) a leitura vigente;
    (4) `Tenants.pessoas_alcancadas/2` **nesta chamada**; (5) o recorte (T015) e os nomes por
    `EO.people_names/2`; (6) `newer_collection`, pelo maior `changes_collected_at` dos repositórios
    observados da organização contra `computed_at` (Q3, research.md R14). Número fixo de consultas. FR-013, FR-015, R3, R10
  - **Feita quando**: `"36500"`, `"-1"`, `"90; drop"`, `"abc"` e `nil` devolvem
    `{:error, :janela_invalida}` sem átomo novo (A8); organização de outro tenant e inexistente
    devolvem o mesmo `{:error, :not_found}` (A3); sem leitura, `{:ausente, :not_computed}`; a conta
    que perde o vínculo deixa de ver os colegas na leitura seguinte (A13); com 5 e com 50 pessoas, o
    mesmo número de consultas; um repositório da organização com corte de coleta posterior ao cálculo
    dá `newer_collection: {:em, _}`, e um de outra organização não
  - **Teste**: `test/the_band/review_network/read_test.exs`, dois tenants e duas organizações.
    **Defeitos a injetar**: trocar a lista fechada por `String.to_integer/1` (A8 reprova); receber o
    alcance como argumento em vez de calculá-lo (A13 reprova); buscar a organização só por id (A3
    reprova)

- [x] T017 [US1] Ligar a fachada aos parâmetros da base
  - **Pronta quando**: T013, T014, T016
  - **Descrição**: `lib/the_band/review_network.ex`, só `defdelegate` para funções que injetam
    `Parameters`: `compute/3`, `read/4`, `windows/0`, `subscribe/1`. Corrigir
    `contracts/review-network.md` se a forma mudar
  - **Feita quando**: a fachada não tem lógica; `read/4` e `compute/3` usam os valores da base, e
    nenhum valor de janela, k ou mínimo aparece no código de `lib/`
  - **Teste**: `test/the_band/review_network/facade_test.exs`: `windows/0` devolve o que a regra diz;
    uma busca no código de `lib/the_band/review_network/` por literais `[30, 90, 180]` e `[1, 2, 3]`
    não acha nada. **Defeito a injetar**: escrever `@windows [30, 90, 180]` no módulo; o teste reprova

- [x] T018 [US1] Conferir tenant e organização antes de calcular, e cancelar sem gravar
  - **Pronta quando**: `contracts/job.md`; T006
  - **Descrição**: `lib/the_band/jobs/compute_review_network.ex`, fila `:transformation`,
    `max_attempts: 3`, unicidade por `(tenant_id, organization_id)` em `available`, `scheduled` e
    `retryable`, `period: :infinity`. `perform/1` lê só `tenant_id` e `organization_id`, nesta ordem:
    `Tenants.fetch/1` → `{:cancel, :tenant_not_found}`; `Tenants.ensure_active/1` →
    `{:cancel, :tenant_inactive}`; `EO.fetch_organization/2` → `{:cancel, :organization_not_found}`.
    Só então chama `ReviewNetwork.compute/3`. FR-010, R4, R6
  - **Feita quando**: tenant suspenso, organização de outro tenant e organização inexistente cancelam
    com o motivo, e **nenhuma** linha é gravada (A10); dois `enqueue/2` seguidos da mesma organização
    deixam um job só; argumento a mais (janela) é ignorado
  - **Teste**: `test/the_band/jobs/compute_review_network_test.exs`, casos de cancelamento.
    **Defeito a injetar**: trocar o cancelamento por organização não encontrada por um cálculo com
    lista vazia; A10 reprova

- [x] T019 [US1] Registrar e avisar o cálculo sem par, nome nem login
  - **Pronta quando**: T017, T018
  - **Descrição**: no caminho feliz do job: `Logger.info` por janela com organização, janela,
    contagens e duração (FR-021); `Phoenix.PubSub.broadcast` de
    `{:review_network_ready, organization_id, reading_ids}` em `"review_network:" <> tenant_id`,
    depois do commit (R3, item 2). O controle positivo da A10: o caminho feliz grava as três janelas
  - **Feita quando**: o caminho feliz grava três linhas; o log, capturado em `:debug` com nomes de
    teste óbvios, não tem nome, login, par nem `person_id` (A16); a mensagem recebida pelo assinante
    tem só ids de leitura (A11)
  - **Teste**: `compute_review_network_test.exs`, casos de sucesso. **Defeitos a injetar**: logar a
    aresta (A16 reprova); transmitir o relator inteiro, como `recompute_promotions.ex:57` (A11 reprova)

- [x] T020 [US1] Disparar o cálculo ao fim da coleta de revisões
  - **Pronta quando**: T019 (disparar antes de o caminho feliz existir enfileiraria, a cada
    sincronização, um job que só levanta)
  - **Descrição**: `lib/the_band/jobs/sync_github_eo.ex`: o `ctx` de `coletar_trabalho/1` ganha
    `organization_id`; `coletar_mudancas/1` chama `ComputeReviewNetwork.enqueue/2` depois de
    `GithubChangeRequests.collect/1` devolver `{:ok, _}`, com o acoplamento escrito ao lado (D6, R8).
    Um teste lê `lib/the_band_web/` e reprova se `ComputeReviewNetwork` aparecer (decisão R6)
  - **Feita quando**: uma sincronização com etapa `:mudancas` bem-sucedida deixa um job da organização
    enfileirado; uma etapa que falha não enfileira; a camada web não enfileira
  - **Teste**: `test/the_band/jobs/sync_github_eo_review_network_test.exs` e
    `test/the_band/review_network/exposicao_test.exs` (caso web). **Defeito a injetar**: enfileirar
    antes do `collect/1`; o caso da etapa que falha reprova

- [x] T021 [US1] Mostrar a concentração, sem nome, na janela escolhida
  - **Pronta quando**: T017, T019, T020 (protótipo aprovado em 2026-10-03; `contracts/tela.md`
    corrigido pela aprovação)
  - **Descrição**: rota `live "/organizations/:id/review-network"` em `lib/the_band_web/router.ex`,
    `live_session :autenticado`; `lib/the_band_web/live/review_network_live/show.ex` chama só o que
    `contracts/tela.md` lista. Janela crua para `read/4`; `{:error, :janela_invalida}` faz
    `push_patch` para a padrão; `{:error, :not_found}` volta a `/organizations` com *"Organization not
    found."*; `<.evidence>` em todo número (FR-014); `<.absent>` em toda ausência; o aviso de recorte
    descreve `pessoas_alcancadas/2` como ela é, sem a frase da liderança declarada; mobile-first
    (FR-016); inglês na tela, com comentário; a linha de coleta mais nova que a leitura (Q3);
    concentração ausente abaixo da amostra e no k maior que os revisores; nenhum desenho da rede, e
    as telas 6 e 7 do protótipo **não** existem (Q1; o item 6.1 da régua vira defeito se aparecerem).
    Exatamente o protótipo (FR-017), `prototipo/PROMPT.md` §3 v2 como régua
  - **Feita quando**: quem administra lê *"the person who reviewed most did 75%"* sem nome; a conta de
    alcance parcial não lê o nome nem o login de Ana em lugar nenhum do HTML (A4) e não lê quantas
    revisões ficaram fora (A7); login excluído não aparece, e a contagem aparece para quem administra
    (A15); organização sem revisão diz em palavras e não mostra `0%` (US1, cenário 3); `?window=36500`
    volta a 90
  - **Teste**: `test/the_band_web/live/review_network_live/show_test.exs`. **Defeitos a injetar**:
    renderizar o nome do primeiro colocado (A4 a); filtrar na tela em vez de `read/4` (A4 b);
    renderizar a contagem de fora (A7); listar logins excluídos (A15)

- [ ] T022 [US1] Aceitar a US1 contra a origem 👤 pessoa mantenedora
  - **Pronta quando**: T002, T021; release com a 073 no ar
  - **Descrição**: SC-001 (contagem manual da janela de 90 dias nas tabelas, só agregados, contra a
    tela de quem administra), SC-003 (cronometrado), SC-004 (dois tenants, duas organizações, uma
    conta de alcance restrito). quickstart.md §5 e §6
  - **Feita quando**: as contagens batem sem diferença; a resposta sai em menos de um minuto; a conta
    restrita não lê nome de fora nem a contagem de fora
  - **Teste**: o registro de aceitação na issue da US1, com as consultas e os números

## Fase 4: US2 — ver quem revisa quem (P2)

**Objetivo**: por pessoa alcançada, revisões feitas e recebidas, e os pares, ordenados por nome.

**Teste independente**: para Bia, as quatro contagens e os pares batem com as revisões da janela.

- [x] T023 [US2] Montar a lista por pessoa, ordenada por nome, com os pares recortados
  - **Pronta quando**: T015, T016
  - **Descrição**: em `Slice` e `Reader`: `people` com `given` e `received` (o total verdadeiro da
    pessoa, sobre a rede inteira, R2 item 1), `{:ausente, :did_not_review_in_window}` e
    `{:ausente, :no_change_request_reviewed_in_window}`; `reviews_of` e `reviewed_by` só com pares alcançados;
    `pairs_outside_reach?` sem número; ordenação por nome e por nada mais (FR-018a);
    `people_without_review_activity` sobre as pessoas `person` alcançadas da organização
    (`EO.organization_person_ids/2`), fora da lista
  - **Feita quando**: Bia lê `reviews: 12, people: 4` e `change_requests: 5, people: 2`; Caio tem
    `received: {:ausente, :no_change_request_reviewed_in_window}`, e não 0; o par fora do alcance não vira linha
    nem número (A5); com as medidas invertidas, a ordem continua a dos nomes
  - **Teste**: `slice_test.exs` e `read_test.exs`, casos da US2. **Defeitos a injetar**: listar o par
    de fora com nome mascarado (A5 reprova); ordenar por `given` (o caso de ordem reprova)

- [x] T024 [US2] Mostrar a lista por pessoa e os pares
  - **Pronta quando**: T021, T023
  - **Descrição**: a lista na mesma LiveView, `stacked` com `data-label` se tiver mais de três
    colunas; nenhuma coluna ordenável; a frase de que a medida não avalia pessoa **antes** da lista
    (D8); a frase *"Each row shows the person's whole count in the window; the pairs show only people
    you reach"* acima dela (FR-015);
    nenhuma exportação (FR-018b)
  - **Feita quando**: a linha de Bia mostra *"reviewed 12, of 4 people"* e *"was reviewed on 5, by 2
    people"*; Caio tem a ausência em palavras; não há controle de ordenação nem de exportação
  - **Teste**: `show_test.exs`, casos da US2. **Defeito a injetar**: `phx-click="sort"` numa coluna; o
    caso FR-018a reprova

## Fase 5: US3 — ver a forma da rede (P3)

**Objetivo**: quantos grupos não se revisam entre si, e o tamanho de cada.

**Teste independente**: dois grupos que só se revisam entre si dão *"2 groups that do not review
each other"* com os dois tamanhos.

- [x] T025 [US3] Contar os grupos só entre as pessoas que quem lê alcança
  - **Pronta quando**: T012, T015
  - **Descrição**: em `Slice`: grupos do **mesmo subgrafo induzido** da concentração
    (`Graph.groups/1` sobre `Graph.induced/2`; Q4, decidido em 2026-10-03); com `:todas`, a rede
    inteira; pessoa sem aresta não é grupo. O grupo mínimo não é lido (contrato, *Os parâmetros*)
  - **Feita quando**: com `:todas`, todos os tamanhos aparecem; com alcance parcial, um grupo de 1 e
    um de 2 de gente de fora **não aparecem**, nem no número de grupos nem em tamanho (A6, reescrito
    pela Q4); rede conexa dá um grupo só
  - **Teste**: `slice_test.exs`, casos da US3. **Defeito a injetar**: calcular os grupos sobre a rede
    inteira; A6 reprova

- [x] T026 [US3] Mostrar os grupos
  - **Pronta quando**: T021, T025
  - **Descrição**: a frase dos grupos na LiveView, sem desenho de grafo nem biblioteca JS (R13; Q1:
    a matriz fica para a fatia 2)
  - **Feita quando**: dois grupos dão *"2 groups that do not review each other"* com os tamanhos; rede
    conexa diz que todas as pessoas estão ligadas por revisão; com alcance parcial, nenhum grupo de
    gente de fora aparece
  - **Teste**: `show_test.exs`, casos da US3. **Defeito a injetar**: renderizar os grupos da rede
    inteira para alcance parcial (A6 reprova na tela)

## Fase 6: Acabamento

- [x] T027 [P] Provar que a rede não sai pela API nem pela MCP
  - **Pronta quando**: nada
  - **Descrição**: `test/the_band/review_network/exposicao_test.exs` lê as rotas de
    `TheBandWeb.Router` e o registro de ferramentas de `lib/the_band/mcp/`, e reprova se alguma rota
    `/api` ou ferramenta mencionar `ReviewNetwork` ou `review_network`. FR-020, R8
  - **Feita quando**: o teste passa hoje, e reprova se uma rota `/api/v1/review-network` aparecer
  - **Teste**: o próprio arquivo. **Defeito a injetar**: uma rota de API apontando para um controller
    `ReviewNetworkController`; o teste reprova

- [x] T028 [P] Abrir a issue do aviso de recorte que promete mais do que aplica
  - **Pronta quando**: nada
  - **Descrição**: issue `bug` + `security` sobre `lib/the_band_web/live/verification_live/people.ex`,
    cujo aviso diz *"whoever you lead by declared role"* e `pessoas_alcancadas/2` não inclui a
    liderança declarada (research.md R6, achado lateral). **Não** corrigir nesta feature (§17)
  - **Feita quando**: a issue existe, com arquivo e linha, e está ligada a este `tasks.md`
  - **Teste**: `gh issue view <n>` mostra os labels e o texto

- [x] T029 Fechar os gates, o contrato e o estado da sessão
  - **Pronta quando**: T001–T027
  - **Descrição**: `mix gates` com `MIX_TEST_PARTITION=73`, saída redirecionada e código lido;
    `contracts/` conferidos contra o código; `RETOMAR.md` atualizado; PR pelo template, com o tipo de
    merge e a equipe `the-band` como revisora
  - **Feita quando**: `mix gates` sai com `0`; `/speckit-analyze` não reporta divergência; o PR tem
    revisor pedido e está no projeto
  - **Teste**: `EXIT=0` do `mix gates`; `gh pr view <n> --json reviewRequests` não vazio

- [x] T030 [P] Contar a conta apagada como sem pessoa ligada, e não como bot, na coleta
  - **Pronta quando**: nada (decisão da pessoa mantenedora de 2026-10-03)
  - **Descrição**: `lib/the_band/ingestion/github_change_requests.ex:321` conta em `de_bot` toda
    avaliação cujo `author.__typename` não é `"User"`, e a avaliação de autor nulo (conta apagada,
    "ghost") cai ali. A rede a classifica como *sem pessoa ligada* (research.md R3; T011). Fazer a
    coleta usar a mesma regra — `Mapper.account_type/1` sobre o autor, e autor nulo fora de `de_bot`
    —, para que as duas contagens não discordem. Conferir quem lê `de_bot` antes de mudar
  - **Feita quando**: uma página com uma avaliação de bot, uma de pessoa e uma de autor nulo dá
    `de_bot: 1`; a conta de login `algo[bot]` com `__typename` `User` conta como bot, como em EO
  - **Teste**: o teste da coleta de mudanças com o payload capturado acrescido do autor nulo.
    **Defeito a injetar**: a regra de hoje (`!= "User"`); o caso do autor nulo reprova

## Dependências

- T001 → T016 (a leitura com alcance precisa da #1181).
- T003 → T004 → T013 → T017 → T019; T013 também → T022 (via T021).
- T005, T006, T007, T008, T009, T011, T012 → T014.
- T012 → T015 → T016; T006 → T016.
- T006 → T018 → T019 → T020.
- T015, T016 → T023; T012, T015 → T025.
- T017, T019, T020 → T021 → T024, T026; T002 e T021 → T022 (o protótipo foi aprovado em 2026-10-03).

**Paralelo**:
- T006, T007, T008, T009, T011 e T012, entre si (arquivos diferentes, nenhuma dependência pendente);
- T010, T027, T028 e T030, a qualquer momento;
- T015 e T018, depois das suas dependências.

**O que não espera a base**: T005–T012, T014–T016, T018, T023, T025, T027, T028, T030. É o escopo do primeiro sprint.

## Estratégia

**MVP**: a US1 inteira (T005–T022), que só fecha com a tela. O backend da US1 (T014–T020) **não** é
entrega sozinho: sem T021 nada é visível, e a memória *Vertical slice* proíbe infraestrutura sem
consumidor. Por isso nenhum PR desta feature é aberto antes de T021.

As US2 e US3 têm o backend pronto junto com a US1 (o recorte é a mesma função), e a tela de cada uma
segue a da US1.
