# Pesquisa — spec 077

Cada item: a pergunta, o que foi medido ou lido, e a decisão.

## R1 — `Plug.RewriteOn` serve para o endereço?

**Não.** `deps/plug/lib/plug/rewrite_on.ex:133-137` pega a primeira linha do cabeçalho e, nela, o
valor mais à **esquerda**, sem conferir quem mandou. Com um Traefik que acrescenta, é o valor que o
cliente escreveu. A 070 (`contracts/rotas-da-plataforma.md`, "Limite por IP") previa usá-lo; esta
spec o substitui pela regra do mais à direita não confiável (`seguranca.md`, L4).

## R2 — Como o Bandit entrega o endereço?

`config/runtime.exs` faz o Bandit escutar em `::`; `deps/bandit/lib/bandit/socket_helpers.ex:52-59`
repassa o par como veio. IPv4 chega mapeado (`::ffff:a.b.c.d`) com `bindv6only = 0`. Decisão:
normalizar antes de qualquer comparação (L2).

## R3 — `:inet.parse_address/1` ou `parse_strict_address/1`?

Medido pelo agente `security` em 2026-10-05: `parse_address` aceita `127.1` e `0x7f.0.0.1` e
descarta zona; `parse_strict_address` recusa os três. Decisão: o estrito, com `String.trim/1` (L12).

## R4 — ETS próprio, `Hammer` ou banco?

ETS próprio, com o padrão de fatias da `ApiRateLimit` (`lib/the_band_web/plugs/api_rate_limit.ex`).
`Hammer` seria dependência nova e não tem a devolução na fatia do incremento; banco escreveria uma
linha por tentativa da campanha. Ver `plan.md`, decisão 1.

## R5 — Os números

10 falhas por 300 s, por origem e por balde, em dez fatias de 30 s (a soma cobre de 270 a 300 s,
mais estrita que a declarada). Proposta inicial aceita pela avaliação; a primeira medida de
falhas legítimas sob NAT virá do estado observado (L1). Teto de tamanho da tabela: 200 000 chaves,
acima do qual a varredura registra. Moram em `access.origin_limit`.

## R6 — Por que a `ConnCase` precisa mudar

`Phoenix.ConnTest.build_conn/0` usa `127.0.0.1`; `recycle/1` preserva o `remote_ip`
(`deps/phoenix/lib/phoenix/test/conn_test.ex:476-483`). Com origem única por `build_conn/0`, cada
requisição nova de teste é um visitante novo, e o limite só aparece onde o teste o pede.

## R7 — A medição #1063

O procedimento é o de `seguranca.md` (*Procedimento seguro da medição #1063*), copiado para o
runbook (§15) e para a tarefa 👤. Ele responde três coisas que mudam a configuração: se o Traefik
sobrescreve ou acrescenta, qual é a sub-rede de onde o socket chega (a lista de proxies), e se há
Cloudflare na frente (um salto ou dois).
