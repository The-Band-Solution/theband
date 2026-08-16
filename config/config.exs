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

# Configure the endpoint
config :the_band, TheBandWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TheBandWeb.ErrorHTML, json: TheBandWeb.ErrorJSON],
    layout: false
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
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

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
  queues: [ingestion: 5, transformation: 5, perfis: 1, rodadas: 1],
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
       {"0 3 1 * *", TheBand.Profiles.MonthlyWorker}
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
import_config "#{config_env()}.exs"
