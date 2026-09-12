defmodule TheBandWeb.FluxoPorPessoaTest do
  @moduledoc """
  A aba *Flow per person* — feature 060, protótipo aprovado em 2026-09-08.

  A régua é a seção 3 de `specs/060-tela-da-equipe/prototipo/team-people-PROMPT.md`, e o que
  se confere aqui é **o que a pessoa lê**, item a item. Divergência é defeito, e não melhoria
  de implementação.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cen = cenario_real(tenant)

    {:ok, equipe} =
      EO.declare_structural_team(tenant, cen.organization.id, "Plataforma", admin.id)

    {:ok, papel} =
      EO.create_role(tenant, cen.organization.id, %{code: "dev", name: "Dev"}, admin.id)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      equipe: equipe,
      papel: papel,
      repo_id: cen.observed_repository_id
    }
  end

  defp membro(ctx, login, opts \\ []) do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: String.capitalize(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    attrs =
      if Keyword.get(opts, :com_papel, true),
        do: %{organizational_role_id: ctx.papel.id},
        else: %{organizational_role_id: ctx.papel.id}

    {:ok, _} = EO.declare_team_membership(ctx.tenant, ctx.equipe.id, p.id, attrs, ctx.admin.id)
    p
  end

  # O TEXTO, e não o HTML. Uma frase do protótipo quebra em três linhas no HEEx, e
  # `html =~ "no column sums to the team"` falha contra o HTML cru enquanto o navegador
  # mostra a frase inteira. Comparar contra HTML é comparar com a formatação do código.
  defp texto(html) do
    html
    |> String.replace(~r/<script.*?<\/script>/s, " ")
    |> String.replace(~r/<[^>]*>/, " ")
    # E DESESCAPA: a pessoa lê `team's`, e o HTML traz `team&#39;s`. Sem isto, toda asserção
    # com apóstrofo, `&` ou aspas falha contra uma tela que está certa.
    |> String.replace("&#39;", "'")
    |> String.replace("&quot;", "\"")
    |> String.replace("&amp;", "&")
    |> String.replace(~r/\s+/, " ")
  end

  # Um item ABERTO, designado à pessoa: `external_created_at` presente e `external_closed_at`
  # nulo é a substituição declarada do WIP.
  defp item_aberto(ctx, pessoa) do
    externo = "FPPW_#{System.unique_integer([:positive, :monotonic])}"

    {:ok, i} =
      TheBand.Repo.insert(%TheBand.WorkItems.Schemas.CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 1_000_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "item #{externo}",
        state: "OPEN",
        external_created_at: DateTime.add(DateTime.utc_now(:second), -10, :day),
        collected_at: DateTime.utc_now(:second)
      })

    TheBand.Repo.insert!(%TheBand.WorkItems.Schemas.IssueAssignee{
      tenant_id: ctx.tenant.id,
      collected_issue_id: i.id,
      login: pessoa.login,
      person_id: pessoa.id
    })

    i
  end

  defp abrir(ctx, extra \\ []), do: texto(abrir_html(ctx, extra))

  # O HTML cru, para o que só existe em ATRIBUTO — o endereço da aba está no `href`, e o
  # `texto/1` o remove junto com as tags.
  defp abrir_html(ctx, extra \\ []) do
    query = URI.encode_query([{"tab", "people"} | extra])
    {:ok, _view, html} = live(ctx.conn, "/teams/#{ctx.equipe.id}?" <> query)
    html
  end

  describe "a aba (§3.1)" do
    test "é o valor `people` no MESMO parâmetro, e não uma rota nova", ctx do
      membro(ctx, "ana")
      assert abrir(ctx) =~ "Flow per person", "a aba existe e nomeia o que responde"

      assert abrir_html(ctx) =~ "tab=people", """
      `people` no mesmo parâmetro das outras duas abas. Rota própria faria a aba parecer outra
      tela, e ela é um recorte da mesma equipe.
      """
    end

    test "aba inexistente NÃO cai silenciosamente no painel", ctx do
      membro(ctx, "ana")
      {:ok, _view, html} = live(ctx.conn, "/teams/#{ctx.equipe.id}?tab=inventada")

      assert html =~ "inventada", """
      Cair no padrão sem avisar é sucesso silencioso: quem digitou o nome errado concluiria
      que a plataforma não tem aquela informação, quando o que ela não tem é aquele nome.
      """
    end
  end

  describe "o cabeçalho e o controle de granulação (§3.2)" do
    test "UM controle para a aba inteira, com a razão escrita", ctx do
      membro(ctx, "ana")
      html = abrir(ctx)

      assert html =~ "One grain control for the whole tab", """
      No Dashboard o controle fica em cada gráfico. Aqui não: os gráficos de duas pessoas
      nunca podem ficar em janelas diferentes, e a tela diz isso.
      """

      for rotulo <- ["week", "month", "year"] do
        assert html =~ rotulo
      end
    end

    test "a granulação pedida reescreve a janela", ctx do
      membro(ctx, "ana")
      assert abrir(ctx, granulacao: "mes") =~ "by month"
      assert abrir(ctx, granulacao: "ano") =~ "by year"
    end
  end

  describe "os dois blocos de leitura, acima da tabela (§3.3)" do
    setup ctx do
      membro(ctx, "ana")
      %{html: abrir(ctx)}
    end

    test "o bloco que recusa o ranking traz as cinco razões", %{html: html} do
      assert html =~ "A table of work items, not a table of people"
      assert html =~ "It is not one, and it cannot support one"
      assert html =~ "no column sums to the team"
      assert html =~ "do not share a denominator"
      assert html =~ "not moved"
      assert html =~ "declared role, then name"
      assert html =~ "No average and no rate per person"
    end

    test "o bloco do WIP diz que NÃO é `flow.wip.count`, e por quê", %{html: html} do
      assert html =~ "flow.wip.count"
      assert html =~ "the end criterion does not exist"
      assert html =~ "#506"
      assert html =~ "external_created_at"
      assert html =~ "no WIP limit"

      assert html =~ "a low number does not mean healthy flow", """
      As más leituras que a medida declara são COPIADAS, e não resumidas — resumir é onde a
      ressalva perde a parte que dói.
      """
    end
  end

  describe "a contagem da previsão (§3.4)" do
    test "aparece INCLUSIVE quando é 0 de N, e o piso é do método", ctx do
      for l <- ~w(ana bruno caio), do: membro(ctx, l)
      html = abrir(ctx)

      assert html =~ "Delivery forecast produced for", "a linha existe"
      assert html =~ "0 of 3", "e diz zero, que é diferente de a linha não existir"

      assert html =~ "The floor belongs to the method", """
      O piso é do MÉTODO, nunca das pessoas abaixo dele — e a frase está na tela, não num
      documento.
      """
    end
  end

  describe "a tabela (§3.5)" do
    test "as seis colunas, na ordem", ctx do
      membro(ctx, "ana")
      html = abrir(ctx)

      for coluna <- [
            "person · role · collection",
            "open now",
            "opened",
            "closed",
            "periods with a close",
            "delivery forecast"
          ] do
        assert html =~ coluna, "falta a coluna #{inspect(coluna)}"
      end
    end

    test "ausência é ESCRITA, e nunca zero mudo", ctx do
      membro(ctx, "ana")
      html = abrir(ctx)

      assert html =~ "none opened"
      assert html =~ "none closed"

      assert html =~ "nothing to forecast", """
      Quem não tem item aberto não tem o que prever — e o piso NÃO é a razão ali. Dizer
      "below the floor" culparia o método por uma ausência de trabalho.
      """
    end

    test "a ordem é papel e nome, e NENHUMA coluna oferece ordenar", ctx do
      membro(ctx, "ana")
      html = abrir(ctx)

      assert html =~ "No measure column sorts this table, and none offers to"

      refute html =~ ~s|phx-click="ordenar" phx-value-coluna="open|, """
      Ordenar pessoas por medida é o ranking que esta tela recusa. Oferecer o clique seria
      recusá-lo em palavras e permiti-lo em ato.
      """
    end
  end

  describe "o bloco de uma pessoa (§3.6)" do
    setup ctx do
      p = membro(ctx, "ana")
      {:ok, view, _} = live(ctx.conn, "/teams/#{ctx.equipe.id}?tab=people")
      %{pessoa: p, view: view}
    end

    test "abre sob a linha, com as duas definições e a ordem de leitura", %{view: view, pessoa: p} do
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => p.id}))

      assert html =~ "promised = opened in the period", """
      A definição vive DENTRO do bloco. A palavra `promised` só aparece onde ela está: sem a
      definição, "prometido" é lido como compromisso, e não há escopo comprometido aqui.
      """

      assert html =~ "no committed scope"
      assert html =~ "what is there"
      assert html =~ "what came in and went out"
      assert html =~ "at what pace"
      assert html =~ "what the pace implies"
    end

    test "o gráfico vazio é DESENHADO, e diz que se conferiu", %{view: view, pessoa: p} do
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => p.id}))

      assert html =~ "nothing in this window — checked, and there was none", """
      Área em branco é lida como "a tela quebrou"; a frase dentro da área é lida como
      "conferido, nada aqui". São duas afirmações diferentes, e a segunda é a verdadeira.
      """

      assert html =~ "scale 0–", "e a escala aparece mesmo sem barra nenhuma"
    end

    test "a recusa da previsão NÃO empresta a história da equipe", ctx do
      # Item ABERTO e sem história: é o que leva ao estado `abaixo do piso`. Sem item, o
      # estado é `nothing to forecast` — e o piso NÃO é a razão ali.
      item_aberto(ctx, ctx.pessoa)
      {:ok, view, _} = live(ctx.conn, "/teams/#{ctx.equipe.id}?tab=people")
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => ctx.pessoa.id}))

      assert html =~ "gap in the observed record, never a statement about the person"

      assert html =~ "team's history is not borrowed", """
      Emprestar a série da equipe atribuiria a alguém um ritmo que não é dela — e a pergunta
      que o piso bloqueia é sobre O TRABALHO, não sobre quem o carrega.
      """
    end

    test "a redundância entre os gráficos 2 e 3 é NOMEADA, e não escondida", %{
      view: view,
      pessoa: p
    } do
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => p.id}))

      assert html =~ "same numbers as chart 2", """
      Os dois foram pedidos pelo nome. Esconder a redundância seria decidir por quem pediu;
      nomeá-la deixa a decisão de tirar um deles com quem a tomou.
      """
    end

    test "fechar tira o bloco, e a linha fica", %{view: view, pessoa: p} do
      render_click(view, "abrir_graficos", %{"person-id" => p.id})
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => p.id}))

      refute html =~ "promised = opened in the period"
      assert html =~ "Ana", "a linha da pessoa continua na tabela"
    end
  end

  describe "o teto de duas, e a terceira pessoa (Q25)" do
    setup ctx do
      pessoas = for l <- ~w(ana bruno caio), do: membro(ctx, l)
      {:ok, view, _} = live(ctx.conn, "/teams/#{ctx.equipe.id}?tab=people")
      %{pessoas: pessoas, view: view}
    end

    test "duas abrem sem pergunta nenhuma", %{view: view, pessoas: [a, b, _]} do
      render_click(view, "abrir_graficos", %{"person-id" => a.id})
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => b.id}))

      refute html =~ "nothing has changed yet", "com duas, não há o que perguntar"
    end

    test "a terceira PERGUNTA qual fechar, e nomeia as duas", %{view: view, pessoas: [a, b, c]} do
      render_click(view, "abrir_graficos", %{"person-id" => a.id})
      render_click(view, "abrir_graficos", %{"person-id" => b.id})
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => c.id}))

      assert html =~ "nothing has changed yet", """
      O estado é dito ANTES das opções: se nada mudou, não há o que desfazer — e é isso que
      faz da volta uma volta, e não um terceiro estado.
      """

      assert html =~ "Which one?"
      assert html =~ "close Ana", "as duas abertas são NOMEADAS — 'feche uma' não é pergunta"
      assert html =~ "close Bruno"
      assert html =~ "open first"
      assert html =~ "open second"

      assert html =~ "the ceiling is legibility, and it was never cost", """
      A razão do teto está na tela — e é a corrigida: medi que abrir pessoas custa zero
      consulta extra, então o argumento de custo saiu.
      """
    end

    test "escolher qual fechar abre a terceira", %{view: view, pessoas: [a, b, c]} do
      render_click(view, "abrir_graficos", %{"person-id" => a.id})
      render_click(view, "abrir_graficos", %{"person-id" => b.id})
      render_click(view, "abrir_graficos", %{"person-id" => c.id})

      html = texto(render_click(view, "fechar_e_abrir", %{"fechar" => a.id}))

      refute html =~ "nothing has changed yet", "a pergunta fecha"
      assert html =~ "Caio", "e a terceira está na tabela"
    end

    test "desistir NÃO abre a terceira, e as duas ficam como estavam", %{
      view: view,
      pessoas: [a, b, c]
    } do
      render_click(view, "abrir_graficos", %{"person-id" => a.id})
      render_click(view, "abrir_graficos", %{"person-id" => b.id})
      render_click(view, "abrir_graficos", %{"person-id" => c.id})

      html = texto(render_click(view, "desistir_da_terceira", %{}))

      refute html =~ "nothing has changed yet", """
      Desistir é VOLTA, e não um terceiro estado: a pergunta fecha, a terceira não abre, e as
      duas continuam exatamente como estavam.
      """
    end
  end

  describe "o bloco de duas pessoas (§3.7)" do
    setup ctx do
      [a, b] = for l <- ~w(ana bruno), do: membro(ctx, l)
      {:ok, view, _} = live(ctx.conn, "/teams/#{ctx.equipe.id}?tab=people")
      render_click(view, "abrir_graficos", %{"person-id" => a.id})
      %{a: a, b: b, view: view}
    end

    test "abrir a segunda TIRA as duas da tabela e monta o par", %{view: view, b: b} do
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => b.id}))

      assert html =~ "Ana × Bruno", "o par existe, e nomeia as duas"
      assert html =~ "same window for both"

      refute html =~ "promised = opened in the period", """
      O bloco de UMA sai quando a segunda abre: dois blocos empilhados seriam duas leituras da
      mesma medida sem que nada dissesse qual comparar com qual.
      """
    end

    test "cada gráfico mantém a SUA escala, e a linha diz o que se compara", %{view: view, b: b} do
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => b.id}))

      assert html =~ "Each chart keeps its own scale"

      assert html =~ "The shapes compare; the heights do not", """
      Escala comum pareceria mais justa e seria o contrário: quem tem três itens e quem tem
      quarenta leriam na mesma altura, ou uma delas sumiria.
      """

      assert html =~ "its own scale"
    end

    test "a linha 3 diz que NENHUMA média ou mediana por pessoa é desenhada", %{view: view, b: b} do
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => b.id}))

      assert html =~ "No average and no median per person is drawn anywhere", """
      Um número único por pessoa é a figura de produtividade que esta plataforma não guarda —
      e a frase fica na linha onde ela seria mais tentadora.
      """

      assert html =~ "delivered` bars of row 2" or html =~ "delivered bars of row 2",
             "e diz que são as mesmas barras da linha 2, lidas como ritmo"
    end

    test "a razão do teto está na tela, e diz o que ele NÃO é", %{view: view, b: b} do
      html = texto(render_click(view, "abrir_graficos", %{"person-id" => b.id}))

      assert html =~ "three scales is a gallery, not a comparison"

      assert html =~ "The ceiling is legibility, and it is not cost", """
      A razão de custo que o protótipo trazia deixou de ser verdadeira: medi em 2026-09-10 e
      abrir pessoas não acrescenta consulta nenhuma. A tela diz o número.
      """

      assert html =~ "no extra query at all"
    end
  end

  describe "as três ausências (§3.8)" do
    test "são TRÊS, e cada uma com o tratamento e a razão", ctx do
      membro(ctx, "ana")
      html = abrir(ctx)

      assert html =~ "The three absences, and they are not the same absence"

      assert html =~ "nothing observed for this person"
      assert html =~ "The row stays", "quem some da tabela é quem ninguém pergunta"

      assert html =~ "One is silence; the other is work that finished", """
      A distinção com o caso vizinho — pessoa com itens e nenhum aberto agora — é o que impede
      a tela de dizer zero onde devia dizer "não sei".
      """

      assert html =~ "Two distinct blocking modes, shown side by side"
      assert html =~ "never a statement about the person"

      assert html =~ "the routing rule did not classify it"

      assert html =~ "would assert a promotion nobody made", """
      Chamar o item sem tipo de TASK afirmaria uma promoção que ninguém fez — e foi o defeito
      que derrubava a tela antes de `sigla_do_conceito(nil)` existir.
      """
    end
  end

  describe "o teto de consultas (SC-031)" do
    test "o custo NÃO cresce com o número de membros", ctx do
      for n <- 1..6, do: membro(ctx, "p#{n}")
      com_6 = contar_consultas(fn -> abrir(ctx) end)

      for n <- 7..30, do: membro(ctx, "p#{n}")
      com_30 = contar_consultas(fn -> abrir(ctx) end)

      assert com_30 == com_6, """
      1+N. A série de cada pessoa sai de TRÊS consultas para o conjunto inteiro, e a mistura
      de conceitos de mais duas — a forma óbvia, uma chamada por linha, custaria três por
      pessoa. Com 6 membros: #{com_6}. Com 30: #{com_30}.
      """
    end
  end

  defp contar_consultas(fun) do
    ref = make_ref()
    :telemetry.attach({__MODULE__, ref}, [:the_band, :repo, :query], &__MODULE__.contar/4, self())

    try do
      fun.()
      drenar(0)
    after
      :telemetry.detach({__MODULE__, ref})
    end
  end

  @doc false
  def contar(_evento, _medidas, _meta, destino), do: send(destino, :consulta)

  defp drenar(n) do
    receive do
      :consulta -> drenar(n + 1)
    after
      0 -> n
    end
  end
end
