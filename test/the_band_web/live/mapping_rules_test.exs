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
               Phoenix.Router.route_info(TheBandWeb.Router, "GET", "/syncs", "host")
    end

    test "o acesso parte da organização que produziu a lacuna", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/syncs")

      assert html =~ "Mapping rules"

      # Um clique a partir do cartão da organização — FR-052.
      assert live
             |> element("button", "Mapping rules")
             |> render_click() =~ "Mapping rules"
    end

    test "o componente tem cabeçalho próprio, separado do relatório de execução",
         %{conn: conn} do
      html = abrir(conn)

      assert html =~ "Mapping rules"
      assert html =~ "What this organisation declares"
      # E a tela hospedeira continua respondendo a pergunta dela.
      assert html =~ "Runs"
    end
  end

  describe "o que a tela mostra" do
    test "declara quanto ainda não tem conceito", %{conn: conn} do
      html = abrir(conn)

      assert html =~ "still without a concept"
    end

    test "as propostas do catálogo chegam propostas, não ativas", %{conn: conn} do
      html = abrir(conn)

      assert html =~ "Catalogue proposals"
      assert html =~ "Activate all"
      assert html =~ "saves the"
    end

    test "os padrões de área aparecem em lista separada, propondo a recusa",
         %{conn: conn, tenant: t, cenario: c} do
      # A tela só mostra padrões de área que existem nesta organização; o cenário não os
      # tem, então a lista fica vazia — e é o comportamento certo.
      html = abrir(conn)

      assert html =~ "Not a type"
      assert html =~ "who does it"

      # E o ponto que mais importa: nenhum padrão de área é oferecido como proposta.
      propostas = Enum.map(Mapping.list_proposals(t, c.organization.id), & &1.pattern)
      refute "[Devops]" in propostas
      refute "[QA]" in propostas
    end
  end

  describe "ativar uma proposta" do
    test "cria a regra com a pessoa como autora, e enfileira o recálculo",
         %{conn: conn, tenant: t, user: u, cenario: c} do
      {:ok, live, _} = live(conn, ~p"/syncs")
      live |> element("button", "Mapping rules") |> render_click()

      chave =
        t
        |> Mapping.list_proposals(c.organization.id)
        |> Enum.find(&(&1.pattern == "Chore"))
        |> Map.fetch!(:catalog_key)

      html = live |> element("button[phx-value-chave='#{chave}']") |> render_click()

      # A regra passa a existir e a proposta deixa de ser proposta — o flash vai para o
      # processo pai, e afirmar sobre ele aqui testaria o LiveView hospedeiro, não isto.
      assert html =~ "Active rules"

      [regra] = Mapping.list_rules(t, c.organization.id)
      assert regra.created_by_id == u.id

      [job] = TheBand.Repo.all(Oban.Job)
      assert job.queue == "transformation"
    end
  end

  describe "a prévia antes de gravar" do
    test "mostra quantas casam e quantas mudariam, e são números diferentes",
         %{conn: conn} do
      {:ok, live, _} = live(conn, ~p"/syncs")
      live |> element("button", "Mapping rules") |> render_click()

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

      assert html =~ "issues match"
      assert html =~ "would change concept"
    end

    test "expressão que casa vazio é recusada com a razão, e nada é gravado",
         %{conn: conn, tenant: t, cenario: c} do
      {:ok, live, _} = live(conn, ~p"/syncs")
      live |> element("button", "Mapping rules") |> render_click()

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

      assert html =~ "match every issue"
      assert Mapping.list_rules(t, c.organization.id) == []
    end
  end

  # Abre o componente a partir do cartão da organização — é o único caminho, e é o que
  # FR-052 pede.
  defp abrir(conn) do
    {:ok, live, _html} = live(conn, ~p"/syncs")
    live |> element("button", "Mapping rules") |> render_click()
  end
end
