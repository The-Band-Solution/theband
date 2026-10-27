# Avisos de 2026-10-27: `bandit`, `jose`, `plug_crypto` e `ex_mcp` — avaliação antes do código

Issue **#1439**. Agente `security`, 2026-10-27. Avaliação **antes do código** (AGENTS.md §14.0):
nada em `mix.exs`, `mix.lock`, `lib/`, `config/` ou `test/` foi alterado. A resolução das versões
novas e o `mix hex.audit` sobre elas foram feitos numa **cópia de `mix.exs`/`mix.lock` no
scratchpad da sessão**, fora do repositório. Nenhum código das versões novas foi compilado nem
executado.

**Escopo**: o diff de dependências que a #1439 pede (quatro pacotes) e o alcance de cada aviso
nesta aplicação. Não é varredura completa da superfície.

## 0. O fato que muda a leitura de tudo: a produção NÃO tem as mitigações do #1434

O #1434 (HTTP/2 do Bandit desligado e `TheBandWeb.Plugs.HostAceito`) está no `development` e
**não está na `main`**:

| Conferido | Comando | Resultado |
|---|---|---|
| #1434 na `main`? | `git merge-base --is-ancestor 9ae29d0 origin/main` | **não** |
| HTTP/2 desligado na `main`? | `git show origin/main:config/config.exs \| grep http_2` | **nenhuma linha**: HTTP/2 no padrão do Bandit, ligado |
| `HostAceito` na `main`? | `git show origin/main:lib/the_band_web/endpoint.ex \| grep HostAceito` | **nenhuma linha** |
| versões na `main` | `git show origin/main:mix.lock` | `bandit 1.12.5`, `jose 1.11.12`, `plug_crypto 2.2.0`, `ex_mcp 1.5.0` |

Então as exceções `EEF-CVE-2026-105659` e `-105660` do `mix.exs` valem para o `development`, e a
v0.12.0 em produção roda o Bandit 1.12.5 **com HTTP/2 ligado e sem a lista de hosts**. A pergunta
"o HTTP/2 é alcançável em produção?" depende de duas coisas que **ninguém mediu**:

1. a porta 4000 está publicada no VPS? — é o item 1 de `docs/producao/o-que-fazer-no-servidor.md`,
   em aberto;
2. o Traefik fala HTTP/1.1 ou h2c com a aplicação? — o comentário em `config/config.exs:36-42`
   afirma HTTP/1.1; **não há medição registrada**.

## 1. Alcance de cada aviso nesta aplicação

Os textos e as faixas vieram do OSV (`api.osv.dev/v1/vulns/<id>`, 22 registros, todos `200`),
guardados em `scratchpad/osv/`. As faixas "consertado em" abaixo são as do OSV.

Legenda de "alcance":
- **Traefik** = alcançável por qualquer cliente da internet, pelo caminho normal;
- **porta direta** = só com conexão direta à porta 4000 (não medido se existe);
- **inalcançável** = o código e a configuração não chegam ao caminho vulnerável, com o porquê.

### 1.1 `bandit` 1.12.5 (servidor HTTP de produção)

