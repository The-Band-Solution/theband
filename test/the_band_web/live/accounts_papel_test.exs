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
  end

  # B, decidida pela pessoa mantenedora em 2026-10-03: volta ao protótipo.
  test "itens 4 e 5: sem episódio, o administrador diz desde a criação e o membro diz nunca",
       ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/accounts")

    assert celula(html, ctx.ana) =~ "since the organisation was created · no role change recorded"
    assert celula(html, ctx.rui) =~ "since the organisation was created · no role change recorded"
    assert celula(html, ctx.bia) =~ "never an administrator"
    refute celula(html, ctx.bia) =~ "no role change recorded"
  end

  # C: `periodo/2` comparava `DateTime` com `<`, que compara o mapa campo a campo, e 28 Sep
  # ficava "depois" de 02 Oct. O registro é somente-acréscimo, então as datas entram no INSERT.
  test "item 4: o período de quem foi administrador atravessa a virada do mês", ctx do
    episodio(ctx, ctx.bia, "member", "admin", ~U[2026-09-28 10:00:00.000000Z])
    episodio(ctx, ctx.bia, "admin", "member", ~U[2026-10-02 14:00:00.000000Z])
    {:ok, _view, html} = live(ctx.conn, ~p"/accounts")

    assert celula(html, ctx.bia) =~ "administrator 28 Sep – 02 Oct"
    refute celula(html, ctx.bia) =~ "until"
  end

  # A, Q1 (b): o administrador desativado pode ser rebaixado; o membro desativado espera.
  test "item 4: o administrador desativado tem o ato de rebaixar, e o membro desativado não",
       ctx do
    for u <- [ctx.rui, ctx.bia] do
      {:ok, _} =
        Tenants.disable_user(ctx.tenant, u.id, ctx.ana.id, %{"reason" => "left_the_organisation"})
    end

    {:ok, _view, html} = live(ctx.conn, ~p"/accounts")

    assert celula(html, ctx.rui) =~ "not counted while the account is disabled"
    assert celula(html, ctx.rui) =~ "Remove admin role…"
    refute celula(html, ctx.rui) =~ "Role changes wait for reactivation."
    assert html =~ ~s(phx-value-id="#{ctx.rui.id}" phx-value-acao="rebaixar")

    assert celula(html, ctx.bia) =~ "Role changes wait for reactivation."
    refute celula(html, ctx.bia) =~ "Make administrator…"
  end

  # D: o painel do papel, desativar e reativar abrem no mesmo lugar, logo abaixo da tabela, e
  # "Administrator changes" vem depois deles.
  test "item 10: os três painéis abrem antes de Administrator changes", ctx do
    {:ok, _} =
      Tenants.disable_user(ctx.tenant, ctx.bia.id, ctx.ana.id, %{
        "reason" => "left_the_organisation"
      })

    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")

    for {evento, params, id} <- [
          {"abrir_papel", %{"id" => ctx.rui.id, "acao" => "rebaixar"}, "painel-do-papel"},
          {"abrir_desativacao", %{"id" => ctx.rui.id}, "desativar-conta"},
          {"abrir_reativacao", %{"id" => ctx.bia.id}, "reativar-conta"}
        ] do
      html = render_click(view, evento, params)
      {tabela, _} = :binary.match(html, "</table>")
      {painel, _} = :binary.match(html, ~s(id="#{id}"))
      {registro, _} = :binary.match(html, ~s(id="mudancas-de-papel"))
      assert tabela < painel, "#{id} abre antes da tabela"
      assert painel < registro, "#{id} abre depois de Administrator changes"
    end
  end

  # E: a terceira frase do protótipo, sem pronome, com a contagem nova.
  test "item 17: o sucesso diz onde a mudança aparece e a contagem nova", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")

    render_click(view, "abrir_papel", %{"id" => ctx.bia.id, "acao" => "promover"})
    html = view |> form("#painel-do-papel", %{"note" => ""}) |> render_submit()

    assert html =~
             "The row and “Administrator changes” show it; the header now reads 3 active administrators."

    render_click(view, "abrir_papel", %{"id" => ctx.rui.id, "acao" => "rebaixar"})
    html = view |> form("#painel-do-papel", %{"note" => ""}) |> render_submit()

    assert html =~
             "The row and “Administrator changes” show it; the header now reads 2 active administrators."
  end

  # F: quem fica é quem está olhando, e a tela diz "you".
  test "item 19: a organização fica com quem age, e a tela diz you", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")

    html = render_click(view, "abrir_papel", %{"id" => ctx.rui.id, "acao" => "rebaixar"})
    assert html =~ "The organisation keeps 1 active administrator: you."

    {:ok, _} = Tenants.promote_user(ctx.tenant, ctx.bia.id, ctx.ana)
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")
    html = render_click(view, "abrir_papel", %{"id" => ctx.rui.id, "acao" => "rebaixar"})
    assert html =~ "The organisation keeps 2 active administrators: "
    assert html =~ ~r/active administrators: (Bia Example, you|you, Bia Example)\./
  end

  # G: a corrida. Ana abre o painel, Rui deixa o papel por fora, Ana confirma.
  test "item 27: a recusa do último nomeia quem deixou o papel depois de o painel abrir", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")
    render_click(view, "abrir_papel", %{"id" => ctx.ana.id, "acao" => "deixar"})

    {:ok, ep} = Tenants.demote_user(ctx.tenant, ctx.rui.id, ctx.rui)

    html =
      view
      |> form("#painel-do-papel", %{"note" => "", "email" => ctx.ana.email})
      |> render_submit()

    quando = Calendar.strftime(ep.inserted_at, "%d %b %H:%M")

    assert html =~
             "Not changed: the organisation would have no active administrator. " <>
               "Rui Example stepped down at #{quando}, so you are now the only one. " <>
               "Your role is unchanged."

    refute html =~ "removed the administrator role from Rui Example at"
    refute html =~ "a moment before this request"
  end

  test "item 27: a mudança anterior à abertura do painel não é citada", ctx do
    {:ok, _} = Tenants.demote_user(ctx.tenant, ctx.rui.id, ctx.rui)
    {:ok, view, _html} = live(ctx.conn, ~p"/accounts")
    render_click(view, "abrir_papel", %{"id" => ctx.ana.id, "acao" => "deixar"})

    html =
      view
      |> form("#painel-do-papel", %{"note" => "", "email" => ctx.ana.email})
      |> render_submit()

    assert html =~
             "Not changed: the organisation would have no active administrator. Your role is unchanged."

    refute html =~ "stepped down at"
  end

  defp episodio(ctx, user, de, para, quando) do
    TheBand.Repo.insert_all(TheBand.Tenants.Schemas.AccountRoleChange, [
      %{
        tenant_id: ctx.tenant.id,
        user_id: user.id,
        changed_by_user_id: ctx.ana.id,
        from_role: de,
        to_role: para,
        inserted_at: quando
      }
    ])
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

  # I: a célula dos atos também leva o nome da coluna, e o cabeçalho o diz ao leitor de tela.
  test "item 34: a célula dos atos tem o nome da coluna", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/accounts")
    doc = LazyHTML.from_document(html)

    assert doc |> LazyHTML.query("table.stacked thead th span.sr-only") |> LazyHTML.text() ==
             "Actions"

    for linha <- LazyHTML.query(doc, "tbody tr"),
        LazyHTML.query(linha, ~s(td[data-label="Person"])) |> Enum.count() == 1 do
      assert linha |> LazyHTML.query(~s(td[data-label="Actions"])) |> Enum.count() == 1
    end
  end
end
