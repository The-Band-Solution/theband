defmodule TheBandWeb.ColunaDoQuadroTest do
  @moduledoc """
  A coluna do quadro nas duas portas — feature 062, FR-033.

  `team_open_work` (MCP) e `GET /api/v1/teams/:id/measures` (API) trazem, em cada tarefa, em que
  quadro ela está e com que valores. As duas saem da mesma construção
  (`ItemPhase.quadros_das_issues/2`), e este arquivo prova que dizem a mesma coisa: a paridade
  das portas vale para o que elas afirmam, e não só para o veredito.

  **A guarda contra a igualdade vazia**: uma tarefa está num quadro, com dois campos, e a outra
  em nenhum. Se as duas portas devolvessem `[]` para tudo, a igualdade passaria, e o primeiro
  teste reprova antes.
  """
  use TheBandWeb.ConnCase, async: false

  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.ContadorDeConsultas
  alias TheBand.MCP.Ferramentas
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Projects
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.WorkItems.Schemas.{CollectedIssue, IssueAssignee}

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "quadro"}, admin)

    org = cenario.organization
    equipe = team_fixture(tenant, "T_quadro", %{organization: org})
    pessoa = pessoa(tenant, equipe)
    agora = DateTime.utc_now(:second)

    {:ok, quadro} =
      Projects.record_observed_project(tenant, %{
        connected_tool_id: cenario.tool.id,
        number: 43,
        title: "Conecta Fapes",
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVT_43",
        collected_at: agora
      })

    status = campo(tenant, quadro, "PVTSSF_status", "Status", "o_prog", "In Progress", agora)
    squad = campo(tenant, quadro, "PVTSSF_squad", "Squad", "o_green", "Green", agora)

    ctx = %{
      conn:
        conn
        |> put_req_header("authorization", "Bearer " <> valor)
        |> put_req_header("accept", "application/json"),
      tenant: tenant,
      admin: admin,
      equipe: equipe,
      pessoa: pessoa,
      repo_id: cenario.observed_repository_id,
      quadro: quadro,
      campos: [{status, "o_prog", "In Progress"}, {squad, "o_green", "Green"}],
      agora: agora
    }

    no_quadro = issue(ctx, "I_no_quadro")
    no_quadro_nos_campos(ctx, no_quadro, "A")
    fora = issue(ctx, "I_fora")

    Map.merge(ctx, %{no_quadro: no_quadro, fora: fora})
  end

  defp pessoa(tenant, equipe) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        login: "quadrista",
        name: "Quadrista",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_quadrista",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: p.id,
        team_id: equipe.id,
        person_external_id: "U_quadrista",
        team_external_id: "T_quadro",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.add(DateTime.utc_now(:second), -30, :day)
      })

    p
  end

  defp campo(tenant, quadro, id, nome, opcao, rotulo, agora) do
    {:ok, f} =
      Projects.record_field_definition(tenant, %{
        observed_project_id: quadro.id,
        field_external_id: id,
        name: nome,
        data_type: "SINGLE_SELECT",
        options: [%{"id" => opcao, "name" => rotulo}],
        collected_at: agora
      })

    f
  end

  defp issue(ctx, externo) do
    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 100_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "issue #{externo}",
        state: "OPEN",
        external_created_at: DateTime.add(ctx.agora, -5, :day),
        collected_at: ctx.agora
      })

    Repo.insert!(%IssueAssignee{
      tenant_id: ctx.tenant.id,
      collected_issue_id: i.id,
      login: "quadrista",
      person_id: ctx.pessoa.id
    })

    i
  end

  defp no_quadro_nos_campos(ctx, issue, sufixo) do
    {:ok, item} =
      Projects.record_item(ctx.tenant, %{
        observed_project_id: ctx.quadro.id,
        collected_issue_id: issue.id,
        is_draft: false,
        source_system: "github",
        source_instance: "https://github.com",
        source_external_id: "PVTI_#{sufixo}",
        collected_at: ctx.agora,
        last_observed_at: ctx.agora
      })

    for {f, opcao, rotulo} <- ctx.campos do
      {:ok, _} =
        Projects.record_item_field_value(ctx.tenant, %{
          project_item_id: item.id,
          project_field_definition_id: f.id,
          raw_value: %{"optionId" => opcao, "name" => rotulo},
          collected_at: ctx.agora,
          last_observed_at: ctx.agora
        })
    end
  end

  defp mcp(ctx) do
    r =
      Ferramentas.chamar(
        ctx.tenant,
        ctx.admin,
        "team_open_work",
        %{"team_id" => ctx.equipe.id},
        %{
          token_public_id: "tb_quadro"
        }
      )

    assert r.state == "checked", inspect(r)
    for p <- r.value.by_person, t <- p.tasks, into: %{}, do: {t.issue_id, t.boards}
  end

  defp api(ctx) do
    d =
      ctx.conn
      |> recycle()
      |> get(~p"/api/v1/teams/#{ctx.equipe.id}/measures")
      |> json_response(200)

    for p <- d["data"]["open_by_person"],
        t <- p["tasks"],
        into: %{},
        do: {t["issue_id"], t["boards"]}
  end

  # A forma do MCP, sem a marca de texto de terceiro e em chaves de texto: a da API.
  defp sem_marca(%{untrusted_text: t}), do: t
  defp sem_marca(%DateTime{} = d), do: DateTime.to_iso8601(d)
  defp sem_marca(%{} = m), do: Map.new(m, fn {k, v} -> {to_string(k), sem_marca(v)} end)
  defp sem_marca(l) when is_list(l), do: Enum.map(l, &sem_marca/1)
  defp sem_marca(v), do: v

  test "o MCP traz o quadro, todos os campos marcados, e a fase não declarada", ctx do
    quadros = mcp(ctx)

    assert [quadro] = quadros[ctx.no_quadro.id]
    assert quadro.board_id == ctx.quadro.id
    assert %{untrusted_text: "Conecta Fapes"} = quadro.board

    assert Enum.map(quadro.fields, &{&1.field.untrusted_text, &1.value.untrusted_text}) ==
             [{"Squad", "Green"}, {"Status", "In Progress"}]

    assert Enum.all?(quadro.fields, &(&1.phase == %{state: "not_declared"}))
    assert quadros[ctx.fora.id] == [], "a tarefa em nenhum quadro vem com lista vazia, e não some"
  end

  test "a API traz o mesmo, em texto", ctx do
    quadros = api(ctx)

    assert [%{"board" => "Conecta Fapes", "fields" => campos}] = quadros[ctx.no_quadro.id]

    assert Enum.map(campos, &{&1["field"], &1["value"]}) == [
             {"Squad", "Green"},
             {"Status", "In Progress"}
           ]

    assert quadros[ctx.fora.id] == []
  end

  test "as duas portas dizem a mesma coisa, tarefa a tarefa", ctx do
    no_mcp = Map.new(mcp(ctx), fn {id, q} -> {id, sem_marca(q)} end)
    na_api = api(ctx)

    assert map_size(no_mcp) == 2
    assert no_mcp == na_api
  end

  test "o custo não cresce com as tarefas: uma consulta para todos os quadros", ctx do
    um = ContadorDeConsultas.contar(fn -> mcp(ctx) end)

    for n <- 1..9 do
      i = issue(ctx, "I_mais_#{n}")
      no_quadro_nos_campos(ctx, i, "B#{n}")
    end

    onze = ContadorDeConsultas.contar(fn -> mcp(ctx) end)
    assert map_size(mcp(ctx)) == 11
    assert onze == um, "2 tarefas: #{um} consultas; 11 tarefas: #{onze}"
  end
end
