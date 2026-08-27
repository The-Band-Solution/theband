#!/bin/sh
# ═══════════════════════════════════════════════════════════════════════════════
# Entrypoint do contêiner — issue de implantação em VPS.
#
# `set -e`: qualquer passo que falhe derruba o contêiner. Sem ele, uma migração que
# reprova deixaria a aplicação subir contra um esquema pela metade, servindo telas
# com zero onde deveria haver dado — e zero silencioso é o defeito que este projeto
# persegue em toda parte.
# ═══════════════════════════════════════════════════════════════════════════════
set -e

# As variáveis obrigatórias são conferidas AQUI, antes de qualquer coisa. A ausência
# de `THE_BAND_MASTER_KEY` já é recusada por `TheBand.Application`, mas a mensagem
# chega no meio de um stacktrace de supervisor. Aqui ela chega sozinha, e diz o nome.
for var in DATABASE_URL SECRET_KEY_BASE THE_BAND_MASTER_KEY PHX_HOST; do
  eval valor=\$$var
  if [ -z "$valor" ]; then
    echo "FALTA a variável de ambiente $var — o contêiner não sobe sem ela." >&2
    exit 1
  fi
done

# A migração roda ANTES do servidor, e não dentro da árvore de supervisão: migrar em
# paralelo com a aplicação servindo deixa uma janela em que requisições veem o
# esquema pela metade.
echo "aplicando migrações pendentes…"
/app/bin/the_band eval 'TheBand.Release.migrate()'
echo "migrações aplicadas."

exec "$@"
