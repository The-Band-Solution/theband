# Tasks: Pessoas e equipes separadas por organização observada

**Feature**: 002-escopo-por-organizacao | **Branch**: `002-escopo-por-organizacao` | **Data**: 2026-08-10

**Entrada**: [spec.md](spec.md) · [ontology-analysis.md](ontology-analysis.md) ·
[plan.md](plan.md) · [research.md](research.md) · [data-model.md](data-model.md) ·
[contracts/](contracts/) · [quickstart.md](quickstart.md)

**Testes**: cada tarefa carrega o seu, no campo `Teste`. Não há tarefa sem forma
de demonstrar que ficou pronta.

**A ordem importa mais que o normal nesta feature.** O achado F1 é a causa raiz:
as colunas que deveriam carregar o vínculo não existem no modelo derivado. Toda
tarefa que dependa da coluna vem **depois** de ela passar a ser derivada.

---

## Phase 1 — Ontologia

Nada de esquema nem de código antes disto. A coluna precisa ter lastro
conceitual antes de existir.

- [x] T001 Declarar equipe pertence a organização
  - **Pronta quando**: nada além do repositório — a análise ontológica já decidiu
    a forma em F4
  - **Descrição**: acrescentar `eo.organizational_team_belongs_to_organization` em
    `priv/knowledge_base/ontology/seon/eo/modules/organizational_structure.yaml`,
    com `source: eo.organizational_team`, `target: eo.organization`,
    `type: association` e cardinalidade `many → one`. **Associação, não
    `part_whole`** — declará-la como parthood faria o derivador gerar a coluna sem
    esforço e apagaria a distinção entre unidade organizacional, que é parte, e
    equipe, que é coletivo (risco R1) — FR-001
  - **Feita quando**: a relação parte do **subkind**, não de `eo.team`; a base
    continua válida e o grafo de dependências íntegro
  - **Teste**: `test/the_band/ontology/knowledge_base_eo_test.exs` — a relação
    existe, sai de `eo.organizational_team`, é `association`, é `many → one`, e
    declara proveniência própria. Mais três testes de violação: unidade
    organizacional continua `part_whole`, nenhuma outra relação liga equipe a
    organização, e `eo.team` **não** recebeu a relação
  - **Correção de tarefa.** O teste original mandava conferir a relação "na saída de
    `mix knowledge.graph`". A task imprime **uma linha** sobre integridade de
    dependências entre ontologias e nunca lista relações — o teste era
    inverificável, e passá-lo seria declarar sucesso sem olhar o que importa.
    Substituído por teste que trava as três decisões da relação. Verificado nos dois
    sentidos: com `part_whole` no lugar de `association`, falha
  - **Fora do previsto, e necessário.** `schemas/module.schema.yaml` passou a admitir
    `provenance` em relação — antes só em ontologia, módulo e conceito. Sem isso a
    relação nova ficaria indistinguível das que SEON declara, e a proveniência do
    módulo, `reference_ontology`, passaria a cobrir algo que não é da referência.
    Nenhuma das 143 relações anteriores carrega proveniência; esta é a primeira, e é
    a primeira que precisa

- [x] T002 [P] Criar as perguntas de competência de EO
  - **Pronta quando**: T001 concluída
  - **Descrição**: primeiro arquivo de `competency_questions/` de EO — a ontologia
    não tem nenhuma hoje (F7). Três perguntas: quais pessoas foram observadas em
    uma organização, a quais organizações uma pessoa está vinculada, e quais
    equipes pertencem a uma organização. Cada uma declara conceitos e relações
    envolvidos, como as de SRO — FR-013
  - **Feita quando**: as três citam apenas conceitos e relações que existem em EO;
    nenhuma depende de dado semeado para ser verificável
  - **Teste**: `mix knowledge.validate` aceita o arquivo, e cada pergunta referencia
    relação declarada — inclusive a de T001

