defmodule TheBandWeb.IndefinidaTest do
  @moduledoc """
  A issue que não se enquadrou em conceito nenhum aparece **nomeada**.

  E o teste que mais importa é o que **recusa**: `indefinida` não pode virar conceito da
  ontologia. Se virar, as issues entram em contagens de conceito e "3360 indefinidas" passa
  a ser lido como um tipo de trabalho que o time faz — ausência de conhecimento virando
  conhecimento.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBandWeb.ConceptLabel

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  describe "o rótulo" do
    test "diz indefinida e o motivo, e o tipo encontrado quando há" do
      assert ConceptLabel.indefinida("type_unknown", "Spike") ==
               "undefined — type Spike has no rule"

      assert ConceptLabel.indefinida("type_absent", nil) == "undefined — no type at the source"
      assert ConceptLabel.indefinida(nil, nil) == "undefined — no promotion recorded"
    end

    test "indefinida NÃO é conceito da base de conhecimento" do
      refute KnowledgeBase.concept?("sro.undefined")
      refute KnowledgeBase.concept?("undefined")

      # E não está na lista que as telas usam para contar por conceito: se estivesse, as
      # issues sem conceito entrariam na contagem de conceitos.
      refute Enum.any?(ConceptLabel.conceitos(), fn {_id, rotulo} -> rotulo == "undefined" end)
    end
  end

  describe "nas telas" do
    test "a listagem de trabalho nomeia as indefinidas", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/work")

      assert html =~ "undefined —"
      assert html =~ "type Spike has no rule"
    end

    test "o detalhe da issue sem conceito nomeia a lacuna", %{conn: conn, cenario: c} do
      {:ok, _live, html} = live(conn, ~p"/work/issues/#{c.issues[202].pai.id}")

      assert html =~ "undefined —"
    end

    test "a tela do repositório nomeia as indefinidas na contagem",
         %{conn: conn, cenario: c} do
      {:ok, _live, html} = live(conn, ~p"/work/repositories/#{c.observed_repository_id}")

      assert html =~ "undefined —"
    end
  end
end
