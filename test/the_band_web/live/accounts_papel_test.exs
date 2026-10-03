defmodule TheBandWeb.AccountsPapelTest do
  @moduledoc """
  A marca de administrador em `/accounts` — spec 072, T011. Cada caso é um item da régua de
  `specs/072-papel-de-administrador/prototipo/PROMPT.md` §3, pelo número.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, ana} = tenant_with_admin()
    rui = conta(tenant, "Rui Example", "admin")
    bia = conta(tenant, "Bia Example", "member")
    %{conn: log_in(conn, ana), tenant: tenant, ana: ana, rui: rui, bia: bia}
  end

  defp conta(tenant, nome, papel) do
    {:ok, u} =
      Tenants.create_user(tenant, %{
        "email" =>
          "#{String.downcase(String.replace(nome, " ", "."))}-#{System.unique_integer([:positive])}@example.test",
        "name" => nome,
        "role" => papel
      })

    u
  end

  defp celula(html, user) do
    [linha] =
      html
      |> LazyHTML.from_document()
      |> LazyHTML.query("tbody tr")
      |> Enum.filter(
        &(&1 |> LazyHTML.query(~s(td[data-label="Person"])) |> LazyHTML.text() =~ user.email)
      )

    linha
    |> LazyHTML.query(~s(td[data-label="Management"]))
    |> LazyHTML.text()
    |> String.replace(~r/\s+/, " ")
  end

  test "itens 1, 2, 6: a contagem, o bloco de quem administra, e nenhum travessão", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/accounts")

    assert html =~ "2 active administrators"
    assert html =~ "Who administers this organisation"
    assert html =~ "The organisation always keeps at least one active administrator:"

    for u <- [ctx.ana, ctx.rui, ctx.bia], do: refute(celula(html, u) =~ "—")
  end

  test "itens 4 e 5: a célula por caso, e a ausência dita (Q6)", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/accounts")

    assert celula(html, ctx.ana) =~ "administrator"
    assert celula(html, ctx.ana) =~ "no role change recorded"
    assert celula(html, ctx.ana) =~ "Step down…"
    assert celula(html, ctx.rui) =~ "Remove admin role…"
    assert celula(html, ctx.bia) =~ "member"
    assert celula(html, ctx.bia) =~ "Make administrator…"
    refute celula(html, ctx.bia) =~ "never an administrator"
  end

  test "itens 10 a 17: promover pelo painel, sem digitar, e a tela reflete", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")

    html = render_click(view, "abrir_papel", %{"id" => ctx.bia.id, "acao" => "promover"})
    assert html =~ "Make Bia Example administrator"
    assert html =~ "what it does not do"
    assert html =~ "kept on the record, not written to the log"
    refute html =~ "Type your e-mail to confirm"

    html =
      view |> form("#painel-do-papel", %{"note" => "Takes over the syncs."}) |> render_submit()

    assert html =~ "Bia Example is now an administrator."
    assert html =~ "3 active administrators"
    assert celula(html, ctx.bia) =~ "since"
    assert html =~ "Takes over the syncs."
    assert html =~ "member → administrator"
  end

  test "itens 18 a 21: rebaixar outra pessoa diz que não tira o acesso", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")

    html = render_click(view, "abrir_papel", %{"id" => ctx.rui.id, "acao" => "rebaixar"})
    assert html =~ "Remove the administrator role from Rui Example"
    assert html =~ "It does not remove access."

    html = view |> form("#painel-do-papel", %{"note" => ""}) |> render_submit()
    assert html =~ "1 active administrator"
    assert celula(html, ctx.rui) =~ "removed by"
    assert html =~ "no note"
  end

  test "itens 22 a 25 e 31: deixar o próprio papel pede o e-mail, e a recusa guarda a nota",
       ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")

    html = render_click(view, "abrir_papel", %{"id" => ctx.ana.id, "acao" => "deixar"})
    assert html =~ "Type your e-mail to confirm"
    assert html =~ "You cannot give the role back yourself."

    html =
      view
      |> form("#painel-do-papel", %{"note" => "On leave.", "email" => "errado@example.test"})
      |> render_submit()

    assert html =~ "That is not the e-mail of your account. You are still an administrator."
    assert html =~ "On leave."
    assert TheBand.Repo.get!(TheBand.Tenants.User, ctx.ana.id).role == "admin"

    view
    |> form("#painel-do-papel", %{"note" => "On leave.", "email" => ctx.ana.email})
    |> render_submit()

    flash = assert_redirect(view, "/people")
    assert flash["info"] =~ "You stepped down as administrator of"
    assert flash["info"] =~ "Rui Example can give the role back."
  end

  test "item 26: o último administrador tem o ato inerte, com a razão", ctx do
    {:ok, _} = Tenants.demote_user(ctx.tenant, ctx.rui.id, ctx.ana)
    {:ok, _view, html} = live(ctx.conn, ~p"/accounts")

    assert html =~ "1 active administrator"
    assert celula(html, ctx.ana) =~ "the only active administrator"

    assert celula(html, ctx.ana) =~
             "The organisation would have no active administrator. Make someone else administrator first."

    refute html =~ ~s(phx-value-acao="deixar")
  end

  test "item 29: quem chegou atrasado lê a mudança que chegou antes, e o painel fecha", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")
    render_click(view, "abrir_papel", %{"id" => ctx.bia.id, "acao" => "promover"})

    {:ok, _} = Tenants.promote_user(ctx.tenant, ctx.bia.id, ctx.rui)
    html = view |> form("#painel-do-papel", %{"note" => ""}) |> render_submit()

    assert html =~ "Not changed: Bia Example is already an administrator."
    assert html =~ "Rui Example made the change at"
    refute html =~ ~s(id="painel-do-papel")
  end

  test "itens 8 e 9: o registro, do mais novo ao mais antigo, e a nota da primeira conta", ctx do
    {:ok, _} = Tenants.promote_user(ctx.tenant, ctx.bia.id, ctx.ana, note: "primeira")
    {:ok, _} = Tenants.demote_user(ctx.tenant, ctx.bia.id, ctx.ana, note: "segunda")
    {:ok, _view, html} = live(ctx.conn, ~p"/accounts")

    assert html =~ "Administrator changes"
    assert html =~ "nothing here is deleted"
    {segunda, _} = :binary.match(html, "segunda")
    {primeira, _} = :binary.match(html, "primeira")
    assert segunda < primeira
    assert html =~ "the first account of an organisation is created"
  end

  test "item 34: a tabela empilha, com o nome da coluna em cada célula", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/accounts")
    assert html =~ ~s(class="table stacked")
    assert html =~ ~s(data-label="Management")
    assert html =~ ~s(data-label="Sign-in credential")
  end
end
