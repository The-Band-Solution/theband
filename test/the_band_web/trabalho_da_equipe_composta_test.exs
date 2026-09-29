defmodule TheBandWeb.TrabalhoDaEquipeCompostaTest do
  @moduledoc """
  O trabalho aberto de uma equipe composta — issue #987.

  A equipe composta é a **união distinta** dela e das partes com composição vigente (spec 060,
  FR-056; na ontologia, `eo.team_part_of_team` é parthood entre coletivos). É a definição do
  roster, e passa a ser a da API `/measures` e do `team_open_work` da MCP.

  O cenário tem as três formas que distinguem união de soma e de só-diretos:

  - **Ana**, só na equipe-mãe;
  - **Bia**, só numa parte. Era ela quem sumia;
  - **Caio**, em duas partes. Ele conta uma vez, e a tarefa dele também.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.MCP.Ferramentas
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    org = cenario.organization
    {:ok, mae} = EO.declare_structural_team(tenant, org.id, "Mãe", admin.id)
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)
    {:ok, _t, token} = Tenants.create_api_token(tenant, admin, %{label: "987"}, admin)

    ctx = %{
      conn: conn,
      tenant: tenant,
      admin: admin,
      org: org,
      mae: mae,
      papel: papel,
      token: token,
      repo_id: cenario.observed_repository_id
    }

    azul = parte(ctx, "Azul")
    verde = parte(ctx, "Verde")
    [ana, bia, caio] = for l <- ~w(ana987 bia987 caio987), do: pessoa(ctx, l)

    vincular(ctx, mae, ana)
    vincular(ctx, azul, bia)
    vincular(ctx, azul, caio)
    vincular(ctx, verde, caio)

    issue(ctx, "I_ana", [ana])
    issue(ctx, "I_bia", [bia])
    issue(ctx, "I_caio", [caio])

    # Uma fechada dentro da janela, de quem está SÓ numa parte: sem ela, `closed_in_window` não
    # seria medido, e uma contagem de fechadas pelos diretos passaria (visto na injeção).
    fechada = issue(ctx, "I_bia_fechada", [bia])

    Repo.update_all(
      from(i in CollectedIssue, where: i.id == ^fechada.id),
      set: [
        state: "CLOSED",
        external_closed_at: DateTime.add(DateTime.utc_now(:second), -2, :day)
      ]
    )

    Map.merge(ctx, %{azul: azul, ana: ana, bia: bia, caio: caio})
  end

  defp parte(ctx, nome) do
    {:ok, t} = EO.declare_structural_team(ctx.tenant, ctx.org.id, nome, ctx.admin.id)
    {:ok, _} = EO.compose_teams(ctx.tenant, t.id, ctx.mae.id, ctx.admin.id)
    t
  end

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => login}
      })

    p
  end

  defp vincular(ctx, equipe, pessoa) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: ctx.papel.id,
        declared_by_user_id: ctx.admin.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -300, :day)
      })
  end

  defp issue(ctx, externo, designados) do
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
        external_created_at: DateTime.add(DateTime.utc_now(:second), -10, :day),
        collected_at: DateTime.utc_now(:second)
      })

    for d <- designados do
      Repo.insert!(%IssueAssignee{
        tenant_id: ctx.tenant.id,
        collected_issue_id: i.id,
        login: d.login,
        person_id: d.id
      })
    end

    i
  end

  defp medidas(ctx, equipe) do
    ctx.conn
    |> put_req_header("authorization", "Bearer " <> ctx.token)
    |> get(~p"/api/v1/teams/#{equipe.id}/measures")
    |> json_response(200)
    |> Map.fetch!("data")
  end

  defp pessoas(lista, chave), do: lista |> Enum.map(& &1[chave]) |> Enum.sort()

  test "a API conta a equipe e as partes, uma vez cada, e não só os diretos", ctx do
    d = medidas(ctx, ctx.mae)

    # 3 pessoas distintas (Caio está em duas partes), 3 tarefas distintas.
    assert d["work"]["members"] == 3
    assert d["work"]["open"] == 3
    assert d["work"]["closed_in_window"] == 1

    assert pessoas(d["open_by_person"], "person_id") ==
             Enum.sort([ctx.ana.id, ctx.bia.id, ctx.caio.id])
  end

  test "a MCP diz is_composed: true e concorda com o roster e com a API", ctx do
    r =
      Ferramentas.chamar(ctx.tenant, ctx.admin, "team_open_work", %{"team_id" => ctx.mae.id}, %{
        token_public_id: "tb_987"
      })

    assert r.state == "checked"
    assert r.composition.is_composed == true
    assert r.composition.note =~ "not the sum"
    assert r.value.totals == %{members: 3, open: 3}

    assert pessoas(r.value.by_person, :person_id) ==
             Enum.sort([ctx.ana.id, ctx.bia.id, ctx.caio.id])

    roster =
      Ferramentas.chamar(ctx.tenant, ctx.admin, "team_roster", %{"team_id" => ctx.mae.id}, %{
        token_public_id: "tb_987"
      })

    assert roster.composition.is_composed == r.composition.is_composed
  end

  test "a parte sozinha continua contando só os dela, e a equipe simples diz is_composed: false",
       ctx do
    d = medidas(ctx, ctx.azul)
    assert d["work"]["members"] == 2
    assert pessoas(d["open_by_person"], "person_id") == Enum.sort([ctx.bia.id, ctx.caio.id])

    r =
      Ferramentas.chamar(ctx.tenant, ctx.admin, "team_open_work", %{"team_id" => ctx.azul.id}, %{
        token_public_id: "tb_987"
      })

    assert r.composition.is_composed == false
  end
end
