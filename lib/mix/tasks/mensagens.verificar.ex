defmodule Mix.Tasks.Mensagens.Verificar do
  @shortdoc "Reprova mensagem literal fora do catálogo nos ralos de mensagem"

  @moduledoc """
  O gate da feature 047 — contrato em
  `specs/047-mensagens-internacionalizadas/contracts/catalogo-de-mensagens.md`.

  Percorre `lib/the_band_web/**/*.ex` por AST e reprova `put_flash/3` cujo terceiro
  argumento é literal (string, interpolação ou concatenação com literal) fora de
  `gettext/dgettext/ngettext/dngettext`. Aponta `arquivo:linha`, e o veredito é o
  código de saída: 0 limpo, 1 com achados.

  A fronteira é do contrato: HEEx, `Logger`, `raise` e `IO.puts` ficam fora do v1 —
  o que o verificador não cobre está enumerado em `pendencias.md`, nunca escondido.
  """

  use Mix.Task

  @raiz "lib/the_band_web"
  @tradutores [:gettext, :dgettext, :ngettext, :dngettext, :pgettext, :dpgettext]

  @impl Mix.Task
  def run(args) do
    raiz = List.first(args) || @raiz

    achados =
      raiz
      |> arquivos()
      |> Enum.flat_map(&achados_do_arquivo/1)
      |> Enum.sort()

    Enum.each(achados, fn {arquivo, linha} ->
      Mix.shell().error("#{arquivo}:#{linha}: put_flash com literal fora do catálogo")
    end)

    case achados do
      [] ->
        Mix.shell().info("mensagens no catálogo: nenhum literal nos ralos.")

      _ ->
        Mix.raise("mensagens.verificar reprovou: #{length(achados)} literais fora do catálogo")
    end
  end

  defp arquivos(raiz) do
    raiz
    |> Path.join("**/*.ex")
    |> Path.wildcard()
  end

  defp achados_do_arquivo(arquivo) do
    # columns/token_metadata não são necessários: a linha basta para apontar.
    case arquivo |> File.read!() |> Code.string_to_quoted(file: arquivo) do
      {:ok, ast} ->
        {_ast, achados} = Macro.prewalk(ast, [], &coletar(&1, &2, arquivo))
        Enum.reverse(achados)

      {:error, _} ->
        # Arquivo que não parseia reprova no gate de compilação, não neste.
        []
    end
  end

  defp coletar({:put_flash, meta, args} = node, achados, arquivo) when is_list(args) do
    mensagem = List.last(args)

    if length(args) in [2, 3] and literal_de_mensagem?(mensagem) do
      {node, [{arquivo, meta[:line]} | achados]}
    else
      {node, achados}
    end
  end

  defp coletar(node, achados, _arquivo), do: {node, achados}

  # String literal.
  defp literal_de_mensagem?(arg) when is_binary(arg), do: true

  # Interpolação: "... #{x} ..." — vira {:<<>>, _, partes}.
  defp literal_de_mensagem?({:<<>>, _, _}), do: true

  # Concatenação contendo literal em qualquer lado.
  defp literal_de_mensagem?({:<>, _, [esq, dir]}),
    do: literal_de_mensagem?(esq) or literal_de_mensagem?(dir)

  # Chamada de tradutor aprova; qualquer outra chamada/variável também — o
  # verificador segue ralos, não fluxo de dados (contrato).
  defp literal_de_mensagem?({funcao, _, _}) when funcao in @tradutores, do: false
  defp literal_de_mensagem?(_), do: false
end
