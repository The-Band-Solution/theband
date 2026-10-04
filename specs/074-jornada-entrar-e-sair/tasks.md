# Tasks: a jornada de entrar e sair, vista por quem opera

**Input**: [spec.md](spec.md), [seguranca.md](seguranca.md), [plan.md](plan.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/jornada.md](contracts/jornada.md), [quickstart.md](quickstart.md),
[ADR 0005](../../docs/adr/0005-telemetria-da-jornada.md)

**Nenhuma tarefa de código começa antes da Fase 0.** As issues e o sprint backlog só nascem
depois do aceite da ADR (`/speckit-taskstoissues`, depois `/sprint-backlog`).

Convenções: 👤 = ato da pessoa mantenedora, que nenhum agente faz. **Defeito a injetar** = o que
se muda de propósito para ver o teste reprovar antes de aceitar a guarda (AGENTS §14.0). Antes de
injetar, **copiar o arquivo** (memória: *git checkout apaga trabalho não commitado*). Todo comando
de verificação redireciona a saída para arquivo e lê o código de saída antes (AGENTS §4).

## Fase 0: Decisões e pré-requisitos

- [x] T001 👤 Aceitar ou recusar a ADR 0005 — *feita: decisão de 2026-10-03, ADR aceita*
  - **Pronta quando**: a ADR emendada e [seguranca.md](seguranca.md) estão no branch
  - **Descrição**: ler a emenda de 2026-10-03 (E1–E8) e decidir. Aceita, o status vira
    **Aceita — <data>**; recusada, a 074 para aqui.
  - **Feita quando**: o status da ADR diz a decisão, com data e quem decidiu
  - **Teste**: `grep -n "Aceita — 2026-10-03" docs/adr/0005-telemetria-da-jornada.md` devolve uma
    linha

