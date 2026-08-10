# Tasks: Editar e remover ferramentas conectadas

**Feature**: 003-editar-remover-ferramentas | **Branch**: `feature/003-editar-remover-ferramentas` | **Data**: 2026-08-10

**Entrada**: [spec.md](spec.md) · [research.md](research.md) · [plan.md](plan.md) ·
[data-model.md](data-model.md) · [contracts/](contracts/) · [quickstart.md](quickstart.md)

**Testes**: cada tarefa carrega o seu, no campo `Teste`. Não há tarefa sem forma de
demonstrar que ficou pronta.

**A ordem importa, e o motivo é o mesmo da feature 002.** Ali a coluna foi escrita antes
de a relação existir. Aqui seria a marca aplicada antes de a causa estar declarada, e
quem lesse o registro não saberia o que ele afirma.

---

## Phase 1 — Base de conhecimento

A semântica é declarada antes de o código a implementar.

- [ ] T001 Declarar a segunda causa de ausência
  - **Pronta quando**: nada além do repositório — R6 já decidiu a forma
  - **Descrição**: `priv/knowledge_base/mappings/github/eo/team_membership_evidence.yaml`
    passa a declarar **duas** causas para um vínculo terminar. Hoje declara uma:
    "Remoção de uma pessoa do time no GitHub não gera evento; só é detectável por
    comparação entre coletas". A segunda é decisão do tenant de parar de observar. Cada
    causa diz o que a retomada faz com ela: a primeira só volta se a origem voltar a
    mostrar; a segunda volta pela coleta seguinte — FR-005, research.md R6
  - **Feita quando**: as duas causas estão declaradas com o efeito de cada uma na
    retomada; nenhuma outra limitação do mapeamento foi alterada
  - **Teste**: `mix knowledge.validate` e `scripts/validate_knowledge_base.py` aceitam o
    arquivo; a segunda causa aparece na saída de `scripts/generate_docs.py` em
    `docs/integrations/mappings.md`

- [ ] T002 [P] Registrar a decisão de encerramento
  - **Pronta quando**: T001 concluída
  - **Descrição**: acrescentar a proveniência `project_decision` que declara encerrar
    observação como decisão da plataforma, não fato sobre a origem — no mesmo lugar e
    formato que a regra `github.default_team` usa. Sem isso, um registro marcado por
    encerramento parece marcado por mudança na origem, e a distinção é a razão de T001
    existir — princípio II, FR-009
  - **Feita quando**: a declaração diz que a causa é da plataforma; a validação Python
    aceita, inclusive o `source_type`
  - **Teste**: `scripts/validate_knowledge_base.py` — a proveniência tem `source_type`
    válido do enum; introduzir um valor inventado reprova

**Checkpoint**: a base declara as duas causas, e cada registro marcado poderá dizer qual
delas se aplicou.

---

## Phase 2 — Eventos de observação

Bloqueia F3: encerrar é um evento, e sem a tabela ele não tem onde ser registrado.

- [ ] T003 Criar a tabela de eventos
  - **Pronta quando**: o contrato `contracts/observation-lifecycle.md` está escrito
  - **Descrição**: migração criando `tool_observation_events` conforme
    [data-model.md](data-model.md) — `tenant_id`, `connected_tool_id`, `event`,
    `occurred_at`, `actor_user_id` anulável, `reason`, `impact` em jsonb,
    `inserted_at`. **Sem `updated_at`**, de propósito: evento não se reescreve, e ter a
    coluna convidaria a isso (ADR 0004 D7). Índice
    `(tenant_id, connected_tool_id, occurred_at desc)`, que é como a derivação pede o
    último evento. **Nenhuma coluna é removida nesta feature**
  - **Feita quando**: a tabela existe sem `updated_at`; o índice existe; aplicar e
    reverter deixa o esquema como estava
  - **Teste**: `mix ecto.migrate` seguido de `mix ecto.rollback`, conferindo o esquema
    nos dois sentidos; a ausência de `updated_at` é conferida em
    `information_schema.columns`