| Aviso | Sev. OSV | Protocolo | Consertado | Alcance em produção (v0.12.0) | Alcance no `development` | Sev. efetiva |
|---|---|---|---|---|---|---|
| **-114213** fragmentos WebSocket de 1 byte furam `max_fragmented_message_size` | HIGH | WebSocket | 1.14.0 | **Traefik**: `/live` aceita qualquer cliente (`Phoenix.LiveView.Socket.connect/3` devolve `{:ok, _}` sempre, `deps/phoenix_live_view/lib/phoenix_live_view/socket.ex:98`); o `check_origin` é contornado por cliente que não é navegador; não há `websocket_options` em `config/` (padrão 8 MB, `deps/bandit/lib/bandit/websocket/connection.ex:144`) | igual | **Alta** — memória ~150× o limite por conexão (~1,2 GB com o padrão), nó único: derruba todos os tenants |
| **-111101** corpo chunked em pedaços de 1 byte | HIGH | HTTP/1.1 | 1.14.0 | **porta direta**: sim. **Traefik**: depende de o Traefik reenquadrar o corpo; **não medido** | igual | Alta se a porta estiver publicada; não medido pelo Traefik |
| **-113436** `content-length` / porta do `Host` com milhares de dígitos (parse quadrático) | HIGH | HTTP/1 e HTTP/2 | 1.14.0 | **porta direta**: sim. **Traefik**: o `content-length` gigante tende a ser recusado pelo proxy; a porta no `Host` repassado **não medido** | igual (o `HostAceito` roda depois do parse, não protege) | Alta se a porta estiver publicada; não medido pelo Traefik |
| **-114216** extensão de chunk com LF solto (smuggling) | MEDIUM | HTTP/1.1 | 1.14.0 (introduzido em 1.12.4) | exige proxy na frente que aceite LF solto **e** repasse o chunked sem reenquadrar. Versão do Traefik e comportamento **não medidos**. E não há controle de acesso no proxy a contornar: a autorização é toda da aplicação | igual | **Baixa** |
| **-110314** frames WebSocket chegam ao WebSock depois do Close do servidor | MEDIUM | WebSocket | 1.14.0 | **Traefik**, mas sem efeito de autorização aqui: a plataforma não usa `{:stop, ...}` do socket para revogar ninguém (nenhum `live_socket_id`/`"disconnect"` em `lib/`); a sessão derrubada cai **dentro** do LiveView, por `redirect` (`lib/the_band_web/live/hooks.ex:137-170`), e um `phx_join` novo passa de novo pelo `on_mount`, que relê o banco | igual | **Baixa** (o caminho restante é o `:socket_drain` num deploy) |
| **-108525** controle de fluxo HTTP/2 de entrada não aplicado | HIGH | HTTP/2 | 1.14.0 | **porta direta** (h2c com conhecimento prévio) ou Traefik em h2c — **não medido** | **inalcançável**: HTTP/2 desligado, guarda `test/the_band_web/bandit_sem_http2_test.exs` | Alta condicional em prod |
| **-108529** SETTINGS/WINDOW_UPDATE quadrático | HIGH | HTTP/2 | 1.14.0 | idem | inalcançável | idem |
| **-109584** "cookie crumb" HPACK → alocação ilimitada | HIGH | HTTP/2 | 1.14.0 | idem | inalcançável | idem |
| **-110499** tabela HPACK do encoder sem teto | HIGH | HTTP/2 | 1.14.0 | idem | inalcançável | idem |
| **-111103** StreamError reverte o estado e fura limites | HIGH | HTTP/2 | 1.14.0 | idem | inalcançável | idem |
| **-115269** WINDOW_UPDATE/SETTINGS reiniciam o prazo de leitura | HIGH | HTTP/2 | 1.14.0 | idem | inalcançável | idem |
| -105659 (já com exceção) | HIGH | HTTP/2 | **1.13.0** | idem | inalcançável (exceção + guarda) | idem |
| -105660 (já com exceção) | MEDIUM | HTTP/1 forma absoluta | **1.13.0** | **porta direta** e Traefik (forma absoluta repassada?) — **não medido**; em prod sem `HostAceito` | mitigado (`HostAceito`, `force_ssl` com `:host`) | Média em prod |

**Novidade do OSV**: -105659 e -105660 **têm conserto** desde a 1.13.0 (15/10). O comentário do
`mix.exs` ("sem versão consertada") era verdade em 2026-10-15 de manhã e deixou de ser no mesmo dia.

### 1.2 `plug_crypto` 2.2.0 — EEF-CVE-2026-105963 (MEDIUM no OSV; **Alta** aqui)

O defeito: toda função pública de `Plug.Crypto` checa tipo na guarda da cabeça; argumento de tipo
errado vira `FunctionClauseError` com **os argumentos reais** no frame do topo, e o Bandit/Logger
escrevem esse frame no log. Em `verify/4`, o primeiro argumento é o `secret_key_base`.

**O caminho concreto nesta aplicação**, lido no código:

1. qualquer cliente abre WebSocket em `/live` (connect aceita todos, ver acima);
2. manda `phx_join` no tópico `lv:qualquer` com `{"session": ["x"]}` — JSON permite lista;
3. `Phoenix.LiveView.Channel.mount/3` casa `%{"session" => session_token}` sem checar tipo
   (`deps/phoenix_live_view/lib/phoenix_live_view/channel.ex:1102-1105`);
4. `Session.verify_session/4` → `Static.verify_token/2` → `Phoenix.Token.verify/4`
   (`deps/phoenix/lib/phoenix/token.ex:231-234`), que repassa o token sem guarda a
   `Plug.Crypto.verify(secret_key_base, salt, ["x"], opts)`;
5. a guarda `is_binary(token)` falha (`deps/plug_crypto/lib/plug/crypto.ex:291-292`) e o processo
   do canal morre com o `secret_key_base` no primeiro argumento do frame.

Os mesmos passos valem para `"static"`, para `"flash"` e para o `"token"` do canal de upload
(`lvu:*`, `upload_channel.ex:57-59`). O LongPoll **não** é caminho: confere `is_binary(token)`
antes (`deps/phoenix/lib/phoenix/transports/long_poll.ex:204`).