- [x] T002 👤 Decidir D1 a D7 da avaliação de segurança — *feita: decisão de 2026-10-03, todas pela recomendação; D7 virou a #1229*
  - **Pronta quando**: T001
  - **Descrição**: as sete decisões de [seguranca.md](seguranca.md), *Decisões da pessoa
    mantenedora*: D1 identificador (recomendado: id cru com minimização), D2 acesso ao painel
    (túnel), D3 hospedagem (mesmo VPS, com #1162 e rede dedicada), D4 retenção (7 e 30 dias),
    D5 os onze pacotes (aceitar com as condições de S9), D6 a ordem (seguir a regra), D7 limite
    por IP (issue própria). Registrar na spec, em *Assumptions*, com data.
  - **Feita quando**: a spec diz, para cada D, a opção escolhida e a data; se D1 for o HMAC,
    `contracts/jornada.md` §5 foi atualizado no mesmo commit
  - **Teste**: revisão: as sete aparecem em `spec.md`; nenhuma ficou "pendente"

- [x] T003 Conferir que os pré-requisitos de segurança chegaram — *conferida em 2026-10-03: PR
  #1227 `MERGED` em `development` às 19:04 UTC (merge `0e3c2f0`); `git grep -n "defmodule
  TheBand.Repo.LogDaConsulta" origin/development -- lib/` devolve
  `lib/the_band/repo/log_da_consulta.ex:1`*
  - **Pronta quando**: T002 (D6)
  - **Descrição**: `gh pr view 1227` mergeado em `development` (D6). A #887 **não** bloqueia: as
    tarefas #871, #872 e #873 estão fechadas (conferido em 2026-10-03), e a US espera só a
    aceitação do Product Owner. `git log origin/development` tem
    `TheBand.Repo.LogDaConsulta`.
  - **Feita quando**: o estado do PR #1227 está escrito neste arquivo, com a data da conferência
  - **Teste**: `git grep -n "defmodule TheBand.Repo.LogDaConsulta" origin/development -- lib/`
    devolve uma linha

## Fase 1: Setup

- [ ] T004 Fixar as dependências do OpenTelemetry
  - **Pronta quando**: T001, T002 (D5), T003
  - **Descrição**: em `mix.exs`, `{:opentelemetry_api, "== 1.5.0"}`, `{:opentelemetry, "==
    1.7.0"}`, `{:opentelemetry_exporter, "== 1.11.0"}` e `{:grpcbox, "~> 0.18.0"}` (só o teto, com
    comentário dizendo isso — S9). Em `releases/0`, `opentelemetry` como `:temporary`, para que uma
    falha do SDK não derrube o nó. `mix deps.get`; revisar o diff do `mix.lock` **linha a linha**:
    entram os onze pacotes de ADR E6, e nenhum outro.
  - **Feita quando**: o `mix.lock` tem exatamente os onze pacotes novos; `mix hex.audit` e
    `mix deps.audit` saem com 0, lidos; depois do boot da release, `:inet.i()` dentro do contêiner
    não mostra porta nova escutando
  - **Teste**: `mix hex.audit > /tmp/hex.log 2>&1; echo EXIT=$?` e o mesmo para `deps.audit`.
    **Defeito a injetar**: tirar o teto de `grpcbox`; `mix hex.outdated grpcbox` passa a mostrar
    que a resolução aceitaria uma versão fora de `0.18.x` quando houver uma; o teto volta

- [ ] T005 Configurar o SDK explicitamente, e desligado por padrão
  - **Pronta quando**: T004; research R11
  - **Descrição**: `config/config.exs` e `config/test.exs`: `traces_exporter: :none`; no teste,
    `processors: [{:otel_simple_processor, %{}}]`. `config/runtime.exs`: liga só com
    `THE_BAND_OTLP_ENDPOINT`, valida o host contra a lista permitida, protocolo `http_protobuf`,
    recurso fixo (`service.name`, `service.version`, `deployment.environment`), sem amostragem
    (FR-016), e o exportador é `TheBand.Telemetria.Exportador` envolvendo
    `:opentelemetry_exporter`. Ler `deps/opentelemetry/src/` para saber se `OTEL_*` do ambiente
    ainda vence a configuração explícita, e registrar a resposta em research R11. FR-015; S10.
  - **Feita quando**: sem a variável, o boot loga *"telemetria desligada"* com o nome da variável;
    com um host fora da lista, idem, e o valor **não** aparece no log; com
    `OTEL_EXPORTER_OTLP_ENDPOINT` apontando para fora, o exportador não vai para lá
  - **Teste**: `test/the_band/telemetria/configuracao_test.exs`, um caso por situação, chamando a
    função que monta a configuração. **Defeito a injetar**: ler a variável sem validar o host; o
    caso do host de fora precisa reprovar

- [ ] T006 Subir o SigNoz local num profile próprio
  - **Pronta quando**: T001
  - **Descrição**: `foundryctl forge` gera o compose; o resultado vai para `deploy/signoz/` com
    as imagens fixadas por resumo (`@sha256:`), servidor e coletor fixados juntos, o coletor com
    `--config` versionado e **sem OpAMP**, `memory_limiter` no coletor, teto de memória nos
    contêineres e `max_server_memory_usage` no ClickHouse (ADR E3), ClickHouse com senha vinda do
    ambiente, chave do JWT **sem valor padrão**. No `compose.yaml`, profile `telemetria` que inclui
    esse arquivo, portas só em `127.0.0.1`. FR-014; ADR E2, E7; S6, S7.
  - **Feita quando**: `docker compose --profile telemetria up -d` sobe; um `POST` OTLP vazio a
    `127.0.0.1:4318` devolve 200; um span de teste **chega** ao ClickHouse; o `the_band_postgres`
    tem o mesmo `CREATED` de antes; sem a chave do JWT, o serviço do SigNoz não sobe
  - **Teste**: o quickstart §1, com os códigos de saída lidos; e
    `grep -n "ports:" deploy/signoz/*.yaml` vazio fora do override de desenvolvimento.
    **Defeito a injetar**: voltar o coletor com OpAMP contra um servidor de outra versão — o span
    de teste não chega, e a conferência por recepção reprova enquanto o *healthcheck* segue verde

## Fase 2: Fundação

- [ ] T007 Declarar a taxonomia da jornada
  - **Pronta quando**: `data-model.md` §1; T001
  - **Descrição**: `priv/knowledge_base/rules/journey_entrar_e_sair.yaml`, `derivation_rule`
    `journey.entrar_e_sair`, com os seis passos, os desfechos, os 17 motivos por passo, o cenário
    de origem de cada um e os três `absent_on_purpose`. Research R7. Vocabulário igual ao da ADR
    §4 (S16).
  - **Feita quando**: `mix knowledge.validate` sai com 0; uma função de leitura devolve, para cada
    passo, a lista de motivos
  - **Teste**: `test/the_band/telemetria/taxonomia_test.exs`, a parte que lê o YAML.
    **Defeito a injetar**: tirar a proveniência; o validador reprova

- [ ] T008 Suporte de teste para ler spans
  - **Pronta quando**: T004, T005
  - **Descrição**: `test/support/spans.ex` com `Record.extract(:span, from_lib:
    "opentelemetry/include/otel_span.hrl")`, uma função que liga o exportador **real** com destino
    `{:otel_exporter_pid, self()}` (research R4; S15), e as funções de varredura de sentinela em
    claro, Base64 e `inspect`.
  - **Feita quando**: um teste de fumaça emite um span e o recebe **depois** de passar pelo filtro
  - **Teste**: o próprio teste de fumaça. **Defeito a injetar**: ligar o `:otel_exporter_pid`
    sem o filtro; a função de suporte precisa recusar (ela confere que o módulo configurado é o
    `TheBand.Telemetria.Exportador`)

- [ ] T009 O exportador que só deixa sair o permitido
  - **Pronta quando**: `contracts/jornada.md` §6; T007, T008
  - **Descrição**: `lib/the_band/telemetria/exportador.ex`, behaviour `:otel_exporter`. Reconstrói
    cada span: nome contra a enumeração dos passos; atributos da lista com o valor na forma
    (UUID, enumeração **do passo**, correlator); sem eventos nem links; status sem descrição;
    recurso fixo. Conta cada descarte em `:counters`. FR-005, FR-006; S1. O nome de span fora da
    enumeração descartado inteiro é também a guarda de FR-012: um span de consulta que alguém
    ligar sem avaliação não sai.
  - **Feita quando**:
    - um span com atributo fora da lista sai sem ele, e o contador sobe com o **nome** do atributo;
    - `failure.reason` com valor fora da enumeração do passo não sai;
    - um evento `exception` e uma descrição de status não saem;
    - o recurso exportado tem as três chaves e nenhuma outra, mesmo com
      `OTEL_RESOURCE_ATTRIBUTES` definida
  - **Teste**: `test/the_band/telemetria/exportador_test.exs`. **Defeitos a injetar**: validar só
    o nome (o `inspect(changeset)` em `failure.reason` precisa reprovar); filtrar o recurso em vez
    de reconstruí-lo

- [ ] T010 O handler que traduz sem sumir
  - **Pronta quando**: `contracts/jornada.md` §4; T009
  - **Descrição**: `lib/the_band/telemetria/jornada.ex`: `anexar/0`, `id/0`, `handle_event/4`,
    montando atributos **só** dos campos permitidos da metadata. `catch kind, reason` que conta e
    loga só o `kind` e o módulo. Anexado em `TheBand.Application.start/2` antes dos filhos. O
    `telemetry_poller` de `TheBandWeb.Telemetry` loga os contadores não zero e confere que o handler
    segue anexado. FR-008; ADR S5; S11.
  - **Feita quando**: um handler forçado a levantar, a fazer `exit` e a fazer `throw` continua
    anexado depois de cada um; o contador sobe; o log tem o tipo e **não** tem a sentinela posta na
    mensagem; com o handler desanexado à mão, o poller loga `error`
  - **Teste**: `test/the_band/telemetria/handler_resiliente_test.exs`. **Defeito a injetar**:
    trocar `catch` por `rescue`; o caso do `exit` precisa reprovar

- [ ] T011 A função única que emite o passo
  - **Pronta quando**: `contracts/jornada.md` §1–2; T010
  - **Descrição**: `AccessEvents.passo/1`, com guardas que só aceitam átomo de lista, id binário,
    correlator e `nil`. S1, terceira camada.
  - **Feita quando**: com passo, desfecho e motivo válidos, um span chega; com uma struct, um mapa
    a mais ou uma string em `motivo`, a função levanta `FunctionClauseError`
  - **Teste**: `test/the_band/tenants/access_events_passo_test.exs`. **Defeito a injetar**: aceitar
    `motivo` binário; o caso da string precisa reprovar

## Fase 3: US1 — sei quem não conseguiu entrar, e por quê (P1) 🎯 MVP

- [x] T012 [US1] A entrada emite o passo depois da transação — *feita em 2026-10-03: 11 casos em
  `regua_test.exs`; defeitos vistos reprovando: motivo devolvido ao controller (8/11 reprovam),
  hash do identificador em forma de UUID como conta (2/11), conta em todo `concluiu` (2/11).
  "Emitir dentro da transação" **não** é pegável pelo teste de tempo: a emissão custa o mesmo
  dentro ou fora; a ordem fica garantida pela leitura do código (`authenticate/3`)*
  - **Pronta quando**: T011
  - **Descrição**: em `Auth`, `verificar_com_trava/2` passa a devolver o relator interno
    `{decisão, motivo, conta}`; `authenticate/3` emite **um** `entrar_com_senha` depois da
    transação, em todo ramo, inclusive o do identificador que não resolve e o da espera
    (`em_espera`); devolve ao controller o mesmo que hoje. Identidade só como FR-004 (D1).
    FR-001 a FR-004, FR-009, FR-017, SC-001 (a parte da entrada); S4, S14.
  - **Feita quando**: as oito linhas de *A régua* do passo `entrar_com_senha` produzem cada uma o passo com o
    desfecho e o motivo certos; `identificador_nao_resolveu` sai sem `user.ref` e sem nada do
    digitado; o `concluiu` comum sai sem `user.ref`, e com ele quando `falhas_apagadas > 0`; o
    controller só recebe `:invalid_credentials` ou `{:throttled, _}`
  - **Teste**: `test/the_band/telemetria/regua_test.exs`, a parte da entrada. **Defeitos a
    injetar**: emitir dentro da transação (o teste de tempo, T015, reprova); devolver o motivo ao
    controller (o caso estrutural reprova); pôr `hash(identificador)` no passo

- [x] T013 [US1] O correlator nasce no servidor e morre na tentativa — *feita em 2026-10-03: 5
  casos; defeitos vistos reprovando: ler dos parâmetros (1/5), não apagar (2/5)*
  - **Pronta quando**: research R5; T011
  - **Descrição**: `lib/the_band_web/plugs/jornada_de_entrada.ex` só no `GET /sign-in`, que
    substitui `:jornada_id`; `SessionController.create/2` lê **só da sessão**, passa a
    `authenticate/3` e apaga com **qualquer** desfecho. FR-011; S5.
  - **Feita quando**:
    - um POST com `journey_id` nos parâmetros e outro na sessão exporta o da sessão;
    - depois de entrar, a sessão autenticada não tem `:jornada_id`;
    - dois `GET /sign-in` seguidos dão dois valores diferentes
  - **Teste**: `test/the_band_web/jornada_de_entrada_test.exs`. **Defeitos a injetar**: ler dos
    parâmetros; não apagar no sucesso

- [x] T014 [US1] A abertura da entrada conta uma vez — *feita em 2026-10-03: 2 casos; defeito
  visto reprovando: emitir em todo `mount` (2/2)*
  - **Pronta quando**: T013
  - **Descrição**: `SessionLive.New.mount/3` emite `abrir_a_entrada` só com `connected?(socket)`,
    com o correlator da sessão. Research R5.
  - **Feita quando**: uma visita com conexão do LiveView produz **uma** abertura; a renderização
    estática sozinha não produz nenhuma
  - **Teste**: `test/the_band_web/live/abrir_a_entrada_test.exs`. **Defeito a injetar**: emitir em
    todo `mount`; a contagem vira dois

- [x] T015 [US1] O tempo e a sessão não distinguem os motivos — *feita em 2026-10-03; defeitos
  vistos reprovando: correlator mantido só na espera (`login_test.exs`), consulta no handler só
  com conta (4/4 rodadas com o limiar de 0,25 ms; com 2 ms passava — research R9)*
  - **Pronta quando**: T012, T013
  - **Descrição**: estender `test/the_band_web/live/login_test.exs` (o do `Enum.uniq`): para os seis
    motivos, além do corpo e do destino, o **conjunto de chaves da sessão decodificada** do
    `Set-Cookie`. E um teste de mediana: 50 emissões por motivo, a diferença entre medianas abaixo
    de 0,25 ms (eram 2 ms; medido insuficiente — research R9). FR-003, SC-003, FR-009; S4.
  - **Feita quando**: o conjunto de chaves é o mesmo nos seis; a diferença de medianas fica abaixo
    do limiar
  - **Teste**: `login_test.exs` e `test/the_band/telemetria/tempo_por_motivo_test.exs`.
    **Defeitos a injetar**: apagar o correlator só em `senha_errada`; pôr um `Repo.one` no handler
    só quando há conta

## Fase 4: US2 — sei quando sair falhou (P1)

- [ ] T016 [US2] Sair diz se encerrou alguma coisa
  - **Pronta quando**: T011
  - **Descrição**: `SessionController.delete/2` emite `sair` com `concluiu` quando havia
    `current_session`, e `falhou` / `sessao_ja_nao_existia` quando não havia. `Sessions.encerrar/1`
    **não muda** (contrato §8).
  - **Feita quando**: entrar e sair dá `concluiu`; repetir o `DELETE` com o cookie velho dá
    `sessao_derrubada` (`encerrada`) **e** `sair` com `sessao_ja_nao_existia`
  - **Teste**: `regua_test.exs`, a parte de sair. **Defeito a injetar**: emitir `concluiu` sempre

- [ ] T017 [US2] A queda de sessão diz o motivo
  - **Pronta quando**: T011
  - **Descrição**: `CurrentScope.sem_sessao/3` emite `sessao_derrubada` com o motivo, ao lado do
    log. `:sem_sessao` (o visitante sem cookie) não emite. Os oito motivos de data-model §1.
  - **Feita quando**: cada um dos oito motivos produz o passo; o visitante sem cookie não produz
    nada
  - **Teste**: `regua_test.exs`, a parte da queda. **Defeito a injetar**: emitir também para
    `:sem_sessao`; o caso do visitante reprova

## Fase 5: US3 — nada disso vaza (P1)

- [ ] T018 [US3] As sentinelas não saem, em nenhum dos quatro passos
  - **Pronta quando**: T012–T017
  - **Descrição**: `test/the_band/telemetria/sentinelas_test.exs` (seguranca.md, S15, T1): os
    quatro passos com sentinela em **todo** campo de credencial, o `assert` de que chegaram spans
    dos quatro antes de qualquer `refute`, e a varredura de nome, atributo, evento, status, link e
    recurso em claro, Base64 e `inspect`. SC-002; FR-005.
  - **Feita quando**: zero ocorrências; e o teste foi **visto reprovando** em cada um dos cinco
    defeitos, com a saída e o código de saída registrados na issue
  - **Teste**: o próprio arquivo. **Defeitos a injetar, um por vez**: sem o filtro;
    `inspect(changeset)` em `failure.reason`; `set_attribute` direto no span corrente;
    `OTEL_RESOURCE_ATTRIBUTES` com sentinela; `record_exception` com a sentinela na mensagem

- [ ] T019 [US3] O gate da taxonomia
  - **Pronta quando**: T007, T012, T016, T017
  - **Descrição**: `taxonomia_test.exs` coleta o que **chegou ao exportador** nos casos da régua e
    compara com o YAML: motivo emitido e não declarado reprova; motivo declarado e nunca emitido
    reprova; `abandonou` emitido pela aplicação reprova. Research R8; FR-002, FR-007; SC-001 (as 15
    linhas de *A régua* cobertas entre T012, T014, T016, T017, T021 e T022).
  - **Feita quando**: as três comparações passam com o código de hoje
  - **Teste**: o próprio arquivo. **Defeitos a injetar**: declarar um motivo a mais no YAML;
    emitir um motivo novo no código sem declarar

- [ ] T020 [US3] Sem backend, entrar e sair seguem iguais
  - **Pronta quando**: T005, T006, T012, T016
  - **Descrição**: com o profile `telemetria` de pé, parar o coletor e fazer dez entradas e dez
    saídas; ler `deps/opentelemetry/src/otel_batch_processor.erl` e decidir como o descarte por fila
    cheia é contado (research R13). SC-004; FR-008.
  - **Feita quando**: dez de dez entradas e saídas funcionam; o contador de perda, ou a lacuna
    declarada em R13 e na ADR, está registrado
  - **Teste**: `test/integration/telemetria_sem_backend_test.exs` (tag `:integration`) apontando o
    exportador para uma porta fechada. **Defeito a injetar**: exportador síncrono no caminho da
    requisição; a entrada passa a esperar e o caso de tempo reprova

## Fase 6: US4 — sei quando definir ou trocar a senha falhou (P2)

- [ ] T021 [US4] Definir e trocar a senha emitem o desfecho
  - **Pronta quando**: T011
  - **Descrição**: `set_password/2` e `update_password/2` emitem `definir_a_senha` e
    `trocar_a_senha` com `confirmacao_diferente`, `recusada_pela_regra`, `fora_do_fluxo` e
    `senha_atual_nao_confere`. O motivo vem do **ramo** do `case`, nunca do changeset (S1).
  - **Feita quando**: as duas linhas de *A régua* produzem os sete casos; nenhum span carrega a
    senha nova, a atual ou a temporária
  - **Teste**: `regua_test.exs`, a parte da senha, e `sentinelas_test.exs` com esses passos.
    **Defeito a injetar**: derivar o motivo de `inspect(changeset.errors)`; o filtro o descarta e o
    caso do motivo reprova

## Fase 7: US5 — quem opera encontra as respostas (P2)

- [ ] T022 [US5] O painel das três perguntas
  - **Pronta quando**: T006, T012, T016
  - **Descrição**: `deploy/signoz/paineis/entrar-e-sair.json`: entradas por passo, desfecho e
    motivo, por organização; contas que precisam de alguém (sem senha, desativada, organização
    suspensa); saídas que falharam; abertura sem tentativa em 30 minutos como `abandonou`
    (research R6). Dimensões **só** de enumeração fechada; `user.ref` e `journey.id` nunca como
    dimensão (S13). Período vazio diz "nenhuma tentativa", e não zero. FR-010, FR-013; SC-005.
  - **Feita quando**: importado no SigNoz local, depois das tentativas do quickstart §3, as três
    perguntas aparecem respondidas sem escrever consulta; com período vazio, o painel diz que não
    houve tentativa
  - **Teste**: o quickstart §3 seguido da importação, com captura de tela anexada à issue; e
    `grep -n "user.ref\|journey.id" deploy/signoz/paineis/entrar-e-sair.json` só nos filtros de
    traço, nunca em `groupBy`

- [ ] T023 [US5] O alerta de enumeração de contas
  - **Pronta quando**: T022
  - **Descrição**: alerta sobre a **contagem** de `identificador_nao_resolveu` por janela, com o
    limiar declarado no arquivo e a razão escrita; corpo sem atributo de traço (S8, S12).
    `deploy/signoz/alertas/enumeracao.json`.
  - **Feita quando**: 200 tentativas com e-mails inexistentes em um minuto, no local, disparam o
    alerta; o corpo do alerta não tem `user.ref`, `journey.id` nem e-mail
  - **Teste**: o script de carga do quickstart contra o local. **Defeito a injetar**: pôr
    `{{user.ref}}` no modelo da mensagem; a conferência do corpo reprova

## Fase 8: Produção — 👤 e o que a cerca

- [ ] T024 👤 Medir o VPS antes de subir
  - **Pronta quando**: T002 (D3)
  - **Descrição**: no VPS, `free -m` e `docker stats --no-stream` com a aplicação e o Postgres de
    pé. Menos de 4 GB disponíveis = opção A cai, e vale a B (ADR E3).
  - **Feita quando**: os números estão na ADR E3, com data e comando
  - **Teste**: revisão do registro na ADR

- [ ] T025 👤 Consertar a distribuição Erlang antes de juntar as redes
  - **Pronta quando**: T002 (D6)
  - **Descrição**: a #1162 fechada, ou a exceção registrada com a razão. Pré-requisito da opção A
    (ADR E7, item 3; S7).
  - **Feita quando**: `gh issue view 1162` fechada, ou a exceção escrita na ADR
  - **Teste**: `gh issue view 1162 --json state`

- [ ] T026 👤 Subir o SigNoz no Dokploy, fechado
  - **Pronta quando**: T006, T024, T025
  - **Descrição**: serviço *Compose* a partir de `deploy/signoz/`; **sem domínio** no Traefik; a
    chave do JWT e a senha do ClickHouse geradas no servidor e coladas no painel do Dokploy; as duas
    redes de ADR E7 item 2; a primeira conta criada **pelo túnel**, e a lista de usuários conferida
    depois (uma conta); telemetria de uso desligada; volume do ClickHouse **fora** do backup;
    retenção 7 e 30 dias. Quickstart §5, passos 2 a 7c.
  - **Feita quando**: os seis itens de S6 têm evidência lida e registrada na issue: compose sem
    `ports:`; `ss -ltnp` sem as seis portas; **conexão de fora recusada**; JWT sem padrão; a
    conta única; imagens por resumo
  - **Teste**: a sonda de fora do VPS a 8080, 4317, 4318, 8123, 9000 e 2181, com a saída anexada.
    **Defeito a injetar**: nenhum em produção — a sonda é rodada antes contra o ambiente local com
    uma porta publicada de propósito, e precisa acusá-la

- [ ] T027 👤 Ligar a aplicação ao coletor
  - **Pronta quando**: T026; T005
  - **Descrição**: no Dokploy, `THE_BAND_OTLP_ENDPOINT` com o nome do serviço do coletor na rede
    dedicada, e **nenhuma** `OTEL_*` no ambiente da aplicação. Deploy.
  - **Feita quando**: entrar com a própria conta e sair aparecem no SigNoz pelo túnel; o log da
    aplicação não diz "telemetria desligada"
  - **Teste**: quickstart §5, passo 9

- [ ] T028 👤 Medir depois, e conferir a saída e a retenção
  - **Pronta quando**: T027
  - **Descrição**: `docker stats --no-stream` com o SigNoz ocioso há 5 minutos; o tráfego de saída
    do contêiner do SigNoz por 10 minutos (nenhum destino externo); depois de oito dias, a idade do
    traço mais antigo por consulta ao ClickHouse. ADR E3, E7; S8, S13; SC-007.
  - **Feita quando**: os números substituem a medida local na ADR E3; a idade do mais antigo está
    abaixo de 8 dias; nenhuma conexão de saída do SigNoz
  - **Teste**: revisão dos registros

- [ ] T029 Atualizar o runbook
  - **Pronta quando**: T026
  - **Descrição**: `docs/producao/runbook.md` §2 ganha `THE_BAND_OTLP_ENDPOINT` e as duas
    variáveis do SigNoz (nomes, nunca valores); um § novo para o SigNoz: túnel, quem vê
    (quem opera, quem tem o Dokploy e o `root`), retenção, volume fora do backup, canal do alerta.
    S13.
  - **Feita quando**: a lista fechada do §2 bate com o que o Dokploy tem; o § novo nomeia quem vê
  - **Teste**: revisão independente comparando o runbook com `config/runtime.exs` e
    `deploy/signoz/`

- [ ] T030 Medir o custo da telemetria na entrada
  - **Pronta quando**: T012
  - **Descrição**: Verificação 1 da ADR 0005: 200 entradas com e sem a telemetria ligada, mesmo
    cenário, mediana comparada. SC-006.
  - **Feita quando**: a diferença está na ADR, com o comando; acima de 5%, a ADR volta à mesa
    (alternativa "log estruturado")
  - **Teste**: o script de medida, com a saída e o código de saída lidos

- [ ] T031 Rodar os gates e abrir o PR
  - **Pronta quando**: T004–T023, T029, T030
  - **Descrição**: `mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"`; `git status --short` limpo;
    corpo do PR a partir do template; revisor a equipe `the-band`; merge commit ou squash
    declarado.
  - **Feita quando**: `EXIT=0` lido; `gh pr view <n> --json reviewRequests` não vazio
  - **Teste**: o próprio código de saída

## Dependências

```
T001 ──> T002 ──> T003 ──> T004 ──> T005 ──> T008 ──> T009 ──> T010 ──> T011
  │                  │                                                    │
  └──> T006, T007    └──> (sem T003, nenhum código)       T011 ──> T012 ──> T013 ──> T014
                                                           T011 ──> T016, T017, T021
                                       T012 + T013 ──> T015 · T012..T017 ──> T018, T019
                                       T006 + T012 + T016 ──> T020, T022 ──> T023
               T024 + T025 + T006 ──> T026 ──> T027 ──> T028 · T026 ──> T029
```

## Paralelo

- T006 e T007 rodam juntas depois de T001.
- Depois de T011: T012, T016, T017 e T021 tocam arquivos diferentes [P].
- T024 e T025 (👤) correm em paralelo com todo o código.

## Estratégia

**MVP = Fases 0 a 5** (US1, US2 e US3 juntas): a US3 é a condição de a US1 ir para produção, e não
um polimento. US4 e US5 vêm depois. A Fase 8 só começa com os seis itens de S6 verificáveis — o
código pode ser mergeado com a telemetria **desligada** (FR-015) antes disso, e não muda nada para
quem entra.

## Issues (criadas em 2026-10-03 por `/speckit-taskstoissues`)

Todas na iteração *Sprint 035* do projeto. User stories com label `us` e filhas do épico #802;
tarefas com o tipo **Task**, filhas da US quando têm uma, e do épico quando são de fase (0, 1, 2
e 8).

| US | issue | tarefas |
|---|---|---|
| US1 | #1230 | T012 #1246 · T013 #1247 · T014 #1248 · T015 #1249 |
| US2 | #1231 | T016 #1250 · T017 #1251 |
| US3 | #1232 | T018 #1252 · T019 #1253 · T020 #1254 |
| US4 | #1233 | T021 #1255 |
| US5 | #1234 | T022 #1256 · T023 #1257 |
| épico | #802 | T001 #1235 (fechada) · T002 #1236 (fechada) · T003 #1237 · T004 #1238 · T005 #1239 · T006 #1240 · T007 #1241 · T008 #1242 · T009 #1243 · T010 #1244 · T011 #1245 · T024 #1258 · T025 #1259 · T026 #1260 · T027 #1261 · T028 #1262 · T029 #1263 · T030 #1264 · T031 #1265 |

Fora da 074, da decisão D7: #1229.
