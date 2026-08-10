defmodule TheBand.SourcesObservationTest do
  @moduledoc """
  Encerrar a observação de uma ferramenta (F3), contra
  `contracts/observation-lifecycle.md`.

  **O teste que decide a feature está em "quem NÃO é marcado".** Uma pessoa observada em
  três organizações tem uma linha e uma proveniência; o que pertence a cada ferramenta é
  o vínculo. Marcar por pessoa em vez de por vínculo revogaria a vigência de quem
  continua sendo observado — o defeito que a primeira versão da spec tinha.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ingestion
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  # Reproduz a forma do dado real: três organizações, uma pessoa em todas as três, uma em
  # duas, e as demais exclusivas de cada uma.
  defp cenario(tenant) do
    orgs =
      Map.new(~w(alfa beta gama), fn login -> {login, organization_fixture(tenant, login)} end)

    tools =
      Map.new(orgs, fn {login, _org} ->
        {:ok, tool} =
          %ConnectedTool{}
          |> ConnectedTool.changeset(%{
            tenant_id: tenant.id,
            tool_type: "github",
            instance_url: "https://github.com",
            organization_login: login
          })
          |> Repo.insert()

        {:ok, _} =
          %ToolCredential{}
          |> ToolCredential.changeset(%{
            tenant_id: tenant.id,
            connected_tool_id: tool.id,
            label: "principal",
            secret: "ghp_segredo_de_#{login}",
            last_four: "0000",
            scopes: ["read:org"],
            validated_at: DateTime.utc_now(:second)
          })
          |> Repo.insert()

        {login, tool}
      end)

    teams =
      Map.new(orgs, fn {login, org} ->
        {login, team_fixture(tenant, "T_#{login}", %{organization: org})}
      end)

    pessoas =
      Map.new(
        [
          {"em_tres", ~w(alfa beta gama)},
          {"em_duas", ~w(alfa beta)},
          {"so_alfa", ~w(alfa)},
          {"so_beta", ~w(beta)}
        ],
        fn {nome, logins} ->
          {:ok, p} =
            EO.upsert_person_from_source(tenant, source_attrs("U_#{nome}", %{name: nome}))

          for login <- logins do
            {:ok, _} =
              EO.record_team_membership_evidence(tenant, %{
                person_id: p.id,
                team_id: teams[login].id,
                person_external_id: "U_#{nome}@#{login}",
                team_external_id: teams[login].external_id,
                platform_access_level: "MEMBER",
                source_system: "github",
                source_instance: "https://github.com",
                observed_at: DateTime.utc_now(:second)
              })
          end

          {nome, p}
        end
      )

    %{orgs: orgs, tools: tools, teams: teams, pessoas: pessoas}
  end

  defp marcada?(schema, id) do
    Repo.get!(schema, id).no_longer_observed_at != nil
  end

  describe "estado derivado do último evento (T004)" do
    setup do
      tenant = tenant_fixture()
      c = cenario(tenant)
      %{tenant: tenant, c: c}
    end

    test "sem evento é vigente — é o que dispensa migração de dado", %{c: c} do
      refute Sources.observation_ended?(c.tools["alfa"])
    end

    test "com ended por último, encerrada", %{tenant: tenant, c: c} do
      {:ok, _} = Sources.end_observation(tenant, c.tools["alfa"], %{"confirmation" => "alfa"})
      assert Sources.observation_ended?(c.tools["alfa"])
    end

    test "dois ended seguidos continuam encerrada", %{tenant: tenant, c: c} do
      for _ <- 1..2 do
        Sources.end_observation(tenant, c.tools["alfa"], %{"confirmation" => "alfa"})
      end

      assert Sources.observation_ended?(c.tools["alfa"])
      assert length(Sources.observation_history(tenant, c.tools["alfa"])) == 2
    end
  end

  describe "o impacto mostrado é o impacto que acontece (T006, SC-009)" do
    setup do
      tenant = tenant_fixture()
      %{tenant: tenant, c: cenario(tenant)}
    end

    test "separa exclusivas de compartilhadas", %{tenant: tenant, c: c} do
      impacto = Sources.observation_impact(tenant, c.tools["gama"])

      # `gama` tem uma equipe e um único vínculo — o da pessoa que está nas três.
      # Ela é **compartilhada**, não exclusiva: juntar as duas contagens esconderia
      # exatamente a que assusta.
      assert impacto.teams == 1
      assert impacto.evidence_links == 1
      assert impacto.people_exclusive == 0
      assert impacto.people_shared == 1
    end

    test "o número mostrado é o número que o encerramento marca", %{tenant: tenant, c: c} do
      impacto = Sources.observation_impact(tenant, c.tools["alfa"])

      {:ok, resultado} =
        Sources.end_observation(tenant, c.tools["alfa"], %{"confirmation" => "alfa"})

      assert resultado.marked.teams == impacto.teams
      assert resultado.marked.links == impacto.evidence_links
      assert resultado.marked.people == impacto.people_exclusive
    end
  end

  describe "marca por vínculo, nunca por pessoa (T007, SC-002, SC-003, SC-008)" do
    setup do
      tenant = tenant_fixture()
      c = cenario(tenant)
      {:ok, _} = Sources.end_observation(tenant, c.tools["gama"], %{"confirmation" => "gama"})
      %{tenant: tenant, c: c}
    end

    test "quem tem vínculo em outra organização NÃO é marcado", %{c: c} do
      # É o teste que decide a feature. `em_tres` tinha vínculo em `gama`, que foi
      # encerrada, e continua observada em `alfa` e `beta`. Marcá-la faria a plataforma
      # afirmar que não observa mais alguém que ela observa toda sincronização.
      refute marcada?(EO.Schemas.Person, c.pessoas["em_tres"].id),
             "a pessoa observada em três organizações foi marcada ao encerrar uma delas"
    end

    test "o vínculo com a organização encerrada é marcado", %{tenant: tenant, c: c} do
      vinculos = EO.list_team_members(tenant, c.teams["gama"].id)
      assert [%{no_longer_observed_at: marcado}] = vinculos
      assert marcado, "o vínculo com a equipe da organização encerrada continuou vigente"
    end

    test "as organizações vigentes da pessoa passam de três para duas", %{tenant: tenant, c: c} do
      vigentes =
        EO.list_person_organizations(tenant, c.pessoas["em_tres"].id, only_observed: true)
        |> Enum.map(& &1.login)

      assert vigentes == ~w(alfa beta)
    end

    test "o histórico mantém a organização encerrada", %{tenant: tenant, c: c} do
      todas =
        EO.list_person_organizations(tenant, c.pessoas["em_tres"].id) |> Enum.map(& &1.login)

      # Ausência não é remoção: a pessoa esteve em `gama`, e o registro continua dizendo.
      assert todas == ~w(alfa beta gama)
    end

    test "a equipe da organização encerrada é marcada, não apagada", %{c: c} do
      assert marcada?(EO.Schemas.Team, c.teams["gama"].id)
      assert Repo.get(EO.Schemas.Team, c.teams["gama"].id)
    end
  end

  describe "quem só existia por causa dela é marcado" do
    test "pessoa com vínculo apenas na organização encerrada perde vigência" do
      tenant = tenant_fixture()
      c = cenario(tenant)

      {:ok, resultado} =
        Sources.end_observation(tenant, c.tools["beta"], %{"confirmation" => "beta"})

      # `so_beta` tinha vínculo só em `beta`. `em_duas` e `em_tres` têm em `alfa`.
      assert marcada?(EO.Schemas.Person, c.pessoas["so_beta"].id)
      refute marcada?(EO.Schemas.Person, c.pessoas["em_duas"].id)
      refute marcada?(EO.Schemas.Person, c.pessoas["em_tres"].id)
      assert resultado.marked.people == 1
    end
  end

  describe "nada é apagado (T009, SC-001)" do
    test "as contagens são idênticas antes e depois" do
      tenant = tenant_fixture()
      c = cenario(tenant)

      antes = {EO.count_people(tenant), EO.count_teams(tenant)}
      {:ok, _} = Sources.end_observation(tenant, c.tools["alfa"], %{"confirmation" => "alfa"})

      assert antes == {EO.count_people(tenant), EO.count_teams(tenant)}
    end
  end

  describe "a credencial deixa de existir (T008, SC-004)" do
    test "nenhuma linha remanescente, e nenhum texto cifrado" do
      tenant = tenant_fixture()
      c = cenario(tenant)
      tool_id = c.tools["alfa"].id

      assert Repo.aggregate(
               from(cr in ToolCredential, where: cr.connected_tool_id == ^tool_id),
               :count,
               :id
             ) == 1

      {:ok, resultado} =
        Sources.end_observation(tenant, c.tools["alfa"], %{"confirmation" => "alfa"})

      assert resultado.credentials_destroyed == 1

      # Consulta direta à tabela, não afirmação no código.
      assert Repo.aggregate(
               from(cr in ToolCredential, where: cr.connected_tool_id == ^tool_id),
               :count,
               :id
             ) == 0
    end
  end

  describe "a confirmação protege (T009, FR-003)" do
    test "confirmação errada não altera nada" do
      tenant = tenant_fixture()
      c = cenario(tenant)

      assert {:error, :confirmation_mismatch} =
               Sources.end_observation(tenant, c.tools["alfa"], %{"confirmation" => "alf"})

      refute Sources.observation_ended?(c.tools["alfa"])
      refute marcada?(EO.Schemas.Team, c.teams["alfa"].id)
      assert Sources.active_credential(c.tools["alfa"])
    end
  end

  describe "o impacto é gravado no evento (M2 da análise)" do
    test "lido de volta do banco, traz os seis números" do
      tenant = tenant_fixture()
      c = cenario(tenant)

      {:ok, _} = Sources.end_observation(tenant, c.tools["alfa"], %{"confirmation" => "alfa"})

      [evento] = Sources.observation_history(tenant, c.tools["alfa"])

      # Gravar sem verificar deixaria um mapa vazio passar por todos os outros testes.
      assert map_size(evento.impact) == 6
      assert evento.impact["teams"] == 1
      assert evento.event == "ended"
      assert evento.occurred_at
    end
  end

  describe "origem encerrada não é coletada (T010, SC-005)" do
    test "a sincronização é recusada, nomeando o motivo" do
      tenant = tenant_fixture()
      c = cenario(tenant)

      # Nenhuma expectativa no Mox da borda HTTP: qualquer chamada à origem derruba
      # este teste sozinho.
      {:ok, _} = Sources.end_observation(tenant, c.tools["alfa"], %{"confirmation" => "alfa"})

      assert {:error, :observation_ended} = Ingestion.start_sync(tenant, c.tools["alfa"])
    end

    test "as demais ferramentas seguem coletáveis" do
      tenant = tenant_fixture()
      c = cenario(tenant)

      {:ok, _} = Sources.end_observation(tenant, c.tools["alfa"], %{"confirmation" => "alfa"})

      assert length(Sources.list_observed_tools(tenant)) == 2
    end
  end

  describe "encerrar não afeta a outra instância (T011c)" do
    test "duas ferramentas para a mesma organização são registros distintos" do
      tenant = tenant_fixture()
      org = organization_fixture(tenant, "dupla")

      tools =
        for instancia <- ["https://github.com", "https://git.interno.example"] do
          {:ok, t} =
            %ConnectedTool{}
            |> ConnectedTool.changeset(%{
              tenant_id: tenant.id,
              tool_type: "github",
              instance_url: instancia,
              organization_login: "dupla"
            })
            |> Repo.insert()

          t
        end

      team_fixture(tenant, "T_dupla", %{organization: org})
      [primeira, segunda] = tools

      {:ok, _} = Sources.end_observation(tenant, primeira, %{"confirmation" => "dupla"})

      assert Sources.observation_ended?(primeira)
      refute Sources.observation_ended?(segunda)
    end
  end
end
