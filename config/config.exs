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
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
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
  queues: [ingestion: 5, transformation: 5],
  plugins: [{Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}]

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
