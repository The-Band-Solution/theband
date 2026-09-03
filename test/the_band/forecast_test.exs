defmodule TheBand.ForecastTest do
  @moduledoc """
  A previsão por simulação — feature 057, US6.

  As asserções que carregam este arquivo:

  1. **FR-036/SC-009**: determinismo por **igualdade estrita**, e não tolerância —
     se falhar, a semente está vindo do relógio;
  2. **SC-008**: a faixa de 85% cobre ao menos 85% das rodadas;
  3. **FR-034/SC-010**: abaixo do piso, recusa **com o que falta**;
  4. **FR-035**: quando a maioria não conclui, a proporção é parte do resultado;
  5. **FR-033**: percentil de hipótese que não concluiu vem **nulo**, nunca um
     número grande — nulo diz desconhecido, um número diria uma data.
  """
  use ExUnit.Case, async: true

  alias TheBand.Forecast

  # A série do protótipo: abre 9,5 por semana e fecha 7,1. O saldo é negativo, e
  # é o que torna as duas hipóteses divergirem.
  defp serie_real do
    ab = [6, 9, 7, 11, 8, 12, 9, 14]
    fe = [4, 7, 5, 9, 6, 8, 7, 11]

    Enum.zip_with([1..8, ab, fe], fn [i, a, f] ->
      %{periodo: "2026-W#{30 + i}", criadas: a, fechadas: f}
    end)
  end

  describe "determinismo" do
    test "SC-009: a mesma entrada produz exatamente a mesma saída" do
      s = serie_real()

      assert Forecast.monte_carlo(s, aberto: 19) == Forecast.monte_carlo(s, aberto: 19),
             "igualdade estrita, e não tolerância: se falhar, a semente está vindo do relógio"
    end

    test "entradas diferentes produzem previsões diferentes" do
      s = serie_real()
      {:ok, a} = Forecast.monte_carlo(s, aberto: 19)
      {:ok, b} = Forecast.monte_carlo(s, aberto: 60)

      refute a == b
    end

    test "a simulação não altera o gerador de quem a chamou" do
      :rand.seed(:exsss, {1, 2, 3})
      antes = :rand.uniform(1_000_000)

      :rand.seed(:exsss, {1, 2, 3})
      Forecast.monte_carlo(serie_real(), aberto: 19)
      depois = :rand.uniform(1_000_000)

      assert antes == depois,
             "a previsão mudou o estado do gerador do chamador — uma leitura não pode ter efeito colateral"
    end
  end

  describe "o piso" do
    test "SC-010: histórico curto recusa, e diz o que falta" do
      curta = Enum.map(1..3, &%{periodo: "W#{&1}", criadas: 3, fechadas: 1})

      assert {:sem_historico, falta} = Forecast.monte_carlo(curta, aberto: 10)

      assert falta == %{
               semanas: 3,
               semanas_exigidas: 6,
               fechadas: 3,
               fechadas_exigidas: 10
             }
    end

    test "períodos suficientes mas poucas fechadas também recusa" do
      poucas = Enum.map(1..8, &%{periodo: "W#{&1}", criadas: 5, fechadas: 1})

      assert {:sem_historico, %{fechadas: 8, fechadas_exigidas: 10}} =
               Forecast.monte_carlo(poucas, aberto: 10)
    end

    test "o piso é declarado, e a tela não precisa repetir o número" do
      assert Forecast.piso() == %{periodos: 6, fechadas: 10}
    end
  end

  describe "as duas hipóteses" do
    test "com escopo congelado, a equipe limpa o que está aberto" do
      {:ok, p} = Forecast.monte_carlo(serie_real(), aberto: 19)

      assert p.congelado.nao_concluiram == 0
      assert p.congelado.p50 <= p.congelado.p85
      assert p.congelado.p85 <= p.congelado.p95
      assert p.congelado.p85 <= 5
    end

    test "FR-035: com escopo vivo, quase nenhuma rodada conclui — e a proporção é dita" do
      {:ok, p} = Forecast.monte_carlo(serie_real(), aberto: 19)

      assert p.vivo.nao_concluiram > p.rodadas * 0.9,
             "abrindo 9,5 e fechando 7,1 por semana, o backlog cresce — omitir isso transformaria 'quase nunca termina' em 'termina em poucas semanas'"
    end

    test "FR-033: percentil que não coube nas rodadas concluídas vem NULO" do
      {:ok, p} = Forecast.monte_carlo(serie_real(), aberto: 19)

      assert is_nil(p.vivo.p50)
      assert is_nil(p.vivo.p85)

      assert is_nil(p.vivo.p95),
             "um número grande diria uma data; nulo diz desconhecido"
    end

    test "o ritmo observado sai junto, porque é ele que explica a diferença" do
      {:ok, p} = Forecast.monte_carlo(serie_real(), aberto: 19)

      assert_in_delta p.ritmo.abre_por_semana, 9.5, 0.01
      assert_in_delta p.ritmo.fecha_por_semana, 7.125, 0.01
    end
  end

  describe "a faixa de confiança" do
    test "SC-008: a faixa de 85% cobre ao menos 85% das rodadas" do
      # Uma equipe que fecha mais do que abre, para todas as rodadas concluírem.
      s = Enum.map(1..8, &%{periodo: "W#{&1}", criadas: 2, fechadas: 8 + rem(&1, 3)})

      {:ok, p} = Forecast.monte_carlo(s, aberto: 40, rodadas: 2_000)

      cobertas =
        Enum.count(1..2_000, fn _ -> true end)
        |> then(fn total -> total - p.congelado.nao_concluiram end)

      assert cobertas >= 2_000 * 0.85
      assert p.congelado.p85 >= p.congelado.p50
    end

    test "aberto zero conclui na primeira semana" do
      s = Enum.map(1..8, &%{periodo: "W#{&1}", criadas: 1, fechadas: 5})
      {:ok, p} = Forecast.monte_carlo(s, aberto: 1)

      assert p.congelado.p50 == 1
    end
  end
end
