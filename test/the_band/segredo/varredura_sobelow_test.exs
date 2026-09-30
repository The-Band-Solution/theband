defmodule TheBand.Segredo.VarreduraSobelowTest do
  @moduledoc """
  A exceção do `sobelow` na varredura vale para UMA função — 064, decisão de 2026-09-28.

  `@sobelow_skip ["Traversal.FileModule"]` em `Varredura.dump/2` é exceção num gate de
  segurança. Ela só se justifica porque o caminho vem de quem opera, pela linha de comando. Se
  a anotação aparecer em outra função, a justificativa não foi feita para ela, e este teste
  reprova.

  Lê o código **sem os comentários**: o motivo escrito ao lado cita a anotação, e contar a prosa
  seria medir a palavra, e não o controle.
  """
  use ExUnit.Case, async: true

  @fonte "lib/the_band/segredo/varredura.ex"

  defp codigo do
    @fonte
    |> File.read!()
    |> String.split("\n")
    |> Enum.reject(&(String.trim_leading(&1) |> String.starts_with?("#")))
  end

  test "a anotação aparece uma vez só" do
    assert Enum.count(codigo(), &String.contains?(&1, "@sobelow_skip [")) == 1
  end

  test "e é a função dump/2 que ela anota" do
    linhas = codigo()
    i = Enum.find_index(linhas, &String.contains?(&1, "@sobelow_skip ["))

    assert linhas |> Enum.at(i + 1) |> String.trim_leading() |> String.starts_with?("def dump("),
           "a exceção do sobelow passou a anotar outra função"
  end
end
