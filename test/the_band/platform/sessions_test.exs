defmodule TheBand.Platform.SessionsTest do
  @moduledoc """
  A sessão do operador — spec 070, T029 (FR-011, FR-014, A11). Um caso por motivo de recusa.
  """
  use TheBand.DataCase, async: true

  import TheBand.OperadorFixtures

  alias TheBand.Platform.{Grant, Operator, OperatorSession, Sessions}
  alias TheBand.Segredo

  setup do
    {op, _} = operador_pronto()
    {:ok, {sessao, segredo}} = Sessions.abrir(op)
    %{op: op, sessao: sessao, segredo: segredo}
  end

  defp recuar(sessao, campo, segundos) do
    Repo.update_all(from(s in OperatorSession, where: s.id == ^sessao.id),
      set: [{campo, DateTime.add(DateTime.utc_now(:second), -segundos, :second)}]
    )
  end

  test "a sessão aberta confere e devolve o operador", ctx do
    assert {:ok, _sessao, %Operator{id: id}} = Sessions.conferir(ctx.sessao.id, ctx.segredo)
    assert id == ctx.op.id
  end

  test ":malformado — id que não é UUID, segredo que não é Segredo, e ausência", ctx do
    assert {:error, :malformado} = Sessions.conferir("nao-e-uuid", ctx.segredo)
    assert {:error, :malformado} = Sessions.conferir(ctx.sessao.id, Segredo.expor(ctx.segredo))
    assert {:error, :malformado} = Sessions.conferir(nil, nil)
  end

  test ":inexistente", ctx do
    assert {:error, :inexistente} = Sessions.conferir(Ecto.UUID.generate(), ctx.segredo)
  end

  test ":resumo_errado", ctx do
    assert {:error, :resumo_errado} = Sessions.conferir(ctx.sessao.id, Segredo.novo("outro"))
  end

  test ":encerrada", ctx do
    :ok = Sessions.encerrar(ctx.sessao)
    assert {:error, :encerrada} = Sessions.conferir(ctx.sessao.id, ctx.segredo)
  end

  test ":vencida — mais de 8 h desde a abertura", ctx do
    recuar(ctx.sessao, :inserted_at, 8 * 3600 + 1)
    assert {:error, :vencida} = Sessions.conferir(ctx.sessao.id, ctx.segredo)
  end

  test ":inativa — mais de 30 min sem uso", ctx do
    recuar(ctx.sessao, :last_seen_at, 30 * 60 + 1)
    assert {:error, :inativa} = Sessions.conferir(ctx.sessao.id, ctx.segredo)
  end

  test ":epoca_velha — a senha foi definida depois da abertura", ctx do
    Repo.update_all(from(o in Operator, where: o.id == ^ctx.op.id), inc: [password_epoch: 1])
    assert {:error, :epoca_velha} = Sessions.conferir(ctx.sessao.id, ctx.segredo)
  end

  test ":sem_concessao — o papel foi revogado depois da abertura", ctx do
    Repo.update_all(from(g in Grant, where: g.operator_id == ^ctx.op.id),
      set: [
        revoked_at: DateTime.utc_now(:second),
        revoked_via: "release_command",
        revoked_by_declared: "quem"
      ]
    )

    assert {:error, :sem_concessao} = Sessions.conferir(ctx.sessao.id, ctx.segredo)
  end

  test "last_seen_at é gravado no máximo uma vez por minuto", ctx do
    recuar(ctx.sessao, :last_seen_at, 120)
    {:ok, _, _} = Sessions.conferir(ctx.sessao.id, ctx.segredo)
    primeira = Repo.get!(OperatorSession, ctx.sessao.id).last_seen_at

    recuar(ctx.sessao, :last_seen_at, 10)
    marcada = Repo.get!(OperatorSession, ctx.sessao.id).last_seen_at
    {:ok, _, _} = Sessions.conferir(ctx.sessao.id, ctx.segredo)

    assert DateTime.diff(DateTime.utc_now(:second), primeira) < 5
    assert Repo.get!(OperatorSession, ctx.sessao.id).last_seen_at == marcada
  end

  test "encerrar_do_operador e encerrar_todas encerram e contam", ctx do
    {:ok, _} = Sessions.abrir(ctx.op)
    assert {:ok, 2} = Sessions.encerrar_do_operador(ctx.op)
    {:ok, _} = Sessions.abrir(ctx.op)
    assert {:ok, n} = Sessions.encerrar_todas()
    assert n >= 1
  end
end