- [x] T003 [P] Reprovar mapeamento com relação inexistente
  - **Pronta quando**: T001 concluída
  - **Descrição**: `scripts/validate_knowledge_base.py` passa a conferir que toda
    relação declarada em `relations:` de um mapeamento aponta para relação
    existente na ontologia de destino. É a validação que faltava: os mapeamentos
    de equipe e de pessoa declaravam vínculo com `eo.organization` sem que a
    relação existisse, e nada avisou (F6) — FR-012
  - **Feita quando**: o validador reprova um mapeamento que declare relação
    inexistente, nomeando qual
  - **Teste**: três verificações, todas executadas. Conceito inventado no
    `target_concept` reprova nomeando-o. Vínculo sem lastro cuja limitação é
    **genérica** reprova. Base restaurada volta a passar
  - **A tarefa dizia "a base atual continua passando", e não continuava.** A
    verificação encontrou **12 vínculos sem lastro**, não um: `eo.person →
    eo.organization` em `user.yaml`, que é o defeito do F6, mais onze em CMPO, CIRO,
    CDRO, QAPO e um em EO. Dois eram falso positivo meu — o check subia por
    `specializes` quando a base usa `parent` — e sobraram dez reais
  - **Três lastros aceitos, decisão da pessoa mantenedora.** O vínculo passa se há
    relação declarada, se há `derivation.rule_id` que o sustente, **ou** se
    `limitations` **nomeia o conceito** do outro lado. O terceiro reusa uma obrigação
    que a base já impõe a todo mapeamento em vez de inventar exceção, e mantém o gate
    verde sem tocar cinco ontologias que a análise excluiu do escopo. Exige o id de
    propósito: frase genérica passaria em qualquer mapeamento e o gate viraria carimbo
  - **`user.yaml` perdeu `relations.organization`**, como a análise prescreve, e
    ganhou duas limitações: EO não tem nem deve ter relação pessoa↔organização, e
    `organization.id` não existe no payload de um membro — a organização é o pai da
    consulta, não campo do nó

**Checkpoint**: a ontologia declara o vínculo, e o validador impede que um
mapeamento prometa relação que não existe.

---

## Phase 2 — Transformação

Bloqueia todo o esquema. A coluna só pode existir depois de a derivação produzi-la.

- [x] T004 Gerar chave estrangeira a partir de associação
  - **Pronta quando**: T001 concluída; o contrato
    `contracts/information-model.md` está escrito
  - **Descrição**: declarar a regra em
    `priv/knowledge_base/transformations/ontology_to_information_model.yaml` e
    implementá-la em `scripts/derive_information_model.py`. Associação com destino
    em kind e cardinalidade `many → one` vira FK na tabela do kind de origem.
    Quando a origem é subkind elevado, a FK é **anulável**, e a obrigatoriedade
    vira `check_constraint` ligada ao discriminador — research.md R3
  - **Feita quando**: `eo_teams` passa a trazer `organization_id` anotada como
    `association`, com o `check_constraint`; **a derivação de todas as outras
    ontologias sai idêntica** à de antes
  - **Teste**: guardar a saída atual de todas as ontologias, aplicar a mudança, e
    comparar — só EO pode diferir, e só pela coluna nova. É o V1 do quickstart.
    **Executado**: das 11 ontologias, só EO diferiu, e apenas por
    `organization_id NULL → FK (association)`, o `check` correspondente e a nota
  - **A regressão era impossível, e foi isso que ela revelou.** A primeira comparação
    acusou **dez das onze** ontologias como alteradas. Nenhuma havia mudado: três
    execuções do mesmo código sobre a mesma base davam três saídas diferentes.
    `owned` era um conjunto de strings, e iterá-lo varia entre execuções por
    randomização de hash — essa ordem decidia a ordem dos discriminadores, das notas
    e das colunas; `glob` somava a ordem do sistema de arquivos. Consertado com
    `sorted` nos quatro pontos, e o CI passou a derivar quatro ontologias duas vezes
    e comparar. Lição L17. O baseline foi então refeito com o código do `HEAD` mais o
    conserto e nada mais, e só aí a regra nova foi comparada
  - **Um defeito da minha própria regra, achado ao executar.** A primeira versão
    gerava `eo_people.person_id` — autorreferência — a partir de
    `eo.team_member_is_person`. `eo.team_member` é **papel** elevado a `eo.person`, e
    pela ADR 0004 D5/D6 papel materializa por relator, nunca por coluna: aquela
    relação é identidade, não referência. Dois guardas acrescentados, cada um
    suficiente por si — origem `role` não gera chave, e origem elevada ao próprio
    destino não gera chave

**Checkpoint**: a coluna existe no modelo derivado, com lastro na ontologia.

---

## Phase 3 — Esquema

