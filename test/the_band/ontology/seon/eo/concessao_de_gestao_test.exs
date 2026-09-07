defmodule TheBand.Ontology.SEON.EO.ConcessaoDeGestaoTest do
  @moduledoc """
  A concessão de **gerir a estrutura** — T004 da feature 060 (FR-080 a FR-082).

  ## Por que ela existe

  Medido em 2026-09-06: 59 participações observadas nos times do GitHub e **nenhum papel
  declarado**. Só a conta administradora podia declarar, e quem conhece a equipe — quem a
  coordena — não podia. A estrutura não era mantida porque a permissão estava no lugar errado.

  ## O que este arquivo prova

  A **forma** da concessão: uma vigente por papel e alcance, garantida pelo banco; revogar
  marca e a linha continua; o alcance é um dos dois valores, e não texto livre. O *alcance* —
  quem a concessão alcança de fato — é da T005, e vive em `EO.StructureGrants`.
  """
  use TheBand.DataCase, async: true

  alias Ecto.Changeset
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.Schemas.RoleStructureManagementGrant, as: Concessao
  alias TheBand.Repo

  setup do
    tenant = tenant_fixture()
    org = organization_fixture(tenant, "acme")
    admin = user_fixture(tenant)

    {:ok, papel} =
      EO.create_role(tenant, org.id, %{code: "tech_lead", name: "Tech Lead"}, admin.id)

    %{tenant: tenant, org: org, admin: admin, papel: papel}
  end

  defp conceder(ctx, escopo, papel \\ nil) do
    %Concessao{}
    |> Concessao.changeset(%{
      tenant_id: ctx.tenant.id,
      organizational_role_id: (papel || ctx.papel).id,
      scope: escopo,
      declared_by_user_id: ctx.admin.id,
      declared_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()
  end

  describe "uma concessão vigente por papel e alcance" do
    test "a segunda vigente para o mesmo par é recusada pelo BANCO", ctx do
      {:ok, _} = conceder(ctx, "team")

      assert {:error, %Changeset{} = changeset} = conceder(ctx, "team"), """
      O banco aceitou duas concessões vigentes de `team` para o mesmo papel. Duas linhas para
      a mesma afirmação é a porta para revogar uma e a permissão continuar de pé pela outra —
      sem que ninguém veja.
      """

      assert changeset.errors[:scope], "a recusa precisa chegar como resposta, não como exceção"
    end

    test "os dois alcances convivem: eles não são exclusivos", ctx do
      assert {:ok, _} = conceder(ctx, "team")

      assert {:ok, _} = conceder(ctx, "organization"), """
      `team` e `organization` são declarações independentes: a segunda amplia a primeira e
      não a substitui. Recusá-la obrigaria a revogar antes de ampliar, e a janela entre as
      duas escritas deixaria a pessoa sem gestão nenhuma.
      """
    end

    test "papéis diferentes recebem a mesma concessão sem colidir", ctx do
      {:ok, outro} =
        EO.create_role(
          ctx.tenant,
          ctx.org.id,
          %{code: "eng_manager", name: "Eng Manager"},
          ctx.admin.id
        )

      assert {:ok, _} = conceder(ctx, "team")
      assert {:ok, _} = conceder(ctx, "team", outro)
    end
  end

  describe "revogar marca, nunca apaga" do
    test "a linha revogada continua, e o par volta a poder ser concedido", ctx do
      {:ok, concedida} = conceder(ctx, "team")
      agora = DateTime.utc_now(:second)

      {:ok, revogada} =
        concedida
        |> Concessao.changeset(%{revoked_at: agora, revoked_by_user_id: ctx.admin.id})
        |> Repo.update()

      assert revogada.id == concedida.id, "revogar é atualizar a mesma linha"
      assert revogada.declared_at, "quem concedeu e quando continua lá — é o que se audita"
      assert Repo.aggregate(Concessao, :count) == 1, "nada foi apagado"

      assert {:ok, _} = conceder(ctx, "team"), """
      Depois de revogada, o índice parcial precisa liberar o par. Sem isso, retirar e devolver
      a gestão a um papel seria impossível — e quem errasse a concessão ficaria sem saída.
      """
    end
  end

  describe "o que a concessão recusa" do
    test "alcance fora dos dois valores é recusado, e nomeado", ctx do
      assert {:error, changeset} = conceder(ctx, "everything")
      assert changeset.errors[:scope], "escopo inventado não pode virar concessão silenciosa"
    end

    test "concessão sem autor é recusada — é a que mais precisa de autor", ctx do
      assert {:error, changeset} =
               %Concessao{}
               |> Concessao.changeset(%{
                 tenant_id: ctx.tenant.id,
                 organizational_role_id: ctx.papel.id,
                 scope: "team",
                 declared_at: DateTime.utc_now(:second)
               })
               |> Repo.insert()

      assert changeset.errors[:declared_by_user_id]
    end

    test "concessão sem instante é recusada — 'desde quando' é metade da pergunta", ctx do
      assert {:error, changeset} =
               %Concessao{}
               |> Concessao.changeset(%{
                 tenant_id: ctx.tenant.id,
                 organizational_role_id: ctx.papel.id,
                 scope: "team",
                 declared_by_user_id: ctx.admin.id
               })
               |> Repo.insert()

      assert changeset.errors[:declared_at]
    end
  end

  describe "dois tenants" do
    test "a concessão de um tenant não aparece no outro", ctx do
      outro_tenant = tenant_fixture()
      outra_org = organization_fixture(outro_tenant, "outra")
      outro_admin = user_fixture(outro_tenant)

      {:ok, papel_de_la} =
        EO.create_role(
          outro_tenant,
          outra_org.id,
          %{code: "tech_lead", name: "Tech Lead"},
          outro_admin.id
        )

      {:ok, _} = conceder(ctx, "team")

      {:ok, _} =
        %Concessao{}
        |> Concessao.changeset(%{
          tenant_id: outro_tenant.id,
          organizational_role_id: papel_de_la.id,
          scope: "team",
          declared_by_user_id: outro_admin.id,
          declared_at: DateTime.utc_now(:second)
        })
        |> Repo.insert()

      daqui = Repo.all(from c in Concessao, where: c.tenant_id == ^ctx.tenant.id)

      assert length(daqui) == 1, """
      A consulta escopada ao tenant trouxe #{length(daqui)} concessões. O mesmo código de
      papel existe nos dois tenants de propósito neste teste: sem o escopo, a concessão de um
      decidiria a escrita no outro.
      """
    end
  end
end
