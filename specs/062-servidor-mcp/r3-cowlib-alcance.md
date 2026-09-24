# R3 — o `cowlib` é alcançável na borda do The Band? · medição de 2026-09-24

Complemento da seção **R3** de `seguranca-revisao-independente.md`. A decisão da pessoa
mantenedora (2026-09-24) foi: *aceitar a exceção no gate SÓ SE for medido que o `cowlib` não é
alcançável na borda desta aplicação*. Este documento é essa medição — defensiva, sem exploit,
feita inteiramente no scratchpad da sessão, fora do repositório. Nada em `mix.exs` ou
`mix.lock` foi alterado; nenhum commit.

**Veredito: (a) não alcançável — exceção defensável, sob quatro condições escritas abaixo,
que a derrubam se deixarem de valer.** Não é "está seguro": é "o código vulnerável não está
em nenhum caminho de requisição de produção, medido estática e dinamicamente, com controle
positivo".

## 1. O que cada advisory afeta

Saída do `mix hex.audit` no projeto de rascunho com `{:ex_mcp, "1.5.0"}`
(`scratchpad/r3_hexaudit.log`, **código de saída 1**):

| Advisory | Severidade | Função | Natureza |
|---|---|---|---|
| EEF-CVE-2026-43966 (GHSA-w4f7-4cxr-rv3c) | MEDIUM | `cow_http_struct_hd:escape_string/2` | **codificador** de *Structured Field Values* (RFC 8941) — escrita de cabeçalho, não parser |
| EEF-CVE-2026-43969 (GHSA-g2wm-735q-3f56) | LOW | `cow_cookie:cookie/1` | **codificador de cliente** do cabeçalho `Cookie:` de *requisição* (o lado que o Gun usa) |

Onde li o texto:

- **43969**: texto completo na base local do mix_audit,
  `~/.local/share/elixir-security-advisories-mirego/packages/cowlib/GHSA-g2wm-735q-3f56.yml`
  (espelho de 2026-09-23): *"cow_cookie:cookie/1 in cowlib builds a client-side Cookie:
  request header from a list of name-value pairs without validating either field [...] The
  decoder side (parse_cookie_name/1, parse_cookie_value/1) and setcookie/3 already validate
  and reject these characters; the encoder alone is missing the check."* Nota lateral: essa
  base registra a faixa `>= 2.9.0, <= 2.16.1`, então `mix deps.audit` **não** a apontaria para
  2.20.0 — mais uma divergência entre as duas bases (não rodei `deps.audit` no rascunho).
- **43966**: **não está** na base local do mix_audit (só a do Hex a conhece). O que tenho é o
  título do Hex — *"HTTP Response Splitting via Non-VCHAR Bytes in
  cow_http_struct_hd:escape_string/2"* — e o fonte: `deps/cowlib/src/cow_http_struct_hd.erl:562-565`
  escapa só `\` e `"` e copia qualquer outro byte (CR, LF, não-VCHAR) para a saída;
  `:468-469` é o único uso, em `bare_item({string, _})`, alcançado pelos exportados `item/1`,
  `list/1` e `dictionary/1`. **Não li o texto OSV completo** (não consultei a rede).
