defmodule TheBandWeb.MenusDoRastroTest do
  @moduledoc """
  Os três menus que alcançam o rastro — feature 038, issue #436.

  ## As asserções que carregam este arquivo

  1. **os três destinos estão na barra**, e não só as rotas no roteador — foi exatamente
     essa a lacuna: telas funcionando que ninguém achava;
  2. **o rótulo é `Checks`, nunca `CI`** — 399 das 1.051 execuções não são integração
     contínua, e o menu não pode prometer o que a tela não entrega;
  3. **a ordem é a da cadeia observada**, e não alfabética nem de chegada;
  4. quem **não** é admin também alcança os três: o rastro é conhecimento, não operação;
  5. **os painéis dizem o tamanho do que existe antes de alguém procurar** — sem eles,
     busca sem resultado é indistinguível de coleta que não rodou.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @destinos ["/work/changes", "/work/files", "/work/verifications"]

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin), tenant: tenant}
  end

  test "os três destinos aparecem na barra, alcançáveis por clique", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/people")

    for destino <- @destinos do
      assert html =~ ~s|href="#{destino}"|,
             "#{destino} não está na barra — a tela existe e ninguém a acha"
    end
  end

  test "o rótulo da verificação é Checks, e nunca CI", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/people")

    assert html =~ ">Checks</a>"

    # A asserção é sobre o ITEM da barra, não sobre a página inteira: "CI" pode aparecer
    # em texto corrido sem prometer nada. O que não pode é rotular o menu.
    refute html =~ ">CI</a>"
  end

  test "a ordem conta a cadeia: Work, Changes, Files, Checks", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/people")

    posicoes =
      Enum.map(["/work\"", "/work/changes", "/work/files", "/work/verifications"], fn rota ->
        {rota, :binary.match(html, ~s|href="#{String.trim_trailing(rota, "\"")}"|)}
      end)

    indices = Enum.map(posicoes, fn {_, {i, _}} -> i end)

    assert indices == Enum.sort(indices),
           "a ordem da barra não segue a cadeia observada: #{inspect(posicoes)}"

    # E os três ficam ANTES de Projects — depois de `Process` eles se separariam do
    # trabalho que descrevem.
    {projects, _} = :binary.match(html, ~s|href="/projects"|)
    assert List.last(indices) < projects
  end

  test "quem não é admin também alcança os três", %{tenant: tenant} do
    {:ok, membro} =
      TheBand.Tenants.create_user(tenant, %{
        "email" => "membro-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    conn = log_in(build_conn(), membro)

    {:ok, _live, html} = live(conn, ~p"/people")

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
      # E o que não é estado: quanto do trabalho não tem rastro até o que foi pedido.
      assert html =~ "no issue recognised"
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
