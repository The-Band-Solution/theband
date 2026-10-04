defmodule TheBand.ReviewNetwork.ParametersTest do
  @moduledoc """
  A leitura dos parâmetros da base — feature 073, T013 (FR-008, FR-011). **Levanta, e nunca
  devolve valor de reserva**, quando falta uma regra, uma chave ou a versão.

  Os casos de falta usam regras escritas no teste, na forma da base; o primeiro caso lê a base
  real, para que o nome de uma chave trocado lá apareça aqui.
  """
  use ExUnit.Case, async: true

  alias TheBand.ReviewNetwork.Parameters

  defp parametros do
    %{
      "id" => "review.network.parameters",
      "version" => 1,
      "rules" => %{
        "window_days" => %{"values" => %{"allowed" => [30, 90, 180], "default" => 90}},
        "k_values" => %{"values" => %{"k" => [1, 2, 3]}},
        "min_reviews" => %{"values" => %{"min_reviews" => 10}}
      }
    }
  end

  defp aresta do
    %{
      "id" => "review.network.edge",
      "version" => 1,
      "rules" => %{
        "counted_states" => %{
          "values" => %{"states" => ~w(APPROVED CHANGES_REQUESTED COMMENTED DISMISSED)}
        },
        "exclusions" => %{
          "values" => %{
            "order" => ~w(bot_or_app organization_account unlinked_person self_review)
          }
        }
      }
    }
  end

  defp medidas, do: %{"review.network.reviews.count" => %{"version" => 2}}

  defp sem(regra, caminho),
    do: update_in(regra, ["rules" | Enum.drop(caminho, -1)], &Map.delete(&1, List.last(caminho)))

  test "a base real dá os parâmetros, e a proveniência leva as duas regras e as nove medidas" do
    p = Parameters.fetch!()

    assert p.windows == [30, 90, 180]
    assert p.default_window == 90
    assert p.ks == [1, 2, 3]
    assert p.minimum_sample == 10
    assert p.counted_states == ~w(APPROVED CHANGES_REQUESTED COMMENTED DISMISSED)

    assert p.knowledge_versions["review.network.parameters"] == 1
    # 076, T027: a versão 2, com a conta da organização entre as exclusões.
    assert p.knowledge_versions["review.network.edge"] == 2
    assert map_size(p.knowledge_versions) == 11
    assert p.knowledge_versions["review.network.concentration.top_k_share"] == 1
  end

  test "as regras completas viram os parâmetros, com as versões" do
    p = Parameters.from_rules!(parametros(), aresta(), medidas())

    assert p.knowledge_versions == %{
             "review.network.parameters" => 1,
             "review.network.edge" => 1,
             "review.network.reviews.count" => 2
           }
  end

  test "cada chave que falta levanta dizendo a regra e a chave" do
    casos = [
      {:p, ["window_days", "values", "allowed"]},
      {:p, ["window_days", "values", "default"]},
      {:p, ["k_values", "values", "k"]},
      {:p, ["min_reviews", "values", "min_reviews"]},
      {:a, ["counted_states", "values", "states"]},
      {:a, ["exclusions", "values", "order"]}
    ]

    for {qual, caminho} <- casos do
      {p, a, id} =
        case qual do
          :p -> {sem(parametros(), caminho), aresta(), "review.network.parameters"}
          :a -> {parametros(), sem(aresta(), caminho), "review.network.edge"}
        end

      texto = "#{id} inconsistente: #{Enum.join(caminho, ".")} ausente"

      assert_raise RuntimeError, texto, fn -> Parameters.from_rules!(p, a, medidas()) end
    end
  end

  test "valores incoerentes levantam" do
    for {caminho, valor} <- [
          {["window_days", "values", "default"], 60},
          {["k_values", "values", "k"], [3, 1]},
          {["min_reviews", "values", "min_reviews"], 0},
          {["window_days", "values", "allowed"], [30, -1]}
        ] do
      assert_raise RuntimeError, ~r/inconsistente/, fn ->
        Parameters.from_rules!(
          put_in(parametros(), ["rules" | caminho], valor),
          aresta(),
          medidas()
        )
      end
    end
  end

  test "a ordem das exclusões diferente da implementada levanta" do
    trocada =
      put_in(
        aresta(),
        ["rules", "exclusions", "values", "order"],
        ~w(bot_or_app unlinked_person self_review)
      )

    assert_raise RuntimeError, ~r/exclusions.order difere/, fn ->
      Parameters.from_rules!(parametros(), trocada, medidas())
    end
  end

  test "medida ou regra sem versão levanta" do
    assert_raise RuntimeError, ~r/review.network.reviews.count inconsistente: version/, fn ->
      Parameters.from_rules!(parametros(), aresta(), %{"review.network.reviews.count" => %{}})
    end

    assert_raise RuntimeError, ~r/review.network.edge inconsistente: version/, fn ->
      Parameters.from_rules!(parametros(), Map.delete(aresta(), "version"), medidas())
    end
  end
end