- [ ] T004 Derivar o estado da observação
  - **Pronta quando**: T003 concluída; o contrato está escrito
  - **Atende**: FR-008, FR-022 · ADR 0004 D7
  - **Descrição**: `observation_ended?/1` em `lib/the_band/sources.ex`, lendo o último
    evento da ferramenta. **Sem evento é vigente** — é o que faz as três ferramentas
    atuais continuarem observadas sem migração de dado. Esta função é o **único**
    caminho de derivação: a tela e o filtro de coleta a usam, e dois caminhos
    discordariam, fazendo a plataforma coletar do que a tela mostra como encerrado
  - **Feita quando**: ferramenta sem evento devolve vigente; com `ended` por último,
    encerrada; com `resumed` por último, vigente; nenhum outro lugar do código deriva
    esse estado
  - **Teste**: `test/the_band/sources_test.exs` — os três casos, mais o de dois `ended`
    seguidos, que continua encerrada. E uma busca no projeto conferindo que nenhum outro
    trecho compara `event` diretamente

- [ ] T005 [P] Registrar evento com autor e impacto
  - **Pronta quando**: T003 concluída
  - **Atende**: FR-009, FR-014 · ADR 0004 D7
  - **Descrição**: schema e changeset de `ObservationEvent` em
    `lib/the_band/sources/observation_event.ex`. `event` restrito a `ended` e `resumed`
    por `validate_inclusion` **e** por `check_constraint` — o segundo é o que vale
    quando a escrita não passa pelo changeset. `actor_user_id` é anulável de propósito:
    uma retomada pode vir de processo, e inventar autor é pior que declarar que não há
  - **Feita quando**: evento com tipo inventado é recusado pelo banco, não só pelo
    changeset; `actor_user_id` nulo é aceito
  - **Teste**: os dois casos como violação — tipo inventado recusado direto no banco
    contornando o changeset, e evento sem autor aceito

**Checkpoint**: as transições têm onde ser registradas, e o estado sai do último evento.

---

## Phase 3 — US1 (P1): parar de observar uma organização

**Meta**: encerrar a observação marca o que dependia dela, destrói a credencial e
preserva todo o resto.

**Teste independente**: encerrar `ifesserra-lab` e conferir que a coleta seguinte não a
inclui, que a credencial não existe mais, e que as pessoas e equipes dela continuam
consultáveis marcadas.

- [ ] T006 [US1] Contar o que depende da ferramenta
  - **Pronta quando**: T004 concluída; o contrato está escrito
  - **Descrição**: `observation_impact/2` devolvendo equipes, equipes derivadas,
    vínculos, pessoas exclusivas, pessoas compartilhadas e payloads preservados. É a
    **mesma função** que o encerramento usa para gravar `impact` — uma segunda contagem
    escrita para a tela divergiria da que age, e o número que a pessoa vê antes de
    confirmar tem de ser o que acontece. `people_exclusive` e `people_shared` são
    separados porque juntá-las esconde a única que assusta — FR-002, SC-009
  - **Feita quando**: para `ifesserra-lab` devolve 1 equipe, 1 derivada, 5 vínculos, 4
    exclusivas, 1 compartilhada e 24 payloads; `preserved_payloads` existe para dizer
    zero apagados
  - **Teste**: `test/the_band/sources_test.exs` — os seis números conferidos contra
    consulta direta ao banco, não contra outra chamada da mesma função

- [ ] T007 [US1] Marcar apenas quem perdeu toda vigência
  - **Pronta quando**: T006 concluída
  - **Descrição**: a marcação por organização encerrada em
    `lib/the_band/ontology/seon/eo/commands.ex`, **nesta ordem**: equipes da organização
    inclusive a derivada, depois os vínculos que apontam para elas, depois as pessoas
    sem nenhum vínculo vigente restante. **As pessoas por último não é preferência de
    estilo**: a decisão depende dos vínculos já marcados, e inverter marcaria pessoa que
    ainda tinha vínculo — é o defeito que a primeira versão da spec tinha. R2 explica por
    que a pessoa não tem proveniência por ferramenta — FR-005, FR-006, FR-010
  - **Feita quando**: encerrar `ifesserra-lab` marca 4 pessoas, 1 equipe e 5 vínculos;
    `Paulo` **não** é marcado; a equipe derivada é marcada e não apagada — SC-002, SC-003, SC-008
  - **Teste**: **a violação, e é o teste que decide a feature.** Encerrar
    `ifesserra-lab` e afirmar que `Paulo` continua vigente, porque está em
    `The-Band-Solution` e `leds-conectafapes`. Se ele aparecer marcado, nenhum outro
    número compensa. Mais o caso de `EduardoNFraiz`, em duas organizações

