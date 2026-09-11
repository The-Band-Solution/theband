defmodule TheBandWeb.SubequipeTest do
  @moduledoc """
  Feature 055, US3 — a estrutura na tela da equipe, e a subequipe.

  **A subequipe herda a organização da mãe**, e não há seletor. Oferecer um faria
  a autoridade subir: quem tem escopo nesta equipe declara DENTRO dela, e não em
  qualquer lugar da organização.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")
    {:ok, mae} = EO.declare_structural_team(tenant, org.id, "Plataforma", admin.id)

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, org: org, mae: mae}
  end

  # O ALERTA, e não a página. Ler a página inteira dá falso positivo: a aba de estrutura tem
  # a frase *"does not exist at any source tool"* como texto fixo, e uma sonda que procurasse
  # `does not exist` no HTML acusaria recusa em TODO caso — inclusive nos felizes. Aconteceu
  # em 2026-09-10, e é o que esta função existe para impedir.
  #
  # `flash-info` e `flash-error` são os ids que `CoreComponents.flash/1` gera.
  defp alerta(html, tipo) do
    case Regex.run(~r/id="flash-#{tipo}".*?<div>(.*?)<\/div>/s, html) do
      [_, dentro] ->
        dentro
        |> String.replace(~r/<[^>]*>/, " ")
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      _ ->
        nil
    end
  end

  defp submeter(ctx, nome) do
    {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}?tab=structure")
    render_submit(view, "criar_subequipe", %{"name" => nome})
  end

  describe "o caminho feliz, PELA TELA — o que a pessoa lê" do
    test "o alerta nomeia a equipe criada, e não há erro nenhum", ctx do
      html = submeter(ctx, "Squad Azul")

      assert alerta(html, "info") == "Team Squad Azul declared inside this one.", """
      A confirmação NOMEIA o que foi criado. "Criado com sucesso" obrigaria a pessoa a
      procurar na lista para saber se o nome saiu como ela escreveu.
      """

      assert alerta(html, "error") == nil, "e nenhum erro aparece junto"
      assert html =~ "Squad Azul", "e a subequipe aparece na estrutura"
    end

    test "o nome é APARADO, e a confirmação mostra o nome aparado", ctx do
      html = submeter(ctx, "  Squad Verde  ")

      assert alerta(html, "info") == "Team Squad Verde declared inside this one.", """
      Espaço na ponta não é nome. E a confirmação mostra o nome COMO FICOU: se ela repetisse
      o que foi digitado, a pessoa não saberia que o ato aparou.
      """
    end

    test "acento e `&` sobrevivem, escapados", ctx do
      html = submeter(ctx, "Análise & Dados")

      assert alerta(html, "info") == "Team Análise &amp; Dados declared inside this one."

      assert html =~ "Análise", """
      O `&` sai escapado no HTML — é o Phoenix protegendo, e não a plataforma alterando o
      nome. No banco o nome é "Análise & Dados", e há teste disso no domínio.
      """
    end

    test "duas subequipes seguidas, e as duas ficam", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}?tab=structure")
      render_submit(view, "criar_subequipe", %{"name" => "Primeira"})
      html = render_submit(view, "criar_subequipe", %{"name" => "Segunda"})

      assert alerta(html, "info") == "Team Segunda declared inside this one."

      partes = EO.team_parts(ctx.tenant, ctx.mae.id) |> Enum.map(& &1.name) |> Enum.sort()
      assert partes == ["Primeira", "Segunda"], "o segundo ato não desfaz o primeiro"
    end
  end

  describe "o caminho infeliz, PELA TELA — a recusa que a pessoa lê" do
    setup ctx do
      {:ok, _} = EO.declare_subteam(ctx.tenant, ctx.mae, "Repetida", ctx.admin.id)
      ctx
    end

    for {rotulo, nome, esperado} <- [
          {"nome vazio", "", "can&#39;t be blank"},
          {"nome só de espaços", "   ", "can&#39;t be blank"},
          {"nome repetido", "Repetida", "já existe uma equipe declarada"},
          {"nome maior que a coluna", String.duplicate("x", 300), "at most 255 character(s)"}
        ] do
      test "#{rotulo}: a tela DIZ o motivo, e não cai", ctx do
        html = submeter(ctx, unquote(nome))

        erro = alerta(html, "error")

        assert erro != nil, """
        Sem alerta de erro a pessoa não sabe que o ato falhou — e o formulário some, o que
        parece sucesso. Ausência de mensagem é a forma de sucesso silencioso que dói mais.
        """

        assert erro =~ unquote(esperado), "leu #{inspect(erro)}"
        assert alerta(html, "info") == nil, "e nenhuma confirmação aparece junto"
      end
    end

    test "a recusa NÃO cria nada — a estrutura fica como estava", ctx do
      antes = EO.team_parts(ctx.tenant, ctx.mae.id) |> length()

      for nome <- ["", "   ", "Repetida", String.duplicate("x", 300)] do
        submeter(ctx, nome)
      end

      assert length(EO.team_parts(ctx.tenant, ctx.mae.id)) == antes, """
      Quatro recusas, nenhuma composição nova. É a invariante da transação vista pela tela:
      antes dela, um dos caminhos deixava equipe criada e solta na organização.
      """
    end

    test "depois de uma recusa, o caminho feliz ainda funciona na MESMA vista", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}?tab=structure")

      render_submit(view, "criar_subequipe", %{"name" => ""})
      html = render_submit(view, "criar_subequipe", %{"name" => "Depois da Recusa"})

      assert alerta(html, "info") == "Team Depois da Recusa declared inside this one.", """
      A recusa não deixa a vista num estado do qual não se sai. Exceção deixaria — mataria o
      processo —, e é o que três dos caminhos infelizes faziam antes de 2026-09-10.
      """
    end
  end

  describe "declarar uma equipe dentro desta" do
    test "a subequipe nasce e aparece em 'Contains'", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}?tab=structure")

      html = render_submit(view, "criar_subequipe", %{"name" => "Dados"})

      assert html =~ "Dados"
      assert [%{name: "Dados"}] = EO.team_parts(ctx.tenant, ctx.mae.id)
    end

    test "ela HERDA a organização da mãe", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}?tab=structure")
      render_submit(view, "criar_subequipe", %{"name" => "Dados"})

      [%{team_id: filha_id}] = EO.team_parts(ctx.tenant, ctx.mae.id)
      {:ok, filha} = EO.fetch_team(ctx.tenant, filha_id)

      assert filha.organization_id == ctx.org.id
    end

    test "a outra direção aparece na tela da filha", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}?tab=structure")
      render_submit(view, "criar_subequipe", %{"name" => "Dados"})
      [%{team_id: filha_id}] = EO.team_parts(ctx.tenant, ctx.mae.id)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{filha_id}?tab=structure")

      # A de cima diz o que contém; a de baixo diz de quem faz parte.
      assert html =~ "Part of"
      assert html =~ "Plataforma"
    end
  end

  describe "descompor não apaga a equipe" do
    test "a filha sai da estrutura e continua existindo", ctx do
      {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}?tab=structure")
      render_submit(view, "criar_subequipe", %{"name" => "Dados"})
      [%{team_id: filha_id}] = EO.team_parts(ctx.tenant, ctx.mae.id)

      antes = EO.count_teams(ctx.tenant)
      render_click(view, "descompor", %{"part_id" => filha_id})

      assert EO.team_parts(ctx.tenant, ctx.mae.id) == []
      assert EO.count_teams(ctx.tenant) == antes
    end
  end

  describe "sem escopo, não declara" do
    test "quem não alcança a organização é recusado", ctx do
      {:ok, outra} =
        TheBand.Tenants.create_user(ctx.tenant, %{
          "email" => "sem-escopo-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      {:ok, view, _} =
        build_conn() |> log_in(outra) |> live(~p"/teams/#{ctx.mae.id}?tab=structure")

      html = render_submit(view, "criar_subequipe", %{"name" => "Pela porta dos fundos"})

      # A recusa MUDOU de nome com a feature 060: o escopo de conta deixou de decidir
      # escrita (T006), e quem não tem pessoa declarada não alcança papel nenhum — logo,
      # concessão nenhuma. "no scope" era a frase do modelo anterior.
      #
      # E note o que este teste prova de mais importante: o formulário NÃO é renderizado
      # para esta conta, e o evento chegou de todo modo, por `render_submit`. Foi o veredito
      # re-perguntado no evento que recusou — esconder o botão nunca foi a proteção.
      assert html =~ "not linked to a person"
      assert EO.team_parts(ctx.tenant, ctx.mae.id) == []
    end
  end
end
