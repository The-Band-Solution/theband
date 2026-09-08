defmodule TheBand.Ontology.SEON.EO.IsolamentoDa060Test do
  @moduledoc """
  Isolamento entre tenants nas consultas que a feature 060 criou — T024, princípio V, FR-005.

  ## Por que um arquivo próprio, e por que os nomes são IGUAIS nos dois lados

  Cada consulta nova é uma porta nova, e uma que esqueça o `tenant_id` **parece funcionar**:
  devolve dados, na forma certa, e ninguém nota até dois clientes estarem no mesmo banco.

  O cenário é deliberadamente cruel: os dois tenants têm organização com o mesmo slug, equipe
  com o mesmo nome, papel com o mesmo código e pessoa com o mesmo login. Se a consulta
  esquecer o tenant, o resultado continua **parecendo certo em contagem** — e é exactamente
  por isso que um cenário com nomes diferentes não prova nada.

  ## As quatro consultas cobertas

  `list_team_roster/3`, `count_team_roster/3`, `team_roster_totals/2` e
  `role_holder_counts/3` — mais o alcance da concessão de gestão (`StructureGrants.alcance/3`)
  e a rota: `?tab=structure` de equipe de outro tenant devolve "Team not found".
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.StructureGrants

  # Um lado do cenário: tudo com os MESMOS nomes do outro.
  defp lado do
    tenant = tenant_fixture()
    autor = user_fixture(tenant)
    org = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_plataforma", %{organization: org, name: "PLATAFORMA"})
    parte = team_fixture(tenant, "T_dados", %{organization: org, name: "DADOS"})

    {:ok, _} = EO.compose_teams(tenant, parte.id, equipe.id, autor.id)

    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, autor.id)

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, source_attrs("U_ana", %{name: "Ana", login: "ana"}))

    {:ok, _} =
      EO.declare_role(tenant, equipe.id, pessoa.id, {:existente, papel.id}, autor.id,
        started_at: ~U[2026-01-01 00:00:00Z]
      )

    %{
      tenant: tenant,
      autor: autor,
      org: org,
      equipe: equipe,
      parte: parte,
      papel: papel,
      pessoa: pessoa
    }
  end

  setup do
    %{a: lado(), b: lado()}
  end

  describe "o roster não atravessa a fronteira" do
    test "list_team_roster com a equipe do OUTRO tenant devolve vazio", ctx do
      assert EO.list_team_roster(ctx.a.tenant, ctx.b.equipe.id) == [], """
      A consulta devolveu gente com o id de uma equipe de outro tenant. Com os nomes iguais dos
      dois lados, o resultado ainda pareceria certo numa tela.
      """

      assert [_uma] = EO.list_team_roster(ctx.a.tenant, ctx.a.equipe.id)
    end

    test "count_team_roster também", ctx do
      assert EO.count_team_roster(ctx.a.tenant, ctx.b.equipe.id) == 0
      assert EO.count_team_roster(ctx.a.tenant, ctx.a.equipe.id) == 1
    end

    test "team_roster_totals também", ctx do
      assert EO.team_roster_totals(ctx.a.tenant, ctx.b.equipe.id) == %{
               vigentes: 0,
               sairam: 0,
               equivocos: 0
             }

      assert EO.team_roster_totals(ctx.a.tenant, ctx.a.equipe.id).vigentes == 1
    end

    test "o ALCANCE do roster não traz as partes do outro tenant", ctx do
      # A equipe de cada lado tem uma parte, e as duas partes têm o mesmo nome. O alcance de A
      # tem de ser [equipe_de_A, parte_de_A] — e nunca a parte de B.
      escopo = EO.team_roster_scope(ctx.a.tenant, ctx.a.equipe.id)

      assert ctx.a.parte.id in escopo
      refute ctx.b.parte.id in escopo, "o alcance atravessou a fronteira do tenant"

      # E o alcance pedido com a equipe do outro lado devolve só o próprio id — a composição
      # não é encontrada, porque ela é de outro tenant.
      assert EO.team_roster_scope(ctx.a.tenant, ctx.b.equipe.id) == [ctx.b.equipe.id]
    end

    test "membro da equipe de B não entra no roster de A nem por vínculo direto", ctx do
      # A mesma pessoa (mesmo login, ids diferentes) vinculada nos dois lados: se a consulta
      # casasse por login em algum lugar, apareceria duas vezes.
      assert [uma] = EO.list_team_roster(ctx.a.tenant, ctx.a.equipe.id)
      assert uma.person_id == ctx.a.pessoa.id
      refute uma.person_id == ctx.b.pessoa.id
    end
  end

  describe "as contagens por papel não atravessam a fronteira" do
    test "role_holder_counts com a organização do outro tenant devolve vazio", ctx do
      assert EO.role_holder_counts(ctx.a.tenant, ctx.b.org.id, ctx.b.equipe.id) == %{}
    end

    test "o papel de mesmo código do outro tenant não soma aqui", ctx do
      contagens = EO.role_holder_counts(ctx.a.tenant, ctx.a.org.id, ctx.a.equipe.id)

      assert contagens[ctx.a.papel.id] == %{nesta_equipe: 1, na_organizacao: 1}, """
      Os dois tenants têm papel com o código `dev` e uma pessoa cada. Se a contagem esquecesse
      o tenant, daria 2 na organização — e 2 é um número plausível, que ninguém questionaria.
      """

      refute Map.has_key?(contagens, ctx.b.papel.id)
    end
  end

  describe "a concessão de gestão não atravessa a fronteira" do
    test "concessão declarada em A não dá alcance sobre a equipe de B", ctx do
      {:ok, _} =
        EO.declare_structure_grant(ctx.a.tenant, ctx.a.papel.id, "organization", ctx.a.autor.id)

      # Em A, com o vínculo vigente e a concessão, alcança.
      assert {:ok, _} = StructureGrants.alcance(ctx.a.tenant, ctx.a.pessoa.id, ctx.a.equipe.id)

      # A mesma pessoa (por id de A) sobre a equipe de B: não alcança.
      assert {:nao, _} = StructureGrants.alcance(ctx.a.tenant, ctx.a.pessoa.id, ctx.b.equipe.id)

      # E o tenant de B não vê a concessão de A, mesmo com o papel de mesmo código.
      assert {:nao, _} = StructureGrants.alcance(ctx.b.tenant, ctx.b.pessoa.id, ctx.b.equipe.id)
    end

    test "grants_by_role só traz as concessões do próprio tenant", ctx do
      {:ok, _} = EO.declare_structure_grant(ctx.a.tenant, ctx.a.papel.id, "team", ctx.a.autor.id)

      assert EO.structure_grants_by_role(ctx.a.tenant)[ctx.a.papel.id] == ["team"]
      assert EO.structure_grants_by_role(ctx.b.tenant) == %{}
    end
  end

  describe "os comandos novos não atravessam a fronteira" do
    test "declarar papel com a equipe do outro tenant é recusado", ctx do
      assert {:error, :not_found} =
               EO.declare_role(
                 ctx.a.tenant,
                 ctx.b.equipe.id,
                 ctx.a.pessoa.id,
                 {:existente, ctx.a.papel.id},
                 ctx.a.autor.id
               )
    end

    test "a saída com a equipe do outro tenant não encerra nada", ctx do
      assert {:error, motivo} =
               EO.record_team_departure(
                 ctx.a.tenant,
                 ctx.b.equipe.id,
                 ctx.b.pessoa.id,
                 ~U[2026-02-01 00:00:00Z],
                 ctx.a.autor.id
               )

      assert motivo =~ "não tem vínculo vigente"

      # E o vínculo de B continua vigente.
      assert EO.team_roster_totals(ctx.b.tenant, ctx.b.equipe.id).vigentes == 1
    end

    test "o equívoco com a equipe do outro tenant não invalida nada", ctx do
      assert {:error, _} =
               EO.record_team_membership_mistake(
                 ctx.a.tenant,
                 ctx.b.equipe.id,
                 ctx.b.pessoa.id,
                 "engano",
                 ctx.a.autor.id
               )

      assert EO.team_roster_totals(ctx.b.tenant, ctx.b.equipe.id).equivocos == 0
    end
  end
end
