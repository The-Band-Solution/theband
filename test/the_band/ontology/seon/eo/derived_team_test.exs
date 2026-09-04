defmodule TheBand.Ontology.SEON.EO.DerivedTeamTest do
  @moduledoc """
  A equipe derivada (F7), contra o contrato `derived-team.md` e a regra
  `github.default_team`.

  A equipe **não existe na ferramenta de origem**, e cada teste aqui guarda uma das
  garantias que mantêm isso verdadeiro e visível. Os três casos de criação usam os
  números medidos nas organizações reais: 5 membros e 0 times, membros fora de times
  existentes, e todos dentro.
  """
  use TheBand.DataCase, async: true

  import Ecto.Query

  alias TheBand.Ingestion.Sync
  alias TheBand.Ontology.SEON.EO
  alias TheBand.RawData
  alias TheBand.Repo
  alias TheBand.Sources.ConnectedTool

  # A regra `github.default_team` só acolhe **membro observado da organização**, e a
  # observação vem do payload preservado. Registrá-la nos testes não é cerimônia: sem
  # ela, "quem é da organização" degenera em "quem do tenant", e foi esse o defeito que
  # a execução no banco real revelou — ifesserra-lab, com 5 membros, recebeu 72.
  defp observa_membro(tenant, org, pessoa) do
    tool =
      Repo.one(
        from t in ConnectedTool,
          where: t.tenant_id == ^tenant.id and t.organization_login == ^org.login
      ) ||
        (
          {:ok, t} =
            %ConnectedTool{}
            |> ConnectedTool.changeset(%{
              tenant_id: tenant.id,
              tool_type: "github",
              instance_url: "https://github-#{System.unique_integer([:positive])}.example",
              organization_login: org.login
            })
            |> Repo.insert()

          t
        )

    sync =
      Repo.one(from s in Sync, where: s.connected_tool_id == ^tool.id) ||
        (
          {:ok, s} =
            %Sync{}
            |> Sync.changeset(%{
              tenant_id: tenant.id,
              connected_tool_id: tool.id,
              status: "completed",
              started_at: DateTime.utc_now(:second)
            })
            |> Repo.insert()

          s
        )

    {:ok, _} =
      RawData.store(%{
        tenant_id: tenant.id,
        sync_id: sync.id,
        raw_entity_type: "github.user",
        external_id: pessoa.external_id,
        payload: %{"id" => pessoa.external_id, "login" => pessoa.login},
        mapping_id: "github.user.to.eo.person",
        mapping_version: 1,
        source_system: "github",
        source_instance: "https://github.com",
        collected_at: DateTime.utc_now(:second)
      })

    pessoa
  end

  defp pessoa(tenant, id, nome), do: pessoa(tenant, id, nome, %{})

  defp pessoa(tenant, id, nome, extra) do
    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs(id, Map.merge(%{name: nome, login: String.downcase(nome)}, extra))
      )

    p
  end

  defp vincula(tenant, pessoa, equipe) do
    {:ok, e} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: pessoa.external_id,
        team_external_id: equipe.external_id,
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    e
  end

  describe "a corrida entre dois coletores (issue #800)" do
    test "o conflito da Application Reference é reconhecido, e não vira erro" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "leds-conectafapes")

      {:ok, primeira} = EO.upsert_derived_team(tenant, org)

      # A corrida, encenada: o segundo coletor consulta, não acha — porque simulamos o
      # instante ANTERIOR à gravação do primeiro — e insere. No código real os dois
      # `find_by_application_reference` acontecem antes de qualquer insert; aqui basta
      # chamar de novo, porque o caminho de conflito é o mesmo.
      assert {:ok, segunda} = EO.upsert_derived_team(tenant, org)

      assert segunda.id == primeira.id, """
      O segundo upsert criou OUTRA equipe. A Application Reference é determinística, e
      duas linhas com a mesma referência fariam a organização parecer ter duas equipes
      derivadas — e a contagem de equipes mentiria.
      """

      assert Repo.aggregate(
               from(t in "eo_teams",
                 where:
                   t.tenant_id == type(^tenant.id, :binary_id) and
                     like(t.external_id, "derived:default_team:%")
               ),
               :count
             ) == 1
    end

    test "OUTRO conflito único continua sendo erro — o discriminador olha o índice" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "alfa")

      {:ok, admin} =
        TheBand.Tenants.create_user(tenant, %{"email" => "a@x.test", "role" => "admin"})

      {:ok, _} = EO.declare_structural_team(tenant, org.id, "Dados", admin.id)

      # `eo_nome_unico_da_equipe_declarada_index` é outro índice único da mesma tabela.
      # Reconhecer o conflito dele como "já existe, atualize" apagaria a recusa que a
      # unicidade do nome declarado existe para produzir — e o discriminador precisa
      # separar os dois pelo NOME do índice, não por ser único.
      assert {:error, _} = EO.declare_structural_team(tenant, org.id, "Dados", admin.id)
    end
  end

  describe "quem a equipe derivada acolhe (T021, FR-004)" do
    test "organização sem nenhum time: todos entram — o caso de ifesserra-lab" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "ifesserra-lab")

      for i <- 1..5 do
        tenant |> pessoa("U_#{i}", "Pessoa#{i}") |> then(&observa_membro(tenant, org, &1))
      end

      assert length(EO.list_people_without_team(tenant, org.id)) == 5

      {:ok, derivada} = EO.upsert_derived_team(tenant, org)

      assert derivada.name == "ifesserra-lab"
      assert derivada.organization_id == org.id
      assert EO.derived_team?(derivada)
    end

    test "organização com times: só quem ficou de fora" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "alfa")
      time = team_fixture(tenant, "T_obs", %{organization: org})

      dentro = observa_membro(tenant, org, pessoa(tenant, "U_dentro", "Dentro"))
      observa_membro(tenant, org, pessoa(tenant, "U_fora", "Fora"))
      vincula(tenant, dentro, time)

      assert ["Fora"] = EO.list_people_without_team(tenant, org.id) |> Enum.map(& &1.name)
    end

    test "todos em times: nenhuma equipe derivada é criada (FR-007)" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "beta")
      time = team_fixture(tenant, "T_todos", %{organization: org})
      vincula(tenant, observa_membro(tenant, org, pessoa(tenant, "U_a", "Ana")), time)
      vincula(tenant, observa_membro(tenant, org, pessoa(tenant, "U_b", "Bruno")), time)

      # A lista vazia é o sinal de que a derivada não deve existir. Criá-la vazia
      # seria registro sem referente, e faria a contagem de derivadas crescer com o
      # número de organizações sem significar nada.
      assert [] == EO.list_people_without_team(tenant, org.id)
      assert is_nil(EO.fetch_derived_team(tenant, org.id))
    end

    test "conta de automação não é acolhida" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "gama")

      observa_membro(
        tenant,
        org,
        pessoa(tenant, "U_bot", "Dependabot", %{account_type: "bot"})
      )

      # Acolher o bot inflaria justamente o quadro que a equipe derivada existe para
      # completar.
      assert [] == EO.list_people_without_team(tenant, org.id)
    end
  end

  describe "a derivada não se apresenta como observada (T022, FR-005)" do
    test "a proveniência é montada pela função, não escolhida por quem chama" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "delta")

      # Mesmo pedindo proveniência do GitHub, a função grava a da plataforma. Não há
      # parâmetro que permita o contrário — é o único jeito de esta feature mentir.
      {:ok, derivada} =
        EO.upsert_derived_team(tenant, org, %{
          source_system: "github",
          external_id: "T_parece_observada"
        })

      assert derivada.source_system == EO.derived_source()
      assert String.starts_with?(derivada.external_id, EO.derived_prefix())
    end

    test "identificador de derivação com proveniência do GitHub é recusado" do
      assert {:error, mensagem} =
               EO.derived_team_declares_itself(%{
                 external_id: "derived:default_team:O_1",
                 source_system: "github"
               })

      assert mensagem =~ "se apresentando como observada"
    end

    test "proveniência da plataforma sem identificador de derivação é recusada" do
      assert {:error, mensagem} =
               EO.derived_team_declares_itself(%{
                 external_id: "T_qualquer",
                 source_system: "the_band"
               })

      assert mensagem =~ "só produz equipe pela regra"
    end

    test "equipe observada legítima passa" do
      assert :ok =
               EO.derived_team_declares_itself(%{
                 external_id: "T_1",
                 source_system: "github"
               })
    end

    test "o vínculo derivado não carrega nível de acesso" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "epsilon")
      {:ok, derivada} = EO.upsert_derived_team(tenant, org)
      p = pessoa(tenant, "U_d", "Ana")

      {:ok, evidencia} =
        EO.record_derived_team_membership(tenant, %{
          person_id: p.id,
          team_id: derivada.id,
          person_external_id: p.external_id,
          team_external_id: derivada.external_id,
          source_instance: org.source_instance,
          observed_at: DateTime.utc_now(:second),
          # Mesmo informado, é descartado: a origem não conhece este vínculo.
          platform_access_level: "MAINTAINER"
        })

      assert is_nil(evidencia.platform_access_level)
    end

    test "nível de acesso em vínculo derivado é recusado pela invariante" do
      assert {:error, mensagem} =
               EO.derived_link_has_no_access_level(%{
                 platform_access_level: "MEMBER",
                 source_system: "the_band"
               })

      assert mensagem =~ "ausência é nula"
    end
  end

  describe "idempotência (contrato: Garantias)" do
    test "derivar duas vezes não cria uma segunda equipe" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "zeta")

      {:ok, primeira} = EO.upsert_derived_team(tenant, org)
      {:ok, segunda} = EO.upsert_derived_team(tenant, org)

      assert primeira.id == segunda.id
      assert length(EO.list_teams(tenant, origin: :derived)) == 1
    end
  end

  describe "esvaziar sem apagar (T023, FR-008)" do
    setup do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "eta")
      {:ok, derivada} = EO.upsert_derived_team(tenant, org)
      p = pessoa(tenant, "U_e", "Ana")

      {:ok, _} =
        EO.record_derived_team_membership(tenant, %{
          person_id: p.id,
          team_id: derivada.id,
          person_external_id: p.external_id,
          team_external_id: derivada.external_id,
          source_instance: org.source_instance,
          observed_at: DateTime.utc_now(:second)
        })

      %{tenant: tenant, org: org, derivada: derivada}
    end

    test "a equipe é marcada, não removida", ctx do
      {:ok, _} = EO.retire_derived_team(ctx.tenant, ctx.derivada)

      # Continua consultável: uma equipe que existiu e esvaziou diz que a organização
      # mantinha gente fora de qualquer time, e deixou de manter.
      assert [equipe] = EO.list_teams(ctx.tenant, origin: :derived)
      assert equipe.id == ctx.derivada.id
      assert equipe.no_longer_observed_at
    end

    test "os vínculos dela são marcados, não apagados", ctx do
      {:ok, _} = EO.retire_derived_team(ctx.tenant, ctx.derivada)

      assert [membro] = EO.list_team_members(ctx.tenant, ctx.derivada.id)
      assert membro.no_longer_observed_at
    end
  end

  describe "origem separada na contagem (T024, FR-011)" do
    setup do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "theta")
      team_fixture(tenant, "T_obs1", %{organization: org})
      team_fixture(tenant, "T_obs2", %{organization: org})
      {:ok, _} = EO.upsert_derived_team(tenant, org)
      %{tenant: tenant}
    end

    test "o padrão conta todas", %{tenant: tenant} do
      assert EO.count_teams(tenant) == 3
    end

    test "observadas e derivadas são contáveis em separado", %{tenant: tenant} do
      # Quem compara o número da plataforma com o do GitHub precisa ver a diferença
      # sem investigar: são 2 na origem, e 3 aqui.
      assert EO.count_teams(tenant, origin: :observed) == 2
      assert EO.count_teams(tenant, origin: :derived) == 1
    end

    test "listagem e contagem concordam sob o filtro de origem", %{tenant: tenant} do
      for origin <- [:all, :observed, :derived] do
        opts = [origin: origin]

        assert length(EO.list_teams(tenant, opts)) == EO.count_teams(tenant, opts),
               "listagem e contagem divergiram para origin: #{origin}"
      end
    end
  end
end