- [ ] T008 [US1] Destruir as credenciais da ferramenta
  - **Pronta quando**: T005 concluída
  - **Descrição**: apagar as linhas de `tool_credentials` da ferramenta ao encerrar —
    apagar, não desativar. `syncs.credential_id` é `ON DELETE SET NULL`, então o
    histórico de coletas sobrevive perdendo apenas qual credencial usou, e essa perda
    está declarada em R3. Um segredo guardado que ninguém usa só pode vazar — FR-007
  - **Feita quando**: nenhuma linha de credencial daquela ferramenta existe; as
    sincronizações continuam existindo com `credential_id` nulo
  - **Teste**: **consulta direta à tabela**, não afirmação no código — nenhuma linha com
    aquele identificador, e nenhum valor cifrado remanescente responde por ela — SC-004.
    Mais a contagem de `syncs` antes e depois, que não muda

- [ ] T009 [US1] Encerrar numa transação única
  - **Pronta quando**: T006, T007 e T008 concluídas
  - **Descrição**: `end_observation/3` em `lib/the_band/sources.ex`, seguindo o contrato:
    confere a confirmação contra `organization_login` devolvendo
    `{:error, :confirmation_mismatch}`, calcula o impacto, e numa **única transação**
    grava o evento, marca equipes, vínculos e pessoas, e destrói as credenciais. Um
    encerramento parcial deixaria a plataforma coletando de ferramenta sem credencial e
    afirmando observar o que não observa — FR-001, FR-003, FR-004, FR-009
  - **Feita quando**: confirmação errada não altera nada; encerrar duas vezes devolve
    sucesso com impacto zerado e grava o segundo evento; uma falha no meio não deixa
    estado parcial; **o `impact` gravado no evento traz os seis números**, e não um mapa
    vazio; as quatro contagens da base são idênticas antes e depois — SC-001
  - **Teste**: quatro casos — confirmação errada com o banco conferido intacto depois;
    idempotência com dois eventos gravados; uma falha forçada dentro da transação
    conferindo que nem o evento nem a marcação persistiram; e o `impact` **lido de volta
    do banco** com os seis números, porque gravar sem verificar deixaria o campo vazio
    passar (achado M2 da análise)

- [ ] T010 [US1] Excluir origem encerrada da coleta
  - **Pronta quando**: T004 concluída
  - **Descrição**: o filtro de ferramentas a sincronizar passa a usar
    `observation_ended?/1` — a **mesma** função da tela. Onde a coleta é enfileirada,
    em `lib/the_band/ingestion.ex` e no job, ferramenta encerrada não entra — FR-008,
    SC-005
  - **Feita quando**: com `ifesserra-lab` encerrada, nenhuma sincronização é criada para
    ela; as outras duas seguem normais
  - **Teste**: o teste roda **sem expectativa no Mox da borda HTTP** para aquela
    instância — qualquer chamada à origem encerrada o derruba sozinho. É o V4 do
    quickstart

- [ ] T011 [US1] Interromper a coleta em andamento
  - **Pronta quando**: T009 concluída
  - **Descrição**: a coleta percebe o encerramento **entre páginas**, no mesmo ponto em
    que grava o checkpoint, e vai para `interrupted` com o motivo, preservando progresso
    e checkpoints. É o caminho que a credencial revogada já usa. Cancelar o job foi
    descartado em R5: deixaria a sincronização em `running` para sempre, e o índice que
    impede coletas simultâneas continuaria bloqueando — FR-027
  - **Feita quando**: a sincronização fica `interrupted` com o motivo do encerramento; o
    progresso parcial e os checkpoints permanecem; nada é escrito depois da percepção
  - **Teste**: coleta simulada de duas páginas com o encerramento acontecendo entre
    elas — a primeira página está gravada, a segunda não, e o checkpoint aponta para o
    fim da primeira