Corrige o F1. Só agora, e nesta ordem.

- [x] T005 Reconferir que as colunas inventadas estão vazias
  - **Pronta quando**: T004 concluída
  - **Descrição**: contar registros com `eo_people.organization_id` ou
    `eo_teams.organization_id` preenchidos. A análise mediu 0 de 72 e 0 de 10, e o
    plano manda reconferir antes de migrar — remover coluna com dado dentro é
    perda silenciosa
  - **Feita quando**: as duas contagens deram zero, e o número está registrado no
    corpo da migração
  - **Teste**: a própria consulta; se devolver diferente de zero, a tarefa
    **para** e o caso vira decisão, não migração
  - **Executado em 2026-08-10**: `eo_people` 72 registros, **0** com
    `organization_id`; `eo_teams` 10 registros, **0**. Registrado no corpo da
    migração `20260810140000`

- [x] T006 Remover as colunas sem lastro
  - **Pronta quando**: T005 concluída com zero
  - **Descrição**: migração que remove `eo_people.organization_id` e a
    `eo_teams.organization_id` atual. `eo_people.organization_id` é
    semanticamente errada — a pessoa pertence a várias organizações, e a coluna
    alternaria de valor a cada coleta. Ambas foram escritas à mão contra a ADR
    0004 D4 (F1)
  - **Feita quando**: nenhuma das duas existe no banco; a migração tem `down`
    explícito
  - **Teste**: aplicar e reverter a migração, conferindo o esquema nos dois
    sentidos

- [x] T007 Receber a organização da equipe pela derivação
  - **Pronta quando**: T004 e T006 concluídas
  - **Descrição**: migração que cria `eo_teams.organization_id` **conforme a saída
    do derivador** — anulável, com `check_constraint` exigindo-a quando
    `type = 'organizational_team'`. Conferir contra a saída, não escrever de
    memória: é exatamente o erro que esta feature corrige — FR-001
  - **Feita quando**: a coluna e a restrição correspondem à saída do derivador;
    gravar equipe organizacional sem organização é recusado **pelo banco**
  - **Teste**: tentar inserir `type = 'organizational_team'` com `organization_id`
    nula e conferir que o banco recusa; com `project_team`, aceita
  - **A ordem da tarefa estava errada, e a execução provou.** Criar coluna e
    `check_constraint` juntos é impossível num banco povoado: as 10 equipes já
    coletadas são todas `organizational_team` com `organization_id` nula, e o Postgres
    recusou a restrição com `ERROR 23514 (check_violation)`. O retrofito que preenche a
    coluna é a T011, de outra fase
  - **A restrição ganhou migração própria, aplicada depois do retrofito** — e isso é
    melhor que um contorno: ela passa a ser **a verificação do retrofito**. Se
    qualquer equipe organizacional ficar sem organização, a migração se recusa a
    aplicar. Esta tarefa entrega a coluna conferida contra a saída do derivador; a
    recusa pelo banco vem com a restrição

- [x] T008 Admitir vínculo sem nível de acesso
  - **Pronta quando**: T007 concluída; `contracts/derived-team.md` escrito
  - **Descrição**: `eo_team_membership_evidence.platform_access_level` passa a ser
    anulável, com `check_constraint` exigindo-a quando `source_system = 'github'`.
    O vínculo derivado não tem nível porque a origem não conhece o vínculo —
    ausência é nula, e gravar `MEMBER` inventaria dado (research.md R2) — FR-006
  - **Feita quando**: vínculo com `source_system` da plataforma aceita nível nulo;
    vínculo do GitHub sem nível é recusado pelo banco
  - **Teste**: `test/the_band/ontology/seon/eo/constraints_test.exs`, três casos, os
    três pela violação — vínculo do GitHub sem nível é recusado; vínculo derivado sem
    nível é aceito **e o nível fica nulo**, não `MEMBER`; nível inventado é recusado
    mesmo em vínculo derivado. Conferidos também direto no banco, contra as duas
    `check_constraint`
  - **A regra vive nos dois lugares, de propósito.** O changeset recusa, e o
    `check_constraint` recusa — o segundo é o que vale quando a gravação não passa
    pelo changeset: script, console, correção manual

**Checkpoint**: esquema e modelo derivado voltam a corresponder.

---

## Phase 4 — US1 (P1): saber de qual organização veio cada registro

