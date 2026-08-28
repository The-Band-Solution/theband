defmodule TheBandWeb.MenusDoRastroTest do
  @moduledoc """
  Os três menus que alcançam o rastro — feature 038, issue #436; morada movida
  pela feature 046 (menu por entidades).

  A lacuna original não muda: telas funcionando que ninguém achava. O que mudou é
  ONDE o rastro se acha — a barra virou entidades, e o rastro vive nas sub-abas de
  Work (`Layouts.work_tabs/1`), um clique a partir de qualquer visão de trabalho.

  ## As asserções que carregam este arquivo

  1. **os três destinos estão nas sub-abas de Work**, e não só as rotas no
     roteador;
  2. **o rótulo é `Checks`, nunca `CI`** — 399 das 1.051 execuções não são
     integração contínua, e o menu não pode prometer o que a tela não entrega;
  3. **a ordem é a da cadeia observada**, e não alfabética nem de chegada;
  4. quem **não** é admin também alcança os três: o rastro é conhecimento, não
     operação;
  5. **os painéis dizem o tamanho do que existe antes de alguém procurar** — sem
     eles, busca sem resultado é indistinguível de coleta que não rodou.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @destinos ["/work/changes", "/work/files", "/work/verifications"]

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin), tenant: tenant}
  end

  test "os três destinos aparecem nas sub-abas de Work, alcançáveis por clique", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/work")

    for destino <- @destinos do
      assert html =~ ~s|href="#{destino}"|,
             "#{destino} não está nas sub-abas — a tela existe e ninguém a acha"
    end
  end

  test "o rótulo da verificação é Checks, e nunca CI", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/work")

    assert html =~ "Checks"

    # A asserção é sobre o ITEM do menu, não sobre a página inteira: "CI" pode aparecer
    # em texto corrido sem prometer nada. O que não pode é rotular a aba.
    refute html =~ ~r/>\s*CI\s*<\/a>/
  end

  test "a ordem conta a cadeia: Issues, Changes, Files, Checks", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/work")

    indices =
      Enum.map(["/work/changes", "/work/files", "/work/verifications"], fn rota ->
        {i, _} = :binary.match(html, ~s|href="#{rota}"|)
        i
      end)

    assert indices == Enum.sort(indices), "a ordem das sub-abas não segue a cadeia observada"

    # E os três ficam ANTES de Boards e Process — depois deles o rastro se
    # separaria do trabalho que descreve, e a ordem deixaria de contar nada.
    {boards, _} = :binary.match(html, ~s|href="/boards"|)
    assert List.last(indices) < boards
  end

  test "quem não é admin também alcança os três", %{tenant: tenant} do
    {:ok, membro} =
      TheBand.Tenants.create_user(tenant, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    conn = log_in(build_conn(), membro)

    {:ok, _live, html} = live(conn, ~p"/work")

    for destino <- @destinos do
      assert html =~ ~s|href="#{destino}"|, "#{destino} sumiu para quem não é admin"
    end

    # E o que É de operação continua restrito.
    refute html =~ ~s|href="/tools"|
  end

  describe "os painéis" do
    test "a lista de mudanças separa integrada, descartada e aberta", ctx do
      # Fechada sem integrar é linha própria: é trabalho pedido, revisado e descartado, e
      # somá-lo às integradas apagaria o único número que mede desperdício de revisão.
      {:ok, _live, html} = live(ctx.conn, ~p"/work/changes")

      assert html =~ "merged"
      assert html =~ "closed without merging"
      assert html =~ "still open"
    end

    test "o escopo aparece com as quatro frases separadas, e nenhuma diz pela outra", ctx do
      # Somá-las foi o defeito #438. "Attends none" é fato sobre o processo; "issue not
      # collected yet" é lacuna nossa; "not measured" é desconhecido. Um rótulo só faria
      # a plataforma acusar a organização pelo que ela mesma não coletou.
      {:ok, _live, html} = live(ctx.conn, ~p"/work/changes")

      assert html =~ "attends an issue"
      assert html =~ "attends none"
      assert html =~ "issue not collected yet"
      assert html =~ "not measured"

      # E nunca o rótulo que somava as três.
      refute html =~ "no issue recognised"
    end

    test "a tela de arquivos diz quantos commits foram percorridos", ctx do
      # O denominador honesto: sem ele, "nenhum arquivo" parece ausência de mudança
      # quando é ausência de coleta.
      {:ok, _live, html} = live(ctx.conn, ~p"/work/files")

      assert html =~ "file paths known"
      assert html =~ "versions recorded"
      assert html =~ "commits swept for files"
    end
  end
end