**Medido em parte.** Com uma chave **fictícia**, `Plug.Crypto.verify("CHAVE-FICTICIA-…", "sal",
["x"], [])` formatado por `Exception.format/3` imprime a chave na linha do frame
(`scratchpad/plug_crypto_prova.log`, 1 ocorrência). **Não medi** o caminho de ponta a ponta (o
socket do LiveView até a linha de log do contêiner), e **não medi** se já aconteceu em produção.

As chamadas próprias de `Plug.Crypto.secure_compare/2` (`lib/the_band/ai.ex:230`,
`lib/the_band/platform/credentials.ex:553`, `lib/the_band/platform/sessions.ex:125`,
`lib/the_band/tenants/sessions.ex:259`, `lib/the_band/tenants/api_tokens.ex:410`) comparam
**resumos** do segredo do pedido com o resumo gravado; no pior caso o frame levaria um resumo, não
o segredo do servidor. Não são o caminho.

**Consequência**: quem lê o log de produção (hoje, quem opera o Dokploy; amanhã, o que a telemetria
da 074 exportar e o backup que guardar log) passa a ter o `secret_key_base`, com o qual se forjam
cookie de sessão e tokens do LiveView. O cookie forjado **não** abre sessão sozinho — a sessão é
relida no banco pelo `session_token` (`Sessao.conferir`) —, e é por isso que a severidade não é
"autenticação contornável". Mas é **segredo logado por pedido de anônimo**, que é Alta pela régua.

**Exposição ativa ou defeito conhecido?** Defeito conhecido alcançável (§14.0, item 2). **Vira
exposição ativa (item 1) se o log de produção tiver ao menos uma ocorrência** — e isso só a pessoa
mantenedora pode medir (seção 5, tarefa B2).

### 1.3 `jose` 1.11.12 — 8 avisos (1 HIGH): inalcançáveis

| Aviso | Função atingida | Alcance |
|---|---|---|
| -65625 tag AES-GCM truncada | `jose_jwa_aes` (fallback puro-Erlang, JWE) | inalcançável |
| -65626 oráculo Bleichenbacher | `jose_jwa_pkcs1` (JWE RSA1_5) | inalcançável |
| -65627 bomba de descompressão | `jose_jwe_zip:uncompress/2` (JWE `zip: DEF`) | inalcançável |
| -65628 recursão infinita | `JOSE.JWK.shared_secret/2` | inalcançável |
| -65629 (HIGH) PBKDF2 fraco na exportação | `JOSE.JWK.to_der/2` com senha | inalcançável |
| -65630 tempo em X25519 puro-Erlang | `jose_jwa_x25519` | inalcançável |
| -65631 fatoração de módulo RSA | `JOSE.JWK.from_map/1`, `from_binary/1` | inalcançável |
| -65632 maleabilidade ECDSA | `jose_jwk_kty_ec:verify/4` | inalcançável |

Como foi verificado: `grep -rn -E 'JOSE|:jose_' lib config` → nenhuma ocorrência fora de
comentário; nas dependências, só a `ex_mcp` chama JOSE, e só em `ExMCP.Authorization.*` (fluxos
OAuth do **cliente** e validação de JWT) e `ExMCP.Plugs.JWKS`. Nada disso é montado: a porta
(`lib/the_band_web/mcp/porta.ex:32-45`) não passa `oauth_enabled` (padrão `false`,
`deps/ex_mcp/lib/ex_mcp/http_plug.ex:212`), não há rota de JWKS nem `.well-known`, e a porta só
entrega `/mcp` exato. **Não há ECDSA, JWT nem JWE nesta aplicação.** Severidade efetiva:
**Informativo**. Some com a subida (1.11.13 entra pela resolução da `ex_mcp`).

### 1.4 `ex_mcp` 1.5.0 — retirada (GHSA-22m7-hr37-pxg3): inalcançável, mas a retirada reprova o gate

O aviso (texto do GitHub, `repos/trust-arbor/arbor_mcp/security-advisories/GHSA-22m7-hr37-pxg3`):
`notifications/cancelled` grava o `requestId` numa ETS global, sem escopo de sessão, e nunca
limpa. Dois efeitos: cancelar o pedido de outro cliente e crescer a tabela sem limite.

**Inalcançável aqui, e por uma defesa que já existe**: `TheBandWeb.Plugs.McpMetodos`
(`lib/the_band_web/plugs/mcp_metodos.ex:58`) deixa passar só `server/discover`, `tools/list` e
`tools/call`. `notifications/cancelled` saiu em 2026-09-25 exatamente por este defeito (N3 da
revisão da 062: "cinco notificações de 200 KB deixaram cerca de 1 MB retido"), e o
`test/the_band_web/mcp/metodos_test.exs:49-54` prova a recusa. O handler
(`lib/the_band_web/mcp/servidor.ex`) não chama `Context.cancelled?/0`. Não há transporte stdio
nem `:beam` iniciado. Severidade efetiva: **Informativo** — a casa achou o defeito três semanas
antes do aviso.

