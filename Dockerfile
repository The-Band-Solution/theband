# ═══════════════════════════════════════════════════════════════════════════════
# A imagem de produção — feature 050, contrato em
# specs/050-em-producao/contracts/pipeline-de-release.md.
#
# Dois estágios, e a MESMA base de SO nos dois (debian bookworm): bcrypt_elixir
# compila NIF no builder, e um runtime de outra família glibc quebraria em
# RUNTIME, não no build — o pior lugar. As versões de Elixir/OTP são as do CI
# (1.20.2 / OTP 29), de propósito: a imagem que vai ao ar é compilada pelo mesmo
# toolchain que os gates aprovaram.
#
# Nenhum segredo entra aqui — nem ARG, nem ENV: tudo chega em runtime pelo painel
# do Dokploy, e o rel/entrypoint.sh recusa subir sem as quatro obrigatórias,
# nomeando a que falta.
# ═══════════════════════════════════════════════════════════════════════════════

# ── Estágio 1: builder ─────────────────────────────────────────────────────────
FROM hexpm/elixir:1.20.2-erlang-29.0.5-debian-bookworm-20260713-slim AS builder

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# Deps primeiro, sozinhas: mudar código de aplicação não invalida o cache desta
# camada — e é ela a mais cara.
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

COPY priv priv
COPY assets assets
COPY lib lib

# O compile vem ANTES do assets.deploy: os assets colocados do Phoenix 1.8
# (phoenix-colocated/*) são extraídos NA compilação — o tailwind os resolve de
# _build, e sem compilar antes o build morre em "Can't resolve colocated.css"
# (medido na primeira tentativa desta imagem).
RUN mix compile
RUN mix assets.deploy

COPY config/runtime.exs config/
COPY rel rel

RUN mix release

# ── Estágio 2: runtime ─────────────────────────────────────────────────────────
FROM debian:bookworm-20260713-slim

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# UTF-8 de verdade: nomes de pessoas e títulos de issues carregam acento, e o
# runtime sem locale os corromperia no log.
RUN sed -i '/pt_BR.UTF-8/s/^# //' /etc/locale.gen && \
    sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

WORKDIR /app
# O contêiner COMEÇA como root — #1140, `specs/071-papeis-do-banco/seguranca-1140.md`. É a
# regressão CIS 4.1 declarada (A7): o entrypoint lê a credencial que migra num arquivo só de root,
# migra, e troca para `band` com `setpriv` antes do `exec`. O processo que serve é `band`, sem
# capacidade nenhuma e com `NoNewPrivs`.
#
# `/app` inteiro é de root e não gravável por `band` (A5): o root executa a release no `eval` da
# migração, e um `/app` gravável por `band` deixaria quem executa código como `band` alterar o
# que o root roda no próximo start — uma escalada que hoje não existe. Nenhum diretório de `band`
# dentro de `/app`: um `tmp` gravável seria ataque de link simbólico contra o `eval` root.
RUN useradd --create-home band
USER root

COPY --from=builder --chown=root:root /app/_build/prod/rel/the_band ./
COPY --from=builder --chown=root:root --chmod=0755 /app/rel/entrypoint.sh /app/entrypoint.sh
COPY --from=builder --chown=root:root --chmod=0755 /app/rel/saude.sh /app/bin/saude
# #1162 (B1): o cookie gravado na imagem era o mesmo em todo contêiner da versão. Ele sai, e o
# entrypoint gera um a cada start; sem o arquivo, a release recusa, em vez de voltar a este.
RUN chown -R root:root /app && chmod -R go-w /app && rm /app/releases/COOKIE

EXPOSE 4000
ENV PHX_SERVER=true

# A FILA ANDA? — issue #801, contrato em docs/producao/saude-da-fila.md.
#
# Em 2026-09-04 o Oban parou por quatro dias com a aplicação respondendo 200, e o guarda que
# deveria perceber é um job do próprio Oban. Este verificador fica fora dele: o `rpc` executa
# `TheBand.Release.saude_da_fila/0` dentro do nó que está servindo, pelo cookie da release, sem
# porta nova e sem pacote novo na imagem (decisão de 2026-09-30, contra instalar `curl`).
#
# A função devolve "ok" ou "parada" e nunca derruba o nó; quem decide é o `grep`. O limiar da
# fila é 15 minutos, e por isso o intervalo é de 1 minuto, com 3 falhas seguidas antes de
# `unhealthy`. O `start-period` cobre as migrações do entrypoint e o primeiro ciclo do Cron.
#
# Desde a #1140, pelo `/app/bin/saude`, que roda o `rpc` como `band`: o HEALTHCHECK é root, e um
# `rpc` root seria um nó root conectado ao nó de `band` (A1).
HEALTHCHECK --interval=60s --timeout=20s --start-period=300s --retries=3 \
  CMD /app/bin/saude | grep -qx ok || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/bin/the_band", "start"]
