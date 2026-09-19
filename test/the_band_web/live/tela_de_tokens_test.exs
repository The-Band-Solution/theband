defmodule TheBandWeb.TelaDeTokensTest do
  @moduledoc """
  `/api-tokens` — a régua da seção 3 de `specs/061-api-publica/prototipo/PROMPT.md`.

  **A tela implementada é exatamente a aprovada**, e o que se confere aqui é o que a pessoa
  lê, item a item. Divergência é defeito, e não melhoria de implementação.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Tenants

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin), tenant: tenant, admin: admin}
  end

  defp texto(html) do
    html
    |> String.replace(~r/<script.*?<\/script>/s, " ")
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace("&#39;", "'")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
    |> String.replace(~r/\s+/, " ")
  end

  defp abrir(ctx) do
    {:ok, view, html} = live(ctx.conn, ~p"/api-tokens")
    {view, html}
  end

  describe "R0 — onde a tela vive" do
    test "conta administradora abre", ctx do
      {_view, html} = abrir(ctx)
      assert texto(html) =~ "API tokens"
    end

    test "conta comum é recusada com motivo nomeado", %{conn: conn, tenant: tenant} do
      {:ok, comum} =
        Tenants.create_user(tenant, %{
          "email" => "comum-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      assert {:error, {:redirect, %{flash: flash}}} =
               live(log_in(conn, comum), ~p"/api-tokens")

      assert flash["error"], """
      A recusa veio sem motivo. Página em branco, 404 mudo ou redirecionamento silencioso
      mandam quem não administra procurar no lugar errado — R5.5.
      """
    end

    test "R0.3 — o texto diz que o token não carrega permissão própria", ctx do
      {_view, html} = abrir(ctx)
      t = texto(html)

      assert t =~ "carries no permission of its own"
      assert t =~ "on every call"
    end
  end

  describe "R1 — o formulário" do
    test "o teto vem da base, e sem expiração NÃO é oferecido", ctx do
      {_view, html} = abrir(ctx)
      t = texto(html)
      {maximo, true} = Tenants.api_token_threshold("token_lifetime")

      assert t =~ "#{maximo} days — the declared maximum"
      assert t =~ "No expiration is not offered here"

      refute html =~ ~s|<option value="">|, """
      O select de expiração ganhou uma opção vazia — que é "sem expiração" pela porta dos
      fundos. Máximo do qual se abre mão não é máximo.
      """
    end

    test "R1.4 e R1.5 — o alcance aparece ANTES de criar, e diz que muda sozinho", ctx do
      {_view, html} = abrir(ctx)
      t = texto(html)

      assert t =~ "what this token will see today"
      assert t =~ "leaves a team"
      assert t =~ "every call is refused"
    end

    test "R2.5 — conta sem elo de pessoa escreve o que a API faz", ctx do
      {_view, html} = abrir(ctx)
      t = texto(html)

      assert t =~ "no person declared for this account"

      assert t =~ "empty collection", """
      A tela diz que a conta não vê nada e não diz o que a API faz. Uma chamada com esse
      token é **aceita** e devolve coleção **vazia** — e quem integra precisa saber que o
      vazio não é erro.
      """
    end
  end

  describe "R3 — o valor, mostrado uma vez" do
    test "aparece ao criar, com o rótulo, e SOME ao navegar", ctx do
      {view, _} = abrir(ctx)

      html = render_submit(form(view, "#novo-token", %{"label" => "painel do diretor"}))
      t = texto(html)

      assert t =~ "Token created · painel do diretor"
      assert t =~ "shown only now"
      assert t =~ "it will not come back"
      assert t =~ Tenants.api_token_prefix()

      valor =
        Regex.run(~r/#{Tenants.api_token_prefix()}[A-Za-z0-9_\-]+/, t)
        |> List.first()

      assert valor

      depois = texto(render_patch(view, ~p"/api-tokens"))

      refute depois =~ valor, """
      O valor sobreviveu a uma navegação.

      Ele vive no assign daquele render e some ao navegar — R3.8. Se sobrevive a
      `handle_params`, sobrevive ao botão de voltar do navegador.
      """

      assert depois =~ "cannot be shown again", """
      A tela voltou em branco. R3.9 pede a linha quieta: o token foi criado, o valor foi
      mostrado uma vez, e o caminho de volta é revogar e criar outro.
      """
    end

    test "R3.11 — a linha nova mostra máscara, never used e a expiração", ctx do
      {view, _} = abrir(ctx)
      html = render_submit(form(view, "#novo-token", %{"label" => "planilha"}))
      t = texto(html)

      assert t =~ "never used"
      assert t =~ String.duplicate("•", 16), "a máscara não tem dezesseis bullets — R2.2"
    end
  end

  describe "R4 — a revogação" do
    setup ctx do
      {view, _} = abrir(ctx)
      render_submit(form(view, "#novo-token", %{"label" => "integração do RH"}))
      %{view: view}
    end

    test "a confirmação nomeia o rótulo no título E no botão", %{view: view} do
      html = view |> element("button", "Revoke") |> render_click() |> texto()

      assert html =~ "Revoke “integração do RH”?"
      assert html =~ "what it does not do"
      assert html =~ "cannot be undone"
      assert html =~ "the same"
    end

    test "R4.9 — depois de revogar a linha FICA, e a contagem total não cai", %{view: view} do
      antes = view |> render() |> texto()
      assert antes =~ "all 1"

      view |> element("button", "Revoke") |> render_click()
      depois = view |> element("button", "Revoke “integração do RH”") |> render_click() |> texto()

      assert depois =~ "all 1", """
      A linha sumiu da lista ao ser revogada. SC-012: zero linhas removidas fisicamente, e a
      lista mostra revogado por padrão.
      """

      assert depois =~ "revoked 1"
      assert depois =~ "no way back"
    end

    test "R2.15 — não existe CONTROLE de reativar", %{view: view} do
      view |> element("button", "Revoke") |> render_click()
      html = view |> element("button", "Revoke “integração do RH”") |> render_click()

      # **O controle, e não a palavra.** A tela diz "there is no reactivate" numa frase que
      # explica a irreversibilidade — procurar o texto reprovaria a tela por dizer a coisa
      # certa. O que não pode existir é um `phx-click` que devolva o token.
      for acao <- ~w(reactivate unrevoke restore reativar) do
        refute html =~ ~s|phx-click="#{acao}"|, "existe um controle de #{acao}"
      end

      assert html =~ "no way back", "a linha revogada não diz que não há volta"

      refute html =~ ~r/<button[^>]*>\s*Reactivate/i,
             "Há um botão de reativar — revogação é definitiva, e um botão a transformaria em pausa."
    end
  end

  describe "R6 — o que vale em toda a tela" do
    test "SC-013 — zero valor e zero hash no HTML renderizado", ctx do
      {view, _} = abrir(ctx)
      render_submit(form(view, "#novo-token", %{"label" => "varredura"}))

      {:ok, token} =
        ctx.tenant |> Tenants.list_api_tokens() |> List.first() |> Map.fetch(:token)

      html = texto(render_patch(view, ~p"/api-tokens"))

      refute html =~ Base.encode16(token.token_hash, case: :lower)
      refute html =~ "token_hash"
    end

    test "R6.5 — nenhum prazo é constante no módulo da tela", _ctx do
      for arquivo <- [
            "lib/the_band_web/live/api_token_live/index.ex",
            "lib/the_band_web/live/api_token_live/view.ex"
          ] do
        fonte = File.read!(arquivo)

        refute fonte =~ ~r/@(prazo|maximo|aviso)\w*\s+\d+/, """
        #{arquivo} guarda um prazo em constante de módulo.

        90, 30 e 14 dias vêm de `api.access.thresholds` — FR-069. Em constante, o número
        muda num diff e a base passa a dizer outra coisa.
        """
      end
    end

    test "R6.1 — ausência é escrita, nunca traço nem zero", ctx do
      {_view, html} = abrir(ctx)
      t = texto(html)

      assert t =~ "No token created yet"
      refute t =~ ~r/>\s*—\s*</, "há um travessão no lugar de uma ausência"
    end
  end
end
