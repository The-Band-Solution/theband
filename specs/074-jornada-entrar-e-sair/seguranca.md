# Avaliação de segurança da spec 074, antes do plano e do código

**Feature**: `specs/074-jornada-entrar-e-sair/spec.md`, a J1 do [ÉPICO #802](https://github.com/The-Band-Solution/theband/issues/802)
**Data**: 2026-10-03
**Papel**: Security (`AGENTS.md` §13 e §14.0). **Não escrevi este desenho**: a spec e a emenda de
2026-10-03 da ADR 0005 são de outro agente.
**Natureza**: leitura do desenho (spec e ADR 0005, inclusive a emenda E1–E7 e a seção S1–S6), do
código que a spec cita, do diff do PR #1227 e de metadados públicos do `hex.pm` (API, consultada
em 2026-10-03). **Não é varredura completa**, e nenhum gate foi rodado: a instrução desta
avaliação vedou `mix test` e `mix gates`. Afirmações sobre o código vêm de leitura, com arquivo e
linha.

**Sobre as marcas [seg] da spec.** A spec chegou com seis itens marcados *"[seg]"*, descritos
como decisões desta avaliação, escritos antes de ela existir. Abaixo eles foram conferidos um a
um: FR-009 e o caso de borda do tempo **se confirmam**; FR-006, FR-011, FR-012 e FR-015 **se
confirmam na direção, e não bastam** como estão (S1, S5, S3, S10). A marca não substitui a
avaliação, e a lacuna fica declarada aqui em vez de presumida cumprida.

## Resumo

O desenho acerta no que é mais difícil de consertar depois: o domínio não conhece OpenTelemetry,
há **um** tradutor de eventos em span, nenhum instrumentador automático entra nesta fatia (E6), o
motivo de recusa é distinto **só** na telemetria (FR-003), o identificador digitado nunca sai, nem
com hash (FR-005), e o backend fica no próprio servidor porque o dado tem identidade (E1).

Os riscos que sobram estão em três lugares.

1. **O filtro do que sai está descrito de dois jeitos incompatíveis, e nenhum dos dois fecha.** A
   ADR S1 pede *deny-list* (`docs/adr/0005-telemetria-da-jornada.md:149`); a spec, FR-006, pede
   lista do que **pode** sair, por **nome** de atributo. Uma lista por nome deixa passar segredo
   dentro de um nome permitido (`failure.reason` com o `inspect` de um changeset), e um filtro
   que mora só no tradutor não vê o recurso, os eventos de exceção nem o atributo posto por
   qualquer outro código no span corrente (S1).
2. **A própria ADR ainda prescreve dois caminhos de atributos que contornam o filtro.** A decisão
   2 anexa `attach_hook(:handle_event)` em toda LiveView (`ADR:70`), e esses eventos carregam o
   token do GitHub e a chave do provedor de modelos digitados nas telas de ferramenta (S2). E a
   FR-012 promete, para um futuro span de consulta, *"a mesma regra"* do PR #1227. Ela não basta:
   a regra redige só tabelas com campo cifrado, e a consulta que resolve o login passa o
   identificador digitado como parâmetro sobre `users`, que não está na lista (S3).
3. **O SigNoz é uma superfície nova com credencial de painel, banco sem senha e portas abertas no
   compose de referência**, numa rede Docker compartilhada onde a distribuição Erlang da
   aplicação já escuta em `0.0.0.0` (#1162). A emenda E2/E5 escreve as regras certas; o que falta
   é **verificar de fora** que elas valem, porque o Docker publica porta por cima do firewall do
   host (S6, S7).

## Veredito

**Pode seguir para o plano, com condições.** Nenhum achado exige refazer o desenho; todos se
fecham com redação na spec e na ADR, e com tarefas de verificação. As condições:

1. **Antes do `/speckit-plan`**: a spec incorpora as emendas da seção *"Decisões que a spec pode
   incorporar já"*, e a ADR 0005 resolve as contradições de S1 (*deny-list* × lista do que pode
   sair), de S2 (decisão 2 e *"Instrumentação automática apenas… os automáticos entram"*,
   `ADR:449-457`, contra E6) e do vocabulário (S16). Divergência entre ADR e spec é bloqueio no
   `/speckit-analyze`, e não observação.
2. **Antes de qualquer código**: a pessoa mantenedora aceita a ADR 0005 e as dependências
   (já é premissa da spec), decide D1 a D7 abaixo, e #1222 e #887 estão em `development` ou têm
   decisão registrada de seguir sem eles (seção *"A ordem"*).
3. **Antes do primeiro deploy com o SigNoz**: os três achados altos têm a verificação feita **e
   lida**, com evidência na tarefa. Para S6 em particular: o que se recomenda é **bloquear a
   implantação** do backend, e não o plano nem o código.

## Tabela de achados

Severidade pela régua do papel: **Alta** = segredo exposto ou logado, dado de um tenant
alcançável por outro, autenticação contornável; **Média** = defesa que depende de alguém lembrar,
ausência de registro, configuração que afrouxa garantia declarada; **Baixa** = endurecimento.
Achado sobre desenho ainda não implementado é classificado **pelo que acontece se ele for
implementado como está escrito**.

