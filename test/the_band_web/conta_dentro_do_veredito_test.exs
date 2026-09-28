defmodule TheBandWeb.ContaDentroDoVereditoTest do
  @moduledoc """
  A conta de plataforma ligada a uma pessoa passa pelo veredito — #991.

  Até a v0.10.0, a seção *Which account is this person* da página da pessoa mostrava, para
  qualquer conta do tenant, o **e-mail** da conta ligada e a cobertura do elo. A API devolvia o
  bloco `account` com o id da conta. Medido em 2026-09-28 com uma conta `member` sem elo:
  `{:nao, :sem_elo_declarado}`, e o e-mail na tela.

  Decisão da pessoa mantenedora em 2026-09-28: quem vê o trabalho da pessoa vê a conta dela.

  **A guarda contra o `refute` vazio**: a pessoa tem uma conta ligada, com e-mail único, e o
  admin **vê** o e-mail na tela e o id na API.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.Tenants.Access

  @email "conta-que-so-o-veredito-abre@example.test"

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()

    {:ok, alvo} =
      EO.upsert_person_from_source(tenant, %{
        login: "alvo-991",
        name: "Alvo 991",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/alvo-991",
        external_id: "U_alvo_991",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, dono} = Tenants.create_user(tenant, %{"email" => @email, "role" => "member"})
    {:ok, _} = Tenants.declare_person(tenant, dono.id, alvo.id, admin.id)

    {:ok, recusada} =
      Tenants.create_user(tenant, %{
        "email" => "recusada-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{conn: conn, tenant: tenant, admin: admin, alvo: alvo, dono: dono, recusada: recusada}
  end

  defp tela(ctx, conta) do
    {:ok, _view, html} =
      ctx.conn |> recycle() |> log_in(conta) |> live(~p"/people/#{ctx.alvo.id}")

    html
  end

  defp api(ctx, conta) do
    {:ok, _t, valor} = Tenants.create_api_token(ctx.tenant, conta, %{label: "991"}, ctx.admin)

    ctx.conn
    |> recycle()
    |> put_req_header("authorization", "Bearer " <> valor)
    |> put_req_header("accept", "application/json")
    |> get(~p"/api/v1/people/#{ctx.alvo.id}")
  end

  test "a guarda do cenário: a conta é de facto recusada pelo veredito", ctx do
    assert {:nao, _} = Access.pode_ver(ctx.tenant, ctx.recusada, ctx.alvo.id)
    assert {:ok, :admin} = Access.pode_ver(ctx.tenant, ctx.admin, ctx.alvo.id)
  end

  describe "a tela da pessoa" do
    test "quem o veredito recusa não vê o e-mail da conta nem a cobertura do elo", ctx do
      html = tela(ctx, ctx.recusada)

      refute html =~ @email, "a tela mostrou o e-mail da conta a quem o veredito recusa"
      refute html =~ "accounts are linked", "a tela mostrou a cobertura do elo"
      refute html =~ ~s(id="account")
    end

    test "e quem o veredito concede vê — o que prova que o refute não é vazio", ctx do
      html = tela(ctx, ctx.admin)

      assert html =~ @email
      assert html =~ "accounts are linked"
    end
  end

  describe "GET /api/v1/people/:id" do
    test "quem o veredito recusa recebe account null", ctx do
      r = api(ctx, ctx.recusada)
      d = json_response(r, 200)["data"]

      assert d["access"]["can_see_work"] == false
      assert d["account"] == nil

      refute r.resp_body =~ ctx.dono.id,
             "a API devolveu o id da conta a quem o veredito recusa"
    end

    test "e quem o veredito concede recebe o id da conta", ctx do
      d = json_response(api(ctx, ctx.admin), 200)["data"]

      assert d["account"]["linked_user_id"] == ctx.dono.id
      assert d["account"]["link_coverage"]["declared"] >= 1
    end
  end
end
