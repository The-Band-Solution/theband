# Tasks: Análise de rede

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/](contracts/), [quickstart.md](quickstart.md), [seguranca.md](seguranca.md),
[revisao-semantica-2.md](revisao-semantica-2.md), [prototipo/](prototipo/)

**Épico**: [#1309](https://github.com/The-Band-Solution/theband/issues/1309)

**Marcas**: `[P]` paralelizável (arquivos diferentes, sem dependência aberta); `[USn]` a user story;
`[security]` a tarefa fecha um achado de [seguranca.md](seguranca.md) ou da revisão semântica com
efeito de acesso — a issue leva o label `security`. **👤** é tarefa da pessoa mantenedora.

**Regras de todas as tarefas**:

- **contrato antes do código**: nenhuma função pública sem a assinatura em [contracts/](contracts/);
  se a implementação mostrar que o contrato errou, o contrato muda **no mesmo commit**, com a razão;
- **a guarda nasce provada**: cada `Teste` diz o defeito a injetar; ele é visto **reprovando** antes
  de a tarefa fechar. Copiar o arquivo antes de injetar, `diff` vazio depois de restaurar
  (memória *git checkout apaga trabalho não commitado*; L106: script de injeção com `set -e`);
- **evidência na issue**: o comando e o código de saída, com e sem o defeito, em comentário
  (princípio VII). O veredito é o código de saída, sem pipe (L60);
- **dois tenants** povoados em todo teste que toca isolamento; `assert` de que a medida mediu
  alguma coisa **antes** de qualquer `refute`;
- **nenhum valor da base no código**: k, janelas, semente, número de aleatórios, teto, cortes,
  tamanhos de lista e faixas vêm de `NetworkAnalysis.Parameters` (T008);
- tarefa fechada sem diff exige emenda da spec ou evidência do critério como escrito (L109).

**Cenários de ataque**: A1–A22 de [seguranca.md](seguranca.md#cenários-de-ataque-para-o-qa), cada
um no `Teste` da tarefa que fecha o achado: A1 e A2 → T023; A3 → T040; A4 e A5 → T016, T033, T037;
A6 e A7 → T032, T033; A8 → T032; A9 → T032; A10 → T047; A11 → T040, T046; A12 → T017; A13 → T020;
A14 → T013; A15 e A16 → T014; A17 → T051; A18 → T004, T014; A19 → T014; A20 → T025, T026;
A21 → T014; A22 → T017.

---

## Fase 1: Setup

- [x] T001 Integrar `development` na branch do plano
  - **Pronta quando**: nada além do repositório
  - **Descrição**: `git merge --no-ff origin/development` em `feature/1309-plano` (criada de
    `origin/feature/1309-revisao-semantica-2`, `a0dd1d1`). Conflito em `.specify/feature.json`
    resolvido para `specs/076-analise-de-rede`
  - **Feita quando**: o merge `72eb9e8` está na branch; `git merge-base --is-ancestor
    origin/development HEAD` sai com `0`
  - **Teste**: o comando acima, código de saída lido. **Defeito a injetar**: não se aplica (tarefa de
    integração); a evidência é o `merge-base`

- [ ] T002 👤 Decidir se a marca de conta da organização vale para a revisão (A7)
  - **Pronta quando**: [revisao-semantica-2.md](revisao-semantica-2.md) A7 e
    [research.md R14](research.md#r14--a-conta-da-organização-d3-a-r8-da-segurança-a7) lidos
  - **Descrição**: a pessoa mantenedora decide se a declaração de conta da organização (D3 (a)) vale
    também para a rede de revisão da 073. Opção padrão do plano: **sim** (`review.network.edge`
    versão 2). A decisão volta para a tabela de decisões de `spec.md` com data
  - **Feita quando**: a linha D3 da spec diz a decisão sobre a revisão, com data; se **não**, T027 é
    fechada como não feita, com o motivo, e T029 escreve na área que a marca não se aplica à revisão
  - **Teste**: a revisão do PR confere a linha da spec contra o comentário de decisão na issue

- [ ] T003 [security] 👤 Medir a rede de designação em produção
  - **Pronta quando**: acesso de leitura à produção; a #1190 (073/T002) aberta
  - **Descrição**: na maior organização observada de produção, contar, **só agregados**: issues
    abertas em 180 dias, designações vigentes, arestas autor → responsável entre pessoas ligadas,
    pessoas distintas, e o tempo da consulta de `WorkItems.assignment_pairs/3` (ou o SQL de
    [research.md R20](research.md#r20--volume-medido)). Junto: quantas contas não ligadas vêm sem o
    sufixo `[bot]` (A3). Escrever em `research.md` R20, ao lado do de desenvolvimento, e comentar na
    #1190
  - **Feita quando**: R20 tem o número de produção, a data e quem mediu; se passar de 300 pessoas ou
    3 000 arestas, R5 e T050 são reabertos antes do merge
  - **Teste**: a revisão do PR compara o número escrito com a consulta registrada na issue

---

## Fase 2: Fundação (bloqueia todas as user stories)

**Segurança primeiro (§14.0)**: T004 e T005 consertam defeitos conhecidos da mesma superfície e vêm
antes de tudo que toca cálculo ou alcance.

- [ ] T004 [P] [security] Gravar a leitura da 073 sem exceção que carrega pares
  - **Pronta quando**: T001; [contracts/fronteiras.md](contracts/fronteiras.md), `ReviewNetwork`
  - **Descrição**: em `lib/the_band/review_network/commands.ex`, `substituir/3` troca `Repo.insert!`
    por `Repo.insert/1`; no erro, `Repo.rollback({:reading_rejected, campos})` só com os nomes dos
    campos do changeset. `compute/3,4` devolvem `{:error, {:reading_rejected, campos}}`;
    `ComputeReviewNetwork` cancela com o motivo. Nenhum `{:ok, _} =` sobre termo com a leitura
    (seguranca.md R10; L105)
  - **Feita quando**: com a organização apagada entre a busca e a inserção, o job cancela e o erro
    gravado em `oban_jobs.errors` não contém nenhum `person_id`
  - **Teste**: `test/the_band/review_network/commands_rejeicao_test.exs` (A18): força a violação da FK
    e `refute` cada `person_id` da fixture no texto do erro (`Exception.format/3` do retorno e do
    job). **Defeito a injetar**: voltar o `Repo.insert!`; o teste reprova

- [ ] T005 [P] [security] Corrigir a frase do recorte da verificação (#1185)
  - **Pronta quando**: a DS4 decidida (a), 2026-10-04
  - **Descrição**: `lib/the_band_web/live/verification_live/people.ex:157-161` passa a dizer a regra
    de `pessoas_alcancadas/2` (o próprio registro, as pessoas das equipes em escopo, as das equipes
    das organizações em escopo, ou administrar o tenant), **sem** *"whoever you lead by declared
    role"*. Fecha a #1185 (`Closes #1185` em inglês, na descrição do PR)
  - **Feita quando**: a frase não promete a liderança declarada; um líder declarado sem escopo não vê
    a pessoa liderada na lista e a frase não diz que veria
  - **Teste**: `test/the_band_web/live/verification_live/people_recorte_test.exs`: conta com
    liderança declarada e sem escopo; `assert` da frase nova; `refute` `"declared role"`; `refute` o
    nome da pessoa liderada. **Defeito a injetar**: devolver a frase antiga; o teste reprova

- [ ] T006 Emendar a proposta da base com as decisões do plano
  - **Pronta quando**: plan.md e research.md R5, R7, R8, R16, R19 commitados
  - **Descrição**: em `specs/076-analise-de-rede/proposta-base/`, pelo agente de ontologia e
    integração semântica (que pode bloquear, §13), e não por quem escreveu o plano:
    - `network_analysis_parameters.yaml`: `size_limit` (300 / 3 000, com a razão de R5);
      `modularity_reading.values.random_weights: shuffled_real_multiset` (R8);
      `small_world.values.generator: exsss` e `.sampling` (rejeição; Fisher–Yates) (R7);
      `betweenness_color_bands` (cinco faixas de cor do protótipo, com a razão: faixa de cor, sem
      adjetivo) e `layout.values.labelled_nodes: 7` (R16);
    - `network_modularity_score.yaml`: tirar a limitação de Q_rand sem peso;
    - perguntas de competência de `network.structure`, uma por medida mostrada;
    - registrar a revisão em `revisao-semantica-2.md` (adendo) ou documento próprio
  - **Feita quando**: o agente semântico aprova por escrito, com data; a cópia de
    `priv/knowledge_base/` com a proposta sobreposta valida
  - **Teste**: `mix knowledge.validate <cópia>` e `mix knowledge.graph <cópia>` com `EXIT=0`, lidos sem
    pipe; **defeito a injetar**: trocar `answers_information_need` de uma medida por id inexistente;
    `EXIT=1`

- [ ] T007 Levar a base aceita para a base de conhecimento
  - **Pronta quando**: T006
  - **Descrição**: copiar os 24 arquivos pelo quadro de `proposta-base/README.md` e as perguntas de
    competência para `priv/knowledge_base/`; `review_network_parameters.yaml` substituído (só a
    recusa do papel sai). Ao `mix knowledge.test`, a conferência das chaves de
    `network.analysis.parameters` e de `network.position_role` (a regra não tem schema, R19)
  - **Feita quando**: `mix knowledge.validate`, `mix knowledge.graph` e `mix knowledge.test` saem com
    `0`; as 20 medidas respondem a `network.structure`
  - **Teste**: os três comandos, códigos de saída lidos. **Defeito a injetar**: apagar
    `small_world.values.seed`; `mix knowledge.test` reprova

- [ ] T008 Ler os parâmetros da análise da base
  - **Pronta quando**: T007; [contracts/network-analysis.md](contracts/network-analysis.md), *Os
    parâmetros entram pela fachada*
  - **Descrição**: `lib/the_band/network_analysis/parameters.ex`, no molde de
    `ReviewNetwork.Parameters`: `fetch!/0` e `from_rules!/3` lêem `network.analysis.parameters`,
    `network.position_role` e `assignment.network.edge`, conferem tipos e a ordem das exclusões que
    `AssignmentClassification` implementa, e devolvem as versões para a proveniência. **Levanta**
    dizendo regra e chave quando falta
  - **Feita quando**: toda chave lida tem teste de falta; nenhum valor de reserva
  - **Teste**: `test/the_band/network_analysis/parameters_test.exs`, um caso por chave apagada.
    **Defeito a injetar**: `Map.get(..., 100)` como reserva para `random_graphs`; o caso reprova

- [ ] T009 [P] Criar a tabela das leituras da análise
  - **Pronta quando**: [data-model.md §1](data-model.md#1-network_analysis_readings--a-leitura-vigente-por-organização-rede-e-janela)
  - **Descrição**: `priv/repo/migrations/<ts>_create_network_analysis_readings.exs`, `change/0`, com
    as colunas, a FK composta `(organization_id, tenant_id)`, o índice único
    `network_analysis_readings_vigente_index` e os `check`; schema privado
    `lib/the_band/network_analysis/schemas/reading.ex` com changeset que declara as constraints pelo
    nome
  - **Feita quando**: migrar, desfazer e migrar saem com `0`; linha com organização de T1 e
    `tenant_id` de T2 é recusada; duas linhas da mesma `(tenant, org, rede, janela)` são recusadas;
    `network = 'collab'` é recusado
  - **Teste**: `test/the_band/network_analysis/reading_constraints_test.exs` com os três
    `assert_raise`. **Defeito a injetar**: FK simples em `organization_id`; o caso da FK composta
    reprova

- [ ] T010 [P] Configurar a fila própria da análise
  - **Pronta quando**: [contracts/job.md](contracts/job.md)
  - **Descrição**: `config/config.exs`, `queues:` ganha `network_analysis: 1` (R4). Fila declarada e
    não configurada fica `available` para sempre (`recompute_promotions.ex:7-9`)
  - **Feita quando**: `Oban.config().queues` tem `network_analysis` com limite 1 em `dev` e `prod`
  - **Teste**: `test/the_band/jobs/fila_network_analysis_test.exs` lê a configuração de `:prod` e
    `assert` o limite 1. **Defeito a injetar**: tirar a linha da configuração; o teste reprova

- [ ] T011 [P] Sortear de forma reproduzível
  - **Pronta quando**: [contracts/algoritmos.md](contracts/algoritmos.md) `Algorithms.Random`; R7
  - **Descrição**: `lib/the_band/network_analysis/algorithms/random.ex`: `new/1`
    (`:rand.seed_s(:exsss, seed)`), `gnm/3` por rejeição sobre índices 1..n, `shuffle/2` por
    Fisher–Yates, todos devolvendo o estado. Nunca `:rand.uniform/1` sem `_s`
  - **Feita quando**: mesmo estado, mesma saída; G(n, m) tem exatamente m pares distintos sem laço;
    uma chamada a `:rand.uniform/0` no meio do processo não muda a saída
  - **Teste**: `test/the_band/network_analysis/algorithms/random_test.exs`, com a primeira saída de
    `gnm(new(42), 10, 15)` fixada no teste. **Defeito a injetar**: `:rand.seed(:exsss, seed)` (estado
    no dicionário) e `:rand.uniform/1`; o caso da chamada intercalada reprova

- [ ] T012 [P] Projetar sem direção e contar componentes e graus
  - **Pronta quando**: `contracts/algoritmos.md` `Algorithms.Projection`
  - **Descrição**: `lib/the_band/network_analysis/algorithms/projection.ex`: `undirected/1` com o peso
    somado dos dois sentidos (FR-010), `components/1` fracos (FR-019), `degrees/1` com o par
    recíproco contado uma vez (FR-033)
  - **Feita quando**: A → B (5) e B → A (1) dão {A, B} com peso 6 e grau 1 para cada; componentes
    ordenados por tamanho e menor id
  - **Teste**: `test/the_band/network_analysis/algorithms/projection_test.exs`. **Defeito a
    injetar**: guardar o peso de um sentido só (o `to_undirected()` da referência); o caso do par
    recíproco reprova

- [ ] T013 [security] Conferir antes de calcular, e encadear depois da 073
  - **Pronta quando**: T010; [contracts/job.md](contracts/job.md)
  - **Descrição**: `lib/the_band/jobs/compute_network_analysis.ex` com a unicidade, o `timeout/1` e as
    três conferências, cancelando sem gravar; `enqueue/2`. Em `compute_review_network.ex`, depois do
    `compute/3` com sucesso, `ComputeNetworkAnalysis.enqueue/2`, com o acoplamento escrito ao lado
    (R3). Argumentos além de `tenant_id` e `organization_id` ignorados
  - **Feita quando**: tenant suspenso, organização de outro tenant, inexistente e `network` fora da
    lista nos args dão `{:cancel, motivo}` (os três primeiros) ou são ignorados (o quarto), e nenhuma
    leitura é gravada; o caminho feliz da 073 enfileira exatamente um job da análise
  - **Teste**: `test/the_band/jobs/compute_network_analysis_test.exs` (A14), com `assert` antes de
    que o caminho feliz grava. **Defeito a injetar**: trocar o cancelamento da organização de outro
    tenant por leitura vazia; o teste reprova

- [ ] T014 [security] Calcular e substituir só a mesma rede e janela
  - **Pronta quando**: T008, T009, T011, T012, T013; `contracts/network-analysis.md` `compute/3`
  - **Descrição**: `lib/the_band/network_analysis/commands.ex`: `compute/3,4` recebe arestas por
    rede e janela (nesta tarefa, de uma função de entrada que T028 liga às duas redes), calcula a
    impressão digital (R4), aplica o teto (R5), monta a leitura com o que já existe (graus,
    componentes) e substitui **só** `(tenant, org, rede, janela)` numa transação, com
    `Repo.insert/1`. Devolve o relator só com contagens; o job registra a partir dele.
    `queries.ex`, `notices.ex`, a fachada `lib/the_band/network_analysis.ex`
  - **Feita quando**: duas execuções com as mesmas arestas: a segunda tem `outcome: :unchanged` e
    não regrava (A15); acima do teto, σ, Q_rand e layout ausentes com
    `network_too_large_for_platform` em tempo limitado (A16); gravar a designação mantém a revisão
    vigente (A21); erro de constraint não leva `person_id` (A18); `capture_log` em `:debug` não tem
    `person_id`, nome, login, papel nem medida por pessoa (A19)
  - **Teste**: `test/the_band/network_analysis/commands_test.exs`, um caso por cenário. **Defeitos a
    injetar**, um por vez: ignorar a impressão; tirar o teto; `delete_all` sem a rede;
    `Repo.insert!`; logar o `nodes`. Cada um reprova o seu caso

- [ ] T015 [P] [security] Alcançar por concessão (DS1)
  - **Pronta quando**: `contracts/fronteiras.md`, `Tenants`
  - **Descrição**: `Tenants.pessoas_alcancadas/3` com `origem: :concedida` em
    `lib/the_band/tenants/access.ex`, delegada em `tenants.ex`: só escopos `origin: :granted`; a
    própria pessoa; administração deste tenant é `:todas`. A `/2` não muda (R11)
  - **Feita quando**: conta só com vínculo de equipe alcança o colega pela `/2` e **não** pela `/3`;
    com concessão de equipe, alcança pelas duas; administrador de outro tenant não recebe `:todas`
  - **Teste**: `test/the_band/tenants/pessoas_alcancadas_concedida_test.exs`, dois tenants.
    **Defeito a injetar**: aceitar `origin: :derived_team` na `/3`; o caso do vínculo reprova

- [ ] T016 [security] Recortar a leitura pelo alcance (FR-015)
  - **Pronta quando**: T014, T015; `contracts/algoritmos.md` `View.build/5`; R10
  - **Descrição**: `lib/the_band/network_analysis/view.ex`, puro, com as dez regras de R10 sobre o que
    a leitura já tem (nós, arestas, componentes, comunidade quando existir): agregados por comunidade
    com k, *"other communities"*, marca *"has links outside your reach"*, ids `outside-<n>`, arestas
    somadas por sentido, supressão complementar, `reach: :nenhum` (DS5),
    `sees_others_positions?` (DS1). As regras de hubs, papel e núcleo de comunidade entram aqui como
    funções que T037, T040 e T046 chamam
  - **Feita quando**: comunidade com 1, 2 e 3 pessoas de fora dá nenhum nó, nenhum nó e nó *"(3)"*
    (A4); só 2 de fora no total dá nenhum agregado e só a marca (A5); nenhum id de agregado deriva de
    `person_id`; administração vê todos por id
  - **Teste**: `test/the_band/network_analysis/view_test.exs` (A4, A5, parte de A6). **Defeitos a
    injetar**: tirar o k; criar *"other communities"* sem conferir k; id do agregado por hash do
    `person_id`. Cada um reprova o seu caso

- [ ] T017 [security] Ler pelo alcance, a cada chamada
  - **Pronta quando**: T016; `contracts/network-analysis.md` `read/4`, `selection/1`, `options/0`
  - **Descrição**: `lib/the_band/network_analysis/reader.ex`: `selection/1` por texto exato contra as
    listas, padrão fora delas; `read/4` na ordem do contrato — organização por id e tenant, leitura
    vigente da rede e janela, `{:ausente, :stale}` além da maior janela, os dois alcances **nesta
    chamada**, `View`, nomes por `EO.people_names/2`, coleta mais nova, número de contas declaradas
  - **Feita quando**: `?network=assignmentx`, `?view=../../`, `?window=36500`, `?window=90;drop` e
    10 000 caracteres voltam ao padrão sem criar átomo (A12); organização de outro tenant e id
    malformado dão o mesmo `not_found`; o alcance perdido some na leitura seguinte (A22); número de
    consultas fixo com 5 e com 50 pessoas
  - **Teste**: `test/the_band/network_analysis/reader_test.exs` com
    `:erlang.system_info(:atom_count)` antes e depois. **Defeitos a injetar**: `String.to_atom/1` no
    parâmetro; guardar o alcance no primeiro `read`; uma consulta de nome por pessoa. Cada um reprova

---

## Fase 3: US1 — A área "Network analysis" no menu, com a rede de revisão como primeira página (P1) 🎯 MVP

**Objetivo**: a área no menu, com a rede de revisão da 073 a um clique. **Teste independente**: a
área aparece, abre a rede de revisão com os números da página da 073, e o endereço antigo leva a ela.

- [ ] T018 [P] [US1] Pôr Network analysis no menu principal
  - **Pronta quando**: [contracts/tela.md](contracts/tela.md)
  - **Descrição**: `lib/the_band_web/components/layouts.ex`: o item **Network analysis** depois de
    *Organization*, e `{"/network-analysis", :network_analysis}` em `@nav_areas` (FR-001). O
    comentário da barra (*"só as entidades"*) ganha a exceção com a data e a decisão (Decisões
    revertidas, 046)
  - **Feita quando**: toda conta vê o item; ele é marcado como ativo em todo caminho sob
    `/network-analysis`
  - **Teste**: `test/the_band_web/components/layouts_nav_area_test.exs` (`nav_area/1` para os caminhos
    da área) e um teste de LiveView que `assert` o `aria-current`. **Defeito a injetar**: tirar a linha
    de `@nav_areas`; o teste reprova

- [ ] T019 [US1] Abrir a área e escolher a organização
  - **Pronta quando**: T017, T018; protótipo §3 Tela 1
  - **Descrição**: `lib/the_band_web/live/network_analysis_live/index.ex` e
    `shared.ex` (cabeçalho, seletores, linha da leitura, aviso de alcance parcial): título e pergunta,
    as duas arestas definidas em palavras, os seis cartões, a frase de não-avaliação; lista as
    organizações observadas do tenant; com uma só, `push_navigate` para ela. Rotas em
    `router.ex`
  - **Feita quando**: com duas organizações, quem consulta escolhe, e nenhuma pessoa só da outra
    aparece (US1, cen. 4); nenhum texto diz *collaboration* nem *delegation*
  - **Teste**: `test/the_band_web/live/network_analysis_live/index_test.exs`, dois tenants e duas
    organizações. **Defeito a injetar**: listar organizações sem filtro de tenant; o caso de outro
    tenant reprova

- [ ] T020 [security] [US1] Montar a rede de revisão na área, e o endereço antigo
  - **Pronta quando**: T019
  - **Descrição**: `router.ex`: `live "/network-analysis/:organization_id", ReviewNetworkLive.Show,
    :show` e o endereço antigo com a ação `:legacy`, que valida o id por `EO.fetch_organization/2` e
    faz `push_navigate` para `~p"/network-analysis/#{id}?window=#{janela}"` com a janela da lista.
    `ReviewNetworkLive.Show` mantém o aviso dela; o cabeçalho da área envolve a página (FR-003; R13)
  - **Feita quando**: a página na área mostra os mesmos números da 073 para a mesma janela (US1,
    cen. 2); `/organizations/<id>/review-network?window=90&return_to=https://exemplo.invalid` vai para
    um caminho da área sem o parâmetro (A13); id de outro tenant dá *"not found"*
  - **Teste**: `test/the_band_web/live/review_network_live/area_test.exs`. **Defeito a injetar**:
    colar a query original no destino; o caso A13 reprova

---

## Fase 4: US2 — A rede de designação (P1)

**Objetivo**: a rede autor → responsável, com contagens e exclusões por motivo. **Teste
independente**: as contagens batem com uma contagem manual das mesmas issues e designações.

- [ ] T021 [P] [US2] [security] Gravar o tipo da conta na coleta de issues (A3)
  - **Pronta quando**: [data-model.md §3](data-model.md#3-o-tipo-da-conta-na-coleta-de-issues-r13-a3); R13
  - **Descrição**: migração `<ts>_add_account_type_to_issue_people.exs` (`change/0`, duas colunas com
    `check`); `CollectedIssue` e `IssueAssignee` aceitam o campo; `Ingestion.GithubWorkItems` passa
    `Mapper.account_type/1` do nó `author` e de cada nó de `assignees`. Chamado, nunca reimplementado
  - **Feita quando**: issue com autor `__typename: "Bot"` e login sem sufixo grava `bot`; responsável
    `User` grava `person`; migrar e desfazer saem com `0`
  - **Teste**: `test/the_band/ingestion/github_work_items_account_type_test.exs` com payload de
    fixture. **Defeito a injetar**: classificar pelo sufixo do login; o caso do `Bot` sem sufixo
    reprova

- [ ] T022 [US2] Preencher o tipo da conta das issues já coletadas
  - **Pronta quando**: T021
  - **Descrição**: migração de dados `<ts>_backfill_issue_account_types.exs`: `up/0` com `execute/1`
    que preenche pelo payload bruto mais recente por `(tenant_id, external_id)` em `raw_payloads`
    (`github.issue`), responsáveis casados pelo login dentro do mesmo payload; `down/0` explícito que
    anula as duas colunas. Medir antes e depois, em desenvolvimento, quantas linhas ficam nulas
  - **Feita quando**: em desenvolvimento, as 3 issues de autor não ligado sem sufixo (R13) ficam
    `bot` ou `app` conforme o payload; o número de nulas antes e depois está na issue
  - **Teste**: `test/the_band/repo/backfill_account_types_test.exs` roda o SQL da migração sobre
    fixture de dois tenants. **Defeito a injetar**: casar o payload sem `tenant_id`; o caso do payload
    de outro tenant com o mesmo `external_id` reprova

- [ ] T023 [US2] [security] Ler os pares de designação com seis filtros de tenant
  - **Pronta quando**: T021; `contracts/fronteiras.md` `WorkItems.assignment_pairs/3`
  - **Descrição**: `lib/the_band/work_items/queries.ex` (delegada em `work_items.ex`): a consulta de R12,
    com `i.tenant_id`, `a.tenant_id`, `p_autor.tenant_id`, `p_resp.tenant_id` e os repositórios da
    organização; responsáveis e issues vigentes; **sem** ler login (R9)
  - **Feita quando**: com `issue_assignees` de T2 apontando, à mão, para issue de T1, nenhuma pessoa de
    T2 aparece (A1); com organizações A e B no mesmo tenant, a leitura de A não traz issue só de B (A2)
  - **Teste**: `test/the_band/work_items/assignment_pairs_test.exs`, `assert` de pares > 0 antes dos
    `refute`. **Defeitos a injetar**: tirar o filtro de tenant de **cada** uma das tabelas, uma por
    vez (para as que não reprovam, escrever na issue qual igualdade de join segura, como a 073 fez);
    filtrar só pelo tenant, sem a organização (L19)

- [ ] T024 [US2] Classificar cada designação em exatamente um destino
  - **Pronta quando**: T008, T023
  - **Descrição**: `lib/the_band/network_analysis/assignment_classification.ex`, puro, pela ordem da
    regra (`bot_or_app` → `organization_account` → `unlinked_person` → `self_assignment` → aresta);
    tipo gravado para conta não ligada, nulo vira `unlinked_person` e é contado em
    `account_type_unknown`; peso por issues distintas; issues sem responsável contadas
  - **Feita quando**: os cinco cenários da US2 dão o resultado da spec (Ana → Bia 4, Ana → Caio 2;
    auto-designação contada; `dependabot[bot]` e conta da organização contados sem login; issue com
    três responsáveis dá três arestas de peso 1); invariante soma + exclusões = pares
  - **Teste**: `test/the_band/network_analysis/assignment_classification_test.exs`. **Defeito a
    injetar**: inverter `organization_account` e `bot_or_app`; o caso da conta que é as duas reprova
    pela contagem dobrada

- [ ] T025 [P] [US2] [security] Declarar e revogar a conta da organização
  - **Pronta quando**: [data-model.md §2](data-model.md#2-organization_account_declarations--a-conta-da-organização-declarada-r14);
    `contracts/fronteiras.md` *Contas da organização*
  - **Descrição**: migração `<ts>_create_organization_account_declarations.exs` (com
    `unique_index(:eo_people, [:id, :tenant_id])`); schema
    `lib/the_band/tenants/access/organization_account_declaration.ex`; em `access.ex`, delegadas em
    `tenants.ex`: `declare_organization_account/4`, `revoke_organization_account/3`,
    `organization_account_ids/1`, `list_organization_accounts/2`; eventos em `AccessEvents` ao
    declarar, revogar e recusar
  - **Feita quando**: declarar pessoa com elo vigente com conta da plataforma é recusado; conta de
    membro é recusada (`:not_admin`); a pessoa da própria conta é recusada; a marca válida sobrevive a
    uma coleta que reescreve `eo_people.account_type`; o evento existe com quem declarou (A20)
  - **Teste**: `test/the_band/tenants/organization_accounts_test.exs`, dois tenants. **Defeitos a
    injetar**: gravar a marca em `account_type`; aceitar de membro. Cada um reprova

- [ ] T026 [US2] [security] Declarar a conta da organização na tela de pessoas
  - **Pronta quando**: T025
  - **Descrição**: `PeopleLive.Show`: para a administração, o controle de declarar (com motivo
    obrigatório) e revogar; `PeopleLive.Index`: para a administração, as contas declaradas com quem
    declarou e quando. Para quem não administra, nada aparece (texto em inglês)
  - **Feita quando**: administração declara e revoga pela tela; conta de membro não vê o controle e o
    evento forjado é recusado sem mudar nada
  - **Teste**: `test/the_band_web/live/people_live/organization_account_test.exs`, com `render_click`
    forjado por conta de membro. **Defeito a injetar**: conferir a administração só no `render`, e não
    no `handle_event`; o evento forjado passa e o teste reprova

- [ ] T027 [US2] [security] Excluir a conta da organização também na revisão (A7)
  - **Pronta quando**: **T002 decidida como sim**; T025
  - **Descrição**: `review.network.edge` versão 2 com `organization_account` na ordem;
    `ReviewNetwork.Classification` recebe as contas declaradas e ganha o destino;
    `ReviewNetwork.Parameters` confere a ordem nova; migração
    `<ts>_add_organization_account_to_review_network_readings.exs` com a coluna **anulável**
    ([data-model.md §4](data-model.md#4-a7-opção-padrão-review_network_readingsexcluded_organization_account));
    a página da 073 mostra o motivo e, numa leitura antiga (nulo), diz que ele não foi avaliado
  - **Feita quando**: a mesma conta declarada é excluída nas duas redes; leitura gravada antes da
    versão 2 não mostra `0` no motivo novo
  - **Teste**: `test/the_band/review_network/classification_test.exs` (caso novo) e
    `test/the_band_web/live/review_network_live/show_test.exs` (leitura antiga). **Defeito a
    injetar**: coluna com `default: 0`; o caso da leitura antiga reprova

- [ ] T028 [US2] Calcular as duas redes nas três janelas
  - **Pronta quando**: T014, T024; T004
  - **Descrição**: `ReviewNetwork.current_edges/2` (só ids, por janela, a partir das leituras
    vigentes da 073) e, em `NetworkAnalysis.Commands`, as arestas das duas redes: revisão de
    `current_edges/2` com `source_computed_at`; designação de `WorkItems.assignment_pairs/3` +
    `AssignmentClassification` com as contas de `Tenants.organization_account_ids/1`, janela pelo
    instante de abertura da issue
  - **Feita quando**: o job grava 6 leituras; a de revisão tem as arestas da 073 da mesma janela;
    a de designação tem as contagens da classificação; sem leitura da 073, a revisão é
    `{:ausente, :not_computed}` e a designação é gravada
  - **Teste**: `test/the_band/network_analysis/commands_duas_redes_test.exs`. **Defeito a injetar**:
    janela da designação por `updated_at` da issue; o caso da issue aberta antes da janela e
    atualizada dentro dela reprova

- [ ] T029 [US2] Mostrar as contagens da rede de designação
  - **Pronta quando**: T017, T028; protótipo 3.2.6–3.2.8
  - **Descrição**: `lib/the_band_web/live/network_analysis_live/graph.ex` (a página Graph, sem o
    desenho ainda): issues, arestas, exclusões por motivo (só com alcance total), pessoas sem aresta,
    conectividade dita certa (*"1 group"*), a frase do que a aresta liga e do que não diz (US2,
    cen. 5), o número de contas declaradas da organização; ausências por `<.absent>`
  - **Feita quando**: rede sem aresta diz que não houve designação entre pessoas, sem 0; alcance
    parcial não mostra as contagens de exclusão
  - **Teste**: `test/the_band_web/live/network_analysis_live/graph_counts_test.exs`. **Defeito a
    injetar**: mostrar as exclusões com alcance parcial; o caso reprova

---

## Fase 5: US3 — O grafo ponderado (P1)

**Objetivo**: o grafo da referência, interativo, sem dado no navegador. **Teste independente**: rede
de 5 pessoas — maior grau, maior círculo; cor pela intermediação com legenda; aresta mais pesada,
mais grossa.

- [ ] T030 [P] [US3] Calcular a intermediação por Brandes
  - **Pronta quando**: T012; `contracts/algoritmos.md` `Algorithms.Betweenness`
  - **Descrição**: `lib/the_band/network_analysis/algorithms/betweenness.ex` (R6), ligado em
    `Commands` como `nodes[].betweenness`
  - **Feita quando**: estrela de 6: centro 1,0, folhas 0,0; caminho de 4: 2/3 nos dois do meio; n < 3
    ausente com `network_too_small`
  - **Teste**: `test/the_band/network_analysis/algorithms/betweenness_test.exs`, tolerância 1e-9.
    **Defeito a injetar**: não dividir por 2 (pares ordenados); a estrela reprova

- [ ] T031 [P] [US3] Posicionar os nós no servidor, com semente
  - **Pronta quando**: T011; `contracts/algoritmos.md` `Algorithms.Layout`; R9
  - **Descrição**: `lib/the_band/network_analysis/algorithms/layout.ex` (Fruchterman–Reingold, R9),
    ligado em `Commands` (`nodes[].x/y`) e chamado pelo `Reader` com alcance parcial sobre o grafo da
    visão
  - **Feita quando**: o mesmo grafo dá as mesmas posições em duas chamadas; todas em [40, 960]²;
    acima do teto, ausente
  - **Teste**: `test/the_band/network_analysis/algorithms/layout_test.exs`. **Defeito a injetar**:
    semear por `:rand.seed/1` com o tempo; a igualdade reprova

- [ ] T032 [US3] [security] Desenhar o grafo em SVG, sem dado no navegador
  - **Pronta quando**: T030, T031; [contracts/tela.md](contracts/tela.md) *O grafo*; R16
  - **Descrição**: `lib/the_band_web/live/network_analysis_live/graph_components.ex`: `graph/1` (SVG
    inline, setas por `marker-end`, tamanho pelo grau, cor por classe da faixa de intermediação,
    espessura pelo peso, nomes só nos sete mais ligados, `<title>` em todos), legenda em texto, lista
    empilhada para o telefone; hook co-localizado `.NetworkGraph` só de `transform` (roda, + / − /
    *fit*, arrasto); destaque por `JS.add_class/remove_class` em `phx-mouseenter`/`phx-focus`;
    `tabindex="0"` nos nós
  - **Feita quando**: nome `<script>alert(1)</script>` e `"><foreignObject>` saem escapados em
    `<text>` e `<title>` (A9); o markup não tem `data-*` com JSON nem `push_event` (A7); não existe
    `handle_event` de destaque, e um evento forjado com `person_id` de fora, UUID aleatório e 10 000
    ids dá a mesma resposta sem crescer estado (A8); `style` só com número
  - **Teste**: `test/the_band_web/live/network_analysis_live/graph_component_test.exs`. **Defeitos a
    injetar**: `raw/1` no rótulo; passar a leitura num `data-graph`. Cada um reprova

- [ ] T033 [US3] [security] Mostrar o grafo ponderado com o recorte
  - **Pronta quando**: T016, T029, T032
  - **Descrição**: a página Graph ganha o desenho da visão (alcançados e agregados), a marca *"has
    links outside your reach"*, o destaque com *"N links out, M in"*, a lista do telefone com a mesma
    visão, e a vista de comunidades alternável quando T035 existir (FR-026)
  - **Feita quando**: administração vê as 4 pessoas de fora por nome; conta parcial vê **um** nó
    *"People outside your reach — community N (4)"*; com 1 ou 2 de fora, nenhum nó, só a marca (US3,
    cen. 5); nenhum `person_id` de fora no HTML nem em hash SHA/MD5 dele; ids de agregado mudam entre
    duas leituras diferentes (A6); telefone sem rolagem lateral (SC-007)
  - **Teste**: `test/the_band_web/live/network_analysis_live/graph_recorte_test.exs`, duas contas,
    organização com 1, 2 e 3 de fora na mesma comunidade. **Defeito a injetar**: renderizar a lista
    da rede inteira no telefone; o caso parcial reprova

- [ ] T034 [US3] Medir o layout da visão parcial na leitura
  - **Pronta quando**: T031, T033
  - **Descrição**: medir o tempo do layout recalculado na leitura para 50 e para 300 nós de visão, e
    escrever em `research.md` R9 (R7 da segurança: *"o plano mede e escreve o número"*)
  - **Feita quando**: R9 tem os dois números, a máquina e a data; se 300 passar de 200 ms, a tarefa
    abre a decisão de guardar o layout por `(leitura, alcance)` em vez de recalcular
  - **Teste**: `test/the_band/network_analysis/layout_custo_test.exs` com teto de tempo folgado (L53:
    o teto vem da medida dos dois lados). **Defeito a injetar**: 500 iterações; o teto reprova

---

## Fase 6: US4 — As comunidades (P2)

**Objetivo**: comunidades com peso e desempate, modularidade contra Q_rand. **Teste independente**:
dois grupos densos com uma ponte dão duas comunidades e a modularidade da conta à mão.

- [ ] T035 [P] [US4] Detectar comunidades pelo guloso com peso
  - **Pronta quando**: T012; `contracts/algoritmos.md` `Algorithms.Communities`
  - **Descrição**: `lib/the_band/network_analysis/algorithms/communities.ex`: CNM com peso,
    desempate pelo par de menor índice, numeração por tamanho; `modularity/2`; `internal_degree/2`.
    Ligado em `Commands` (`nodes[].community`, `internal_degree`, `communities`, `measures.modularity`)
  - **Feita quando**: dois triângulos ligados por uma aresta dão duas comunidades e Q = 5/14; empate
    perfeito dá a mesma partição em 10 execuções e com a entrada em ordem invertida
  - **Teste**: `test/the_band/network_analysis/algorithms/communities_test.exs`. **Defeito a
    injetar**: desempatar pela ordem do mapa; o caso da entrada invertida reprova

- [ ] T036 [US4] Comparar a modularidade com a dos aleatórios, com peso (A5)
  - **Pronta quando**: T011, T035; R8
  - **Descrição**: `lib/the_band/network_analysis/algorithms/small_world.ex`, `random_battery/2`, com a
    parte de modularidade: 100 G(n, m) na sequência declarada, pesos reais embaralhados, o mesmo
    guloso em cada um; ligado em `Commands` (`measures.random.modularity`); acima do teto, ausente
  - **Feita quando**: com todos os pesos 1, Q_rand é igual à do mesmo grafo sem peso; com pesos
    concentrados, Q_rand com peso é maior que sem peso no mesmo sorteio; mesma semente, mesmo Q_rand
  - **Teste**: `test/the_band/network_analysis/algorithms/q_rand_test.exs`. **Defeito a injetar**: não
    passar os pesos aos aleatórios; o caso dos pesos concentrados reprova

- [ ] T037 [US4] [security] Mostrar as comunidades com o recorte
  - **Pronta quando**: T016, T033, T036; protótipo §3 Tela 3; decisões a confirmar R10 item 8 e R21
  - **Descrição**: `lib/the_band_web/live/network_analysis_live/communities.ex`: número de
    comunidades, modularidade com Q_rand e as faixas **citadas** com a fonte (FR-031), *"Not the
    declared teams — a reading"* (FR-030), o método (guloso, com peso), um bloco por comunidade com
    rótulo, tamanho, arestas internas, os três mais centrais (entre os alcançados, *"among the members
    you reach"*, e só com escopo concedido pela DS1), todos os membros alcançados por nome, os de
    fora pela regra do agregado; a vista de comunidades no grafo (FR-026)
  - **Feita quando**: comunidade de 7 mostra tamanho, arestas internas, três mais centrais e membros
    (US4, cen. 2); com membros de fora, tamanho e arestas suprimidos quando contariam menos de 3 de
    fora, com a frase do porquê (US4, cen. 4); comunidade sem alcançado sem bloco; cor nunca é o
    único sinal
  - **Teste**: `test/the_band_web/live/network_analysis_live/communities_test.exs`, duas contas, com
    1, 2 e 3 de fora (A4, A5). **Defeito a injetar**: mostrar o tamanho mesmo suprimido; o caso de 2
    de fora reprova

---

## Fase 7: US5 — Os hubs (P2)

**Objetivo**: as quatro centralidades em listas, com frase correta. **Teste independente**: estrela
de 6 — o centro lidera grau, intermediação e proximidade.

- [ ] T038 [P] [US5] Calcular distâncias de cada pessoa e a proximidade
  - **Pronta quando**: T012; `contracts/algoritmos.md` `Algorithms.Paths`
  - **Descrição**: `lib/the_band/network_analysis/algorithms/paths.ex`: `all_pairs/1`, `closeness/2`
    (Wasserman–Faust), `person_distance/1`; ligado em `Commands` (`closeness`, `distance_mean`,
    `reaches`)
  - **Feita quando**: estrela de 6: centro com proximidade 1,0 e distância média 1; desconexa: a
    proximidade usa r(u) e n da rede inteira, e a distância média é sobre quem a pessoa alcança
  - **Teste**: `test/the_band/network_analysis/algorithms/paths_test.exs`, 1e-9. **Defeito a
    injetar**: devolver 1/proximidade como distância média (a referência, `:318`); o caso desconexo
    reprova

- [ ] T039 [P] [US5] Calcular o autovetor por componente
  - **Pronta quando**: T012; `contracts/algoritmos.md` `Algorithms.Eigenvector`
  - **Descrição**: `lib/the_band/network_analysis/algorithms/eigenvector.ex` (A + I, com peso, por
    componente, tolerância e teto da base); ligado em `Commands`
  - **Feita quando**: bipartida converge; componente de 2 dá 1/√2 aos dois; com `max_iterations: 1`
    forçado, o componente fica ausente com `did_not_converge` e os outros não mudam
  - **Teste**: `test/the_band/network_analysis/algorithms/eigenvector_test.exs`, 1e-6 relativo.
    **Defeito a injetar**: iterar sobre A sem I; a bipartida reprova; e devolver o grau como reserva;
    o caso de não convergência reprova

- [ ] T040 [US5] [security] Mostrar os hubs só entre alcançados
  - **Pronta quando**: T016, T030, T038, T039; protótipo §3 Tela 4
  - **Descrição**: `lib/the_band_web/live/network_analysis_live/hubs.ex`: quatro listas do tamanho da
    base, ordenadas pela medida, empate pelo id marcado *"tied"*; grau por sentido com os rótulos de
    `network.degree.count` (*"opened issues assigned to"* / *"assigned on issues opened by"*;
    *"reviews"* / *"is reviewed by"*); proximidade com distância média e quantos alcança; autovetor
    por componente, com a frase de que componentes não se comparam; a frase de não-avaliação; com
    alcance parcial, *"Among the people you reach"* e *"People outside your reach are not ranked
    here."*; sem escopo concedido (DS1), a seção diz que os hubs com nome de outras pessoas não estão
    disponíveis; DS5 sem a seção
  - **Feita quando**: a pessoa de maior intermediação fora do alcance não tem linha, com ou sem valor,
    e não há número de posição na rede inteira (A3); conta só com vínculo de equipe não vê hubs com
    nome de colega e vê o próprio papel (A11); grau normalizado não aparece com alcance parcial
  - **Teste**: `test/the_band_web/live/network_analysis_live/hubs_test.exs`, administração, alcance
    parcial concedido, vínculo derivado e sem alcance. **Defeito a injetar**: renderizar a lista da
    rede inteira com *"a person outside your reach"* (o texto antigo da US5); o caso A3 reprova

---

## Fase 8: US6 — Distância e eficiência (P3)

**Objetivo**: distância média, diâmetro e eficiência ao lado dos aleatórios. **Teste independente**:
caminho de 4 — 5/3, 3 e 13/18.

- [ ] T041 [US6] Calcular distância média, diâmetro e eficiência, e as dos aleatórios
  - **Pronta quando**: T036, T038
  - **Descrição**: `Paths.network/2` e, em `random_battery/2`, as mesmas medidas sobre os 100
    aleatórios pela mesma regra de pares que se alcançam, com `reachable_share` dos dois lados (A6);
    ligado em `Commands` (`measures.average_distance`, `diameter`, `global_efficiency`,
    `random.*`)
  - **Feita quando**: caminho de 4 dá 5/3, 3 e 13/18; desconexa dá a média sobre pares que se
    alcançam com a fração; sem aresta, as três ausentes com `no_edge_in_window`
  - **Teste**: `test/the_band/network_analysis/algorithms/network_distances_test.exs`. **Defeito a
    injetar**: média simples das médias por componente (a referência, `:139-149`); o caso desconexo
    reprova

- [ ] T042 [US6] Mostrar distância, diâmetro e eficiência
  - **Pronta quando**: T017, T041; protótipo §3 Tela 5 (3.5.1, 3.5.2, 3.5.5)
  - **Descrição**: `lib/the_band_web/live/network_analysis_live/distance.ex`, primeira metade: as três
    medidas com o valor médio dos aleatórios ao lado, a fração de pares que se alcançam, *"the longest
    distance between people who reach each other"*, a nota de que só a eficiência conta pares sem
    caminho como zero, a distribuição dos comprimentos; nenhuma faixa vira adjetivo
  - **Feita quando**: rede com dois componentes diz que há pares sem caminho (US6, cen. 2); nenhum
    *"efficient"* nem *"slow"* na página
  - **Teste**: `test/the_band_web/live/network_analysis_live/distance_test.exs`. **Defeito a
    injetar**: escrever *"efficient"* acima de 0,7 (a referência, `:354`); o teste reprova

---

## Fase 9: US7 — Mundo pequeno (P3)

**Objetivo**: clustering, σ e o critério escrito como critério. **Teste independente**: o mesmo dado
dá o mesmo σ, com semente e número de aleatórios na proveniência.

- [ ] T043 [US7] Calcular o clustering e o σ
  - **Pronta quando**: T041; `contracts/algoritmos.md` `Algorithms.Clustering`, `SmallWorld.sigma/4`
  - **Descrição**: `lib/the_band/network_analysis/algorithms/clustering.ex` (grau < 2 fora e
    contado) e `SmallWorld.sigma/4`; os aleatórios com a mesma regra; média sobre os grafos em que a
    medida está definida, com o número; ausências pelos motivos da base; ligado em `Commands`
  - **Feita quando**: todo aleatório gerado entra (inclusive desconexo) e a média divide pelo que
    entrou; abaixo de 10 pessoas, `network_too_small`; C_rand médio zero dá
    `random_clustering_undefined`; mesmo dado, mesmo σ
  - **Teste**: `test/the_band/network_analysis/algorithms/small_world_test.exs`. **Defeitos a
    injetar**: descartar os aleatórios desconexos; dividir sempre por 100; contar 0 para grau < 2.
    Cada um reprova o seu caso

- [ ] T044 [US7] Mostrar o mundo pequeno como critério
  - **Pronta quando**: T042, T043; protótipo 3.5.3, 3.5.4
  - **Descrição**: `distance.ex`, segunda metade: a tabela clustering e distância média, real ×
    aleatório, com as razões; σ com uma casa; *"meets the σ > 1 criterion"* (ou *"does not meet"*) e a
    frase do que o critério não prova (Telesford et al.); quantos aleatórios entraram, a semente, e
    quantas pessoas ficaram fora do clustering; ausência nunca lida como *"not a small world"*
  - **Feita quando**: σ ausente não produz *"not"* nenhum sobre mundo pequeno (US7, cen. 3); a frase
    de σ > 1 traz o critério e o limite
  - **Teste**: `test/the_band_web/live/network_analysis_live/small_world_test.exs`. **Defeito a
    injetar**: escrever *"is a small world"*; o teste reprova

---

## Fase 10: US8 — O papel de cada pessoa (P3)

**Objetivo**: o papel derivado na leitura, com o critério ao lado. **Teste independente**: rede de 20
com percentis conhecidos dá o papel da regra a cada pessoa.

- [ ] T045 [P] [US8] Derivar percentil e papel na leitura
  - **Pronta quando**: T008; `contracts/algoritmos.md` `Algorithms.Position`
  - **Descrição**: `lib/the_band/network_analysis/algorithms/position.ex`: percentil por posto médio
    sobre a rede inteira, cortes e rótulos de `network.position_role`, mínimo de pessoas; chamado no
    `Reader`, **nunca** em `Commands`
  - **Feita quando**: percentil 90 / 85 dá `central_position`; 40% empatados em zero dão percentil 20;
    abaixo de 10 pessoas, todos ausentes; a leitura gravada não tem papel nem percentil
  - **Teste**: `test/the_band/network_analysis/algorithms/position_test.exs` e um caso em
    `commands_test.exs` que `refute` as chaves `role`/`percentile` em `nodes`. **Defeito a injetar**:
    gravar o papel em `Commands`; o caso reprova

- [ ] T046 [US8] [security] Mostrar as posições por nome, com o critério
  - **Pronta quando**: T016, T040, T045; protótipo §3 Tela 6 (3.6.1–3.6.3)
  - **Descrição**: `lib/the_band_web/live/network_analysis_live/positions.ex`: tabela por **nome**,
    sem ordenação por coluna — pessoa, comunidade, ligada a, posição em frase com os dois percentis e
    o corte; a regra a um clique; a frase de não-avaliação e de que o papel muda com a rede; DS1:
    papel de outra pessoa só com escopo concedido; o próprio papel sempre; nenhuma contagem de papel
    entre os de fora
  - **Feita quando**: conta de vínculo derivado vê o próprio papel e não o do colega (A11); conta
    parcial não vê *"N people outside your reach are …"*; administração vê todos
  - **Teste**: `test/the_band_web/live/network_analysis_live/positions_test.exs`. **Defeito a
    injetar**: usar `pessoas_alcancadas/2` sem a opção concedida; o caso do vínculo derivado reprova

---

## Fase 11: US9 — O perfil individual (P3)

**Objetivo**: o perfil de uma pessoa nas duas redes. **Teste independente**: contagens e listas
batem com as arestas da leitura.

- [ ] T047 [US9] [security] Abrir o perfil só de quem se alcança
  - **Pronta quando**: T017, T045; `contracts/network-analysis.md` `profile/5`
  - **Descrição**: `Reader.profile/5`: abre se a pessoa está em `pessoas_alcancadas/2` desta chamada ou
    é a de quem consulta; `pode_ver/3` não é chamado; as duas redes; pares de fora agregados (*"N
    issues with people outside your reach"*, sem número por pessoa); total verdadeiro (DS3 (a));
    papel e percentis de outra pessoa pela DS1
  - **Feita quando**: pessoa de outro tenant, inexistente, fora do alcance e `abc` dão o mesmo `not
    found`; pessoa alcançada sem aresta dá `no_edges_in_window` (A10); com uma liderança declarada na
    fixture, perfil e grafo concordam
  - **Teste**: `test/the_band/network_analysis/profile_test.exs`. **Defeito a injetar**: usar
    `pode_ver/3` no perfil e `pessoas_alcancadas/2` no grafo; o caso da liderança declarada reprova
    pela divergência

- [ ] T048 [US9] Mostrar o perfil
  - **Pronta quando**: T047; protótipo 3.6.4, Tela 8
  - **Descrição**: `lib/the_band_web/live/network_analysis_live/profile.ex`: por rede, as contagens com
    os rótulos de `network.degree.count`, grau e intermediação com percentil, papel, as duas listas
    por peso com o total, o agregado de fora; ausência escrita; empilhado no telefone; links das
    outras páginas da área (nomes de alcançados) levam a ele
  - **Feita quando**: Bia (3 por quem foi designada, 2 a quem abriu) mostra *"opened issues assigned
    to 2 people"* e *"assigned on issues opened by 3 people"* (US9, cen. 1); nenhum *"assigns to"* nem
    *"receives from"*
  - **Teste**: `test/the_band_web/live/network_analysis_live/profile_test.exs`. **Defeito a injetar**:
    o rótulo *"assigns to"*; o teste reprova

---

## Fase 12: Acabamento

- [ ] T049 Provar as cinco redes conhecidas e a reprodutibilidade
  - **Pronta quando**: T030, T035, T038, T039, T041, T043
  - **Descrição**: `test/the_band/network_analysis/redes_conhecidas_test.exs`: `compute/4` sobre
    estrela, caminho, dois grupos com ponte, bipartida e desconexa, cada valor com a conta à mão ao
    lado (SC-002, tolerância de R6); e a mesma leitura calculada **10 vezes**, comparada por `==`,
    inclusive comunidades, σ, Q_rand e posições (SC-003)
  - **Feita quando**: os cinco casos e as dez repetições passam
  - **Teste**: o próprio arquivo. **Defeito a injetar**: somar os pesos de um mapa sem ordenar as
    chaves em `Communities`; a igualdade das dez reprova se a ordem mudar (se não reprovar, escrever
    na issue por que a ordem do mapa não muda o resultado)

- [ ] T050 Medir o teto e o tempo do job
  - **Pronta quando**: T043, T036, T031
  - **Descrição**: medir `compute/4` para G(n, m) de 300 pessoas e 3 000 arestas nas duas redes e três
    janelas; escrever em `research.md` R5 e ajustar `size_limit` e o `timeout/1` se preciso (a mudança
    na base passa pelo agente semântico); com a #1190 e T003, confirmar o teto
  - **Feita quando**: R5 tem a medida, a máquina e a data; as 6 combinações cabem no `timeout/1`
  - **Teste**: `test/the_band/network_analysis/teto_test.exs`, tag `:slow`, com o teto de tempo
    (L53). **Defeito a injetar**: 1 000 grafos aleatórios; o teto reprova

- [ ] T051 [P] [security] Guardar a análise fora da API, do MCP e do perfil
  - **Pronta quando**: T020
  - **Descrição**: `test/the_band/network_analysis/exposicao_test.exs` lê o roteador, o registro de
    ferramentas MCP (`lib/the_band/mcp/`), `lib/the_band_web/controllers/api/` e `lib/the_band/profiles/`
    e reprova se aparecer `NetworkAnalysis`, `network_analysis_readings` ou rota da área que não seja
    `live` (FR-053, A17); e o HTML das páginas da área não tem `download`, `Content-Disposition` nem
    botão de exportar
  - **Feita quando**: o teste passa sobre o código da feature
  - **Teste**: o próprio arquivo. **Defeito a injetar**: uma rota `get "/network-analysis/:id/graph.svg"`;
    o teste reprova

- [ ] T052 [P] [security] Apagar as leituras ao encerrar a observação
  - **Pronta quando**: T014; `contracts/fronteiras.md` `Sources`
  - **Descrição**: `NetworkAnalysis.discard_organization/2` e `ReviewNetwork.discard_organization/2`,
    chamadas por `Sources.end_observation/3` dentro da transação (R18); o `Reader` já recusa leitura
    velha (T017)
  - **Feita quando**: encerrar a observação apaga as leituras das duas features só daquela
    organização e daquele tenant; uma falha na transação não apaga nada
  - **Teste**: `test/the_band/sources/end_observation_leituras_test.exs`, dois tenants. **Defeito a
    injetar**: apagar por `tenant_id` só; a leitura de outra organização do mesmo tenant some e o teste
    reprova

- [ ] T053 Conferir a tela contra o protótipo aprovado — QA e Design
  - **Pronta quando**: T020, T029, T033, T037, T040, T042, T044, T046, T048
  - **Descrição**: o QA, em par com o agente `design`, lê cada página entregue contra
    `prototipo/PROMPT.md` §3, item a item, com as divergências de `research.md` R21; telefone incluído
    (Tela 8). Registro em `docs/sprints/<sprint>/aceitacao.md`
  - **Feita quando**: cada item tem *conforme*, *divergência aprovada (R21)* ou *defeito*, com a
    captura; defeito vira tarefa antes do merge
  - **Teste**: a tabela item a item, com as imagens (L73: a prova de tela é a imagem)

- [ ] T054 👤 Aceitar contra a origem (SC-001, SC-006)
  - **Pronta quando**: T053; uma organização real com leitura
  - **Descrição**: a pessoa mantenedora conta à mão, na origem, as issues abertas na janela, as
    designações e as exclusões por motivo, e compara com a tela; e responde, a partir da tela, *"quais
    grupos se formam e quem os liga?"* em menos de dois minutos
  - **Feita quando**: as contagens batem sem diferença, ou a diferença está explicada e aceita por
    escrito; o tempo da pergunta está registrado
  - **Teste**: o registro na issue, com os números dos dois lados

- [ ] T055 Rodar os gates e abrir o PR
  - **Pronta quando**: todas as anteriores, exceto as 👤 que esperam produção
  - **Descrição**: `mix gates` com o código de saída lido sem pipe; auditoria contra a origem
    (`git status --short` primeiro); PR para `development` com o template inteiro, revisor equipe
    `the-band`, no projeto com Iteration e `Status = In review` conferidos, tipo de merge declarado,
    `Sprint:` preenchido
  - **Feita quando**: `mix gates` `EXIT=0`; `gh pr view --json reviewRequests` não vazio; `mix.lock` e
    `assets/package.json` sem diferença contra `development`
  - **Teste**: os comandos e códigos de saída no comentário da issue

---

## Dependências

```text
Fase 1 (T001–T003) ── T002 só bloqueia T027; T003 só bloqueia o merge (via T050)
Fase 2 (T004–T017) ── bloqueia todas as US
US1 (T018–T020)    ── depende de T017; independente das outras US       🎯 MVP
US2 (T021–T029)    ── depende da Fase 2
US3 (T030–T034)    ── depende de US2 (T029 é a página Graph)
US4 (T035–T037)    ── depende de US3 (o grafo de comunidades)
US5 (T038–T040)    ── depende da Fase 2 e de T030
US6 (T041–T042)    ── depende de T036 (os aleatórios) e T038
US7 (T043–T044)    ── depende de US6
US8 (T045–T046)    ── depende de US5 (T040)
US9 (T047–T048)    ── depende de T045
Acabamento         ── T049 depois dos algoritmos; T053–T055 no fim
```

## Paralelismo

- **Fase 2**: T004, T005, T009, T010, T011, T012 e T015 em paralelo (arquivos diferentes);
- **algoritmos**: T030, T031, T035, T038, T039 e T045 em paralelo depois de T012;
- **US2**: T021 e T025 em paralelo; T023 depois de T021;
- **acabamento**: T051 e T052 em paralelo, a qualquer momento depois das dependências.

## Estratégia de entrega

1. **MVP = Fase 2 + US1**: a área no menu com a rede de revisão da 073 dentro. Visível, sem esperar
   algoritmo;
2. **US2 + US3**: a rede de designação com o grafo ponderado — o primeiro grafo pedido;
3. **US4 + US5**: comunidades e hubs — o que o pedido cita por nome;
4. **US6 + US7 + US8 + US9**: o resto da análise da referência;
5. cada fatia com a tela e o backend juntos (princípio VI); o PR único do épico pode ser fatiado em
   PRs empilhados pela ordem acima, com merge commit (§12).

## Contagem

| fase | tarefas |
|---|---|
| Setup | 3 (T001–T003) |
| Fundação | 14 (T004–T017) |
| US1 | 3 (T018–T020) |
| US2 | 9 (T021–T029) |
| US3 | 5 (T030–T034) |
| US4 | 3 (T035–T037) |
| US5 | 3 (T038–T040) |
| US6 | 2 (T041–T042) |
| US7 | 2 (T043–T044) |
| US8 | 2 (T045–T046) |
| US9 | 2 (T047–T048) |
| Acabamento | 7 (T049–T055) |
| **Total** | **55** |
