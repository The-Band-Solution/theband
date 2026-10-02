defmodule TheBand.ReleaseOperadorTest do
  @moduledoc """
  Os comandos de operação do papel de operador — spec 070, T032 (FR-001, O11). São o único caminho
  que concede, reinicia e revoga o papel: nenhuma tela o faz.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureIO
  import ExUnit.CaptureLog

  alias TheBand.Platform.{Operator, Sessions}
  alias TheBand.Release

  defp saida(fun),
    do:
      capture_log(fn -> send(self(), {:io, capture_io(fun)}) end)
      |> then(fn _ -> receive(do: ({:io, s} -> s)) end)

  test "conceder_operador imprime o código uma vez, e nenhuma senha" do
    texto = saida(fn -> Release.conceder_operador("cmd@example.org", "Op", "quem executa") end)

    assert texto =~ "operador concedido: cmd@example.org"

    [codigo] =
      Regex.run(~r/código de definição \(vale 30 minutos, uma vez\): ([a-z2-7]+)/, texto,
        capture: :all_but_first
      )

    assert texto |> String.split(codigo) |> length() == 2
    refute texto =~ ~r/senha:|password/i
  end

  test "girar_sessoes/0 e encerrar_todas_as_sessoes/0 encerram as sessões de operador e dizem a contagem" do
    {op, _} = TheBand.OperadorFixtures.operador_pronto()

    {:ok, {s1, _}} = Sessions.abrir(op)
    assert Release.girar_sessoes() =~ "1 sessão(ões) de operador encerrada(s)"
    assert Repo.get!(TheBand.Platform.OperatorSession, s1.id).ended_at

    {:ok, {s2, _}} = Sessions.abrir(Repo.get!(Operator, op.id))
    assert saida(fn -> Release.encerrar_todas_as_sessoes() end) =~ "e 1 sessão(ões) de operador"
    assert Repo.get!(TheBand.Platform.OperatorSession, s2.id).ended_at
  end

  # FR-001: o papel não se concede pela web. Pelo `mix xref callers`, que vê chamada de verdade,
  # inclusive por alias, e não lê comentário.
  test "nenhum módulo de TheBandWeb chama TheBand.Platform.Grants" do
    {saida, 0} =
      System.cmd("mix", ["xref", "callers", "TheBand.Platform.Grants"],
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    chamadores = saida |> String.split("\n") |> Enum.filter(&String.contains?(&1, "lib/"))

    assert chamadores != [],
           "o xref não achou chamador nenhum: a medição não mediu (Release chama)"

    assert Enum.filter(chamadores, &String.contains?(&1, "lib/the_band_web/")) == []
  end
end
