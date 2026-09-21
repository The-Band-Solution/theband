defmodule TheBandWeb.Api.V1.SwaggerUITest do
  @moduledoc """
  A página do Swagger — `/api/docs` — sob a política de conteúdo desta casa.

  **Existe porque um `HTTP 200` não prova que uma página funciona.** Em 2026-09-21 a página
  subiu, respondeu 200, e o navegador mostrou uma tela em branco: a política é
  `script-src 'self'`, e ela bloqueia tanto o script de CDN quanto o bloco inline que
  inicializa a interface. O servidor não tem como saber disso — quem bloqueia é o navegador,
  depois da resposta, e nenhum código de status muda.

  A verificação daquele dia foi `curl -o /dev/null -w '%{http_code}'`. Ela deu 200, e estava
  certa sobre o que media. Só não media o que importava.

  Estes testes medem o que o navegador vai obedecer: o que a política PERMITE, e o que a
  página PEDE. Se os dois deixarem de casar, a tela fica em branco de novo — e desta vez a
  suíte reprova antes de alguém abrir o navegador.
  """
  use TheBandWeb.ConnCase, async: true

  setup do
    {tenant, user} = tenant_with_admin()
    %{tenant: tenant, user: user}
  end

  describe "a política e a página casam" do
    setup %{conn: conn, user: user} do
      resposta = conn |> log_in(user) |> get(~p"/api/docs")
      %{resposta: resposta, html: html_response(resposta, 200)}
    end

    test "`script-src` traz nonce, e NÃO `'unsafe-inline'`", %{resposta: resposta} do
      assert diretiva(resposta, "script-src") =~ ~r/'nonce-[A-Za-z0-9+\/=]+'/,
             "sem nonce na diretiva, o bloco inline que inicializa a interface é bloqueado"

      refute diretiva(resposta, "script-src") =~ "'unsafe-inline'",
             "'unsafe-inline' liberaria QUALQUER script injetado — o nonce libera só aquele bloco"
    end

    # A distinção entre as duas diretivas fica escrita porque a primeira versão deste teste
    # a ignorou: procurou `'unsafe-inline'` na política INTEIRA e reprovou por causa de
    # `style-src`, que é padrão da casa e está certo. Um teste que reprova o comportamento
    # correto seria removido na primeira vez que incomodasse, e levaria junto a guarda do
    # `script-src`, que é a que importa.
    test "`style-src` permite inline — e isso é escolha, não descuido", %{resposta: resposta} do
      assert diretiva(resposta, "style-src") =~ "'unsafe-inline'",
             "a interface do Swagger injeta estilo inline; sem isto a página vem sem formato"
    end

    test "o nonce da política é o mesmo que o script carrega", %{resposta: resposta, html: html} do
      [_, da_politica] =
        Regex.run(~r/'nonce-([A-Za-z0-9+\/=]+)'/, diretiva(resposta, "script-src"))

      assert html =~ "nonce=\"#{da_politica}\"",
             "a política permite um nonce que nenhum script da página apresenta"
    end

    test "cada bloco inline apresenta o nonce — nenhum fica de fora", %{html: html} do
      inline = Regex.scan(~r/<script(?![^>]*\ssrc=)[^>]*>/, html) |> List.flatten()

      refute inline == [], "a página não tem bloco inline — o teste perdeu seu objeto"

      sem_nonce = Enum.reject(inline, &(&1 =~ "nonce="))

      assert sem_nonce == [],
             "#{length(sem_nonce)} de #{length(inline)} blocos inline sem nonce: #{inspect(sem_nonce)}"
    end

    test "todo ativo vem do próprio domínio, nenhum de CDN", %{html: html} do
      externos =
        ~r/(?:src|href)="(https?:\/\/[^"]+)"/
        |> Regex.scan(html)
        |> Enum.map(fn [_, url] -> url end)

      assert externos == [],
             "ativo de terceiro na página contraria o achado do Sobelow #288: #{inspect(externos)}"
    end

    test "os três ativos do Swagger apontam para `/vendor/`", %{html: html} do
      for ativo <- ~w(swagger-ui.css swagger-ui-bundle.js swagger-ui-standalone-preset.js) do
        assert html =~ "/vendor/swagger-ui/#{ativo}", "a página não pede #{ativo} do domínio"
      end
    end

    test "e esses ativos existem no disco, com conteúdo", %{} do
      for ativo <- ~w(swagger-ui.css swagger-ui-bundle.js swagger-ui-standalone-preset.js) do
        caminho = Path.join(:code.priv_dir(:the_band), "static/vendor/swagger-ui/#{ativo}")

        assert File.exists?(caminho), "#{ativo} referenciado pela página e ausente do repositório"
        assert File.stat!(caminho).size > 1_000, "#{ativo} existe mas está vazio"
      end
    end

    test "a página aponta para a descrição, e a descrição responde", %{html: html, conn: conn} do
      assert html =~ "/api/openapi"

      descricao = conn |> get(~p"/api/openapi") |> json_response(200)

      assert Map.has_key?(descricao["paths"], "/api/v1/teams")
      assert Map.has_key?(descricao["paths"], "/api/v1/people")
    end
  end

  # Estilo inline e script inline não têm o mesmo peso: um muda a aparência, o outro executa
  # código com a sessão de quem está logado. Por isso a política trata cada diretiva à parte,
  # e por isso o teste também precisa.
  defp diretiva(resposta, nome) do
    [politica] = get_resp_header(resposta, "content-security-policy")

    politica
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.find(fn d -> String.starts_with?(d, nome <> " ") end)
    |> case do
      nil -> flunk("a política não declara `#{nome}`: #{politica}")
      d -> d
    end
  end

  describe "o alcance da página" do
    test "sem sessão, a interface não abre — decisão Q7 da spec 061", %{conn: conn} do
      resposta = get(conn, ~p"/api/docs")

      assert redirected_to(resposta) == ~p"/sign-in"
    end

    test "sem sessão, a DESCRIÇÃO abre — é contrato, e não carrega dado", %{conn: conn} do
      descricao = conn |> get(~p"/api/openapi") |> json_response(200)

      assert descricao["info"]["title"] =~ "The Band"
    end
  end
end
