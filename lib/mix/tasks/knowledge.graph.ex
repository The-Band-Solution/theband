defmodule Mix.Tasks.Knowledge.Graph do
  @shortdoc "Verifica a direção das dependências entre ontologias"

  @moduledoc """
  A dependência vai do específico para o geral. `EO → SRO`, `SPO → CIRO` e
  `SysSwO → CDRO` são proibidas (AGENTS.md §6, constituição princípio I).

  Se um conceito já existe em ontologia mais geral, ele deve ser reutilizado por
  referência — nunca duplicado.
  """

  use Mix.Task

  alias TheBand.Ontology.YamlLoader
  alias TheBand.Ontology.YamlValidator

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.config")
    Application.ensure_all_started(:yaml_elixir)

    root = List.first(args) || YamlLoader.root()

    case YamlLoader.load_all(root) do
      {:ok, artifacts} ->
        case YamlValidator.dependency_problems(artifacts) do
          [] ->
            modules = Enum.count(artifacts, &(&1.kind == :module))
            Mix.shell().info("dependências entre ontologias íntegras — #{modules} módulos")

          problems ->
            Enum.each(problems, &Mix.shell().error("  #{&1}"))
            Mix.raise("#{length(problems)} dependência(s) na direção errada")
        end

      {:error, problems} ->
        Enum.each(problems, &Mix.shell().error("  #{&1}"))
        Mix.raise("não foi possível ler a base de conhecimento")
    end
  end
end
