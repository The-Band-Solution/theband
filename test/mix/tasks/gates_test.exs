defmodule Mix.Tasks.GatesTest do
  @moduledoc """
  `mix gates`, gate 17 ("validadores concordam") — issue #1224.

  O gate copia a base para um diretório temporário. Com nome fixo, dois worktrees rodando
  `mix gates` ao mesmo tempo usavam a mesma cópia, e o gate reprovava sem defeito na base.
  """
  use ExUnit.Case, async: true

  alias Mix.Tasks.Gates

  test "duas chamadas para o mesmo caso devolvem diretórios distintos, ambos no tmp do sistema" do
    primeiro = Gates.copy_dir(:integra)
    segundo = Gates.copy_dir(:integra)

    assert primeiro != segundo

    tmp = Path.expand(System.tmp_dir!())

    for caminho <- [primeiro, segundo] do
      assert Path.dirname(Path.expand(caminho)) == tmp
    end
  end

  test "o diretório leva o pid do SO, para separar execuções de worktrees diferentes" do
    assert Gates.copy_dir(:com_segredo) =~ "-#{System.pid()}-"
  end
end
