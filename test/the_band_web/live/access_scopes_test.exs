defmodule TheBandWeb.AccessScopesTest do
  @moduledoc """
  /access-scopes — feature 045, US2.

  Derivado com hachura e SEM Revoke (FR-021); concessão sem alvo recusada com a
  frase (FR-007); revogação marca e some da vigência.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")

    {:ok, member} =
      Tenants.create_user(tenant, %{
        "email" => "conta-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, member: member, org: org}
  end

  test "member não alcança a gestão", ctx do
    assert {:error, {:redirect, %{to: "/people"}}} =
             build_conn() |> log_in(ctx.member) |> live(~p"/access-scopes")
  end

  test "concessão sem alvo é recusada com a frase do motivo (FR-007)", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/access-scopes")

    html =
      render_submit(view, "grant", %{
        "user_id" => ctx.member.id,
        "level" => "organization",
        "target_id" => ""
      })

    assert html =~ "Escolha a organização — escopo organization não existe sem alvo."
  end

  test "conceder mostra proveniência; revogar marca e some da vigência", ctx do
    {:ok, view, _} = live(ctx.conn, ~p"/access-scopes")

    html =
      render_submit(view, "grant", %{
        "user_id" => ctx.member.id,
        "level" => "organization",
        "target_id" => ctx.org.id
      })

    assert html =~ "Escopo organization concedido."
    assert html =~ ctx.admin.email

    grant =
      Repo.one!(
        from g in TheBand.Tenants.Access.ScopeGrant,
          where: g.user_id == type(^ctx.member.id, :binary_id) and is_nil(g.revoked_at)
      )

    html = render_click(view, "revoke", %{"id" => grant.id})
    assert html =~ "Escopo revogado."

    # A linha fica no banco — marca, nunca delete.
    assert Repo.get!(TheBand.Tenants.Access.ScopeGrant, grant.id).revoked_at
  end

  test "derivado aparece com a origem e sem botão de revogar (FR-021)", ctx do
    pessoa =
      elem(
        EO.upsert_person_from_source(
          ctx.tenant,
          Map.merge(source_attrs("U_dev"), %{name: "dev", login: "dev", account_type: "person"})
        ),
        1
      )

    {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.member.id, pessoa.id, ctx.admin.id)
    {:ok, equipe} = EO.create_declared_team(ctx.tenant, "Plataforma", ctx.admin.id)

    Repo.update_all(
      from(x in "eo_teams",
        where: x.id == type(^equipe.id, :binary_id),
        update: [set: [organization_id: type(^ctx.org.id, :binary_id)]]
      ),
      []
    )

    papel =
      elem(EO.create_role(ctx.tenant, ctx.org.id, %{code: "dev", name: "Dev"}, ctx.admin.id), 1)

    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        started_at: DateTime.utc_now(:second)
      })

    {:ok, _view, html} = live(build_conn() |> log_in(ctx.admin), ~p"/access-scopes")

    assert html =~ "team · derivado"
    assert html =~ "vínculo pessoa-equipe"
    assert html =~ "fecha com o fato"

    # O derivado não tem Revoke: o botão só existe ao lado de concessão.
    [bloco_da_conta] =
      html |> String.split(ctx.member.email) |> Enum.drop(1) |> Enum.take(1)

    bloco_ate_proxima_secao = bloco_da_conta |> String.split("</section>") |> hd()
    refute bloco_ate_proxima_secao =~ "Revoke"
  end
end
