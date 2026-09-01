# Fase 1 — Como validar: e a medida que o HTTP não faz

**Regra desta feature**: um `200` não é evidência. O defeito que ela existe para
evitar produz exatamente um `200` com o socket recusado (L85). Toda validação
abaixo termina no socket.

## Pré-requisitos

- os gates verdes na branch (`mix gates`, com o código de saída lido **dentro**
  do log — L60);
- para as medidas de produção: os dois endereços publicados e o certificado do
  nome novo emitido.

## 1. Os invariantes, sem subir nada

```bash
MIX_ENV=test mix test test/the_band_web/origens_test.exs
```

**Esperado**: todos verdes, e entre eles os casos que reprovam se a ausência
passar a liberar (C2 e C7 do [contrato](contracts/origens-aceitas.md)).

**A injeção que prova o teste** — desligar o acréscimo do host principal, ou
fazer `nil` devolver lista vazia. Se a suíte continuar verde com qualquer uma
delas, o teste não está provando o invariante, e é o teste que precisa mudar.

## 2. A lista em vigor, na aplicação de pé

```bash
set -a; . ./.env; set +a
MIX_ENV=dev mix run -e '
  TheBandWeb.Endpoint.config(:check_origin) |> IO.inspect(label: "origens aceitas")
'
```

**Esperado**: a lista, com o host principal em primeiro lugar. É a conferência de
que a configuração chegou ao endpoint — passo que costuma ser pulado, e é onde
mora o erro de digitação.

## 3. O HTTP, nos dois endereços

```bash
for BASE in https://theband.dev https://theband.5.189.161.85.sslip.io; do
  echo "== $BASE"
  curl -s -o /dev/null -w '  sign-in: %{http_code} em %{time_total}s\n' --max-time 20 "$BASE/sign-in"
  curl -s -o /dev/null -D - --max-time 20 "${BASE/https:/http:}/sign-in" | head -2
done
```

**Esperado**: `200` no HTTPS dos dois, e `301` com `Location:` em HTTPS no HTTP
simples dos dois (FR-002, AS1 da US1).

## 4. **O socket** — a medida que decide

```bash
handshake() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
    -H "Origin: $2" \
    -H 'Upgrade: websocket' -H 'Connection: Upgrade' \
    -H 'Sec-WebSocket-Version: 13' \
    -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
    "$1/live/websocket?vsn=2.0.0"
}

# cada endereço, com a PRÓPRIA origem — os dois têm de ser aceitos (SC-002)
handshake https://theband.dev                      https://theband.dev
handshake https://theband.5.189.161.85.sslip.io    https://theband.5.189.161.85.sslip.io

# e uma origem que ninguém declarou — tem de ser recusada (SC-003)
handshake https://theband.dev                      https://origem-que-ninguem-declarou.example
```

**Como ler o número** — e esta tabela é a parte que se esquece:

| Código | Significa |
|---|---|
| **403** | origem **recusada**. Correto na terceira linha; **defeito** nas duas primeiras |
| **400** | handshake incompleto do `curl` — a origem **passou**. É o resultado esperado nas duas primeiras |
| **101** | conexão aceita e promovida |
| **200** | não é resposta de socket: a requisição foi parar em outro lugar |

**Um `403` na primeira ou na segunda linha é o defeito inteiro desta feature**,
aparecendo. Nenhuma medida de HTTP o encontraria.

## 5. A recusa, no registro

Depois da terceira linha do passo 4, no log da aplicação:

```
Could not check origin for Phoenix.Socket transport.
Origin of the request: https://origem-que-ninguem-declarou.example
```

**Esperado**: presente, nomeando a origem (FR-008). Ausente, o SC-003 não está
atendido — recusar em silêncio é metade do requisito.

## 6. O endereço antigo, durante a transição

```bash
while true; do
  printf '%s %s\n' "$(date +%H:%M:%S)" \
    "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
       https://theband.5.189.161.85.sslip.io/sign-in)"
  sleep 5
done
```

Deixar rodando **antes** de mexer no DNS e parar depois de conferir o nome novo.
**Esperado**: `200` em toda linha (SC-004). Uma linha diferente de 200 é a
interrupção que o critério proíbe, com a hora em que aconteceu.

## 7. Os segredos

```bash
docker history --no-trunc ghcr.io/the-band-solution/theband:latest | grep -ci "token\|secret\|senha\|password" || echo 0
```

**Esperado**: `0` (SC-005). A mesma varredura que a 050 usa — se a configuração
do intermediário tiver exigido credencial, ela ficou no painel, não na imagem.