- O contexto do mantenedor, do próprio pacote: `ex_mcp-1.5.0/mix.exs:29-49` e
  `ex_mcp-1.5.0/CHANGELOG.md:196-202` — o mantenedor do Cowlib recusou corrigir ("won't fix",
  ninenines/cowlib #152, #166, #169); a saída anunciada é o Cowboy opcional na ex_mcp 2.0.

Nenhuma das duas é parser HTTP/1.1, HTTP/2, websocket ou multipart. **As duas são
codificadores**: só fazem mal se alguém chamá-los com dado controlado pelo atacante.

Quem chama esses codificadores dentro das dependências (grep em `r3probe/deps`, fontes `.erl`
e `.ex`):

- `cow_http_struct_hd:item|list|dictionary` → só `cow_http_hd:variant_key/1`, `variants/1`,
  `wt_available_protocols/1`, `wt_protocol/1` (`cowlib/src/cow_http_hd.erl:3307, 3363, 3425,
  3442`). `grep -rnE "cow_http_hd:(variant_key|variants|wt_available_protocols|wt_protocol)\("`
  → **código de saída 1** (nenhum chamador, nem no Cowboy 2.19.0);
- `grep -rnE "cow_cookie:cookie\("` → **código de saída 1**. O Cowboy usa
  `cow_cookie:setcookie/3` (`cowboy/src/cowboy_req.erl:774`), que a própria advisory diz
  validar.

Ou seja: **mesmo sob Cowboy**, nenhum código do pacote chama as duas funções. Isso é
informação lateral — o critério da decisão é mais forte, e é o da seção 2.

## 2. O endpoint é servido pelo Bandit, e o `cowlib` não existe hoje

- `config/config.exs:26` — `adapter: Bandit.PhoenixAdapter`. É a **única** ocorrência de
  `adapter` em `config/` e em `lib/the_band_web/endpoint.ex` (grep). Há um só endpoint
  (`lib/the_band_web/endpoint.ex:2`).
- `mix.lock` do The Band: `cowlib`, `cowboy`, `ranch` e `gun` **não existem** como pacote.
  `plug_cowboy` aparece só como dependência `optional: true` de `phoenix` (linha 39) e de
  `websock_adapter` (linha 58) — não resolvida.
- `grep -rln ":cow_\|:cowboy\|:ranch\|Plug\.Cowboy" lib config test` do repositório →
  **código de saída 1**.
- Pilha do Bandit no rascunho (`bandit`, `thousand_island`, `hpax`, `websock`, `plug`,
  `plug_crypto`, `mint`, `mint_web_socket`, `jose`, `ex_json_schema`): as únicas menções a
  Cowboy são documentação, `@xref_exclude` e os wrappers depreciados
  `plug/lib/plug/adapters/cowboy.ex` (que só **iniciam** listener Cowboy). Nenhuma chama
  `:cow_*`. HTTP/2 no Bandit é `Bandit.HTTP2` + `hpax`, não `cow_http2`.

## 3. Dentro da ex_mcp 1.5.0: quem chama Cowboy/cowlib

`grep -rn ":cow_" ex_mcp-1.5.0/lib` → **código de saída 1**: a ex_mcp não chama nenhuma
função do cowlib diretamente, em módulo nenhum.

`grep -rn ":cowboy\|Plug\.Cowboy\|:ranch\|cowboy_" ex_mcp-1.5.0/lib`:

| Arquivo:linha | O que é |
|---|---|
| `lib/ex_mcp/http_plug.ex:4, 29-30` | **só `@moduledoc`** — exemplo de uso |
| `lib/ex_mcp/server/transport.ex:184, 204` | `Plug.Cowboy.http/3` em `start_http_server/4` — o **transporte standalone** |
| `lib/ex_mcp/server/transport.ex:315` | `Code.ensure_loaded?(Plug.Cowboy)` em `list_transports/0` |

O `ExMCP.HttpPlug`, que seria montado com `forward` no router Phoenix, **não referencia
Cowboy em código**. Ele fala com `Plug.Conn`, e sob o Bandit o adaptador do `conn` é
`Bandit.Adapter`.

Caminhos até `Plug.Cowboy.http/3` (o único ponto que sobe listener):

- `ExMCP.Server.Transport.start_server/4` com `transport: :http` (`transport.ex:65-69`);
- o `start_link/1` gerado pela DSL, **só** com `transport: :http` explícito — o padrão é
  `:beam` (`lib/ex_mcp/server/dsl.ex:620-633`);
- `ExMCP.start_server/1` vai para `HandlerServer.start_link/1`, cujo `connect_transport/2`
  aceita só `:test` e `:beam` (`handler_server.ex:732-748`) — não sobe Cowboy.

## 4. A aplicação da ex_mcp não sobe listener

`lib/ex_mcp/application.ex:9-51`: a árvore tem `DynamicSupervisor`, caches ETS,
`SessionRegistry`, `SessionManager`, `ProgressTracker`, `Reliability.Supervisor` — **nenhum
listener**, nenhuma porta. Não há configuração a desligar porque não há nada ligado.

Medido (não deduzido), em `scratchpad/r3probe` com `mix run --no-start`:

- depois de `Application.ensure_all_started(:ex_mcp)`, as aplicações `cowlib`, `ranch`,
  `cowboy`, `cowboy_telemetry` e `plug_cowboy` **são iniciadas** (são `applications` do
  `.app` da ex_mcp), mas `:ranch.info()` → `%{}`: **nenhum listener**;
- o único socket TCP em escuta é `Mix.Sync.PubSub` (processo do próprio `mix`, ancestral
  `Mix.Supervisor`), presente **antes** de iniciar a ex_mcp e ausente num release.

## 5. Dá para usar a ex_mcp sem `plug_cowboy`?

**Não na 1.5.0.** `plug_cowboy` é obrigatória (`ex_mcp-1.5.0/mix.exs:102`) e está em
`applications` do `ex_mcp.app` (`_build/dev/lib/ex_mcp/ebin/ex_mcp.app`; só `fuse` é
`optional_applications`). Experimento em `scratchpad/r3override`, com
`{:plug_cowboy, "~> 2.7", only: :test, override: true}`:

| Passo | Resultado |
|---|---|
| `mix deps.get` | saída 0 |
| `mix hex.audit` | **saída 1** — o `mix.lock` continua com `cowlib`; o gate lê o lock, não o build |
| `MIX_ENV=prod mix compile` | saída 0, com aviso `Plug.Cowboy.http/3 is undefined` em `transport.ex:184` |
| `Application.ensure_all_started(:ex_mcp)` em prod | `{:error, {:plug_cowboy, {~c"no such file or directory", ~c"plug_cowboy.app"}}}` — **não sobe** |

O `override` não resolve o gate e quebra o boot. As alternativas reais continuam as três da
R3: exceção registrada, esperar a 2.0 (o `docs/V2_ROADMAP.md` citado no CHANGELOG **não vem
no pacote**; prazo desconhecido), ou enquadramento JSON-RPC próprio sobre `Plug`.

## A medição dinâmica, e a prova de que ela mede

`scratchpad/r3probe/lib/r3.ex` (projeto de rascunho com `ex_mcp 1.5.0` + `bandit 1.12.5`):

1. `:erlang.trace(:all, true, [:call])` e `trace_pattern({m, :_, :_}, true, [:global])` em
   **todos os 77 módulos** das aplicações `cowlib`, `cowboy`, `ranch`, `plug_cowboy`,
   `cowboy_telemetry` — **816 funções**;
2. Bandit em `127.0.0.1:48123` servindo um `Plug.Router` com
   `forward "/mcp", to: ExMCP.HttpPlug` e um handler da DSL com uma ferramenta;
3. carga: `initialize` → `notifications/initialized` → `tools/list` → `tools/call` → `ping`
   → JSON malformado → `GET` (SSE) → `/.well-known/oauth-protected-resource` → `DELETE`,
   com cabeçalho `Cookie` e `mcp-session-id`;
4. **controle positivo**: o **mesmo** router sob `Plug.Cowboy.http/3` em `:48124`, mesma
   carga, mesmo tracer.

`mix run --no-start -e 'R3.Run.main()'` → **código de saída 0** (o script sai 0 só se o
Bandit tiver **zero** chamadas e o controle tiver **mais que zero**; `scratchpad/r3_run.log`):

| | Respostas (a carga foi processada) | Chamadas a cowlib/cowboy/ranch/plug_cowboy |
|---|---|---|
| **Bandit** | 200, 202, 200, 200, 200, 400 (`-32700 Parse error`), 404, 404, 204 | **0 funções distintas** |
| **Cowboy (controle)** | as mesmas | **85 funções distintas**, em `cow_http`, `cow_http1`, `cow_http_hd`, `cow_http_te`, `cowboy_*`, `ranch_*`, `Plug.Cowboy.*` |

A guarda de que mediu: as respostas do Bandit têm corpo real de `tools/list` e `tools/call`
(o plug executou), e o tracer **enxergou** 85 funções quando o caminho passava pelo Cowboy.
Zero no Bandit não é tracer quebrado. Nem o controle Cowboy tocou `cow_cookie:cookie/1` nem
`cow_http_struct_hd` — coerente com a seção 1.

## Onde a exceção entraria, e como o repositório registra exceção hoje

- O gate é `{"auditoria de dependências", {:mix, ["hex.audit"]}}` em
  `lib/mix/tasks/gates.ex:63`; o CI roda `mix gates` (`.github/workflows/ci.yml:113`). Não há
  exceção em `gates.ex` nem nos workflows.
- O mecanismo usado antes é `hex: [ignore_advisories: [...]]` em `project/0` do `mix.exs`
  (commit `c86b70b`, `CVE-2026-32686` do `decimal`), com o comentário do motivo ao lado.
  Removido em `4b2ab27` quando o próprio `hex.audit` passou a avisar que a entrada não casava
  com nada — o achado **H11** (`docs/seguranca/2026-09-09-o-que-consertar-agora.md:36`). O
  registro de que ela viveu ali está hoje em `mix.exs:21-28`.
- Portanto a exceção entraria em **`mix.exs`, `project/0`**, depois de `releases: releases()`,
  com os **dois IDs exatos** — nunca um curinga, para que toda advisory nova continue
  reprovando. **Não a apliquei.**

### Texto proposto para o comentário

```elixir
      # RISCO RESIDUAL ACEITO, e não falso positivo — decisão de <quem>, em <data>;
      # medição em `specs/062-servidor-mcp/r3-cowlib-alcance.md`.
      #
      # `ex_mcp 1.5.0` exige `plug_cowboy`, que traz `cowlib 2.20.0` com duas advisories
      # SEM correção upstream (o mantenedor do Cowlib recusou: ninenines/cowlib #152, #166,
      # #169). As duas são CODIFICADORES: `cow_http_struct_hd:escape_string/2` (43966) e o
      # `Cookie:` de cliente em `cow_cookie:cookie/1` (43969).
      #
      # Não alcançáveis aqui, medido com trace de chamadas e controle positivo: o endpoint é
      # servido pelo Bandit (`config/config.exs`, `adapter: Bandit.PhoenixAdapter`), o
      # `ExMCP.HttpPlug` roda sob o Bandit sem tocar em função nenhuma de cowlib/cowboy/ranch,
      # e a aplicação `:ex_mcp` não inicia listener (`:ranch.info() == %{}`).
      #
      # ESTA EXCEÇÃO CAI — e sai daqui no mesmo PR — se qualquer uma destas deixar de valer:
      #   1. o `adapter:` do endpoint deixar de ser `Bandit.PhoenixAdapter` (sem a linha, o
      #      Phoenix volta ao Cowboy EM SILÊNCIO, porque o `plug_cowboy` agora existe);
      #   2. algum listener Cowboy for iniciado: `Plug.Cowboy.http/https`,
      #      `ExMCP.Server.Transport.start_server/4`, ou `transport: :http` num handler da DSL;
      #   3. algum código deste repositório, ou dependência nova, chamar `:cow_*` ou usar `gun`;
      #   4. a `ex_mcp` mudar de versão (fixada em `== 1.5.0`): a medição vale para ela.
      # E sai sozinha quando a `ex_mcp` tornar o Cowboy opcional (anunciado para a 2.0): o
      # `hex.audit` avisa que a entrada ficou obsoleta — foi assim que o H11 apareceu.
      hex: [ignore_advisories: ["EEF-CVE-2026-43966", "EEF-CVE-2026-43969"]]
```

### O que tem de existir ANTES da exceção (cenários para o QA)

A proteção não pode ser a linha do `mix.exs` — mesmo padrão do `decimal_limitado_test.exs`.
As condições 1 e 2 viram teste, senão a exceção sobrevive à mudança que a derruba:

| Condição | Cenário | Asserção |
|---|---|---|
| 1 | a aplicação de teste carregada | `TheBandWeb.Endpoint.config(:adapter) == Bandit.PhoenixAdapter`; prova de falha: tirar a linha de `config/config.exs` e ver reprovar |
| 2 | a aplicação inteira iniciada | `refute` listener: `:ranch.info() == %{}` |
| 2, 3 | guarda estática sobre `lib/` (sem comentários, ver a lição "guarda que lê código reprova a prosa") | `refute` ocorrência de `Plug.Cowboy`, `ExMCP.Server.Transport`, `transport: :http` e `:cow_` |
| 4 | `mix.exs` | versão da `ex_mcp` fixada em `== 1.5.0`, não `~> 1.5` (R3) |

## O que NÃO verifiquei

- **O texto OSV completo da EEF-CVE-2026-43966** — não está na base local do mix_audit;
  trabalhei com o título do Hex e o fonte.
- **HTTP/2 dinamicamente**: o cliente do rascunho (`:httpc`) só fala HTTP/1.1. Para HTTP/2 a
  evidência é estática (Bandit usa `Bandit.HTTP2`/`hpax`; nenhum `:cow_` na pilha).
  **WebSocket/LiveView** também não foi exercitado sob trace; a evidência é estática
  (`websock_adapter` despacha pelo adaptador do `conn`).
- **O The Band real com a ex_mcp**: medi num projeto de rascunho com o mesmo Bandit
  (1.12.5), não no endpoint desta aplicação, nem num **release** (modo embarcado, que carrega
  todos os módulos no boot — carregado não é chamado, e o trace mede chamada).
- **Opções não padrão do `HttpPlug`** (`legacy_http_sse`, OAuth, `subscriptions/listen`) não
  foram exercitadas sob trace; a cobertura delas é o grep `:cow_` → nenhum em `lib/`.
- **`mix deps.audit` no rascunho** não foi rodado.
- **O teste `dependency_advisory_mitigation_test.exs`** citado pela ex_mcp não vem no pacote.
- **As outras oito dependências novas** (R3) — só avaliei o eixo cowlib/cowboy. Isso não
  responde sobre `jose`, `mint_web_socket`, `ex_json_schema`, nem sobre o código de stdio/ACP
  (`System.cmd`/`Port.open`) que entra no release.
- **`mix gates` não foi rodado**: nada mudou no repositório além deste arquivo.
