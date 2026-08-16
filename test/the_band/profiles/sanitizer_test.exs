defmodule TheBand.Profiles.SanitizerTest do
  @moduledoc """
  A limpeza do resumo — feature 026, T007.

  **Todo texto aqui é real.** Saiu do provedor nas rodadas de validação de 2026-08-15, e cada
  caso é um defeito que aconteceu — inclusive os dois que a primeira versão da limpeza
  produziu ao consertar o primeiro.
  """
  use ExUnit.Case, async: true

  alias TheBand.Profiles.Sanitizer

  test "tira o grupo de citações entre parênteses" do
    texto = """
    ## AndreCoelhoS

    Nas tarefas de autoria própria aparecem instrumentação e ajustes de coleta (#181, #349, #61, #102).

    ## O trabalho

    Aqui a citação fica (#403, #409).
    """

    {limpo, removidas} = Sanitizer.clean_summary(texto)

    assert removidas == 1
    refute limpo =~ "#181"

    assert limpo =~ "#403",
           """
           A limpeza passou do resumo.

           As seções seguintes existem justamente para carregar a evidência; tirá-la de lá
           deixaria o texto inteiro sem lastro.
           """
  end

  test "tira a enumeração solta, junto do conectivo que a apresenta" do
    texto = """
    ## AndreCoelhoS

    Há rotina de provisionar infraestrutura, com VMs, DNS e deploys, como #458, #459 e #449.

    ## O trabalho
    """

    {limpo, removidas} = Sanitizer.clean_summary(texto)

    assert removidas >= 1
    refute limpo =~ "#458"

    refute limpo =~ ~r/,\s*como\s*\./,
           """
           Sobrou frase terminando em conjunção: "… e deploys, como."

           Foi exatamente o que a primeira versão da limpeza produziu. Tirar a citação e
           deixar o conectivo troca um defeito por outro.
           """
  end

  test "não deixa parêntese começando com espaço" do
    texto = """
    ## AndreCoelhoS

    O texto de lá diz mais sobre a distribuição do registro (#199, no resumo do período 3).

    ## O trabalho
    """

    {limpo, _} = Sanitizer.clean_summary(texto)

    refute limpo =~ "( ",
           """
           Sobrou "( no resumo do período 3)".

           A citação saiu de dentro do parêntese e o resto ficou, com o espaço na frente.
           """
  end

  test "o título não conta como subtítulo" do
    texto = """
    ## AndreCoelhoS

    Um resumo com citação (#199).

    ## O trabalho

    Outra (#403).
    """

    {limpo, removidas} = Sanitizer.clean_summary(texto)

    assert removidas == 1,
           """
           A limpeza não achou o resumo.

           O título é ele próprio um `##`. Cortar na primeira ocorrência deixa o resumo vazio
           e a limpeza sem efeito — **sem erro**, que é o pior jeito de não funcionar.
           """

    refute limpo =~ "#199"
    assert limpo =~ "#403"
  end

  test "texto sem subtítulo algum é devolvido inteiro" do
    assert {"linha só", 0} = Sanitizer.clean_summary("linha só")
  end
end
