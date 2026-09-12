defmodule TheBand.SegredoTest do
  @moduledoc """
  O que este arquivo prova é uma coisa só: **o valor não aparece**.

  O defeito que originou o tipo foi medido, não suposto — um token do GitHub em texto claro
  dentro de `oban_jobs.errors`, de 2026-09-04 a 2026-09-12. O mecanismo era a lista de
  argumentos do quadro de pilha, e é por isso que o teste central aqui não olha um log
  nosso: ele levanta uma exceção de verdade e lê o texto que `Exception.format/3` produz,
  que é exatamente o que o executor de tarefas grava.
  """

  use ExUnit.Case, async: true

  alias TheBand.Segredo

  # Um valor com a MESMA forma do token que vazou: 40 caracteres, alfanumérico. A forma
  # importa porque é ela que a varredura do banco procura.
  @valor "ghp_" <> String.duplicate("z", 32) <> "omAX"

  describe "a recusa a virar texto" do
    test "inspect mostra a marca, nunca o valor" do
      texto = inspect(Segredo.novo(@valor))

      refute texto =~ @valor
      assert texto == "#Segredo<…omAX>"
    end

    test "inspect dentro de estrutura aninhada também não vaza" do
      # `inspect` desce em listas, mapas e tuplas. Se a marca só valesse no topo, um
      # `ctx` inteiro impresso num log continuaria vazando.
      ctx = %{tool: %{instance_url: "https://github.com"}, token: Segredo.novo(@valor)}

      texto = inspect(ctx, limit: :infinity, printable_limit: :infinity)

      refute texto =~ @valor
      assert texto =~ "#Segredo<…omAX>"
    end

    test "interpolação levanta em vez de vazar" do
      segredo = Segredo.novo(@valor)

      # `String.Chars` não é implementado DE PROPÓSITO. Devolver uma marca aqui seria pior:
      # a requisição sairia com `Bearer #Segredo<…>` e o 401 não se ligaria à causa.
      assert_raise Protocol.UndefinedError, fn -> "Bearer #{segredo}" end
    end

    test "não serializa para JSON — não dá para guardar nos argumentos de um job" do
      assert_raise Protocol.UndefinedError, fn ->
        Jason.encode!(%{token: Segredo.novo(@valor)})
      end
    end
  end

  describe "o vazamento medido: a lista de argumentos do quadro de pilha" do
    # ESTA é a forma do defeito, e descobri-la custou um teste que falhou primeiro.
    #
    # Um `raise` no corpo da função NÃO põe os argumentos no quadro de pilha — o primeiro
    # teste que escrevi usava `raise` e não reproduzia nada. A VM só captura a lista de
    # argumentos quando o erro nasce da própria chamada: nenhuma cláusula casou. Aí
    # `Exception.format/3` imprime os argumentos um a um, e é exatamente a forma que está
    # gravada em `oban_jobs.errors`:
    #
    #     graphql("https://github.com", "<40 caracteres>", "# As linhas de ...")
    #
    # Por isso a cláusula abaixo tem guarda: chamá-la com uma query binária levanta
    # `FunctionClauseError`, que é o caminho real.
    defp chamada_que_so_casa_atom(url, token, query) when is_atom(query),
      do: {url, token, query}

    test "o texto da exceção formatada NÃO contém o segredo" do
      texto = texto_da_excecao(Segredo.novo(@valor))

      assert texto =~ "FunctionClauseError", "o teste precisa levantar pelo caminho real"
      refute texto =~ @valor
    end

    test "e o texto ainda permite dizer QUAL credencial falhou" do
      # FR-007 da spec 064: identificar sem revelar. Sem isto, a correção trocaria um
      # vazamento por um erro que ninguém consegue investigar.
      assert texto_da_excecao(Segredo.novo(@valor)) =~ "#Segredo<…omAX>"
    end

    test "o mesmo caminho com binário NU vaza — é o defeito reinjetado" do
      # Este teste é o que dá sentido aos dois acima. Sem ele, eles passariam também numa
      # implementação que não protege nada, e eu não saberia. Ele reproduz o vazamento de
      # 2026-09-04 em miniatura: mesmo erro, mesma formatação, segredo legível.
      assert texto_da_excecao(@valor) =~ @valor
    end

    defp texto_da_excecao(token) do
      chamada_que_so_casa_atom("https://github.com", token, "query { viewer { login } }")
    catch
      _kind, erro -> Exception.format(:error, erro, __STACKTRACE__)
    end
  end

  describe "a recusa não pode vazar o que ela recusa" do
    # Esta é a fronteira do módulo, e é onde o defeito quase voltou.
    #
    # Sem cláusula de recusa, `expor/1` chamado com um binário nu levantaria
    # `FunctionClauseError` — o MESMO erro que põe a lista de argumentos no quadro de pilha.
    # O módulo escrito para impedir que um segredo vire texto o faria virar texto, na sua
    # própria porta.

    test "expor/1 com binário nu recusa sem mostrar o valor" do
      texto = texto_da_recusa(fn -> Segredo.expor(@valor) end)

      refute texto =~ @valor
      assert texto =~ "binário de 40 bytes"
      refute texto =~ "FunctionClauseError", "a recusa tem de vir de raise, não de cláusula"
    end

    test "novo/1 com algo que não é binário recusa sem mostrar o valor" do
      texto = texto_da_recusa(fn -> Segredo.novo(String.to_charlist(@valor)) end)

      refute texto =~ @valor
      assert texto =~ "lista de 40 itens"
    end

    test "ultimos_quatro/1 idem" do
      assert texto_da_recusa(fn -> Segredo.ultimos_quatro(@valor) end) =~ "binário de 40 bytes"
    end

    test "a recusa DIZ qual função foi chamada — senão não dá para depurar" do
      assert texto_da_recusa(fn -> Segredo.expor(@valor) end) =~ "expor/1"
    end

    defp texto_da_recusa(fun) do
      fun.()
    catch
      kind, erro -> Exception.format(kind, erro, __STACKTRACE__)
    end
  end

  describe "ultimos_quatro" do
    test "devolve os quatro finais" do
      assert Segredo.ultimos_quatro(Segredo.novo(@valor)) == "omAX"
    end

    test "segredo curto não é revelado inteiro a pretexto de mostrar o fim" do
      assert Segredo.ultimos_quatro(Segredo.novo("ab")) == "…"
      refute inspect(Segredo.novo("ab")) =~ "ab"
    end
  end

  describe "novo/1 e expor/1" do
    test "expor devolve o valor original" do
      assert Segredo.expor(Segredo.novo(@valor)) == @valor
    end

    test "embrulhar duas vezes não aninha" do
      # Uma borda chamada duas vezes não pode produzir um valor cujo `expor/1` devolva
      # uma struct em vez do binário — isso chegaria como `Bearer %TheBand.Segredo{...}`.
      duas = Segredo.novo(Segredo.novo(@valor))

      assert Segredo.expor(duas) == @valor
    end
  end
end
