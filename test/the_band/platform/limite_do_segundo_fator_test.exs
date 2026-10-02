defmodule TheBand.Platform.LimiteDoSegundoFatorTest do
  @moduledoc """
  O limite próprio do segundo fator — spec 070, T028a (cenários C1 e C1b de `seguranca-totp.md`,
  achado T1, alta). **Bloqueia T036 e T039**: a área do operador não vai ao ar sem ele provado.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.{Credentials, Grants, Operator, OperatorSession}
  alias TheBand.Segredo

  defp quieto(fun) do
    ref = make_ref()
    log = capture_log(fn -> send(self(), {ref, fun.()}) end)
    receive do: ({^ref, r} -> {r, log})
  end

  # Avança a espera: a espera é da senha, e este teste mede o contador do segundo fator.
  defp sem_espera(op),
    do: Repo.update_all(from(o in Operator, where: o.id == ^op.id), set: [last_failed_at: nil])

  defp entrar(email, senha, c), do: Credentials.autenticar(email, Segredo.novo(senha), c)

  test "C1: nove erros não travam, o décimo trava, o certo é recusado, e o reinício destrava" do
    {r, _} = quieto(fn -> pelo_caminho_real() end)
    errado = totp(r.segredo, System.os_time(:second) + 600)

    for _ <- 1..9 do
      sem_espera(r.op)

      {{:error, :invalid_credentials}, _} =
        quieto(fn -> entrar(r.email, senha_do_operador(), errado) end)
    end

    # A guarda de que mediu: antes do décimo, o certo entra (e zera o contador).
    sem_espera(r.op)

    {{:ok, _}, _} =
      quieto(fn ->
        entrar(r.email, senha_do_operador(), totp(r.segredo, System.os_time(:second) + 30))
      end)

    for _ <- 1..10 do
      sem_espera(r.op)

      {{:error, :invalid_credentials}, _} =
        quieto(fn -> entrar(r.email, senha_do_operador(), errado) end)
    end

    sem_espera(r.op)

    {resultado, log} =
      quieto(fn ->
        entrar(r.email, senha_do_operador(), totp(r.segredo, System.os_time(:second) + 60))
      end)

    assert resultado == {:error, :invalid_credentials}
    assert log =~ "motivo=:segundo_fator_travado"

    assert Repo.aggregate(
             from(s in OperatorSession, where: s.operator_id == ^r.op.id and is_nil(s.ended_at)),
             :count
           ) == 0

    {{:ok, _}, _} = quieto(fn -> Grants.reiniciar_credencial(r.email, "quem") end)
    assert Repo.get!(Operator, r.op.id).second_factor_failures == 0
  end

  test "C1b: dez senhas erradas não tocam o contador, e a entrada legítima passa" do
    {r, _} = quieto(fn -> pelo_caminho_real() end)

    for _ <- 1..10 do
      sem_espera(r.op)

      {{:error, :invalid_credentials}, _} =
        quieto(fn -> entrar(r.email, "senha-errada-e-comprida", totp(r.segredo)) end)
    end

    assert Repo.get!(Operator, r.op.id).second_factor_failures == 0
    sem_espera(r.op)

    assert {{:ok, _}, _} =
             quieto(fn ->
               entrar(r.email, senha_do_operador(), totp(r.segredo, System.os_time(:second) + 30))
             end)
  end
end
