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
# Os papéis do banco — spec 071 (#1131). A migração roda com o papel DONO do esquema, por uma
# credencial separada, entregue SÓ a esta linha; o processo que serve usa DATABASE_URL, um papel
# sem posse e só com DML, que não consegue desligar as guardas do banco.
#
# A credencial que migra nunca é exportada nem ecoada (nada de `set -x` aqui), e sai do ambiente
# antes do `exec`. O limite, decidido em 2026-10-02 (S5): o HEALTHCHECK e todo `docker exec`
# recebem o ambiente configurado do contêiner, e com ele a credencial. A #1140 trata disso.
#
# Sem DATABASE_MIGRATION_URL, os três estados de FR-008 (TheBand.Papeis.estado_sem_credencial/1):
# migra como hoje se quem serve ainda é dono; sobe sem migrar se não há pendente; NÃO sobe se há.
echo "aplicando migrações pendentes…"
if [ -n "$DATABASE_MIGRATION_URL" ]; then
  # A URL de quem serve é lida ANTES: nas atribuições em prefixo, o sh as faz da esquerda para a
  # direita, e `THE_BAND_URL_QUE_SERVE="$DATABASE_URL"` depois de trocar `DATABASE_URL` leria a
  # credencial que migra (medido no contêiner; a guarda :mesma_credencial recusou).
  url_que_serve="$DATABASE_URL"
  DATABASE_URL="$DATABASE_MIGRATION_URL" THE_BAND_URL_QUE_SERVE="$url_que_serve" \
    /app/bin/the_band eval 'TheBand.Release.migrate()'
  unset url_que_serve
else
  /app/bin/the_band eval 'TheBand.Release.migrar_sem_credencial()'
fi
unset DATABASE_MIGRATION_URL
echo "migrações aplicadas."

# A primeira conta — feature 052. Sem ela, uma instalação nova sobe e ninguém
# consegue entrar: o `seeds.exs` levanta em produção de propósito, e `/accounts`
# pressupõe que já exista alguém administrando.
#
# NÃO derruba o contêiner quando as variáveis faltam, ao contrário das quatro
# conferidas lá em cima. Sem banco, subir significaria servir zero em toda tela;
# sem primeira conta, a plataforma está correta e apenas vazia — e derrubar por
# variável esquecida transformaria um esquecimento em produção fora do ar.
/app/bin/the_band eval 'TheBand.Release.semear_primeira_conta()'

exec "$@"