O problema real é de **gate**: versão retirada reprova `mix hex.audit`, e a fixação `== 1.5.0`
impede a saída.

## 2. O que a subida muda

### 2.1 Resolução medida (cópia do `mix.exs`/`mix.lock` no scratchpad)

`ex_mcp` trocada para `== 1.7.3` e `mix deps.update bandit jose ex_mcp cowlib thousand_island`;
`mix deps.get` (só baixa). Diferença do `mix.lock` contra o do repositório:

| Pacote | Hoje | Depois | Por quê |
|---|---|---|---|
| `bandit` | 1.12.5 | **1.14.0** | conserta os 11 novos e -105659/-105660 |
| `thousand_island` | 1.5.0 | **1.6.0** | o Bandit ≥ 1.13 exige `~> 1.6` |
| `plug_crypto` | 2.2.0 | **2.2.1** | conserta -105963 (resolve sozinho: `plug` aceita `~> 2.0`) |
| `jose` | 1.11.12 | **1.11.13** | conserta os 8 |
| `ex_mcp` | 1.5.0 | **1.7.3** | única 1.x não retirada |
| `cowlib` | 2.20.0 | **2.21.0** | a `ex_mcp` ≥ 1.6.2 passa a exigir `cowlib ~> 2.20` **direto**; a 2.21.0 conserta -43969 |
| `cowboy` | 2.19.0 | **2.20.0** | arrastado pelo `cowlib` |
| `castore` | 1.0.21 | **1.0.22** | arrastado pela `ex_mcp` |

`hpax`, `mint`, `plug_cowboy` (2.9.0), `decimal` (3.2.0) e o resto: **iguais**.

`mix hex.audit` sobre esse lock, com o `mix.exs` atual (as exceções todas lá):
**`EXIT=0`**. Sobram, ignorados: `cloak` -95105, `cloak_ecto` -94206 e `cowlib 2.21.0` -43966. E
três avisos amarelos: as entradas **-43969, -105659 e -105660 "não casam com nenhum aviso e podem
ser removidas"**.

### 2.2 Qual `ex_mcp`

| Versão | Situação no Hex (`mix hex.info ex_mcp`, 2026-10-27) |
|---|---|
| 1.5.0, 1.6.0, 1.6.1 | retiradas |
| **1.6.2** (a que o aviso manda) | **retirada** — GHSA-2q9v-qvwf-3m8w e GHSA-jrw4-h7gq-x4cj (adaptadores ACP). Medido: com ela, `hex.audit` sai **1** |
| 1.7.0, 1.7.2 | retiradas |
| **1.7.3** (2026-10-26) | **não retirada** |

**Recomendação: `{:ex_mcp, "== 1.7.3"}`**, mantendo a fixação exata e o motivo dela. A 1.6.2 que a
issue cita reprovaria o gate do mesmo jeito.

O que a 1.6.2→1.7.3 muda, para esta aplicação (CHANGELOG da 1.7.3, lido no pacote baixado):
- **ainda exige `plug_cowboy ~> 2.7`** e agora também `cowlib ~> 2.20` e `decimal >= 3.1.2`; o
  Cowboy opcional continua anunciado para a 2.0;
- `lib/ex_mcp/application.ex` **idêntico** ao da 1.5.0 (`diff`, saída vazia): nenhum listener novo;
- `lib/ex_mcp/protocol/methods.ex` idêntico: a tabela de métodos modernos é a mesma que o
  `McpMetodos` documenta;
- as opções lidas por `ExMCP.HttpPlug.init/1` são as mesmas; a única mudança no `http_plug.ex` é de
  compatibilidade de versão do protocolo **legado** (não usamos: `protocol_mode: :modern_only`);
- 1.6.1: `structuredOutput` passa a sair como `structuredContent` — usamos `structuredContent`
  direto (`lib/the_band_web/mcp/servidor.ex:83`); `outputSchema` passa a ser validado — não
  declaramos `outputSchema` (grep vazio);
- 1.7.3: `logging/setLevel` deixava cliente mudar o nível global do Logger — **nunca chegou** aqui,
  porque `logging/*` é recusado pelo `McpMetodos`;
- o resto (86 arquivos de `lib/` diferem) é ACP, cliente OAuth e transportes que não montamos.

### 2.3 `bandit` 1.12.5 → 1.14.0: o que pode quebrar

