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

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, equipe: equipe, papel: papel}
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
    |> String.replace(~r/\s+/, " ")
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
