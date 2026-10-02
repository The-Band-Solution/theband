defmodule TheBand.Platform.GrantsTest do
  @moduledoc "Conceder, reiniciar e revogar o papel — spec 070, T030 (FR-001, FR-002, FR-014)."
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.{Grants, Sessions}

  test "revogar encerra a sessão do operador na mesma transação" do
    r =
      capture_log(fn -> send(self(), {:r, pelo_caminho_real()}) end)
      |> then(fn _ -> receive(do: ({:r, x} -> x)) end)

    {:ok, {sessao, segredo}} = Sessions.abrir(r.op)
    assert {:ok, _, _} = Sessions.conferir(sessao.id, segredo)

    capture_log(fn -> assert {:ok, _} = Grants.revogar(r.email, "quem revogou", nil) end)

    assert {:error, :encerrada} = Sessions.conferir(sessao.id, segredo)
    refute Grants.vigente?(r.op.id)
  end

  test "conceder duas vezes seguidas devolve {:error, :ja_concedido}" do
    capture_log(fn ->
      assert {:ok, _} = Grants.conceder("dup@example.org", "Op", "quem rodou")
      assert {:error, :ja_concedido} = Grants.conceder("dup@example.org", "Op", "quem rodou")
    end)
  end
end
