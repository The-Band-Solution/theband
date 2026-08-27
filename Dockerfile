# ═══════════════════════════════════════════════════════════════════════════════
# The Band — imagem de produção para VPS
#
# Duas etapas: a de construção tem Elixir, Node e o código-fonte; a de execução tem
# só o release e as bibliotecas de sistema que o BEAM precisa. A imagem final não
# carrega compilador nem fonte, e é o que reduz superfície de ataque e tamanho.
#
# ## O que NÃO pode faltar na etapa final
#
# `priv/` inteiro. A base de conhecimento (724K de YAML) e as consultas GraphQL dos
# conectores vivem lá, e são LIDAS EM TEMPO DE EXECUÇÃO — a aplicação recusa subir
# sem elas, e uma imagem que copia só `_build` sobe e falha no primeiro boot.
#
# ## As versões são fixas de propósito
#
# `elixir:1.20` sem digest seguiria a tag e mudaria debaixo do deploy. A versão do
# Debian da etapa final tem de ser a MESMA da etapa de construção: o BEAM é ligado à
# libc da imagem onde foi compilado, e misturar bookworm com trixie produz erro de
# símbolo no boot que não parece erro de versão.
# ═══════════════════════════════════════════════════════════════════════════════

# Estes três números NÃO são escolha de estilo: a combinação exata tem de existir
# como tag em `hexpm/elixir`. A primeira tentativa usou `29.0` e uma data de Debian
# inventada, e o build reprovou com `not found` — que é o erro que este arquivo
# existe para não deixar chegar ao servidor.
#
# Conferidos no registro em 2026-08-27:
#   curl -s "https://hub.docker.com/v2/repositories/hexpm/elixir/tags/?name=1.20.2-erlang-29"
ARG ELIXIR_VERSION=1.20.2
ARG OTP_VERSION=29.0.3
ARG DEBIAN_VERSION=bookworm-20260713-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ─────────────────────────────────────────── construção ───────────────────────
FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
  && apt-get install -y build-essential git curl \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# As dependências vêm ANTES do código-fonte: elas mudam raramente, e esta camada
# fica em cache enquanto `mix.lock` não muda. Copiar tudo de uma vez recompilaria
# 100 dependências a cada linha alterada no `lib/`.
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# **`compile` ANTES de `assets.deploy`**, e a ordem não é preferência.
#
# `app.css` importa `phoenix-colocated/the_band/colocated.css`, que é gerado pelo
# COMPILADOR do LiveView — não pelo tailwind. E o alias `assets.deploy` deste projeto
# não inclui `compile`: são só `tailwind`, `esbuild` e `phx.digest`.
#
# Na ordem inversa o build morre com `Can't resolve
# 'phoenix-colocated/the_band/colocated.css'`, e o erro não parece de ordem — parece
# de dependência de JavaScript ausente. Medido em 2026-08-27: build reprovou em
# `[builder 13/17]`.
RUN mix compile

# `assets.deploy` roda tailwind e esbuild e depois `phx.digest`, que produz os
# arquivos com hash em `priv/static`. Sem o digest o cache do navegador serve CSS
# velho depois de cada deploy, e o sintoma parece bug de layout.
RUN mix assets.deploy

# `runtime.exs` vem por último: ele é lido no BOOT, e não na compilação. Copiá-lo
# antes não muda nada agora, e invalidaria o cache das camadas acima a cada mudança
# de configuração de execução.
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# ─────────────────────────────────────────── execução ─────────────────────────
FROM ${RUNNER_IMAGE}

# `libstdc++6` e `libncurses5` são do BEAM; `openssl` é de toda conexão TLS,
# inclusive a do Postgres gerenciado; `ca-certificates` é o que faz a chamada ao
# GitHub não falhar com erro de certificado — e esse erro NÃO se parece com falta
# de pacote quando aparece.
RUN apt-get update -y \
  && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# UTF-8 explícito: nomes de pessoa e título de issue vêm com acento, e sob a locale
# `POSIX` do Debian mínimo eles chegam ao log e ao HTML corrompidos.
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

WORKDIR /app

# Usuário sem privilégio. O contêiner não precisa de root para servir HTTP, e rodar
# como root transforma qualquer execução remota de código em execução como root.
RUN chown nobody /app
USER nobody

ENV MIX_ENV="prod"

# SEM isto o endpoint NÃO serve. `runtime.exs` só liga `server: true` quando
# `PHX_SERVER` está definida — é a convenção de release do Phoenix —, e o contêiner
# subiria, ficaria saudável, e não responderia em porta nenhuma. O sintoma é um
# health check que falha sem log de erro.
ENV PHX_SERVER="true"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/the_band ./

COPY --chown=nobody:root rel/entrypoint.sh ./entrypoint.sh

EXPOSE 4000

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/bin/the_band", "start"]
