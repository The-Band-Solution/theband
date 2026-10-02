defmodule TheBand.Platform.SegundoFatorNaEntradaTest do
  @moduledoc """
  A entrada exige o segundo fator a cada vez — spec 070, T028 (FR-016; cenários C3, C4, C5, C9 e
  C12 de `seguranca-totp.md`).
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.{Credentials, Operator, RecoveryCode, SegundoFator}
  alias TheBand.Segredo

  defp quieto(fun) do
    ref = make_ref()
    log = capture_log(fn -> send(self(), {ref, fun.()}) end)
    receive do: ({^ref, r} -> {r, log})
  end

  defp entrar(op, segundo_fator, senha \\ senha_do_operador()),
    do: Credentials.autenticar(op.email, Segredo.novo(senha), segundo_fator)

  defp codigos(op, n) do
    for c <- Enum.take(SegundoFator.gerar_codigos_de_recuperacao(), n) do
      Repo.insert!(%RecoveryCode{operator_id: op.id, code_hash: SegundoFator.resumo(c)})
      c
    end
  end

  test "sem segundo fator, a recusa única" do
    {op, _} = operador_pronto()
    assert {{:error, :invalid_credentials}, _} = quieto(fn -> entrar(op, Segredo.novo("")) end)
  end

  test "C3: o mesmo código TOTP duas vezes, e o passo gravado é o aceito" do
    {op, segredo} = operador_pronto()
    c = totp(segredo)

    assert {{:ok, _}, _} = quieto(fn -> entrar(op, c) end)
    passo = Repo.get!(Operator, op.id).totp_last_used_step

    assert passo == div(System.os_time(:second), 30) or
             passo == div(System.os_time(:second), 30) - 1

    assert {{:error, :invalid_credentials}, log} = quieto(fn -> entrar(op, c) end)
    assert log =~ "motivo=:segundo_fator_reusado"
  end

  test "C12: senha errada com um código de recuperação válido não gasta o código" do
    {op, _} = operador_pronto()
    [c] = codigos(op, 1)

    assert {{:error, :invalid_credentials}, _} =
             quieto(fn -> entrar(op, c, "senha-errada-e-comprida") end)

    assert Repo.one!(from r in RecoveryCode, where: r.operator_id == ^op.id, select: r.used_at) ==
             nil
  end

  test "C9: dois usos paralelos do mesmo código de recuperação, e o evento diz quantos restam" do
    {op, _} = operador_pronto()
    [c, _, _] = codigos(op, 3)

    {resultados, log} =
      quieto(fn ->
        1..2
        |> Task.async_stream(fn _ -> entrar(op, c) end, max_concurrency: 2)
        |> Enum.map(fn {:ok, r} -> r end)
      end)

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert Enum.count(resultados, &(&1 == {:error, :invalid_credentials})) == 1
    assert log =~ "operador recuperação usada" and log =~ "restantes=2"
  end
end
