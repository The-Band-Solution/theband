defmodule Mix.Tasks.Mensagens.LacunasTest do
  @moduledoc """
  FR-006 da 047: lacuna aparece nomeada; catálogo completo relata zero.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mensagens.Lacunas

  @fixtures Path.join(System.tmp_dir!(), "mensagens_lacunas_fixtures")

  setup do
    File.rm_rf!(@fixtures)
    File.mkdir_p!(Path.join(@fixtures, "pt/LC_MESSAGES"))
    on_exit(fn -> File.rm_rf!(@fixtures) end)
    :ok
  end

  test "a lacuna aparece nomeada, e a traduzida não" do
    File.write!(Path.join(@fixtures, "pt/LC_MESSAGES/errors.po"), """
    msgid ""
    msgstr ""
    "Language: pt\\n"

    msgid "Board not found."
    msgstr ""

    msgid "Role not found."
    msgstr "Papel não encontrado."
    """)

    saida = capture_io(fn -> Lacunas.run([@fixtures]) end)

    assert saida =~ "pt: 1 lacunas"
    assert saida =~ "errors: Board not found."
    refute saida =~ "Role not found."
  end

  test "catálogo completo relata zero" do
    File.write!(Path.join(@fixtures, "pt/LC_MESSAGES/errors.po"), """
    msgid ""
    msgstr ""
    "Language: pt\\n"

    msgid "Board not found."
    msgstr "Quadro não encontrado."
    """)

    saida = capture_io(fn -> Lacunas.run([@fixtures]) end)
    assert saida =~ "pt: 0 lacunas"
  end
end
