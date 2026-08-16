defmodule TheBand.Profiles.SanitizerTest do
  @moduledoc """
  A limpeza dos três campos do resumo — feature 026, T007.

  ## O que a saída estruturada consertou, e por que este arquivo encolheu

  A versão anterior operava sobre **prosa**, e tinha de adivinhar onde o resumo terminava
  procurando o primeiro subtítulo. Metade dos casos aqui eram defeitos dessa adivinhação:
  o título contado como subtítulo, o conectivo órfão, o parêntese pela metade.

  Em 2026-08-16 a adivinhação falhou de vez — o modelo respondeu sem subtítulo algum, a
  limpeza tratou os 6651 caracteres como resumo e apagou **dezenove** citações, a evidência
  inteira, em silêncio.

  Com o schema, os três campos são endereçáveis. Os casos que sobraram são sobre o texto,
  e não sobre a estrutura, porque a estrutura deixou de ser adivinhada.
  """
  use ExUnit.Case, async: true

  alias TheBand.Profiles.Sanitizer

  defp com_resumo(forcas, evolucao \\ "sem citação", atencao \\ "sem citação") do
    %{
      "habilidades" => ["observabilidade"],
      "resumo" => %{"forcas" => forcas, "evolucao" => evolucao, "atencao" => atencao},
      "destaques" => [%{"dominio" => "observabilidade", "evidencia" => [199, 200]}]
    }
  end

  test "tira o grupo de citações entre parênteses" do
    {limpo, removidas} =
      Sanitizer.clean_summary(com_resumo("Instrumentou a coleta (#181, #349, #61)."))

    assert removidas == 1
    assert limpo["resumo"]["forcas"] == "Instrumentou a coleta."
  end

  test "não toca na evidência dos destaques" do
    {limpo, _} = Sanitizer.clean_summary(com_resumo("Instrumentou (#181)."))

    assert limpo["destaques"] == [%{"dominio" => "observabilidade", "evidencia" => [199, 200]}],
           """
           A limpeza passou do resumo.

           `destaques` e `lacunas` têm campo próprio para os números; é lá que a evidência
           mora, e tirá-la deixaria o texto sem lastro. Na versão que operava sobre prosa
           isto era um risco constante — aqui é impossível por construção, e o teste existe
           para que continue sendo.
           """
  end

  test "tira a enumeração solta, junto do conectivo que a apresenta" do
    {limpo, removidas} =
      Sanitizer.clean_summary(com_resumo("Provisionou DNS e deploys, como #458, #459 e #449."))

    assert removidas >= 1
    refute limpo["resumo"]["forcas"] =~ "#458"

    refute limpo["resumo"]["forcas"] =~ ~r/,\s*como\s*\./,
           """
           Sobrou frase terminando em conjunção: "… e deploys, como."

           Foi o que a primeira versão da limpeza produziu. Tirar a citação e deixar o
           conectivo troca um defeito por outro.
           """
  end

  test "não deixa parêntese começando com espaço" do
    {limpo, _} =
      Sanitizer.clean_summary(
        com_resumo("O registro recente (#199, no período 3) é de terceiros.")
      )

    refute limpo["resumo"]["forcas"] =~ "( ",
           "a citação saiu de dentro do parêntese e o resto ficou, com o espaço na frente"
  end

  test "limpa os três campos, e conta o total" do
    {limpo, removidas} =
      Sanitizer.clean_summary(com_resumo("A (#1).", "B (#2).", "C (#3)."))

    assert removidas == 3
    assert limpo["resumo"]["forcas"] == "A."
    assert limpo["resumo"]["evolucao"] == "B."
    assert limpo["resumo"]["atencao"] == "C."
  end

  test "resumo ausente não é consertado em silêncio" do
    conteudo = %{"habilidades" => ["x"]}
    assert {^conteudo, 0} = Sanitizer.clean_summary(conteudo)
  end
end
