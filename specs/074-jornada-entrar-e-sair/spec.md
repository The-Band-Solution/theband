# Feature Specification: A jornada de entrar e sair, vista por quem opera

**Feature Branch**: `feature/802-tracing-signoz`

**Created**: 2026-10-03

**Status**: Draft — emendada em 2026-10-03 com as decisões da [avaliação de segurança](seguranca.md)
que não são da pessoa mantenedora (anotadas *(seguranca.md, Sn)* em cada requisito). As decisões
D1–D7 da avaliação foram **decididas pela pessoa mantenedora em 2026-10-03**, todas pela
recomendação (ver *Decisões de 2026-10-03*, abaixo); a ADR 0005 foi **aceita** na mesma data.

**Input**: pedido da pessoa mantenedora no [ÉPICO #802](https://github.com/The-Band-Solution/theband/issues/802):
*"quero saber quem deu erro ao fazer login ou logout"* (2026-09-04), e a direção de 2026-09-27:
*"criar os tracing no signoz, baseado nos cenários e nas jornadas"*. Primeira fatia vertical do
épico: a **J1, entrar e sair**, de `docs/backlog/observabilidade-com-opentelemetry.md`. Arquitetura
em [ADR 0005](../../docs/adr/0005-telemetria-da-jornada.md), com a emenda de 2026-10-03 (SigNoz).

## O que já existe, medido e não suposto

| fato | onde |
|---|---|
| a recusa de login devolve **um** `{:error, :invalid_credentials}` para todo motivo, e a tela mostra **uma** frase (FR-002 da 045) | `lib/the_band/tenants/auth.ex:40-55`; `lib/the_band_web/controllers/session_controller.ex:24` |
| o motivo interno **já é nomeado** em cinco valores: `identificador_nao_resolveu`, `organizacao_suspensa`, `conta_desativada`, `conta_sem_senha`, `senha_errada`; e a espera crescente devolve `{:throttled, s}` | `auth.ex:84-145`, `:150-175` |
| os motivos vão hoje **só para o log** da aplicação, por `TheBand.Tenants.AccessEvents` — `entrada_aceita/3`, `entrada_recusada/3`, `espera_acionada/3`, `sessao_derrubada/3` | `lib/the_band/tenants/access_events.ex:66-140` |
| **sair** encerra a sessão no servidor só se havia sessão conferida; sem ela, apaga o cookie e redireciona **sem dizer nada**. `Sessions.encerrar/1` devolve `:ok` mesmo quando a sessão já estava encerrada | `session_controller.ex:44-50`; `lib/the_band/tenants/sessions.ex:119-127` |
| a queda de sessão já tem motivo (`:sem_sessao`, `:organizacao_suspensa`, `:conta_desativada` e os de `Sessions.motivo()`) | `lib/the_band_web/plugs/current_scope.ex:34-88` |
| definir a senha (fluxo da temporária) e trocar a senha recusam por motivos distintos, e nada os registra | `session_controller.ex:52-140` |
| **não existe entrar pelo GitHub** (OAuth): a spec 049 está em Draft e não há rota. O "usuário do GitHub" de hoje é só um **identificador** digitado com senha | `lib/the_band_web/router.ex:283-291`; `specs/049-entrar-com-github/spec.md` |
| **não existe "tenant errado"**: o identificador é global e o tenant sai da conta autenticada | `auth.ex:12-17` |
| **não existe "vínculo expirado"** na definição de senha: o fluxo é por senha temporária, sem link | `session_controller.ex:78-125` |
| `TheBandWeb.Telemetry` declara métricas e **não tem exportador**; não há dependência OpenTelemetry | `lib/the_band_web/telemetry.ex`; `mix.exs` |
| a redação dos parâmetros de consulta das tabelas cifradas está no PR #1227 (#1222), **não mergeado**, com a fonte `TheBand.Rotacao.campos_cifrados/0` | `lib/the_band/rotacao.ex:41`; branch `fix/1222-segredo-no-log-debug` |
| a 064/US3 (*segredo nunca chega a log, erro ou campo de diagnóstico*, #887) está aberta só à espera da aceitação do Product Owner: as três tarefas, #871, #872 e #873, estão **fechadas** (conferido em 2026-10-03). O comentário de 2026-09-27 do #802 põe este épico depois dela | `gh issue view 871`, `872`, `873` |

As linhas "não existe" mudam o desenho do backlog: a J1 do backlog lista *entrar pelo GitHub*,
*tenant errado* e *vínculo expirado*, e os três **não são passos nem desfechos possíveis hoje**.
Esta spec não os instrumenta. Declarar um desfecho que o código não pode produzir criaria uma
série que é sempre zero — e zero, aqui, mentiria ("ninguém falhou assim") em vez de dizer
"isto não existe".

## A régua: os cenários de aceitação viram os spans

A direção de 2026-09-27 é que **cada cenário Dado/Quando/Então** diga qual passo existe e qual
desfecho ele pode ter. A J1 já tem cenários escritos — os da spec 045. A tabela é o contrato
entre a spec antiga e o traço novo:

| cenário de origem | passo | desfecho | motivo |
|---|---|---|---|
| 045/US1 #7 — a tela de entrada aparece a qualquer visitante | `abrir_a_entrada` | `concluiu` | — |
| 045/US1 #1 e #2 — entra com e-mail, ou com o usuário do GitHub, e senha | `entrar_com_senha` | `concluiu` | — |
| 045/US1 #3 — senha errada | `entrar_com_senha` | `falhou` | `senha_errada` |
| 045/US1 #4 — o identificador não identifica conta | `entrar_com_senha` | `falhou` | `identificador_nao_resolveu` |
| 045/US1 #5 — elo revogado (o usuário do GitHub deixa de resolver) | `entrar_com_senha` | `falhou` | `identificador_nao_resolveu` |
| 045/US1 #8 — conta sem senha definida | `entrar_com_senha` | `falhou` | `conta_sem_senha` |
| achado H3, parte B (2026-09-09) — conta desativada | `entrar_com_senha` | `falhou` | `conta_desativada` |
| achado H3, parte A (2026-09-09) — organização suspensa | `entrar_com_senha` | `falhou` | `organizacao_suspensa` |
| 045 FR-016 — a espera crescente segurou a tentativa | `entrar_com_senha` | `falhou` | `em_espera` |
| abriu a entrada e não tentou | `abrir_a_entrada` | `abandonou` | — |
| 045/US1 #6 — encerra a sessão | `sair` | `concluiu` | — |
| sair sem sessão válida no servidor | `sair` | `falhou` | `sessao_ja_nao_existia` |
| 064 S5 / 070 — a sessão caiu sem a pessoa pedir | `sessao_derrubada` | `falhou` | o motivo de `CurrentScope` |
| 045 FR-013 — define a senha temporária | `definir_a_senha` | `concluiu` / `falhou` | `confirmacao_diferente`, `recusada_pela_regra`, `fora_do_fluxo` |
| 045/US3 #2 e #3 — troca a própria senha | `trocar_a_senha` | `concluiu` / `falhou` | `senha_atual_nao_confere`, `recusada_pela_regra`, `em_espera` e `tentativas_esgotadas` (os dois da issue #1409) |

## User Scenarios & Testing *(mandatory)*

Quem usa esta feature é **quem opera a plataforma** — hoje, a pessoa mantenedora. Quem entra e
sai não vê nada de novo: a tela de entrada continua idêntica, byte a byte.

### User Story 1 - Sei quem não conseguiu entrar, e por quê (Priority: P1)

Quem opera abre o painel de telemetria e vê, para um período, as tentativas de entrada **por
desfecho e por motivo**, por organização. Para os motivos que pedem ação de outra pessoa — conta
sem senha, conta desativada, organização suspensa —, vê **qual conta** foi, por um identificador
que só resolve para a pessoa dentro da plataforma, nunca pelo e-mail.

**Why this priority**: é o pedido literal da pessoa mantenedora, e os cinco motivos têm cinco
ações diferentes. Hoje eles existem só em linhas de log que ninguém agrega.

**Independent Test**: com a plataforma rodando localmente e o backend de telemetria local, fazer
uma entrada certa, uma com senha errada, uma com identificador inexistente e uma numa conta sem
senha. O painel mostra quatro tentativas, com os três motivos distintos, e a tela de entrada
mostrou a **mesma** frase nas três recusas.

**Acceptance Scenarios**:

1. **Given** uma conta com senha definida, **When** a pessoa entra com a senha certa, **Then** um
   passo `entrar_com_senha` com desfecho `concluiu` chega ao painel, com a organização e **sem**
   identificador de conta — salvo se o sucesso apagou tentativas falhas, quando o identificador
   vai junto, porque é o sinal de uma campanha que deu certo (FR-004).
2. **Given** uma conta com senha definida, **When** a pessoa digita a senha errada, **Then** o
   passo chega com `falhou` e `senha_errada`, **e** a tela mostra a frase única de sempre.
3. **Given** um identificador que não identifica conta, **When** alguém tenta entrar, **Then** o
   passo chega com `falhou` e `identificador_nao_resolveu`, **sem** identificador de conta e
   **sem** o que foi digitado, em nenhuma forma (nem truncado, nem com hash).
4. **Given** uma conta sem senha definida, uma conta desativada, ou uma conta de organização
   suspensa, **When** a pessoa tenta entrar, **Then** o passo chega com o motivo correspondente
   e o identificador opaco da conta, que quem opera usa para agir.
5. **Given** uma conta em espera crescente, **When** a pessoa tenta de novo antes da liberação,
   **Then** o passo chega com `falhou` e `em_espera`.
6. **Given** a tela de entrada aberta, **When** a pessoa não tenta entrar dentro da janela de
   abandono, **Then** o painel conta aquela abertura como `abandonou`.
7. **Given** qualquer uma das tentativas acima, **When** quem opera procura o traço, **Then** ele
   não contém senha, token, cookie, e-mail, o identificador digitado, nem código de segundo
   fator — e a [US3](#user-story-3---nada-disso-vaza-priority-p1) prova isso por teste.

---

### User Story 2 - Sei quando sair falhou (Priority: P1)

Quem opera vê as saídas por desfecho. Uma saída que não encerrou sessão nenhuma no servidor
aparece como falha nomeada, e as quedas de sessão que a pessoa não pediu aparecem com o motivo.

**Why this priority**: o pedido nomeia o logout. Uma saída que falha é invisível por definição: a
pessoa fecha a aba e vai embora. E a queda de sessão por conta desativada ou organização suspensa
é a prova de que os controles da 064 e da 070 agiram.

**Independent Test**: entrar e sair; depois, repetir o pedido de saída com o cookie antigo. O
painel mostra uma saída `concluiu` e uma `falhou` com `sessao_ja_nao_existia`. Desativar a conta
com uma tela aberta: aparece uma `sessao_derrubada` com `conta_desativada`.

**Acceptance Scenarios**:

1. **Given** uma sessão aberta, **When** a pessoa sai, **Then** o passo `sair` chega com
   `concluiu`, e a sessão está encerrada no servidor.
2. **Given** um pedido de saída sem sessão válida no servidor (cookie ausente, adulterado, ou de
   sessão já encerrada), **When** ele chega, **Then** o passo `sair` chega com `falhou` e
   `sessao_ja_nao_existia`, e a pessoa é levada à tela de entrada como hoje.
3. **Given** uma sessão aberta de uma conta que é desativada, ou de uma organização suspensa,
   **When** a próxima requisição dela chega, **Then** um passo `sessao_derrubada` chega com o
   motivo, e a pessoa vê o que já via.

---

### User Story 3 - Nada disso vaza (Priority: P1)

O que sai da aplicação para o backend de telemetria passa por uma lista fechada do que **pode**
sair. O que não está na lista não sai, e um teste injeta segredo de propósito e prova que ele
não chega ao exportador.

**Why this priority**: a telemetria é uma cópia do que acontece saindo do processo, com
controle de acesso diferente do banco (ADR 0005, S1). Sem esta história, a US1 e a US2 criam um
caminho novo para segredo sair, e não podem ir para produção. É P1 junto com elas, e não depois.

**Independent Test**: um teste troca **só o exportador interno** por um que entrega os spans ao
processo do teste, e mantém o filtro de produção no caminho (seguranca.md, S15). Ele faz os quatro
passos com valores-sentinela em todo campo de credencial (senha tentada, identificador, e-mail,
`password_hash`, senha temporária, atual e nova, o cookie inteiro, o token de CSRF), afirma
**primeiro** que chegaram spans dos quatro passos, e então varre nome, atributo, evento, status,
link e recurso, em claro, em Base64 e em `inspect`: nenhuma sentinela. Reprova com cada um dos
cinco defeitos injetados: sem o filtro; `inspect(changeset)` em `failure.reason`;
`set_attribute` direto no span corrente; `OTEL_RESOURCE_ATTRIBUTES` com sentinela;
`record_exception` com a sentinela na mensagem.

**Acceptance Scenarios**:

1. **Given** uma tentativa de entrada com senha, identificador e cookie sentinela, **When** os
   spans são exportados, **Then** nenhuma sentinela aparece em nome, atributo, evento ou recurso.
2. **Given** um atributo que não está na lista do que pode sair, **When** um passo o emite,
   **Then** ele é descartado antes do exportador, e o descarte é contado.
3. **Given** um motivo de falha ou um nome de jornada que não está declarado na base de
   conhecimento, **When** o gate roda, **Then** ele reprova.
4. **Given** o handler que traduz evento em span levanta exceção, **When** isso acontece, **Then**
   a aplicação segue, a entrada da pessoa não é afetada, e a perda é **dita** (contada e logada
   sem o conteúdo), em vez de a telemetria sumir em silêncio.
5. **Given** o backend de telemetria fora do ar, **When** a pessoa entra e sai, **Then** entrar e
   sair funcionam igual, e o que o exportador descartar é contado.
6. **Given** um passo cujo código tenta pôr no span uma mensagem de erro, uma exceção, um atributo
   fora da lista ou um valor fora da forma (por exemplo, o `inspect` de um changeset em
   `failure.reason`), **When** o span é exportado, **Then** nada disso sai, e o descarte é contado
   (FR-006, FR-017).
7. **Given** um pedido de entrada que traz um correlator nos parâmetros, **When** o passo é
   exportado, **Then** o correlator é o da sessão, e não o do pedido (FR-011).

---

### User Story 4 - Sei quando definir ou trocar a senha falhou (Priority: P2)

Quem opera vê as definições da senha temporária e as trocas de senha por desfecho e motivo.

**Why this priority**: *conta sem senha* (US1) pede que alguém reinicie a senha; esta história
mostra se a pessoa conseguiu defini-la depois. Fecha o ciclo, mas a US1 já entrega sem ela.

**Independent Test**: com uma conta de senha temporária, tentar definir com confirmação diferente,
depois com senha curta, depois certo. O painel mostra três passos `definir_a_senha`, dois com
motivo e um `concluiu`.

**Acceptance Scenarios**:

1. **Given** uma conta com senha temporária, **When** a confirmação não confere, **Then** o passo
   chega com `falhou` e `confirmacao_diferente`.
2. **Given** uma conta com senha temporária, **When** a senha nova é recusada pela regra, **Then**
   o passo chega com `falhou` e `recusada_pela_regra`.
3. **Given** uma sessão de conta em regime normal, **When** ela tenta a rota da senha temporária,
   **Then** o passo chega com `falhou` e `fora_do_fluxo`, e a sessão cai como hoje.
4. **Given** a tela de perfil, **When** a pessoa erra a senha atual ao trocá-la, **Then** o passo
   `trocar_a_senha` chega com `falhou` e `senha_atual_nao_confere`.

---

### User Story 5 - Quem opera encontra as respostas sem montar consulta (Priority: P2)

Um painel versionado no repositório responde às três perguntas da J1 — *quantas entradas por
desfecho e motivo, por organização*; *quais contas precisam de alguém (sem senha, desativada,
organização suspensa)*; *quantas saídas falharam* — e um alerta avisa quando a taxa de
`identificador_nao_resolveu` sobe acima do normal, que é o sinal de alguém adivinhando e-mails.

**Why this priority**: sem o painel, a resposta existe e depende de alguém lembrar a consulta.
É o que torna a fatia **visível**. P2 porque as consultas avulsas já respondem com a US1.

**Independent Test**: importar o painel no backend local, fazer as tentativas da US1 e ver as
três perguntas respondidas sem escrever consulta.

**Acceptance Scenarios**:

1. **Given** o painel importado, **When** houve tentativas no período, **Then** as três perguntas
   aparecem respondidas, por organização, e nenhuma delas por e-mail.
2. **Given** um período sem tentativa nenhuma, **When** o painel é aberto, **Then** ele diz que não
   houve tentativa, e não mostra zero como se fosse medida.
3. **Given** um pico de `identificador_nao_resolveu`, **When** ele passa do limiar declarado,
   **Then** o alerta dispara para quem opera.

---

### Edge Cases

- **O identificador digitado é um e-mail de verdade de outra pessoa.** Não entra em span em
  nenhuma forma; hash de e-mail é reversível por dicionário (ADR 0005, S1).
- **A mesma pessoa abre a tela em duas abas.** São duas aberturas; a que não tentou conta como
  `abandonou`. A janela de abandono é declarada, e o painel diz qual é.
- **A tentativa chega sem ter passado pela tela** (requisição direta ao endpoint de entrada).
  O passo `entrar_com_senha` existe sem `abrir_a_entrada` antes; é um sinal legítimo de
  automação, e não um erro de correlação.
- **O backend de telemetria demora ou cai.** O exportador é assíncrono; a entrada não espera
  por ele (US3, cenário 5).
- **O tempo de resposta não pode passar a distinguir motivos.** A emissão do passo não pode
  custar mais num motivo do que em outro, ou a telemetria criaria o oráculo de tempo que a 045 e
  a #1047 fecharam (FR-009).
- **Conta de outra organização.** O painel é de quem opera a plataforma, e não de quem administra
  uma organização; nenhuma conta de organização cliente o vê (ADR 0005, E5).
- **O PR #1227 (#1222) não foi mergeado.** A implementação não começa (D6). A #887 não bloqueia: as tarefas estão entregues.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A plataforma MUST emitir um passo de jornada para cada um dos passos da tabela *A
  régua*, com exatamente um desfecho entre `concluiu`, `falhou` e `abandonou`.
- **FR-002**: Todo passo com `falhou` MUST trazer um motivo da **lista fechada declarada** na base
  de conhecimento, e o motivo MUST ser o mesmo valor que a decisão de acesso já produz hoje.
- **FR-003**: A tela e a resposta HTTP MUST continuar idênticas entre os motivos de recusa de
  entrada (FR-002 da 045). A distinção existe **só** na telemetria. O passo de entrada MUST ser
  emitido **pelo domínio, depois da transação**, a partir de um relator interno; o controller
  MUST continuar recebendo só a recusa colapsada (`:invalid_credentials` ou `{:throttled, _}`);
  e **nenhuma escrita na sessão MUST depender do motivo**. *(seguranca.md, S4)*
- **FR-004**: Todo passo MUST carregar a organização (`tenant`) quando ela é conhecida. O
  identificador opaco da conta MUST ir só nos desfechos que pedem ação — as recusas com conta
  conhecida, a espera, a queda de sessão, a saída que falhou — e, no `concluiu` da entrada, **só
  quando o sucesso apagou tentativas falhas** (o sinal de campanha que deu certo). Quando o
  identificador digitado não resolve, o passo MUST NOT carregar nada que dependa do que foi
  digitado. *(seguranca.md, S14; padrão até a decisão D1 da pessoa mantenedora)*
- **FR-005**: Nenhum passo, evento, atributo, nome, status ou recurso exportado MUST conter senha
  (tentada, temporária, nova ou atual), hash de senha, token de sessão, cookie, token de CSRF,
  cabeçalho de autorização, segredo de ferramenta ou de provedor, chave, código de segundo fator,
  código de recuperação, e-mail, ou o identificador digitado — em claro, truncado ou com hash.
- **FR-006**: O que sai MUST ser **reconstruído no último ponto antes do envio**, a partir de uma
  lista fechada: nome de span de uma enumeração; atributos permitidos **por nome e pela forma do
  valor**, com as enumerações validadas contra a base de conhecimento; recurso reconstruído só com
  `service.name`, `service.version` e `deployment.environment`; **nenhum evento**; status sem
  descrição. Todo descarte MUST ser contado. O tradutor MUST montar atributos só dos campos
  permitidos, e a função de domínio que emite o passo MUST aceitar só id, átomo de lista e
  contagem. *(seguranca.md, S1)*
- **FR-007**: Um gate MUST reprovar passo, jornada ou motivo que não esteja declarado na base de
  conhecimento, e MUST reprovar motivo declarado que nenhum código produz.
- **FR-008**: Falha do tradutor de eventos ou do exportador MUST NOT afetar a jornada da pessoa e
  MUST NOT ser silenciosa. O tradutor MUST capturar exceção, `exit` e `throw`; o log da falha MUST
  ter só o tipo (nunca mensagem nem pilha); o contador de perda MUST viver **fora** do
  OpenTelemetry e ser logado periodicamente, junto com a conferência de que o tradutor continua
  anexado. *(seguranca.md, S11)*
- **FR-009**: A emissão do passo MUST ser assíncrona em relação ao backend e MUST NOT variar de
  custo conforme o motivo: o tradutor não consulta banco e faz o mesmo trabalho em todo ramo.
  *(seguranca.md, S4 — confirmada)*
- **FR-010**: O abandono MUST ser derivado na consulta (abertura sem tentativa correlacionada
  dentro da janela declarada), e não por processo que espera.
- **FR-011**: O correlator da jornada MUST nascer no servidor no `GET /sign-in`, com 16 bytes
  aleatórios; viver na sessão; ser substituído a cada abertura; ser lido **só da sessão**, nunca de
  parâmetro; ser apagado depois da tentativa, com qualquer desfecho; e ser validado na forma. MUST
  NOT derivar do token de sessão, do id da sessão ou da conta. `abrir_a_entrada` MUST ser emitido
  uma vez por visita, no `mount` conectado (o robô que não roda JavaScript não conta como
  abertura). `journey.id` MUST NOT ser dimensão de métrica. *(seguranca.md, S5)*
- **FR-012**: Nesta fatia **não** há span de consulta ao banco. Um span de consulta MUST exigir
  avaliação de segurança própria; a regra de `TheBand.Repo.LogDaConsulta` (fonte:
  `TheBand.Rotacao.campos_cifrados/0`, PR #1227) é **necessária e não suficiente**: `users`,
  `user_sessions` e as credenciais do operador também têm os parâmetros redigidos. *(seguranca.md, S3)*
- **FR-013**: O painel e o alerta da US5 MUST ser versionados no repositório. O alerta MUST ser
  sobre **métrica** (contagem), sem atributo de traço no corpo. *(seguranca.md, S8, S12)*
- **FR-014**: O ambiente de desenvolvimento MUST poder subir o backend de telemetria localmente,
  sem tocar no Postgres de desenvolvimento, para medir.
- **FR-015**: A aplicação MUST configurar o SDK **explicitamente**, a partir de variáveis cujos
  **nomes** estão na lista fechada do runbook; nenhum valor no repositório. O destino MUST ser
  validado contra os hosts permitidos; destino fora da lista desliga a telemetria e loga o
  **nome** da variável, nunca o valor. Sem variável, nenhum exportador é configurado, a aplicação
  MUST subir e MUST dizer no log que a telemetria está desligada. *(seguranca.md, S10)*
- **FR-016**: Os passos MUST ser exportados sem amostragem nesta fatia.
- **FR-017**: Nenhum passo MUST registrar exceção, pilha ou mensagem de erro no span. O passo MUST
  ser emitido com `:telemetry.execute/3` **depois** da decisão, e nunca com `:telemetry.span/3` em
  volta de função que recebe credencial. *(seguranca.md, S1, S11)*

### Key Entities

- **Jornada**: o que a pessoa veio fazer (`entrar_e_sair`). Declarada, com seus passos.
- **Passo**: uma tentativa de fazer uma coisa (`entrar_com_senha`, `sair`…). Tem início, fim,
  desfecho e, se falhou, motivo. Vira um span.
- **Desfecho**: `concluiu`, `falhou`, `abandonou` — lista fechada.
- **Motivo de falha**: lista fechada por passo, declarada, com o cenário de origem.
- **Correlator da jornada**: valor aleatório que liga a abertura da tela à tentativa, e nada mais.
- **Identificador opaco da conta**: o que permite a quem opera agir sobre a conta dentro da
  plataforma, sem expor e-mail.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Para cada linha da tabela *A régua*, um teste produz o passo e afirma o desfecho e o
  motivo — 15 de 15 linhas cobertas.
- **SC-002**: O teste das sentinelas (US3) varre 100% dos spans exportados numa sessão de testes da
  J1 e encontra **zero** ocorrências; com o filtro removido, encontra pelo menos uma.
- **SC-003**: As respostas de recusa de entrada continuam byte-idênticas entre os seis motivos
  (o teste da 045 que usa `Enum.uniq` continua passando), **e o conjunto de chaves da sessão no
  `Set-Cookie` é o mesmo nos seis**.
- **SC-004**: Com o backend de telemetria parado, entrar e sair funcionam em 10 de 10 tentativas.
- **SC-005**: Quem opera responde *"quem não conseguiu entrar ontem, e por quê"* em menos de um
  minuto, abrindo o painel, sem escrever consulta.
- **SC-006**: O custo de uma entrada com a telemetria ligada fica dentro de 5% da mediana sem ela,
  medido no mesmo cenário (Verificação 1 da ADR 0005).
- **SC-007**: A memória do backend de telemetria no VPS, ocioso, está medida e registrada na ADR,
  e é menor que o teto declarado (3 GB para os quatro contêineres).

## Assumptions

- O backend é o **SigNoz**, auto-hospedado (decisão da pessoa mantenedora em 2026-09-27; ADR 0005,
  emenda de 2026-10-03, aceita em 2026-10-03), no mesmo VPS (D3).
- A ADR 0005 e as dependências novas foram **aceitas** em 2026-10-03 (D5). O código continua
  esperando a ordem de D6.
- D6: o código espera a #1227 mergeada; a #887 tem as tarefas entregues (#871, #872, #873 fechadas) e espera aceitação. A #1162 (distribuição Erlang em `0.0.0.0`) vem antes do deploy do SigNoz no
  mesmo VPS.
- O identificador opaco da conta é o `id` da conta, com a minimização da FR-004 (D1).
- A implantação do SigNoz fica **bloqueada** até os seis itens de S6 da avaliação terem evidência
  lida (ADR 0005, E7). O código da aplicação não fica: com a telemetria desligada, nada muda.
- A janela de abandono é de 30 minutos, o tempo em que uma tela de entrada aberta ainda é a mesma
  intenção. Ajustável sem mudar código (é parâmetro da consulta).
- Retenção: traços 7 dias, métricas 30 dias, sem log (ADR 0005, E4; D4).

## Decisões de 2026-10-03

Decididas pela pessoa mantenedora; opções em [seguranca.md](seguranca.md).

| | decisão |
|---|---|
| ADR 0005 | **aceita**, com o SigNoz |
| D1 | `users.id` cru com minimização (FR-004); HMAC quando outra pessoa ganhar acesso ao SigNoz |
| D2 | painel só por túnel SSH |
| D3 | mesmo VPS via Dokploy, teto de 3 GB, rede dedicada aplicação↔coletor, nenhuma porta publicada; cai se o VPS tiver menos de 4 GB livres (T024) |
| D4 | traços 7 dias, métricas 30 dias, nenhum log; volume do ClickHouse fora do backup |
| D5 | as dependências aceitas, com versão exata e teto no `grpcbox` |
| D6 | o código espera a #1227 mergeada; a #887 tem as tarefas entregues (#871, #872, #873 fechadas) e espera aceitação; a #1162 antes do deploy |
| D7 | limite por IP fora da 074: [#1229](https://github.com/The-Band-Solution/theband/issues/1229) |

## Fora de escopo

- **Entrar pelo GitHub** (OAuth): não existe; entra quando a 049 entrar.
- **A entrada do operador da plataforma** (`/platform/sign-in`, com segundo fator, spec 070): é
  outra jornada, com outro público e outro motivo de falha (o segundo fator). Próxima fatia, com
  o mesmo filtro.
- **A primeira conta do ambiente** (052): acontece no boot, não é jornada de quem usa.
- J2 a J6, a US3 do épico (perceber o Oban parado) e qualquer instrumentador automático (rota,
  consulta, job, HTTP de saída) — ADR 0005, E6.
- Trilha de auditoria (ADR 0005, S6).
