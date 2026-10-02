defmodule TheBand.Platform.EsperaPagaOHashTest do
  @moduledoc """
  A espera do operador paga o custo do hash — spec 070, T025 (A3; cenário 2 de
  `seguranca-autenticacao.md`). Contado pelo evento de telemetria que todo custo de hash de
  `Credentials` emite, e não por cronômetro.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.{Credentials, Operator}
  alias TheBand.Segredo

  defp contando(fun) do
    ref = make_ref()
    eu = self()
    id = "hash-#{inspect(ref)}"

    :telemetry.attach(
      id,
      [:the_band, :platform, :custo_do_hash],
      fn _e, _m, meta, _ -> send(eu, {ref, meta.motivo}) end,
      nil
    )

    resultado =
      capture_log(fn -> send(self(), {ref, :resultado, fun.()}) end)
      |> then(fn _ -> receive(do: ({^ref, :resultado, r} -> r)) end)

    :telemetry.detach(id)
    {resultado, coletar(ref, [])}
  end

  defp coletar(ref, acc) do
    receive do
      {^ref, motivo} when is_atom(motivo) -> coletar(ref, [motivo | acc])
    after
      0 -> acc
    end
  end

  test "a recusa por espera paga o hash uma vez, e devolve {:throttled, _}" do
    {op, segredo} = operador_pronto(failed_attempts: 5)

    Repo.update_all(from(o in Operator, where: o.id == ^op.id),
      set: [last_failed_at: DateTime.utc_now(:second)]
    )

    {resultado, custos} =
      contando(fn ->
        Credentials.autenticar(op.email, Segredo.novo(senha_do_operador()), totp(segredo))
      end)

    assert {:error, {:throttled, _}} = resultado
    assert length(custos) == 1
  end

  test "o e-mail inexistente paga o hash uma vez" do
    {resultado, custos} =
      contando(fn ->
        Credentials.autenticar(
          "ninguem@example.org",
          Segredo.novo("x-y-z-bem-comprida"),
          Segredo.novo("123456")
        )
      end)

    assert resultado == {:error, :invalid_credentials}
    assert length(custos) == 1
  end
end
