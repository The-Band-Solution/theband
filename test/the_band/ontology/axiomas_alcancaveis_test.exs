defmodule TheBand.Ontology.AxiomasAlcancaveisTest do
  @moduledoc """
  Os axiomas da tese são alcançáveis por consulta — issue #320.

  ## O defeito que este arquivo trava

  `sro_axioms.yaml` e `spo_axioms.yaml` usam a chave de topo `rules:`, que não era nenhum dos
  nove tipos que o carregador reconhecia. Os nove axiomas caíam em `:unknown`: estavam na base,
  passavam na validação, e **nenhuma consulta por tipo os alcançava**.

  A `sro.rule07` — cuja violação a tela de processo exibe — funcionava porque estava escrita no
  código, e não porque a plataforma a lia da base. O princípio IV diz que a semântica vive no
  YAML; ela vivia, e ninguém conseguia perguntar a ela.

  **É o inverso da L57.** Lá, uma verificação filtrava um tipo que ninguém produzia e devolvia
  verde percorrendo lista vazia. Aqui um tipo era produzido e ninguém conseguia filtrá-lo. As
  duas têm a mesma forma: nada erra, nada avisa, e a consulta devolve o que não existe.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase

  setup_all do
    {:ok, artifacts} = KnowledgeBase.load()
    %{artifacts: artifacts}
  end

  test "nenhum arquivo de axioma é classificado como desconhecido", %{artifacts: artifacts} do
    desconhecidos =
      artifacts
      |> Enum.filter(&(&1.kind == :unknown))
      |> Enum.map(& &1.path)

    assert Enum.filter(desconhecidos, &String.contains?(&1, "axioms")) == [],
           """
           Um arquivo de axiomas voltou a cair em `:unknown`.

           Isso não quebra nada e não avisa nada: a base carrega, a validação passa, e os
           axiomas simplesmente somem de toda consulta por tipo.
           """
  end

  test "os axiomas têm tipo próprio, e não se misturam às regras de derivação", %{
    artifacts: artifacts
  } do
    axiomas = Enum.filter(artifacts, &(&1.kind == :axiom))
    derivacoes = Enum.filter(artifacts, &(&1.kind == :derivation_rule))

    assert length(axiomas) == 2, "os dois arquivos de axioma — SRO e SPO"
    assert derivacoes != []

    refute Enum.any?(derivacoes, &String.contains?(&1.path, "axioms")),
           """
           Um axioma foi classificado como regra de derivação.

           Axioma vem da tese e diz o que a rede afirma ser verdade; regra de derivação é
           decisão da plataforma sobre como derivar um valor. Juntos num tipo só, quem
           perguntasse "quais regras a plataforma decidiu" receberia os axiomas junto.
           """
  end

  describe "consultar os axiomas" do
    test "a lista devolve cada axioma, e não os dois arquivos que os contêm" do
      axiomas = KnowledgeBase.axioms()

      assert length(axiomas) == 9, "sete da SRO e dois da SPO"
      assert Enum.all?(axiomas, &is_map/1)
      assert Enum.all?(axiomas, &Map.has_key?(&1, "id"))
    end

    test "a `sro.rule07` é alcançável pela base, e não só pelo código" do
      assert {:ok, axioma} = KnowledgeBase.axiom("sro.rule07.task_never_meets_epic")

      assert axioma["ontology"] == "sro"
      assert axioma["statement"]["pt-BR"] =~ "épico"

      assert axioma["provenance"]["source_type"] == "thesis",
             "o que distingue axioma de regra de derivação é vir da tese"
    end

    test "identificador que não existe devolve erro, e não o axioma mais parecido" do
      assert :error = KnowledgeBase.axiom("sro.rule99.inexistente")
      assert :error = KnowledgeBase.axiom("sro.rule07")
    end
  end

  describe "nenhum artefato novo some em silêncio" do
    # **O teste acima trava o defeito; este trava a família dele.**
    #
    # Consertar os dois arquivos de axioma não impede o próximo arquivo de cair em
    # `:unknown` exatamente do mesmo jeito — e não é hipótese: em 2026-08-15
    # `profile_thresholds.yaml` nasceu com `rules:` e ficou ilegível por
    # `KnowledgeBase.rule/1`, meses depois de os axiomas terem caído no mesmo buraco. A
    # segunda mordida veio de a primeira nunca ter deixado guarda.
    #
    # Os JSON Schemas são o `:unknown` **legítimo**: não são artefatos de conhecimento, e
    # `SchemaCheck` os alcança pelo caminho, com `Regex.run(~r{schemas/…})`. Tipá-los
    # inventaria um tipo para arquivos que existem só para validar os outros.
    #
    # `sources/`, `glossary/` e `examples/` **não** são legítimos: são conhecimento, e
    # nenhuma consulta por tipo os alcança. Estão declarados aqui como **dívida**, e não
    # como decisão — a #320 cobriu os axiomas e parou neles.
    @unknown_esperado ~w(
      examples/sro_espm_project.yaml
      glossary/glossary.yaml
      schemas/common.schema.yaml
      schemas/competency-question.schema.yaml
      schemas/information-need.schema.yaml
      schemas/mapping.schema.yaml
      schemas/measurement.schema.yaml
      schemas/module.schema.yaml
      schemas/ontology.schema.yaml
      schemas/transformation.schema.yaml
      sources/azure_devops.yaml
      sources/github.yaml
      sources/gitlab.yaml
      sources/jira.yaml
      sources/sonar.yaml
    )

    test "a lista de :unknown é a declarada — nem mais, nem menos", %{artifacts: artifacts} do
      atual =
        artifacts |> Enum.filter(&(&1.kind == :unknown)) |> Enum.map(& &1.path) |> Enum.sort()

      novos = atual -- @unknown_esperado
      resolvidos = @unknown_esperado -- atual

      assert novos == [],
             """
             Estes arquivos passaram a carregar como `:unknown`, e nenhuma consulta por tipo
             os alcança:

             #{Enum.map_join(novos, "\n", &"  #{&1}")}

             A chave de topo tem de ser um dos tipos de `YamlLoader.@tops`. Se o arquivo é de
             um tipo novo, acrescente o tipo lá — não o deixe em `:unknown`, que é onde os
             axiomas ficaram invisíveis por duas features.
             """

      assert resolvidos == [],
             """
             Estes arquivos deixaram de ser `:unknown`, o que é bom — tire-os da lista:

             #{Enum.map_join(resolvidos, "\n", &"  #{&1}")}
             """
    end
  end
end