Do CHANGELOG (1.13.0, 1.13.1, 1.14.0), o que toca esta aplicação:
- HTTP/1: linha de pedido com exatamente três palavras e versão `HTTP/1.1`/`HTTP/1.0`; forma
  absoluta com caminho vazio e query recebe **400**; autoridade da forma absoluta validada pela
  gramática do `Host`; bytes de controle no alvo recusados; `Host` exigido no HTTP/1.1. **Pode
  mudar o código ou o corpo de resposta esperado em `test/the_band_web/host_aceito_test.exs`**
  (casos de forma absoluta). Não medido — é para o QA rodar;
- conexão ociosa que não manda nada é fechada **sem 408**;
- WebSocket: o servidor fecha a conexão quando o prazo do Close passa (pode afetar teste que
  dependa do socket ficar aberto depois de `{:stop, ...}`);
- HTTP/2: limites novos por padrão (`max_concurrent_streams` 500 etc.) — irrelevante com HTTP/2
  desligado;
- `read_body` no HTTP/2 pode devolver mais que `:length` — irrelevante com HTTP/2 desligado.

**Idade das versões**: `bandit` 1.14.0, `jose` 1.11.13 e `ex_mcp` 1.7.3 saíram em 2026-10-26, um
dia antes desta avaliação. Risco de regressão real; a mitigação é a suíte inteira, `mix gates` e
o roteiro de aceitação depois do deploy — não é motivo para esperar, porque a 1.12.5 tem
caminho alcançável pelo Traefik (-114213 e -105963).

## 3. O destino de cada exceção e guarda

| Exceção / guarda | Hoje | Depois da subida | O que fazer | Medir de novo? |
|---|---|---|---|---|
| `ignore_advisories` **EEF-CVE-2026-105659** | exceção aceita (2026-10-15) | **obsoleta** (consertado na 1.13.0); `hex.audit` avisa | **remover** do `mix.exs`, com o comentário | não |
| `ignore_advisories` **EEF-CVE-2026-105660** | exceção aceita | **obsoleta** (1.13.0) | **remover** | não |
| `ignore_advisories` **EEF-CVE-2026-43969** (cowlib) | exceção aceita (2026-09-24) | **obsoleta** (cowlib 2.21.0) | **remover** | não |
| `ignore_advisories` **EEF-CVE-2026-43966** (cowlib) | exceção aceita | **continua** (2.21.0 ainda afetada; o próprio `ex_mcp` 1.7.3 a mantém ignorada no `mix.exs` dele) | manter, **refazer a medição** e reescrever o comentário: condição 4 passa a citar 1.7.3, e a dependência direta da `ex_mcp` em `cowlib` | **sim** — ver abaixo |
| `test/the_band/cowlib_inalcancavel_test.exs` teste 4 (`ex_mcp == "1.5.0"`) | verde | **reprova**, como foi escrito para fazer | trocar para `1.7.3` **só depois** da medição refeita; nunca antes | **sim** |
| idem, testes 1–3 (adapter Bandit, `:ranch.info() == %{}`, varredura de AST) | verdes | devem continuar verdes | nada; o QA confirma | rodam sozinhos |
| `test/the_band_web/bandit_sem_http2_test.exs` | guarda da exceção -105659 | a exceção some; o teste **continua passando** | **manter o HTTP/2 desligado e o teste**, reescrevendo o `@moduledoc` e o comentário de `config/config.exs:36-42`: deixa de ser guarda de exceção e passa a ser guarda de **endurecimento** — 7 dos 13 avisos do Bandit em 12 dias eram só de HTTP/2 (e um oitavo, -113436, é amplificado por ele), e a aplicação não precisa dele atrás do Traefik. Religar é decisão da pessoa mantenedora | não |
| `TheBandWeb.Plugs.HostAceito` + `test/the_band_web/host_aceito_test.exs` + `force_ssl` com `:host` | guarda da exceção -105660 | a exceção some | **manter**: a 1.13.0 valida a **gramática** da autoridade, mas o cliente continua escolhendo o host (como sempre escolheu pelo cabeçalho `Host`). Reescrever o comentário para defesa em profundidade | o QA confere os casos de forma absoluta (seção 2.3) |
| guardas do `cloak`/`cloak_ecto` | verdes | inalteradas (versões iguais) | nada | não |
| `test/the_band/decimal_limitado_test.exs` | verde | inalterado (`decimal` 3.2.0, e a `ex_mcp` agora exige ≥ 3.1.2) | nada | não |

### 3.1 A medição R3 refeita para `ex_mcp` 1.7.3 — o que é preciso

`specs/062-servidor-mcp/r3-cowlib-alcance.md` mediu a 1.5.0 em quatro frentes. O que já li aqui
(estático, no pacote baixado):
- `grep -rn -E ':cow_|Plug\.Cowboy|:ranch|:gun' ex_mcp-1.7.3/lib` → só `lib/ex_mcp/http_plug.ex:30`
  (exemplo no `@moduledoc`) e `lib/ex_mcp/server/transport.ex:129,177,184,198,204,315` — os mesmos
  pontos da 1.5.0 (transporte standalone, que não iniciamos);