**Meta**: cada pessoa e cada equipe indicam a organização observada de origem.

**Teste independente**: com duas ou mais organizações coletadas, abrir a lista de
pessoas e conferir que cada linha indica a origem, e que quem está em duas mostra
as duas.

- [x] T009 [US1] Vincular a equipe à organização na coleta
  - **Pronta quando**: T007 concluída; `contracts/ontology-eo.md` da feature 002
    escrito
  - **Descrição**: o conector passa a gravar a organização de cada equipe.
    Corrigir também `mappings/github/eo/team.yaml`, que aponta para um caminho
    inexistente no payload — a organização é o pai da consulta, não campo do nó
    (F6) — FR-001, FR-012
  - **Feita quando**: toda equipe coletada tem organização; nenhuma consulta
    precisa adivinhar a partir do nome
  - **Teste**: coleta simulada de duas organizações com times de mesmo slug — as
    duas equipes ficam distintas, cada uma sob a sua organização. É FR-002 e SC-007

- [x] T010 [US1] Ler as organizações de uma pessoa
  - **Pronta quando**: T009 concluída
  - **Descrição**: `list_person_organizations/2` em `queries/`, atravessando os
    vínculos de equipe até `eo_teams.organization_id`. Não existe aresta direta
    entre pessoa e organização, e criar uma seria o segundo caminho que a spec
    rejeitou — FR-003, contrato de EO
  - **Feita quando**: a pessoa em equipes de duas organizações devolve as duas,
    sem repetição; a pessoa em duas equipes da mesma organização devolve uma; a
    pessoa cujo vínculo com uma organização deixou de ser observado **mantém** as
    demais (FR-009, SC-006)
  - **Teste**: os três casos, mais o de quem não está em equipe alguma — que
    devolve lista vazia, não erro

- [x] T011 [US1] Retrofitar a organização do que já foi coletado
  - **Pronta quando**: T009 concluída
  - **Descrição**: atribuir organização às equipes já coletadas percorrendo
    `raw_payloads → syncs → connected_tools.organization_login →
    eo_organizations`. **Sem consultar o GitHub** — toda a corrente já está
    preservada (research.md R4) — FR-023, FR-024
  - **Feita quando**: as 10 equipes existentes têm organização; o relatório diz
    quantas receberam e quantas ficaram sem, com o motivo
  - **Teste**: cinco testes em `test/the_band/semantic_integration_test.exs`, **sem
    expectativa no Mox da borda HTTP** — qualquer chamada à origem os derruba. É o V3
    do quickstart, e SC-005
  - **Executado no banco real**: 10 equipes sem organização antes, **10 atribuídas, 0
    sem resolver**. `leds-conectafapes` 8, `The-Band-Solution` 2. Nenhuma consulta ao
    GitHub — a corrente `raw_payloads → syncs → connected_tools.organization_login →
    eo_organizations` já estava toda preservada
  - **O sucesso tornou o estado "antes" inalcançável, e isso mudou os testes.** Com a
    restrição aplicada, nenhum caminho de escrita cria equipe organizacional sem
    organização. Os testes do mecanismo usam `project_team`, que legitimamente pode
    não ter organização; o conserto das organizacionais reais foi provado por execução
    e pela migração da restrição, que recusaria aplicar se alguma tivesse ficado.
    **Retrofito é migração de uma vez só, não caminho permanente**

- [ ] T012 [US1] Mostrar a organização em pessoas e equipes
  - **Pronta quando**: T010 e T011 concluídas; `contracts/screens.md` escrito
  - **Descrição**: coluna de organização nas telas de pessoas e de equipes. Na de
    pessoas são **as** organizações, no plural — quem está em duas mostra as duas
    — FR-015
  - **Feita quando**: nenhuma linha aparece sem organização; a pessoa em duas
    aparece **uma vez**, com as duas indicadas
  - **Teste**: teste de interface com duas organizações povoadas — o que precisa
    estar visível, e que a pessoa sobreposta não aparece duplicada. É SC-001

**Checkpoint**: US1 entrega valor sozinha — dá para responder de onde veio cada
registro sem que US2 exista.

---

## Phase 5 — US2 (P2): consultar uma organização de cada vez

**Meta**: escolher uma organização e ver só o que é dela, com as contagens
acompanhando.

