defmodule TheBand.Ontology.TenantRulesTest do
  @moduledoc """
  A regra do tenant, travada onde ela pode virar mapeamento por semelhança de nome
  (feature 004, T003).

  A regra em `rules/tenants/the_band_solution.yaml` declara os tipos de issue que
  **esta** organização usa e os campos do quadro que a plataforma interpreta. Ela é o
  padrão do qual a configuração de cada ferramenta parte.

  ## O que estes testes impedem

  Três coisas, e nenhuma delas quebraria a aplicação:

    * **`Priority` mapeado para `importance`.** É o antipadrão nomeado em
      `AGENTS.md` §7.7 — importance é decimal com escala declarada, `Priority` é
      seleção única cujos valores esta organização inventou. A conversão atribuiria
      escala a um rótulo, e toda ordem derivada mentiria sem avisar;
    * **campo identificado por nome.** Renomear "Priority" para "Prioridade"
      quebraria o mapeamento em silêncio. A identidade é o identificador — FR-027;
    * **a ausência de `importance` deixar de ser declarada.** Ausência silenciosa e
      ausência declarada parecem iguais no YAML, e só a segunda permite a tela dizer
      que a ordem não é derivável.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase

  @regra "github.issue_type_routing.the_band_solution"

  setup_all do
    {:ok, _} = KnowledgeBase.load()

    # `rule/1` em vez de varrer os artefatos: é a API pública do módulo, e usá-la
    # aqui verifica de quebra que a regra é alcançável pelo caminho que o código de
    # produção usa. Um teste que varre a lista passaria com a indexação quebrada.
    assert {:ok, regra} = KnowledgeBase.rule(@regra),
           "a regra #{@regra} não foi carregada da base"

    %{regra: regra}
  end

  describe "os tipos desta organização" do
    test "os três em uso estão declarados", %{regra: regra} do
      tipos = Enum.map(regra["type_mapping"], & &1["github_type"])
      assert Enum.sort(tipos) == ["Bug", "Feature", "Task"]
    end

    test "`Feature` roteia para dois conceitos, e a estrutura decide", %{regra: regra} do
      feature = Enum.find(regra["type_mapping"], &(&1["github_type"] == "Feature"))

      assert feature["decided_by"] == "structure"
      assert "sro.epic" in feature["concepts"]
      assert "sro.atomic_user_story" in feature["concepts"]
    end

    test "`Epic` e `User Story` constam como ausentes, com o motivo", %{regra: regra} do
      ausentes = Map.new(regra["absent_types"], &{&1["github_type"], &1["reason"]["pt-BR"]})

      # Ausente com motivo é decisão; ausente em silêncio é esquecimento. As duas
      # parecem iguais no YAML, e é por isso que o motivo é exigido aqui.
      assert Map.has_key?(ausentes, "Epic")
      assert Map.has_key?(ausentes, "User Story")
      assert ausentes["Epic"] =~ "estrutura"
    end
  end

  describe "os campos do quadro" do
    test "`Priority` NÃO é mapeado para importance", %{regra: regra} do
      mapeados = Enum.map(regra["field_mapping"] || [], & &1["target_attribute"])

      refute "sro.user_story.importance" in mapeados, """
      Algum campo passou a ser mapeado para `sro.user_story.importance`.

      Se for `Priority`, é o antipadrão de mapeamento por semelhança de nome:
      importance é decimal com escala declarada — quão valiosa a user story é para a
      organização —, e Priority é seleção única cujos valores esta organização
      inventou (P0, P1, P2). Converter um no outro atribui escala a um rótulo.

      Este quadro não tem campo numérico de importância, e a ausência é declarada em
      `missing_attributes`.
      """
    end

    test "`Priority`, `Size` e `Status` constam como não interpretados", %{regra: regra} do
      nao_mapeados = Enum.map(regra["unmapped_fields"], & &1["field_name"])

      assert "Priority" in nao_mapeados
      assert "Size" in nao_mapeados
      assert "Status" in nao_mapeados
    end

    test "todo campo citado traz o identificador, não só o nome", %{regra: regra} do
      campos = (regra["field_mapping"] || []) ++ regra["unmapped_fields"]

      for campo <- campos do
        assert campo["field_external_id"], """
        O campo "#{campo["field_name"] || campo["field_name_at_declaration"]}" está
        declarado sem `field_external_id`.

        A identidade de um campo configurável é o identificador — FR-027. Sem ele,
        renomear o campo no quadro quebra o mapeamento em silêncio.
        """
      end
    end

    test "a ausência de importância é declarada, não omitida", %{regra: regra} do
      faltantes = Map.new(regra["missing_attributes"], &{&1["attribute"], &1["reason"]["pt-BR"]})

      assert Map.has_key?(faltantes, "sro.user_story.importance")
      assert faltantes["sro.user_story.importance"] =~ "nula"
    end
  end

  describe "a regra sobrescreve a global sem substituí-la" do
    test "declara qual regra ela sobrescreve", %{regra: regra} do
      assert regra["overrides"] == "github.issue_type_routing"
    end

    test "a proveniência é decisão de projeto, e não observação", %{regra: regra} do
      assert regra["provenance"]["source_type"] == "project_decision"
    end
  end
end
