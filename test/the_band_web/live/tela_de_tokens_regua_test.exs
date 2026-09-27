defmodule TheBandWeb.TelaDeTokensReguaTest do
  @moduledoc """
  `/api-tokens` — os itens da régua (seção 3 de `specs/061-api-publica/prototipo/PROMPT.md`)
  que a conferência de 2026-09-23 encontrou **sem guarda** ou com guarda que passava por
  acidente.

  ## Cada caso aqui nasceu de um defeito injetado que a suíte não pegou

  | Item | O defeito injetado | O que a suíte fez |
  |---|---|---|
  | `R4.2` | o botão de confirmar passou a ler só `Revoke` | 84 testes verdes |
  | `R4.7` | o cartão *what the client sees* (o `401`) foi apagado | 84 testes verdes |
  | `R4.12` | a prosa que justifica a cláusula foi apagada | 84 testes verdes |
  | `R6.1` | a célula da conta dona virou um travessão | 84 testes verdes |
  | `R3.10`/`R6.6` | o hash de cada token foi impresso num atributo `data-h` | 28 testes verdes |

  As três primeiras passavam porque a asserção casava com **outro trecho da mesma página**:
  o título (e não o botão), `"the same"` de *"the same account"* (e não do `401`), e
  `"suspected leak"` da **opção do select** (e não da frase que explica o campo).

  ## A varredura é no HTML SERVIDO, e não no texto

  `R3.10` diz *"inclusive em atributo, em `data-*`, em comentário"*. Toda guarda desta casa
  que primeiro tira as tags está cega justamente aí: a varredura de segredo desta suíte lê o
  HTML cru, e por isso reprova o atributo.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Tenants

  # As oito colunas de `R2.1`, **na ordem aprovada**. A oitava é a da ação, e não tem rótulo.
  @colunas [
    "label",
    "token",
    "owner account · what it sees today",
    "created",
    "last used",
    "expires",
    "state",
    ""
  ]

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    %{conn: log_in(conn, admin), tenant: tenant, admin: admin}
  end

  defp abrir(ctx), do: live(ctx.conn, ~p"/api-tokens")

  defp criar(ctx, rotulo) do
    {:ok, view, _} = abrir(ctx)
    html = render_submit(form(view, "#novo-token", %{"label" => rotulo}))
    {view, html}
  end

  defp texto(html) do
    html
    |> String.replace(~r/<script.*?<\/script>/s, " ")
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
  end

  describe "R0.2 — a entrada do menu" do
    test "aparece para quem administra, depois de Accounts e Access scopes", ctx do
      {:ok, _view, html} = abrir(ctx)

      [menu] = Regex.run(~r/<header.*?<\/header>/s, html)

      ordem =
        ~r{href="(/accounts|/access-scopes|/api-tokens)"}
        |> Regex.scan(menu)
        |> Enum.map(&List.last/1)

      assert ordem == ["/accounts", "/access-scopes", "/api-tokens"], """
      O grupo **Contas** do menu não traz os três na ordem aprovada: #{inspect(ordem)}.

      Sem o item, a tela só se alcança pela URL — e foi assim que 100 participações
      observadas ficaram esperando numa tela que ninguém achava.
      """

      assert menu =~ ~r{href="/api-tokens"[^>]*>API tokens<}, """
      O item existe com outro texto. O menu promete o nome da tela, e o da régua é
      **API tokens**.
      """
    end

    test "NÃO aparece para conta comum", %{conn: conn, tenant: tenant} do
      {:ok, comum} =
        Tenants.create_user(tenant, %{
          "email" => "comum-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        })

      {:ok, _view, html} = live(log_in(conn, comum), ~p"/people")

      # A guarda mede alguma coisa: a página do member é uma página com menu, e o menu
      # traz os itens dele. Sem esta asserção, uma página em branco daria "não aparece".
      assert html =~ "Teams", "a página do member veio sem menu — a varredura olharia o nada"

      refute html =~ ~s|href="/api-tokens"|, """
      O menu ofereceu a tela de tokens a quem não administra. O clique levaria à recusa —
      menu que promete o que a porta nega ensina a ignorar o menu.
      """
    end
  end

  describe "R2.1 — as oito colunas, na ORDEM" do
    test "os oito rótulos, na ordem aprovada", ctx do
      {_view, html} = criar(ctx, "painel do diretor")

      [cabecalho] = Regex.run(~r/<thead>.*?<\/thead>/s, html)

      # `<th\b`, e nunca `<th[^>]*>`: este último casa com `<thead>` — "ead" cabe em
      # `[^>]*` — e a primeira coluna lida sai como `<tr><th>label`.
      colunas =
        ~r/<th\b[^>]*>(.*?)<\/th>/s
        |> Regex.scan(cabecalho)
        |> Enum.map(fn [_, c] -> c |> String.replace(~r/\s+/, " ") |> String.trim() end)

      assert colunas == @colunas, """
      As colunas da lista não são as oito aprovadas, nesta ordem.

      lidas:    #{inspect(colunas)}
      aprovada: #{inspect(@colunas)}

      A contagem sozinha não pega troca de ordem — e `owner account · what it sees today`
      antes de `token` muda o que a linha conta primeiro.
      """
    end
  end

  describe "R4.2, R4.7 e R4.12 — a confirmação" do
    setup ctx do
      {view, _} = criar(ctx, "integração do RH")
      html = view |> element("button", "Revoke") |> render_click()
      %{view: view, html: html}
    end

    test "R4.2 — o BOTÃO de confirmar nomeia o rótulo, e não só o título", %{html: html} do
      assert html =~
               ~r/<button[^>]*type="submit"[^>]*>\s*Revoke\s+“integração do RH”\s*<\/button>/,
             """
             O botão de confirmar não nomeia o rótulo.

             Afirmar o título não prova o botão: quem confirma olha o botão, e revogar o token
             errado interrompe a integração de um terceiro que não está na sala — FR-049.
             """
    end

    test "R4.7 — o cartão diz o 401 e o log interno, pelo id da requisição", %{html: html} do
      t = texto(html)

      assert t =~ "a token that never existed would get", """
      O cartão *what the client sees* não diz que a resposta é a **mesma** de um token que
      nunca existiu. `"the same"` não serve de guarda: ele casa com *"other tokens of the
      same account"*, do cartão ao lado.
      """

      assert t =~ "401", "o cartão não mostra o código que o cliente recebe"

      assert t =~ "findable by the request id", """
      A tela promete o motivo real sem dizer por onde ele é achado. Sem o id da requisição,
      *"por que esta chamada foi recusada?"* volta a ser *"por alguma coisa"*.
      """
    end

    test "R4.12 — a razão do campo está escrita, e não é a opção do select", %{html: html} do
      t = texto(html)

      # **Fora da lista de opções.** `"suspected leak"` é o rótulo declarado da cláusula
      # `suspeita_de_vazamento`, e aparece no `<option>` — uma asserção por ele passa com a
      # frase apagada. O recorte é a sentença que só existe na prosa.
      assert t =~ "rotate everything that account reaches", """
      A frase que justifica o campo sumiu. Sem ela o motivo vira burocracia que alguém
      preenche por hábito, e a lista fechada perde a razão de ser fechada.
      """

      assert t =~ "is a count and not a reading of free text", """
      A tela não diz por que a lista é fechada: para que *"quantas revogações foram por
      vazamento neste trimestre?"* seja contagem, e não leitura de texto livre.
      """
    end
  end

  describe "R3.10 e R6.6 — a varredura no HTML servido" do
    test "nem o valor nem o hash aparecem, nem dentro de atributo", ctx do
      {view, criado} = criar(ctx, "varredura do atributo")

      [valor] = Regex.run(~r/#{Tenants.api_token_prefix()}[a-f0-9]+_[A-Za-z0-9_\-]+/, criado)
      ["tb", "api", _publico, segredo] = String.split(valor, "_", parts: 4)

      token = ctx.tenant |> Tenants.list_api_tokens() |> List.first() |> Map.fetch!(:token)

      hashes = [
        Base.encode16(token.token_hash, case: :lower),
        Base.encode16(token.token_hash, case: :upper),
        Base.encode64(token.token_hash)
      ]

      # **HTML cru, e não `texto/1`.** Tirar as tags apaga os atributos, que é onde este
      # vazamento cabe: `data-h={Base.encode16(hash)}` numa célula passou por 28 testes.
      depois = render_patch(view, ~p"/api-tokens")

      assert depois =~ token.last_four, """
      A varredura não achou nem os quatro últimos — ela não está olhando a lista, e os
      `refute` abaixo não provariam nada.
      """

      refute depois =~ valor, "o valor em claro sobreviveu à navegação"
      refute depois =~ segredo, "o segredo sobreviveu à navegação, ainda que o valor não"

      for hash <- hashes do
        refute depois =~ hash, """
        O hash do token está no HTML servido, em alguma das grafias.

        Ele não é o valor, e ainda assim é o verificador: publicá-lo entrega a quem tem o
        HTML o alvo de uma busca offline. SC-001 diz zero nos quatro lugares.
        """
      end
    end
  end

  describe "R6.1 — ausência é escrita, nunca traço nem zero" do
    test "nenhuma célula traz um travessão ou um zero sozinho, em estado nenhum", ctx do
      {view, criado} = criar(ctx, "integração do RH")

      confirmacao = view |> element("button", "Revoke") |> render_click()

      revogado =
        view
        |> form("form[phx-submit=revogar]", %{"revocation_clause" => "integracao_encerrada"})
        |> render_submit()

      painel =
        render_click(view, "abrir_uso", %{
          "id" =>
            ctx.tenant
            |> Tenants.list_api_tokens()
            |> List.first()
            |> Map.fetch!(:token)
            |> Map.fetch!(:id)
        })

      for {onde, html} <- [
            {"logo após criar", criado},
            {"com a confirmação aberta", confirmacao},
            {"com a linha revogada", revogado},
            {"com o painel de uso aberto", painel}
          ] do
        # **No HTML cru.** Depois de tirar as tags não sobra nenhum `>` nem `<`, e a mesma
        # varredura sobre o texto nunca pode casar — ela passaria com a tela toda de traços.
        achados = Regex.scan(~r/>\s*(?:—|-|0)\s*</, html)

        assert achados == [], """
        Há uma célula com traço, travessão ou zero no lugar de uma ausência #{onde}.

        Ausência escrita nunca é zero: quem lê um traço não sabe se a plataforma não olhou,
        olhou e não achou, ou achou nada.
        """
      end
    end
  end

  describe "R2.22 — o painel conta POR ROTA, e o número é o da janela" do
    # O que a suíte entregue afirma do painel são os **nomes das rotas**, e um deles —
    # `/api/v1/teams` — aparece na página mesmo com o painel vazio: ele está no exemplo
    # `curl` do painel do valor, que continua aberto enquanto o uso abre. Nenhum teste olha
    # a **contagem**, e contagem errada é o defeito que não levanta erro: a tela continua
    # abrindo, e o número responde outra pergunta.
    test "duas leituras numa rota e uma noutra são 2 e 1, cada uma na sua linha", ctx do
      {view, _} = criar(ctx, "painel do diretor")
      token = ctx.tenant |> Tenants.list_api_tokens() |> List.first() |> Map.fetch!(:token)

      for rota <- ["/api/v1/teams", "/api/v1/teams", "/api/v1/people"] do
        registrar_leitura(ctx.tenant, token.public_id, rota)
      end

      html = render_click(view, "abrir_uso", %{"id" => token.id})

      # A tabela do painel, e não a página: `2` sozinho casa com qualquer data.
      painel =
        ~r/<table.*?<\/table>/s
        |> Regex.scan(html)
        |> Enum.map(&hd/1)
        |> Enum.find(&(&1 =~ ~s|data-label="route"|))

      assert painel, "não achei a tabela do painel de uso — a varredura olharia o nada"

      lidas =
        ~r|<td data-label="route">.*?<code[^>]*>(.*?)</code>.*?<td data-label="reads"[^>]*>\s*(\d+)\s*</td>|s
        |> Regex.scan(painel)
        |> Enum.map(fn [_, rota, n] -> {String.trim(rota), n} end)

      assert lidas == [{"/api/v1/teams", "2"}, {"/api/v1/people", "1"}], """
      A quebra por rota não é a medida: #{inspect(lidas)}.

      Esperado `/api/v1/teams` com 2 e `/api/v1/people` com 1, nessa ordem — a consulta
      ordena pela contagem, decrescente, porque quem investiga procura onde o volume está.
      Um total somado, uma contagem de rotas distintas ou a ordem invertida passam por
      qualquer asserção que só procure o nome da rota na página.
      """

      assert Regex.scan(~r/<td data-label="last one".*?· observed/s, painel) |> length() == 2,
             """
             A última leitura veio sem a marca de proveniência em alguma das linhas.

             A data é **observada** — veio de uma chamada que aconteceu —, e marca é o que
             separa isso de um cálculo.
             """
    end

    # Pelo `Repo`, e não por `ApiAccessLog.registrar/1`: aquela função carimba o próprio
    # instante de propósito, e aqui o instante é o dado do teste.
    defp registrar_leitura(tenant, publico, rota) do
      {1, nil} =
        TheBand.Repo.insert_all(TheBand.Tenants.ApiAccessLog, [
          %{
            tenant_id: tenant.id,
            token_public_id: publico,
            route: rota,
            occurred_at: DateTime.truncate(DateTime.utc_now(), :microsecond)
          }
        ])

      :ok
    end
  end

  describe "R6.5 — nenhum prazo declarado vira literal" do
    # A guarda que existia olhava só **atributo de módulo** — `~r/@(prazo|maximo|aviso)\w*\s+\d+/`.
    # Trocar `Tenants.api_token_threshold("token_lifetime", "max_days")` por `maximo = 90`
    # dentro de `prazos/0` passa por ela inteira, e é exatamente a violação que `R6.5`
    # nomeia: *"qualquer prazo como constante"*.
    #
    # O critério da régua é o `grep` por **90** e por **14**, e é ele que está aqui.
    test "nem 90 nem 14 aparecem no módulo da tela ou no da fronteira" do
      for arquivo <- [
            "lib/the_band_web/live/api_token_live/index.ex",
            "lib/the_band_web/live/api_token_live/view.ex",
            "lib/the_band/tenants/api_tokens.ex"
          ] do
        # **Só o código.** Os três arquivos explicam os prazos em prosa — "90, 30 e 14 dias
        # vêm de `api.access.thresholds`" —, e uma guarda que lesse a documentação
        # reprovaria o arquivo por dizer a coisa certa.
        fonte =
          arquivo
          |> File.read!()
          |> String.replace(~r/@moduledoc\s+"""..*?"""/s, "")
          |> String.replace(~r/@doc\s+"""..*?"""/s, "")
          |> String.split("\n")
          |> Enum.reject(&String.starts_with?(String.trim(&1), "#"))
          |> Enum.join("\n")

        for {numero, limiar} <- [{"90", "token_lifetime"}, {"14", "token_expiry_warning"}] do
          refute fonte =~ ~r/\b#{numero}\b/, """
          #{arquivo} traz #{numero} como literal.

          Ele é o valor declarado de `#{limiar}` em `api.access.thresholds`. Em literal, o
          número muda num diff, a base passa a dizer outra coisa, e a tela continua
          imprimindo o que foi escrito à mão — FR-069.
          """
        end
      end
    end
  end
end
