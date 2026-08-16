import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :the_band, TheBand.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "the_band_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :the_band, TheBandWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "MbkR9vteR3U/epDrIGuD13uWBM2LjHj/nf5dMJI5AYkZcVcQ5Qpw0JGgxdIpWXjz",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# ---------------------------------------------------------------------------
# Oban em modo de teste — filas, plugins e peer desligados.
#
# ## O que acontecia sem isto
#
# O `Oban.Peer` e o `Oban.Plugins.Cron` sobem processos que consultam o banco por
# conta própria, fora do processo dono da conexão do sandbox. Cada consulta morre
# com `DBConnection.OwnershipError`, o supervisor reinicia, e o ciclo recomeça.
#
# Quando a intensidade de reinício estoura, quem reinicia é o supervisor da
# aplicação — e ele leva junto o `TheBand.Ontology.KnowledgeBase`, que é **dono da
# tabela ETS** da base de conhecimento. A tabela some com o processo, e todo teste
# seguinte falha com
#
#     the table identifier does not refer to an existing ETS table
#
# Medido em 2026-08-14, no PR #306: **197 testes** falharam assim numa execução, e
# a mesma árvore passou na execução do push, quinze segundos antes. É a L56 — a
# cobertura muda o tempo, e o que muda com o tempo é a janela de quem mede.
#
# ## Por que isto não enfraquece a suíte
#
# Nenhum teste depende de o Oban **executar** trabalho. Eles inserem `%Oban.Job{}`
# direto para montar estado, leem `Repo.all(Oban.Job)` para conferir que a coleta
# foi enfileirada, ou chamam `perform/1` na mão. `testing: :manual` mantém o
# `Oban.insert/1` gravando a linha — que é o que essas asserções leem — e desliga
# só quem executa.
# ---------------------------------------------------------------------------
# `testing: :manual` seria o modo documentado, e ele **não** serve aqui: ele faz o Oban
# conferir a versão da migração na subida, e o repositório está em `version: 12` com a
# biblioteca exigindo 14. Essa é dívida separada, com efeito em produção, e não se resolve
# de carona num conserto de CI.
#
# Desligar fila, plugins e peer chega ao mesmo lugar pelo caminho que não mexe em migração.
config :the_band, Oban,
  queues: false,
  plugins: false,
  peer: false

# A segunda borda de I/O da plataforma. Mesma postura da primeira: é o único ponto que o
# teste substitui, e nada abaixo dela é mockado.
config :the_band, :llm_http_client, TheBand.LLMHTTPMock
