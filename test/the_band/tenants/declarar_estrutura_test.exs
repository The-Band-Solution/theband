defmodule TheBand.Tenants.DeclararEstruturaTest do
  @moduledoc """
  Feature 055 — quem pode declarar equipe, e onde.

  A regra decidida em 2026-09-01: **cada escopo declara o tipo que ele nomeia**.
  Escopo `organization` numa organização declara a equipe da estrutura DELA;
  escopo `project` num projeto declara a equipe de trabalho DAQUELE projeto.

  **A recusa cruzada é o caso que decide.** Sem ela, a implementação óbvia —
  *"tem escopo? pode"* — passa, e quem tem escopo numa organização passa a
  declarar em todas.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Tenants
  alias TheBand.Tenants.Access

  setup do
    tenant = tenant_fixture()
    admin = user_fixture(tenant, "admin")
    acme = organization_fixture(tenant, "acme")
    globex = organization_fixture(tenant, "globex")

    {:ok, pessoa} =
      Tenants.create_user(tenant, %{
        "email" => "p-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    %{tenant: tenant, admin: admin, acme: acme, globex: globex, pessoa: pessoa}
  end

  describe "escopo de organização declara equipe da estrutura" do
    test "na organização que o escopo nomeia, pode", ctx do
      {:ok, _} = Tenants.grant_scope(ctx.tenant, ctx.pessoa.id, :organization, ctx.acme.id, ctx.admin)

      assert {:ok, _} =
               Access.pode_declarar_estrutura(ctx.tenant, ctx.pessoa, :organization, ctx.acme.id)
    end

    test "NOUTRA organização, não pode — é a recusa cruzada", ctx do
      {:ok, _} = Tenants.grant_scope(ctx.tenant, ctx.pessoa.id, :organization, ctx.acme.id, ctx.admin)

      assert {:nao, _} =
               Access.pode_declarar_estrutura(ctx.tenant, ctx.pessoa, :organization, ctx.globex.id)
    end

    test "sem escopo nenhum, não pode", ctx do
      assert {:nao, _} =
               Access.pode_declarar_estrutura(ctx.tenant, ctx.pessoa, :organization, ctx.acme.id)
    end
  end

  describe "escopo de projeto declara equipe de projeto" do
    setup ctx do
      {:ok, p1} = SPO.create_project(ctx.tenant, %{"name" => "Alfa"}, ctx.admin.id)
      {:ok, p2} = SPO.create_project(ctx.tenant, %{"name" => "Beta"}, ctx.admin.id)
      Map.merge(ctx, %{p1: p1, p2: p2})
    end

    test "no projeto que o escopo nomeia, pode", ctx do
      {:ok, _} = Tenants.grant_scope(ctx.tenant, ctx.pessoa.id, :project, ctx.p1.id, ctx.admin)

      assert {:ok, _} = Access.pode_declarar_estrutura(ctx.tenant, ctx.pessoa, :project, ctx.p1.id)
    end

    test "NOUTRO projeto, não pode", ctx do
      {:ok, _} = Tenants.grant_scope(ctx.tenant, ctx.pessoa.id, :project, ctx.p1.id, ctx.admin)

      assert {:nao, _} = Access.pode_declarar_estrutura(ctx.tenant, ctx.pessoa, :project, ctx.p2.id)
    end

    test "escopo de PROJETO não declara equipe de ORGANIZAÇÃO", ctx do
      # O escopo nomeia um projeto; equipe da estrutura pertence a organização.
      # Deixar passar seria o escopo significando duas coisas.
      {:ok, _} = Tenants.grant_scope(ctx.tenant, ctx.pessoa.id, :project, ctx.p1.id, ctx.admin)

      assert {:nao, _} =
               Access.pode_declarar_estrutura(ctx.tenant, ctx.pessoa, :organization, ctx.acme.id)
    end
  end

  describe "escopo de equipe não declara nada" do
    test "quem tem escopo de uma equipe não declara equipe alguma", ctx do
      equipe = team_fixture(ctx.tenant, "T1", %{organization: ctx.acme})
      {:ok, _} = Tenants.grant_scope(ctx.tenant, ctx.pessoa.id, :team, equipe.id, ctx.admin)

      assert {:nao, _} =
               Access.pode_declarar_estrutura(ctx.tenant, ctx.pessoa, :organization, ctx.acme.id)
    end
  end

  describe "quem administra" do
    test "declara em qualquer organização do tenant", ctx do
      assert {:ok, :admin} =
               Access.pode_declarar_estrutura(ctx.tenant, ctx.admin, :organization, ctx.globex.id)
    end
  end
end