- `lib/ex_mcp/application.ex` idêntico ao da 1.5.0.

O que **falta medir**, e é o que a decisão de 2026-09-24 exigiu ("SÓ SE for medido"):
1. **dinâmico**: com o lock novo, num projeto de rascunho, `Application.ensure_all_started(:ex_mcp)`
   e conferir `:ranch.info() == %{}`;
2. **o trace com controle positivo**: as chamadas a `:cow_*` durante um `POST /mcp` servido pelo
   Bandit (esperado: zero) e o mesmo sob Cowboy (esperado: > 0), como na R3 §4;
3. **o codificador do 43966 no `cowlib` 2.21.0**: `grep` dos chamadores de
   `cow_http_struct_hd:item|list|dictionary` no `cowlib` 2.21.0 e no `cowboy` 2.20.0 — a R3 achou
   zero no 2.20.0/2.19.0; versão nova, contagem nova;
4. registrar como `r3-cowlib-alcance-1.7.3.md` (ou seção nova no mesmo arquivo), com os códigos de
   saída, e só então atualizar o teste 4.

## 4. Cenários de ataque para o QA, e as guardas que nascem provadas

Regra da casa: cada guarda é vista **reprovando** com o defeito presente. Para dependência, o
"defeito injetado" é o lock atual: o teste é escrito **antes** de subir a versão, roda contra
1.12.5 / 2.2.0 e reprova; depois da subida, passa. A evidência (comando e `EXIT`) vai na #1439.

| # | Cenário (quem, com o quê, esperando o quê) | Asserção que importa | Como nasce provada |
|---|---|---|---|
| **G1** | anônimo abre o socket do LiveView e manda `phx_join` em `lv:x` com `"session"` de tipo errado (lista; e mapa); idem `"static"`, `"flash"` e o `"token"` do `lvu:x` | `capture_log` do join: **`refute` que o log contém o `secret_key_base` do endpoint** (e a guarda de cenário: `assert` que o log tem **alguma** linha do join, senão o `refute` passa por não ter medido nada) | reprova com `plug_crypto` 2.2.0 (o frame traz a chave); passa com 2.2.1. Chave de teste é a de `config/test.exs`, pública por desenho |
| **G2** | piso de versão do `plug_crypto` | `Application.spec(:plug_crypto, :vsn)` ≥ 2.2.1, no molde de `decimal_limitado_test.exs` | reprova com 2.2.0 |
| **G3** | cliente HTTP/1.1 manda, numa conexão, `POST` chunked com `2;\nxx\r\n40\r\n0\r\n\r\n` seguido de `GET /x` (PoC da -114216), contra um Bandit com as opções do endpoint e um plug que registra cada pedido | **`refute` que o Bandit despachou dois pedidos**; controle: o mesmo par sem o LF solto despacha os dois | determinístico; reprova na 1.12.5 |
| **G4** | WebSock cujo `init/1` devolve `{:stop, :normal, ...}`; o cliente ignora o Close e manda um frame de texto (PoC da -110314) | **`refute` que `handle_in/2` rodou** | determinístico; reprova na 1.12.5 |
| **G5** | piso de versão do `bandit` | `Application.spec(:bandit, :vsn)` ≥ 1.14.0 | reprova com 1.12.5. É a guarda que cobre os avisos de memória/CPU (-114213, -111101, -113436), cujo teste de comportamento depende de medir memória e tempo — instável na suíte; se o QA quiser um, que seja `@tag :integration` e fora do `mix gates` |
| **G6** | `ex_mcp` fixada e medida | o teste 4 do `cowlib_inalcancavel_test.exs` em `"1.7.3"` / `"== 1.7.3"` | **só** depois da medição da seção 3.1; o teste atual (1.5.0) reprova com o lock novo — essa reprovação é a evidência de que ele mede |
| **G7** | `notifications/cancelled` continua recusado depois da troca da biblioteca | o caso já existe (`metodos_test.exs:49-54`); o QA confirma que ele **está na suíte e verde** com a 1.7.3 | defeito injetado: tirar a recusa em cópia do plug e ver reprovar (copiar antes, como manda a lição do `git checkout`) |
| **G8** | HTTP/2 continua desligado | `bandit_sem_http2_test.exs` sem mudança de asserção | já nasceu provado no #1434; com a 1.14.0, o controle positivo (HTTP/2 ligado responde SETTINGS) precisa continuar passando, senão o teste perde o controle |
| **G9** | as exceções obsoletas saíram | lista de `ignore_advisories` do `Mix.Project.config()[:hex]` é exatamente `["EEF-CVE-2026-43966", "EEF-CVE-2026-95105", "EEF-CVE-2026-94206"]` | reprova com o `mix.exs` atual (6 entradas). Ver achado M1 |