**Teste independente**: filtrar por uma organização e conferir que a quantidade
corresponde ao que ela tem na origem.

- [ ] T013 [US2] Filtrar consultas por organização
  - **Pronta quando**: T010 concluída
  - **Descrição**: `opts[:organization_id]` em `list_*` **e** em `count_*`, com o
    mesmo efeito nas duas. Para pessoas, o filtro atravessa as equipes. Listagem e
    contagem compartilham a montagem do filtro — contagem que ignora o filtro da
    listagem exibe um total que não corresponde à tela — FR-016, FR-018
  - **Feita quando**: `list_*` e `count_*` concordam sob qualquer combinação de
    organização, busca e tipo de conta; a pessoa em **duas equipes da mesma
    organização** aparece **uma vez**, não duas — atravessar equipes sem
    `distinct` é o modo natural de errar aqui (FR-010)
  - **Teste**: percorrer as combinações comparando o tamanho da lista com a
    contagem, mais o caso da pessoa em duas equipes da mesma organização — o
    teste que já existe para a feature 001, estendido

- [ ] T014 [US2] Contar pessoa sobreposta uma vez só
  - **Pronta quando**: T013 concluída
  - **Descrição**: a contagem total conta cada pessoa uma vez, ainda que ela esteja
    em várias organizações; por organização, conta em cada uma. **A soma das
    parciais é maior que o total, e isso está correto** — FR-019
  - **Feita quando**: a diferença entre a soma das parciais e o total é exatamente
    o número de pessoas sobrepostas
  - **Teste**: com uma pessoa em duas organizações, conferir que total é 1 e a
    soma das parciais é 2 — é SC-003 e SC-004

- [ ] T015 [US2] Seletor de organização nas telas
  - **Pronta quando**: T013 concluída; `contracts/screens.md` escrito
  - **Descrição**: um componente só, usado nas telas de pessoas e de equipes,
    listando as organizações observadas com a quantidade de pessoas de cada uma.
    Organização conectada e ainda não sincronizada aparece com zero e a razão —
    sumir da lista faria parecer que ela não foi cadastrada — FR-016
  - **Feita quando**: o filtro combina com a busca; a contagem do cabeçalho segue
    a escolha; a nota explica por que a soma das parciais não fecha
  - **Teste**: teste de interface — filtrar reduz a lista, a contagem acompanha, e
    a nota sobre a soma está presente. Conferir o quadro filtrado contra a origem
    é SC-002

- [ ] T016 [US2] Provar que o filtro não vaza entre clientes
  - **Pronta quando**: T013 concluída
  - **Descrição**: o filtro por organização vem da interface, e é onde um
    vazamento entre organizações clientes nasceria: `organization_id` de outro
    tenant, composto sem o escopo, alcança dado alheio. Toda consulta continua
    recebendo o tenant, e o filtro compõe **sobre** ele, nunca no lugar dele —
    FR-022, constituição princípio V
  - **Feita quando**: passar o identificador de uma organização de outro tenant
    devolve vazio, não o registro; nenhuma função de leitura nova existe sem o
    tenant na assinatura
  - **Teste**: dois tenants povoados, cada um com sua organização; o de um pede o
    `organization_id` do outro e recebe vazio. O teste é a **violação** — é o V10
    do quickstart, e SC-008

- [ ] T017 [P] [US2] Separar estado vazio de filtro vazio
  - **Pronta quando**: T015 concluída
  - **Descrição**: "nenhuma coleta ocorreu" e "nada corresponde ao filtro" são
    causas diferentes. Um estado vazio genérico faz procurar defeito onde não há —
    FR-020
  - **Feita quando**: os dois estados têm texto próprio, e cada um diz o que fazer
  - **Teste**: teste de interface nos dois casos, conferindo qual frase aparece

**Checkpoint**: dá para trabalhar uma organização por vez, com números que fecham.

---

## Phase 6 — US3 (P3): enxergar quem atravessa organizações

**Meta**: identificar as contas presentes em mais de uma organização observada.

**Teste independente**: com a mesma conta em duas organizações, conferir que ela
é sinalizada e que as duas aparecem.

