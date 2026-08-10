defmodule TheBand.Ontology.SEON.EO.QueriesTest do
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO

  describe "listagem e contagem concordam sob qualquer filtro" do
    setup do
      tenant = tenant_fixture()

      {:ok, _} =
        EO.upsert_person_from_source(
          tenant,
          source_attrs("U_1", %{name: "Ana Souza", login: "ana"})
        )

      {:ok, _} =
        EO.upsert_person_from_source(
          tenant,
          source_attrs("U_2", %{name: "Bruno Lima", login: "bruno"})
        )

      {:ok, _} =
        EO.upsert_person_from_source(
          tenant,
          source_attrs("U_3", %{name: "dependabot", login: "dependabot", account_type: "bot"})
        )

      %{tenant: tenant}
    end

    test "sem filtro", %{tenant: tenant} do
      assert length(EO.list_people(tenant)) == EO.count_people(tenant)
    end

    test "filtrando por tipo de conta", %{tenant: tenant} do
      opts = [account_type: "person"]
      assert length(EO.list_people(tenant, opts)) == EO.count_people(tenant, opts)
      assert EO.count_people(tenant, opts) == 2
    end

    test "filtrando por busca", %{tenant: tenant} do
      opts = [search: "ana"]
      assert length(EO.list_people(tenant, opts)) == EO.count_people(tenant, opts)
      assert EO.count_people(tenant, opts) == 1
    end

    test "combinando filtros", %{tenant: tenant} do
      opts = [account_type: "person", search: "bruno"]
      assert length(EO.list_people(tenant, opts)) == EO.count_people(tenant, opts)
    end

    # Este é o teste que existe por causa de um defeito real: contagem que ignora
    # o filtro da listagem exibe um total que não corresponde ao que está na tela.
    test "a contagem nunca é maior que a listagem sem paginação", %{tenant: tenant} do
      for opts <- [[], [account_type: "person"], [search: "a"], [search: "zzz"]] do
        assert length(EO.list_people(tenant, opts)) == EO.count_people(tenant, opts),
               "listagem e contagem divergiram para #{inspect(opts)}"
      end
    end
  end

  describe "integrantes de equipe" do
    test "trazem nível de acesso na plataforma e o estado do papel" do
      tenant = tenant_fixture()
      {:ok, pessoa} = EO.upsert_person_from_source(tenant, source_attrs("U_9", %{name: "Ana"}))
      equipe = team_fixture(tenant, "T_9")

      {:ok, _} =
        EO.record_team_membership_evidence(tenant, %{
          person_id: pessoa.id,
          team_id: equipe.id,
          person_external_id: "U_9",
          team_external_id: "T_9",
          platform_access_level: "MAINTAINER",
          source_system: "github",
          source_instance: "https://github.com",
          observed_at: DateTime.utc_now(:second)
        })

      assert [membro] = EO.list_team_members(tenant, equipe.id)
      assert membro.platform_access_level == "MAINTAINER"
      assert membro.pending_role
      assert membro.person.id == pessoa.id
    end
  end

  describe "ausência não é remoção" do
    test "vínculo que some da origem é marcado, nunca apagado" do
      tenant = tenant_fixture()
      {:ok, pessoa} = EO.upsert_person_from_source(tenant, source_attrs("U_10", %{name: "Ana"}))
      equipe = team_fixture(tenant, "T_10")

      ontem = DateTime.add(DateTime.utc_now(:second), -86_400)

      {:ok, _} =
        EO.record_team_membership_evidence(tenant, %{
          person_id: pessoa.id,
          team_id: equipe.id,
          person_external_id: "U_10",
          team_external_id: "T_10",
          platform_access_level: "MEMBER",
          source_system: "github",
          source_instance: "https://github.com",
          observed_at: ontem
        })

      # Uma coleta posterior não observou o vínculo.
      assert {:ok, 1} = EO.mark_evidence_no_longer_observed(tenant, DateTime.utc_now(:second))

      assert [membro] = EO.list_team_members(tenant, equipe.id)
      assert membro.no_longer_observed_at
      # Continua contando como pendente: o vínculo existiu e não foi apagado.
      assert EO.count_evidence_pending_role(tenant) == 1
    end
  end

  describe "as organizações de uma pessoa (T010, FR-003)" do
    setup do
      tenant = tenant_fixture()

      orgs =
        for login <- ~w(alfa beta) do
          {:ok, o} =
            EO.upsert_organization_from_source(
              tenant,
              source_attrs("O_#{login}", %{name: login, login: login})
            )

          {login, o}
        end
        |> Map.new()

      equipe = fn slug, org ->
        {:ok, t} =
          EO.upsert_team_from_source(
            tenant,
            source_attrs("T_#{slug}", %{name: slug, organization_id: org.id})
          )

        t
      end

      {:ok, pessoa} = EO.upsert_person_from_source(tenant, source_attrs("U_p", %{name: "Ana"}))
      {:ok, sozinha} = EO.upsert_person_from_source(tenant, source_attrs("U_s", %{name: "Bia"}))

      vincula = fn pessoa, equipe, sufixo ->
        {:ok, e} =
          EO.record_team_membership_evidence(tenant, %{
            person_id: pessoa.id,
            team_id: equipe.id,
            person_external_id: pessoa.external_id <> sufixo,
            team_external_id: equipe.external_id,
            platform_access_level: "MEMBER",
            source_system: "github",
            source_instance: "https://github.com",
            observed_at: DateTime.utc_now(:second)
          })

        e
      end

      %{
        tenant: tenant,
        orgs: orgs,
        equipe: equipe,
        pessoa: pessoa,
        sozinha: sozinha,
        vincula: vincula
      }
    end

    test "em equipes de duas organizações, devolve as duas sem repetir", ctx do
      a = ctx.equipe.("a", ctx.orgs["alfa"])
      b = ctx.equipe.("b", ctx.orgs["beta"])
      ctx.vincula.(ctx.pessoa, a, "")
      ctx.vincula.(ctx.pessoa, b, "-b")

      assert ["alfa", "beta"] =
               EO.list_person_organizations(ctx.tenant, ctx.pessoa.id) |> Enum.map(& &1.login)
    end

    test "em duas equipes da mesma organização, devolve uma", ctx do
      a1 = ctx.equipe.("a1", ctx.orgs["alfa"])
      a2 = ctx.equipe.("a2", ctx.orgs["alfa"])
      ctx.vincula.(ctx.pessoa, a1, "")
      ctx.vincula.(ctx.pessoa, a2, "-2")

      assert ["alfa"] =
               EO.list_person_organizations(ctx.tenant, ctx.pessoa.id) |> Enum.map(& &1.login)
    end

    test "vínculo que deixou de ser observado mantém a organização (FR-009)", ctx do
      a = ctx.equipe.("a", ctx.orgs["alfa"])
      b = ctx.equipe.("b", ctx.orgs["beta"])
      ctx.vincula.(ctx.pessoa, a, "")
      ctx.vincula.(ctx.pessoa, b, "-b")

      # A origem deixou de mostrar o vínculo com beta. Ausência não é remoção: a
      # pessoa esteve lá, e o registro tem de continuar dizendo isso.
      #
      # O instante somado em um segundo não é detalhe de teste: as colunas são
      # `timestamp(0)`, então um `utc_now()` do mesmo segundo é truncado ao mesmo
      # valor de `last_observed_at`, e `X < X` não marca nada.
      depois = DateTime.utc_now(:second) |> DateTime.add(1, :second)
      {:ok, 2} = EO.mark_evidence_no_longer_observed(ctx.tenant, depois)

      assert ["alfa", "beta"] =
               EO.list_person_organizations(ctx.tenant, ctx.pessoa.id) |> Enum.map(& &1.login)

      assert [] == EO.list_person_organizations(ctx.tenant, ctx.pessoa.id, only_observed: true)
    end

    test "quem não está em equipe alguma devolve lista vazia, não erro", ctx do
      assert [] == EO.list_person_organizations(ctx.tenant, ctx.sozinha.id)
    end

    test "não atravessa tenant", ctx do
      a = ctx.equipe.("a", ctx.orgs["alfa"])
      ctx.vincula.(ctx.pessoa, a, "")
      outro = tenant_fixture("outra-org")

      assert [] == EO.list_person_organizations(outro, ctx.pessoa.id)
    end
  end
end
