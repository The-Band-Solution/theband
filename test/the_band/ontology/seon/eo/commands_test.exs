defmodule TheBand.Ontology.SEON.EO.CommandsTest do
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO

  describe "proveniência" do
    test "registro sem Application Reference é rejeitado como inválido, não gravado incompleto" do
      tenant = tenant_fixture()

      assert {:error, changeset} =
               EO.upsert_person_from_source(tenant, %{name: "Sem origem"})

      assert %{provenance: [mensagem]} = errors_on(changeset)
      assert mensagem =~ "Application Reference incompleta"
    end

    test "falta parcial de proveniência também rejeita, nomeando o que falta" do
      tenant = tenant_fixture()

      attrs = %{name: "Meia origem", source_system: "github", external_id: "X1"}

      assert {:error, changeset} = EO.upsert_person_from_source(tenant, attrs)
      assert %{provenance: [mensagem]} = errors_on(changeset)
      assert mensagem =~ "source_instance"
      assert mensagem =~ "collected_at"
    end
  end

  describe "idempotência (FR-014, SC-003)" do
    test "segunda chamada com os mesmos atributos não altera record_version" do
      tenant = tenant_fixture()
      attrs = source_attrs("U_1", %{name: "Ana"})

      assert {:ok, primeira} = EO.upsert_person_from_source(tenant, attrs)
      assert primeira.outcome == :created
      assert primeira.record_version == 1

      assert {:ok, segunda} = EO.upsert_person_from_source(tenant, attrs)
      assert segunda.outcome == :unchanged
      assert segunda.record_version == 1
      assert segunda.id == primeira.id

      assert EO.count_people(tenant) == 1
    end

    test "atributo alterado na origem atualiza e incrementa record_version" do
      tenant = tenant_fixture()

      {:ok, antes} = EO.upsert_person_from_source(tenant, source_attrs("U_2", %{name: "Ana"}))

      {:ok, depois} =
        EO.upsert_person_from_source(tenant, source_attrs("U_2", %{name: "Ana Maria"}))

      assert depois.outcome == :updated
      assert depois.record_version == antes.record_version + 1
      assert depois.name == "Ana Maria"
      assert EO.count_people(tenant) == 1
    end

    test "internal_id é determinístico: mesma origem, mesmo identificador" do
      tenant = tenant_fixture()
      attrs = source_attrs("U_3", %{name: "Bruno"})

      {:ok, primeira} = EO.upsert_person_from_source(tenant, attrs)
      {:ok, segunda} = EO.upsert_person_from_source(tenant, attrs)

      assert primeira.internal_id == segunda.internal_id
    end
  end

  describe "isolamento entre tenants (FR-027, SC-008)" do
    test "o mesmo identificador externo em dois tenants gera dois registros distintos" do
      um = tenant_fixture("um")
      outro = tenant_fixture("outro")

      {:ok, pessoa_um} = EO.upsert_person_from_source(um, source_attrs("U_MESMO", %{name: "Ana"}))

      {:ok, pessoa_outro} =
        EO.upsert_person_from_source(outro, source_attrs("U_MESMO", %{name: "Ana"}))

      refute pessoa_um.id == pessoa_outro.id
      assert EO.count_people(um) == 1
      assert EO.count_people(outro) == 1
    end

    test "a listagem de um tenant nunca devolve registro do outro" do
      um = tenant_fixture("um")
      outro = tenant_fixture("outro")

      {:ok, _} = EO.upsert_person_from_source(um, source_attrs("U_A", %{name: "Só do um"}))

      assert [pessoa] = EO.list_people(um)
      assert pessoa.name == "Só do um"
      assert EO.list_people(outro) == []
    end
  end

  describe "classificação de contas (FR-022)" do
    test "automação é registrada e fica fora da contagem de pessoas" do
      tenant = tenant_fixture()

      {:ok, _} = EO.upsert_person_from_source(tenant, source_attrs("U_H", %{name: "Humana"}))

      {:ok, bot} =
        EO.upsert_person_from_source(
          tenant,
          source_attrs("U_B", %{name: "dependabot", account_type: "bot"})
        )

      assert bot.account_type == "bot"
      assert EO.count_people(tenant, account_type: "person") == 1
      assert EO.count_people(tenant, account_type: ["bot", "app"]) == 1
      # A automação continua consultável — descartá-la perderia o vínculo com a
      # equipe onde ela aparece.
      assert length(EO.list_people(tenant)) == 2
    end
  end
end
