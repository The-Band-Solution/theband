defmodule TheBand.ReviewNetwork.ExposicaoTest do
  @moduledoc """
  A rede de revisão não sai pela API pública, pela MCP, nem é enfileirada pela camada web —
  feature 073, T027 (FR-020, R8) e a metade de T020 que não espera a base (decisão de 2026-10-03
  sobre R6: nenhuma tela pede cálculo).

  Lê o registro de rotas, o de ferramentas e o código da camada web. O que se prova é que o
  segundo consumidor não nasce lendo a tabela: exposição futura é spec própria, e passa por
  `ReviewNetwork.read/4`.

  O código é lido **sem comentários**, para que uma frase que explique a proibição não reprove o
  teste (memória *guarda que lê código reprova a prosa*).
  """
  use ExUnit.Case, async: true

  alias TheBand.MCP.Ferramentas

  @proibido ~r/review[_-]?network|ReviewNetwork/i

  test "nenhuma rota de /api fala da rede de revisão" do
    rotas =
      for r <- Phoenix.Router.routes(TheBandWeb.Router),
          String.starts_with?(r.path, "/api"),
          do: r

    assert rotas != [], "o teste precisa ver rotas de API para provar alguma coisa"
    refute Enum.any?(rotas, &(&1.path =~ @proibido or inspect(&1.plug) =~ @proibido))
  end

  test "nenhuma ferramenta MCP fala da rede de revisão" do
    ferramentas = Ferramentas.listar()

    assert [_ | _] = ferramentas
    refute Enum.any?(ferramentas, &(&1.nome =~ @proibido or inspect(&1.modulo) =~ @proibido))
  end

  test "a camada web não enfileira o cálculo" do
    arquivos = Path.wildcard("lib/the_band_web/**/*.{ex,heex}")
    assert length(arquivos) > 50

    culpados =
      for arquivo <- arquivos,
          codigo = arquivo |> File.read!() |> sem_comentarios(),
          codigo =~ "ComputeReviewNetwork",
          do: arquivo

    assert culpados == []
  end

  defp sem_comentarios(codigo) do
    codigo
    |> String.split("\n")
    |> Enum.reject(&(String.trim_leading(&1) |> String.starts_with?("#")))
    |> Enum.join("\n")
  end
end