- [ ] T018 [US3] Encontrar pessoas em mais de uma organização
  - **Pronta quando**: T010 concluída
  - **Descrição**: `list_people_in_several_organizations/2` em `queries/`, contando
    organizações distintas alcançadas pelas equipes. É informação que a
    organização cliente não tem em nenhuma das ferramentas de origem — cada uma só
    enxerga a si mesma — FR-021
  - **Feita quando**: quem está em uma só organização não aparece; quem está em
    duas aparece com as duas
  - **Teste**: os dois casos, mais o de quem está em duas equipes da **mesma**
    organização — que não é sobreposição e não deve aparecer

- [ ] T019 [US3] Sinalizar a sobreposição na tela
  - **Pronta quando**: T018 e T012 concluídas
  - **Descrição**: marcar na tela de pessoas quem está em mais de uma organização,
    e quais são — sem exigir que se comparem listas à mão — FR-021
  - **Feita quando**: a marcação aparece só para quem tem sobreposição; as
    organizações são legíveis sem abrir outra tela
  - **Teste**: teste de interface — a pessoa sobreposta traz a marcação, a não
    sobreposta não traz

---

## Phase 7 — Equipe derivada

Atravessa as três histórias: é o que completa o caminho pela equipe.

- [ ] T020 Declarar a regra da equipe derivada
  - **Pronta quando**: `contracts/derived-team.md` escrito
  - **Descrição**: `rules/github_default_team.yaml`, no formato da regra de
    vínculo com equipe — o que materializa, o que **não** materializa com a razão,
    e as limitações. A principal: a equipe não existe na ferramenta de origem —
    FR-013, FR-014
  - **Feita quando**: a regra declara a proveniência da equipe derivada e a
    ausência de nível de acesso no vínculo dela
  - **Teste**: `mix knowledge.validate` aceita a regra; o mapeamento de equipe a
    referencia

- [ ] T021 Criar a equipe derivada
  - **Pronta quando**: T008 e T021 concluídas
  - **Descrição**: ao fim de cada coleta, a organização com membros fora de todas
    as suas equipes recebe uma equipe com o nome dela, e esses membros são
    vinculados. Avaliar **ao fim** é o único momento em que se sabe quem ficou de
    fora. `source_system` da plataforma e `external_id` determinístico a partir da
    organização (research.md R1, R5) — FR-004, FR-005
  - **Feita quando**: organização sem times recebe a equipe com todos; organização
    com times recebe só os de fora; organização com todos em times **não** recebe
    nada
  - **Teste**: os três casos, com os números reais — 5/0 times, 64/8 times e 6
    membros todos em times. É o V4 do quickstart, e cobre FR-007 e SC-009

- [ ] T022 Impedir derivada passar por observada
  - **Pronta quando**: T021 concluída
  - **Descrição**: invariantes em `constraints/` — equipe com `external_id` de
    derivação não pode ter `source_system` do GitHub; vínculo derivado não pode ter
    nível de acesso; e quem chama o comando **não** escolhe a proveniência, a
    função a monta — FR-005, FR-006, contrato de EO
  - **Feita quando**: não existe caminho na API pública que grave equipe derivada
    com proveniência do GitHub
  - **Teste**: tentar gravar pela API pública uma derivada como observada e
    conferir que é recusado — o teste é a **violação**

- [ ] T023 Esvaziar a derivada sem apagá-la
  - **Pronta quando**: T021 concluída
  - **Descrição**: a equipe derivada que fica sem integrantes é marcada como não
    mais observada, nunca removida. Uma equipe que existiu e esvaziou é
    informação — FR-008, contrato da equipe derivada
  - **Feita quando**: a pessoa que entra numa equipe observada sai da derivada na
    coleta seguinte, e o vínculo anterior fica marcado; a equipe permanece
    consultável
  - **Teste**: duas coletas, a segunda com a pessoa já num time observado —
    conferir a marcação e que nada foi apagado

- [ ] T024 Distinguir derivada na contagem e na tela
  - **Pronta quando**: T021 e T015 concluídas
  - **Descrição**: `opts[:origin]` nas consultas, lendo `source_system`; selo
    visível na tela, não nota de rodapé; contagem no formato "N equipes, M
    derivadas". Esconder é pior que marcar: quem não vê a equipe não explica por
    que a contagem de pessoas não fecha — FR-011, FR-017
  - **Feita quando**: descontadas as derivadas, a contagem por organização bate com
    a origem; o selo aparece sempre que a equipe aparece
  - **Teste**: teste de interface conferindo o selo, mais a comparação da contagem
    com o que a origem tem — é o V5 do quickstart, e cobre SC-010

