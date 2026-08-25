defmodule TheBand.Ontology.SEON.EO.PapeisPorOrganizacaoTest do
  @moduledoc """
  O catálogo composto e o escopo por organização — feature 043, issue #317.

  ## A cadeia que esta feature destrava

  Medido em 2026-08-24: **12 equipes, 101 evidências de vínculo, 0 vínculos, 0 papéis** — e
  `eo_team_memberships.organizational_role_id` é `NOT NULL`.

  Parada no primeiro elo. Sem papel cadastrado nenhuma evidência vira vínculo, e por isso todo
  o nível Equipe dos painéis está vazio: quatro das cinco medidas declaram `team`.

  ## O que estes casos protegem

  Que o catálogo **não seja semeado**, que o escopo seja a organização, e que a origem de cada
  papel fique visível. Os três são decisões que um refactor bem-intencionado desfaz sem
  perceber.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.Schemas.OrganizationalRole

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()

    %{
      tenant: tenant,
      org: organization_fixture(tenant, "acme"),
      outra: organization_fixture(tenant, "outra"),
      user: user_fixture(tenant)
    }
  end

  describe "o catálogo" do
    test "os quatro aparecem numa organização sem linha alguma", ctx do
      papeis = EO.list_organization_roles(ctx.tenant, ctx.org.id)

      assert length(papeis) == 4

      assert Enum.all?(papeis, &is_nil(&1.id)), """
      **Papel do catálogo sem uso tem `id` NULO.** É deliberado: um identificador sintético
      faria a tela acreditar que a linha existe, e a promoção falharia com chave estrangeira
      inválida.
      """

      assert Repo.aggregate(OrganizationalRole, :count) == 0, """
      **Compor não é semear.** Nenhuma linha foi gravada — se fosse, quatro linhas por
      organização nasceriam sem ninguém as declarar, e divergiriam da rede no dia em que a SRO
      renomeasse um papel.
      """
    end

    test "a origem é tupla marcada, e diz qual conceito da SRO", ctx do
      papeis = EO.list_organization_roles(ctx.tenant, ctx.org.id)

      assert Enum.all?(papeis, &match?({:catalogo, "sro." <> _}, &1.origem)), """
      A origem carrega **qual** conceito originou o papel. Um booleano `do_catalogo?` perderia
      isso, e a FR-003 exige a origem visível — não inferida do nome.
      """
    end

    test "aparecem nas duas organizações, independentemente", ctx do
      assert length(EO.list_organization_roles(ctx.tenant, ctx.org.id)) == 4
      assert length(EO.list_organization_roles(ctx.tenant, ctx.outra.id)) == 4
    end
  end

  describe "materializar" do
    test "a linha nasce no primeiro uso, e só uma", ctx do
      conceito = "sro.scrum_master_role"

      {:ok, primeiro} = EO.materialize_catalog_role(ctx.tenant, ctx.org.id, conceito)
      {:ok, segundo} = EO.materialize_catalog_role(ctx.tenant, ctx.org.id, conceito)

      assert primeiro.id == segundo.id, """
      **`on_conflict: :nothing` e releitura.** A segunda chamada não cria linha nova — ela usa
      a que existe. É o que cobre a corrida de duas promoções simultâneas, e o desfecho certo
      ali é "use a que já existe", não "falhe".
      """

      assert Repo.aggregate(OrganizationalRole, :count) == 1
    end

    test "a linha materializada aparece na lista com id, e o resto continua sem", ctx do
      {:ok, papel} = EO.materialize_catalog_role(ctx.tenant, ctx.org.id, "sro.developer_role")

      papeis = EO.list_organization_roles(ctx.tenant, ctx.org.id)

      assert length(papeis) == 4, "continua sendo quatro: a composição não duplica"

      com_id = Enum.filter(papeis, &(not is_nil(&1.id)))
      assert [encontrado] = com_id
      assert encontrado.id == papel.id
    end

    test "materializar numa organização não alcança a outra", ctx do
      {:ok, _} = EO.materialize_catalog_role(ctx.tenant, ctx.org.id, "sro.developer_role")

      outros = EO.list_organization_roles(ctx.tenant, ctx.outra.id)

      assert Enum.all?(outros, &is_nil(&1.id)), """
      **É o índice `UNIQUE (tenant_id, organization_id, code)` em ação.** Com o índice antigo,
      por tenant, a segunda organização a materializar o mesmo papel bateria na constraint — e
      era esse o bloqueio real da issue #317.
      """
    end

    test "conceito que a rede não nomeia é recusado", ctx do
      assert {:error, :not_in_catalog} =
               EO.materialize_catalog_role(ctx.tenant, ctx.org.id, "sro.inventado_role")
    end
  end

  describe "o escopo" do
    test "papel declarado numa organização não aparece na outra", ctx do
      {:ok, _} =
        EO.create_role(
          ctx.tenant,
          ctx.org.id,
          %{code: "tech_lead", name: "Tech Lead"},
          ctx.user.id
        )

      declarados = fn org_id ->
        ctx.tenant
        |> EO.list_organization_roles(org_id)
        |> Enum.filter(&(elem(&1.origem, 0) == :declarado))
      end

      assert length(declarados.(ctx.org.id)) == 1
      assert declarados.(ctx.outra.id) == []
    end

    test "o mesmo código nas duas organizações são papéis diferentes", ctx do
      {:ok, um} =
        EO.create_role(
          ctx.tenant,
          ctx.org.id,
          %{code: "tech_lead", name: "Tech Lead"},
          ctx.user.id
        )

      {:ok, outro} =
        EO.create_role(
          ctx.tenant,
          ctx.outra.id,
          %{code: "tech_lead", name: "Líder Técnico"},
          ctx.user.id
        )

      refute um.id == outro.id

      assert um.internal_id != outro.internal_id, """
      A organização entra no `internal_id` porque entrou na identidade. Sem ela, os dois
      colapsariam num só — e o rastro diria que são o mesmo papel.
      """
    end
  end

  describe "uma origem só" do
    test "papel sem origem alguma é recusado", ctx do
      changeset =
        OrganizationalRole.changeset(%OrganizationalRole{}, %{
          tenant_id: ctx.tenant.id,
          organization_id: ctx.org.id,
          internal_id: "x",
          code: "x",
          name: "X"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:catalog_concept_id]
    end

    test "papel com as duas origens é recusado", ctx do
      changeset =
        OrganizationalRole.changeset(%OrganizationalRole{}, %{
          tenant_id: ctx.tenant.id,
          organization_id: ctx.org.id,
          internal_id: "x",
          code: "x",
          name: "X",
          catalog_concept_id: "sro.developer_role",
          declared_by_user_id: ctx.user.id
        })

      refute changeset.valid?, """
      Do catálogo tem conceito e não tem autor; declarado tem autor e não tem conceito. Um
      papel que afirmasse as duas deixaria a tela sem o que mostrar como proveniência.
      """
    end
  end

  describe "renomear e ocultar" do
    test "papel do catálogo não é renomeável", ctx do
      {:ok, papel} = EO.materialize_catalog_role(ctx.tenant, ctx.org.id, "sro.developer_role")

      assert {:error, :from_catalog} =
               EO.rename_role(ctx.tenant, papel.id, "Outro nome", ctx.user.id)
    end

    test "papel declarado é renomeável, e o código não muda", ctx do
      {:ok, papel} =
        EO.create_role(
          ctx.tenant,
          ctx.org.id,
          %{code: "tech_lead", name: "Tech Lead"},
          ctx.user.id
        )

      assert {:ok, renomeado} =
               EO.rename_role(ctx.tenant, papel.id, "Líder Técnico", ctx.user.id)

      assert renomeado.name == "Líder Técnico"

      assert renomeado.code == "tech_lead", """
      **O código é a identidade.** Trocá-lo faria os vínculos existentes apontarem para outra
      coisa sem que nada avisasse, e nenhuma função pública o permite.
      """
    end

    test "ocultar marca, e o papel continua existindo", ctx do
      {:ok, papel} =
        EO.create_role(
          ctx.tenant,
          ctx.org.id,
          %{code: "tech_lead", name: "Tech Lead"},
          ctx.user.id
        )

      assert {:ok, oculto} = EO.hide_role(ctx.tenant, papel.id, ctx.user.id)
      assert oculto.hidden_at

      assert Repo.aggregate(OrganizationalRole, :count) == 1, """
      **Ocultar não apaga.** A linha continua, e os vínculos que a usam continuam válidos —
      é a mesma regra do `no_longer_observed_at` da coleta.
      """

      assert {:ok, devolvido} = EO.unhide_role(ctx.tenant, papel.id, ctx.user.id)
      refute devolvido.hidden_at
    end
  end
end
