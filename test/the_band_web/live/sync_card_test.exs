defmodule TheBandWeb.SyncCardTest do
  @moduledoc """
  O cartão de execução em `/sincronizacoes` (reorganização pedida em 2026-08-11).

  O teste que mais importa aqui é o das **chaves das fases**. A lista de fases da tela e
  as chaves que a coleta grava no checkpoint são dois lugares, e elas divergiram: a tela
  dizia `github.organization_members` e `github.teams`, a ingestão grava `github.user` e
  `github.team`.

  O efeito era silencioso e errado: as barras de pessoas e equipes ficavam eternamente
  pendentes, com contagem zero, sobre 67 pessoas e 8 equipes **que tinham sido
  coletadas**. Ausência virando zero, na tela.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ingestion
  alias TheBand.Ontology.KnowledgeBase

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    {:ok, sync} = Ingestion.start_sync(tenant, cenario.tool)

    %{conn: log_in(conn, user), tenant: tenant, sync: sync, cenario: cenario}
  end

  describe "as fases" do
    test "cada chave da tela corresponde a uma que a coleta grava",
         %{conn: conn, sync: sync} do
      # As chaves reais, medidas numa coleta da organização `leds-conectafapes`.
      for {entidade, quantos} <- [
            {"github.organization", 1},
            {"github.user", 67},
            {"github.team", 8},
            {"github.team_member:dados", 4},
            {"github.team_member:ia", 7},
            {"github.repository", 121},
            {"github.issue", 3383},
            {"promocao", 4474}
          ] do
        Ingestion.checkpoint_page(sync, entidade, nil, quantos)
      end

      {:ok, _live, html} = live(conn, ~p"/sincronizacoes")

      # Pessoas e equipes precisam mostrar o que foi coletado. Antes da correção, as duas
      # apareciam pendentes com zero.
      assert html =~ "people"
      assert html =~ ">67<"
      assert html =~ "teams"
      assert html =~ ">8<"
    end

    test "vínculos de equipe somam os checkpoints por prefixo, e não entram em equipes",
         %{conn: conn, sync: sync} do
      Ingestion.checkpoint_page(sync, "github.team", nil, 8)
      Ingestion.checkpoint_page(sync, "github.team_member:dados", nil, 4)
      Ingestion.checkpoint_page(sync, "github.team_member:ia", nil, 7)

      {:ok, _live, html} = live(conn, ~p"/sincronizacoes")

      assert html =~ "team links"
      assert html =~ ">11<"

      # `String.starts_with?` puro casaria `github.team_member` dentro de `github.team`, e
      # a contagem de equipes viraria 19.
      refute html =~ ">19<"
    end

    test "fase sem checkpoint mostra travessão, e zero mostra zero",
         %{conn: conn, sync: sync} do
      Ingestion.checkpoint_page(sync, "github.organization", nil, 1)
      Ingestion.checkpoint_page(sync, "github.user", nil, 0)

      {:ok, _live, html} = live(conn, ~p"/sincronizacoes")

      # "não executou" e "executou e não achou nada" são coisas diferentes, e a tela diz
      # coisas diferentes para as duas.
      assert html =~ "—"
      assert html =~ ">0<"
    end
  end

  describe "a organização dos números" do
    test "os três grupos existem, e cada um responde uma pergunta", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/sincronizacoes")

      assert html =~ "what the run did"
      assert html =~ "the work it brought"
      assert html =~ "what went unanswered"
    end

    test "a explicação da lacuna fica junto do número que ela explica", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/sincronizacoes")

      [grupo] =
        Regex.scan(~r{what went unanswered.*?</div>\s*</div>}s, html) |> Enum.map(&hd/1)

      assert grupo =~ "links with no role"
      assert grupo =~ "A knowledge gap, not an error"
    end
  end
end
