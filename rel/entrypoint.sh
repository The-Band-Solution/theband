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
# A4 de `seguranca-1140.md`: o que o root criar (um crash dump da migração, que traz a senha) nasce
# só dele.
umask 077

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

# ─── Os papéis do banco — spec 071 (#1131) e a credencial em arquivo (#1140) ──────────────────────
#
# A migração roda com o papel DONO do esquema; o processo que serve usa DATABASE_URL, um papel sem
# posse e só com DML, que não consegue desligar as guardas do banco.
#
# A credencial que migra chega num ARQUIVO só de root (padrão `/run/secrets/database_migration_url`,
# um File Mount do Dokploy), e não pelo ambiente do contêiner, que todo `docker exec` herda (S5). O
# contêiner começa como root só para lê-lo, e tudo que não precisa de root roda como `band`.
# Desenho e medições: `specs/071-papeis-do-banco/seguranca-1140.md`.

if [ "$(id -u)" != 0 ]; then
  echo "o entrypoint precisa começar como root para ler a credencial que migra (#1140)" >&2
  exit 1
fi

# Uma função só para descer a `band`: sem a variável que migra (o `env -u` vem ANTES do `setpriv`,
# no processo root), sem capacidades, com NoNewPrivs, e com o HOME de `band` (o `setpriv` não o
# troca). Nunca `--reset-env`, que apagaria DATABASE_URL e o resto que o servidor precisa.
como_band() {
  env -u DATABASE_MIGRATION_URL setpriv --reuid=band --regid=band --init-groups \
    --inh-caps=-all --bounding-set=-all --no-new-privs \
    env HOME=/home/band USER=band LOGNAME=band "$@"
}

# A3: a propriedade é "band não abre o arquivo", e não o modo — no Docker Desktop o `chmod` passa
# ao host e band continuava lendo. Por isso a prova é abrir como band; se abrir, corrige e prova de
# novo; se ainda abrir, NÃO sobe. (A sonda cala o erro de leitura, que é o resultado esperado; o
# chown e o chmod, que escrevem, não calam nada.)
band_le() { como_band sh -c 'exec 3<"$1"' _ "$1" 2>/dev/null; }

arquivo="${THE_BAND_MIGRATION_URL_FILE:-/run/secrets/database_migration_url}"
cred=""
if [ -e "$arquivo" ]; then
  if band_le "$arquivo"; then
    chown 0:0 "$arquivo"
    chmod 0400 "$arquivo"
    if band_le "$arquivo"; then
      echo "RECUSADO: $arquivo é legível pelo usuário band e não pôde ser restrito (#1140)" >&2
      exit 1
    fi
    echo "aviso: $arquivo era legível por band; agora é 0400 de root" >&2
  fi
  cred=$(cat "$arquivo")
  if [ -z "$cred" ]; then
    echo "RECUSADO: $arquivo está vazio" >&2
    exit 1
  fi
  if [ -n "$DATABASE_MIGRATION_URL" ]; then
    echo "aviso: arquivo e DATABASE_MIGRATION_URL presentes; vale o arquivo — tire a variável do painel (#1140)" >&2
  fi
elif [ -n "$DATABASE_MIGRATION_URL" ]; then
  # A2: aceito, para a transição, e dito em voz alta. Pela variável, a credencial fica em
  # `docker inspect` e em todo `docker exec`.
  echo "aviso: credencial que migra pela variável de ambiente; S5 (#1140) continua aberto — use o arquivo" >&2
  cred="$DATABASE_MIGRATION_URL"
fi
unset DATABASE_MIGRATION_URL

# Sem credencial, os três estados de FR-008 (TheBand.Papeis.estado_sem_credencial/1): migra como
# hoje se quem serve ainda é dono; sobe sem migrar se não há pendente; NÃO sobe se há.
echo "aplicando migrações pendentes…"
if [ -n "$cred" ]; then
  # A URL de quem serve é lida ANTES: nas atribuições em prefixo, o sh as faz da esquerda para a
  # direita, e `THE_BAND_URL_QUE_SERVE="$DATABASE_URL"` depois de trocar `DATABASE_URL` leria a
  # credencial que migra (medido no contêiner). Como root, porque só o root lê o arquivo; a
  # release é de root e não gravável por band (A5). Sem crash dump (A4).
  url_que_serve="$DATABASE_URL"
  ERL_CRASH_DUMP_SECONDS=0 DATABASE_URL="$cred" THE_BAND_URL_QUE_SERVE="$url_que_serve" \
    /app/bin/the_band eval 'TheBand.Release.migrate()'
  unset url_que_serve
else
  como_band /app/bin/the_band eval 'TheBand.Release.migrar_sem_credencial()'
fi
cred=""
unset cred
echo "migrações aplicadas."

# A primeira conta — feature 052. Sem ela, uma instalação nova sobe e ninguém
# consegue entrar: o `seeds.exs` levanta em produção de propósito, e `/accounts`
# pressupõe que já exista alguém administrando.
#
# NÃO derruba o contêiner quando as variáveis faltam, ao contrário das quatro
# conferidas lá em cima. Sem banco, subir significaria servir zero em toda tela;
# sem primeira conta, a plataforma está correta e apenas vazia — e derrubar por
# variável esquecida transformaria um esquecimento em produção fora do ar.
como_band /app/bin/the_band eval 'TheBand.Release.semear_primeira_conta()'

# O processo que serve é `band`, sem capacidades e com NoNewPrivs (A7).
exec env -u DATABASE_MIGRATION_URL setpriv --reuid=band --regid=band --init-groups \
  --inh-caps=-all --bounding-set=-all --no-new-privs \
  env HOME=/home/band USER=band LOGNAME=band "$@"
