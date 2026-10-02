defmodule TheBandWeb.Plataforma.CorridaDaReativacaoTest do
  @moduledoc """
  A corrida entre entrar e suspender — spec 070, T052 (cenário 4 de `seguranca.md`; O8, FR-015).

  A entrada leu a organização `active` antes da suspensão e gravou a sessão depois dela. A
  reativação encerra de novo toda sessão aberta, e por isso essa sessão também cai.
  """
  use TheBandWeb.ConnCase, async: false

  import TheBand.SuspensaoFixtures

  alias TheBand.Platform
  alias TheBand.Segredo
  alias TheBand.Tenants.Sessions

  test "a sessão gravada durante a suspensão vai para /sign-in depois da reativação" do
    {_op, sessao_op} = sessao_de_operador()
    %{tenant: a, admin: admin} = organizacao_povoada()

    {:ok, _} = Platform.suspender(sessao_op, a.slug, %{reason: "contract_ended"})

    # Inserida direto, como a entrada que leu `active` antes do ato.
    {:ok, {sessao, segredo}} = Sessions.abrir(admin)

    {:ok, _} = Platform.reativar(sessao_op, a.slug, %{reason: "contract_resumed"})

    conn =
      Plug.Test.init_test_session(build_conn(), %{
        "session_id" => sessao.id,
        "session_secret" => Segredo.expor(segredo)
      })

    assert redirected_to(get(conn, ~p"/people")) == ~p"/sign-in"
  end
end
