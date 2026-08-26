defmodule TheBandWeb.ClicarLevaAPaginaTest do
  @moduledoc """
  O nome de uma pessoa leva à página dela (feature 014, T001 a T005).

  ## O `refute` importa mais que o `assert`

  São **288** aparições cujo login a plataforma **não** coletou como pessoa — 15 logins, gente que
  saiu da organização antes de a plataforma existir. Ligar todos os nomes por uniformidade produz
  clique que promete e não entrega, e a tela hoje **declara** a ausência com *"person not
  collected"*.

  Por isso metade dos casos aqui assere que **não** há ligação.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  describe "o detalhe da issue" do
    test "o autor coletado leva à página dele", ctx do
      pessoa = pessoa(ctx.tenant, "quem-escreveu")
      issue = issue_com_autor(ctx, pessoa)

      html = abrir_issue(ctx, issue)

      assert html =~ ~s{href="/people/#{pessoa.id}"}
    end

    test "o designado coletado leva à página dele", ctx do
      pessoa = pessoa(ctx.tenant, "quem-recebeu")
      %{pai: issue} = ctx.cenario.issues[3]

      {:ok, _} =
        WorkItems.replace_assignees(ctx.tenant, issue.id, [
          %{login: pessoa.login, person_id: pessoa.id}
        ])

      assert abrir_issue(ctx, issue) =~ ~s{href="/people/#{pessoa.id}"}
    end

    test "o autor SEM pessoa coletada não vira ligação", ctx do
      issue = issue_com_login_solto(ctx, "jessicaduque")

      html = abrir_issue(ctx, issue)

      assert html =~ "jessicaduque"
      assert html =~ "person not collected"

      refute html =~ ~r{<a[^>]*href="/people/[^"]+"[^>]*>\s*jessicaduque}, """
      Um login sem pessoa coletada virou ligação.

      São 15 logins assim — gente que saiu da organização antes de a plataforma existir. A tela
      **declara** que a pessoa não foi coletada; transformar isso em ligação trocaria uma declaração
      honesta por um clique que não leva a lugar nenhum.
      """
    end

    test "o designado sem pessoa coletada não vira ligação", ctx do
      %{pai: issue} = ctx.cenario.issues[3]

      {:ok, _} =
        WorkItems.replace_assignees(ctx.tenant, issue.id, [
          %{login: "sofialctv", person_id: nil}
        ])

      html = abrir_issue(ctx, issue)

      assert html =~ "sofialctv"
      refute html =~ ~r{<a[^>]*href="/people/[^"]+"[^>]*>\s*sofialctv}
    end
  end

  describe "o detalhe da equipe" do
    test "o membro leva à página dele, e o login também", ctx do
      pessoa = pessoa(ctx.tenant, "quem-participa")
      equipe = equipe_com(ctx.tenant, pessoa)

      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{equipe.id}")

      assert html =~ ~s{href="/people/#{pessoa.id}"}

      ocorrencias = length(Regex.scan(~r{href="/people/#{pessoa.id}"}, html))

      assert ocorrencias >= 2, """
      Só uma das duas grafias do nome é clicável.

      Nome e login são a mesma pessoa, e obrigar quem lê a descobrir qual das duas responde ao
      clique é pedir que ele adivinhe.
      """
    end
  end

  describe "o que não pode virar ligação" do
    test "a organização não vira ligação na lista de pessoas", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people")

      refute html =~ ~r{<a[^>]*href="/organizations}, """
      Um nome de organização virou ligação.

      **Não existe página de organização.** Criar a rota é decisão de produto; apontar para uma que
      não existe é afirmar tela que não há.
      """
    end
  end

  describe "o custo" do
    test "ligar não acrescenta consulta nenhuma", ctx do
      pessoa = pessoa(ctx.tenant, "quem-escreveu")
      issue = issue_com_autor(ctx, pessoa)

      consultas = contar_consultas(fn -> live(ctx.conn, ~p"/work/issues/#{issue.id}") end)

      assert consultas > 0, "a medida deu zero — o que passou não foi a garantia"

      # O identificador da pessoa já viaja nos dados que a tela carrega. Uma consulta por linha
      # para resolver o destino é o defeito que a feature 007 pagou com 135 por render.
      # **O número veio da medida, não de escolha.** Antes da feature 014, a mesma tela fazia
      # **39** consultas nos dois renders de `live/2`; depois, **38**. Um teto inventado —
      # "menos que 30" — reprovaria com o código certo, e um "menos que 300" passaria com o
      # defeito.
      #
      # **40 desde a feature 030**: a discussão da issue custa UMA consulta fixa, que roda
      # inclusive quando não há comentário nenhum (é ela que distingue "não coletada" de
      # "coletada e vazia"). Os autores dos comentários entram na consulta de nomes que já
      # existia — nunca uma por comentário, e `discussions_test.exs` mede isso.
      #
      # **42 desde a feature 032**, e as duas têm nome. `Changes.for_issue/2` traz as
      # solicitações que atendem a issue (uma, fixa, com join — nunca uma por PR), e a
      # consulta do repositório observado passou a ser feita porque a seção precisa de
      # `changes_collected_at` para distinguir "não coletada" de "nenhuma atende". Os
      # autores e integradores entram na consulta de nomes que já existia.
      # **46 desde a feature 042**, e são DUAS consultas fixas por render — o dobro porque
      # `live/2` renderiza duas vezes. `resolve_start/2` decide o critério que se aplica a
      # esta issue: uma consulta pelos quadros que declararam, outra pelo projeto. Nenhuma
      # cresce com o número de linhas, e a terceira — a primeira ocorrência do evento — só
      # roda quando algum critério se aplica, e aqui nenhum se aplica.
      #
      # **O teto sobe, a garantia não muda**: o que este caso protege é crescimento POR
      # LINHA. Consulta fixa nova é custo declarado; consulta por linha é o defeito.
      assert consultas <= 46, """
      A tela passou a fazer #{consultas} consultas por render, contra 46 medidas depois da
      feature 042 (42 na 032, 40 na 030, 39 antes dela, 38 depois da 014).

      Ligar um nome usa `person_id`, que já está carregado. Se o número subiu, alguma coisa
      está resolvendo por linha — o defeito que a feature 007 pagou com 135 por render.
      """
    end
  end

  defp abrir_issue(ctx, issue) do
    {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{issue.id}")
    html
  end

  defp pessoa(tenant, login) do
    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        name: login,
        login: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        last_observed_at: DateTime.utc_now(:second)
      })

    pessoa
  end

  defp issue_com_autor(ctx, pessoa) do
    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        number: 9_300,
        title: "issue com autor coletado",
        state: "OPEN",
        issue_type: "Task",
        author_login: pessoa.login,
        author_person_id: pessoa.id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_9300"
      })

    issue
  end

  defp issue_com_login_solto(ctx, login) do
    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        number: 9_301,
        title: "issue de quem saiu antes",
        state: "OPEN",
        issue_type: "Task",
        author_login: login,
        author_person_id: nil,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_9301"
      })

    issue
  end

  defp equipe_com(tenant, pessoa) do
    {:ok, organization} =
      EO.upsert_organization_from_source(tenant, %{
        name: "org-do-teste",
        login: "org-do-teste",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "O_teste",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, equipe} =
      EO.upsert_team_from_source(tenant, %{
        name: "equipe do teste",
        slug: "equipe-do-teste",
        type: "organizational_team",
        organization_external_id: "O_teste",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "T_teste",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        team_id: equipe.id,
        person_id: pessoa.id,
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        # A evidência é identificada pelo par externo pessoa/equipe — é ele que a torna
        # idempotente entre coletas, e a ausência dele levanta em vez de gravar duplicado.
        person_external_id: "U_#{pessoa.login}",
        team_external_id: "T_teste",
        collected_at: DateTime.utc_now(:second),
        observed_at: DateTime.utc_now(:second),
        last_observed_at: DateTime.utc_now(:second)
      })

    _ = organization
    equipe
  end

  defp contar_consultas(fun) do
    TheBand.ContadorDeConsultas.contar(fn ->
      {:ok, _live, _html} = fun.()
    end)
  end

  defp _unused, do: Repo
end