- [ ] T011a [US1] Recusar operação de outro tenant
  - **Pronta quando**: T009 concluída
  - **Descrição**: `end_observation/3`, `rename_credential/3` e `destroy_credential/2`
    recebem o tenant e devolvem **não encontrado** para ferramenta ou credencial de outra
    organização cliente. Hoje só `clear_needs_attention` tem essa checagem prevista, em
    T017 — as três operações de maior consequência não tinham, e é achado **C1** da
    análise. "Não encontrado", nunca "sem permissão": dizer que existe mas não é sua já
    vaza que existe — FR-025, SC-010, princípio V
  - **Feita quando**: as três operações devolvem não encontrado para recurso de outro
    tenant; nenhuma delas devolve mensagem que revele existência
  - **Teste**: **a violação, três vezes.** Com dois tenants povoados, tentar encerrar,
    renomear e remover pela sessão do outro, conferindo não encontrado e que o registro
    alheio permaneceu intacto. É o V9 do quickstart

- [ ] T011b [US1] Derivar a causa da marca
  - **Pronta quando**: T007 concluída
  - **Descrição**: a função que decide, para um registro marcado, **qual das duas causas
    se aplicou** — decisão da plataforma ou ausência na origem. O `data-model.md` recusou
    criar coluna de causa argumentando que a informação é derivável: registro marcado
    cuja ferramenta tem evento `ended` posterior à última coleta foi marcado por decisão;
    os demais, por ausência. **O argumento é válido e ninguém havia agendado a
    derivação** — achado **C2** da análise, e é a mesma forma do G1 da feature 001, em
    que FR-017 tinha teste e nenhum chamador — FR-023
  - **Feita quando**: um registro marcado por encerramento é classificado como decisão da
    plataforma; um marcado por ausência entre coletas é classificado como mudança na
    origem; nenhuma coluna nova foi criada para isso
  - **Teste**: os dois casos, cada um construído pelo seu caminho — um encerrando a
    observação, outro marcando por ausência com `mark_evidence_no_longer_observed` — e a
    classificação conferida em cada

- [ ] T011c [US1] Encerrar não afeta a outra instância
  - **Pronta quando**: T009 concluída
  - **Descrição**: duas ferramentas para a **mesma** organização em instâncias diferentes
    são registros distintos, e encerrar uma não encerra a outra. Os registros com
    proveniência da outra permanecem vigentes. Edge case sem cobertura antes — achado
    **H1** da análise
  - **Feita quando**: encerrada uma, a outra continua vigente e continua sendo coletada;
    os registros da outra não são marcados
  - **Teste**: duas ferramentas com o mesmo `organization_login` e instâncias diferentes;
    encerrar a primeira e conferir que a segunda coleta normalmente e que nada dela foi
    marcado

**Checkpoint**: US1 entrega valor sozinha — dá para parar de observar uma organização
sem que nada se perca.

---

## Phase 4 — US2 (P2): retomar uma observação encerrada

**Meta**: quem encerrou por engano, ou voltou a precisar, reconecta sem duplicar nada.

**Teste independente**: encerrar, reconectar a mesma organização, e conferir que não
existe uma segunda ferramenta nem pessoa ou equipe duplicada.

- [ ] T012 [US2] Retomar reusando a ferramenta existente
  - **Pronta quando**: T009 concluída; o contrato está escrito
  - **Descrição**: `resume_observation/3`, validando a credencial nova contra a
    ferramenta como `connect_tool/2` já faz, e gravando o evento `resumed` mais a
    credencial numa transação. A identidade é tipo, instância e organização, e o índice
    de unicidade já garante — o que falta é o evento. **Credencial nova é obrigatória**:
    a anterior foi destruída, e a função não tem parâmetro para reusar o que não existe
    — FR-011, FR-012, FR-013
  - **Feita quando**: existe **uma** ferramenta para a combinação, não duas; as
    contagens de pessoas e equipes não mudam com a retomada
  - **Teste**: `test/the_band/sources_test.exs` — encerrar e retomar, conferindo uma
    ferramenta, 72 pessoas e 12 equipes inalteradas. É o V5 do quickstart

