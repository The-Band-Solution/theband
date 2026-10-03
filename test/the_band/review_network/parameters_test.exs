defmodule TheBand.ReviewNetwork.ParametersTest do
  @moduledoc """
  A leitura dos parâmetros da base — feature 073, T013 (FR-008). **Levanta, e nunca devolve valor
  de reserva**, quando falta a regra ou uma chave dela.

  A regra aqui é escrita no teste, na forma da proposta (`proposta-base/rules/`), porque a base
  ainda não a tem (T004). O caso "com a base real" entra quando ela existir.
  """
  use ExUnit.Case, async: true

  alias TheBand.ReviewNetwork.Parameters

  defp regra do
    %{
      "id" => "review.network.parameters",
      "version" => 1,
      "rules" => %{
        "window_days" => %{"values" => %{"allowed" => [30, 90, 180], "default" => 90}},
        "k_values" => %{"values" => %{"k" => [1, 2, 3]}},
        "min_reviews" => %{"values" => %{"min_reviews" => 10}},
        "counted_states" => %{
          "values" => %{"states" => ~w(APPROVED CHANGES_REQUESTED COMMENTED DISMISSED)}
        }
      }
    }
  end

  defp sem(caminho),
    do:
      update_in(regra(), ["rules" | Enum.drop(caminho, -1)], &Map.delete(&1, List.last(caminho)))

  test "a regra completa vira os parâmetros, com a versão na proveniência" do
    assert Parameters.from_rule!(regra()) == %{
             windows: [30, 90, 180],
             default_window: 90,
             ks: [1, 2, 3],
             minimum_sample: 10,
             counted_states: ~w(APPROVED CHANGES_REQUESTED COMMENTED DISMISSED),
             knowledge_versions: %{"review.network.parameters" => 1}
           }
  end

  test "cada chave que falta levanta dizendo qual" do
    for {caminho, texto} <- [
          {["window_days", "values", "allowed"], "window_days.values.allowed ausente"},
          {["window_days", "values", "default"], "window_days.values.default ausente"},
          {["k_values", "values", "k"], "k_values.values.k ausente"},
          {["min_reviews", "values", "min_reviews"], "min_reviews.values.min_reviews ausente"},
          {["counted_states", "values", "states"], "counted_states.values.states ausente"}
        ] do
      assert_raise RuntimeError, ~r/#{Regex.escape(texto)}/, fn ->
        Parameters.from_rule!(sem(caminho))
      end
    end
  end

  test "valores incoerentes levantam" do
    for {caminho, valor} <- [
          {["window_days", "values", "default"], 60},
          {["k_values", "values", "k"], [3, 1]},
          {["min_reviews", "values", "min_reviews"], 0},
          {["window_days", "values", "allowed"], [30, -1]},
          {["counted_states", "values", "states"], []}
        ] do
      assert_raise RuntimeError, ~r/inconsistente/, fn ->
        Parameters.from_rule!(put_in(regra(), ["rules" | caminho], valor))
      end
    end
  end

  test "sem a regra na base, levanta, e não inventa valor" do
    assert_raise RuntimeError, ~r/review.network.parameters ausente/, fn ->
      Parameters.fetch!()
    end
  end
end
