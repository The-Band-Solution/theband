defmodule Mix.Tasks.Mensagens.Verificar do
  @shortdoc "Reprova mensagem literal fora do catálogo nos ralos de mensagem"

  @moduledoc """
  O gate da feature 047 — contrato em
  `specs/047-mensagens-internacionalizadas/contracts/catalogo-de-mensagens.md`.

  Percorre `lib/the_band_web/**/*.ex` por AST e reprova `put_flash/3` cujo terceiro
  argumento é literal (string, interpolação ou concatenação com literal) fora de
  `gettext/dgettext/ngettext/dngettext`. Aponta `arquivo:linha`, e o veredito é o
  código de saída: 0 limpo, 1 com achados.

  A fronteira é do contrato: HEEx, `Logger`, `raise` e `IO.puts` ficam fora —
  o que o verificador não cobre está enumerado em `pendencias.md`, nunca escondido.

  ## O salto de um nó (v3, 2026-08-30)

  Frase de tela pode nascer numa FUNÇÃO e só então cair no ralo — foi assim que
  a classe escapou três vezes (`humanizar/1`, `primeira_mensagem/1`,
  `ja_e_de_outra/1`). O verificador agora resolve UM salto, no MESMO arquivo:
  função passada como mensagem tem as cláusulas conferidas. Um salto, e não
  fluxo de dados — a fronteira continua declarada e mecânica.
  """

  use Mix.Task

  @raiz "lib/the_band_web"
  @tradutores [:gettext, :dgettext, :ngettext, :dngettext, :pgettext, :dpgettext]

  # A classe "assign de mensagem renderizado" — achada pela aceitação do sprint 024
  # (047/T012, #609): `assign(erro: "…")`/`assign(ok: "…")` exibidos em div escapavam
  # do pente do put_flash, e duas user stories voltaram por isso. As chaves são
  # DECLARADAS aqui porque assign carrega de tudo (page_title, contadores) — vigiar
  # toda string em assign afogaria o gate em falso positivo; vigiar as chaves de
  # mensagem é a fronteira que o contrato registra.
  @chaves_de_mensagem [:erro, :ok, :error, :aviso]

  @impl Mix.Task
  def run(args) do
    raiz = List.first(args) || @raiz

    achados =
      raiz
      |> arquivos()
      |> Enum.flat_map(&achados_do_arquivo/1)
      |> Enum.sort()

    Enum.each(achados, fn {arquivo, linha, ralo} ->
      Mix.shell().error("#{arquivo}:#{linha}: #{ralo} com literal fora do catálogo")
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
        {_ast, diretos} = Macro.prewalk(ast, [], &coletar(&1, &2, arquivo))
        Enum.reverse(diretos) ++ indiretos(ast, arquivo)

      {:error, _} ->
        # Arquivo que não parseia reprova no gate de compilação, não neste.
        []
    end
  end

  # ── O salto de um nó ──────────────────────────────────────────────────────
  # Quais funções DESTE arquivo alimentam ralo de mensagem, e quais delas têm
  # cláusula devolvendo literal. Duas varreduras sobre a mesma árvore: uma acha
  # os nomes que chegam ao ralo, outra confere as definições. Nada atravessa
  # arquivo — resolver módulo alheio seria fluxo de dados, e o contrato o exclui.
  defp indiretos(ast, arquivo) do
    alimentam = nomes_que_alimentam_ralo(ast)

    {_ast, achados} =
      Macro.prewalk(ast, [], fn
        {def_kind, meta, [{nome, _, _args}, corpo]} = node, acc
        when def_kind in [:def, :defp] ->
          if MapSet.member?(alimentam, nome) and corpo_com_literal?(corpo) do
            {node, [{arquivo, meta[:line], :"#{nome}/frase"} | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(achados)
  end

  defp nomes_que_alimentam_ralo(ast) do
    {_ast, nomes} =
      Macro.prewalk(ast, [], fn
        {:put_flash, _, args} = node, acc when is_list(args) ->
          {node, nome_de_funcao(List.last(args)) ++ acc}

        {{:., _, [_mod, :put_flash]}, _, args} = node, acc when is_list(args) ->
          {node, nome_de_funcao(List.last(args)) ++ acc}

        {:assign, _, args} = node, acc when is_list(args) ->
          {node, nomes_em_opcoes(List.last(args)) ++ acc}

        {{:., _, [_mod, :assign]}, _, args} = node, acc when is_list(args) ->
          {node, nomes_em_opcoes(List.last(args)) ++ acc}

        node, acc ->
          {node, acc}
      end)

    MapSet.new(nomes)
  end

  defp nome_de_funcao({nome, _, args}) when is_atom(nome) and is_list(args), do: [nome]
  defp nome_de_funcao(_), do: []

  defp nomes_em_opcoes(opcoes) when is_list(opcoes) do
    if Keyword.keyword?(opcoes) do
      opcoes
      |> Enum.filter(fn {chave, _} -> chave in @chaves_de_mensagem end)
      |> Enum.flat_map(fn {_, valor} -> nome_de_funcao(valor) end)
    else
      []
    end
  end

  defp nomes_em_opcoes(_), do: []

  # `do:` de uma linha e bloco `do ... end` — nas duas formas, o que importa é
  # se ALGUMA expressão devolvida é literal fora do catálogo.
  defp corpo_com_literal?([{:do, corpo}]), do: expressao_com_literal?(corpo)
  defp corpo_com_literal?(_), do: false

  defp expressao_com_literal?({:__block__, _, exprs}),
    do: exprs |> List.last() |> expressao_com_literal?()

  defp expressao_com_literal?({:|>, _, [_esq, dir]}), do: expressao_com_literal?(dir)

  defp expressao_com_literal?({:case, _, [_alvo, [do: clausulas]]}),
    do: Enum.any?(clausulas, fn {:->, _, [_padrao, corpo]} -> expressao_com_literal?(corpo) end)

  defp expressao_com_literal?({:if, _, [_cond, ramos]}) when is_list(ramos),
    do: Enum.any?(ramos, fn {_chave, corpo} -> expressao_com_literal?(corpo) end)

  defp expressao_com_literal?({:||, _, [esq, dir]}),
    do: expressao_com_literal?(esq) or expressao_com_literal?(dir)

  defp expressao_com_literal?(expr), do: literal_de_mensagem?(expr)

  defp coletar({:put_flash, meta, args} = node, achados, arquivo) when is_list(args) do
    {node, acumular(args, meta, achados, arquivo)}
  end

  # A forma qualificada (Phoenix.Controller.put_flash / Phoenix.LiveView.put_flash)
  # tem outra cabeça de AST — e foi por ela que a recusa do plug escapou da
  # primeira varredura (pego pelo teste de idioma, 2026-08-28).
  defp coletar({{:., _, [_mod, :put_flash]}, meta, args} = node, achados, arquivo)
       when is_list(args) do
    {node, acumular(args, meta, achados, arquivo)}
  end

  # assign/2 (pipe) e assign/3: a lista de opções pode vir como último argumento.
  defp coletar({:assign, meta, args} = node, achados, arquivo) when is_list(args) do
    {node, acumular_assign(args, meta, achados, arquivo)}
  end

  defp coletar({{:., _, [_mod, :assign]}, meta, args} = node, achados, arquivo)
       when is_list(args) do
    {node, acumular_assign(args, meta, achados, arquivo)}
  end

  defp coletar(node, achados, _arquivo), do: {node, achados}

  defp acumular_assign(args, meta, achados, arquivo) do
    opcoes = List.last(args)

    if Keyword.keyword?(opcoes) and
         Enum.any?(opcoes, fn {chave, valor} ->
           chave in @chaves_de_mensagem and literal_de_mensagem?(valor)
         end) do
      [{arquivo, meta[:line], :assign} | achados]
    else
      achados
    end
  end

  defp acumular(args, meta, achados, arquivo) do
    if length(args) in [2, 3] and literal_de_mensagem?(List.last(args)) do
      [{arquivo, meta[:line], :put_flash} | achados]
    else
      achados
    end
  end

  # String literal.
  defp literal_de_mensagem?(arg) when is_binary(arg), do: true

  # Interpolação: "... #{x} ..." — vira {:<<>>, _, partes}. Só é MENSAGEM se as
  # partes estáticas tiverem letra: `"#{campo}: #{traduzida}"` é junção de dois
  # valores por pontuação, e reprová-la mandaria traduzir dois-pontos (o padrão
  # largo inventando achado — a lição que o projeto já pagou).
  defp literal_de_mensagem?({:<<>>, _, partes}) do
    partes
    |> Enum.filter(&is_binary/1)
    |> Enum.join()
    |> String.match?(~r/\p{L}/u)
  end

  # Concatenação contendo literal em qualquer lado.
  defp literal_de_mensagem?({:<>, _, [esq, dir]}),
    do: literal_de_mensagem?(esq) or literal_de_mensagem?(dir)

  # Chamada de tradutor aprova; qualquer outra chamada/variável também — o
  # verificador segue ralos, não fluxo de dados (contrato).
  defp literal_de_mensagem?({funcao, _, _}) when funcao in @tradutores, do: false
  defp literal_de_mensagem?(_), do: false
end
