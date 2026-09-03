defmodule TheBand.PeriodosTest do
  @moduledoc """
  A interseção de períodos — feature 058, T001.

  As asserções que carregam este arquivo:

  1. **FR-012**: a borda é `[início, fim)` — no instante do fim já não está;
  2. **FR-009**: `inicio` nulo é **desconhecido** e produz `{:parcial, _}`;
     `fim` nulo é **vigente**, e não produz dúvida nenhuma — as duas pontas
     significam coisas diferentes, e confundi-las poria a marca em quase toda
     linha até ela deixar de significar algo;
  3. **o erro simétrico**: `{:parcial, _}` não pode aparecer quando o que se sabe
     **já basta para negar** — isso transformaria conhecimento em dúvida;
  4. três e quatro períodos funcionam igual, porque a US2 usa três e a US3 quatro.
  """
  use ExUnit.Case, async: true

  doctest TheBand.Periodos

  alias TheBand.Periodos

  defp d(dia),
    do: DateTime.new!(Date.new!(2026, 1, 1) |> Date.add(dia - 1), ~T[00:00:00], "Etc/UTC")

  describe "a borda [início, fim)" do
    test "FR-012: no instante exato do fim já não está dentro" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(10)},
               %{inicio: d(10), fim: d(20)}
             ]) == :nao_intersecta
    end

    test "um instante antes do fim ainda está" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(11)},
               %{inicio: d(10), fim: d(20)}
             ]) == :intersecta
    end

    test "contem?/2 usa a mesma borda" do
      p = %{inicio: d(1), fim: d(10)}

      assert Periodos.contem?(p, d(1))
      assert Periodos.contem?(p, d(9))
      refute Periodos.contem?(p, d(10))
    end
  end

  describe "nil é desconhecido, e não aberto" do
    test "FR-009: início nulo produz {:parcial, _}" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(10)},
               %{inicio: nil, fim: d(20)}
             ]) == {:parcial, [:inicio_desconhecido]}
    end

    test "fim nulo é VIGENTE, e não produz dúvida" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(10)},
               %{inicio: d(5), fim: nil}
             ]) == :intersecta,
             "`unlinked_at` nulo significa em curso; marcá-lo como desconhecido poria a dúvida em quase toda linha"
    end

    test "as duas nulas: só o início conta como desconhecido" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(10)},
               %{inicio: nil, fim: nil}
             ]) == {:parcial, [:inicio_desconhecido]}
    end

    test "nenhuma borda nula devolve :intersecta, e não {:parcial, []}" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(10)},
               %{inicio: d(5), fim: d(20)}
             ]) == :intersecta
    end
  end

  describe "o erro simétrico: dúvida onde já há resposta" do
    test "bordas conhecidas que se cruzam na ordem errada NEGAM, mesmo com nulo em outro campo" do
      # O fim do primeiro é anterior ao início do segundo — isso já basta para
      # negar, e o `inicio: nil` do primeiro não torna a resposta duvidosa.
      assert Periodos.interseccao([
               %{inicio: nil, fim: d(5)},
               %{inicio: d(10), fim: nil}
             ]) == :nao_intersecta,
             "dizer {:parcial, _} aqui transformaria conhecimento em dúvida — o que se sabe já responde"
    end

    test "três períodos em que só um par é disjunto já nega" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(30)},
               %{inicio: d(1), fim: d(5)},
               %{inicio: d(10), fim: d(30)}
             ]) == :nao_intersecta
    end
  end

  describe "a marca é PESSIMISTA, e este caso não estava coberto" do
    # Escrito em 2026-09-03, depois de o moduledoc ser corrigido. Ele afirmava que
    # o {:parcial, _} aparecia só quando a sobreposição DEPENDIA da borda nula, e
    # o código nunca fez isso — `bordas_desconhecidas` marca sempre que existe
    # início nulo.
    #
    # Os 12 testes originais da T001 passaram porque nenhum deles tinha um
    # período de início nulo cuja sobreposição fosse CERTA pelos outros. Este tem.
    test "início nulo marca mesmo quando a sobreposição é certa pelos outros períodos" do
      # Os dois primeiros cobrem 1–30 com início conhecido. O terceiro termina no
      # dia 20: comece onde começar, a sobreposição 1–20 existe.
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(30)},
               %{inicio: d(1), fim: d(30)},
               %{inicio: nil, fim: d(20)}
             ]) == {:parcial, [:inicio_desconhecido]},
             "o comportamento é pessimista de propósito, e o moduledoc diz isso desde 2026-09-03"
    end

    test "consequência: janela de consulta sem data envenena toda linha" do
      # É a razão prática de o moduledoc mandar exigir as duas datas em formulário.
      # Com a janela aberta no início, o veredito NUNCA é limpo — nem para quem
      # tem o vínculo inteiro conhecido.
      membro = %{inicio: d(1), fim: d(30)}
      vinculo = %{inicio: d(1), fim: d(30)}

      assert Periodos.interseccao([membro, vinculo, %{inicio: nil, fim: d(20)}]) ==
               {:parcial, [:inicio_desconhecido]}

      # E com as duas datas preenchidas, limpo.
      assert Periodos.interseccao([membro, vinculo, %{inicio: d(5), fim: d(20)}]) ==
               :intersecta
    end
  end

  describe "quantos períodos" do
    test "três — a interseção que a US2 usa" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(30)},
               %{inicio: d(5), fim: d(25)},
               %{inicio: d(10), fim: d(20)}
             ]) == :intersecta
    end

    test "quatro — a que a US3 acrescenta, com o repositório" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(30)},
               %{inicio: d(5), fim: d(25)},
               %{inicio: d(10), fim: d(20)},
               %{inicio: d(12), fim: nil}
             ]) == :intersecta

      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(30)},
               %{inicio: nil, fim: d(25)},
               %{inicio: d(10), fim: d(20)},
               %{inicio: d(12), fim: nil}
             ]) == {:parcial, [:inicio_desconhecido]}
    end

    test "lista vazia não intersecta, e um período sozinho intersecta consigo" do
      assert Periodos.interseccao([]) == :nao_intersecta
      assert Periodos.interseccao([%{inicio: nil, fim: nil}]) == :intersecta
    end
  end
end
