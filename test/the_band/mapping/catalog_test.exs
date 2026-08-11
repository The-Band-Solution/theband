defmodule TheBand.Mapping.CatalogTest do
  @moduledoc """
  O catálogo composto por organização (feature 005, F4).

  Dois testes carregam o desenho inteiro: **nada é copiado na conexão**, e **reordenar o
  YAML não desliga decisões**. Os dois são a diferença entre compor em leitura e copiar.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Mapping
  alias TheBand.Ontology.KnowledgeBase

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    user = user_fixture(tenant)
    %{tenant: tenant, org: cenario.organization.id, user: user}
  end

  describe "a composição" do
    test "organização recém-conectada não tem nenhuma linha gravada",
         %{tenant: t, org: org} do
      propostas = Mapping.list_proposals(t, org)

      assert length(propostas) >= 10
      assert Enum.all?(propostas, &(&1.state == :proposed))

      # É o ponto do desenho: copiar na conexão criaria 18 linhas com autor "sistema".
      assert Mapping.list_rules(t, org) == []
    end

    test "a proposta traz o conceito, a nota e quantas issues casaria aqui",
         %{tenant: t, org: org} do
      proposta = Enum.find(Mapping.list_proposals(t, org), &(&1.pattern == "Chore"))

      assert proposta.target_concept == "sro.intended_scrum_development_task"
      assert proposta.where == "declared_type"
      assert is_integer(proposta.would_match)
      assert proposta.note =~ "manutenção"
    end

    test "would_match é medido NESTA organização, não copiado do catálogo",
         %{tenant: t, org: org} do
      # O cenário não tem issues `Chore`: a contagem do catálogo diz 17, e aqui é zero.
      proposta = Enum.find(Mapping.list_proposals(t, org), &(&1.pattern == "Chore"))

      assert proposta.seen == 17

      assert proposta.would_match == 0, """
      Mostrar o número do catálogo faria a tela prometer o que não existe nesta
      organização — e zero é "não aplicável aqui", não erro (FR-045).
      """
    end
  end

  describe "ativar" do
    test "ativar registra a pessoa como autora, nunca sistema",
         %{tenant: t, org: org, user: u} do
      proposta = Enum.find(Mapping.list_proposals(t, org), &(&1.pattern == "Chore"))

      assert {:ok, regra} = Mapping.activate_catalog_rule(t, org, proposta.catalog_key, u.id)

      assert regra.created_by_id == u.id
      assert regra.catalog_key == proposta.catalog_key
    end

    test "depois de ativar, a proposta aparece como ativada", %{tenant: t, org: org, user: u} do
      proposta = Enum.find(Mapping.list_proposals(t, org), &(&1.pattern == "Chore"))
      {:ok, _} = Mapping.activate_catalog_rule(t, org, proposta.catalog_key, u.id)

      depois = Enum.find(Mapping.list_proposals(t, org), &(&1.pattern == "Chore"))
      assert depois.state == :activated
    end

    test "editar a regra ativada a marca como editada, e o YAML não muda",
         %{tenant: t, org: org, user: u} do
      antes = File.read!("priv/knowledge_base/rules/github_issue_pattern_catalog.yaml")

      proposta = Enum.find(Mapping.list_proposals(t, org), &(&1.pattern == "Chore"))
      {:ok, regra} = Mapping.activate_catalog_rule(t, org, proposta.catalog_key, u.id)
      {:ok, _} = Mapping.update_rule(t, regra.id, %{target_concept: "osdef.defect"}, u.id)

      depois = Enum.find(Mapping.list_proposals(t, org), &(&1.pattern == "Chore"))
      assert depois.state == :edited

      assert File.read!("priv/knowledge_base/rules/github_issue_pattern_catalog.yaml") == antes,
             "editar a regra da organização não pode alterar o catálogo das outras (FR-042)"
    end

    test "ativar todas cria uma regra por proposta, com a mesma autoria",
         %{tenant: t, org: org, user: u} do
      {:ok, criadas} = Mapping.activate_all_proposals(t, org, u.id)

      assert length(criadas) >= 10
      assert Enum.all?(criadas, &(&1.created_by_id == u.id))
      assert Enum.all?(Mapping.list_proposals(t, org), &(&1.state != :proposed))
    end

    test "ativar todas duas vezes não duplica", %{tenant: t, org: org, user: u} do
      {:ok, primeira} = Mapping.activate_all_proposals(t, org, u.id)
      {:ok, segunda} = Mapping.activate_all_proposals(t, org, u.id)

      assert segunda == []
      assert length(Mapping.list_rules(t, org)) == length(primeira)
    end

    test "chave inexistente é recusada em vez de criar regra do nada",
         %{tenant: t, org: org, user: u} do
      assert {:error, :unknown_entry} =
               Mapping.activate_catalog_rule(t, org, "title|starts_with|[inexistente]", u.id)

      assert Mapping.list_rules(t, org) == []
    end

    test "a chave não depende da ordem no YAML", %{tenant: t, org: org} do
      chaves = Enum.map(Mapping.list_proposals(t, org), & &1.catalog_key)

      # `(where, how, pattern)` normalizado. Reordenar o catálogo não pode desligar
      # decisões já tomadas, e o índice na lista faria exatamente isso.
      assert "declared_type|equals|chore" in chaves
      assert Enum.all?(chaves, &String.contains?(&1, "|"))
      refute Enum.any?(chaves, &String.match?(&1, ~r/^\d+$/))
    end
  end

  describe "o que NÃO é tipo" do
    test "o catálogo lista os padrões de área, para serem recusados",
         %{tenant: t, org: org} do
      padroes = Mapping.not_type_patterns(t, org)
      textos = Enum.map(padroes, & &1.pattern)

      assert "[Devops]" in textos
      assert "[QA]" in textos

      # E nenhum deles aparece entre as propostas: sugerir regra para `[Devops]` daria ao
      # produto 340 user stories que são rótulos de equipe.
      propostas = Enum.map(Mapping.list_proposals(t, org), & &1.pattern)
      refute "[Devops]" in propostas
      refute "[QA]" in propostas
    end

    test "a razão está escrita, e é sobre medida errada", %{tenant: _t} do
      assert Mapping.not_type_reason() =~ "área"
      assert Mapping.not_type_reason() =~ "Conceito errado é pior que conceito ausente"
    end
  end
end
