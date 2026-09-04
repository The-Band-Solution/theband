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

  describe "o caso que era pessimista, e deixou de ser" do
    # Escrito em 2026-09-03 para registrar o defeito: o moduledoc afirmava que o
    # {:parcial, _} aparecia só quando a sobreposição DEPENDIA da borda nula, e o
    # código marcava sempre que existisse início nulo.
    #
    # Os 12 testes originais da T001 passaram porque nenhum deles tinha um período
    # de início nulo cuja sobreposição fosse CERTA pelos outros. Estes têm — e em
    # 2026-09-04 o código passou a cumprir o que o documento prometia.
    test "início nulo NÃO marca quando a sobreposição é certa pelos outros períodos" do
      # Os dois primeiros cobrem 1–30 com início conhecido. O terceiro termina no
      # dia 20: comece onde começar, a sobreposição 1–20 existe.
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(30)},
               %{inicio: d(1), fim: d(30)},
               %{inicio: nil, fim: d(20)}
             ]) == :intersecta,
             "a dúvida não decide nada aqui, e marcar mesmo assim faria a marca aparecer sempre"
    end

    test "a janela sem data de início deixou de envenenar toda linha" do
      # Era a razão prática de o moduledoc mandar exigir as duas datas em
      # formulário. Com a regra corrigida, a janela aberta no início só levanta
      # dúvida quando ela realmente decide.
      membro = %{inicio: d(1), fim: d(30)}
      vinculo = %{inicio: d(1), fim: d(30)}

      assert Periodos.interseccao([membro, vinculo, %{inicio: nil, fim: d(20)}]) ==
               :intersecta

      # E continua marcando quando o desconhecido pode cair fora: `?–d(60)` contra
      # um vínculo que acaba no dia 30 pode ter começado depois dele.
      assert Periodos.interseccao([membro, vinculo, %{inicio: nil, fim: d(60)}]) ==
               {:parcial, [:inicio_desconhecido]}

      # Com as duas datas preenchidas, limpo — como sempre foi.
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

  describe "a marca só aparece quando a sobreposição DEPENDE da borda que falta" do
    test "início nulo cujo FIM já garante a sobreposição não marca" do
      # `?–d(160)` dentro de `d(1)–d(340)`: onde quer que ele comece, começa antes
      # de d(160) e depois de d(1) — a sobreposição existe sem depender da data.
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(340)},
               %{inicio: nil, fim: d(160)}
             ]) == :intersecta
    end

    test "três períodos, e o desconhecido não é o que decide" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(340)},
               %{inicio: d(1), fim: d(340)},
               %{inicio: nil, fim: d(160)}
             ]) == :intersecta
    end

    test "início nulo cujo fim cai FORA do outro período marca — a dúvida decide" do
      # `?–d(340)` contra `d(60)–d(90)`: se começou em d(120), não houve sobreposição
      # nenhuma. A resposta depende da data que ninguém declarou.
      assert Periodos.interseccao([
               %{inicio: d(60), fim: d(90)},
               %{inicio: nil, fim: d(340)}
             ]) == {:parcial, [:inicio_desconhecido]}
    end

    test "início nulo E fim nulo continuam marcando — pode ter começado depois de tudo" do
      assert Periodos.interseccao([
               %{inicio: d(1), fim: d(160)},
               %{inicio: nil, fim: nil}
             ]) == {:parcial, [:inicio_desconhecido]}
    end

    test "o desconhecido que termina onde o outro começa é DISJUNTO, e não duvidoso" do
      # Borda `[início, fim)`: `?–d(160)` acaba quando `d(160)–d(340)` começa. O que
      # se sabe já basta para negar, e transformar isso em dúvida seria o erro
      # simétrico ao que esta correção conserta.
      assert Periodos.interseccao([
               %{inicio: d(160), fim: d(340)},
               %{inicio: nil, fim: d(160)}
             ]) == :nao_intersecta
    end

    test "o caso da tela: vínculo em curso sem started_at continua marcado" do
      # É a linha que a feature 058 mostra, e continua marcando: um vínculo aberto
      # sem data de início pode ter começado depois da janela inteira.
      assert Periodos.interseccao([
               %{inicio: nil, fim: nil},
               %{inicio: d(1), fim: nil},
               %{inicio: d(1), fim: d(60)}
             ]) == {:parcial, [:inicio_desconhecido]}
    end
  end
end
