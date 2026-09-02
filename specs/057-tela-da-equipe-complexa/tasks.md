---

description: "Tarefas da feature 057 — a tela da equipe, e a equipe feita de equipes"
---

# Tasks: A tela da equipe, e a equipe feita de equipes

**Input**: documentos de desenho em `/specs/057-tela-da-equipe-complexa/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/](contracts/medidas-de-equipe.md)

**Testes**: cada tarefa carrega o seu, no campo `Teste`.

**Nenhuma migração.** A feature não cria tabela nem coluna.

**A fase 3 vai sozinha num PR** — ela muda números já exibidos, e misturá-la com
tela nova tornaria impossível saber se uma diferença veio da correção ou da
feature.

---

## Phase 1: Setup

- [ ] T001 [#721](https://github.com/The-Band-Solution/theband/issues/721) Fixtures de equipe com período de vínculo
  - **Pronta quando**: nada além do repositório; as fixtures da feature 055 já
    produzem equipe declarada e composição
  - **Descrição**: em `test/support/fixtures/`, acrescentar helpers que criam
    vínculo com `started_at`, `ended_at` e `invalidated_at` controlados, e issues
    com `external_created_at` / `external_closed_at` em datas escolhidas. Sem
    isso, nenhum cenário de período é escrevível — e os cenários de período são a
    feature inteira
  - **Feita quando**: um teste consegue montar, em três linhas, uma equipe com
    pessoa que entrou em janeiro e saiu em março, com trabalho fechado antes e
    depois; e as issues criadas ficam ligadas ao tenant informado
  - **Teste**: `test/support/fixtures/eo_fixtures_test.exs` — o vínculo criado com
    `ended_at` no passado não aparece em `count_team_members_at/3` para uma data
    posterior

---

## Phase 2: Foundational — bloqueia todas as user stories

- [ ] T002 [#722](https://github.com/The-Band-Solution/theband/issues/722) Consultar quem pertencia numa data
  - **Pronta quando**: o contrato em `contracts/medidas-de-equipe.md` está escrito
    (está); T001 concluída
  - **Descrição**: `EO.team_members_at/3` em
    `lib/the_band/ontology/seon/eo/queries.ex`, exposta em `eo.ex`. A vigência tem
    **três** condições e a borda é `[started_at, ended_at)` — a mesma de
    `count_team_members_at/3`, que fica ao lado. Extrair o fragmento de vigência
    para função privada reusada pelas duas, para não existir uma segunda definição
    de "vigente" (R5, D3)
  - **Feita quando**: a função devolve os membros ordenados por nome; vínculo
    invalidado não aparece em data nenhuma; quem sai num dia e entra em outra
    equipe no mesmo dia conta em **uma** só
  - **Teste**: `test/the_band/ontology/seon/eo/queries_test.exs` — caso da borda:
    vínculo `[2026-01-10, 2026-03-15)` aparece em `2026-03-14T23:59` e **não**
    aparece em `2026-03-15T00:00`

- [ ] T003 [P] [#723](https://github.com/The-Band-Solution/theband/issues/723) Expor só os ids dos membros na data
  - **Pronta quando**: T002 concluída
  - **Descrição**: `EO.team_member_ids_at/3`, mesma regra de vigência, devolvendo
    apenas os ids. Existe porque quem monta consulta de trabalho não usa os nomes,
    e carregá-los seria trabalho jogado fora em toda chamada
  - **Feita quando**: devolve exatamente os mesmos ids que `team_members_at/3`
    devolveria, na mesma ordem
  - **Teste**: `queries_test.exs` — igualdade entre
    `Enum.map(team_members_at(...), & &1.person_id)` e `team_member_ids_at(...)`

- [ ] T004 [P] [#724](https://github.com/The-Band-Solution/theband/issues/724) Declarar as medidas novas na base de conhecimento
  - **Pronta quando**: nada além do repositório
  - **Descrição**: em `priv/knowledge_base/`, declarar as medidas que a feature
    apresenta — o burn com linha de base e a previsão — cada uma ligada a uma
    necessidade de informação, com **limitações e interpretações incorretas**, como
    o princípio IV exige. As limitações já estão escritas na spec: não há escopo
    comprometido; "fechado" é o ato da ferramenta; a previsão assume que o período
    à frente se parece com o observado; o tempo em tarefa conta da abertura
  - **Feita quando**: as medidas existem em YAML com os campos de limitação
    preenchidos, e nenhuma delas aparece na tela sem estar declarada aqui
  - **Teste**: `mix knowledge.validate` e `mix knowledge.test` verdes, e
    `mix knowledge.graph` sem aresta nova de ontologia

---

## Phase 3: User Story 1 — A medida conta só enquanto a pessoa pertenceu (P1) 🎯 MVP

**Objetivo**: os números da tela param de contar quem saiu, e o passado para de
se reescrever.

**Teste independente**: declarar equipe com três pessoas, registrar saída com data
no passado, conferir que o trabalho conta até a saída; anotar os meses fechados,
registrar outra saída, conferir que os meses fechados **não mudaram**.

### Implementação da User Story 1

- [ ] T005 [US1] [#725](https://github.com/The-Band-Solution/theband/issues/725) Passar a data para as competências da equipe
  - **Pronta quando**: T002 concluída
  - **Descrição**: em `lib/the_band/profiles/team_skills.ex`, `membros/2` vira
    `membros/3` recebendo a data e chamando `EO.team_members_at/3` no lugar de
    `list_team_members(..., include_no_longer_observed: false)`. `coverage/2`
    delega para `coverage/3` com o instante atual; o tipo `coverage()` **não muda**
    (R9, contrato §4)
  - **Feita quando**: uma pessoa com vínculo encerrado deixa de aparecer na
    cobertura de hoje; o trabalho que ela concluiu antes da saída continua contando
    para a equipe; a assinatura antiga continua funcionando
  - **Teste**: `test/the_band/profiles/team_skills_test.exs` — vínculo encerrado em
    2026-03-15, issue fechada em 03-10 conta e a de 04-02 não

- [ ] T006 [US1] [#726](https://github.com/The-Band-Solution/theband/issues/726) Recortar a evolução mês a mês
  - **Pronta quando**: T005 concluída
  - **Descrição**: `evolution/2` deixa de montar **um** conjunto de membros e
    aplicá-lo a todos os meses. Passa a chamar `membros/3` **uma vez por mês da
    série**, com o corte daquele mês. A série continua tendo um ponto por mês que
    teve geração de perfil, e não um por mês de calendário — interpolar afirmaria
    observação que não houve
  - **Feita quando**: uma pessoa que entrou em junho não aparece nos pontos
    anteriores a junho; uma pessoa que saiu em março aparece nos pontos até março e
    não depois
  - **Teste**: `team_skills_test.exs` — série com entrada em junho e saída em
    março, conferindo a presença mês a mês

- [ ] T007 [US1] [#727](https://github.com/The-Band-Solution/theband/issues/727) Provar que o passado não se reescreve
  - **Pronta quando**: T006 concluída
  - **Descrição**: o teste que corresponde ao **SC-002**, e o mais importante da
    feature. Capturar a série inteira, registrar uma saída com data em julho,
    recapturar, e comparar. É o mesmo defeito que o SC-003 da 055 proíbe no
    vínculo, e o teste tem a mesma forma
  - **Feita quando**: os pontos anteriores a julho são **idênticos** antes e
    depois; só julho em diante difere
  - **Teste**: `team_skills_test.exs` — `assert antes_de_julho(serie_1) ==
    antes_de_julho(serie_2)`, igualdade estrita

- [ ] T008 [P] [US1] [#728](https://github.com/The-Band-Solution/theband/issues/728) Apresentar a evidência não promovida em separado
  - **Pronta quando**: T005 concluída
  - **Descrição**: em `lib/the_band_web/live/teams_live/show.ex`, quem a origem
    lista sem vínculo declarado sai por `pending_evidence/2` — que já existe — e é
    apresentado **nomeado**, fora das contagens (FR-005). Depois de T005 essas
    pessoas somem dos números, e some-las da tela também as tornaria invisíveis
  - **Feita quando**: a pessoa observada sem vínculo aparece na tela com rótulo de
    evidência não promovida, e não é contada em nenhum indicador
  - **Teste**: `test/the_band_web/live/teams_live/show_test.exs` — o nome aparece
    no HTML e a contagem de membros não a inclui

**Checkpoint**: a US1 é entregável sozinha. Números corrigidos, nenhuma tela nova.

---

## Phase 4: User Story 2 — A equipe complexa mostra suas equipes, uma a uma (P1)

**Objetivo**: comparar subequipes sem nunca somá-las.

**Teste independente**: compor equipe com duas subequipes que compartilham uma
pessoa; conferir que nenhum número é a soma das linhas, que a tela diz por quê, e
que o clique leva à tela da subequipe.

### Implementação da User Story 2

- [ ] T009 [US2] [#729](https://github.com/The-Band-Solution/theband/issues/729) Descobrir se a equipe é composta
  - **Pronta quando**: T002 concluída; `team_parts/2` já existe da feature 055
  - **Descrição**: em `show.ex`, carregar as partes vigentes com `EO.team_parts/2`.
    Composição **encerrada** não entra (FR-013). Uma parte só **não** é equipe
    composta para efeito desta tela — segue como equipe simples com composição
    declarada
  - **Feita quando**: equipe com duas ou mais partes vigentes entra no caminho
    composto; equipe com zero ou uma parte segue no caminho simples, sem seção
    vazia
  - **Teste**: `show_test.exs` — três equipes de exemplo (0, 1 e 3 partes),
    conferindo qual caminho cada uma toma

- [ ] T010 [US2] [#730](https://github.com/The-Band-Solution/theband/issues/730) Montar a linha de indicadores de uma equipe
  - **Pronta quando**: T002 e T009 concluídas
  - **Descrição**: a estrutura `linha_de_subequipe` de `data-model.md` — membros,
    abertas, fechadas na janela, paradas, e `sem_trabalho?`. O booleano existe para
    separar **zero observado** de **ausência** (FR-012): a tela usa o booleano, e
    não infere ausência de um zero
  - **Feita quando**: cada subequipe produz uma linha; a equipe produz também a
    linha dos membros diretos, marcada como tal; nenhuma função devolve um campo de
    total
  - **Teste**: `show_test.exs` — a estrutura devolvida para três subequipes tem
    quatro linhas e nenhuma chave `total`

- [ ] T011 [US2] [#731](https://github.com/The-Band-Solution/theband/issues/731) Tela da equipe composta, sem total
  - **Pronta quando**: T010 concluída
  - **Descrição**: renderizar uma linha por subequipe mais a dos diretos, cada uma
    ligando à tela daquela subequipe (FR-010). **Nenhum gráfico** aqui (FR-011): a
    tela é de comparação, e comparação se faz em números alinhados. Números em
    fonte tabular, para as colunas alinharem
  - **Feita quando**: o HTML renderizado não contém cabeçalho de coluna com
    `total`, `sum` ou `combined`; cada linha tem link para `/teams/:id` da
    subequipe; nenhum `<svg>` aparece na tela composta
  - **Teste**: `show_test.exs` — varredura do HTML por essas três palavras e por
    `<svg>`, todas ausentes

- [ ] T012 [P] [US2] [#732](https://github.com/The-Band-Solution/theband/issues/732) Dizer por que as linhas não somam
  - **Pronta quando**: T011 concluída
  - **Descrição**: texto na tela nomeando a causa (FR-009): a mesma pessoa pode
    estar em duas subequipes e a mesma tarefa aparecer nas duas. Sem o texto, a
    ausência de total parece esquecimento e alguém acrescenta o total depois
  - **Feita quando**: o texto está visível na tela composta e nomeia as duas
    causas — pessoa e tarefa
  - **Teste**: `show_test.exs` — o HTML contém a explicação, e ela cita as duas
    causas

- [ ] T013 [P] [US2] [#733](https://github.com/The-Band-Solution/theband/issues/733) Nomear a subequipe sem trabalho
  - **Pronta quando**: T010 concluída
  - **Descrição**: linha de subequipe com `sem_trabalho?: true` é apresentada com
    ausência dita em texto, **nunca com zero** (FR-012)
  - **Feita quando**: a subequipe sem trabalho no período aparece na tela com
    texto de ausência, e nenhum `0` no lugar dos indicadores
  - **Teste**: `show_test.exs` — subequipe sem issues; o HTML da linha não contém
    `0` nas células de indicador

---

## Phase 5: User Story 3 — O detalhe da subequipe (P2)

**Objetivo**: o destino do clique responde as quatro perguntas.

**Teste independente**: abrir subequipe com trabalho aberto, fechado e
enfileirado; conferir que as seções trazem itens distintos e que a série cobre o
período declarado.

### Implementação da User Story 3

- [ ] T014 [US3] [#734](https://github.com/The-Band-Solution/theband/issues/734) Série semanal da equipe, recortada pelo vínculo
  - **Pronta quando**: T002 concluída; o contrato §2 está escrito
  - **Descrição**: `WorkItems.team_state_changes_by_period/4` em
    `lib/the_band/work_items/queries.ex`. A vigência entra como **junção** avaliada
    contra a data do evento — `external_created_at` na série de criadas,
    `external_closed_at` na de fechadas —, e não como lista de ids (R5, D3). É o
    que faz SC-002 valer também aqui. Formato de período com ano **ISO**
    (`IYYY-"W"IW`), nunca civil
  - **Feita quando**: uma issue fechada depois da saída de quem a tinha não aparece
    na série; registrar uma saída hoje não altera nenhuma semana anterior à saída;
    a semana de 29/12 recebe o rótulo do ano ISO
  - **Teste**: `test/the_band/work_items/team_series_test.exs` — série capturada,
    saída registrada, série recapturada; igualdade estrita nas semanas anteriores

- [ ] T015 [US3] [#735](https://github.com/The-Band-Solution/theband/issues/735) Contar uma vez a issue de duas pessoas
  - **Pronta quando**: T014 concluída
  - **Descrição**: `DISTINCT` na issue dentro de `team_state_changes_by_period/4`
    (R4). Item atribuído a duas pessoas **da mesma equipe** é um item só para a
    equipe. É o oposto da regra por pessoa, e é a razão de FR-008 proibir somar as
    linhas de subequipe — a tarefa e o texto de T012 falam do mesmo fato
  - **Feita quando**: a série da equipe conta **1** para a issue compartilhada,
    enquanto as linhas por pessoa contam **2**
  - **Teste**: `team_series_test.exs` — issue com dois designados da mesma equipe;
    `assert serie_da_equipe == 1` e `assert soma_por_pessoa == 2`

- [ ] T016 [US3] [#736](https://github.com/The-Band-Solution/theband/issues/736) Seções do que faz, fez, e vem a seguir
  - **Pronta quando**: T014 concluída
  - **Descrição**: em `show.ex`, três seções distintas listando itens
    identificáveis com link para a issue (FR-014). A ordem é a da spec: fazendo,
    feito, a seguir, e depois o que a equipe sabe
  - **Feita quando**: as três seções aparecem com itens distintos; seção sem itens
    diz isso em texto e não mostra zero
  - **Teste**: `show_test.exs` — subequipe com um item em cada estado; os três
    títulos e os três identificadores aparecem no HTML

- [ ] T017 [P] [US3] [#737](https://github.com/The-Band-Solution/theband/issues/737) Separar semana zerada de semana não coletada
  - **Pronta quando**: T014 concluída
  - **Descrição**: semana sem movimento **dentro** do período coletado vem com zero
    nas duas séries; semana **fora** do período coletado não aparece (FR-016). A
    diferença é entre "observamos e não houve" e "não observamos"
  - **Feita quando**: a série tem um ponto para toda semana do período coletado,
    inclusive as vazias; e nenhum ponto fora dele
  - **Teste**: `team_series_test.exs` — janela de 8 semanas com duas vazias no
    meio; a série tem 8 pontos, e não 6

---

## Phase 6: User Story 4 — O que cada pessoa está fazendo, e o que demonstrou (P2)

**Objetivo**: todas as tarefas de cada pessoa, e as habilidades com sua
proveniência.

**Teste independente**: duas tarefas abertas para a mesma pessoa aparecem as duas,
com tempos distintos, sem que nenhuma seja eleita a atual.

### Implementação da User Story 4

- [ ] T018 [US4] [#738](https://github.com/The-Band-Solution/theband/issues/738) Todas as tarefas abertas de cada pessoa
  - **Pronta quando**: T002 concluída; o contrato §2 está escrito
  - **Descrição**: `WorkItems.team_open_tasks_by_person/3`, **uma consulta** para a
    equipe inteira. `aberta_ha_dias` conta da **abertura do item** — a origem não
    registra quando a atribuição aconteceu (R1), e FR-019a proíbe apresentar tempo
    de atribuição. Pessoa sem tarefa entra no mapa com lista **vazia**; chave
    ausente significa que não é da equipe
  - **Feita quando**: pessoa com duas tarefas devolve as duas; pessoa sem tarefa
    aparece com `[]`; nenhuma função elege uma tarefa como atual
  - **Teste**: `team_series_test.exs` — mapa com uma pessoa de duas tarefas e outra
    de nenhuma; a segunda tem chave presente e lista vazia

- [ ] T019 [P] [US4] [#739](https://github.com/The-Band-Solution/theband/issues/739) Marcar a tarefa parada, e dizer o que a marca é
  - **Pronta quando**: T018 concluída
  - **Descrição**: `parada?` quando passa de 90 dias desde a abertura (FR-020). A
    tela mostra a marca **e** o texto de que ela é convite a perguntar, não
    veredito — e declara que o tempo conta da abertura, porque a origem não informa
    quando a pessoa assumiu
  - **Feita quando**: tarefa aberta há 91 dias recebe marca; a de 89 não; o texto
    sobre o significado da marca e sobre a origem do tempo está na tela
  - **Teste**: `show_test.exs` — duas tarefas nas bordas do limiar, e a presença
    dos dois textos no HTML

- [ ] T020 [US4] [#740](https://github.com/The-Band-Solution/theband/issues/740) Habilidades demonstradas com marca de derivada
  - **Pronta quando**: T005 concluída
  - **Descrição**: seção própria em `show.ex`, por pessoa, na gramática da tela de
    pessoa — pílulas com marca `derived` e fundo hachurado, porque são conclusão
    lida do trabalho concluído e não registro (FR-022). Consome o perfil vigente
    já existente; **não** define piso próprio (R8)
  - **Feita quando**: cada habilidade carrega a marca de derivada; a seção declara
    que habilidade ausente significa não observada aqui, nunca incapacidade
    (FR-024)
  - **Teste**: `show_test.exs` — contagem de pílulas igual à contagem de marcas de
    derivada, e o texto sobre ausência presente

- [ ] T021 [P] [US4] [#741](https://github.com/The-Band-Solution/theband/issues/741) Dizer por que alguém não tem habilidade listada
  - **Pronta quando**: T020 concluída
  - **Descrição**: pessoa com material abaixo do piso devolve
    `{:abaixo_do_piso, %{fechadas: n, exigidas: n}}` — o relator, e não lista vazia.
    Lista vazia responde "nenhuma habilidade", que é afirmação diferente de "não
    havia material para ler" (FR-023)
  - **Feita quando**: a pessoa aparece na seção **sem** nenhuma pílula e **com** o
    motivo escrito, citando quantas fechou e quantas seriam necessárias
  - **Teste**: `show_test.exs` — pessoa com duas issues fechadas; nenhuma pílula
    para ela, e o motivo no HTML

- [ ] T022 [P] [US4] [#742](https://github.com/The-Band-Solution/theband/issues/742) Ver a equipe sem poder administrá-la
  - **Pronta quando**: T011 concluída
  - **Descrição**: conferir que a leitura da tela **não** exige escopo de
    administrar equipes (FR-039) — administrar não é ver. Os controles de declarar,
    compor e registrar saída continuam restritos
  - **Feita quando**: pessoa sem escopo abre a tela e lê tudo; os controles de
    escrita não aparecem para ela
  - **Teste**: `show_test.exs` — dois usuários, um com escopo e outro sem; ambos
    veem os indicadores, só o primeiro vê os formulários

---

## Phase 7: User Story 5 — Burn-up e burn-down (P2)

**Objetivo**: o que resta lido como a distância entre as curvas.

**Teste independente**: com série conhecida, a diferença entre as curvas em
qualquer semana é igual à contagem de itens em aberto naquela semana.

### Implementação da User Story 5

- [ ] T023 [US5] [#743](https://github.com/The-Band-Solution/theband/issues/743) Contar o trabalho aberto no início da janela
  - **Pronta quando**: T002 concluída; o contrato §2 está escrito
  - **Descrição**: `WorkItems.team_open_at/3` — criados até a data, não fechados
    até a data, de quem pertencia na data. É a **linha de base** de FR-026a. Sem
    ela a distância entre as curvas mede só os itens nascidos na janela, e uma
    equipe com 40 itens abertos há meses apareceria com distância zero (R2)
  - **Feita quando**: devolve a contagem correta para uma data no passado, e
    respeita a vigência do vínculo naquela data
  - **Teste**: `team_series_test.exs` — 12 issues abertas antes da janela; a função
    devolve 12 para a data de início

- [ ] T024 [US5] [#744](https://github.com/The-Band-Solution/theband/issues/744) Acumular o burn a partir da linha de base
  - **Pronta quando**: T023 concluída
  - **Descrição**: `PersonWork.burn/2` recebendo `aberto_inicial`, com `burn/1`
    delegando com `0`. Função **pura**, sem consulta. A página da pessoa **não
    muda** nesta feature — a limitação dela vira item de backlog em T032 (D2)
  - **Feita quando**: `aberto(t) == aberto_inicial + criadas(t₀..t) −
    fechadas(t₀..t)` em todo ponto; `burn/1` devolve exatamente o que devolvia
    antes
  - **Teste**: `test/the_band/work_items/person_work_test.exs` — linha de base 12,
    6 criadas e 4 fechadas na janela; `aberto` final é 14, e bate com a contagem
    direta de issues em aberto naquela data

- [ ] T025 [US5] [#745](https://github.com/The-Band-Solution/theband/issues/745) Desenhar o que resta como faixa, nunca como linha
  - **Pronta quando**: T024 concluída
  - **Descrição**: na tela da subequipe, duas séries num **único eixo** — nunca
    dois eixos —, e o que resta como a **região entre elas**, hachurada porque é
    derivada (FR-027). O campo `aberto` existe e é o mesmo número que a altura da
    faixa representa; o que a regra proíbe é apresentá-lo como terceira série
  - **Feita quando**: o gráfico tem duas `polyline` e um `polygon` hachurado, e não
    três `polyline`; há um só eixo de valores
  - **Teste**: `show_test.exs` — contagem de elementos no SVG renderizado

- [ ] T026 [P] [US5] [#746](https://github.com/The-Band-Solution/theband/issues/746) Declarar o que o burn não responde
  - **Pronta quando**: T025 concluída; T004 concluída
  - **Descrição**: os dois textos que a spec exige (FR-029, FR-030): não há escopo
    comprometido, então o gráfico não responde se um sprint termina; e "fechado" é
    o ato registrado na ferramenta — item abandonado e item concluído entram
    iguais. Os mesmos textos que T004 declarou como limitações da medida
  - **Feita quando**: os dois textos estão na tela, e dizem o mesmo que a
    declaração em YAML
  - **Teste**: `show_test.exs` — os dois textos presentes no HTML

---

## Phase 8: User Story 6 — Uma previsão que diz sua confiança (P3)

**Objetivo**: previsão por simulação, sempre com confiança e nunca como data.

**Teste independente**: com histórico conhecido, a faixa de 85% cobre pelo menos
85% das simulações; abaixo do piso, a previsão é recusada com o que falta.

### Implementação da User Story 6

- [ ] T027 [US6] [#747](https://github.com/The-Band-Solution/theband/issues/747) Simular as duas hipóteses de entrega
  - **Pronta quando**: T014 concluída; o contrato §3 está escrito
  - **Descrição**: `TheBand.Forecast.monte_carlo/2` em `lib/the_band/forecast.ex`,
    módulo **puro** que não toca no banco. Duas hipóteses: escopo congelado sorteia
    só de `fechadas`; escopo vivo sorteia também de `criadas` e soma. Semente
    derivada dos dados de entrada, aplicada em processo isolado — sem isso o
    resultado muda entre duas leituras e FR-036 falha (R6)
  - **Feita quando**: as duas hipóteses saem com p50, p85, p95 e `nao_concluiram`;
    a mesma entrada devolve exatamente a mesma saída; percentil de hipótese cujas
    rodadas não concluíram vem `nil`, nunca um número grande
  - **Teste**: `test/the_band/forecast_test.exs` — `assert monte_carlo(s, aberto: 19)
    == monte_carlo(s, aberto: 19)`, igualdade estrita; e a faixa de 85% cobre ao
    menos 85% das rodadas

- [ ] T028 [P] [US6] [#748](https://github.com/The-Band-Solution/theband/issues/748) Recusar prever sem histórico
  - **Pronta quando**: T027 concluída
  - **Descrição**: menos de 6 períodos **ou** menos de 10 fechadas devolve
    `{:sem_historico, faltando}` (FR-034, R7). `faltando` traz o observado **e** o
    exigido, para a tela dizer o que falta em vez de só recusar. Com 3 semanas e 4
    fechamentos a faixa cobriria quase todo o horizonte, e rotulá-la de 85%
    emprestaria autoridade a ruído
  - **Feita quando**: as duas condições do piso recusam separadamente; a estrutura
    devolvida traz os quatro números
  - **Teste**: `forecast_test.exs` — série de 3 semanas com 4 fechadas devolve
    `{:sem_historico, %{semanas: 3, semanas_exigidas: 6, fechadas: 4,
    fechadas_exigidas: 10}}`

- [ ] T029 [US6] [#749](https://github.com/The-Band-Solution/theband/issues/749) Apresentar a faixa, nunca a data
  - **Pronta quando**: T027 e T028 concluídas; T004 concluída
  - **Descrição**: na tela, cada resultado com sua confiança, e nenhum texto
    apresentando valor como data prometida (FR-033). Quando a maioria das rodadas
    não termina, apresentar a **proporção** (FR-035) — omitir transformaria "quase
    nunca termina" em "termina em poucas semanas". Sem histórico, mostrar o que
    falta e nenhuma faixa
  - **Feita quando**: os três estados aparecem corretamente — com previsão, sem
    histórico, e com maioria não concluída; o texto declara o que a simulação
    assume (FR-037)
  - **Teste**: `show_test.exs` — três equipes de exemplo, uma por estado; e o HTML
    não contém data absoluta em nenhum deles

---

## Phase 9: Polish & Cross-Cutting

- [ ] T030 [P] [#750](https://github.com/The-Band-Solution/theband/issues/750) Provar o isolamento entre tenants
  - **Pronta quando**: T014, T018 e T023 concluídas
  - **Descrição**: dois tenants povoados ao mesmo tempo, cada um com equipe de
    mesmo nome e issues próprias. Exigido pelo princípio V e por FR-038 — consulta
    sem tenant é bug de segurança, não de correção
  - **Feita quando**: nenhuma das funções novas devolve linha do outro tenant
  - **Teste**: `team_series_test.exs` — um caso por função pública nova, cada um
    com os dois tenants povoados

- [ ] T031 [P] [#751](https://github.com/The-Band-Solution/theband/issues/751) Medir o teto de consultas das duas telas
  - **Pronta quando**: T011 e T029 concluídas
  - **Descrição**: contar as consultas por render e conferir contra o teto do
    plano — 9 na tela da subequipe, 4 + 3 por subequipe na composta. O teto vira
    teste, e não anotação: sem ele a próxima seção acrescentada passa despercebida
  - **Feita quando**: o teste falha se o número subir
  - **Teste**: `show_test.exs` — contagem via telemetria do Ecto nos dois caminhos

- [ ] T032 [P] [#752](https://github.com/The-Band-Solution/theband/issues/752) Registrar no backlog a limitação da página da pessoa
  - **Pronta quando**: T024 concluída
  - **Descrição**: em `docs/backlog/`, registrar que a página da pessoa acumula o
    burn a partir de zero e tem a mesma limitação que T023 corrige para a equipe
    (R2). **Não corrigir aqui**: exige critério de revisão próprio e tem teto de
    consultas próprio, medido em `person_detail_test.exs`. Declarada, não escondida
  - **Feita quando**: o documento existe, nomeia a função, o efeito e por que não
    foi corrigido agora; e está referenciado no índice do backlog
  - **Teste**: revisão — o item cita `burn/1`, o efeito de subestimar o trabalho
    aberto, e o teto de consultas como motivo do adiamento

- [ ] T033 [#753](https://github.com/The-Band-Solution/theband/issues/753) Fechar os gates e abrir o PR
  - **Pronta quando**: T001 a T032 concluídas
  - **Descrição**: `mix gates` é a definição única — o veredito é o **código de
    saída dela**, e qualquer comando depois o substitui. PR com resumo na frente e
    as issues depois, mirando `development`, com revisão independente (princípio
    VII)
  - **Feita quando**: `mix gates` sai com código 0; o PR está aberto com revisor
    pedido; o texto declara o que a fase 3 muda nos números já exibidos, com antes
    e depois medidos em dado real
  - **Teste**: `echo $?` imediatamente após `mix gates`, e o PR aberto com
    revisor atribuído

---

## As issues

Criadas em 2026-09-02. Toda tarefa tem issue — nenhuma pendência de link.

| User story | Issue | Tarefas |
|---|---|---|
| US1 | [#715](https://github.com/The-Band-Solution/theband/issues/715) | T005–T008 |
| US2 | [#716](https://github.com/The-Band-Solution/theband/issues/716) | T009–T013 |
| US3 | [#717](https://github.com/The-Band-Solution/theband/issues/717) | T014–T017 |
| US4 | [#718](https://github.com/The-Band-Solution/theband/issues/718) | T018–T022 |
| US5 | [#719](https://github.com/The-Band-Solution/theband/issues/719) | T023–T026 |
| US6 | [#720](https://github.com/The-Band-Solution/theband/issues/720) | T027–T029 |

Setup e Foundational (T001–T004) e Polish (T030–T033) não pertencem a user
story: são pré-requisito e fechamento.

Faixa completa: [#721](https://github.com/The-Band-Solution/theband/issues/721) a [#753](https://github.com/The-Band-Solution/theband/issues/753).

---

## Dependencies & Execution Order

### Entre fases

```text
Phase 1 (Setup)
   └─→ Phase 2 (Foundational) ──→ bloqueia TUDO
          ├─→ Phase 3 (US1) ── PR próprio, sozinho
          ├─→ Phase 4 (US2)
          ├─→ Phase 5 (US3) ──→ Phase 8 (US6)
          ├─→ Phase 6 (US4)
          └─→ Phase 7 (US5)
                 └─→ Phase 9 (Polish)