- [ ] T013 [US2] Devolver vigência só pela coleta
  - **Pronta quando**: T012 concluída
  - **Descrição**: a retomada **não desmarca nada por si**. Só a coleta pode dizer se a
    origem ainda mostra o registro, e desmarcar no ato ressuscitaria vínculo que a
    origem já não tem — a plataforma afirmaria observação que não ocorreu. A distinção
    das duas causas declaradas em T001 é o que decide quem volta: o marcado por decisão
    volta pela coleta; o marcado por ausência espera a origem — FR-011, SC-007,
    research.md R6
  - **Feita quando**: logo após retomar, os registros continuam marcados; depois da
    coleta, os que a origem mostra estão vigentes e os que ela não mostra continuam
    marcados
  - **Teste**: coleta com fixture em que uma das 5 pessoas de `ifesserra-lab` não volta
    a aparecer — as outras 4 ficam vigentes, e aquela permanece marcada. É o V6

- [ ] T014 [P] [US2] Consultar o histórico de observação
  - **Pronta quando**: T012 concluída
  - **Descrição**: `observation_history/2` devolvendo os eventos em ordem, para que o
    registro mostre as transições e não apenas o estado atual. É a razão de a tabela ser
    append-only: encerrar e reconectar no mesmo dia produz três transições, e um par de
    colunas guardaria uma — FR-014
  - **Feita quando**: encerrar, retomar e encerrar de novo devolve três eventos na ordem
    em que ocorreram, cada um com o seu instante
  - **Teste**: os três eventos conferidos em sequência, com os instantes distintos e o
    impacto gravado de cada encerramento

---

## Phase 5 — US3 (P3): ajustar o que é ajustável

**Meta**: renomear e remover credenciais, limpar o estado de atenção, e a tela dizendo o
que não é editável e por quê.

**Teste independente**: renomear uma credencial e conferir que só o rótulo mudou; tentar
alterar a organização e conferir que não há caminho.

- [ ] T015 [US3] Renomear credencial sem revalidar
  - **Pronta quando**: o contrato `contracts/credential-management.md` está escrito
  - **Descrição**: `rename_credential/3` alterando **exclusivamente** `label`. O
    segredo, os escopos, `validated_at` e `last_four` permanecem. Renomear não revalida:
    `validated_at` é o primeiro critério de desempate da escolha de credencial, e mexer
    nele mudaria qual credencial a coleta usa — FR-015
  - **Feita quando**: só o rótulo mudou; `validated_at` e os escopos estão iguais; a
    credencial escolhida pela coleta não mudou
  - **Teste**: comparar todos os campos antes e depois, e reafirmar que
    `active_credential/1` devolve a mesma de antes

- [ ] T016 [US3] Recusar remover a última ativa
  - **Pronta quando**: o contrato está escrito
  - **Descrição**: `destroy_credential/2` apagando a linha, e recusando com
    `{:error, :last_active_credential}` quando é a última ativa de ferramenta observada.
    Erro nomeado e não changeset: é condição do domínio, e a tela precisa dizer o que
    fazer. A razão da recusa é evitar um estado que a plataforma não sabe descrever —
    observada e sem como coletar não é observada nem encerrada — FR-016, FR-017
  - **Feita quando**: com duas credenciais, remover uma funciona e a ferramenta continua
    coletando com a outra; com uma só, é recusado nomeando o motivo
  - **Teste**: os dois casos, e o segundo é a violação — a recusa é conferida, e a
    mensagem diz que encerrar a observação é o caminho para parar de coletar

- [ ] T016a [US3] Remover credencial em uso pela coleta
  - **Pronta quando**: T016 concluída
  - **Descrição**: remover a credencial que uma coleta está usando **naquele instante**.
    A coleta já tem o segredo em memória e não vai relê-lo, então ela termina; a próxima
    escolhe outra credencial ativa, ou falha com `:no_active_credential` se não houver.
    O que **não** pode acontecer é a coleta em curso quebrar no meio por causa da
    remoção. Edge case sem cobertura antes — achado **H1** da análise
  - **Feita quando**: a coleta em andamento termina normalmente; a seguinte usa outra
    credencial ativa; sem nenhuma ativa, a seguinte é recusada com o erro nomeado
  - **Teste**: coleta simulada com a remoção acontecendo entre duas páginas — a coleta
    conclui, e a sincronização seguinte escolhe a outra credencial

