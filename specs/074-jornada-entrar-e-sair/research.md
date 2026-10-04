# Research: a jornada de entrar e sair (074)

Cada decisão: **Decisão**, **Razão**, **Alternativas**. As decisões de arquitetura estão na
[ADR 0005](../../docs/adr/0005-telemetria-da-jornada.md) (e na emenda de 2026-10-03); aqui ficam
as de implementação que a ADR deixou abertas. As que dependem da pessoa mantenedora estão
marcadas **[PM]**; todas foram decididas em 2026-10-03 (ver a spec, *Decisões de 2026-10-03*).

## R1. De onde vem o passo: `AccessEvents` emite, um handler traduz

**Decisão**: o passo nasce de `:telemetry.execute([:the_band, :jornada, :passo], medidas,
metadados)`, emitido por **uma função nova** de `TheBand.Tenants.AccessEvents`, `passo/1`, que
recebe só átomos de lista, ids e o correlator. Um handler, `TheBand.Telemetria.Jornada`, anexado
no boot, traduz o evento em span.

**Quem chama, e quando** (seguranca.md, S4): para a entrada, **`Auth.authenticate/3` depois da
transação**. Hoje `recusar/2` roda **dentro** da transação com `FOR UPDATE` para a conta que
resolve, e fora dela para o identificador que não resolve (`auth.ex:47-73`); emitir ali faria o
custo do passo cair num ramo e não no outro. A transação passa a devolver um relator interno
`{decisão, motivo, conta_conhecida?}`, e `authenticate/3` emite **um** passo depois dela, em
todos os ramos, e devolve ao controller exatamente o que devolve hoje. As funções de log que
existem (`entrada_aceita/3`, `entrada_recusada/3`…) **não mudam** — o log continua com o que já
tem. Para sair, definir e trocar a senha: `SessionController`, depois da decisão. Para a queda:
`CurrentScope.sem_sessao/3`, ao lado de `AccessEvents.sessao_derrubada/3`.

**Razão**: os motivos já estão nomeados em `Auth` e `CurrentScope`, e `AccessEvents` já é o
ponto único que recebe identificadores e motivos, **nunca credencial** — "não é uma disciplina de quem chama, é o que a
assinatura das funções permite passar" (`access_events.ex:44-50`). Emitir o evento ao lado do
log herda essa garantia de graça: o handler só vê o que a assinatura deixou passar.

**Alternativas**: (a) `Tracer.with_span` dentro de `Auth.authenticate/2` — acopla o domínio ao
OpenTelemetry, o que a decisão 1 da ADR proíbe, e o span envolveria o Bcrypt, cujo tempo é o que
a 045 iguala entre motivos; (b) instrumentador de Phoenix — dá a rota, não o motivo (ADR,
alternativas).

## R2. O span tem início e fim, mas o passo é um instante

**Decisão**: nesta fatia o evento **não carrega duração** (`medidas = %{}`, contrato §1), e todo
span é instantâneo: o handler o abre e o fecha no mesmo instante. Se uma fatia futura quiser
duração, ela entra por um passo que não envolva credencial, e com o teste de R9.

**Razão**: o span existe para carregar desfecho e motivo, e não latência — o épico não é APM.
Medir a duração da autenticação inteira (com o Bcrypt) e exportá-la **por motivo** recriaria o
oráculo de tempo no painel; ver R9.

**Alternativas**: `:telemetry.span/3` em volta da autenticação — exporta exatamente a duração que
não se quer distinguir por motivo.

## R3. O que pode sair: lista fechada aplicada no exportador

**Decisão**: um exportador próprio, `TheBand.Telemetria.Exportador`, implementa o behaviour
`:otel_exporter` e **envolve** o exportador OTLP. Antes de delegar, ele reescreve cada span
mantendo **só** os atributos cujo nome está na lista permitida (`journey.name`, `journey.step`,
`journey.id`, `outcome`, `failure.reason`, `tenant.id`, `user.ref`), descarta **todos** os
eventos e links, confere o **valor** de cada atributo contra o formato declarado (UUID,
enumeração da base, correlator), confere o **nome do span** contra a enumeração dos passos,
apaga a **descrição do status**, e **reconstrói o recurso** a partir de três chaves fixas — não o
filtra a partir do que o SDK detectou (seguranca.md, S1). Atributo, valor, evento ou span fora da
regra é descartado e **contado**.

**Três camadas, e só a primeira é a garantia**: (1) o exportador; (2) o handler monta atributos
só dos campos permitidos da metadata, nunca da metadata inteira; (3) `AccessEvents.passo/1` só
aceita átomo de lista, id e contagem, então nenhum outro handler anexado ao mesmo evento recebe
struct de conta, `conn` ou changeset.

