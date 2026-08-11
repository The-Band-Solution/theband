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

      # Uma coleta posterior da **mesma organização** não observou o vínculo.
      assert {:ok, 1} =
               EO.mark_evidence_no_longer_observed(
                 tenant,
                 equipe.organization_id,
                 DateTime.utc_now(:second)
               )

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
      # A marca é **por organização**: a coleta olha uma por vez, e "não apareceu" só
      # significa algo em relação ao que foi olhado (L19). Marcar as duas exige duas
      # chamadas, uma por organização — e é essa exigência que impede uma coleta de
      # marcar os vínculos da outra.
      depois = DateTime.utc_now(:second) |> DateTime.add(1, :second)
      {:ok, 1} = EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.orgs["alfa"].id, depois)
      {:ok, 1} = EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.orgs["beta"].id, depois)

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

  describe "a marca de ausência é por organização (L19)" do
    setup do
      tenant = tenant_fixture()

      alfa = organization_fixture(tenant, "alfa")
      beta = organization_fixture(tenant, "beta")
      t_alfa = team_fixture(tenant, "T_alfa", %{organization: alfa})
      t_beta = team_fixture(tenant, "T_beta", %{organization: beta})

      {:ok, pessoa} = EO.upsert_person_from_source(tenant, source_attrs("U_x", %{name: "Ana"}))

      ontem = DateTime.add(DateTime.utc_now(:second), -86_400)

      for {equipe, sufixo} <- [{t_alfa, "-a"}, {t_beta, "-b"}] do
        {:ok, _} =
          EO.record_team_membership_evidence(tenant, %{
            person_id: pessoa.id,
            team_id: equipe.id,
            person_external_id: "U_x" <> sufixo,
            team_external_id: equipe.external_id,
            platform_access_level: "MEMBER",
            source_system: "github",
            source_instance: "https://github.com",
            observed_at: ontem
          })
      end

      %{tenant: tenant, alfa: alfa, beta: beta, t_alfa: t_alfa, t_beta: t_beta, pessoa: pessoa}
    end

    test "coletar uma organização NÃO marca os vínculos da outra", ctx do
      # É o defeito da L19 escrito como violação. Antes da correção, esta chamada marcava
      # os dois vínculos — o de `beta` inclusive, que não apareceu na coleta de `alfa`
      # porque é de outra organização e nunca apareceria.
      agora = DateTime.utc_now(:second)
      assert {:ok, 1} = EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.alfa.id, agora)

      [vinculo_beta] = EO.list_team_members(ctx.tenant, ctx.t_beta.id)

      refute vinculo_beta.no_longer_observed_at,
             "coletar alfa marcou o vínculo de beta — é a L19 de volta"
    end

    test "a pessoa continua vigente na organização não coletada", ctx do
      agora = DateTime.utc_now(:second)
      {:ok, _} = EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.alfa.id, agora)

      vigentes =
        EO.list_person_organizations(ctx.tenant, ctx.pessoa.id, only_observed: true)
        |> Enum.map(& &1.login)

      # Antes da correção isto devolvia lista vazia: era o que fazia `EduardoNFraiz`
      # aparecer sem organização alguma estando em duas observadas.
      assert vigentes == ["beta"]
    end

    test "o vínculo da organização coletada é marcado — a correção não marca de menos",
         ctx do
      agora = DateTime.utc_now(:second)
      {:ok, _} = EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.alfa.id, agora)

      [vinculo_alfa] = EO.list_team_members(ctx.tenant, ctx.t_alfa.id)

      # O oposto do defeito é igualmente errado. Marcar de menos faria a plataforma
      # afirmar observação que a origem deixou de mostrar.
      assert vinculo_alfa.no_longer_observed_at
    end

    test "duas coletas em sequência marcam cada uma a sua", ctx do
      agora = DateTime.utc_now(:second)

      assert {:ok, 1} = EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.alfa.id, agora)
      assert {:ok, 1} = EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.beta.id, agora)

      # É a sequência que o banco de desenvolvimento tinha e o teste não: uma coleta
      # após a outra, cada uma de uma organização diferente.
      assert [] == EO.list_person_organizations(ctx.tenant, ctx.pessoa.id, only_observed: true)
    end
  end
end
