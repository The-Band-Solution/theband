defmodule TheBandWeb.Api.RosterSemEmailTest do
  @moduledoc """
  `GET /api/v1/teams/:id/members` não devolve o e-mail de ninguém, e não quebra com quem saiu —
  achados N1 e N2 da revisão de segurança da implementação do MCP, em 2026-09-25.

  **O que estava em produção, na v0.9.1**:

  - **N1**: um vínculo marcado como equívoco saía com `mistake.por`, o **e-mail** de quem o
    marcou. O schema OpenAPI da própria rota diz que e-mail não sai;
  - **N2**: um vínculo encerrado saía com `ended_at` igual a uma **tupla**,
    `{:declarado, <e-mail>, …}`. O Jason não serializa tupla, e a rota respondia `500` para toda
    equipe com alguém que saiu. O e-mail de quem declarou a saída ia para o log de erro.

  Nenhum teste pegava, porque a fixture da 061 só tinha vínculo **observado e vigente**. Os dois
  campos que vazavam nunca eram povoados. Este arquivo monta os dois casos.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  @email ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    {:ok, _t, valor} = Tenants.create_api_token(tenant, admin, %{label: "n1"}, admin)

    org = organization_fixture(tenant, "acme-#{System.unique_integer([:positive])}")
    equipe = team_fixture(tenant, "T_#{System.unique_integer([:positive])}", %{organization: org})
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    saiu = pessoa(tenant, "saiu")
    engano = pessoa(tenant, "engano")

    for p <- [saiu, engano] do
      {:ok, _} =
        EO.declare_team_membership(
          tenant,
          equipe.id,
          p.id,
          %{
            organizational_role_id: papel.id,
            started_at: DateTime.add(DateTime.utc_now(:second), -30, :day)
          },
          admin.id
        )
    end

    # N2: a saída declarada por alguém, que carrega o e-mail de quem declarou.
    {:ok, _} =
      EO.record_team_departure(tenant, equipe.id, saiu.id, DateTime.utc_now(:second), admin.id)

    # N1: o equívoco marcado por alguém, que carrega o e-mail de quem marcou.
    {:ok, _} =
      EO.record_team_membership_mistake(tenant, equipe.id, engano.id, "pessoa errada", admin.id)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> valor)
      |> put_req_header("accept", "application/json")

    %{conn: conn, admin: admin, equipe: equipe, saiu: saiu, engano: engano}
  end

  test "a rota responde, mesmo com quem saiu (N2)", ctx do
    r = get(ctx.conn, ~p"/api/v1/teams/#{ctx.equipe.id}/members")

    assert r.status == 200, "a rota quebrou com um vínculo encerrado: #{r.status}"
  end

  test "nenhum e-mail sai, nem de quem encerrou, nem de quem marcou o equívoco (N1)", ctx do
    corpo = ctx.conn |> get(~p"/api/v1/teams/#{ctx.equipe.id}/members") |> response(200)

    refute corpo =~ ctx.admin.email, "a rota devolveu o e-mail de quem declarou: #{corpo}"
    refute Regex.match?(@email, corpo), "a rota devolveu um e-mail: #{corpo}"
  end

  test "a guarda: a saída e o equívoco continuam na resposta, sem o autor", ctx do
    membros =
      ctx.conn
      |> get(~p"/api/v1/teams/#{ctx.equipe.id}/members")
      |> json_response(200)
      |> Map.fetch!("data")
      |> Map.new(&{&1["login"], &1})

    [saida] = membros["saiu"]["memberships"]
    assert saida["ended_at"], "a saída sumiu, em vez de sair sem o autor"
    assert saida["end_origin"] == "declared"

    [engano] = membros["engano"]["memberships"]
    assert engano["mistake"]["reason"] == "pessoa errada"
    assert engano["mistake"]["at"]
    refute Map.has_key?(engano["mistake"], "por")
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    p
  end
end
