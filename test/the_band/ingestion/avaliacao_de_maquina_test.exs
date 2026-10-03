defmodule TheBand.Ingestion.AvaliacaoDeMaquinaTest do
  @moduledoc """
  A contagem de avaliações de máquina na coleta de mudanças — feature 073, T030.

  A conta apagada na origem (autor nulo) **não** é bot: a rede de revisão a conta como *sem pessoa
  ligada* (decisão de 2026-10-03), e as duas contagens não podem discordar. A classificação é a de
  EO (`Mapper.account_type/1`): `__typename` e sufixo `[bot]`.

  Os nós têm a forma do payload do GitHub que a coleta grava em `raw_payload`.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ingestion.GithubChangeRequests

  defp review(autor), do: %{"id" => "PRR_1", "state" => "APPROVED", "author" => autor}

  test "bot, aplicativo e login com [bot] são máquina; pessoa e conta apagada, não" do
    pagina = [
      review(%{"__typename" => "Bot", "login" => "dependabot"}),
      review(%{"__typename" => "User", "login" => "ana"}),
      review(nil),
      review(%{"__typename" => "User", "login" => "renovate[bot]"}),
      review(%{"__typename" => "App", "login" => "uma-app"})
    ]

    assert Enum.map(pagina, &GithubChangeRequests.avaliacao_de_maquina?/1) ==
             [true, false, false, true, true]

    assert Enum.count(pagina, &GithubChangeRequests.avaliacao_de_maquina?/1) == 3
  end
end
