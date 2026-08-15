defmodule TheBandWeb.ProjetosTest do
  @moduledoc """
  A tela dos projetos — feature 025, US1 a US4.

  ## As três asserções que carregam este arquivo

  1. **o formulário não pergunta o tipo** — a fase é consequência de ter partes, e
     oferecer a escolha convidaria a gravar algo que a estrutura contradiz;
  2. **a recusa nomeia o motivo** — de quem o projeto já é parte, ou onde o ciclo se
     fecha. Dizer só "não deu" deixa quem cadastrou procurando;
  3. **as duas contagens não somam** — direto e de subprojeto são fatos diferentes.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, user: user, cenario: cenario}
  end

  defp projeto(ctx, nome) do
    {:ok, p} = SPO.create_project(ctx.tenant, %{name: nome}, ctx.user.id)
    p
  end

  describe "cadastrar" do
    test "a tela vazia diz que projeto é declarado, e não observado", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/projects")

      assert html =~ "No project registered yet"

      assert html =~ "declared, never observed", """
      A tela vazia não disse de onde vem um projeto.

      Sem isso, quem abre espera que a coleta preencha — e ela nunca vai: inferir projeto
      de nome de repositório produziria agrupamento que ninguém decidiu.
      """
    end

    test "o formulário não pergunta se é simples ou complexo", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/projects")
      html = live |> element("button", "New project") |> render_click()

      refute html =~ "simple or complex", ""

      refute html =~ ~r/name="(phase|type|kind)"/, """
      O formulário oferece escolha de tipo.

      A fase é **consequência de ter partes**: antes das partes a pergunta não tem
      resposta, e um campo gravado divergiria da estrutura no primeiro dia.
      """
    end

    test "cadastrar cria o projeto, e ele nasce simples", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/projects")
      live |> element("button", "New project") |> render_click()

      html =
        live
        |> form("form[phx-submit='criar']", %{"name" => "Conecta Fapes"})
        |> render_submit()

      assert html =~ "Conecta Fapes"
      assert html =~ "simple"
    end

    test "nome repetido é recusado com a mensagem no nome", ctx do
      projeto(ctx, "Conecta Fapes")
      {:ok, live, _html} = live(ctx.conn, ~p"/projects")
      live |> element("button", "New project") |> render_click()

      html =
        live
        |> form("form[phx-submit='criar']", %{"name" => "Conecta Fapes"})
        |> render_submit()

      assert html =~ "name:"
    end
  end

  describe "a hierarquia" do
    test "o segundo pai é recusado, e a mensagem nomeia o atual", ctx do
      um = projeto(ctx, "Conecta Fapes")
      _outro = projeto(ctx, "Diretoria")
      filho = projeto(ctx, "Backend")
      {:ok, _} = SPO.set_parent(ctx.tenant, filho.id, um.id)

      {:ok, live, _html} = live(ctx.conn, ~p"/projects")

      html =
        live
        |> form("#pai-#{filho.id}", %{"parent_id" => _outro.id})
        |> render_change()

      assert html =~ "already part of Conecta Fapes", """
      A recusa não disse de quem o projeto já é parte.

      "Não foi possível" deixa quem cadastrou procurando numa árvore que pode ter dezenas
      de projetos. Nomear o pai atual diz o que desfazer.
      """
    end

    test "o ciclo é recusado, e a mensagem nomeia o caminho", ctx do
      a = projeto(ctx, "A")
      b = projeto(ctx, "B")
      c = projeto(ctx, "C")
      {:ok, _} = SPO.set_parent(ctx.tenant, b.id, a.id)
      {:ok, _} = SPO.set_parent(ctx.tenant, c.id, b.id)

      {:ok, live, _html} = live(ctx.conn, ~p"/projects")

      html =
        live
        |> form("#pai-#{a.id}", %{"parent_id" => c.id})
        |> render_change()

      assert html =~ "would create a cycle", """
      Um ciclo indireto foi aceito pela tela.

      Um pai só não impede ciclo: em `A → B → C → A` cada projeto tem exatamente um pai.
      """

      assert html =~ "→", "o caminho do ciclo precisa aparecer, e não só a palavra ciclo"
    end

    test "o pai definido aparece no cartão", ctx do
      pai = projeto(ctx, "Conecta Fapes")
      filho = projeto(ctx, "Backend")
      {:ok, _} = SPO.set_parent(ctx.tenant, filho.id, pai.id)

      {:ok, _live, html} = live(ctx.conn, ~p"/projects")

      assert html =~ "part of Conecta Fapes"
      assert html =~ "complex", "o pai passou a complexo por ter parte, e o cartão diz isso"
    end
  end

  describe "os repositórios e as issues" do
    test "associar vários de uma vez traz as issues", ctx do
      p = projeto(ctx, "Conecta Fapes")
      {:ok, live, _html} = live(ctx.conn, ~p"/projects")

      live |> element("button", "Associate repositories") |> render_click()

      live
      |> element("input[phx-value-repository_id='#{ctx.cenario.observed_repository_id}']")
      |> render_click()

      html = live |> element("button", "Associate 1") |> render_click()

      assert html =~ "issues from its own repositories"
      refute html =~ "No repository associated"
    end

    test "a busca filtra os repositórios", ctx do
      p = projeto(ctx, "Conecta Fapes")
      {:ok, live, _html} = live(ctx.conn, ~p"/projects")
      live |> element("button", "Associate repositories") |> render_click()

      com_termo =
        live |> form("#buscar-#{p.id}", %{"busca" => "nao-existe-isso"}) |> render_change()

      assert com_termo =~ "No repository matches this search", """
      A busca sem resultado não disse que foi a busca.

      "Nada encontrado" e "tudo já associado" produzem a mesma lista vazia e pedem ações
      diferentes: apagar o termo, ou nada.
      """

      refute com_termo =~ "theband"

      sem_termo = live |> form("#buscar-#{p.id}", %{"busca" => "theband"}) |> render_change()
      assert sem_termo =~ "theband"
    end

    test "o já associado sai da lista de disponíveis", ctx do
      p = projeto(ctx, "Conecta Fapes")

      {:ok, _} =
        SPO.link_repository(ctx.tenant, p.id, ctx.cenario.observed_repository_id, ctx.user.id)

      {:ok, live, _html} = live(ctx.conn, ~p"/projects")
      html = live |> element("button", "Associate repositories") |> render_click()

      assert html =~ "already associated with this project", """
      A lista ofereceu um repositório que o projeto já tem.

      Oferecer o que não faz nada é ruído, e com 160 repositórios o ruído é o que impede
      achar o que falta.
      """
    end

    test "projeto sem repositório diz que não alcança issue alguma", ctx do
      projeto(ctx, "Vazio")
      {:ok, _live, html} = live(ctx.conn, ~p"/projects")

      assert html =~ "No repository associated", """
      O projeto sem repositório mostrou zero em vez de dizer o que falta.

      Zero sugere "olhei e não achei"; o que existe é "não há de onde olhar".
      """
    end

    test "as issues de subprojeto aparecem separadas das diretas", ctx do
      pai = projeto(ctx, "Conecta Fapes")
      filho = projeto(ctx, "Backend")
      {:ok, _} = SPO.set_parent(ctx.tenant, filho.id, pai.id)

      {:ok, _} =
        SPO.link_repository(ctx.tenant, filho.id, ctx.cenario.observed_repository_id, ctx.user.id)

      {:ok, _live, html} = live(ctx.conn, ~p"/projects")

      assert html =~ "from subprojects", """
      As issues herdadas de subprojeto foram somadas às diretas sem distinguir.

      "Veio de repositório meu" e "veio de subprojeto" são fatos diferentes, e um total
      esconderia de onde o número veio — FR-014.
      """
    end

    test "a travessia é explicada na tela", ctx do
      projeto(ctx, "Conecta Fapes")
      {:ok, _live, html} = live(ctx.conn, ~p"/projects")

      assert html =~ "traversal", """
      A tela não diz que as issues vêm de uma travessia.

      Sem isso, quem lê supõe que existe um campo de projeto na issue — e é justamente o
      que a plataforma recusa ter, porque duas fontes discordariam.
      """
    end
  end

  describe "o isolamento entre tenants" do
    test "o projeto de um tenant não aparece no outro", ctx do
      projeto(ctx, "Conecta Fapes")
      {_outro, outro_user} = tenant_with_admin()
      conn = log_in(Phoenix.ConnTest.build_conn(), outro_user)

      {:ok, _live, html} = live(conn, ~p"/projects")

      refute html =~ "Conecta Fapes"
      assert html =~ "No project registered yet"
    end
  end
end
