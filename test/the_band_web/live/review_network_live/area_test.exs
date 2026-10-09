defmodule TheBandWeb.ReviewNetworkLive.AreaTest do
  @moduledoc """
  A rede de revisão da 073 como primeira página da área Network analysis, e o endereço antigo —
  feature 076, T020 (FR-003; US1, cen. 2 e 3; R13 da segurança, A13).

  - na área, a página mostra os mesmos números que `ReviewNetwork.read/4` dá para a mesma janela;
  - o endereço antigo leva à área com o id validado e **só** a janela da lista: nada da query
    original atravessa (A13, redirecionamento aberto);
  - organização de outro tenant, inexistente e id malformado dão o mesmo *"Not found."*.
  """
  use TheBandWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TheBand.ReviewNetworkFixtures

  alias TheBand.ReviewNetwork

  defp dias_atras(n), do: DateTime.add(DateTime.utc_now(:second), -n * 86_400, :second)

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organizacao_com_repositorio(tenant)
    repo = org.observed_repository_id

    ana = pessoa(tenant, "Ana")
    bia = pessoa(tenant, "Bia")
    ciro = pessoa(tenant, "Ciro")

    for {revisor, autor, vezes} <- [{ana, bia, 5}, {ciro, bia, 3}, {bia, ana, 2}],
        i <- 1..vezes do
      cr = solicitacao(tenant, repo, autor, dias_atras(20 + i))
      revisao(tenant, cr, revisor, dias_atras(19 + i))
    end

    {:ok, _} = ReviewNetwork.compute(tenant, org.organization, DateTime.utc_now(:second))

    %{conn: conn, tenant: tenant, admin: admin, org: org}
  end

  defp texto(html, seletor) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(seletor)
    |> LazyHTML.text()
    |> String.replace(~r/\s+/, " ")
  end

  test "na área, os mesmos números da 073 para a mesma janela", ctx do
    id = ctx.org.organization.id
    {:ok, visao} = ReviewNetwork.read(ctx.tenant, ctx.admin, id, 90)
    {:ok, revisoes} = visao.reviews
    {:ok, revisores} = visao.reviewers
    {:ok, revisados} = visao.authors

    assert revisoes == 10

    {:ok, _view, html} = live(log_in(ctx.conn, ctx.admin), ~p"/network-analysis/#{id}?window=90")

    contagens =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#contagens dd span.text-lg")
      |> Enum.map(&LazyHTML.text/1)
      |> Enum.map(&String.trim/1)

    assert contagens == Enum.map([revisoes, revisores, revisados], &Integer.to_string/1)

    # A página fica dentro da área: as seis páginas acima, a rede de revisão marcada.
    assert texto(html, ~s(#area-network-analysis a[aria-current="page"])) =~ "Review network"
    assert texto(html, "#review-network") =~ "Is code review concentrated in a few people?"
  end

  # 3.0.3 (T053): quem escolheu a designação e passa pela página da 073 volta à designação. Valor
  # fora da lista da base não é repetido em link nenhum.
  test "a rede escolhida atravessa a página da 073, e valor fora da lista não", ctx do
    id = ctx.org.organization.id
    conn = log_in(ctx.conn, ctx.admin)

    {:ok, _view, html} = live(conn, ~p"/network-analysis/#{id}?window=90&network=assignment")

    hrefs =
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#area-network-analysis a")
      |> LazyHTML.attribute("href")

    assert Enum.all?(hrefs, &(&1 =~ "network=assignment"))

    {:ok, _view, html} = live(conn, ~p"/network-analysis/#{id}?window=90&network=xss%3Cb%3E")
    refute html =~ "xss"
  end

  test "o endereço antigo leva à área, só com a janela da lista (A13)", ctx do
    id = ctx.org.organization.id
    conn = log_in(ctx.conn, ctx.admin)

    assert {:error, {:live_redirect, %{to: destino}}} =
             live(
               conn,
               "/organizations/#{id}/review-network?window=90&return_to=https://exemplo.invalid"
             )

    assert destino == "/network-analysis/#{id}?window=90"
    refute destino =~ "exemplo.invalid"
    refute destino =~ "return_to"

    assert {:error, {:live_redirect, %{to: "/network-analysis/" <> _ = trinta}}} =
             live(conn, "/organizations/#{id}/review-network?window=30")

    assert trinta == "/network-analysis/#{id}?window=30"

    # Janela fora da lista: a padrão, sem dizer que era inválida.
    for janela <- ["36500", "90;drop", "090", String.duplicate("9", 10_000)] do
      assert {:error, {:live_redirect, %{to: padrao}}} =
               live(
                 conn,
                 "/organizations/#{id}/review-network?window=#{URI.encode_www_form(janela)}"
               )

      assert padrao == "/network-analysis/#{id}?window=90"
    end
  end

  test "outro tenant, inexistente e id malformado dão o mesmo Not found, nos dois endereços",
       ctx do
    {outro, _} = tenant_with_admin()
    de_fora = organizacao_com_repositorio(outro)
    conn = log_in(ctx.conn, ctx.admin)

    respostas =
      for id <- [de_fora.organization.id, Ecto.UUID.generate(), "abc"],
          caminho <- ["/organizations/#{id}/review-network", "/network-analysis/#{id}"] do
        assert {:error, {:live_redirect, %{to: "/network-analysis", flash: flash}}} =
                 live(conn, caminho)

        flash
      end

    assert Enum.uniq(respostas) == [%{"error" => "Not found."}]
    refute inspect(respostas) =~ ~r/permission/i
  end
end
