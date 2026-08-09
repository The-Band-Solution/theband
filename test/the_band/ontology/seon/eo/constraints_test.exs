defmodule TheBand.Ontology.SEON.EO.ConstraintsTest do
  @moduledoc """
  Cada teste protege uma limitação **declarada na base de conhecimento**. Se um
  deles quebrar, a resposta certa quase nunca é afrouxar o teste: é descobrir por
  que o código passou a contrariar o modelo.
  """

  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.Constraints

  describe "nível de acesso na plataforma não é papel organizacional" do
    test "MAINTAINER e MEMBER são aceitos como nível de acesso" do
      assert :ok = Constraints.platform_access_level_is_not_a_role("MAINTAINER")
      assert :ok = Constraints.platform_access_level_is_not_a_role("MEMBER")
    end

    test "qualquer outro valor é recusado, dizendo por quê" do
      assert {:error, mensagem} = Constraints.platform_access_level_is_not_a_role("developer")
      assert mensagem =~ "não é nível de acesso conhecido"
      assert mensagem =~ "nenhum dos dois é papel organizacional"
    end

    test "a evidência recusa nível de acesso desconhecido no changeset" do
      tenant = tenant_fixture()
      {:ok, pessoa} = EO.upsert_person_from_source(tenant, source_attrs("U_1", %{name: "Ana"}))
      {:ok, equipe} = EO.upsert_team_from_source(tenant, source_attrs("T_1", %{name: "Time"}))

      assert {:error, changeset} =
               EO.record_team_membership_evidence(tenant, %{
                 person_id: pessoa.id,
                 team_id: equipe.id,
                 person_external_id: "U_1",
                 team_external_id: "T_1",
                 platform_access_level: "programadora",
                 source_system: "github",
                 source_instance: "https://github.com",
                 observed_at: DateTime.utc_now(:second)
               })

      assert %{platform_access_level: [mensagem]} = errors_on(changeset)
      assert mensagem =~ "nível de acesso na plataforma"
    end
  end

  describe "alocação em equipe exige papel" do
    test "membership sem papel é recusada — o relator tem três termos" do
      assert {:error, mensagem} =
               Constraints.membership_requires_role(%{organizational_role_id: nil})

      assert mensagem =~ "sem papel organizacional"
    end

    test "membership com papel é aceita" do
      assert :ok =
               Constraints.membership_requires_role(%{
                 organizational_role_id: Ecto.UUID.generate()
               })
    end
  end

  describe "equipe do GitHub é organizacional" do
    test "project_team sem vínculo com repositório ou projeto é recusada" do
      assert {:error, mensagem} =
               Constraints.github_team_is_organizational(%{
                 type: "project_team",
                 granted_repositories: []
               })

      assert mensagem =~ "a equipe é organizacional"
    end

    test "organizational_team é sempre aceita" do
      assert :ok = Constraints.github_team_is_organizational(%{type: "organizational_team"})
    end
  end

  describe "vínculo observado" do
    test "é contado como pendente de papel enquanto não for promovido (FR-021)" do
      tenant = tenant_fixture()
      {:ok, pessoa} = EO.upsert_person_from_source(tenant, source_attrs("U_2", %{name: "Ana"}))
      {:ok, equipe} = EO.upsert_team_from_source(tenant, source_attrs("T_2", %{name: "Time"}))

      {:ok, evidencia} =
        EO.record_team_membership_evidence(tenant, %{
          person_id: pessoa.id,
          team_id: equipe.id,
          person_external_id: "U_2",
          team_external_id: "T_2",
          platform_access_level: "MAINTAINER",
          source_system: "github",
          source_instance: "https://github.com",
          observed_at: DateTime.utc_now(:second)
        })

      assert is_nil(evidencia.promoted_membership_id)
      assert EO.count_evidence_pending_role(tenant) == 1
      assert EO.count_evidence_pending_role(tenant, team_id: equipe.id) == 1
    end

    test "reobservar o mesmo vínculo não cria um segundo" do
      tenant = tenant_fixture()
      {:ok, pessoa} = EO.upsert_person_from_source(tenant, source_attrs("U_3", %{name: "Ana"}))
      {:ok, equipe} = EO.upsert_team_from_source(tenant, source_attrs("T_3", %{name: "Time"}))

      attrs = %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: "U_3",
        team_external_id: "T_3",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      }

      {:ok, _} = EO.record_team_membership_evidence(tenant, attrs)
      {:ok, _} = EO.record_team_membership_evidence(tenant, attrs)

      assert EO.count_evidence_pending_role(tenant) == 1
    end
  end

  describe "equipe do GitHub gravada" do
    test "nasce como organizational_team, nunca como project_team (FR-023)" do
      tenant = tenant_fixture()
      {:ok, equipe} = EO.upsert_team_from_source(tenant, source_attrs("T_4", %{name: "Time"}))

      assert equipe.type == "organizational_team"
    end
  end
end