- [ ] T017 [P] [US3] Limpar o estado de atenção
  - **Pronta quando**: nada além do repositório — a função já existe
  - **Descrição**: `clear_needs_attention/2` passa a **receber o tenant explicitamente**.
    Hoje aceita só a ferramenta, e função de escrita sem tenant é função cujo escopo
    depende de quem chama lembrar. Expor na interface — FR-018, princípio V
  - **Feita quando**: a assinatura exige o tenant; ferramenta de outro tenant devolve
    não encontrado; a ferramenta volta a `active` e a sincronizar
  - **Teste**: a violação — tentar limpar ferramenta de outro tenant e conferir não
    encontrado, nunca "sem permissão", porque dizer que existe já vaza que existe

---

## Phase 6 — Telas

- [ ] T018 Mostrar o impacto antes de confirmar
  - **Pronta quando**: T006 e T009 concluídas; `contracts/screens.md` está escrito
  - **Descrição**: a confirmação de encerramento em
    `lib/the_band_web/live/source_live/`, mostrando o que será marcado, quem
    **permanece vigente** e nomeado, o que será destruído, e o que **não** será apagado
    com o número de payloads. A confirmação exige digitar o `organization_login`. Os
    números vêm de `observation_impact/2`, nunca de contagem escrita para a tela —
    FR-002, FR-003, SC-009
  - **Feita quando**: a tela mostra os seis números; a pessoa que permanece aparece pelo
    nome; confirmação errada não encerra; os números batem com o que o encerramento
    marca
  - **Teste**: teste de interface conferindo os números contra o que foi marcado depois
    de confirmar — é o V8 do quickstart. Divergir significa duas contagens no código

- [ ] T019 [P] Distinguir os três estados na lista
  - **Pronta quando**: T004 concluída
  - **Descrição**: `/ferramentas` distingue observada, encerrada e precisando de
    atenção, e a encerrada **continua na lista** esmaecida dizendo desde quando. Sumir
    faria parecer apagada, e é como a retomada fica alcançável. O estado vazio distingue
    "nenhuma conectada" de "todas encerradas" — FR-021, FR-022, FR-024
  - **Feita quando**: os três estados são visualmente distintos; a encerrada aparece com
    a data; os dois estados vazios têm textos diferentes
  - **Teste**: teste de interface com uma ferramenta em cada estado, e os dois casos de
    estado vazio conferidos pelo texto exibido

- [ ] T020 [P] Explicar o que não é editável
  - **Pronta quando**: `contracts/screens.md` está escrito
  - **Descrição**: no lugar onde alguém procuraria editar tipo, instância ou
    organização, a tela **explica** que são a identidade da ferramenta e que trocá-los
    faria os registros já coletados apontarem para uma origem que não os produziu.
    Explicar é diferente de não oferecer: campo ausente faz a pessoa supor limitação —
    FR-019, FR-020
  - **Feita quando**: o texto da ausência está visível na tela de edição; nenhum
    caminho da interface altera os três campos
  - **Teste**: teste de interface conferindo o texto presente, mais a violação — enviar
    os três campos pelo formulário e conferir que nada mudou no registro

- [ ] T021 [P] Marcar origem encerrada nas telas
  - **Pronta quando**: T007 concluída
  - **Descrição**: `/pessoas` e `/equipes` distinguem registro de origem vigente de
    origem encerrada, com a data. A marca por encerramento é distinguível da marca por
    ausência na origem: uma diz "a origem mudou", a outra diz "nós paramos de olhar" —
    FR-023
  - **Feita quando**: as duas causas são distinguíveis na tela; a data aparece
  - **Teste**: teste de interface com um registro marcado por cada causa, conferindo que
    os dois textos são diferentes

- [ ] T021a [P] Distinguir nunca conectou de encerrou tudo
  - **Pronta quando**: T019 concluída
  - **Descrição**: encerrar a **última** ferramenta do tenant deixa a organização cliente
    sem origem alguma, e as telas de ferramentas, pessoas e equipes precisam distinguir
    "nunca conectou" de "encerrou tudo". São situações diferentes: a primeira pede
    conectar, a segunda pede retomar ou conectar outra. Edge case sem cobertura antes —
    achado **H1** da análise, FR-024
  - **Feita quando**: os dois estados vazios têm textos diferentes nas três telas; o
    texto de "encerrou tudo" diz quantas foram encerradas
  - **Teste**: teste de interface nos dois estados — tenant sem ferramenta alguma, e
    tenant cuja única ferramenta foi encerrada —, conferindo que os textos diferem

