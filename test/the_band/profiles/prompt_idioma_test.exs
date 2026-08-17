defmodule TheBand.Profiles.PromptIdiomaTest do
  @moduledoc """
  O perfil sai em inglês, e a regra mora no SCHEMA — issue #402.

  A lição registrada (2026-08-16): regra pedida em texto ao modelo é ignorada; virada
  em estrutura, é obedecida. Aqui a estrutura é a descrição de cada campo de texto
  livre exigindo inglês — e este teste é o que impede alguém de traduzir o schema de
  volta sem perceber o que está desfazendo.
  """
  use ExUnit.Case, async: true

  alias TheBand.Profiles.Prompt

  # Os campos onde o modelo escreve prosa. Os que ficam de fora carregam formato
  # (AAAA-MM, números de tarefa) ou citação (título de tarefa não se traduz).
  @campos_de_prosa [
    ~w(habilidades),
    ~w(resumo),
    ~w(resumo properties forcas),
    ~w(resumo properties evolucao),
    ~w(resumo properties atencao),
    ~w(trajetoria items properties titulo),
    ~w(trajetoria items properties texto),
    ~w(destaques items properties dominio),
    ~w(destaques items properties demonstrou),
    ~w(lacunas items properties forma),
    ~w(lacunas items properties observado),
    ~w(do_time_nao_da_pessoa),
    ~w(alocacao),
    ~w(recomendacoes),
    ~w(nao_alcanca)
  ]

  test "toda descrição de campo de prosa exige inglês" do
    props = Prompt.schema()["schema"]["properties"]

    for caminho <- @campos_de_prosa do
      campo = get_in(props, caminho)

      assert campo,
             "o campo #{Enum.join(caminho, ".")} sumiu do schema — o teste precisa acompanhar"

      assert campo["description"] =~ "English",
             """
             O campo #{Enum.join(caminho, ".")} não exige inglês na descrição.

             A regra do idioma mora no schema porque é onde o modelo obedece — pedida
             só no texto das instruções, ela foi ignorada (lição de 2026-08-16). Um
             perfil em português numa interface em inglês foi o que motivou a #402.
             """
    end
  end

  test "as instruções dizem a regra e as duas exceções" do
    instrucoes = Prompt.instrucoes()

    assert instrucoes =~ "Em inglês",
           "a regra do idioma sumiu das instruções"

    assert instrucoes =~ "citação não se traduz",
           "a exceção do título citado sumiu — sem ela o modelo traduz evidência"
  end
end
