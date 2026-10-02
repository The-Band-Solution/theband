defmodule TheBand.Platform.SessaoAutorizadaTest do
  @moduledoc """
  A autorização conferida por dentro de `TheBand.Platform` — spec 070 (FR-014, O6). Ter passado pelo
  plug não basta: a revogação pode vir entre o plug e o ato.
  """
  use TheBand.DataCase, async: true

  import TheBand.OperadorFixtures

  alias TheBand.Platform
  alias TheBand.Platform.{Grant, Operator, OperatorSession, Sessions}

  setup do
    {op, _} = operador_pronto()
    {:ok, {sessao, _}} = Sessions.abrir(op)
    %{op: op, sessao: sessao}
  end

  test "a sessão aberta, no prazo e com concessão autoriza", %{sessao: sessao} do
    assert Sessions.autorizada(sessao) == :ok
  end

  for {caso, mudanca} <- [
        {"encerrada", :encerrada},
        {"vencida (mais de 8 h)", :vencida},
        {"inativa (mais de 30 min)", :inativa},
        {"de outra época da senha", :epoca},
        {"sem concessão vigente", :revogada}
      ] do
    @mudanca mudanca
    test "#{caso}: :nao_autorizado, relida do banco e não da struct", %{op: op, sessao: sessao} do
      mudar(@mudanca, op, sessao)
      assert Sessions.autorizada(sessao) == {:error, :nao_autorizado}
    end
  end

  test "listar_organizacoes/1 confere por dentro: com a concessão revogada, recusa", %{
    op: op,
    sessao: sessao
  } do
    tenant_fixture()
    assert {:ok, [_ | _] = resumos} = Platform.listar_organizacoes(sessao)
    assert Enum.all?(resumos, &(&1.ultimo_episodio_em == nil))

    mudar(:revogada, op, sessao)
    assert Platform.listar_organizacoes(sessao) == {:error, :nao_autorizado}
  end

  defp mudar(:encerrada, _op, sessao), do: Sessions.encerrar(sessao)

  defp mudar(:vencida, _op, sessao),
    do:
      atualizar_sessao(sessao,
        inserted_at: DateTime.add(DateTime.utc_now(:second), -8 * 3600 - 1)
      )

  defp mudar(:inativa, _op, sessao),
    do:
      atualizar_sessao(sessao,
        last_seen_at: DateTime.add(DateTime.utc_now(:second), -30 * 60 - 1)
      )

  defp mudar(:epoca, op, _sessao),
    do: Repo.update_all(from(o in Operator, where: o.id == ^op.id), inc: [password_epoch: 1])

  defp mudar(:revogada, op, _sessao),
    do:
      Repo.update_all(from(g in Grant, where: g.operator_id == ^op.id),
        set: [
          revoked_at: DateTime.utc_now(:second),
          revoked_via: "release_command",
          revoked_by_declared: "quem rodou"
        ]
      )

  defp atualizar_sessao(sessao, campos),
    do: Repo.update_all(from(s in OperatorSession, where: s.id == ^sessao.id), set: campos)
end
