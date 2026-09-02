defmodule TheBandWeb.DetalheDaSubequipeTest do
  @moduledoc """
  Feature 057, US3/US4/US5/US6 — o detalhe da subequipe.

  As asserções que carregam este arquivo:

  1. **FR-027**: o que resta é a **região** entre as curvas, e não uma terceira
     série — duas `polyline` e um `polygon`, nunca três `polyline`;
  2. **FR-026a**: o acumulado parte da linha de base, e a tela diz o número;
  3. **FR-029/FR-030**: a tela declara que não há escopo comprometido e que
     "fechado" é o ato da ferramenta;
  4. **FR-017/FR-018/FR-021**: todas as tarefas, nenhuma eleita atual, ausência
     dita;
  5. **FR-019/FR-019a**: o tempo conta da abertura, e a tela diz isso;
  6. **FR-033/FR-034/FR-035**: faixa com confiança, recusa explicada, proporção
     de não conclusão — e **nenhuma data**.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    org = cenario.organization
    {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Dados", admin.id)
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      org: org,
      equipe: equipe,
      papel: papel,
      repo_id: cenario.observed_repository_id
    }
  end

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => login}
      })

    p
  end

  defp vincular(ctx, pessoa, opts \\ []) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: ctx.equipe.id,
        organizational_role_id: ctx.papel.id,
        started_at: Keyword.get(opts, :desde, dias(-300))
      })
  end

  defp dias(n), do: DateTime.utc_now(:second) |> DateTime.add(n, :day)

  # O HEEx quebra o texto em linhas, e uma frase da tela chega ao HTML partida por
  # `\n` e indentação. Asserir sobre o HTML cru faria o teste falhar quando alguém
  # só reindentasse o template — o que é ruído, e não regressão.
  defp texto(html) do
    html
    |> String.replace(~r/\s+/, " ")
    |> String.replace("&#39;", "'")
  end

  defp issue(ctx, externo, pessoa, opts) do
    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 100_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "issue #{externo}",
        state: if(opts[:fechada], do: "CLOSED", else: "OPEN"),
        external_created_at: opts[:criada],
        external_closed_at: opts[:fechada],
        collected_at: DateTime.utc_now(:second)
      })

    Repo.insert!(%IssueAssignee{
      tenant_id: ctx.tenant.id,
      collected_issue_id: i.id,
      login: pessoa.login,
      person_id: pessoa.id
    })

    i
  end

  # Uma equipe com histórico suficiente para a previsão existir.
  defp com_historico(ctx) do
    ana = pessoa(ctx, "ana")
    vincular(ctx, ana)

    for n <- 1..16 do
      issue(ctx, "h#{n}", ana, criada: dias(-55 + n * 3), fechada: dias(-53 + n * 3))
    end

    ana
  end

  describe "o burn" do
    test "FR-027: o que resta é a faixa entre as curvas, e não uma terceira linha", ctx do
      com_historico(ctx)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert length(Regex.scan(~r/<polyline/, html)) == 2,
             "três polyline significaria o que resta desenhado como série própria"

      assert html =~ "<polygon"
      assert html =~ "burn-hachura"
    end

    test "FR-026a: a tela diz de onde o acumulado parte", ctx do
      ana = com_historico(ctx)
      for n <- 1..7, do: issue(ctx, "velha#{n}", ana, criada: dias(-200), fechada: nil)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      t = texto(html)
      assert t =~ "the items already open when the window began"
      assert t =~ "Starting from zero would measure only"
    end

    test "FR-029/FR-030: a tela declara o que o burn não responde", ctx do
      com_historico(ctx)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      t = texto(html)
      assert t =~ "no committed scope"
      assert t =~ "does not answer whether a sprint finishes"
      assert t =~ "an act of the tool, not a declared end criterion"
      assert t =~ "A task abandoned and one finished look the same here"
    end

    test "a tabela do burn fecha a identidade em cada semana", ctx do
      com_historico(ctx)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "see as a table"
      assert html =~ "still open"
    end
  end

  describe "a previsão" do
    test "FR-034: sem histórico, recusa e diz o que falta", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ana)
      issue(ctx, "1", ana, criada: dias(-10), fechada: dias(-5))

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      t = texto(html)
      assert t =~ "No forecast yet"
      assert t =~ "weeks of history and"
      assert t =~ "Refusing says more than a number nobody could act on"
    end

    test "FR-033/FR-035: com histórico, faixa com confiança e a proporção", ctx do
      com_historico(ctx)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      t = texto(html)
      assert t =~ "Delivery forecast"
      assert t =~ "if nothing new opened"
      assert t =~ "if work keeps arriving as it has"
      assert t =~ "did not finish"
      assert t =~ "never as a date that was promised"
    end

    test "FR-033: nenhuma data absoluta aparece na previsão", ctx do
      com_historico(ctx)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      trecho =
        html
        |> String.split("Delivery forecast")
        |> Enum.at(1)
        |> String.split("What each person is on")
        |> List.first()

      refute trecho =~ ~r/\d{4}-\d{2}-\d{2}/,
             "uma data absoluta na previsão seria lida como promessa"
    end

    test "a previsão carrega marca de derivada", ctx do
      com_historico(ctx)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert texto(html) =~ "derived — simulated from this team's own history"
    end
  end

  describe "as pessoas" do
    test "FR-017/FR-018: todas as tarefas abertas, nenhuma eleita atual", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ana)
      issue(ctx, "primeira", ana, criada: dias(-20), fechada: nil)
      issue(ctx, "segunda", ana, criada: dias(-5), fechada: nil)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "primeira"
      assert html =~ "segunda"
      refute html =~ "current task"
      refute html =~ "on now"
    end

    test "FR-021: pessoa sem tarefa aparece com a ausência dita", ctx do
      ana = pessoa(ctx, "ana")
      bia = pessoa(ctx, "bia")
      vincular(ctx, ana)
      vincular(ctx, bia)
      issue(ctx, "1", ana, criada: dias(-5), fechada: nil)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "bia"
      assert html =~ "No open task assigned"
    end

    test "FR-020: tarefa parada recebe marca, e a tela diz o que a marca é", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ana)
      issue(ctx, "velha", ana, criada: dias(-95), fechada: nil)
      issue(ctx, "nova", ana, criada: dias(-85), fechada: nil)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      t = texto(html)
      assert t =~ "stale"
      assert t =~ "invitation to ask, not a verdict"
      assert html =~ "95d"
      assert html =~ "85d"
    end

    test "FR-019a: a tela diz que o tempo conta da abertura, não da atribuição", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ana)
      issue(ctx, "1", ana, criada: dias(-5), fechada: nil)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert texto(html) =~ "the source does not record when someone took it on"
    end

    test "FR-025: a tela diz por que as linhas por pessoa não somam", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ana)
      issue(ctx, "1", ana, criada: dias(-5), fechada: nil)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      t = texto(html)
      assert t =~ "appears once for each"
      assert t =~ "Summing these lines would overcount the team"
    end

    test "FR-006: vínculo sem data de início é dito na tela", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ana, desde: nil)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "start date unknown"
      assert html =~ "ana"
    end
  end

  describe "a equipe composta não mostra o detalhe" do
    test "FR-011: com duas subequipes, nenhum gráfico e nenhuma previsão", ctx do
      {:ok, a} = EO.declare_structural_team(ctx.tenant, ctx.org.id, "A", ctx.admin.id)
      {:ok, b} = EO.declare_structural_team(ctx.tenant, ctx.org.id, "B", ctx.admin.id)
      {:ok, _} = EO.compose_teams(ctx.tenant, a.id, ctx.equipe.id, ctx.admin.id)
      {:ok, _} = EO.compose_teams(ctx.tenant, b.id, ctx.equipe.id, ctx.admin.id)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      refute html =~ "<svg"
      refute html =~ "Delivery forecast"
      refute html =~ "What each person is on"
      assert html =~ "Teams inside this one"
    end
  end
end
