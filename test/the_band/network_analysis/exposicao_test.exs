defmodule TheBand.NetworkAnalysis.ExposicaoTest do
  @moduledoc """
  A análise de rede não sai da área — feature 076, T051 (FR-053; R12 e A17 de `seguranca.md`).

  Desde a T028 as leituras são gravadas em `development`, e por isso esta guarda vem antes das
  páginas que faltam: protege uma superfície que já existe.

  - toda rota sob `/network-analysis` é `live`: nenhuma rota de controlador entrega imagem, CSV,
    JSON nem HTML exportável da análise;
  - nenhuma rota de `/api`, nenhuma ferramenta MCP, nenhum controlador de `api/` e nenhum módulo
    de `profiles/` fala da análise nem da tabela das leituras. Exposição futura é spec própria, e
    passa pela mesma função recortada (`NetworkAnalysis.read/4`);
  - o HTML das páginas da área não tem `download`, `Content-Disposition` nem botão de exportar.

  O código é lido **sem comentários**, para que uma frase que explique a proibição não reprove o
  teste (memória *guarda que lê código reprova a prosa*).

  **Defeito a injetar**: uma rota `get "/network-analysis/:id/graph.svg"`; o primeiro caso reprova.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.ReviewNetworkFixtures

  alias TheBand.MCP.Ferramentas
  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.Ontology.KnowledgeBase
  alias TheBandWeb.NetworkAnalysisLive.Shared

  @proibido ~r/NetworkAnalysis|network_analysis_readings|network[_-]analysis/i

  test "toda rota da área é live, e nenhuma é de controlador" do
    rotas =
      for r <- Phoenix.Router.routes(TheBandWeb.Router),
          String.starts_with?(r.path, "/network-analysis"),
          do: r

    assert length(rotas) >= 3, "o teste precisa ver as rotas da área para provar alguma coisa"

    for r <- rotas do
      assert r.plug == Phoenix.LiveView.Plug,
             "#{r.verb} #{r.path} não é live (#{inspect(r.plug)}): a área não exporta (FR-053)"

      assert r.verb == :get
    end
  end

  test "nenhuma rota de /api fala da análise" do
    rotas =
      for r <- Phoenix.Router.routes(TheBandWeb.Router),
          String.starts_with?(r.path, "/api"),
          do: r

    assert rotas != []
    refute Enum.any?(rotas, &(&1.path =~ @proibido or inspect(&1.plug) =~ @proibido))
  end

  test "nenhuma ferramenta MCP fala da análise" do
    ferramentas = Ferramentas.listar()

    assert [_ | _] = ferramentas
    refute Enum.any?(ferramentas, &(&1.nome =~ @proibido or inspect(&1.modulo) =~ @proibido))
  end

  test "o MCP, os controladores da API e o material de perfil não leem a análise" do
    arquivos =
      Path.wildcard("lib/the_band/mcp/**/*.ex") ++
        Path.wildcard("lib/the_band/mcp.ex") ++
        Path.wildcard("lib/the_band_web/controllers/api/**/*.ex") ++
        Path.wildcard("lib/the_band/profiles/**/*.ex") ++
        Path.wildcard("lib/the_band/profiles.ex")

    assert length(arquivos) > 10, "o teste precisa ler os três lugares para provar alguma coisa"

    culpados =
      for arquivo <- arquivos,
          arquivo |> File.read!() |> sem_comentarios() =~ @proibido,
          do: arquivo

    assert culpados == []
  end

  test "o código das páginas da área não oferece download nem exportação" do
    arquivos = Path.wildcard("lib/the_band_web/live/network_analysis_live/**/*.ex")
    assert length(arquivos) >= 4

    culpados =
      for arquivo <- arquivos,
          arquivo |> File.read!() |> sem_comentarios() =~
            ~r/send_download|Content-Disposition|\bdownload=|phx-click="export/i,
          do: arquivo

    assert culpados == []
  end

  describe "o HTML das páginas" do
    setup %{conn: conn} do
      {:ok, _} = KnowledgeBase.load()
      {tenant, admin} = tenant_with_admin()
      %{organization: org} = organizacao_com_repositorio(tenant)
      [ana, bia, caio] = for n <- ~w(Ana Bia Caio), do: pessoa(tenant, "#{n} Exposicao")

      entrada = %{
        edges: [
          %{source: ana.id, target: bia.id, weight: 2},
          %{source: bia.id, target: caio.id, weight: 1}
        ],
        exclusions: %{"issues" => 3},
        people_without_edges: 0,
        source_computed_at: nil,
        provenance: %{}
      }

      {:ok, _, [_ | _]} =
        Commands.compute(
          tenant,
          org,
          DateTime.utc_now(:second),
          Parameters.fetch!(),
          fn _, _, _ -> {:ok, entrada} end
        )

      %{conn: log_in(conn, admin), org: org}
    end

    test "nenhuma página tem download, Content-Disposition nem botão de exportar", ctx do
      caminhos =
        ["/network-analysis"] ++
          for p <- Shared.pages(),
              Shared.available?(p.page),
              do: Shared.page_path(p.page, ctx.org.id, %{network: "assignment", window: 90})

      assert length(caminhos) >= 3

      for caminho <- caminhos do
        html = abrir(ctx.conn, caminho)

        assert html =~ "Network analysis", "#{caminho} não abriu a página da área"
        refute html =~ ~r/\bdownload\b/i, "#{caminho} oferece download"
        refute html =~ ~r/content-disposition/i
        refute html =~ ~r/>\s*export/i, "#{caminho} tem botão de exportar"
      end
    end
  end

  # Com uma organização só, a entrada da área leva direto a ela (T019).
  defp abrir(conn, caminho) do
    case live(conn, caminho) do
      {:ok, _view, html} ->
        html

      {:error, {:live_redirect, _}} = redirecionado ->
        {:ok, _view, html} = follow_redirect(redirecionado, conn)
        html
    end
  end

  defp sem_comentarios(codigo) do
    codigo
    |> String.split("\n")
    |> Enum.reject(&(String.trim_leading(&1) |> String.starts_with?("#")))
    |> Enum.join("\n")
  end
end
