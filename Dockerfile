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
RUN useradd --create-home band && chown -R band /app
USER band

COPY --from=builder --chown=band:band /app/_build/prod/rel/the_band ./
COPY --from=builder --chown=band:band /app/rel/entrypoint.sh /app/entrypoint.sh

EXPOSE 4000
ENV PHX_SERVER=true

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/bin/the_band", "start"]