| # | Achado | Severidade | OWASP 2021 / ASVS 4.0.3 |
|---|---|---|---|
| S1 | O filtro do que sai: *deny-list* na ADR, lista por **nome** na spec, e aplicado só no tradutor. Não cobre valor, recurso, evento de exceção, status nem atributo posto por outro código | **Alta** | A09, A04 / V7.1.1, V7.1.2, V8.3.4, V5.1.3 |
| S2 | A decisão 2 da ADR (`attach_hook(:handle_event)` em toda LiveView) leva ao tradutor os parâmetros que carregam token de ferramenta e chave de provedor | **Alta** | A09, A02 / V7.1.1, V8.3.4 |
| S3 | FR-012: *"a mesma regra do log das consultas"* não basta para span de consulta. A consulta do login carrega o identificador digitado, e `users` não tem campo cifrado | Média (Alta no dia em que houver span de consulta) | A09 / V7.1.1, V7.1.2 |
| S4 | Oráculo de enumeração: onde o motivo vive, o cookie de sessão legível pelo cliente, a emissão dentro da transação | Média | A07, A04 / V2.2.1, V7.4.1, V8.2.2 |
| S5 | O correlator da jornada: onde mora, quem o gera, quando morre. Na forma óbvia (campo oculto) ele é forjável, e na forma persistente é rastreio de visitante | Média | A04, A08 / V3.1.1, V5.1.3, V8.3.4 |
| S6 | O SigNoz exposto: portas publicadas por cima do firewall, `secret` como chave do JWT, a corrida da primeira conta, ClickHouse sem senha, imagem por tag | **Alta** | A05, A07, A01 / V2.10.2, V4.3.1, V14.1.5, V14.2.4 |
| S7 | A vizinhança: rede compartilhada do Dokploy, coletor sem autenticação, OpAMP reescrevendo o pipeline pelo painel, e a distribuição Erlang em `0.0.0.0` (#1162) | Média | A05, A08 / V1.14.1, V1.2.2, V10.3.2 |
| S8 | O que sai do servidor pelo próprio SigNoz: telemetria de uso do produto e canais de alerta, contra a premissa de E1 | Média | A05, A04 / V8.3.4, V12.6.1 |
| S9 | Cadeia de suprimento: onze pacotes, e não nove; `grpcbox` com requisito `>= 0.0.0`; contas pessoais únicas como donas de quatro pacotes; servidor HTTP/2 que não se usa dentro da release | Média | A06, A08 / V14.2.1, V14.2.4, V14.2.5, V14.2.6 |
| S10 | A configuração do SDK por variáveis `OTEL_*` do ambiente, fora da lista fechada da FR-015, inclusive o destino do envio | Média | A05, A10 / V14.1.3, V12.6.1 |
| S11 | Falha silenciosa: `rescue` que não pega `exit`/`throw`, log de erro que imprime argumento, contador de perda que viaja pelo mesmo cano que perdeu | Média | A09 / V7.1.3, V7.4.1 |
| S12 | Inundação sem autenticação e sem amostragem: quem tenta identificadores inexistentes não tem espera, e o descarte por fila cheia apaga exatamente os spans do ataque | Média | A04 / V11.1.4, V2.2.1 |
| S13 | Retenção e LGPD: o TTL do ClickHouse não é exato, o backup do volume estende a retenção, e "métrica sem identidade" depende de uma configuração que ninguém declarou | Média | A04 / V8.3.4, V8.3.8 |
| S14 | Minimização: a spec põe identidade no sucesso (`concluiu`), que é o registro de toda entrada de toda pessoa | Média | A04 / V8.3.4 |
| S15 | Teste das sentinelas que troca o exportador inteiro testa um filtro que não roda em produção | Média | A09 / V7.1.1 |
| S16 | Vocabulário divergente entre ADR e spec (`ok`/`concluiu`, `conta_sem_senha_definida`/`conta_sem_senha`, `user.id`/`user.ref`) — e a lista do que pode sair valida valor contra esse vocabulário | Baixa | A04 / V1.1.2 |

---

## Achados

### S1 — Alta: o filtro do que sai, em dois desenhos incompatíveis, e nenhum fecha

**O que é.** A09. A garantia de que segredo não sai do processo é declarada como *deny-list* de
atributos (`ADR:149-152`) e, na spec, como lista do que **pode** sair, por **nome**, *"aplicada
num ponto único antes do exportador"* (FR-006). As duas formas deixam caminhos abertos.

**Onde, e por quê.**

- *Deny-list* falha aberto: o atributo novo que ninguém pôs na lista sai. É a forma errada para
  esta casa, e a spec já o percebeu. A ADR precisa ser corrigida, ou a contradição chega ao
  `/speckit-analyze`.
- Lista **por nome** falha no valor. `failure.reason` é nome permitido; o valor é o que o código
  puser. A FR-013 da 045 recusa a senha pela regra, e o caminho natural para nomear o motivo
  `recusada_pela_regra` é ler o changeset de `User.senha_changeset/3`. Um `inspect(changeset)` ou
  uma mensagem de validação escrita à mão no valor leva a senha nova junto. O `redact: true` de
  `lib/the_band/tenants/user.ex:48-49` protege o `inspect/1` da struct, **não** o de `changes` de
  um changeset montado em outro lugar, nem interpolação.
- Filtro **só no tradutor** não vê:
  - **o recurso** do span (`service.*`, `host.*`, `process.*`, e o que `OTEL_RESOURCE_ATTRIBUTES`
    trouxer, ver S10). O SDK o monta por detectores, e não pelo nosso código;
  - **eventos de exceção**: `record_exception` grava `exception.message` e `exception.stacktrace`.
    Num `FunctionClauseError` o quadro de pilha traz os **argumentos**, e não a aridade. É o
    mecanismo exato do token que ficou oito dias em `oban_jobs.errors`
    (`lib/the_band/tenants/sessions.ex:18-21`, e a #887). Se o passo `entrar_com_senha` for
    escrito como `:telemetry.span/3` em volta de `Auth.authenticate/2`, o evento `:exception`
    entrega ao tradutor `kind`, `reason` e `stacktrace` com a senha como argumento;
  - **o status** do span (a descrição é texto livre) e os *links*;
  - **atributo posto por outro código** no span corrente (`OpenTelemetry.Tracer.set_attribute/2`
    chamado por uma biblioteca, ou por um desenvolvedor que "só queria depurar").

**Caminho concreto.** Ninguém ataca: um desenvolvedor da casa, na US4, mapeia o erro do changeset
para o motivo com `inspect(changeset.errors)` ou põe `Exception.message(e)` no status. A senha
nova da pessoa vai para o ClickHouse, com retenção de sete dias e controle de acesso do SigNoz, e
**passa** no teste das sentinelas se o teste só fizer entradas com senha errada. Consequência
para o negócio: **a senha de uma pessoa fica legível no painel de telemetria para quem o opera, e
em todo backup do volume.**

**O que fecha.** Três camadas, e a primeira é a garantia:

1. **No último ponto antes do envio**, um envoltório do exportador (ou um processador que
   envolve o `otel_batch_processor`) reconstrói cada span só com o que está na lista: nome do
   span de uma enumeração fechada; atributos permitidos **por nome e por forma do valor**
   (`failure.reason`, `outcome`, `journey.name`, `journey.step` contra a enumeração da base de
   conhecimento; `tenant.id` e o identificador de conta contra a forma de UUID ou de HMAC
   hexadecimal; `journey.id` contra a forma do correlator, ver S5); **eventos descartados todos**;
   **status sem descrição**; **recurso reconstruído** a partir de uma lista fechada
   (`service.name`, `service.version`, `deployment.environment`), e não filtrado a partir do que
   o SDK detectou. Tudo o que for descartado é **contado** (S11);
2. **no tradutor**, os atributos são montados só a partir dos campos permitidos da metadata do
   evento, e nunca a partir da metadata inteira. Defesa em profundidade, e não a garantia;
3. **na assinatura do evento**: a função de domínio que emite o passo aceita só id, átomo de uma
   lista e contagem, como `TheBand.Tenants.AccessEvents` já faz (`access_events.ex:43-48`,
   `:163-165`). Assim a metadata do `:telemetry.execute` nunca carrega struct de conta, `conn`
   ou changeset, o que protege também **outros** handlers anexados ao mesmo evento.

E duas proibições escritas na spec: **nenhum `record_exception`**, e **nenhum `:telemetry.span/3`
em volta de função que recebe credencial** (o passo se emite com `:telemetry.execute/3` depois de
a decisão sair).

**O teste** (QA escreve; cenário em S15): sentinelas em todo campo de credencial dos quatro
passos, varredura de nome, atributo, evento, status, link e recurso; defeitos a injetar, um por
vez: (a) remover o envoltório; (b) pôr `inspect(changeset)` em `failure.reason`; (c) chamar
`set_attribute("depuracao", senha)` direto no span corrente, por fora do tradutor; (d) definir
`OTEL_RESOURCE_ATTRIBUTES` com uma sentinela; (e) `record_exception` com uma exceção cuja mensagem
contém a sentinela. O teste tem de reprovar nos cinco.

**Se não entrar agora.** A US3 passa com um filtro que não é o de produção, e a primeira
mensagem de erro escrita no span vira o vazamento.

### S2 — Alta: a decisão 2 da ADR captura os parâmetros de toda interação

**O que é.** A09. `ADR:65-76` manda anexar `attach_hook(:handle_event)` no `on_mount` de
`TheBandWeb.Live.Hooks`, para pegar *"cada interação, sem instrumentar tela por tela"*. A
callback de `handle_event` recebe os **parâmetros do formulário**.

**Onde.** Os formulários de segredo desta base são LiveView com `phx-submit`, e não POST
clássico:

- `lib/the_band_web/live/source_live/index.ex:493`, `:648` e `:760`: o campo `secret`, que é o
  token do GitHub, nos eventos `connect`, `resume_observation` e `add_credential`
  (`:35`, `:346`, `:104`);
- `lib/the_band_web/live/ai_live/index.ex:217-222`: o campo `secret`, a chave do provedor de
  modelos, no evento `save` (`:31`).

Hoje esses valores existem só na memória do processo e no banco cifrado
(`lib/the_band/rotacao.ex:29-34`). Um gancho genérico os entrega ao tradutor de spans, e daí em
diante a proteção é **só** o filtro de S1.

**Por que é achado, se a spec deixa instrumentador fora (E6).** Porque a ADR é o que se aceita,
e ela diz duas vezes o contrário: a decisão 2 chama o gancho de *"quase de graça"*, e
`ADR:449-457` diz que *"os automáticos entram, e os spans de domínio são acrescentados por
cima"*. A próxima fatia que ler a ADR implementa o gancho.

**O que fecha.** A ADR é emendada: o gancho de `handle_event`, se um dia existir, emite **só o
nome do evento e a tela** (`socket.view`), **nunca** os parâmetros, e entra com avaliação de
segurança própria. `ADR:449-457` passa a dizer que os automáticos **não** entram sem fatia e
avaliação própria. Teste para quando o gancho existir: evento `save` em `/ai` com uma sentinela
em `secret`, varredura do exportado; defeito a injetar: passar `params` ao tradutor.

### S3 — Média: "a mesma regra" do log das consultas não basta para span de consulta

**O que é.** A09. A FR-012 diz que um span de consulta, se existir, sai com os parâmetros
redigidos pela regra de `TheBand.Repo.LogDaConsulta` (PR #1227). Essa regra redige **as
consultas que tocam tabela com campo cifrado** (`redigir?/2` no diff do PR, sobre
`Rotacao.campos_cifrados/0`, `rotacao.ex:29-34`): `tool_credentials`, `ai_provider_credentials`,
`platform_operators`. Ela foi desenhada para o segredo de ferramenta, e cumpre isso.

**Onde ela não alcança, e é a superfície desta feature.**

- `lib/the_band/tenants/auth.ex:239-241`: `por_email/1` passa `String.downcase(identificador)`
  como parâmetro, sobre `users`. É o **identificador digitado**, que a FR-005 proíbe em qualquer
  forma, e que é muitas vezes a senha digitada no campo errado;
- `auth.ex:247-257`: `por_login_do_github/1`, o mesmo, sobre `users` e `eo_people`;
- `auth.ex:199-206` e `User.senha_changeset/3`: o `UPDATE` de `users` leva `password_hash` como
  parâmetro. É bcrypt, e não segredo cifrado: está fora da lista. Hash bcrypt exportado é
  material de ataque por dicionário fora do banco;
- `user_sessions`: o `INSERT` de `Sessions.abrir/1` (`sessions.ex:60-67`) leva `token_hash`. Não
  autentica sozinho, mas também não precisa sair.

**Caminho.** No dia em que alguém ligar `opentelemetry_ecto` ou escrever um tradutor para
`[:the_band, :repo, :query]` *"com a mesma regra"*, o identificador digitado de toda tentativa de
login sai em claro, e passa no teste que só confere as três tabelas cifradas.

**Por que Média, e não Alta.** Nesta fatia não há span de consulta (FR-012, E6). O achado é
sobre a regra que a spec escreve para o futuro, e que, escrita assim, autoriza o vazamento.

**O que fecha.** A FR-012 passa a dizer: *"Nesta fatia não há span de consulta. Um span de
consulta exige avaliação de segurança própria; a regra de `LogDaConsulta` é condição necessária,
e não suficiente: `users`, `user_sessions` e as tabelas de credencial do operador também têm os
parâmetros redigidos."* Vale registrar no PR #1227, como observação e não como bloqueio dele: o
mesmo vale para o log de consultas em `:debug` em desenvolvimento, porque o identificador e o
`password_hash` saem ali hoje (produção está em `:info`, `config/prod.exs:34`, e por isso não é
exposição ativa).

### S4 — Média: o oráculo de enumeração, pelos três canais que a spec não nomeia

**O que é.** A07. A FR-003 e a FR-009 já exigem tela idêntica e custo constante. Falta dizer
**onde** o motivo existe, porque o lugar decide se ele vaza.

**Os três canais.**

1. **Quem segura o motivo.** Hoje o motivo existe só dentro de `Auth`: `recusar/2`
   (`auth.ex:86-89`) o entrega a `AccessEvents` e devolve `{:error, :invalid_credentials}`, e o
   controller recebe a recusa colapsada (`session_controller.ex:36-37`). A forma mais curta de
   instrumentar é **mudar o retorno** para o controller receber o motivo e emitir o span. Isso
   põe o motivo a uma linha do `put_flash`. O passo `entrar_com_senha` precisa ser emitido **no
   domínio**, e o controller continua recebendo só a recusa colapsada;
2. **O cookie é legível pelo cliente.** A sessão é assinada, **não cifrada**
   (`lib/the_band_web/endpoint.ex:4-14`; `lib/the_band_web/sessao.ex:16-17`). Qualquer valor que
   a instrumentação guardar na sessão, ou **deixar de apagar**, conforme o motivo, chega ao
   cliente no `Set-Cookie`. Exemplo concreto: o correlator de S5 apagado na recusa por senha
   errada e mantido na espera crescente diz ao cliente qual dos dois aconteceu;
3. **O tempo.** `recusar/2` roda **dentro** da transação com `FOR UPDATE` (`auth.ex:64-73`) para
   as contas que resolvem, e fora dela para o identificador que não resolve (`auth.ex:47-50`).
   Trabalho do tradutor que dependa do motivo (montar o identificador opaco só quando há conta,
   calcular HMAC, buscar o nome da organização) custa só num dos ramos. Comparado ao bcrypt, é
   pequeno, e é exatamente o tipo de diferença que a #1047 fechou na espera (`auth.ex:174-178`).

**O que fecha.**

- o passo de entrada é emitido por `Auth`, **depois** da transação, a partir de um relator
  interno `{decisão, motivo}`; `authenticate/2` continua devolvendo o mesmo que hoje, e o
  controller nunca vê o motivo. A regra da L69 fica atendida: o teste assere sobre o relator
  interno, e não sobre o log;
- o tradutor não consulta banco e faz o **mesmo trabalho** em todo ramo: se houver HMAC (D1), ele
  é calculado também quando não há conta, sobre um valor fixo, e descartado;
- **nenhuma escrita na sessão depende do motivo**: as chaves gravadas e apagadas numa recusa são
  as mesmas para os seis motivos.

**O teste.** Estende o de `Enum.uniq` da 045 (SC-003): para os seis motivos, além do corpo e do
destino do redirecionamento, comparar **o conjunto de chaves da sessão decodificada** do
`Set-Cookie`. Defeito a injetar: apagar o correlator só no ramo `senha_errada`. E um segundo
teste, estrutural: o controller recebe só `{:error, :invalid_credentials}` ou
`{:error, {:throttled, _}}`; defeito a injetar: devolver o motivo ao controller.

### S5 — Média: o correlator da jornada

**O que é.** A04 e A08. A FR-011 diz *aleatório, nunca derivado de token, sessão ou conta*, e
está certa. Falta dizer onde ele mora, quem o gera e quando morre, e cada omissão tem um defeito
conhecido.

**Os fatos que limitam o desenho.**

- `/sign-in` é LiveView (`lib/the_band_web/router.ex:283`), e LiveView **não escreve cookie**. A
  tentativa é um POST HTML clássico a `/session` (`session_live/new.ex:131`), e não um evento do
  socket;
- o `mount` roda **duas vezes**, na renderização estática e na conexão (`session_live/new.ex:25`);
- `Sessao.abrir/2` renova a sessão mas **não apaga chaves estranhas** a ela (`sessao.ex:59-65`):
  só as suas e as antigas.

**Os caminhos errados, e o que cada um faz.**

| onde | defeito |
|---|---|
| campo oculto no formulário | o cliente escolhe o valor: casa a própria tentativa com a abertura de outra pessoa, apaga abandonos do painel, ou manda uma cadeia de 1 MB por tentativa para o ClickHouse |
| cookie próprio, persistente | identificador de rastreio do visitante não autenticado, que liga tentativas com contas diferentes do mesmo navegador (computador compartilhado) entre visitas |
| na sessão, sem apagar no sucesso | atravessa a autenticação e liga a pessoa autenticada ao que ela fez antes de entrar, por sete dias |
| emitir `abrir_a_entrada` em todo `mount` | duas aberturas por visita, e a metade conta como abandono |

**O que fecha.** O correlator nasce **no servidor**, numa função de plug na rota `GET /sign-in`,
com 16 bytes aleatórios; vai para a **sessão** (assinada, então o cliente não o forja); é
**substituído** a cada `GET /sign-in`; é **lido** pelo POST de `/session` **da sessão, nunca dos
parâmetros**, e **apagado** depois da tentativa, com qualquer desfecho (S4: o mesmo apagamento
para todos os motivos); `abrir_a_entrada` é emitido **uma vez**, só no `mount` conectado (o que
também tira do painel o robô que não roda JavaScript, e a spec precisa dizer isso); valor
ausente ou fora da forma vira passo **sem** `journey.id`, que é o caso de borda *"requisição
direta"* já previsto. E `journey.id` **nunca** é dimensão de métrica (S13).

**O teste.** (a) POST com `journey_id` nos parâmetros e outro na sessão: o exportado tem o da
sessão; defeito a injetar: ler dos parâmetros. (b) Entrar e, já autenticado, conferir que a
sessão não tem mais o correlator; defeito: não apagar. (c) Dois `GET /sign-in` seguidos dão dois
valores diferentes. (d) Uma visita com conexão gera uma só abertura.

### S6 — Alta: o SigNoz exposto

**O que é.** A05, A07, A01. O painel do SigNoz tem a identidade das pessoas de **todas** as
organizações (E5). Quem entra nele lê dado de um tenant sendo de outro, ou de nenhum.

**O que o compose de referência traz, segundo a própria ADR** (`ADR:264-265`), e o que cada item
dá a um atacante na internet:

| item | caminho |
|---|---|
| `SIGNOZ_TOKENIZER_JWT_SECRET=secret` | quem conhece o valor público assina um JWT de administrador e entra no painel sem senha |
| `8080` em todas as interfaces | o painel na internet, antes ou depois de existir conta |
| `4317`/`4318` em todas as interfaces | qualquer um envia spans forjados (S7) e enche o disco (S12) |
| primeira conta vira administradora (E5) | quem chegar antes da pessoa mantenedora fica com o painel |
| ClickHouse com o usuário `default` sem senha | dentro da rede, leitura direta de todo traço; com porta publicada, de fora |

**O fato que torna isso pior do que parece**: porta publicada pelo Docker entra pela cadeia
`DOCKER` do `iptables`, **antes** das regras do `ufw`. Um firewall do host que nega 8080 não
fecha uma porta publicada. Ler o compose e ver *"sem `ports:`"* é a evidência certa; conferir o
`ufw` não é.

**O que fecha.** E2/E5 já dizem o quê. O que falta é **a verificação, com evidência lida**, numa
tarefa 👤 bloqueante do deploy:

1. compose gerado e versionado sem nenhuma chave `ports:` em ClickHouse, ZooKeeper, coletor e
   painel; **e** no VPS, `ss -ltnp` sem 8080, 4317, 4318, 8123, 9000, 2181; **e** uma tentativa
   de conexão **de fora** do VPS a essas portas (é o nosso próprio sistema), recusada;
2. a chave do JWT vem do ambiente do Dokploy, gerada no próprio servidor, com 32 bytes
   aleatórios ou mais, e **o compose não tem valor padrão** para ela (sem a variável, o contêiner
   não sobe, como `TheBand.Application` faz com a chave mestra);
3. a primeira conta é criada **pelo túnel**, antes de existir qualquer rota; depois, a lista de
   usuários do SigNoz é conferida (uma conta) e o convite aberto, se existir, é desligado;
4. ClickHouse com senha vinda do ambiente;
5. imagens fixadas por **resumo** (`imagem@sha256:…`), e não só por tag: tag é mutável, e o
   argumento do H7 da casa vale aqui;
6. servidor e coletor fixados juntos (o defeito `nop` de `ADR:316-322`), e o quickstart confere
   que **um span chegou ao ClickHouse**, e não que o contêiner está *healthy*.

**Recomendo bloqueio da implantação do SigNoz até os seis itens terem evidência.** Não bloqueia o
plano nem o código da aplicação, que com a telemetria desligada (FR-015) não muda nada para quem
entra.

### S7 — Média: a vizinhança do coletor, e o que ela alcança

**O que é.** A05, A08. E5 põe a aplicação e o coletor *"na mesma rede Docker do Dokploy"*
(`ADR:388`). No Dokploy, essa rede costuma ser a compartilhada por todos os serviços
implantados; **não verifiquei** qual é a do VPS (a #1162 também não verificou).

**Três consequências.**

1. **Telemetria envenenada.** O coletor sem autenticação aceita spans de qualquer contêiner da
   rede, com `service.name = the_band` e qualquer `failure.reason`. Um painel que mostra
   *"conta desativada"* para uma conta que nunca tentou entrar produz decisão errada com cara de
   evidência (S4 da ADR).
2. **A distribuição Erlang.** A #1162 (aberta, Média) mediu `epmd` e a porta de distribuição em
   `0.0.0.0` dentro do contêiner, com o cookie na imagem. Pôr quatro imagens de terceiros
   (ClickHouse, ZooKeeper, SigNoz, coletor) na rede da aplicação **aumenta quem alcança essa
   porta**. Sem o cookie ninguém executa código, e a imagem não é puxável anonimamente (medido na
   #1162); mas a defesa passa a depender só do cookie.
3. **OpAMP.** O coletor recebeu configuração do servidor por OpAMP na medida da E3
   (`ADR:316-322`). Se o servidor pode reescrever o pipeline do coletor, **quem administra o
   painel** pode mudar processadores e, conforme a versão, exportadores: o filtro do coletor e o
   destino dos dados deixam de ser o arquivo versionado. Não verifiquei o alcance do OpAMP na
   `v0.144`.

**O que fecha.** Uma rede **dedicada** entre a aplicação e o coletor, sem nenhum outro membro;
ClickHouse, ZooKeeper e painel numa segunda rede, sem a aplicação. O coletor roda com
`--config` versionado e **sem OpAMP** (foi o que a própria medida fez para funcionar). Token de
portador no receptor OTLP (`bearertokenauth`) é barato e fecha o envenenamento pela rede: fica
como recomendação, obrigatório na opção B de E3. E a #1162 entra como **pré-requisito da opção
A** (seção *"A ordem"*).

### S8 — Média: o que sai do servidor pelo próprio SigNoz

**O que é.** A05. A razão de E1 para escolher o SigNoz no servidor é que *"o dado com identidade
não sai"*. Dois caminhos de saída não foram considerados:

- **a telemetria de uso do próprio produto.** O SigNoz envia estatística de uso ao fabricante, e
  versões anteriores identificavam a conta administradora pelo e-mail. **Não verifiquei** o que a
  `v0.144` envia, nem o nome da variável que desliga;
- **os canais de alerta** da US5. Um alerta por e-mail, Slack ou webhook sai do servidor, e o
  modelo de mensagem pode incluir atributos do traço (`user.ref`, `tenant.id`).

**O que fecha.** Telemetria de uso desligada, conferida **pelo tráfego de saída** do contêiner
(e não pela variável); o alerta da US5 é sobre **métrica** (contagem de
`identificador_nao_resolveu`), sem atributo de traço no corpo; o canal de alerta é declarado no
runbook.

### S9 — Média: cadeia de suprimento

**O que foi medido** no `hex.pm`, em 2026-10-03:

| pacote | versão que a resolução pega | publicado | dono no Hex | observação |
|---|---|---|---|---|
| `opentelemetry_exporter` 1.11.0 | — | 2026-09-16 | organização `opentelemetry` | exige `grpcbox` **`>= 0.0.0`**, sem teto |
| `grpcbox` | 0.18.0 | 2026-07-11 | `tristan` (conta pessoal, único) | exige `gproc ~>1.2.0`, `ctx ~>0.6.0`, `acceptor_pool ~>1.0.0`, `ts_chatterbox ~>0.16.0` |
| `gproc` | **1.2.0**, e não 1.3.0 (`~>1.2.0` não aceita 1.3) | 2026-04-11 | `uwiger` | a ADR (`ADR:406`) diz 1.3.0 |
| `ctx` | 0.6.0 | 2020-12-23 | `tristan` (único) | sem release há quase seis anos |
| `ts_chatterbox` | 0.16.0 | 2026-06-28 | `tristan` (único) | exige `hpack_erl ~>0.3.0` |
| `hpack_erl` | 0.3.0 | 2023-06-03 | `tristan` (único) | **ausente da ADR** |
| `acceptor_pool` | 1.0.1 | 2025-12-15 | `fishcakez`, `tristan` | |
| `tls_certificate_check` | 1.35.0 | 2026-08-13 | — | exige `ssl_verify_fun ~> 1.1` |
| `ssl_verify_fun` | 1.1.7 | 2023-06-20 | `deadtrickster` | **ausente da ADR**; não está no `mix.lock` de hoje |

São **três diretas e oito transitivas**, e não seis. Nenhuma versão acima está aposentada.

**Os riscos.**

- **Conta pessoal única** publica `grpcbox`, `ctx`, `ts_chatterbox` e `hpack_erl` (e publicou as
  releases medidas do SDK e do exportador). É a mesma pessoa que mantém o projeto
  OpenTelemetry Erlang, o que explica e não elimina: a tomada dessa conta publica versão nova de
  quatro pacotes;
- **`grpcbox >= 0.0.0`**: o `mix.lock` fixa a versão e o resumo, e é a defesa contra troca de
  versão já publicada. Mas um `mix deps.update --all` aceita qualquer `grpcbox` futuro, inclusive
  uma 1.0 que mude o mundo, sem que o `mix.exs` mostre nada;
- **código que não se usa dentro da release**: `grpcbox`, `ts_chatterbox` e `acceptor_pool` são
  cliente **e servidor** gRPC/HTTP/2. O exportador por HTTP não usa nada disso, mas as aplicações
  sobem com a release. Não verifiquei se alguma abre porta sem configuração;
- **o que os gates cobrem.** `mix hex.audit` (gate, `lib/mix/tasks/gates.ex:63`) vê
  **aposentadoria** no Hex. `mix deps.audit` (não é gate) vê os avisos da base do `mix_audit`,
  que cobre pouco o ecossistema Erlang. **Nenhum dos dois vê uma versão maliciosa recém-publicada
  sem aviso**, que é o risco real de conta pessoal única.

**O que fecha.** `grpcbox` declarado **direto** no `mix.exs` com `~> 0.18.0`, só para pôr teto;
dependências diretas com versão exata; diff do `mix.lock` revisado linha a linha no PR (pacote
novo no lock é decisão, e não efeito colateral); `mix hex.audit` **e** `mix deps.audit` rodados e
lidos antes do merge; depois do boot da release, conferir que nenhuma porta nova escuta
(`ss -ltnp` dentro do contêiner, ou `:inet.i()`); o inventário da ADR corrigido para onze, com
`gproc` 1.2.0.

### S10 — Média: o SDK lê o ambiente por conta própria

**O que é.** A05, A10. A FR-015 diz que a configuração vem de variáveis cujos **nomes** estão na
lista fechada do runbook. O SDK OpenTelemetry lê variáveis `OTEL_*` por conta própria
(`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS`, `OTEL_RESOURCE_ATTRIBUTES`,
`OTEL_TRACES_SAMPLER`, `OTEL_SDK_DISABLED`…), independentemente da lista. **Não verifiquei**, para
a 1.7.0, se a variável vence a configuração da aplicação; a documentação do SDK diz que sim.

**Caminho.** Quem opera cola no Dokploy o endpoint de um serviço gerenciado para testar, ou um
`OTEL_EXPORTER_OTLP_ENDPOINT` herdado de outro serviço: os traços com identidade passam a sair
para terceiro, que é o que E1 recusou. Sem a variável, o padrão do exportador é
`localhost:4318`, que no contêiner é a própria aplicação: a telemetria fica *"ligada"*, falhando
em silêncio, em vez de *"desligada, e dito no log"*.

**O que fecha.** A aplicação monta a configuração do SDK **explicitamente** a partir da lista
fechada, no `config/runtime.exs`; o destino é validado no boot contra uma lista de hosts
permitidos (o nome do serviço do coletor na rede interna) e esquema `http` só dentro dela;
destino fora da lista desliga a telemetria e diz no log o **nome** da variável, nunca o valor;
sem variável, `traces_exporter: :none`, e não o padrão. O plano confere se o SDK ainda lê
`OTEL_*` depois disso, e o teste o prova: boot com `OTEL_EXPORTER_OTLP_ENDPOINT` apontando para
fora, e o exportador **não** é configurado para ele.

### S11 — Média: a falha silenciosa, nos três lugares em que ela mora

**O que é.** A09. S5 da ADR e a FR-008 nomeiam o desanexo do `:telemetry`. O PR #1227 já tem o
padrão (`rescue` no handler, log só do tipo do erro). Três lacunas:

1. **`rescue` não pega `exit` nem `throw`**, e o `:telemetry` desanexa do mesmo jeito. O tradutor
   usa `catch kind, reason`, e loga **só** o `kind` e o módulo da exceção;
2. **o log do erro não imprime mensagem nem pilha**: `Exception.message/1` pode conter valor, e a
   pilha de um `FunctionClauseError` traz os argumentos (`sessions.ex:18-21`);
3. **o contador de perda não pode viajar pelo cano que perdeu.** Contar o descarte como span ou
   métrica OTel é circular: com o exportador parado, o contador some junto. O contador vive em
   `:counters` e é **logado periodicamente** pelo `telemetry_poller` que já existe
   (`lib/the_band_web/telemetry.ex:14`), que também confere que o tradutor continua anexado
   (`:telemetry.list_handlers/1`) e loga erro se não estiver.

E o descarte do processador em lote por fila cheia: **não verifiquei** se o `otel_batch_processor`
1.7.0 o expõe. O plano mede com o coletor parado e fila pequena; se a biblioteca não disser, o
envoltório de S1 conta o retorno de `on_end`.

**O teste.** Tradutor que levanta, que faz `exit` e que faz `throw`, um de cada vez: entrar
continua funcionando, o handler continua anexado, o contador sobe, e o log tem o tipo e **não**
tem a sentinela posta na mensagem da exceção. Defeito a injetar: trocar `catch` por `rescue`.

### S12 — Média: inundação sem autenticação e sem amostragem

**O que é.** A04. `GET /sign-in` e `POST /session` não pedem autenticação, e a FR-016 exporta
sem amostragem. A espera crescente é **por conta** (`auth.ex:158-186`): o identificador que não
resolve não tem conta, **nunca entra em espera** (`auth.ex:47-50`) e gera um span por tentativa.

**Caminho.** Uma campanha de adivinhação de e-mails a algumas centenas de tentativas por segundo
enche a fila do processador em lote, e **o que é descartado são os spans da própria campanha**,
justamente quando eles importam. Pela medida da E3 (`ADR:301-304`), ≈ 190 bytes por span: dez
milhões de tentativas em sete dias são ~2 GB no ClickHouse, e o coletor saltou de 28 MiB para
291 MiB sob 100 000 spans. O disco não é o problema principal; a perda seletiva e a memória sob
teto (E3) são.

**O que fecha.** O alerta da US5 é sobre **contagem**, que sobrevive à perda se for medida antes
do descarte (o contador do envoltório de S1, por motivo, logado pelo `telemetry_poller`); o
coletor tem `memory_limiter`; o ClickHouse tem teto de disco além do TTL. Limite por IP em
`POST /session` é outra feature, e fica como decisão D7.

### S13 — Média: retenção e LGPD

**O que é.** A04. E4 fixa traços em 7 dias e métricas em 30, sem identidade. Quatro pontos
tornam o número menos verdadeiro do que parece:

1. **o TTL do ClickHouse age na fusão de partes**, e não no instante: um span pode viver além de
   7 dias. A tarefa 👤 confere a idade do traço **mais antigo** depois de oito dias, e não a tela
   de configuração;
2. **o backup**: se o volume do ClickHouse entrar no backup do Dokploy ou no destino de segundo
   host (`docs/seguranca/2026-09-12-destino-de-backup-em-segundo-host.md`), a retenção real vira
   a do backup. O volume fica **fora** do backup, ou o backup tem a mesma retenção, e isso é
   escrito;
3. **"métrica sem identidade" é uma configuração, e ninguém a declarou.** As dependências da E6
   exportam **traço**; não há SDK de métricas. Se a métrica de 30 dias nascer de traços no
   coletor (processador de métricas de span), as **dimensões** dele são uma segunda lista do que
   pode sair, e precisam excluir `user.ref` e `journey.id`. Versionada junto com o compose;
4. **quase-identificador**: numa organização de três pessoas, `tenant.id` + `conta_desativada` +
   dia identifica a pessoa por 30 dias. Aceitável para quem opera; vale escrever.

**Quem vê.** E5 diz *"só quem opera a plataforma"*. Na prática, também quem tem acesso ao
Dokploy (lê as variáveis e os volumes) e o `root` do VPS. Vale escrever isso no runbook, porque é
o que a pergunta *"quem viu o quê?"* de um incidente precisa.

**LGPD.** Identificador de conta é dado pessoal, pseudonimizado ou não. A finalidade
(segurança e suporte ao acesso) e a base (legítimo interesse, segurança da operação) precisam
estar escritas onde o tratamento de dados da plataforma é declarado; a retenção curta é o que
torna o legítimo interesse defensável. **Não verifiquei** se a plataforma tem aviso de
privacidade ou registro de tratamento.

### S14 — Média: minimização, a identidade no sucesso

**O que é.** A04. O cenário 1 da US1 põe o identificador opaco no passo `concluiu`. O pedido é
*"quem deu erro"* (`spec.md:10-11`), e S2 da ADR traça a linha entre agregado e individual. A
entrada bem-sucedida com identidade é o registro de **toda** entrada de **toda** pessoa, por sete
dias, numa ferramenta que não tem o controle de acesso do domínio: é vigilância de presença sem
pedido.

**O que fecha.** É parte da decisão D1. A recomendação: identidade nos desfechos que pedem ação
(as recusas com conta conhecida, a espera, a queda de sessão e a saída que falhou) e, no
`concluiu`, **só quando o sucesso apagou tentativas falhas** (`falhas_apagadas > 0`,
`auth.ex:217`), que é o sinal de campanha que deu certo do achado H4.

### S15 — Média: o teste das sentinelas pode testar um filtro que não roda

**O que é.** A09. A forma comum de testar spans no Erlang é trocar o exportador por um que manda
os spans ao processo do teste. Se o filtro de S1 viver no envoltório do exportador e o teste
trocar o exportador **inteiro**, o teste nunca passa pelo filtro, e passa verde.

**O que fecha.** O teste troca **só o exportador interno** e mantém o envoltório, o mesmo módulo
configurado em produção. A guarda de que mediu: antes de qualquer `refute`, `assert` de que
chegaram spans dos quatro passos e de que a contagem bate com as tentativas feitas. As
sentinelas, cada uma com valor óbvio de teste: senha tentada, identificador digitado, o e-mail da
conta, o valor do `password_hash`, a senha temporária, a senha atual e a nova da troca, o valor
inteiro do cookie `_the_band_key`, o `session_secret`, o token de CSRF. Cada uma procurada em
claro, em Base64 e em `inspect/1`, como o PR #1227 faz com o TOTP. Os defeitos a injetar são os
cinco de S1.

### S16 — Baixa: o vocabulário diverge entre a ADR e a spec

`ADR:99-100` usa `outcome ok | falha | abandonada` e `conta_sem_senha_definida`; a spec usa
`concluiu | falhou | abandonou` e `conta_sem_senha`; `ADR:101` e `:167` dizem `user.id`, `ADR:371`
diz `user.ref`. É problema de rastreabilidade, e vira de segurança por um detalhe: a lista de S1
valida **valor** contra a enumeração da base, e duas enumerações produzem dois filtros. A
taxonomia da base de conhecimento é a fonte única, e a ADR se alinha a ela.

---

## A ordem: #887, #1222 e #1162 são pré-requisitos?

| item | estado (conferido com `gh` em 2026-10-03) | é pré-requisito técnico? | é pré-requisito pela regra? |
|---|---|---|---|
| **#1222** / PR #1227 | issue aberta; PR aberto, sem revisão | **não** para esta fatia, que não tem span de consulta | **sim**: `AGENTS.md` §14.0, item 2, *"defeito de segurança conhecido vem antes de funcionalidade nova na mesma superfície"*. A superfície é a mesma: diagnóstico que sai do processo. E a FR-012 se apoia no módulo que o PR cria |
| **#887** (064/US3, *segredo nunca chega a log, erro ou campo de diagnóstico*) | aberta, `us` + `security` | **parcialmente**: o mecanismo dela (argumento no quadro de pilha) é o mesmo de S1 e S11, e a correção do lado do provedor de modelos ainda falta | **sim**, pela mesma regra, e pelo comentário de 2026-09-27 no #802, que já pôs o épico depois dela |
| **#1162** (distribuição Erlang em `0.0.0.0`) | aberta | **não** para o código | **sim para a opção A da E3**: pôr a aplicação na rede de quatro imagens de terceiros é construir sobre a porta que se sabe aberta (S7) |

**Recomendação**: #1222 e #887 entram antes da implementação, como a spec já supõe. #1162 entra
antes do deploy do SigNoz no mesmo VPS. Se a pessoa mantenedora decidir outra ordem, a decisão
fica registrada com a razão, e não implícita.

---

## Decisões que a spec pode incorporar já

São redação de requisito ou tarefa de verificação. Nenhuma muda o que a pessoa mantenedora
decide.

| onde | redação proposta | achado |
|---|---|---|
| **FR-006** | *"O que sai MUST ser reconstruído no último ponto antes do envio, a partir de uma lista fechada: nome de span de uma enumeração; atributos permitidos **por nome e por forma do valor**, com os valores de enumeração validados contra a base de conhecimento; recurso reconstruído só com `service.name`, `service.version` e `deployment.environment`; nenhum evento; status sem descrição. O descarte MUST ser contado. O tradutor monta atributos só dos campos permitidos, e a função de domínio que emite o passo aceita só id, átomo de lista e contagem."* | S1 |
| **FR nova** | *"Nenhum passo MUST registrar exceção, pilha ou mensagem de erro no span. O passo MUST ser emitido com `:telemetry.execute/3` depois da decisão, e nunca com `:telemetry.span/3` em volta de função que recebe credencial."* | S1, S11 |
| **ADR, S1** | trocar *deny-list* por lista do que pode sair, com o texto da FR-006 acima | S1 |
| **ADR, decisão 2 e `ADR:449-457`** | o gancho de `handle_event` emite só nome do evento e tela, nunca parâmetros, e não entra sem avaliação própria; os automáticos **não** entram por padrão | S2 |
| **FR-012** | *"Nesta fatia não há span de consulta. Um span de consulta exige avaliação de segurança própria; a regra de `LogDaConsulta` é necessária e não suficiente: `users`, `user_sessions` e as tabelas de credencial do operador também têm os parâmetros redigidos."* | S3 |
| **FR-003 e FR-009** | acrescentar: *"o passo de entrada é emitido pelo domínio, depois da transação, a partir do relator interno; o controller recebe só a recusa colapsada; o tradutor não consulta banco e faz o mesmo trabalho em todo ramo; nenhuma escrita na sessão depende do motivo"* | S4 |
| **SC-003** | estender: *"…e o conjunto de chaves da sessão no `Set-Cookie` é o mesmo nos seis motivos"* | S4 |
| **FR-011** | *"O correlator nasce no servidor no `GET /sign-in`, com 16 bytes aleatórios, vive na sessão, é substituído a cada abertura, é lido só da sessão (nunca de parâmetro), é apagado depois da tentativa com qualquer desfecho, e é validado na forma. `abrir_a_entrada` é emitido uma vez por visita, no `mount` conectado. `journey.id` nunca é dimensão de métrica."* | S5 |
| **Tarefa 👤 bloqueante do deploy** | os seis itens de S6, cada um com a evidência lida | S6 |
| **E5 e tarefa 👤** | rede dedicada aplicação↔coletor; ClickHouse, ZooKeeper e painel em outra rede; coletor com `--config` versionado e sem OpAMP | S7 |
| **E1/E5 e tarefa 👤** | telemetria de uso do SigNoz desligada e conferida pelo tráfego de saída; alerta da US5 sobre métrica, sem atributo de traço | S8 |
| **E6** | inventário corrigido para onze pacotes (`hpack_erl`, `ssl_verify_fun`, `gproc` 1.2.0); `grpcbox ~> 0.18.0` declarado direto para pôr teto; diff do `mix.lock` revisado; nenhuma porta nova escutando depois do boot | S9 |
| **FR-015** | *"A aplicação configura o SDK explicitamente a partir da lista fechada; o destino é validado contra os hosts permitidos; destino fora da lista desliga a telemetria e loga o nome da variável, nunca o valor; sem variável, nenhum exportador é configurado."* | S10 |
| **FR-008** | *"O tradutor captura `exit`, `throw` e exceção; o log da falha tem só o tipo; o contador de perda vive fora do OpenTelemetry e é logado periodicamente, junto com a conferência de que o tradutor continua anexado."* | S11 |
| **E4 e tarefa 👤** | idade do traço mais antigo conferida depois de oito dias; volume do ClickHouse fora do backup, ou backup com a mesma retenção; dimensões das métricas declaradas e versionadas | S13 |
| **US3, teste independente** | o teste troca só o exportador interno, afirma que mediu antes de refutar, usa as sentinelas de S15 e reprova nos cinco defeitos de S1 | S15 |
| **ADR §4 e S2** | alinhar `outcome`, motivos e `user.ref` à taxonomia da base | S16 |
| **Assumptions** | *"#1222 e #887 em `development` antes da implementação; #1162 antes do deploy do SigNoz no mesmo VPS"* | A ordem |

## Decisões da pessoa mantenedora

Cada uma com as opções e a recomendação deste papel. **A decisão é dela**, e a spec registra a
escolhida com data.

### D1 — O identificador de pessoa no traço

| opção | o que é | a favor | contra |
|---|---|---|---|
| **A. `users.id` cru** | o UUID da conta | resolve no banco sem ferramenta nova; é o mesmo valor que o log de `AccessEvents` já tem (`access_events.ex:66-83`) | quem tiver o painel **e** o banco ou o log identifica a pessoa; o mesmo valor em três lugares liga os três |
| **B. pseudônimo por HMAC** | `HMAC(chave do ambiente, users.id)` | o painel sozinho não identifica ninguém, mesmo com o log em mãos; trocar a chave desfaz a ligação | uma chave nova para guardar e girar (variável na lista fechada, nunca no repositório); quem opera precisa de um resolvedor (tarefa `mix` que calcula o HMAC de cada conta e compara); o ganho é pequeno enquanto quem vê o painel é a mesma pessoa que vê o banco |
| C. nada | só organização e motivo | nenhum dado pessoal no traço | **não atende o pedido** (*"quem"*): ninguém reinicia a senha de ninguém |
| **D. A ou B, mais minimização** | identidade só nos desfechos que pedem ação, e no `concluiu` só com `falhas_apagadas > 0` (S14) | o traço deixa de ser registro de presença | o painel não responde *"quando fulano entrou pela última vez"*, que não foi pedido |

**Recomendação: A com D.** Hoje só a pessoa mantenedora vê o painel, e ela já vê o banco; o HMAC
custaria uma chave e uma ferramenta para proteger contra quem tem o painel e não tem o banco, e
esse alguém ainda não existe. **Mudar para B** quando qualquer outra pessoa ganhar acesso ao
SigNoz, ou se a opção B da E3 (outro VPS) for escolhida.

### D2 — Como se chega ao painel

| opção | a favor | contra |
|---|---|---|
| **Túnel SSH** (`ssh -L`), nenhuma rota | nada alcançável da internet; a autenticação é a do SSH, que já protege o servidor | incômodo; sem acesso pelo celular |
| Traefik com HTTPS + lista de IPs + login do SigNoz | acesso direto | o painel existe na internet; a lista de IPs depende de o Traefik ler o IP real (e não um `X-Forwarded-For` forjável); o login do SigNoz vira a última barreira, e não tem segundo fator por padrão |

**Recomendação: túnel.** Se o Traefik for escolhido, ele só sobe **depois** de a primeira conta
existir (S6, item 3).

### D3 — Onde o SigNoz roda (E3), visto pela segurança

A opção A (mesmo VPS) exige a #1162 consertada e a rede dedicada de S7. A opção B (outro VPS)
exige TLS e autenticação no coletor, e o traço com identidade atravessa a internet. **Recomendo
A**, com as duas condições, que é o que a ADR já recomenda pelo custo.

### D4 — A retenção

7 dias para traço com identidade e 30 para métrica sem identidade (E4). **Recomendo manter**,
com o volume fora do backup (S13). Menos de 7 dias perde a semana de investigação de uma
campanha; mais é guardar presença.

### D5 — Aceitar as onze dependências

É parte da aceitação da ADR. **Recomendo aceitar** com as condições de S9; o risco de conta
pessoal única é real e não tem alternativa no ecossistema Erlang para OTLP.

### D6 — A ordem

Seguir a regra (#1222 e #887 antes do código; #1162 antes do deploy) ou registrar a exceção com a
razão. **Recomendo seguir a regra.**

### D7 — Limite por IP em `POST /session`

Fora desta fatia. O identificador que não resolve não tem espera nenhuma hoje (S12), e a
telemetria vai tornar isso **visível**, não resolvido. **Recomendo abrir uma issue** com o label
`security`, para avaliação própria, e não pôr na 074.

---

## Cenários de ataque para o QA

Regras herdadas do QA: `assert` de que a medida mediu **antes** de qualquer `refute`; cada guarda
vista **reprovando** com o defeito injetado, com cópia do arquivo antes de injetar; nenhum
segredo real, só valores óbvios de teste.

| # | Quem, com o quê | Asserção | Defeito a injetar |
|---|---|---|---|
| T1 | Entradas com as sentinelas de S15 nos quatro passos e nos seis motivos | `assert` spans dos quatro passos chegaram; `refute` sentinela em nome, atributo, evento, status, link e recurso, em claro, Base64 e `inspect` | os cinco de S1, um por vez |
| T2 | `failure.reason` com valor fora da enumeração | o atributo não sai, e o contador de descarte sobe | validar só o nome |
| T3 | Os seis motivos de recusa | corpo, destino e **chaves da sessão** idênticos | apagar o correlator só em `senha_errada` |
| T4 | O controller recebe a recusa | só `:invalid_credentials` ou `{:throttled, _}` | devolver o motivo ao controller |
| T5 | POST com `journey_id` em parâmetro e outro na sessão | exportado tem o da sessão | ler dos parâmetros |
| T6 | Entrar com sucesso | a sessão autenticada não tem correlator | não apagar |
| T7 | Uma visita com conexão do LiveView | uma abertura | emitir em todo `mount` |
| T8 | Tradutor que levanta, faz `exit`, faz `throw` | entrar funciona; handler anexado; contador sobe; log sem a sentinela da mensagem | `catch` → `rescue` |
| T9 | Boot com `OTEL_EXPORTER_OTLP_ENDPOINT` para um host fora da lista | exportador não configurado para ele; log com o nome da variável e sem o valor | ler a variável sem validar |
| T10 | Boot sem variáveis | telemetria desligada e dito no log; entrar e sair funcionam (SC-004) | usar o padrão do exportador |
| T11 | O identificador digitado não resolve | o passo não tem nenhum atributo que dependa do digitado, nem identificador de conta | pôr `hash(identificador)` |
| T12 | Recusa com conta conhecida e `concluiu` sem `falhas_apagadas` (se D1 = A ou B com D) | identidade na recusa; **sem** identidade no sucesso comum | identidade em todo passo |

## Risco residual, mesmo com tudo acima

- **Quem administra o SigNoz lê a identidade das pessoas de todas as organizações** por sete
  dias. É inerente ao pedido; a retenção e o acesso por túnel o limitam, não o eliminam.
- **Telemetria não é trilha de auditoria** (S6 da ADR). Um span forjado por um vizinho de rede
  continua possível sem o token de portador de S7.
- **A conta pessoal única** dos pacotes `grpcbox`, `ctx`, `ts_chatterbox` e `hpack_erl` continua
  sendo um ponto único de comprometimento da cadeia; o `mix.lock` protege as versões já
  publicadas, não as próximas.
- **O identificador que não resolve não tem limite** (D7). A telemetria mostra a campanha; não a
  detém.

## O que eu NÃO verifiquei

- **Nenhum gate e nenhuma ferramenta foi rodada**: `mix sobelow`, `mix hex.audit`,
  `mix deps.audit`, `mix credo`, `mix test`. A instrução vedou. Os dados de dependência vêm da API
  pública do `hex.pm`, e não de uma resolução real com `mix deps.get`.
- **O código-fonte do SDK OpenTelemetry Erlang 1.7.0 e do exportador 1.11.0**: não estão no
  cache local. Por isso ficaram como *"a verificar no plano"*: os detectores de recurso padrão, a
  precedência das variáveis `OTEL_*`, se `otel_batch_processor` conta o descarte, e se as
  aplicações `grpcbox`/`chatterbox` abrem porta sem configuração.
- **O SigNoz `v0.144`**: não li o código nem a documentação do Foundry. Ficaram por verificar o
  alcance do OpAMP, o nome da variável que desliga a telemetria de uso, o que ela envia, e se há
  convite ou cadastro aberto depois da primeira conta.
- **O VPS**: qual é a rede Docker da aplicação no Dokploy, quais outros serviços a compartilham,
  e o que o backup de volumes inclui. Nenhum acesso ao servidor nesta avaliação.
- **`lib/the_band/tenants/user.ex` inteiro, `User.senha_changeset/3`** e as mensagens de erro de
  validação da senha: li só os campos com `redact`.
- **A tela de perfil e `ProfileLive`** além de confirmar que a troca de senha é POST clássico
  (`profile_live/index.ex:112`); e `SetPassword` além do formulário.
- **A entrada do operador da plataforma** (`/platform/sign-in`, spec 070): está fora de escopo
  da 074, e é a próxima fatia; o código TOTP e o código de recuperação passam por ela, e ela
  precisa da própria avaliação com este mesmo filtro.
- **`docs/backlog/observabilidade-com-opentelemetry.md`** e **`specs/049-entrar-com-github/`**: não
  li. A spec afirma que OAuth não existe; conferi só que o roteador não tem rota para ele
  (`router.ex:283-291`).
- **O aviso de privacidade e o registro de tratamento** da plataforma, para a parte LGPD de S13.
- **As seções da ADR fora das citadas**, e as mudanças que o autor fez nela durante esta
  avaliação: o arquivo mudou em disco enquanto eu lia; os números de linha citados são da versão
  de 521 linhas.
