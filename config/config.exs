# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :the_band,
  ecto_repos: [TheBand.Repo],
  generators: [timestamp_type: :utc_datetime]

# O log embutido do Ecto fica desligado em todo ambiente — issue #1222. Em `:debug` ele loga os
# parâmetros antes de o tipo cifrar, e o segredo saía em claro. Quem loga as consultas é
# `TheBand.Repo.LogDaConsulta`, que redige os parâmetros das tabelas com campo cifrado.
config :the_band, TheBand.Repo, log: false

# O catálogo de mensagens (feature 047). O padrão é "en" porque o msgid É a frase
# que a tela mostra hoje (research R2) — trocar a plataforma para pt é trocar a
# linha do :gettext quando o catálogo pt fechar, e só ela (FR-005). Ela vive no app
# :gettext porque é a ÚNICA lida em runtime — a do backend é compile-time (medido:
# o teste de idioma reprovou com a config no backend, e passou aqui).
config :gettext, :default_locale, "en"

config :the_band, TheBandWeb.Gettext, allowed_locales: ["en", "pt"]

# Configure the endpoint
config :the_band, TheBandWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TheBandWeb.ErrorHTML, json: TheBandWeb.ErrorJSON],
    # O layout RAIZ, e não `false` — issue #437. Sem ele a página de erro chega sem `<head>`,
    # logo sem folha de estilo: o conteúdo estava certo e a tela saía crua.
    #
    # É o raiz e não o `app`: o `app` depende de `current_tenant` e `current_user`, e numa
    # página de erro esses assigns podem não existir. O raiz depende só de `@inner_content` —
    # conferido — então a página de erro não tem como dar erro por assign faltando.
    layout: {TheBandWeb.Layouts, :root}
  ],
  pubsub_server: TheBand.PubSub,
  live_view: [signing_salt: "G2b/MAn9"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  the_band: [
    args:
      ~w(js/app.js js/theme.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  the_band: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
# OS CAMPOS DE OBSERVABILIDADE — `AGENTS.md` §15, achado H4 de 2026-09-09.
#
# Era só `request_id`, e `Logger.metadata` não era chamado em lugar nenhum de `lib/`.
# Sem `tenant_id` e `user_id`, o log do Phoenix registrava método, caminho e status — e
# **nenhuma linha dizia de quem era a requisição**. Reconstruir um incidente de acesso era
# impossível, e é o que dava severidade ao achado.
#
# Um campo listado aqui e ausente na linha simplesmente não aparece: pôr os três não
# obriga ninguém a preenchê-los, e quem os preenche é `CurrentScope` e a hook do LiveView,
# uma vez por requisição.
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  # `:operator_id` — spec 070, T016, achado O14. O operador da plataforma não é conta de
  # organização e não tem `user_id`: sem a chave aqui, a linha de log de um ato dele sairia sem
  # dizer quem fez, mesmo com `Logger.metadata(operator_id: …)` preenchido.
  metadata: [:request_id, :tenant_id, :user_id, :operator_id]

# Os parâmetros que nunca chegam ao log — spec 070, T016, achado A10. O padrão do Phoenix é só
# `"password"`. O operador manda código de definição, código de guarda, código do segundo fator e
# código de recuperação, e cada um abre a conta do operador. O filtro casa por **trecho** do nome
# do campo: `"token"` cobre `setup_token` e `second_factor_token`, `"code"` cobre
# `recovery_code` e `confirm_code`.
config :phoenix, :filter_parameters, ["password", "token", "secret", "code", "totp"]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Oban — sincronização de fontes, paginação, retries e reprocessamento.
# Não há broker externo: Oban cobre o papel da camada de comunicação interna
# descrita na tese (AGENTS.md §1.1, constituição princípio V).
config :the_band, Oban,
  repo: TheBand.Repo,
  engine: Oban.Engines.Basic,
  # `perfis` com concorrência 1: a geração é sob demanda e cada chamada leva de 25 a 60
  # segundos. Paralelizar gastaria crédito em rajada sem ninguém esperando mais rápido.
  # `rodadas` é fila **própria**, e não uma vaga a mais em `perfis` — feature 027, T003. Uma
  # rodada mensal percorre até 34 pessoas em sequência: de 15 a 35 minutos, medidos. Na fila
  # `perfis`, que tem concorrência 1, ela deixaria toda geração pedida a mão esperando o mês.
  #
  # `manutencao` é fila **própria** para os jobs do `Cron` que mantêm a plataforma — issue #801,
  # achado S1 da avaliação de segurança de 2026-10-01. Eles estavam na `ingestion`, que tem 5
  # vagas, e cada coleta ocupa uma vaga por horas: com cinco coletas simultâneas nenhum job
  # completava, e o verificador da fila (`TheBand.Saude`) dizia "parada" com a fila trabalhando.
  # O healthcheck marcava o contêiner `unhealthy`, e reiniciá-lo mataria as cinco coletas. Numa
  # fila só deles, o `Cron` completa a cada 5 minutos enquanto o Oban estiver vivo, que é
  # exatamente o que o verificador mede.
  #
  # `network_analysis` é fila **própria**, com concorrência 1 — feature 076, T010 (R4; R7 da
  # segurança). Cada cálculo roda 100 grafos aleatórios por rede e janela, seis combinações por
  # organização; na `transformation`, que a coleta usa, ele disputaria vaga com a sincronização.
  # Fila declarada no worker e não configurada aqui fica `available` para sempre
  # (`recompute_promotions.ex:7-9`); `fila_network_analysis_test.exs` guarda a linha.
  queues: [
    ingestion: 5,
    transformation: 5,
    perfis: 1,
    rodadas: 1,
    manutencao: 2,
    network_analysis: 1
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    # Reconcilia execuções presas a cada cinco minutos. É o atraso máximo aceitável entre a
    # coleta morrer e a ferramenta voltar a aceitar coleta nova.
    #
    # E a rodada de perfis, no dia 1 às 03:00 — `FR-001a`. O momento é **um só**, no fuso do
    # servidor: um momento por fuso faria a mesma rodada existir várias vezes, e a proibição
    # de simultaneidade da `FR-003` deixaria de significar.
    {Oban.Plugins.Cron,
     crontab: [
       {"*/5 * * * *", TheBand.Jobs.ReconcileStuckSyncs},
       # O agendador olha ESTADO — qual ferramenta tem intervalo e está vencida —, e por isso
       # uma entrada só serve a todos os tenants. Uma entrada por ferramenta cresceria com o
       # número de organizações e exigiria implantar para mudar o ritmo, que é decisão de quem
       # administra o tenant, não de quem implanta.
       #
       # A cada cinco minutos porque é a resolução do intervalo mais curto que a plataforma
       # aceita (15 min): verificar com menos frequência faria "a cada 15 minutos" significar
       # outra coisa.
       {"*/5 * * * *", TheBand.Jobs.ScheduleDueSyncs},
       {"0 3 1 * *", TheBand.Profiles.MonthlyWorker},
       # 064, T020, decisão P3: as sessões que deixaram de valer há 90 dias saem da tabela.
       # Uma vez por dia basta, porque a retenção é medida em dias.
       {"0 4 * * *", TheBand.Jobs.ApagaSessoesAntigas}
     ]}
  ]

# `Oban.Plugins.Lifeline` NÃO entra, e a razão está medida em
# specs/008-destravar-sync-presa/research.md R1: o resgate dele é
#
#     where([j], j.state == "executing" and j.attempted_at < ^cut)
#
# sem nenhuma verificação de processo vivo. `rescue_after` é uma constante que envelhece com o
# crescimento da coleta — a mais longa medida leva 16 min 25 s e cresce com o número de
# repositórios. No dia em que passar do valor, o plugin resgata coleta VIVA e ela roda duas
# vezes: é a L02, onde 32 registros apareceram no lugar de 16 e o número pareceu plausível.
#
# Trabalho órfão é ENCERRADO pela reconciliação, e a coleta nova recoleta — sem duplicar
# linha, porque a gravação é por chave natural.

# Base de conhecimento — carregada uma vez no boot para ETS (research.md R4).
# Falha de carga é falha de boot: uma aplicação que sobe com o modelo pela
# metade é pior que uma que não sobe.
config :the_band, TheBand.Ontology.KnowledgeBase,
  path: "priv/knowledge_base",
  load_on_boot: true

# Cliente HTTP das integrações. Em teste, o Mox substitui apenas a borda HTTP —
# nunca um módulo de domínio próprio.
config :the_band, :github_http_client, TheBand.Integrations.GitHub.HTTP.Req

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Telemetria da jornada — spec 074, T005 (FR-015). DESLIGADA por padrão: sem exportador, nada
# sai. Quem liga é `config/runtime.exs`, e só com `THE_BAND_OTLP_ENDPOINT` num host permitido.
# Com o padrão do SDK (`opentelemetry_exporter` para `localhost:4318`), a telemetria ficaria
# "ligada" falhando em silêncio — no contêiner, `localhost` é a própria aplicação (S10).
config :opentelemetry, traces_exporter: :none

import_config "#{config_env()}.exs"
