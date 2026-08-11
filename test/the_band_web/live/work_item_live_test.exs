defmodule TheBandWeb.WorkItemLiveTest do
  @moduledoc """
  A tela `/trabalho`, com a forma do dado real (T028).

  O cenário vem de `TheBand.WorkItemsFixtures.cenario_real/2`, medido pela API em
  2026-08-11 — inclui as três `Feature` com sub-issues que **não** são épicos.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  describe "as contagens" do
    test "a soma fecha: coletadas = promovidas + lacunas", %{tenant: tenant} do
      coletadas = WorkItems.count_collected(tenant)
      promovidas = tenant |> WorkItems.count_by_promotion() |> Map.values() |> Enum.sum()
      lacunas = tenant |> WorkItems.count_gaps_by_reason() |> Map.values() |> Enum.sum()

      assert coletadas == promovidas + lacunas, """
      A soma não fecha: #{coletadas} coletadas, #{promovidas} promovidas, #{lacunas} lacunas.

      Alguma issue não tem promoção registrada, e o número que a tela mostra passa a ser
      menor que a realidade sem avisar. É o SC-001.
      """
    end

    test "a tela não mostra o aviso de desvio quando a soma fecha", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/trabalho")

      refute html =~ "As contagens não somam"
    end
  end

  describe "a classificação, nos seis casos reais" do
    test "#3 com nove partes Task é ATÔMICA, não épico", %{tenant: tenant, cenario: c} do
      issue = c.issues[3].pai

      assert WorkItems.classification(tenant, issue.id) == :atomic_user_story, """
      A issue #3 tem nove sub-issues, todas do tipo Task, e é ATÔMICA.

      Tarefa ATENDE a user story, não a compõe. Se ela virar épico, as tarefas passam a
      se ligar a épicos e violam sro.rule07 — e o esforço é contado duas vezes.
      """
    end

    test "#1, #79 e #98 são épicos, porque têm partes que são user stories", %{
      tenant: tenant,
      cenario: c
    } do
      for numero <- [1, 79, 98] do
        assert WorkItems.classification(tenant, c.issues[numero].pai.id) == :epic,
               "a issue ##{numero} tem partes que são user stories e deveria ser épico"
      end
    end

    test "#4 e #5 são atômicas", %{tenant: tenant, cenario: c} do
      for numero <- [4, 5] do
        assert WorkItems.classification(tenant, c.issues[numero].pai.id) == :atomic_user_story
      end
    end
  end

  describe "a lacuna aparece com o nome do tipo" do
    test "Spike é contado, e o nome aparece na tela", %{conn: conn, tenant: tenant} do
      assert WorkItems.unknown_types(tenant) == [{"Spike", 1}]

      {:ok, _live, html} = live(conn, ~p"/trabalho")

      assert html =~ "tipo desconhecido"

      assert html =~ "Spike (1)", """
      A tela não mostrou o nome do tipo desconhecido.

      "tipo desconhecido: 1" não diz onde a regra precisa mudar. "Spike (1)" diz.
      """
    end

    test "issue sem tipo aparece como lacuna própria", %{conn: conn, tenant: tenant} do
      assert WorkItems.count_gaps_by_reason(tenant)["type_absent"] == 1

      {:ok, _live, html} = live(conn, ~p"/trabalho")
      assert html =~ "sem tipo na origem"
    end

    test "nenhuma issue de tipo desconhecido aparece promovida", %{tenant: tenant} do
      promovidas =
        tenant
        |> WorkItems.list_issues(limit: 500)
        |> Enum.filter(& &1.derived_concept)
        |> Enum.map(& &1.issue_type)

      refute "Spike" in promovidas
      refute nil in promovidas
    end
  end

  describe "a divergência" do
    test "não há divergência quando a regra do tenant cobre os dois conceitos", %{
      tenant: tenant
    } do
      # `Feature` cobre épico e atômica na regra desta organização: o rótulo não afirma
      # qual, e a estrutura completa o que ele não disse. Não há o que divergir.
      assert WorkItems.list_divergences(tenant) == []
    end

    test "a tela diz isso em vez de deixar a seção vazia", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/trabalho")

      assert html =~ "tipo declarado e a estrutura concordam"
    end
  end

  describe "a tela mostra o repositório com o que o git fornece" do
    test "nome, linguagem e ramo padrão", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/trabalho")

      assert html =~ "theband"
      assert html =~ "Elixir"
      assert html =~ "main"
    end

    test "não há botão de coletar aqui: sincronizar traz tudo", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/trabalho")

      # Dois lugares para disparar a mesma coleta produziriam duas leituras de "quando
      # isto foi atualizado". A coleta é uma, e tem tela própria.
      refute html =~ "coletar issues de"
      assert html =~ "pessoas, equipes, repositórios e issues vêm na mesma coleta"
    end
  end

  describe "o que a tela NÃO mostra" do
    test "nenhuma soma de épicos com atômicas", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/trabalho")

      # Somar os dois seria contagem dupla: tarefa se liga a atômica, e escopo se conta
      # na folha.
      refute html =~ "total de user stories"
    end

    test "nenhum percentual de cobertura", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/trabalho")

      refute html =~ "cobertura"
      refute html =~ "% promovid"
    end
  end

  describe "isolamento entre tenants" do
    test "o vizinho não vê issue nenhuma", %{conn: conn} do
      {outro, usuario} = tenant_with_admin("vizinho")

      assert WorkItems.count_collected(outro) == 0

      {:ok, _live, html} = live(log_in(conn, usuario), ~p"/trabalho")
      assert html =~ "Nenhuma coleta de issues ocorreu ainda"
    end
  end
end
