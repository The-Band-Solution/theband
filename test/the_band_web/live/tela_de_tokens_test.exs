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
    # **A regra virou, e este teste virou com ela** — Q1, aprovada em 2026-09-23. Até então
    # afirmava o contrário: que "sem expiração" NÃO era oferecido. Fica registrado aqui para
    # que a reversão seja legível no histórico, e não pareça teste que alguém afrouxou.
    test "R1.2 — o prazo vem da base, e 'sem expiração' É oferecido, por último", ctx do
      {_view, html} = abrir(ctx)
      t = texto(html)
      {maximo, true} = Tenants.api_token_threshold("token_lifetime", "max_days")

      assert t =~ "#{maximo} days — suggested"

      refute t =~ "the declared maximum", """
      A tela ainda chama o teto de máximo declarado. Máximo do qual se abre mão não é máximo,
      e desde que "sem expiração" é oferecido, a palavra afirma o que a regra desfez.
      """

      assert html =~ ~s|<option value="">no expiration</option>|, """
      A opção "sem expiração" não está no select, ou não carrega valor vazio. Valor vazio é o
      que o contexto lê como escolha explícita de não expirar.
      """

      # A ORDEM importa: a opção sem prazo é a última, e nunca a primeira. A primeira é a que
      # se escolhe sem pensar.
      #
      # O recorte é o select DO PRAZO, e não a página: a primeira `<option>` do documento é
      # da conta dona, e varrer tudo mediria outro select.
      [prazo] = Regex.run(~r/name="expires_in_days".*?<\/select>/s, html)

      opcoes = Regex.scan(~r/<option value="([^"]*)"/, prazo) |> Enum.map(&List.last/1)

      assert opcoes != [], "não encontrei o select de prazo no HTML"
      assert List.last(opcoes) == "", "«sem expiração» não é a última opção do select"
      assert List.first(opcoes) == "#{maximo}", "o prazo sugerido não é o primeiro"
    end

    test "R1.3 — a caixa explica a escolha, e data a reversão", ctx do
      {_view, html} = abrir(ctx)
      t = texto(html)

      assert t =~ "is a choice with a cost"
      assert t =~ "leaves circulation only by deliberate revocation"
      assert t =~ "read again on every call"
      assert t =~ "reverted on 23 Sep 2026"

      refute t =~ "No expiration is not offered here", """
      A caixa ainda nega a opção que o select oferece — a tela contradiz a si mesma.
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

      depois =
        view
        |> form("form[phx-submit=revogar]", %{"revocation_clause" => "integracao_encerrada"})
        |> render_submit()
        |> texto()

      assert depois =~ "all 1", """
      A linha sumiu da lista ao ser revogada. SC-012: zero linhas removidas fisicamente, e a
      lista mostra revogado por padrão.
      """

      assert depois =~ "revoked 1"
      assert depois =~ "no way back"
    end

    test "R2.15 — não existe CONTROLE de reativar", %{view: view} do
      view |> element("button", "Revoke") |> render_click()

      html =
        view
        |> form("form[phx-submit=revogar]", %{"revocation_clause" => "integracao_encerrada"})
        |> render_submit()

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

    test "R4.11 — a confirmação oferece as quatro cláusulas da base, e a nota", %{view: view} do
      html = view |> element("button", "Revoke") |> render_click()

      # As cláusulas vêm da base de conhecimento, e o teste as lê de lá: escrevê-las aqui
      # faria o teste passar no dia em que a tela e a regra divergissem — R6.5.
      for {id, rotulo} <- Tenants.api_token_revocation_labels() do
        assert html =~ ~s|<option value="#{id}">#{rotulo}</option>|,
               "a cláusula #{id} não está no select, ou não usa o rótulo declarado"
      end

      assert html =~ ~s|name="revocation_note"|, "não há campo de nota livre"

      t = texto(html)
      assert t =~ "optional", "a nota não está marcada como opcional"
      assert t =~ "suspected leak", "a razão do campo não está escrita — R4.12"
      assert t =~ "omission, not a decision"
    end

    test "R4.13 — a linha revogada mostra a cláusula e a nota", %{view: view} do
      view |> element("button", "Revoke") |> render_click()

      t =
        view
        |> form("form[phx-submit=revogar]", %{
          "revocation_clause" => "suspeita_de_vazamento",
          "revocation_note" => "apareceu num gist público"
        })
        |> render_submit()
        |> texto()

      assert t =~ "suspected leak", """
      A cláusula não voltou à tela. Gravar a razão e não mostrá-la deixa a decisão no banco,
      onde ninguém a reconstrói — que é o estado que a Q4 trocou.
      """

      assert t =~ "apareceu num gist público", "a nota livre não aparece na linha"
    end

    test "cláusula fora da lista é RECUSADA, e a confirmação continua aberta", %{
      view: view,
      tenant: tenant
    } do
      view |> element("button", "Revoke") |> render_click()
      [linha] = Tenants.list_api_tokens(tenant)

      # **O evento direto, e não o formulário.** O ajudante de teste recusa um valor fora do
      # select — que é o que o navegador faz, e não é onde a guarda tem de estar. Quem forja
      # a requisição não passa pelo select, e é essa chamada que o servidor precisa recusar.
      t =
        render_submit(view, "revogar", %{
          "token_id" => linha.token.id,
          "revocation_clause" => "porque_sim"
        })
        |> texto()

      assert t =~ "Revoke “integração do RH”?", """
      A confirmação fechou depois de uma recusa, e quem revoga voltou ao começo sem saber por
      quê. A recusa tem de ficar onde o campo está.
      """

      refute t =~ "revoked 1", "o token foi revogado com uma cláusula que não está na lista"
    end
  end

  describe "R2.20 a R2.25 — o painel de uso" do
    setup ctx do
      {view, _} = abrir(ctx)
      render_submit(form(view, "#novo-token", %{"label" => "painel do diretor"}))
      linha = ctx.tenant |> Tenants.list_api_tokens() |> List.first()
      %{view: view, token: linha.token}
    end

    test "R2.1 continua em OITO colunas — o uso não virou nona", ctx do
      {_view, html} = abrir(ctx)

      [cabecalho] = Regex.run(~r/<thead>.*?<\/thead>/s, html)
      colunas = Regex.scan(~r/<th\b/, cabecalho) |> length()

      assert colunas == 8, """
      A tabela tem #{colunas} colunas, e a R2.1 aprovada tem oito. O uso abre num painel
      justamente para não virar a nona.
      """
    end

    test "R2.21 e R2.22 — abre por rota, com a janela escolhida e dita", ctx do
      registrar_leitura(ctx.tenant, ctx.token.public_id, "/api/v1/teams")
      registrar_leitura(ctx.tenant, ctx.token.public_id, "/api/v1/teams")
      registrar_leitura(ctx.tenant, ctx.token.public_id, "/api/v1/people")

      t =
        ctx.view
        |> element("button[phx-click=abrir_uso]")
        |> render_click()
        |> texto()

      assert t =~ "painel do diretor · what it read"

      assert t =~ "last 24 h",
             "a janela não aparece — contagem sem janela é número sem denominador"

      assert t =~ "/api/v1/teams"
      assert t =~ "/api/v1/people"
      assert t =~ "By route, never one total"

      refute t =~ "3 reads", "há um total somando as rotas — R2.22 pede a quebra, nunca a soma"
    end

    test "janela sem leitura escreve a ausência, e não zero", ctx do
      # A leitura existe, e está **fora** da janela — dez dias atrás contra as últimas 24 h.
      # É a diferença que o teste mede: "nenhuma chamada nesta janela" não é "nenhuma chamada
      # jamais", e um zero as confundiria.
      registrar_leitura(
        ctx.tenant,
        ctx.token.public_id,
        "/api/v1/teams",
        DateTime.add(DateTime.utc_now(), -10, :day)
      )

      t = ctx.view |> element("button[phx-click=abrir_uso]") |> render_click() |> texto()

      assert t =~ "no accepted call in the chosen window", """
      A janela vazia veio como tabela vazia ou como zero. Ausência se escreve, e "nenhuma
      chamada nesta janela" não é "nenhuma chamada jamais".
      """
    end

    test "R2.23 a R2.25 — o painel diz o que não mostra, por que existe, e o que ele é", ctx do
      t = ctx.view |> element("button[phx-click=abrir_uso]") |> render_click() |> texto()

      assert t =~ "Not what was read"
      assert t =~ "Not a refused call"
      assert t =~ "The verdict cannot see accumulation; this panel can"
      assert t =~ "itself a record about people"
      assert t =~ "indefinitely"
      assert t =~ "require_admin"
    end

    # O registro nasce do plug da API, e aqui a linha é montada direto: o que se confere é o
    # painel, e não o caminho da requisição — esse tem teste próprio em
    # `registro_e_limite_test.exs`.
    #
    # **Pelo `Repo`, e não por `ApiAccessLog.registrar/1`**: aquela função carimba o próprio
    # instante e ignora o que recebe, de propósito — instante vindo de quem chama é instante
    # que quem chama forja. Só que é exatamente o instante que este teste precisa mover.
    defp registrar_leitura(tenant, publico, rota, quando \\ nil) do
      {1, nil} =
        TheBand.Repo.insert_all(TheBand.Tenants.ApiAccessLog, [
          %{
            tenant_id: tenant.id,
            token_public_id: publico,
            route: rota,
            occurred_at: DateTime.truncate(quando || DateTime.utc_now(), :microsecond)
          }
        ])

      :ok
    end
  end

  describe "R6 — o que vale em toda a tela" do
    # **Esta guarda não guardava nada, e a conferência do QA provou por injeção**: pondo
    # `data-h={Base.encode16(token_hash)}` em cada linha, o hash aparecia duas vezes no HTML
    # servido e os 84 testes ficavam verdes — inclusive este, que leva o nome do critério.
    #
    # Duas razões, e cada uma bastaria. A varredura rodava sobre `texto/1`, que **tira as
    # tags** — e `R3.10` diz, com todas as letras, *"inclusive em atributo, em `data-*`, em
    # comentário"*, que é exatamente o que some junto com as tags. E ela nunca afirmava nada
    # sobre o **valor em claro**: procurava o hash e a palavra `token_hash`, nunca o segredo.
    #
    # Procurar a palavra `token_hash` era, ainda por cima, guarda que lê a palavra e não o
    # comportamento — o nome do campo não é o segredo.
    test "SC-013 — zero valor e zero hash no HTML renderizado", ctx do
      {view, _} = abrir(ctx)
      criado = render_submit(form(view, "#novo-token", %{"label" => "varredura"}))

      [valor] = Regex.run(~r/#{Tenants.api_token_prefix()}[A-Za-z0-9_\-]+/, texto(criado))
      token = ctx.tenant |> Tenants.list_api_tokens() |> List.first() |> Map.fetch!(:token)

      # O HTML **CRU**. Nada de `texto/1` aqui.
      html = render_patch(view, ~p"/api-tokens")

      assert html =~ token.last_four, """
      A varredura não achou nem os quatro últimos, que DEVEM estar na máscara.

      Controle positivo: sem ele, uma varredura que lesse a página errada passaria por estar
      lendo nada.
      """

      refute html =~ valor, "o valor em claro sobreviveu ao patch — R3.8 e SC-013"
      refute html =~ Base.encode16(token.token_hash, case: :lower)
      refute html =~ Base.encode16(token.token_hash, case: :upper)
      refute html =~ Base.encode64(token.token_hash)
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

    # **Esta asserção não podia falhar.** Ela procurava `>—<` depois de `texto/1` ter tirado
    # todas as tags: não sobra um `>` nem um `<` no texto, então o padrão nunca casa. Guarda
    # que não pode reprovar passa sempre, e essa é a pior espécie — ela conta como coberta.
    test "R6.1 — ausência é escrita, nunca traço nem zero", ctx do
      {view, _} = abrir(ctx)

      assert texto(render(view)) =~ "No token created yet", "a lista vazia não escreve a ausência"

      # **A varredura precisa de linhas.** A primeira versão desta guarda rodava na lista
      # VAZIA — zero células —, e passava com um travessão plantado na tela. Guarda sem
      # denominador passa sempre, e conta como coberta.
      render_submit(form(view, "#novo-token", %{"label" => "varredura da ausência"}))
      html = render(view)

      # No HTML **cru**, onde `>` e `<` existem, recortado à **célula de tabela**. Procurar
      # `><` solto casaria com todo `<span></span>` estrutural, e padrão largo erra para o
      # lado barato: reprova o que está certo e ensina a ignorá-lo.
      celulas = Regex.scan(~r/<td[^>]*>(.*?)<\/td>/s, html) |> Enum.map(&List.last/1)

      assert length(celulas) >= 8, """
      A varredura achou #{length(celulas)} células, e a linha aprovada tem oito.

      Controle positivo: sem ele, esta guarda volta a varrer nada.
      """

      for celula <- celulas, vazio <- ["—", "-", "0"] do
        refute String.trim(celula) == vazio,
               "uma célula traz apenas `#{vazio}` — ausência se escreve, e traço não é escrita"
      end
    end
  end
end