- [ ] T022 Provar que o segredo não vaza
  - **Pronta quando**: T015, T016 e T018 concluídas
  - **Descrição**: percorrer as telas que a feature acrescenta ou muda com uma
    credencial de segredo conhecido, procurando o texto do segredo no HTML servido —
    FR-026, SC-011
  - **Feita quando**: o segredo não aparece em nenhuma das quatro telas; o que aparece é
    `last_four`
  - **Teste**: **a violação** — procura o segredo e exige não encontrar. "A tela
    renderiza" não prova nada aqui. É o V10 do quickstart, e é a mesma forma que a
    feature 001 usa

---

## Phase 7 — Fechamento

- [ ] T023 [P] Atualizar a documentação gerada
  - **Pronta quando**: T001 e T002 concluídas
  - **Descrição**: regerar `docs/integrations/mappings.md` a partir da base, que mudou
    com as duas causas declaradas
  - **Feita quando**: a segunda causa aparece na documentação; nenhum documento descreve
    estrutura que não existe
  - **Teste**: `scripts/generate_docs.py` roda sem erro, e a segunda causa está no
    arquivo gerado

- [ ] T024 Rodar os quality gates
  - **Pronta quando**: as fases 1 a 6 concluídas
  - **Descrição**: os nove gates, sem exceção e sem desabilitar check para o pipeline
    passar — os oito da constituição mais o de derivação reproduzível
  - **Feita quando**: todos verdes, com a saída registrada
  - **Teste**: os próprios gates; a saída de cada um é a evidência

- [ ] T025 Executar os cenários do quickstart
  - **Pronta quando**: T024 concluída
  - **Descrição**: percorrer V1 a V10 de [quickstart.md](quickstart.md) e registrar a
    evidência de cada um, inclusive dos que não puderem ser executados, com o motivo
  - **Feita quando**: todo cenário tem resultado registrado; V1 mostra as quatro
    contagens idênticas antes e depois, e V2 mostra `Paulo` não marcado
  - **Teste**: o próprio percurso; a evidência vai para o `sprint-review.md`

---

## Dependências

```text
Phase 1 (Base de conhecimento) ── a causa é declarada antes de a marca existir
   └→ Phase 2 (Eventos) ── encerrar é evento; sem tabela não há onde registrar
         └→ Phase 3 US1 (P1) ── entrega valor sozinha
               ├→ Phase 4 US2 (P2) ── precisa de encerrar para retomar
               └→ Phase 6 (Telas) ── precisa do impacto e da derivação
         └→ Phase 5 US3 (P3) ── independente de US1; só precisa do contrato
               └→ Phase 7 (Fechamento)
```

**US3 não depende de US1.** Renomear e remover credencial existem sem encerrar
observação, e podem ser feitas em paralelo — a única dependência é T016 precisar saber
se a ferramenta está observada, que vem de T004.

## Paralelismo

| Podem correr juntas | Por que |
|---|---|
| T002 com T003 | arquivos diferentes; T002 é base de conhecimento, T003 é migração |
| T005 com T004 | schema e derivação, arquivos diferentes |
| T015, T016 e T017 | três funções independentes em credenciais |
| T019, T020 e T021 | três telas diferentes |

## Estratégia de implementação

**MVP: Phase 1, 2 e 3.** Encerrar a observação é o pedido, e as três entregam.

**O custo de parar no MVP, declarado**: sem US2, o encerramento é irreversível na
prática, e encerramento irreversível faz as pessoas não encerrarem — deixam a ferramenta
quebrada no lugar. Se o MVP for entregue sem retomar, **T019 precisa dizer na tela que a
retomada ainda não existe**, em vez de deixar descobrir.

**A tarefa que decide a feature é T007.** Se `Paulo` for marcado, o defeito é o mesmo
que a primeira versão da spec tinha, e nenhuma outra tarefa compensa.
