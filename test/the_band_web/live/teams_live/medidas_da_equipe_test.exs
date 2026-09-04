defmodule TheBandWeb.TeamsLive.MedidasDaEquipeTest do
  @moduledoc """
  As três medidas na tela da equipe — feature 058.

  Cada asserção aqui existe porque a ausência da frase correspondente seria
  **invisível**: a tela continuaria bonita, com números que afirmam mais do que a
  plataforma sabe.

  | o que o teste protege | requisito |
  |---|---|
  | quem trabalhou no projeto, com as equipes por onde chegou | FR-007, SC-004 |
  | a marca do período parcialmente desconhecido, **nomeando a borda** | FR-009, SC-005 |
  | a ausência dita em texto, e não lista vazia | FR-011 |
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Repo

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)
    {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Dados", admin.id)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      org: org,
      papel: papel,
      equipe: equipe
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

  # `started_at` nulo é **desconhecido**, e é a única ponta que produz dúvida —
  # `linked_at` é NOT NULL nas duas tabelas de projeto (R2a).
  defp vincular(ctx, equipe, pessoa, desde) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: ctx.papel.id,
        started_at: desde
      })
  end

  defp projeto_ligado(ctx, nome, equipe) do
    {:ok, projeto} = SPO.create_project(ctx.tenant, %{name: nome}, ctx.admin.id)
    {:ok, v} = SPO.link_team(ctx.tenant, projeto.id, equipe.id, ctx.admin.id)
    {projeto, v}
  end

  # O vínculo equipe ↔ projeto nasce com `linked_at` = agora. Para montar a matriz
  # de datas à mão, o teste ajusta a coluna direto — a mesma técnica do teste da
  # consulta, e pela mesma razão: o período é o que está sob teste.
  defp periodo_do_vinculo(vinculo, desde, ate) do
    Repo.update_all(
      from(x in "spo_project_teams", where: x.id == type(^vinculo.id, :binary_id)),
      set: [linked_at: desde, unlinked_at: ate]
    )
  end

  defp dias_atras(n), do: DateTime.add(DateTime.utc_now(:second), -n, :day)

  describe "quem trabalhou no projeto (US2)" do
    test "lista as pessoas com as equipes por onde chegaram", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      {_projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)

      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "Who worked on these projects"
      assert html =~ "Alfa"
      assert html =~ "ana"
      assert html =~ "via Dados"
    end

    test "a mesma pessoa por duas equipes aparece uma vez, com as duas nomeadas", ctx do
      {:ok, outra} =
        EO.declare_structural_team(ctx.tenant, ctx.org.id, "Plataforma", ctx.admin.id)

      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      vincular(ctx, outra, ana, dias_atras(200))

      {projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)
      {:ok, _} = SPO.link_team(ctx.tenant, projeto.id, outra.id, ctx.admin.id)

      {:ok, live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      linhas =
        live
        |> element("#quem-trabalhou")
        |> render()
        |> then(&Regex.scan(~r/link link-hover">\s*ana\s*</, &1))

      assert length(linhas) == 1, """
      A pessoa apareceu #{length(linhas)} vezes na seção. Duas linhas somariam a mesma
      pessoa, e quem contasse a lista mediria participações em vez de gente (FR-010).
      """

      assert html =~ "via Dados, Plataforma" or html =~ "via Plataforma, Dados"
    end

    test "vínculo sem data de início traz a marca, e ela NOMEIA a borda que falta", ctx do
      sem_data = pessoa(ctx, "semdata")
      vincular(ctx, ctx.equipe, sem_data, nil)
      {_projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)

      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "partially unknown"

      assert html =~ "start date", """
      A marca apareceu sem nomear a borda. "Parcial" sozinho diz que há dúvida e não diz
      o que fazer com ela; "start date" diz qual campo preencher (FR-009, SC-005).
      """
    end

    test "vínculo apenas em curso NÃO é marcado — fim nulo é vigente", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      {_projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)

      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      refute html =~ "partially unknown", """
      A marca apareceu para um vínculo apenas em curso. `fim` nulo é **vigente**, e
      marcá-lo poria a dúvida em quase toda linha até ela deixar de significar alguma
      coisa (FR-009a).
      """
    end

    test "projeto sem interseção no período diz a ausência em texto, e não lista vazia", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      {_projeto, vinculo} = projeto_ligado(ctx, "Alfa", ctx.equipe)
      # A equipe esteve ligada de 400 a 300 dias atrás — fora da janela de 8 semanas.
      periodo_do_vinculo(vinculo, dias_atras(400), dias_atras(300))

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      # A asserção é sobre a SEÇÃO, e não sobre a página: "ana" aparece na tabela
      # de membros da equipe de qualquer jeito, e um refute sobre o HTML inteiro
      # passaria a medir a página errada.
      secao = live |> element("#quem-trabalhou") |> render()

      assert secao =~ "Alfa"

      assert secao =~ "Nobody worked on this project in the window", """
      O projeto ficou sem pessoas e sem frase. Lista vazia sem explicação é
      indistinguível de erro de carregamento (FR-011).
      """

      refute secao =~ "ana"
    end
  end
end
