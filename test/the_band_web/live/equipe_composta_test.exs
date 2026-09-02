defmodule TheBandWeb.EquipeCompostaTest do
  @moduledoc """
  Feature 057, US2 — a equipe composta mostra suas equipes, uma a uma.

  As asserções que carregam este arquivo:

  1. **FR-007**: uma linha por subequipe, mais a dos membros diretos;
  2. **FR-008/SC-003**: **nenhuma célula de total** — e a varredura procura pelas
     palavras que um total teria;
  3. **FR-009**: a tela **diz por que** não soma, nomeando pessoa e tarefa;
  4. **FR-010**: cada linha leva à tela daquela subequipe;
  5. **FR-011**: **nenhum gráfico** aqui;
  6. **FR-012**: subequipe sem trabalho aparece **nomeada**, nunca com zero;
  7. **SC-005**: a ordem é por trabalho parado, e não alfabética;
  8. **FR-013**: composição encerrada não aparece;
  9. **SC-012**: ver não exige administrar.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.DataCase, only: [user_fixture: 2]
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    org = cenario.organization
    {:ok, mae} = EO.declare_structural_team(tenant, org.id, "Plataforma", admin.id)
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      org: org,
      mae: mae,
      papel: papel,
      repo_id: cenario.observed_repository_id
    }
  end

  defp subequipe(ctx, nome) do
    {:ok, filha} = EO.declare_structural_team(ctx.tenant, ctx.org.id, nome, ctx.admin.id)
    {:ok, _} = EO.compose_teams(ctx.tenant, filha.id, ctx.mae.id, ctx.admin.id)
    filha
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

  defp vincular(ctx, equipe, pessoa) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: ctx.papel.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -300, :day)
      })
  end

  defp issue(ctx, externo, designados, dias_atras) do
    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 100_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "issue #{externo}",
        state: "OPEN",
        external_created_at: DateTime.add(DateTime.utc_now(:second), -dias_atras, :day),
        collected_at: DateTime.utc_now(:second)
      })

    for d <- designados do
      Repo.insert!(%IssueAssignee{
        tenant_id: ctx.tenant.id,
        collected_issue_id: i.id,
        login: d.login,
        person_id: d.id
      })
    end

    i
  end

  describe "a tela da equipe composta" do
    setup ctx do
      dados = subequipe(ctx, "Dados")
      interface = subequipe(ctx, "Interface")

      ana = pessoa(ctx, "ana")
      bia = pessoa(ctx, "bia")
      vincular(ctx, dados, ana)
      vincular(ctx, interface, bia)

      # Dados tem trabalho parado; Interface tem trabalho recente.
      issue(ctx, "velha", [ana], 120)
      issue(ctx, "outra-velha", [ana], 100)
      issue(ctx, "nova", [bia], 3)

      Map.merge(ctx, %{dados: dados, interface: interface, ana: ana, bia: bia})
    end

    test "FR-007/FR-010: uma linha por subequipe, mais a dos diretos, e cada uma leva à sua tela",
         ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      assert html =~ "Teams inside this one"
      assert html =~ "Dados"
      assert html =~ "Interface"
      assert html =~ "direct members"
      assert html =~ ~s|/teams/#{ctx.dados.id}|
      assert html =~ ~s|/teams/#{ctx.interface.id}|
    end

    test "FR-008/SC-003: nenhuma célula de total", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      cabecalhos =
        Regex.scan(~r|<th[^>]*>(.*?)</th>|s, html)
        |> Enum.map(&(&1 |> List.last() |> String.downcase()))

      for proibido <- ~w(total sum combined overall aggregate) do
        refute Enum.any?(cabecalhos, &String.contains?(&1, proibido)),
               "a tela tem um cabeçalho com #{proibido} — somar as linhas contaria a mesma pessoa e a mesma tarefa duas vezes"
      end
    end

    test "FR-009: a tela diz por que não soma, nomeando pessoa e tarefa", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      assert html =~ "why these rows are not added up"
      assert html =~ "two sub-teams"
      assert html =~ "same task"
    end

    test "FR-011: nenhum gráfico nesta tela", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      refute html =~ "<svg",
             "gráfico aqui contraria a decisão: a tela composta é para comparar, e comparação se faz em números alinhados"
    end

    test "SC-005: a ordem é por trabalho parado, e não alfabética", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      pos_dados = :binary.match(html, "/teams/#{ctx.dados.id}") |> elem(0)
      pos_interface = :binary.match(html, "/teams/#{ctx.interface.id}") |> elem(0)

      assert pos_dados < pos_interface,
             "Dados tem 2 tarefas paradas e Interface nenhuma — sem a ordem declarada, achar a que precisa de conversa depende de sorte na ordem alfabética"
    end

    test "FR-012: subequipe sem trabalho aparece nomeada, nunca com zero", ctx do
      vazia = subequipe(ctx, "Integrações")
      carlos = pessoa(ctx, "carlos")
      vincular(ctx, vazia, carlos)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      assert html =~ "Integrações"
      assert html =~ "No work observed in the period"
      assert html =~ "not the same as zero"
    end

    test "SC-012: ver não exige administrar", ctx do
      leitor = user_fixture(ctx.tenant, "member")

      {:ok, _view, html} = live(log_in(build_conn(), leitor), ~p"/teams/#{ctx.mae.id}")

      assert html =~ "Teams inside this one"
      assert html =~ "Dados"
    end
  end

  describe "quando a equipe não é composta" do
    test "com nenhuma parte, a seção não existe", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      refute html =~ "Teams inside this one"
    end

    test "com UMA parte só, segue como equipe simples", ctx do
      subequipe(ctx, "Dados")

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      refute html =~ "Teams inside this one",
             "comparar uma linha com nada não é comparação — uma parte só é composição declarada, não equipe composta"

      assert html =~ "Contains:"
    end

    test "FR-013: composição encerrada não faz a equipe ser composta", ctx do
      dados = subequipe(ctx, "Dados")
      interface = subequipe(ctx, "Interface")
      {:ok, _} = EO.decompose_teams(ctx.tenant, interface.id, ctx.mae.id, ctx.admin.id)

      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.mae.id}")

      refute html =~ "Teams inside this one"
      refute html =~ ~s|/teams/#{interface.id}|
      assert html =~ ~s|/teams/#{dados.id}|
    end
  end
end
