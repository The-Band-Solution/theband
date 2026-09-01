#!/usr/bin/env bash
#
# Feature 054 — mede um endereço da plataforma, e mede o SOCKET.
#
# Por que existe: um 200 de HTTP pode afirmar o que o socket contradiz. Com o
# `check_origin` errado, a página carrega e nenhuma tela viva funciona — sem
# erro visível, só uma barra de carregamento que não termina (lição L85, e a
# pendência P1 da 050). Nenhuma medida de HTTP encontra isso.
#
# Uso:
#   bash scripts/medir-enderecos.sh https://theband.dev
#
# Sai 0 quando o endereço serve E aceita a própria origem no socket.
# Sai 1 quando qualquer uma das duas coisas falha.

set -u

BASE="${1:-}"
if [ -z "$BASE" ]; then
  echo "uso: $0 https://endereco" >&2
  exit 2
fi

ORIGEM_PROPRIA="$BASE"
ORIGEM_ESTRANHA="https://origem-que-ninguem-declarou.example"
HTTP_SIMPLES="${BASE/https:/http:}"

handshake() {
  # Devolve o código do handshake do socket, com a origem dada em $1.
  curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
    -H "Origin: $1" \
    -H 'Upgrade: websocket' \
    -H 'Connection: Upgrade' \
    -H 'Sec-WebSocket-Version: 13' \
    -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
    "$BASE/live/websocket?vsn=2.0.0"
}

echo "== $BASE"
echo

# ── HTTP ─────────────────────────────────────────────────────────────────────
CODIGO_ENTRADA=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$BASE/sign-in")
TEMPO_ENTRADA=$(curl -s -o /dev/null -w '%{time_total}' --max-time 20 "$BASE/sign-in")
CODIGO_REDIRECT=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$HTTP_SIMPLES/sign-in")

printf '  tela de entrada .......... %s em %ss\n' "$CODIGO_ENTRADA" "$TEMPO_ENTRADA"
printf '  http simples ............. %s (esperado 301 ou 308)\n' "$CODIGO_REDIRECT"

# ── SOCKET ───────────────────────────────────────────────────────────────────
CODIGO_PROPRIA=$(handshake "$ORIGEM_PROPRIA")
CODIGO_ESTRANHA=$(handshake "$ORIGEM_ESTRANHA")

printf '  socket, origem própria ... %s\n' "$CODIGO_PROPRIA"
printf '  socket, origem estranha .. %s\n' "$CODIGO_ESTRANHA"

echo
echo "  como ler o código do socket:"
echo "    403  origem RECUSADA         — certo na estranha, DEFEITO na própria"
echo "    400  handshake incompleto do curl, com a origem ACEITA — é o esperado"
echo "    101  conexão aceita e promovida"
echo "    200  não é resposta de socket: a requisição foi parar em outro lugar"
echo

# ── Veredito ─────────────────────────────────────────────────────────────────
FALHOU=0

if [ "$CODIGO_ENTRADA" != "200" ]; then
  echo "  FALHA: a tela de entrada devolveu $CODIGO_ENTRADA, e não 200"
  FALHOU=1
fi

if [ "$CODIGO_REDIRECT" != "301" ] && [ "$CODIGO_REDIRECT" != "308" ]; then
  echo "  FALHA: o http simples devolveu $CODIGO_REDIRECT, e não um redirecionamento"
  FALHOU=1
fi

if [ "$CODIGO_PROPRIA" = "403" ]; then
  echo "  FALHA: a PRÓPRIA origem foi recusada no socket."
  echo "         É o defeito inteiro da feature 054 aparecendo: declare este"
  echo "         endereço em THE_BAND_ORIGENS_EXTRAS, ou corrija o PHX_HOST."
  FALHOU=1
fi

if [ "$CODIGO_ESTRANHA" != "403" ]; then
  echo "  FALHA: a origem estranha devolveu $CODIGO_ESTRANHA, e não 403."
  echo "         A plataforma está aceitando origem que ninguém declarou (FR-007)."
  FALHOU=1
fi

if [ "$FALHOU" = "0" ]; then
  echo "  OK: serve, redireciona, aceita a própria origem e recusa a estranha."
fi

exit "$FALHOU"
