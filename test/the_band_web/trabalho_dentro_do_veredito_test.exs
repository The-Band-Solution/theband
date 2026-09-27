defmodule TheBandWeb.TrabalhoDentroDoVereditoTest do
  @moduledoc """
  As mudanças e as discussões de uma pessoa são **trabalho**, e passam pelo veredito — #989.

  Até a v0.9.2 as duas viviam em *Where this came from*, fora do painel que `pode_ver/3`
  protege, e eram carregadas para qualquer conta do tenant. A API as devolvia "porque na tela
  também estão fora". O efeito: quem a tela recusava lia, pelas duas portas, o título dos PRs
  que a pessoa abriu e o título das issues em que ela comentou.

  **A guarda contra o `refute` vazio**: o cenário povoa um PR e uma discussão com títulos
  únicos, e a conta admin **vê** os dois nas duas portas. Sem isso, "a conta recusada não vê"
  passaria com o dado ausente, e passaria igual com o furo aberto.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.Communication.Commands, as: CommunicationCommands
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.Tenants.Access

  @titulo_do_pr "PR-QUE-SO-O-VEREDITO-ABRE"
  @titulo_da_issue "ISSUE-DA-DISCUSSAO-QUE-SO-O-VEREDITO-ABRE"

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    {:ok, alvo} =
      EO.upsert_person_from_source(tenant, %{
        login: "alvo-989",
        name: "Alvo 989",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/alvo-989",
        external_id: "U_alvo_989",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, _} =
      ChangeCommands.record_change_request(tenant, %{
        observed_repository_id: cenario.observed_repository_id,
        number: 9890,
        title: @titulo_do_pr,
        state: "MERGED",
        author_login: alvo.login,
        author_person_id: alvo.id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_9890"
      })

    {:ok, issue} =
      TheBand.WorkItems.record_collected_issue(tenant, %{
        observed_repository_id: cenario.observed_repository_id,
        number: 9891,
        title: @titulo_da_issue,
        state: "OPEN",
        issue_type: "Task",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_9891"
      })

    {:ok, _} =
      CommunicationCommands.record_comment(tenant, %{
        collected_issue_id: issue.id,
        body: "comentário",
        author_login: alvo.login,
        author_person_id: alvo.id,
        external_published_at: DateTime.utc_now(:second),
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "C_9891"
      })

    {:ok, recusada} =
      Tenants.create_user(tenant, %{
        "email" => "recusada-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{conn: conn, tenant: tenant, admin: admin, alvo: alvo, recusada: recusada}
  end

  defp tela(ctx, conta) do
    {:ok, _view, html} =
      ctx.conn |> recycle() |> log_in(conta) |> live(~p"/people/#{ctx.alvo.id}")

    html
  end

  defp api(ctx, conta) do
    {:ok, _t, valor} = Tenants.create_api_token(ctx.tenant, conta, %{label: "989"}, ctx.admin)

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
    test "quem o veredito recusa não vê o título do PR nem o da discussão", ctx do
      html = tela(ctx, ctx.recusada)

      refute html =~ @titulo_do_pr, "a tela mostrou o PR a quem o veredito recusa"
      refute html =~ @titulo_da_issue, "a tela mostrou a discussão a quem o veredito recusa"
      # A identidade e a proveniência continuam: é a pessoa, e não o trabalho dela.
      assert html =~ "Where this came from"
    end

    test "e quem o veredito concede vê os dois — o que prova que o refute não é vazio", ctx do
      html = tela(ctx, ctx.admin)

      assert html =~ @titulo_do_pr
      assert html =~ @titulo_da_issue
    end
  end

  describe "GET /api/v1/people/:id" do
    test "quem o veredito recusa recebe null nas duas, como em work", ctx do
      r = api(ctx, ctx.recusada)
      d = json_response(r, 200)["data"]

      assert d["access"]["can_see_work"] == false
      assert d["changes"] == nil
      assert d["discussion_participation"] == nil
      refute r.resp_body =~ @titulo_do_pr, "a API devolveu o PR a quem o veredito recusa"

      refute r.resp_body =~ @titulo_da_issue,
             "a API devolveu a discussão a quem o veredito recusa"
    end

    test "e quem o veredito concede recebe os dois", ctx do
      r = api(ctx, ctx.admin)

      assert r.resp_body =~ @titulo_do_pr
      assert r.resp_body =~ @titulo_da_issue
    end
  end
end
