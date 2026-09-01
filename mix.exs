defmodule TheBand.MixProject do
  use Mix.Project

  def project do
    [
      app: :the_band,
      version: "0.2.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.xml": :test, "coveralls.html": :test],
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      # As Mix tasks de conhecimento chamam Mix.shell/0 e Mix.raise/1; sem :mix
      # no PLT o Dialyzer as reporta como funções inexistentes.
      dialyzer: [plt_add_apps: [:mix, :ex_unit]],
      listeners: [Phoenix.CodeReloader],
      releases: releases()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {TheBand.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  # O release, para implantação em VPS.
  #
  # `include_executables_for: [:unix]` gera `bin/the_band`, que é o que o contêiner
  # executa. `steps: [:assemble]` e nada mais: `:tar` produziria um pacote que ninguém
  # consome — a imagem já é o pacote.
  #
  # **Sem `strip_beams: false`.** Os beams são despidos, e com isso `Code.fetch_docs/1`
  # deixa de funcionar no release. Nada em produção lê doc; o que lê é a base de
  # conhecimento em `priv/`, que vai inteira e é copiada explicitamente no Dockerfile.
  defp releases do
    [
      the_band: [
        include_executables_for: [:unix],
        steps: [:assemble]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Cobertura em formato que ferramenta externa lê. O `mix test --cover` embutido produz
      # HTML para olho humano, e nenhum relatório que o SonarCloud saiba importar — e sem
      # relatório o painel mostraria "0% de cobertura" para 31 mil linhas de Elixir, que é pior
      # que não mostrar nada.
      {:excoveralls, "~> 0.18", only: :test},
      {:phoenix, "~> 1.8.9"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.5.20",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},

      # Feature 001 — decisões registradas em specs/001-github-eo-ingestion/research.md
      # Req fica fixado em ~> 0.7.2 e não >= 0.7: está em 0.x, onde mudança
      # incompatível pode vir em versão menor (R1).
      {:req, "~> 0.7.2"},
      {:oban, "~> 2.23"},
      {:yaml_elixir, "~> 2.12"},
      {:cloak_ecto, "~> 1.3"},
      # Feature 045 — hash de senha (FR-003), justificativa em
      # specs/045-autenticacao-e-acesso/research.md R1: padrão do phx.gen.auth,
      # manutenção ativa, e o custo (~100ms/verificação) é a proteção, não o preço.
      {:bcrypt_elixir, "~> 3.3"},
      {:mox, "~> 1.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      # Segurança de Phoenix — XSS, CSRF, injeção, configuração insegura. Nenhuma ferramenta
      # aqui olhava isso, e esta é uma aplicação multitenant que cifra credencial em repouso.
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      # Dependência com CVE conhecida. Antes disso, só aparecia quando alguém lembrava de
      # rodar `mix hex.audit` à mão — foi assim que a CVE do LiveView apareceu, por acaso.
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind the_band", "esbuild the_band"],
      "assets.deploy": [
        "tailwind the_band --minify",
        "esbuild the_band --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"],
      # `mix gates` é a definição dos nove; este alias existe só para quem procura
      # por "ci" antes de procurar por "gates".
      ci: ["gates"]
    ]
  end
end
