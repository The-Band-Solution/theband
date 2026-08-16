defmodule TheBand.Ontology.SEON.SPO.GestaoDoProjetoTest do
  @moduledoc """
  O ciclo de vida do projeto declarado e os vínculos novos — feature 028.

  ## As asserções que carregam este arquivo

  1. **remover é marca** — a linha permanece, sai das listagens, e não há undelete;
  2. **remover com partes é recusado** — cascata apagaria declarações que ninguém pediu;
  3. **a equipe declarada nasce project_team, sem organização, com autor** — e a
     constraint da EO aceita, porque o vínculo com o projeto é o que a justifica;
  4. **religar revive o vigente** — nunca duas linhas vigentes para o mesmo par.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    {:ok, projeto} = SPO.create_project(tenant, %{name: "Alfa"}, admin.id)

    %{tenant: tenant, admin: admin, projeto: projeto}
  end

  describe "editar — FR-001" do
    test "alcança nome e período, e grava o autor da mudança", ctx do
      {:ok, editado} =
        SPO.update_project(
          ctx.tenant,
          ctx.projeto.id,
          %{name: "Alfa 2", started_on: ~D[2026-01-01]},
          ctx.admin.id
        )

      assert editado.name == "Alfa 2"
      assert editado.started_on == ~D[2026-01-01]
      assert editado.updated_by_user_id == ctx.admin.id
    end

    test "não alcança o pai — mover é set_parent, com a regra de ciclo", ctx do
      {:ok, outro} = SPO.create_project(ctx.tenant, %{name: "Beta"}, ctx.admin.id)

      {:ok, editado} =
        SPO.update_project(ctx.tenant, ctx.projeto.id, %{parent_id: outro.id}, ctx.admin.id)

      assert editado.parent_id == nil,
             "a edição moveu o projeto na hierarquia — a validação de ciclo não rodou"
    end
  end

  describe "remover — FR-002 e FR-003" do
    test "é marca: sai da listagem, permanece no banco, sem undelete", ctx do
      {:ok, removido} = SPO.remove_project(ctx.tenant, ctx.projeto.id, ctx.admin.id)

      assert removido.removed_at != nil
      assert removido.removed_by_user_id == ctx.admin.id

      refute Enum.any?(SPO.list_projects(ctx.tenant), &(&1.id == ctx.projeto.id))

      assert Repo.get(TheBand.Ontology.SEON.SPO.Schemas.Project, ctx.projeto.id) != nil,
             "a linha foi apagada — remover é marca, e a declaração desfeita continua consultável"
    end

    test "com partes é recusado, e a parte continua no lugar", ctx do
      {:ok, parte} = SPO.create_project(ctx.tenant, %{name: "Parte"}, ctx.admin.id)
      {:ok, _} = SPO.set_parent(ctx.tenant, parte.id, ctx.projeto.id)

      assert {:error, :has_parts} =
               SPO.remove_project(ctx.tenant, ctx.projeto.id, ctx.admin.id)

      assert Enum.any?(SPO.list_projects(ctx.tenant), &(&1.id == ctx.projeto.id))
    end
  end

  describe "organizações — FR-004" do
    test "associa com autor, desassocia com marca, religa revivendo", ctx do
      [org | _] = EO.list_organizations(ctx.tenant) |> organizacoes_ou_semente(ctx)

      {:ok, v1} = SPO.link_organization(ctx.tenant, ctx.projeto.id, org.id, ctx.admin.id)
      assert v1.linked_by_user_id == ctx.admin.id

      # Religar o vigente devolve o MESMO vínculo — nunca duas linhas vigentes.
      {:ok, v2} = SPO.link_organization(ctx.tenant, ctx.projeto.id, org.id, ctx.admin.id)
      assert v2.id == v1.id

      {:ok, desfeito} = SPO.unlink_organization(ctx.tenant, v1.id, ctx.admin.id)
      assert desfeito.unlinked_at != nil

      assert SPO.list_project_organizations(ctx.tenant, ctx.projeto.id) == []

      # Religar depois de desfazer cria linha NOVA — a história dos vínculos é o dado.
      {:ok, v3} = SPO.link_organization(ctx.tenant, ctx.projeto.id, org.id, ctx.admin.id)
      assert v3.id != v1.id
    end
  end

  describe "equipes — FR-006 a FR-009" do
    test "a equipe declarada nasce project_team, sem organização, com autor", ctx do
      {:ok, equipe} = EO.create_declared_team(ctx.tenant, "Time Alfa", ctx.admin.id)

      assert equipe.type == "project_team"
      assert equipe.organization_id == nil
      assert equipe.declared_by_user_id == ctx.admin.id
      assert equipe.source_instance == "declared"
    end

    test "o vínculo com o projeto carrega a proveniência para a tela separar", ctx do
      {:ok, equipe} = EO.create_declared_team(ctx.tenant, "Time Beta", ctx.admin.id)
      {:ok, _} = SPO.link_team(ctx.tenant, ctx.projeto.id, equipe.id, ctx.admin.id)

      assert [vinculada] = SPO.list_project_teams(ctx.tenant, ctx.projeto.id)
      assert vinculada.name == "Time Beta"

      assert vinculada.declared == true,
             "a proveniência sumiu do vínculo — declarada e observada são a distinção que o produto existe para manter"
    end
  end

  # O tenant do fixture pode nascer sem organização observada; semear uma é mais honesto
  # que pular o teste — o vínculo precisa de uma organização real do MESMO tenant.
  defp organizacoes_ou_semente([], ctx) do
    {:ok, org} =
      EO.upsert_organization_from_source(ctx.tenant, %{
        login: "org-teste",
        name: "Org Teste",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "O_teste",
        collected_at: DateTime.utc_now(:second)
      })

    [org]
  end

  defp organizacoes_ou_semente(orgs, _ctx), do: orgs
end
