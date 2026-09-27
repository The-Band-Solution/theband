defmodule TheBand.MCP.AusenciaTest do
  @moduledoc """
  Os três estados da ausência — feature 062, T005, SC-002.

  **SC-002: 0 respostas com `0` onde o estado é *não conferido* ou *recusado*.** O teste
  afirma as duas metades: nos estados de ausência o valor é `nil`, e nunca zero; e no estado
  conferido o zero é aceito, porque ali ele é resposta. Um teste que só proibisse o zero
  passaria com uma implementação que também o apagasse de `checked`.
  """
  use ExUnit.Case, async: true

  alias TheBand.MCP.Ausencia

  test "os três estados se distinguem pelo `state`, sem olhar o valor" do
    estados =
      [
        Ausencia.conferido(3),
        Ausencia.nao_conferido("a coleta de comentários"),
        Ausencia.recusado(:fora_do_alcance)
      ]
      |> Enum.map(& &1.state)

    assert estados == ["checked", "not_checked", "refused"]
  end

  test "conferido com zero é o único caso em que zero é resposta" do
    assert %{state: "checked", value: 0} = Ausencia.conferido(0)

    for ausente <- [Ausencia.nao_conferido("x"), Ausencia.recusado(:fora_do_alcance)] do
      assert ausente.value == nil, "#{ausente.state} saiu com valor #{inspect(ausente.value)}"
      refute ausente.value == 0
    end
  end

  test "não conferido carrega o que falta, e recusado carrega a razão" do
    assert %{missing: "a coleta de comentários"} =
             Ausencia.nao_conferido("a coleta de comentários")

    assert %{reason: "fora_do_alcance"} = Ausencia.recusado(:fora_do_alcance)
    assert %{reason: "fora_do_alcance"} = Ausencia.recusado("fora_do_alcance")
  end

  test "sem o que o estado exige, a construção falha, e não produz um estado mudo" do
    assert_raise FunctionClauseError, fn -> Ausencia.nao_conferido("") end
    assert_raise FunctionClauseError, fn -> Ausencia.nao_conferido(nil) end
    assert_raise FunctionClauseError, fn -> Ausencia.recusado("") end
    assert_raise FunctionClauseError, fn -> Ausencia.recusado(nil) end

    # E a aridade zero não existe: `nao_conferido()` e `recusado()` não compilam.
    refute function_exported?(Ausencia, :nao_conferido, 0)
    refute function_exported?(Ausencia, :recusado, 0)
  end
end