```

### Entre user stories

- **US1** não depende de nenhuma outra, e todas dependem dela **em correção** — as
  demais podem ser escritas em paralelo, mas nenhuma deve ser entregue antes
- **US2** depende só da fundação
- **US3** depende da fundação; **US6** depende da série de US3
- **US4** e **US5** dependem da fundação, e são independentes entre si

### Oportunidades de paralelismo

- T003 e T004 juntas, depois de T002
- T012, T013 juntas, depois de T010
- T019, T021, T022 juntas
- T030, T031, T032 juntas, no fim

## Implementation Strategy

### MVP — só a US1

A fase 3 sozinha já entrega valor: os números da tela param de mentir sobre quem
saiu, e param de reescrever o passado. **Vai num PR próprio** — misturá-la com tela
nova tornaria impossível saber se uma diferença veio da correção ou da feature.

### Entrega incremental

1. Fases 1–3 → PR 1 — a correção
2. Fases 4 → PR 2 — a equipe composta sem soma
3. Fases 5–7 → PR 3 — o detalhe da subequipe, com as pessoas e o burn
4. Fase 8 → PR 4 — a previsão
5. Fase 9 → junto com o último PR

## Notes

- **33 tarefas**, 6 user stories, nenhuma migração
- Toda tarefa tem `Pronta quando`, `Descrição`, `Feita quando` e `Teste`
- Nenhum `Teste` é `mix test` sozinho — cada um nomeia arquivo, caso ou asserção
- **T007 é a tarefa mais importante da feature**: se o passado se reescreve,
  nenhum outro número importa
