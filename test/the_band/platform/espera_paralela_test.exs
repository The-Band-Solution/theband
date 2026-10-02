defmodule TheBand.Platform.EsperaParalelaTest do
  @moduledoc """
  A espera do operador não se contorna em paralelo — spec 070, T024 (A1; cenário 1 de
  `seguranca-autenticacao.md`).

  ## Por que dois testes

  No sandbox, as transações de processos diferentes se enfileiram numa conexão só, e o teste da
  rajada passaria só com a releitura. O que prova a trava, que importa em produção, é a captura do
  `FOR UPDATE` — o desenho da #1046 (PR #1048).
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.{Credentials, Operator}
  alias TheBand.Segredo

  defp rajada(op, senha, segundo_fator) do
    1..10
    |> Task.async_stream(
      fn _ -> Credentials.autenticar(op.email, Segredo.novo(senha), segundo_fator) end,
      max_concurrency: 10,
      ordered: false
    )
    |> Enum.map(fn {:ok, r} -> r end)
  end

  test "dez senhas erradas ao mesmo tempo: uma conta a falha, nove recebem a espera" do
    {op, segredo} = operador_pronto(failed_attempts: 3)
    # A espera de 3 falhas é de 2 s: dez segundos atrás, ela já passou, e a primeira tentativa
    # entra. As outras nove encontram a falha que ela gravou.
    Repo.update_all(from(o in Operator, where: o.id == ^op.id),
      set: [last_failed_at: DateTime.add(DateTime.utc_now(:second), -10, :second)]
    )

    resultados =
      capture_log(fn ->
        send(self(), {:r, rajada(op, "senha-errada-e-comprida", totp(segredo))})
      end)
      |> then(fn _ -> receive(do: ({:r, r} -> r)) end)

    assert Enum.count(resultados, &(&1 == {:error, :invalid_credentials})) == 1
    assert Enum.count(resultados, &match?({:error, {:throttled, _}}, &1)) == 9
    assert Repo.get!(Operator, op.id).failed_attempts == 4
  end

  test "a guarda de que mediu: com a senha certa e sem espera, uma das dez entra" do
    {op, segredo} = operador_pronto()
    c = totp(segredo)

    resultados =
      capture_log(fn -> send(self(), {:r, rajada(op, senha_do_operador(), c)}) end)
      |> then(fn _ -> receive(do: ({:r, r} -> r)) end)

    # O mesmo código: a primeira entra e grava o passo; as outras são reuso.
    assert Enum.count(resultados, &match?({:ok, %Operator{}}, &1)) == 1
  end

  test "a linha do operador é relida com FOR UPDATE" do
    {op, segredo} = operador_pronto()
    ref = make_ref()
    eu = self()
    id = "trava-operador-#{inspect(ref)}"

    :telemetry.attach(
      id,
      [:the_band, :repo, :query],
      fn _e, _m, %{query: sql}, _ -> send(eu, {ref, sql}) end,
      nil
    )

    capture_log(fn ->
      Credentials.autenticar(op.email, Segredo.novo("errada-e-comprida"), totp(segredo))
    end)

    :telemetry.detach(id)

    consultas = coletar(ref, [])
    assert consultas != [], "a captura não mediu consulta nenhuma"
    assert Enum.any?(consultas, &(&1 =~ ~s(FROM "platform_operators") and &1 =~ "FOR UPDATE"))
  end

  defp coletar(ref, acc) do
    receive do
      {^ref, sql} -> coletar(ref, [sql | acc])
    after
      0 -> acc
    end
  end
end
