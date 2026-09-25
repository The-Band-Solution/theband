defmodule TheBand.MCP.FronteiraTest do
  @moduledoc """
  A fronteira do contexto MCP — feature 062, T002 (e T008, que acrescenta o banco a este
  arquivo).

  `lib/the_band/mcp/` monta as respostas, e `lib/the_band_web/` as transporta. Se um módulo
  daqui referenciar `TheBandWeb`, a camada fina sobre a `ex_mcp` deixa de ser fina, e trocar a
  biblioteca volta a ser reescrever, e não adaptar (plan.md, *Structure Decision*).

  **A varredura lê a AST**, sem comentários (o `string_to_quoted` os descarta) e sem
  `@moduledoc`/`@doc`. A prosa que explica a fronteira cita `TheBandWeb`, e uma guarda que lesse
  o texto reprovaria a explicação. Isso já aconteceu duas vezes nesta casa.
  """
  use ExUnit.Case, async: true

  @dir "lib/the_band/mcp"

  test "nenhum módulo de lib/the_band/mcp/ referencia TheBandWeb" do
    arquivos = Path.wildcard("#{@dir}/**/*.ex")

    # Guarda contra a varredura vazia: sem arquivo, "nenhuma referência" não diria nada.
    assert length(arquivos) >= 3, "esperava ao menos os três módulos do T002 em #{@dir}"

    achados =
      for arquivo <- arquivos, modulo <- referencias(File.read!(arquivo), [:TheBandWeb]) do
        "#{arquivo}: #{modulo}"
      end

    assert achados == [], """
    Módulos do contexto MCP referenciam o transporte:

    #{Enum.map_join(achados, "\n", &("  " <> &1))}

    O que é de transporte vive em `lib/the_band_web/`. Aqui ficam só as respostas.
    """
  end

  # T008 — **a fronteira do banco.** As respostas vêm dos contextos, como na API da 061. Um
  # módulo daqui que falasse com o `Repo` tornaria a extração posterior um reescrever, e não um
  # mover (research.md D2), e criaria um segundo caminho até o dado, ao lado do veredito.
  @proibidos_do_banco [[:TheBand, :Repo], [:Ecto, :Query], [:Ecto, :Adapters, :SQL]]

  test "nenhum módulo de lib/the_band/mcp/ fala com o banco direto" do
    arquivos = Path.wildcard("#{@dir}/**/*.ex")
    assert length(arquivos) >= 3, "esperava ao menos os três módulos do T002 em #{@dir}"

    achados =
      for arquivo <- arquivos,
          prefixo <- @proibidos_do_banco,
          modulo <- referencias(File.read!(arquivo), prefixo) do
        "#{arquivo}: #{modulo}"
      end

    assert achados == [], """
    Módulos do contexto MCP falam com o banco direto:

    #{Enum.map_join(achados, "\n", &("  " <> &1))}

    O dado chega pelos contextos (`EO`, `TeamWork`, `Quality`), e nunca pelo `Repo`.
    """
  end

  describe "a varredura mede, e não lê a prosa — o controle positivo" do
    test "acha TheBandWeb em alias, chamada e struct" do
      fonte = """
      defmodule Injetado do
        alias TheBandWeb.Endpoint
        def a, do: TheBandWeb.Router.Helpers.x()
        def b, do: %TheBandWeb.Algo{}
      end
      """

      assert length(referencias(fonte, [:TheBandWeb])) == 3
    end

    test "acha Repo e Ecto.Query em alias, import e chamada" do
      fonte = """
      defmodule Injetado do
        alias TheBand.Repo
        import Ecto.Query
        def a, do: TheBand.Repo.all(from(x in "t"))
      end
      """

      achados = Enum.flat_map(@proibidos_do_banco, &referencias(fonte, &1))
      assert "TheBand.Repo" in achados
      assert "Ecto.Query" in achados
    end

    test "ignora TheBandWeb em comentário, @moduledoc e @doc" do
      fonte = ~S'''
      defmodule SoFala do
        @moduledoc "Nada aqui referencia TheBandWeb."
        # TheBandWeb.Endpoint fica do outro lado.
        @doc "Ver TheBandWeb.Router."
        def ok, do: :ok
      end
      '''

      assert referencias(fonte, [:TheBandWeb]) == []
    end
  end

  # Os aliases do fonte que começam por um dos prefixos, na AST sem comentários e sem docs.
  defp referencias(fonte, prefixo) do
    {:ok, ast} = Code.string_to_quoted(fonte)

    ast =
      Macro.prewalk(ast, fn
        {:@, _, [{attr, _, _}]} when attr in [:moduledoc, :doc, :typedoc] -> :documentacao
        no -> no
      end)

    {_, achados} =
      Macro.prewalk(ast, [], fn
        {:__aliases__, _, partes} = no, acc when is_list(partes) ->
          if List.starts_with?(partes, prefixo),
            do: {no, [Enum.map_join(partes, ".", &to_string/1) | acc]},
            else: {no, acc}

        no, acc ->
          {no, acc}
      end)

    Enum.reverse(achados)
  end
end
