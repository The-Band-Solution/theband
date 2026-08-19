defmodule TheBandWeb.PaginasDeErroTest do
  @moduledoc """
  As páginas de erro — issue #437.

  ## As asserções que carregam este arquivo

  1. **o 404 diz que é o CAMINHO**, e não que o dado não existe — foi a confusão que originou
     a issue: `/works/verifications` devolveu 404 e a leitura foi "a tela não existe";
  2. **o 404 sugere a rota parecida**, e só quando ela está na lista fechada;
  3. **o 403 NÃO nomeia recurso nenhum** — nomear entregaria a existência pela porta que a
     regra fechou;
  4. **o 500 traz o identificador da requisição**, que é o que liga a tela ao log;
  5. as três renderizam **sem `current_tenant` e sem `current_user`** — o layout do app
     depende deles, e seria a página de erro dando erro.
  """
  use TheBandWeb.ConnCase, async: true

  alias Phoenix.ConnTest
  alias Phoenix.HTML
  alias TheBandWeb.ErrorHTML

  # Renderiza a página como o endpoint faz, com uma `conn` **crua**: sem sessão, sem tenant,
  # sem usuário. É o estado em que uma página de erro de verdade é renderizada.
  defp render_erro(template, caminho \\ "/qualquer-coisa") do
    conn = ConnTest.build_conn(:get, caminho)

    ErrorHTML.render(template, %{conn: conn})
    |> HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  describe "o 404" do
    test "diz que o problema é o caminho, e mostra qual" do
      html = render_erro("404.html", "/works/verifications")

      assert html =~ "Nothing plays at this address"
      assert html =~ "/works/verifications"
      assert html =~ "matches no page on this platform"
    end

    test "diz explicitamente que isso não fala do dado" do
      # A frase existe por causa do caso real: quem viu o 404 concluiu que a tela não
      # existia, quando a tela existe e o caminho estava errado.
      html = render_erro("404.html", "/works/verifications")

      assert html =~ "says nothing about the data"
      assert html =~ "nothing collected yet"
    end

    test "sugere a rota parecida quando ela está na lista" do
      html = render_erro("404.html", "/works/verifications")

      assert html =~ "Did you mean"
      assert html =~ "/work/verifications"
    end

    test "não sugere nada quando nada casa — e dizer isso é resposta" do
      html = render_erro("404.html", "/xyz/nada-parecido")

      refute html =~ "Did you mean"
    end

    test "não sugere para caminho que só COMEÇA parecido" do
      # `/workspace` não é `/works`. Sem a checagem de fronteira, a sugestão apareceria e a
      # plataforma afirmaria que existe tela onde não existe.
      html = render_erro("404.html", "/workspace/algo")

      refute html =~ "Did you mean"
    end
  end

  describe "o 403" do
    test "diz que falta permissão" do
      html = render_erro("403.html")

      assert html =~ "The stage door is closed"
      assert html =~ "not available to it"
    end

    test "NÃO nomeia recurso nenhum — a regra do tenant vale aqui também" do
      # As LiveViews devolvem "não encontrada" para recurso de outro tenant justamente para
      # não confirmar que existe. Se esta página dissesse "você não pode ver o repositório X",
      # entregaria a existência pela porta que a regra fechou.
      html = render_erro("403.html", "/work/repositories/o-segredo")

      refute html =~ "o-segredo"
      refute html =~ "repositor"
    end
  end

  describe "o 500" do
    test "diz que a culpa é da plataforma, não do pedido" do
      html = render_erro("500.html")

      assert html =~ "A string broke mid-song"
      assert html =~ "on our side"
    end

    test "traz o identificador da requisição quando existe" do
      conn =
        ConnTest.build_conn(:get, "/x")
        |> Plug.Conn.put_resp_header("x-request-id", "REQ-123")

      html =
        ErrorHTML.render("500.html", %{conn: conn})
        |> HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      # Sem ele, "deu erro" não tem como ser investigado.
      assert html =~ "REQ-123"
      assert html =~ "whoever investigates"
    end

    test "sem o identificador, não inventa um" do
      html = render_erro("500.html")

      refute html =~ "whoever investigates"
    end
  end

  describe "as três juntas" do
    test "renderizam sem tenant e sem usuário", _ do
      # O layout do app depende de `current_tenant` e `current_user`. Se a moldura usasse ele,
      # a página de erro daria erro exatamente quando fosse mais necessária.
      for template <- ["404.html", "403.html", "500.html"] do
        html = render_erro(template)

        assert html =~ "The Band"
        # O caminho de volta: erro sem saída obriga quem lê a apagar a barra de endereço.
        assert html =~ ~s|href="/people"|
        assert html =~ ~s|href="/work"|
      end
    end

    test "cada uma tem a ilustração, e ela é decorativa" do
      for template <- ["404.html", "403.html", "500.html"] do
        html = render_erro(template)

        assert html =~ "<svg"
        # Decorativa: quem usa leitor de tela recebe o título e as frases, que carregam a
        # informação toda.
        assert html =~ ~s|aria-hidden="true"|
        # Nenhuma requisição externa: a página de erro tem de funcionar quando a plataforma
        # está com problema.
        refute html =~ "<img"
      end
    end

    test "código sem página própria cai no nome do status, sem ilustração" do
      html = render_erro("502.html")

      assert html =~ "Bad Gateway"
      # Desenhar algo para 502 exigiria inventar metáfora para o que não se sabe.
      refute html =~ "<svg"
    end
  end
end
