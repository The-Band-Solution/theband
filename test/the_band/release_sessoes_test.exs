defmodule TheBand.ReleaseSessoesTest do
  @moduledoc """
  O giro de todas as sessões pelo release — feature 064, T016. É o comando que o runbook §10
  manda rodar, e ele precisa fazer o que o texto diz: toda sessão aberta passa a estar encerrada,
  e um cookie de antes deixa de valer.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureIO

  alias TheBand.Release
  alias TheBand.Repo
  alias TheBand.Tenants.Schemas.UserSession

  test "encerra todas as sessões abertas, e o cookie de antes cai", %{conn: conn} do
    {_tenant, a} = tenant_with_admin()
    {_outro, b} = tenant_with_admin()

    conn_a = log_in(conn, a)
    assert get(conn_a, ~p"/people").status == 200
    _ = log_in(build_conn(), b)

    saida = capture_io(fn -> assert :ok = Release.encerrar_todas_as_sessoes() end)

    assert saida =~ "sessão(ões) encerrada(s)"
    assert Repo.aggregate(from(s in UserSession, where: is_nil(s.ended_at)), :count) == 0
    assert redirected_to(get(conn_a, ~p"/people")) == ~p"/sign-in"
  end
end
