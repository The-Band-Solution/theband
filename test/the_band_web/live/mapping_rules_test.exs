defmodule TheBandWeb.MappingRulesTest do
  @moduledoc """
  A tela de regras de mapeamento (feature 005, F5).

  O teste que carrega o desenho é o que **recusa**: a tela não pode sugerir regra para
  `[Devops]` na lista de prováveis tipos. Sugerir daria ao produto 340 user stories que são
  rótulos de equipe.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Mapping
  alias TheBand.Ontology.KnowledgeBase

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, user: user, cenario: cenario}
  end

  describe "onde a tela vive" do
    test "não existe página própria de mapeamento" do
      # FR-050: a tela vive na sincronização. Uma página separada obrigaria a lembrar que
      # ela existe e a escolher a organização de novo.
      #
      # A pergunta é feita ao **roteador**, e não por requisição: uma requisição pode ser
      # redirecionada por autenticação e passar sem provar nada.
      assert Phoenix.Router.route_info(TheBandWeb.Router, "GET", "/mapeamento", "host") == :error

      assert %{plug: _} =
               Phoenix.Router.route_info(TheBandWeb.Router, "GET", "/sincronizacoes", "host")
    end

    test "o acesso parte da organização que produziu a lacuna", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/sincronizacoes")

      assert html =~ "regras de mapeamento"

      # Um clique a partir do cartão da organização — FR-052.
      assert live
             |> element("button", "regras de mapeamento")
             |> render_click() =~ "Regras de mapeamento"
    end

    test "o componente tem cabeçalho próprio, separado do relatório de execução",
         %{conn: conn} do
      html = abrir(conn)

      assert html =~ "Regras de mapeamento"
      assert html =~ "O que esta organização declarou"
      # E a tela hospedeira continua respondendo a pergunta dela.
      assert html =~ "Execuções"
    end
  end

  describe "o que a tela mostra" do
    test "declara quanto ainda não tem conceito", %{conn: conn} do
      html = abrir(conn)

      assert html =~ "ainda sem conceito"
    end

    test "as propostas do catálogo chegam propostas, não ativas", %{conn: conn} do
      html = abrir(conn)

      assert html =~ "Propostas do catálogo"
      assert html =~ "ativar todas"
      assert html =~ "economiza a escrita"
    end

    test "os padrões de área aparecem em lista separada, propondo a recusa",
         %{conn: conn, tenant: t, cenario: c} do
      # A tela só mostra padrões de área que existem nesta organização; o cenário não os
      # tem, então a lista fica vazia — e é o comportamento certo.
      html = abrir(conn)

      assert html =~ "Não são tipo"
      assert html =~ "quem faz"

      # E o ponto que mais importa: nenhum padrão de área é oferecido como proposta.
      propostas = Enum.map(Mapping.list_proposals(t, c.organization.id), & &1.pattern)
      refute "[Devops]" in propostas
      refute "[QA]" in propostas
    end
  end

  describe "ativar uma proposta" do
    test "cria a regra com a pessoa como autora, e enfileira o recálculo",
         %{conn: conn, tenant: t, user: u, cenario: c} do
      {:ok, live, _} = live(conn, ~p"/sincronizacoes")
      live |> element("button", "regras de mapeamento") |> render_click()

      chave =
        t
        |> Mapping.list_proposals(c.organization.id)
        |> Enum.find(&(&1.pattern == "Chore"))
        |> Map.fetch!(:catalog_key)

      html = live |> element("button[phx-value-chave='#{chave}']") |> render_click()

      assert html =~ "ativada"

      [regra] = Mapping.list_rules(t, c.organization.id)
      assert regra.created_by_id == u.id

      [job] = TheBand.Repo.all(Oban.Job)
      assert job.queue == "transformation"
    end
  end

  describe "a prévia antes de gravar" do
    test "mostra quantas casam e quantas mudariam, e são números diferentes",
         %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/sincronizacoes")
      live |> element("button", "regras de mapeamento") |> render_click()

      html =
        live
        |> element("form[phx-submit='criar']")
        |> render_change(%{
          "regra" => %{
            "where" => "declared_type",
            "how" => "equals",
            "pattern" => "Spike",
            "target_concept" => "sro.intended_scrum_development_task"
          }
        })

      assert html =~ "issues casam"
      assert html =~ "mudariam de conceito"
    end

    test "expressão que casa vazio é recusada com a razão, e nada é gravado",
         %{conn: conn, tenant: t, cenario: c} do
      {:ok, live, _} = live(conn, ~p"/sincronizacoes")
      live |> element("button", "regras de mapeamento") |> render_click()

      html =
        live
        |> element("form[phx-submit='criar']")
        |> render_change(%{
          "regra" => %{
            "where" => "title",
            "how" => "regex",
            "pattern" => ".*",
            "target_concept" => "sro.intended_scrum_development_task"
          }
        })

      assert html =~ "casaria todas as issues"
      assert Mapping.list_rules(t, c.organization.id) == []
    end
  end

  # Abre o componente a partir do cartão da organização — é o único caminho, e é o que
  # FR-052 pede.
  defp abrir(conn) do
    {:ok, live, _html} = live(conn, ~p"/sincronizacoes")
    live |> element("button", "regras de mapeamento") |> render_click()
  end
end
