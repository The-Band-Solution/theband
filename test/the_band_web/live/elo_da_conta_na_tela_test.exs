defmodule TheBandWeb.EloDaContaNaTelaTest do
  @moduledoc """
  Quem pode dizer qual conta é qual pessoa — issue #369, FR-012c.

  ## A asserção que carrega este arquivo é de autorização

  **O elo concede visibilidade.** Apontar uma conta para uma pessoa observada é dar a essa
  conta o painel dela — não é campo de cadastro, é ato de acesso. Por isso a declaração é de
  admin, e por isso o teste que mais importa aqui prova que quem não é admin **não
  consegue**, e não apenas que não vê o formulário.

  Esconder o formulário sem recusar o evento é o defeito clássico desta classe: o cliente
  LiveView está do outro lado da rede, e um evento chega sem que a tela o tenha oferecido.

  ## A escolha é numa lista, e não digitada

  As 88 pessoas observadas têm `external_id` — `U_kgDOABFnGA` — e login. Nenhuma tem
  e-mail. O id é a identidade e não é para ser transcrito: a tela oferece as contas, e a
  plataforma guarda a ligação.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()

    {:ok, comum} =
      Tenants.create_user(tenant, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    pessoa = pessoa(tenant, "ana", "Ana")

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, comum: comum, pessoa: pessoa}
  end

  defp pessoa(tenant, login, nome) do
    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        Map.merge(source_attrs("U_#{login}"), %{name: nome, login: login, account_type: "person"})
      )

    p
  end

  describe "a autorização" do
    test "admin escolhe a conta numa lista, e o elo fica", ctx do
      {:ok, live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Which account is this person"
      assert html =~ "No account linked"
      assert html =~ ctx.admin.email, "as contas do tenant não foram oferecidas para escolha"

      html =
        live
        |> form("#elo-da-conta", %{"user_id" => ctx.admin.id})
        |> render_submit()

      assert html =~ "Linked to"
      assert {:ok, achada} = Tenants.user_for_person(ctx.tenant, ctx.pessoa.id)
      assert achada.id == ctx.admin.id
    end

    # A asserção que importa: o evento é RECUSADO, e não apenas escondido. O cliente
    # LiveView está do outro lado da rede — esconder o formulário não impede o evento
    # chegar, e do outro lado dele está o painel de outra pessoa.
    test "quem não é admin tem o evento recusado, e não só o formulário escondido", ctx do
      conn = log_in(Phoenix.ConnTest.build_conn(), ctx.comum)
      {:ok, live, html} = live(conn, ~p"/people/#{ctx.pessoa.id}")

      refute html =~ "id=\"elo-da-conta\""
      assert html =~ "Only an administrator can change this link"

      render_hook(live, "declarar_conta", %{"user_id" => ctx.comum.id})

      assert Tenants.user_for_person(ctx.tenant, ctx.pessoa.id) == :not_declared, """
      Uma pessoa sem papel de admin declarou o elo enviando o evento direto.

      Apontar a própria conta para outra pessoa observada é passar a ver o painel dela.
      Esconder o formulário não é autorizar.
      """
    end

    test "quem não é admin tem a revogação recusada", ctx do
      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, ctx.pessoa.id, ctx.admin.id)

      conn = log_in(Phoenix.ConnTest.build_conn(), ctx.comum)
      {:ok, live, _html} = live(conn, ~p"/people/#{ctx.pessoa.id}")

      render_hook(live, "revogar_conta", %{"user_id" => ctx.admin.id})

      assert {:ok, _} = Tenants.user_for_person(ctx.tenant, ctx.pessoa.id), """
      Uma pessoa sem papel de admin revogou o elo.

      Retirar o elo é retirar acesso, e é ato de admin tanto quanto concedê-lo.
      """
    end

    test "admin revoga, e o elo sai de circulação", ctx do
      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, ctx.pessoa.id, ctx.admin.id)

      {:ok, live, _html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")
      html = live |> element("button[phx-click=revogar_conta]") |> render_click()

      assert html =~ "No account linked"
      assert Tenants.user_for_person(ctx.tenant, ctx.pessoa.id) == :not_declared
    end
  end

  describe "o que a tela diz" do
    test "sem elo, diz que ninguém alcança o painel — nem a própria pessoa", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "No account linked", "a ausência do elo não foi nomeada"

      assert html =~ "not even they", """
      A tela disse "nenhuma conta" sem dizer o efeito.

      Sem elo, nem a própria pessoa alcança o próprio painel. Omitir isso faz o campo
      parecer detalhe de cadastro, quando é o que decide acesso.
      """
    end

    test "mostra o login da origem, que é de onde a identidade vem", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "ana", "o login da origem não apareceu"
      assert html =~ "on GitHub"
    end

    test "a cobertura mostra quantas contas de quantas", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "of 2", """
      A tela não mostrou a lacuna.

      `0 de 2` e `0` afirmam coisas diferentes: o primeiro diz quantas contas ainda não
      alcançam painel nenhum.
      """
    end
  end
end
