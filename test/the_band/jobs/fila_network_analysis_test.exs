defmodule TheBand.Jobs.FilaNetworkAnalysisTest do
  @moduledoc """
  A fila da análise de rede está configurada, com concorrência 1 — feature 076, T010 (R4).

  Fila declarada no worker e não configurada fica `available` para sempre
  (`recompute_promotions.ex:7-9`). Lê a configuração de `:prod` e de `:dev`, porque a de teste
  desliga as filas (`config/test.exs`).

  **Defeito a injetar**: tirar `network_analysis: 1` de `config/config.exs`; o teste reprova.
  """
  use ExUnit.Case, async: true

  for ambiente <- [:prod, :dev] do
    test "em #{ambiente}, a fila network_analysis tem limite 1" do
      filas =
        "config/config.exs"
        |> Config.Reader.read!(env: unquote(ambiente))
        |> get_in([:the_band, Oban, :queues])

      assert is_list(filas) and filas != [], "a configuração não tem filas: nada seria medido"
      assert Keyword.get(filas, :network_analysis) == 1
    end
  end
end
