defmodule TheBand.Segredo.PadroesTest do
  @moduledoc """
  Os padrões de segredo em um lugar só — 064/T001.

  O `exemplo_valido` de cada padrão é o material do controle positivo da varredura. Se ele não
  casar o próprio padrão, a varredura sai "limpo" sem enxergar nada. Se casar outro padrão, o
  relatório atribui o achado ao tipo errado.
  """
  use ExUnit.Case, async: true

  alias TheBand.Segredo.Padroes
  alias TheBand.Tenants.User

  test "há pelo menos os três tipos que a plataforma guarda" do
    assert Enum.map(Padroes.todos(), & &1.tipo) ==
             [:token_github, :chave_provedor_de_modelos, :token_de_sessao]
  end

  test "cada exemplo casa o próprio padrão" do
    for p <- Padroes.todos() do
      assert Regex.match?(p.regex, p.exemplo_valido),
             "o exemplo de #{p.nome} não casa o próprio padrão: o controle positivo não enxergaria"
    end
  end

  test "e nenhum exemplo casa outro padrão" do
    for p <- Padroes.todos(), outro <- Padroes.todos(), outro.tipo != p.tipo do
      refute Regex.match?(outro.regex, p.exemplo_valido),
             "o exemplo de #{p.nome} casa também #{outro.nome}"
    end
  end

  test "os padrões com prefixo não casam dentro de um identificador maior" do
    [github | _] = Padroes.todos()
    refute Regex.match?(github.regex, "x" <> github.exemplo_valido)
    refute Regex.match?(github.regex, github.exemplo_valido <> "x")
  end

  test "o token de sessão vale só na coluna dele, e casa o campo inteiro" do
    sessao = Enum.find(Padroes.todos(), &(&1.tipo == :token_de_sessao))

    assert Padroes.vale_em?(sessao, "users", "session_token")
    refute Padroes.vale_em?(sessao, "collected_verifications", "phase")
    # Um trecho de 43 dentro de um texto maior não é o campo: é a forma que gerava 5 926
    # falsos positivos no dump de desenvolvimento.
    refute Regex.match?(sessao.regex, "fase " <> sessao.exemplo_valido)
  end

  test "o valor real que o sistema gera tem a forma que o padrão procura" do
    sessao = Enum.find(Padroes.todos(), &(&1.tipo == :token_de_sessao))
    assert Regex.match?(sessao.regex, User.novo_token())
  end
end
