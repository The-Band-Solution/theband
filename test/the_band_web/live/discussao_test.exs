defmodule TheBandWeb.DiscussaoTest do
  @moduledoc """
  A discussão na tela — feature 030, FR-003 e FR-004.

  ## As asserções que carregam este arquivo

  1. **os dois vazios são frases diferentes**: "não coletada" e "coletada e sem
     comentários" dizem coisas opostas sobre a origem (L57);
  2. autor sem pessoa coletada aparece em texto, nunca como ligação (FR-007);
  3. **o sinal "parada" tem três diagnósticos**, e eles pedem ações opostas — foi o
     defeito que motivou a feature: silêncio e conversa ativa produziam a mesma linha.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Communication.Commands
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      repo_id: cenario.observed_repository_id
    }
  end

  defp pessoa(tenant, login, nome) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: nome,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{}
      })

    p
  end

  defp issue(ctx, numero, attrs \\ %{}) do
    {:ok, i} =
      WorkItems.record_collected_issue(
        ctx.tenant,
        Map.merge(
          %{
            observed_repository_id: ctx.repo_id,
            number: numero,
            title: "issue #{numero}",
            state: "OPEN",
            issue_type: "Task",
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "I_#{numero}"
          },
          attrs
        )
      )

    i
  end

  defp comentar(ctx, issue, autor_login, person_id, quando) do
    {:ok, c} =
      Commands.record_comment(ctx.tenant, %{
        collected_issue_id: issue.id,
        body: "o que foi dito",
        author_login: autor_login,
        author_person_id: person_id,
        external_published_at: quando,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "C_#{issue.number}_#{DateTime.to_unix(quando, :microsecond)}"
      })

    c
  end

  # Parada de verdade: aberta há 200 dias e designada — os dois critérios do stale_open.
  defp parada(ctx, numero) do
    antiga = DateTime.add(DateTime.utc_now(:second), -200, :day)
    i = issue(ctx, numero, %{external_created_at: antiga})

    {:ok, _} =
      WorkItems.replace_assignees(ctx.tenant, i.id, [
        %{login: ctx.pessoa.login, person_id: ctx.pessoa.id}
      ])

    i
  end

  defp marcar_coletado(ctx) do
    Repo.update_all(
      from(r in "observed_repositories",
        where: r.id == type(^ctx.repo_id, :binary_id)
      ),
      set: [comments_collected_at: DateTime.utc_now(:second)]
    )
  end

  describe "a discussão no detalhe da issue" do
    test "não coletada e coletada-sem-comentários são frases DIFERENTES", ctx do
      i = issue(ctx, 8001)

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{i.id}")

      assert html =~ "No discussion has been collected for this repository yet",
             "a tela afirmou silêncio onde a coleta nunca passou"

      refute html =~ "this issue has no comments"

      marcar_coletado(ctx)

      {:ok, _live, html2} = live(ctx.conn, ~p"/work/issues/#{i.id}")

      assert html2 =~ "Collected, and this issue has no comments",
             """
             Depois da coleta, a tela continuou dizendo "não coletada".

             "Olhei e não achei" e "não olhei" são fatos diferentes, e usar a mesma frase
             para os dois é o defeito que a L57 descreve.
             """
    end

    test "o comentário aparece com o NOME de quem escreveu, e o login solto sem link", ctx do
      marcar_coletado(ctx)
      ana = pessoa(ctx.tenant, "ana-login", "Ana Coletada")
      i = issue(ctx, 8002)

      comentar(ctx, i, "ana-login", ana.id, ~U[2026-06-01 10:00:00Z])
      comentar(ctx, i, "quem-saiu", nil, ~U[2026-06-02 10:00:00Z])

      {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{i.id}")

      assert html =~ "Ana Coletada", "mostrou o login onde o nome existe"
      assert html =~ ~s{href="/people/#{ana.id}"}
      assert html =~ "o que foi dito"

      assert html =~ "quem-saiu"
      assert html =~ "person not collected"

      refute html =~ ~r{<a[^>]*href="/people/[^"]+"[^>]*>\s*quem-saiu},
             "login sem pessoa coletada virou ligação que não leva a lugar nenhum"
    end
  end

  describe "o sinal parada, com resolução" do
    setup ctx do
      pessoa = pessoa(ctx.tenant, "quem-trabalha", "Quem Trabalha")
      %{pessoa: pessoa}
    end

    test "silêncio, conversa antiga e conversa recente são três rótulos", ctx do
      marcar_coletado(ctx)

      _silenciosa = parada(ctx, 8101)
      antiga = parada(ctx, 8102)
      recente = parada(ctx, 8103)

      comentar(
        ctx,
        antiga,
        ctx.pessoa.login,
        ctx.pessoa.id,
        DateTime.add(DateTime.utc_now(:second), -150, :day)
      )

      comentar(
        ctx,
        recente,
        ctx.pessoa.login,
        ctx.pessoa.id,
        DateTime.add(DateTime.utc_now(:second), -3, :day)
      )

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "never discussed", "a parada sem conversa não foi rotulada"
      assert html =~ "decide whether it dies or comes back"

      assert html =~ "stale discussion", "a parada com conversa antiga não foi rotulada"
      assert html =~ "discussed, then left"

      assert html =~ "active discussion",
             """
             A parada com conversa RECENTE saiu com o mesmo rótulo das outras.

             É o defeito que a feature existe para resolver: "parada há 90 dias" era a
             mesma frase para a issue abandonada em silêncio e para a que tem discussão
             ativa — e as duas pedem ações opostas.
             """

      assert html =~ "the work is alive; the record is not"
    end

    test "participação aparece para quem NÃO tem designação alguma — o achado da feature", ctx do
      # Sete das 24 pessoas sem designação do tenant real trabalham na conversa
      # (lucasbruno-devdog: 72 comentários em 50 discussões). Sem esta seção, elas eram
      # pessoas sem trabalho registrado na plataforma.
      marcar_coletado(ctx)
      i = issue(ctx, 8301)

      comentar(ctx, i, ctx.pessoa.login, ctx.pessoa.id, ~U[2026-06-01 10:00:00Z])
      comentar(ctx, i, ctx.pessoa.login, ctx.pessoa.id, ~U[2026-07-01 10:00:00Z])

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Discussions they took part in"
      assert html =~ "issue 8301", "a discussão não apareceu para quem não tem designação"
      assert html =~ "2×", "a contagem de atos não apareceu"

      assert html =~ "derived — counted from collected comments",
             "a participação apareceu sem a marca de derivada"

      assert html =~ "not</strong>\n                a completed task" or
               html =~ "a completed task",
             "faltou a frase que impede ler participação como execução"
    end

    test "sem comentário coletado, a ausência é nomeada — nunca seção vazia", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "No comment by this person has been collected"

      assert html =~ "Either they work through other",
             "a ausência não disse o que ela pode significar"
    end

    test "sem coleta de comentários, silêncio NÃO é afirmado", ctx do
      parada(ctx, 8201)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "discussion not collected"

      assert html =~ "silence here is not evidence",
             "a ausência de coleta virou afirmação de silêncio"

      refute html =~ "nobody has commented on it"
    end
  end
end
