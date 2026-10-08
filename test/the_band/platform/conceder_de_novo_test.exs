defmodule TheBand.Platform.ConcederDeNovoTest do
  @moduledoc """
  Conceder de novo não devolve credencial antiga — spec 070, T031 (cenário 4 de
  `seguranca-autenticacao.md`, achado A6; T8).
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.{Credentials, Grants, Operator, RecoveryCode, Sessions}
  alias TheBand.Segredo

  defp quieto(fun) do
    ref = make_ref()
    capture_log(fn -> send(self(), {ref, fun.()}) end)
    receive do: ({^ref, r} -> r)
  end

  test "conceder, cadastrar, revogar e conceder de novo: a senha e o aplicativo de antes não entram" do
    r = quieto(fn -> pelo_caminho_real() end)
    [usado | _] = r.codigos

    {:ok, _} =
      quieto(fn ->
        Credentials.autenticar(
          r.email,
          Segredo.novo(senha_do_operador()),
          usado,
          TheBand.OrigemDeTeste.nova()
        )
      end)

    {:ok, {sessao, segredo_da_sessao}} = Sessions.abrir(Repo.get!(Operator, r.op.id))

    quieto(fn -> {:ok, _} = Grants.revogar(r.email, "quem", "suspeita") end)
    quieto(fn -> {:ok, _} = Grants.conceder(r.email, "Op", "quem") end)

    depois = Repo.get!(Operator, r.op.id)
    assert depois.password_hash == nil
    assert Repo.one!(from o in Operator, where: o.id == ^r.op.id, select: o.totp_secret) == nil

    assert quieto(fn ->
             Credentials.autenticar(
               r.email,
               Segredo.novo(senha_do_operador()),
               totp(r.segredo, System.os_time(:second) + 30),
               TheBand.OrigemDeTeste.nova()
             )
           end) ==
             {:error, :invalid_credentials}

    assert {:error, _} = Sessions.conferir(sessao.id, segredo_da_sessao)

    marcas =
      Repo.all(
        from c in RecoveryCode,
          where: c.operator_id == ^r.op.id,
          select: {c.used_at, c.invalidated_at}
      )

    assert Enum.count(marcas, fn {u, _} -> u != nil end) == 1
    assert Enum.count(marcas, fn {u, i} -> u == nil and i != nil end) == 9
  end
end
