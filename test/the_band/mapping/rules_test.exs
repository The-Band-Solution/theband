defmodule TheBand.Mapping.RulesTest do
  @moduledoc """
  As regras de mapeamento por organização (feature 005, F1).

  O que estes testes protegem é a **recusa**: regra sem autor, padrão que não compila,
  conceito que não existe, e apagamento de regra que tem promoção apontando para ela.
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

    %{tenant: tenant, org: cenario.organization.id, user: user, cenario: cenario}
  end

  describe "criar" do
    test "exige autor na assinatura, e não há versão sem ele" do
      # A obrigatoriedade está no **tipo**: `create_rule/4`, e nenhuma aridade menor.
      # É o mesmo desenho de `mark_issues_no_longer_observed/3`, onde o escopo é
      # obrigatório porque esquecê-lo custou a L19.

      # **`ensure_loaded!` antes, e não é detalhe.** `function_exported?/3` devolve `false`
      # para módulo ainda não carregado — e aí o `refute` abaixo passa por vacuidade,
      # inclusive se alguém criar o `create_rule/3` que ele existe para proibir. O `assert`
      # falha no mesmo caso, então o teste alternava entre passar errado e falhar sem
      # motivo, dependendo do que rodou antes dele.
      Code.ensure_loaded!(Mapping)

      refute function_exported?(Mapping, :create_rule, 3)
      assert function_exported?(Mapping, :create_rule, 4)
    end

    test "grava a regra com autor, posição e versão", %{tenant: t, org: org, user: u} do
      assert {:ok, regra} =
               Mapping.create_rule(
                 t,
                 org,
                 %{
                   where: "declared_type",
                   how: "equals",
                   pattern: "Chore",
                   target_concept: "sro.intended_scrum_development_task"
                 },
                 u.id
               )

      assert regra.created_by_id == u.id
      assert regra.position == 1
      assert regra.version == 1
      assert regra.active
    end

    test "a posição seguinte é a próxima livre, e o índice único a garante",
         %{tenant: t, org: org, user: u} do
      {:ok, a} = criar(t, org, u, %{pattern: "Chore"})
      {:ok, b} = criar(t, org, u, %{pattern: "Refactor"})

      assert [a.position, b.position] == [1, 2]
    end

    test "recusa conceito que não existe na base de conhecimento",
         %{tenant: t, org: org, user: u} do
      assert {:error, {:unknown_concept, "sro.coisa_inventada"}} =
               criar(t, org, u, %{target_concept: "sro.coisa_inventada"})

      # E nada foi gravado: a recusa é antes de tocar o banco.
      assert Mapping.list_rules(t, org) == []
    end

    test "recusa expressão que não compila, e nada é gravado",
         %{tenant: t, org: org, user: u} do
      assert {:error, {:invalid_pattern, {:does_not_compile, _razao, _pos}}} =
               criar(t, org, u, %{how: "regex", pattern: "[US"})

      assert Mapping.list_rules(t, org) == []
    end

    test "recusa expressão que casa vazio", %{tenant: t, org: org, user: u} do
      assert {:error, {:invalid_pattern, :matches_empty}} =
               criar(t, org, u, %{how: "regex", pattern: ".*"})
    end

    test "recusa a mesma comparação duas vezes na mesma organização",
         %{tenant: t, org: org, user: u} do
      {:ok, _} = criar(t, org, u, %{pattern: "Chore"})

      assert {:error, changeset} = criar(t, org, u, %{pattern: "Chore"})

      assert "esta organização já declarou esta comparação" in errors_on(changeset).organization_id
    end
  end

  describe "alterar e desativar" do
    test "alterar incrementa a versão e revalida o padrão",
         %{tenant: t, org: org, user: u} do
      {:ok, regra} = criar(t, org, u, %{pattern: "Chore"})

      assert {:ok, alterada} =
               Mapping.update_rule(t, regra.id, %{target_concept: "osdef.defect"}, u.id)

      assert alterada.version == 2
      assert alterada.target_concept == "osdef.defect"

      # Alterar sem revalidar deixaria entrar por edição o que a criação recusa.
      assert {:error, {:invalid_pattern, :matches_empty}} =
               Mapping.update_rule(t, regra.id, %{how: "regex", pattern: ".*"}, u.id)
    end

    test "desativar não apaga, e a regra continua consultável",
         %{tenant: t, org: org, user: u} do
      {:ok, regra} = criar(t, org, u, %{pattern: "Chore"})

      assert {:ok, desativada} = Mapping.deactivate_rule(t, regra.id, u.id)
      refute desativada.active
      assert desativada.deactivated_by_id == u.id

      # Some das vigentes, permanece na listagem completa: a promoção que ela produziu
      # aponta para ela, e apagá-la tornaria a proveniência ilegível.
      assert Mapping.active_rules(t, org) == []
      assert [_] = Mapping.list_rules(t, org)
    end

    test "não existe função para apagar regra" do
      refute function_exported?(Mapping, :delete_rule, 2)
      refute function_exported?(Mapping, :delete_rule, 3)
    end
  end

  describe "não é tipo" do
    test "declarar tira o padrão da pendência sem promover nada",
         %{tenant: t, org: org, user: u} do
      assert {:ok, decisao} = Mapping.declare_not_a_type(t, org, "[Devops]", u.id, "área")

      assert decisao.decided_by_id == u.id
      assert [%{pattern: "[Devops]"}] = Mapping.list_not_a_type(t, org)

      # E nenhuma regra foi criada: declarar que não é tipo não mapeia.
      assert Mapping.list_rules(t, org) == []
    end

    test "declarar duas vezes o mesmo padrão não duplica",
         %{tenant: t, org: org, user: u} do
      {:ok, _} = Mapping.declare_not_a_type(t, org, "[QA]", u.id)
      {:ok, _} = Mapping.declare_not_a_type(t, org, "[QA]", u.id)

      assert length(Mapping.list_not_a_type(t, org)) == 1
    end

    test "reverter devolve o padrão à lista, e o registro permanece",
         %{tenant: t, org: org, user: u} do
      {:ok, decisao} = Mapping.declare_not_a_type(t, org, "[Dados]", u.id)

      assert {:ok, revertida} = Mapping.revert_not_a_type(t, decisao.id, u.id)
      assert revertida.reverted_by_id == u.id
      assert Mapping.list_not_a_type(t, org) == []

      # A reversão é fato novo, não apagamento: quem decidiu o quê permanece.
      assert revertida.decided_by_id == u.id
    end
  end

  describe "isolamento entre tenants" do
    test "regra de outro tenant devolve não encontrada, nunca sem permissão",
         %{tenant: t, org: org, user: u} do
      {:ok, regra} = criar(t, org, u, %{pattern: "Chore"})
      outro = tenant_fixture()

      assert Mapping.fetch_rule(outro, regra.id) == {:error, :not_found}
      assert Mapping.list_rules(outro, org) == []
    end
  end

  defp criar(tenant, org, user, attrs) do
    Mapping.create_rule(
      tenant,
      org,
      Map.merge(
        %{
          where: "declared_type",
          how: "equals",
          pattern: "Chore",
          target_concept: "sro.intended_scrum_development_task"
        },
        attrs
      ),
      user.id
    )
  end
end