---

## Phase 8 — Polish

- [ ] T025 [P] Atualizar a documentação gerada
  - **Pronta quando**: as fases 1 a 7 concluídas
  - **Descrição**: regerar `docs/ontology/` e `docs/integrations/` a partir da
    base, que mudou com a relação nova, as perguntas de competência e a regra
  - **Feita quando**: nenhum documento descreve estrutura que não existe mais
  - **Teste**: o gerador roda sem erro, e a relação nova aparece na documentação
    de EO

- [ ] T026 Rodar os quality gates
  - **Pronta quando**: as fases 1 a 7 concluídas
  - **Descrição**: os oito gates da constituição, sem exceção e sem desabilitar
    check para o pipeline passar
  - **Feita quando**: todos verdes, com a saída registrada
  - **Teste**: os próprios gates — a saída de cada um é a evidência

- [ ] T027 Executar os cenários do quickstart
  - **Pronta quando**: T026 concluída
  - **Descrição**: percorrer V1 a V10 de [quickstart.md](quickstart.md) e registrar
    a evidência de cada um, inclusive dos que não puderem ser executados, com o
    motivo
  - **Feita quando**: todo cenário tem resultado registrado; V9 devolve zero
    pessoas sem equipe, que é a prova de o caminho ter ficado completo
  - **Teste**: o próprio percurso; a evidência vai para o `sprint-review.md`

---

## Dependências

```text
Phase 1 (Ontologia)  ── a relação precisa existir antes da coluna
   └→ Phase 2 (Transformação)  ── a coluna precisa ser derivada antes de migrar
        └→ Phase 3 (Esquema)   ── corrige o F1
             ├→ Phase 4 US1 (P1)
             │     ├→ Phase 5 US2 (P2)  ── precisa da organização legível
             │     └→ Phase 6 US3 (P3)  ── precisa de US1
             └→ Phase 7 (Equipe derivada) ── atravessa as três
                  └→ Phase 8 (Polish)
```

A cadeia das três primeiras fases é rígida, e é a lição do F1: coluna antes de
relação foi exatamente o erro que criou este trabalho.

## Paralelismo

| Fase | Tarefas `[P]` | Por que são seguras |
|---|---|---|
| 1 | T002, T003 | arquivos distintos, ambas só dependem de T001 |
| 5 | T017 | tela, sem colisão com as consultas |
| 8 | T025 | documentação |

As demais são sequenciais por dependência real, não por conveniência.

## Estratégia de entrega

**MVP** = Fases 1 a 4 **e 7**. A fase 7 não é opcional no MVP, e a versão
anterior deste documento errava ao dizer que podia ficar para depois.

A razão é um critério de sucesso: SC-003a exige que **nenhuma pessoa conhecida
fique sem organização**. Sem a equipe derivada, as 18 pessoas que não estão em
equipe alguma continuam sem — inclusive as 5 de `ifesserra-lab`, que não tem
nenhum time. Entregar as fases 1 a 4 sozinhas produziria uma feature que corrige
o defeito para 54 das 72 pessoas e o mantém para as outras 18, sem que a tela
diga por quê.

Incremento 2 = Fase 5, filtrar por organização.
Incremento 3 = Fase 6, a sobreposição.

**Total**: 27 tarefas — 3 de ontologia, 1 de transformação, 4 de esquema, 4 de
US1, 5 de US2, 2 de US3, 5 de equipe derivada, 3 de polish.

### Correções após o `/speckit-analyze`

| Achado | O que era | Correção |
|---|---|---|
| **G1** | isolamento por tenant sem tarefa nem teste, no lugar exato onde esta feature introduz o risco | T016, com o teste da violação — o tenant pede o `organization_id` do outro e recebe vazio |
| **X1** | o MVP declarado não satisfazia SC-003a | a fase 7 passa a fazer parte do MVP, com a razão escrita |
| **G2** | FR-010 sem cobertura: atravessar equipes sem `distinct` desdobra a pessoa | asserção acrescentada a T013 |
| **G3** | SC-006 sem tarefa | asserção acrescentada a T010 |
| **M1, M2** | oito critérios verificados só pela T027, no fim | cada um citado na tarefa que o realiza |
