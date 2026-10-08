defmodule TheBand.Platform.CodigoDeUsoUnicoTest do
  @moduledoc """
  O código de definição, o de cadastro e o de guarda são de uso único, mesmo em paralelo — spec
  070, T027 (A5; cenário 3 de `seguranca-autenticacao.md`). Os dois lados contados (L90).
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog

  alias TheBand.Platform.{Credentials, Grant, Operator}
  alias TheBand.Segredo

  defp operador_novo do
    op =
      Repo.insert!(%Operator{
        email: "op-#{System.unique_integer([:positive])}@example.org",
        name: "Op"
      })

    Repo.insert!(%Grant{
      operator_id: op.id,
      granted_at: DateTime.utc_now(:second),
      granted_via: "release_command",
      granted_by_declared: "quem rodou",
      email_at_grant: op.email
    })

    {:ok, codigo} = Credentials.emitir_codigo(op)
    {op, codigo}
  end

  defp em_paralelo(funs) do
    ref = make_ref()

    capture_log(fn ->
      r =
        funs
        |> Task.async_stream(& &1.(), max_concurrency: 2, ordered: true)
        |> Enum.map(fn {:ok, x} -> x end)

      send(self(), {ref, r})
    end)

    receive do: ({^ref, r} -> r)
  end

  defp quieto(fun) do
    ref = make_ref()
    capture_log(fn -> send(self(), {ref, fun.()}) end)
    receive do: ({^ref, r} -> r)
  end

  defp contar(resultados) do
    {Enum.count(resultados, &match?({:ok, _}, &1)),
     Enum.count(resultados, &(&1 == {:error, :invalid_credentials}))}
  end

  test "o mesmo código de definição com duas senhas: uma passa, a outra não, e vale a senha da que ganhou" do
    {op, codigo} = operador_novo()
    senhas = ["primeira-senha-bem-comprida", "segunda-senha-bem-comprida"]

    resultados =
      em_paralelo(
        Enum.map(senhas, fn s ->
          fn ->
            Credentials.definir_senha(
              op.email,
              codigo,
              Segredo.novo(s),
              TheBand.OrigemDeTeste.nova()
            )
          end
        end)
      )

    assert contar(resultados) == {1, 1}

    depois = Repo.get!(Operator, op.id)
    assert depois.setup_code_hash == nil

    [vencedora] = for {{:ok, _}, s} <- Enum.zip(resultados, senhas), do: s
    assert Bcrypt.verify_pass(vencedora, depois.password_hash)
  end

  test "o mesmo código de cadastro, e depois o mesmo código de guarda, em paralelo: um passa cada vez" do
    {op, codigo} = operador_novo()

    {:ok, {_, %{segredo: segredo, enrollment_token: token}}} =
      quieto(fn ->
        Credentials.definir_senha(
          op.email,
          codigo,
          Segredo.novo("a-senha-do-operador-1"),
          TheBand.OrigemDeTeste.nova()
        )
      end)

    c = Segredo.novo(NimbleTOTP.verification_code(Segredo.expor(segredo)))

    cadastros =
      em_paralelo(
        for _ <- 1..2,
            do: fn ->
              Credentials.confirmar_segundo_fator(
                op.email,
                token,
                c,
                TheBand.OrigemDeTeste.nova()
              )
            end
      )

    assert contar(cadastros) == {1, 1}

    [{:ok, {_, _, guarda}}] = Enum.filter(cadastros, &match?({:ok, _}, &1))

    conclusoes =
      em_paralelo(
        for _ <- 1..2,
            do: fn ->
              Credentials.concluir_cadastro(op.email, guarda, TheBand.OrigemDeTeste.nova())
            end
      )

    assert contar(conclusoes) == {1, 1}
  end
end
