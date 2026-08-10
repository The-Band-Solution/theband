defmodule Mix.Tasks.Knowledge.Validate do
  @shortdoc "Valida a base de conhecimento YAML"

  @moduledoc """
  Lê `priv/knowledge_base/`, verifica integridade e reporta os problemas.

  Quality gate obrigatório (constituição, princípio VII). Falha com status
  diferente de zero quando encontra problema — YAML inválido não entra no
  repositório.
  """

  use Mix.Task

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.YamlLoader

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.config")
    Application.ensure_all_started(:yaml_elixir)

    root = List.first(args) || YamlLoader.root()

    case KnowledgeBase.load(root) do
      {:ok, artifacts} ->
        Mix.shell().info("base de conhecimento válida — #{length(artifacts)} artefatos")

        artifacts
        |> Enum.frequencies_by(& &1.kind)
        |> Enum.sort()
        |> Enum.each(fn {kind, n} -> Mix.shell().info("  #{kind}: #{n}") end)

      {:error, problems} ->
        Mix.shell().error("#{length(problems)} problema(s):\n")
        Enum.each(problems, &Mix.shell().error("  #{&1}"))
        Mix.raise("base de conhecimento inválida")
    end
  end
end