Nenhum segredo real em fixture: G1 usa a chave de `config/test.exs`.

## 5. Achados e tarefas, para o Product Owner

### A1 — Alta: `secret_key_base` vai para o log por pedido de anônimo (`plug_crypto` 2.2.0)

| Campo | Conteúdo |
|---|---|
| O que é | OWASP A09/A02 (segredo em log). Anônimo manda `phx_join` com `session` de tipo errado e o `secret_key_base` é escrito no log de erro |
| Onde | `deps/phoenix_live_view/lib/phoenix_live_view/channel.ex:1102-1105` → `deps/phoenix/lib/phoenix/token.ex:231-234` → `deps/plug_crypto/lib/plug/crypto.ex:291-292`; versão em `mix.lock:67` |
| Severidade | Alta — "segredo exposto ou logado" |
| Consequência | quem tiver o log (operação, retenção, backup, telemetria futura) tem a chave que assina a sessão de todas as organizações. Não abre sessão sozinha (a sessão é relida no banco), mas forja qualquer token do LiveView e qualquer cookie |
| O que fecha | `plug_crypto` 2.2.1 + G1 + G2 |
| Se não entrar agora | qualquer pessoa pode, a qualquer momento, gravar a chave no log de produção |

**Tarefas bloqueantes da v0.12.1:**
- **B1** subir `plug_crypto` para 2.2.1, com G1 e G2 vistos reprovando antes;
- **B2** 👤 **pessoa mantenedora**, no VPS: contar, **sem copiar linha nenhuma**, as ocorrências de
  `no function clause matching in Plug.Crypto` no log da aplicação desde o deploy da v0.12.0 (só o
  número volta para a issue). Se for **> 0**, é exposição ativa (§14.0, item 1): **girar o
  `SECRET_KEY_BASE` primeiro** (derruba as sessões abertas; ninguém usa a plataforma hoje, segundo o
  roteiro do servidor), tratar o log retido como sensível, e registrar a rotação na nota da
  release. Se for 0, registrar o 0 e a janela de retenção medida (que é a #1390, em aberto).

### A2 — Alta: esgotamento de memória pelo WebSocket do LiveView (`bandit` 1.12.5, -114213)

| Campo | Conteúdo |
|---|---|
| O que é | OWASP A06 (componente vulnerável) com efeito de indisponibilidade. Uma conexão anônima em `/live` segura ~150× `max_fragmented_message_size` (padrão 8 MB) |
| Onde | `mix.lock:3` (`bandit` 1.12.5); nenhuma `websocket_options` em `config/config.exs`; `/live` em `lib/the_band_web/endpoint.ex:20-22` |
| Severidade | Alta **por extensão minha da régua**: a tabela da casa não nomeia indisponibilidade. O critério usado é o mesmo da N3 da 062 (memória esgotável por cliente → nó único → todos os tenants fora). O PO pode rebaixar para Média, com o registro |
| Consequência | um único cliente sem conta derruba a plataforma para todas as organizações, pelo caminho normal (Traefik) |
| O que fecha | `bandit` 1.14.0 + G5 |
| Se não entrar agora | a produção fica derrubável por quem quiser, até a próxima release |

**Tarefa bloqueante:** **B3** subir `bandit` para 1.14.0 (e `thousand_island` 1.6.0), com G3, G4 e
G5 vistos reprovando antes, e os testes de `host_aceito_test.exs` e `bandit_sem_http2_test.exs`
rodados contra a versão nova.

### A3 — Alta condicional: produção com HTTP/2 ligado e sem `HostAceito`

| Campo | Conteúdo |
|---|---|
| O que é | os sete avisos HTTP/2 HIGH (mais -105659) e o -105660 estão **abertos na v0.12.0**, porque o #1434 não foi para a `main` |
| Onde | `origin/main:config/config.exs` (sem `http_2_options`), `origin/main:lib/the_band_web/endpoint.ex` (sem `HostAceito`) |
| Severidade | Alta **se** a porta 4000 estiver publicada ou se o Traefik falar h2c com a aplicação; Baixa se nenhum dos dois. **Não medido** |
| O que fecha | a v0.12.1 com #1434 **e** esta subida juntos — a subida conserta o defeito; o #1434 reduz a superfície |
| Tarefa | **B4** 👤 item 1 de `docs/producao/o-que-fazer-no-servidor.md` (porta 4000), antes ou junto do deploy da v0.12.1. Não bloqueia o PR; bloqueia **declarar** a exposição como fechada |

### A4 — Bloqueante de gate (sem exposição): `ex_mcp` 1.5.0 retirada

O aviso é inalcançável (seção 1.4), mas a retirada reprova `mix hex.audit` e, com ele, **todo PR**.
**B5** `ex_mcp` `== 1.7.3`, com a **medição R3 refeita** (seção 3.1) antes de atualizar o teste 4 e
o comentário da exceção -43966; remover as entradas -43969, -105659 e -105660 (G9). A `jose`
1.11.13 entra junto, pela resolução.

### M1 — Baixa: entrada obsoleta em `ignore_advisories` não reprova o gate

Medido no scratchpad: com as três entradas obsoletas, `mix hex.audit` sai **0** e só imprime aviso
amarelo. Os comentários do `mix.exs` dizem que a exceção "sai sozinha quando o `hex.audit` avisa" —
o aviso existe, mas **não reprova**, e um `| tail` ou uma leitura apressada o perdem. Risco
concreto pequeno (o ID é único por aviso; só voltaria a mascarar algo num rebaixamento de versão),
mas é exatamente a forma de "verde que não foi lido". O que fecha: G9, ou o `mix gates` tratar a
linha `does not match any advisory` como reprovação. Item de backlog, sem prazo.

### Classificação de entrega

| Severidade | Itens |
|---|---|
| Alta (recomendação de bloqueio da v0.12.1 até entrar) | A1 (B1, B2), A2 (B3) |
| Alta condicional / medição pendente | A3 (B4) |
| Bloqueio de gate, sem exposição | A4 (B5) |
| Baixa | M1; -114216 e -110314 nesta aplicação |
| Informativo | `jose` (8 avisos), GHSA-22m7 (já fechado pelo `McpMetodos`) |

Se a v0.12.1 sair sem A1 ou A2, a decisão é do Product Owner e vai para `docs/releases/v0.12.1.md`
como risco residual aceito, com quem decidiu, quando e por quê.

## 6. O que NÃO foi verificado

- **se a porta 4000 está publicada** no VPS, e **qual protocolo** o Traefik usa com a aplicação
  (HTTP/1.1 afirmado em comentário, nunca medido): decide o alcance de -108525, -108529, -109584,
  -110499, -111103, -115269, -105659, -111101, -113436 e -105660 em produção;
- **a versão do Traefik** e como ele trata LF solto em chunk e se reenquadra corpos chunked:
  decide -114216 e -111101 pelo caminho normal;
- **se o `Host` com porta de milhares de dígitos atravessa o Traefik** (-113436);
- **o caminho de ponta a ponta do A1**: provei só que o frame formatado carrega a chave (com chave
  fictícia); não subi o endpoint nem conferi a linha no log do contêiner;
- **se o A1 já aconteceu em produção** — é a B2, da pessoa mantenedora;
- **para onde vai o log de produção** além do `stdout` do contêiner (retenção do Dokploy, backup,
  e se a telemetria da 074 exporta log ou só traços) — a #1390 está aberta;
- **a medição R3 dinâmica para `ex_mcp` 1.7.3** (trace com controle e `:ranch.info()`): li só o
  estático;
- **`mix deps.audit`** (mix_audit) sobre o lock novo: não rodei, porque exigiria compilar as
  dependências novas, e o pedido foi não executar código delas. Só o `hex.audit` foi medido;
- **a suíte contra as versões novas**: nenhum teste foi rodado com o lock novo; as quebras da seção
  2.3 são leitura de CHANGELOG, não resultado;
- **avisos de `thousand_island` 1.6.0, `cowboy` 2.20.0 e `castore` 1.0.22**: o `hex.audit` do lock
  novo não acusou nenhum; avisos não publicados não são conhecidos por ninguém;
- `mix gates` **não foi rodado** (árvore compartilhada, por instrução).

## Evidência (fora do repositório, no scratchpad da sessão)

`/private/tmp/claude-501/-Users-paulossjunior-projects-theband/c8edf967-303f-4714-a0f5-01cfe45ca793/scratchpad/`:
- `osv/*.json` — os 22 registros OSV;
- `pkgs/` — `bandit-1.13.0`, `bandit-1.14.0`, `ex_mcp-1.6.2`, `ex_mcp-1.7.3`, `jose-1.11.13`,
  `plug_crypto-2.2.1`, desempacotados e só lidos;
- `resolucao/mix.lock` e `resolucao/audit-com-excecoes.log` — o lock resolvido e o `hex.audit`
  com `EXIT=0`;
- `resolucao162/audit.log` — o `hex.audit` com `ex_mcp` 1.6.2, `EXIT=1` (retirada);
- `plug_crypto_prova.log` — o frame com a chave fictícia.
