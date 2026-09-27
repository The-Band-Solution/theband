defmodule TheBandWeb.Api.RecusaDeEquipeRegistradaTest do
  @moduledoc """
  A recusa de equipe deixa rastro, na API e na tela — feature 062, T022, achado N6 do inventário
  de 2026-09-24.

  Antes, `GET /api/v1/teams/:id` fora do alcance caía num `404` sem registro nenhum, e a tela da
  equipe escondia a quebra por pessoa também sem registro. A pergunta *"esta conta tentou ler o
  painel de qual equipe?"* não tinha resposta, e é a que a FR-024 da 045 aponta como o caminho
  para perceber agregação.

  **A guarda** está nos dois lados: quem alcança a equipe **não** deixa evento de recusa. Sem
  ela, um registro que gravasse toda chamada passaria no teste da recusa.
  """
  use TheBandWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, membro} =
      Tenants.create_user(tenant, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    org = organization_fixture(tenant, "acme-#{System.unique_integer([:positive])}")
    equipe = team_fixture(tenant, "T_#{System.unique_integer([:positive])}", %{organization: org})

    # A GUARDA DO CENÁRIO: o membro não alcança a equipe, e o admin alcança.
    assert {:nao, :fora_do_alcance} = Tenants.pode_ver_equipe(tenant, membro, equipe.id)
    assert {:ok, :admin} = Tenants.pode_ver_equipe(tenant, admin, equipe.id)

    %{conn: conn, tenant: tenant, admin: admin, membro: membro, equipe: equipe}
  end

  defp com_token(conn, tenant, dono) do
    {:ok, _t, valor} = Tenants.create_api_token(tenant, dono, %{label: "n6"}, dono)

    conn
    |> put_req_header("authorization", "Bearer " <> valor)
    |> put_req_header("accept", "application/json")
  end

  describe "a API" do
    test "fora do alcance, o 404 deixa o evento, com a equipe e o request_id", ctx do
      {r, log} =
        with_log(fn ->
          ctx.conn |> com_token(ctx.tenant, ctx.membro) |> get(~p"/api/v1/teams/#{ctx.equipe.id}")
        end)

      assert r.status == 404
      [request_id] = get_resp_header(r, "x-request-id")

      [linha] = log |> String.split("\n") |> Enum.filter(&(&1 =~ "acesso: equipe recusada"))
      assert linha =~ ~s(alvo_team_id="#{ctx.equipe.id}")
      assert linha =~ "motivo=:fora_do_alcance"
      assert linha =~ request_id
    end

    test "a guarda: com alcance, nenhum evento de recusa", ctx do
      {r, log} =
        with_log(fn ->
          ctx.conn |> com_token(ctx.tenant, ctx.admin) |> get(~p"/api/v1/teams/#{ctx.equipe.id}")
        end)

      assert r.status == 200
      refute log =~ "equipe recusada"
    end
  end

  describe "a tela da equipe" do
    test "sem alcance, a quebra por pessoa escondida deixa o evento", ctx do
      log =
        capture_log(fn ->
          {:ok, _live, _html} =
            ctx.conn |> log_in(ctx.membro) |> live(~p"/teams/#{ctx.equipe.id}?tab=review")
        end)

      assert log =~ "acesso: equipe recusada"
      assert log =~ ~s(alvo_team_id="#{ctx.equipe.id}")
    end

    test "a guarda: com alcance, nenhum evento de recusa", ctx do
      log =
        capture_log(fn ->
          {:ok, _live, _html} =
            ctx.conn |> log_in(ctx.admin) |> live(~p"/teams/#{ctx.equipe.id}?tab=review")
        end)

      refute log =~ "equipe recusada"
    end
  end
end
