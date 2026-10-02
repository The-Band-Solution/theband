defmodule TheBandWeb.Plataforma.RevogacaoEmVooTest do
  @moduledoc """
  A revogação com o formulário aberto — spec 070, T054 (quickstart §5; cenário 3 de `seguranca.md`;
  O6, FR-014, A15).

  O operador abre o formulário de suspensão e, antes de enviá-lo, o papel é revogado (ou a
  credencial reiniciada). O envio não suspende nada, e a resposta é o `404`.

  Na tela, o plug também recusa, porque `Sessions.conferir/2` relê a concessão. A conferência
  **por dentro** do ato, que fecha a janela entre o plug e a transação, está provada em
  `test/the_band/platform/suspender_test.exs`, caso `:nao_autorizado`.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Platform.{Grants, OperatorSession, Suspension}
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  setup %{conn: conn} do
    {op, _} = operador_pronto()
    a = tenant_fixture()
    conn = log_in_operador(conn, op)
    assert conn |> get(~p"/platform/organizations/#{a.slug}") |> html_response(200) =~ "Suspend"
    %{conn: conn, op: op, a: a}
  end

  defp enviar(conn, a) do
    capture_log(fn ->
      r =
        post(conn, "/platform/organizations/#{a.slug}/suspension", %{
          "reason" => "contract_ended",
          "confirm_slug" => a.slug
        })

      send(self(), {:r, r})
    end)

    assert_received {:r, r}
    r
  end

  defp nada_aconteceu!(a) do
    assert Repo.get!(Tenant, a.id).status == "active"
    assert Repo.all(from(s in Suspension, where: s.tenant_id == ^a.id)) == []
  end

  test "o papel revogado com o formulário aberto: 404, A continua ativa, a sessão encerrada",
       ctx do
    capture_log(fn -> {:ok, _} = Grants.revogar(ctx.op.email, "quem rodou", nil) end)

    assert html_response(enviar(ctx.conn, ctx.a), 404)
    nada_aconteceu!(ctx.a)

    sessoes = Repo.all(from(s in OperatorSession, where: s.operator_id == ^ctx.op.id))
    assert sessoes != [] and Enum.all?(sessoes, & &1.ended_at)
  end

  test "A15: a credencial reiniciada com o formulário aberto também dá 404", ctx do
    capture_log(fn -> {:ok, _} = Grants.reiniciar_credencial(ctx.op.email, "quem rodou") end)

    assert html_response(enviar(ctx.conn, ctx.a), 404)
    nada_aconteceu!(ctx.a)
  end
end