**Razão**: ADR 0005, S1 — *"a garantia é filtro no exportador, não disciplina de quem escreve"*.
Lista permitida, e não lista proibida: uma lista proibida precisa prever o nome do próximo
vazamento; a permitida só precisa conhecer os sete nomes que existem. Também cobre o recurso
(`resource`): `service.name`, `service.version` e `deployment.environment`, e nada de
`host.name` com o nome do VPS.

**Alternativas**: (a) filtrar só no handler — vale enquanto o handler for o único criador de
span; o primeiro instrumentador que alguém ligar passaria por fora; (b) processador no coletor
(`attributes/delete`) — o segredo já teria saído do processo; (c) `otel_span_processor`
customizado — o `on_end` recebe o span pronto e não o reescreve, só decide se exporta.

## R4. Testar com o exportador em memória

**Decisão**: em `config/test.exs`, `traces_exporter: :none` e `processors:
[{:otel_simple_processor, %{}}]`. Cada teste chama
`:otel_simple_processor.set_exporter(TheBand.Telemetria.Exportador, %{destino: {:otel_exporter_pid, self()}})`
— o **filtro real** fica no caminho, e o destino é o processo do teste, que recebe
`{:span, span}`. Os campos do span são extraídos com `Record.extract(:span, from_lib:
"opentelemetry/include/otel_span.hrl")`, como na documentação oficial
([opentelemetry.io/docs/languages/erlang/testing](https://opentelemetry.io/docs/languages/erlang/testing/)).

**Razão**: o teste das sentinelas (US3) precisa atravessar o mesmo filtro que a produção usa. Um
teste que captura o span **antes** do filtro provaria que o handler é cuidadoso, e não que nada
sai — a diferença entre disciplina e garantia.

**Alternativas**: Mox no exportador — mock de módulo próprio, que a casa proíbe (§7.7); o
`:otel_exporter_pid` puro, sem o filtro — testaria a coisa errada.

## R5. O correlator da jornada

**Decisão** (seguranca.md, S5): um plug, só na rota `GET /sign-in`, **substitui** na sessão do
Phoenix `:jornada_id = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)` a cada
abertura. LiveView não escreve cookie de sessão (é a razão de `set_password` viver num
controller, `session_controller.ex:78-81`), por isso o valor nasce no plug. O passo
`abrir_a_entrada` é emitido **uma vez**, no `mount` **conectado** do `SessionLive.New`
(`connected?(socket)`), lendo o valor da sessão: o `mount` roda duas vezes, e o robô que não roda
JavaScript não abre o socket — não conta como abertura, e o painel diz isso.
`SessionController.create/2` lê o correlator **só da sessão** (nunca dos parâmetros), o põe no
passo `entrar_com_senha` e o **apaga**, com **qualquer** desfecho — o mesmo apagamento para os
seis motivos, porque o cookie é assinado e não cifrado (`endpoint.ex:4-14`) e uma chave apagada
num motivo e não noutro diria ao cliente qual aconteceu (S4). Valor ausente ou fora da forma vira
passo **sem** `journey.id`. Sair e as quedas não carregam correlator (não há
abertura a correlacionar). Formato validado no exportador (R3): 22 caracteres base64url.

**Razão**: FR-011. Vive no cookie **assinado** do Phoenix, então o cliente não o escolhe; é
aleatório, então não deriva da sessão nem da conta; e morre na tentativa, então não vira
identificador de longo prazo da pessoa.

**Alternativas**: o `request_id` — muda a cada requisição, não correlaciona; o id da sessão —
proibido por FR-011.

## R6. O abandono é consulta, não processo

**Decisão**: `abandonou` não é emitido pela aplicação. O painel (US5) conta aberturas
(`abrir_a_entrada`) cujo `journey.id` não aparece num `entrar_com_senha` em até 30 minutos.

**Razão**: FR-010. Um processo que espera 30 minutos por pessoa que abriu a tela é estado em
memória que morre no deploy e mente ao voltar. A consulta é recalculável e não perde nada.

**Alternativas**: um job Oban agendado por abertura — um job por visitante anônimo é vetor de
negação de serviço gratuito.

## R7. A taxonomia mora em `rules/`, e não numa pasta nova

**Decisão**: `priv/knowledge_base/rules/journey_entrar_e_sair.yaml`, `derivation_rule` com id
`journey.entrar_e_sair`, na forma de `access_account_lifecycle.yaml`: passos, desfechos, motivos
de cada passo, e o **cenário de origem** de cada motivo (a tabela *A régua* da spec).

**Razão**: princípio VIII. A ADR 0005 (decisão 5) previa `priv/knowledge_base/journeys/`, e uma
pasta nova pede schema novo, validador novo e entrada no manifesto — para **uma** jornada. A
forma `derivation_rule` já é validada, já tem precedente para vocabulário de acesso
(`access.account_lifecycle`, `access.account_role`) e já é lida em runtime. Na terceira jornada
declarada (J1, J2, J4), a pasta própria se paga e a mudança é mecânica.

**O que fica pior**: `rules/` mistura regras de derivação com taxonomia de telemetria. É
aceitável enquanto houver uma.

**Alternativas**: a pasta `journeys/` da ADR — adiada pela regra dos três, e a ADR é anotada.

## R8. O gate da taxonomia

**Decisão**: um teste, `test/the_band/telemetria/taxonomia_test.exs`, que (a) lê o YAML e o
compara com os motivos que o código produz — lidos das cláusulas de `Auth`, `CurrentScope` e
`SessionController` por **valor de retorno** e não por texto, emitindo cada motivo num caso e
coletando o que chega ao exportador; (b) reprova motivo emitido e não declarado; (c) reprova
motivo declarado que nenhum caso produz. O exportador (R3) também descarta `failure.reason` fora
da lista, e conta.

**Razão**: FR-007, ADR decisão 5. A lição "guarda que lê código reprova a prosa" (memória de
2026-09) pede que o gate teste o **comportamento**, e não o texto-fonte.

## R9. O tempo não pode distinguir motivos

**Decisão**: a emissão é `:telemetry.execute`, síncrona e barata (lookup em ETS mais a criação do
span em memória); a exportação é do `BatchProcessor`, assíncrona. O custo da emissão é o mesmo
para todos os motivos, porque o caminho é o mesmo. SC-006 mede o custo total; um teste mede a
**diferença** entre motivos e falha se a mediana de um passar 0,25 ms da mediana de outro.

**Corrigido na implementação (2026-10-03)**: o limiar era 2 ms, e foi medido insuficiente. A
emissão custa ~0,1 ms por motivo, e as medianas divergem ~17 µs sem defeito. Com o defeito de
T015 injetado — uma consulta no handler só quando há conta —, os motivos com conta foram a
0,5–2,8 ms e o sem conta ficou em 0,13 ms; a divergência ficou abaixo de 2 ms em uma de duas
rodadas, e o defeito passaria. Com 0,25 ms, o defeito reprovou em quatro de quatro rodadas
(menor divergência: 503 µs) e o código sem defeito passou em cinco de cinco
(`test/the_band/telemetria/tempo_por_motivo_test.exs`).

**Razão**: FR-009. A 045 e a #1047 gastaram trabalho para igualar o tempo entre motivos; a
telemetria não pode desfazê-lo.

## R10. Dependências

Ver ADR 0005, E6. Entram `opentelemetry_api` 1.5.0, `opentelemetry` 1.7.0 e
`opentelemetry_exporter` 1.11.0, fixadas com `==`, como a casa já faz com `nimble_totp` e
`ex_mcp` (`mix.exs:152`, `:188`), e `grpcbox ~> 0.18.0` declarada direto só para pôr o teto que o
exportador não põe (seguranca.md, S9). **Nenhum instrumentador.** Aceitos em 2026-10-03
(D5).

## R11. Configuração

**Decisão** (seguranca.md, S10): em `config/runtime.exs`, a aplicação configura o SDK
**explicitamente** — o exportador, o endpoint, o protocolo e o recurso — a partir de
`THE_BAND_OTLP_ENDPOINT`, variável **da casa**, e não da `OTEL_EXPORTER_OTLP_ENDPOINT` que o SDK
leria sozinho. O host do endpoint é validado contra a lista de hosts permitidos (o nome do serviço
do coletor na rede interna, e `127.0.0.1` em desenvolvimento); fora da lista, a telemetria fica
desligada e o log diz o **nome** da variável, nunca o valor. Sem a variável:
`traces_exporter: :none` e *"telemetria desligada: THE_BAND_OTLP_ENDPOINT ausente"*. **A
verificar na T006**: se o SDK 1.7.0 ainda lê `OTEL_*` depois da configuração explícita — o teste
sobe com `OTEL_EXPORTER_OTLP_ENDPOINT` apontando para fora e prova que o exportador não vai para
lá. Protocolo `http_protobuf`. Nome do serviço
`the_band`, ambiente de `THE_BAND_AMBIENTE` (ou `prod`). **Sem amostragem** (FR-016).

As variáveis de produção são **nomes**, e entram na lista fechada do runbook (§2):

| variável | valor (descrito, nunca escrito) |
|---|---|
| `THE_BAND_OTLP_ENDPOINT` | `http://<nome do serviço do coletor na rede dedicada>:4318` |
| `SIGNOZ_TOKENIZER_JWT_SECRET` | no serviço **do SigNoz**, nunca no da aplicação; gerado com `openssl rand -hex 32` |

**Razão**: FR-015. A ausência não impede o boot — como a primeira conta (052) — e é **dita**.

**Verificado na T005 (2026-10-03), lendo o código do SDK em `deps/`**: sim, `OTEL_*` **vence** a
configuração explícita, nos dois pacotes.

- `opentelemetry` 1.7.0, `otel_configuration:merge_list_with_environment/3`: `os:getenv(OSVar)`
  é lido **antes** de `AppEnv`. `OTEL_TRACES_EXPORTER`, `OTEL_TRACES_SAMPLER`, `OTEL_SDK_DISABLED`,
  `OTEL_BSP_*` vencem `config :opentelemetry`; e `merge_processor_config_/4` deixa
  `traces_exporter` vindo do ambiente **substituir o exportador do processador** — os spans
  sairiam por fora do filtro;
- `opentelemetry_exporter` 1.11.0, `otel_exporter_otlp:merge_with_environment/8` e
  `update_opts/6`: `OTEL_EXPORTER_OTLP_ENDPOINT`, `..._TRACES_ENDPOINT`, `..._HEADERS`,
  `..._PROTOCOL` substituem até o `endpoints` passado direto ao `init/1`;
- o detector de recurso padrão lê `OTEL_RESOURCE_ATTRIBUTES` e `OTEL_SERVICE_NAME`.

**Decisão**: `config/runtime.exs` **apaga** do ambiente do processo toda variável `OTEL_*` antes
de o SDK subir (`TheBand.Telemetria.Configuracao.neutralizar_ambiente_otel/0`), e o boot loga os
**nomes** apagados. O recurso é reconstruído pelo exportador de qualquer forma (R3). Validação do
endpoint: `http`, host em `["127.0.0.1", "localhost", "signoz-otel-collector"]`, porta 4318, sem
caminho, credencial, consulta ou fragmento. Ambiente em `THE_BAND_AMBIENTE`, na forma
`[a-z0-9_-]{1,32}`, ou `prod`. Amostrador `always_on`, explícito.

## R12. Ambiente de desenvolvimento

**Decisão**: um profile `telemetria` no `compose.yaml`, com o SigNoz gerado por
`foundryctl forge` e as imagens fixadas, portas só em `127.0.0.1` (painel `3301`, OTLP `4318`).
Sem o profile, `docker compose up` continua subindo só o Postgres. O projeto do compose é o mesmo,
e os serviços novos têm nomes próprios: o `the_band_postgres` não é tocado.

**Razão**: FR-014, e o precedente dos profiles `producao` e `backup`.

**Risco medido**: a medida da ADR (E3) achou o coletor de pé com configuração `nop` quando a
versão do servidor e a do coletor não casavam. O quickstart confere que um span **chegou**.

## R13. Contar a perda — onde o contador mora, e o que ainda está em aberto

**Decisão** (seguranca.md, S11): os contadores de perda (`handler_falhou`, `atributo_descartado`,
`span_descartado`) vivem em `:counters`, **fora** do OpenTelemetry — contar a perda pelo mesmo
cano que perdeu é circular: com o exportador parado, o contador some junto. O `telemetry_poller`
que já existe (`lib/the_band_web/telemetry.ex:14`) os loga periodicamente em `warning` quando não
são zero, e na mesma rodada confere que o handler continua anexado
(`:telemetry.list_handlers([:the_band, :jornada, :passo])`), logando `error` se não estiver.

**Em aberto**: **não foi verificado** se o `otel_batch_processor` de `opentelemetry 1.7.0` expõe
o descarte por fila cheia. A tarefa que configura o SDK lê
`deps/opentelemetry/src/otel_batch_processor.erl` e mede com o coletor parado e fila pequena; se
a biblioteca não disser, o exportador conta o que recebe contra o que o handler emitiu, e a
diferença é a perda. Afirmar que o SDK expõe sem ler seria a *limitação declarada sem olhar o
dado* que a casa já cometeu duas vezes.

**Lido na T005/T020 (2026-10-03)**: `otel_batch_processor.erl` 1.7.0 **não expõe** o descarte.
Com a fila no teto (`check_table_size`), `disable/1` desliga a inserção e `do_insert/2` devolve
`dropped` a `on_end/2`, cujo retorno ninguém conta. Por isso a perda é a diferença entre
`passo_emitido` (contado pelo handler) e `span_exportado` + `span_descartado` (contados pelo
filtro), com os spans em trânsito dentro dela; e a recusa do destino (coletor fora) é
`exportacao_falhou`, rotulada pelo retorno.

**Inundação** (seguranca.md, S12): o identificador que não resolve não entra em espera
(`auth.ex:47-50`), então uma campanha de adivinhação gera um span por tentativa e enche a fila —
e o que se perde são os spans da campanha. Por isso o alerta da US5 é sobre o **contador** por
motivo, contado **antes** do descarte, e o coletor tem `memory_limiter`. Limite por IP em
`POST /session` é a decisão D7, fora desta fatia.
