#!/bin/sh
# A saúde da fila para o HEALTHCHECK — issue #801, e #1140 (A1, A2 de `seguranca-1140.md`). O
# HEALTHCHECK roda como root, porque o contêiner começa como root; o `rpc` roda como `band`, e o
# `env -u` vem ANTES do `setpriv`, no processo root, para a variável que migra nunca chegar a um
# processo de `band` (medido: na ordem inversa, ela vazava). A guarda de `rel/env.sh.eex` cobre
# quem tirar o `setpriv` daqui.
exec env -u DATABASE_MIGRATION_URL setpriv --reuid=band --regid=band --init-groups \
  --inh-caps=-all --bounding-set=-all --no-new-privs \
  env HOME=/home/band USER=band LOGNAME=band \
  /app/bin/the_band rpc 'IO.puts(TheBand.Release.saude_da_fila())'
