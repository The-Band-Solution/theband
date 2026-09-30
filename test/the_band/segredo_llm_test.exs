defmodule TheBand.SegredoLlmTest do
  @moduledoc """
  A chave do provedor de modelos não aparece no texto de um erro — 064/T006, FR-006.

  O mecanismo é o mesmo de `test/the_band/segredo_test.exs`: a VM só guarda a lista de
  argumentos de uma chamada quando **nenhuma cláusula casou** (`FunctionClauseError`), e é
  essa lista que `Exception.format/3` imprime, e que o executor de tarefas grava em
  `oban_jobs.errors`. Foi assim que um token do GitHub ficou em texto claro por oito dias.

  Aqui o erro é levantado na **borda de verdade**, `LLM.HTTP.Req.verify/2` e `complete/3`,
  com `opts` que não é lista. A chave está entre os argumentos.

  **A reinjeção**: o mesmo caminho, com a chave em binário nu, vaza. Sem ela, "o texto não
  contém a chave" passaria numa implementação que não protege nada.
  """
  use ExUnit.Case, async: true

  alias TheBand.Integrations.LLM.HTTP.Req, as: Borda
  alias TheBand.Segredo

  # A forma de uma chave de provedor: prefixo, e o resto longo o bastante para a varredura.
  @chave "sk-proj-" <> String.duplicate("q", 40) <> "Zx9w"

  defp texto_da_excecao(fun) do
    fun.()
    flunk("a chamada devia ter levantado FunctionClauseError")
  rescue
    e in FunctionClauseError -> Exception.format(:error, e, __STACKTRACE__)
  end

  test "verify/2: o erro formatado não contém a chave, e diz qual credencial era" do
    texto = texto_da_excecao(fn -> Borda.verify(Segredo.novo(@chave), :nao_e_lista) end)

    assert texto =~ "FunctionClauseError", "o teste precisa levantar pelo caminho real"
    refute texto =~ @chave
    assert texto =~ "#Segredo<…Zx9w>", "sem identificar a credencial, ninguém investiga"
  end

  test "complete/3: a chave dentro das opções também não aparece" do
    texto =
      texto_da_excecao(fn ->
        Borda.complete("instruções", "material", {:key, Segredo.novo(@chave)})
      end)

    assert texto =~ "FunctionClauseError"
    refute texto =~ @chave
  end

  test "a reinjeção: o mesmo caminho, com a chave em binário nu, VAZA" do
    # É isto que o `Segredo` impede. Se este teste deixar de vazar, o de cima deixou de
    # provar alguma coisa.
    texto = texto_da_excecao(fn -> Borda.verify(@chave, :nao_e_lista) end)

    assert texto =~ @chave
  end

  test "a borda não aceita chave em binário nu: recusa sem mostrar o valor" do
    erro =
      assert_raise ArgumentError, fn -> Borda.verify(@chave, base_url: "http://127.0.0.1:1") end

    refute Exception.message(erro) =~ @chave
  end
end
