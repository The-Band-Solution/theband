defmodule TheBandWeb.VincularPessoaTest do
  @moduledoc """
  Vincular uma pessoa a uma equipe — FR-003 da spec 055, protótipo aprovado em 2026-09-11.

  A cláusula é **MUST** desde a 055, e nunca teve tela: `declare_team_membership/5` tinha
  `@spec`, `@doc` e onze testes, e **zero chamadas em `lib/`**. A saída era declarável e a
  entrada não — e quem a origem não mostra não entrava em equipe nenhuma pela interface, que
  é exatamente o caso para o qual a FR-003 existe.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Ontology.SEON.EO

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")
    {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Plataforma", admin.id)
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      org: org,
      equipe: equipe,
      papel: papel
    }
  end

  defp pessoa(ctx, login, opts \\ []) do
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

    if Keyword.get(opts, :sumiu?, false) do
      {:ok, m} =
        p
        |> Ecto.Changeset.change(no_longer_observed_at: DateTime.utc_now(:second))
        |> TheBand.Repo.update()

      m
    else
      p
    end
  end

  defp texto(html) do
    html
    |> String.replace(~r/<script.*?<\/script>/s, " ")
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace("&#39;", "'")
    |> String.replace("&amp;", "&")
    |> String.replace(~r/\s+/, " ")
  end

  defp abrir(ctx) do
    {:ok, view, _} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?tab=structure")
    view
  end

  describe "a seção (§3.4)" do
    test "existe, entre Roles e Members, e diz por que tem seção própria", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?tab=structure")
      t = texto(html)

      assert t =~ "Link a person to this team"
      assert t =~ "for someone the source does not show"

      assert t =~ "no row to live in", """
      O sujeito do ato é quem NÃO está na lista. É por isso que ele tem seção, e não uma ação
      por linha — não há linha onde ele pudesse morar.
      """
    end

    test "em repouso a busca fica fechada", ctx do
      {:ok, _view, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?tab=structure")

      refute texto(html) =~ "step 1 · find the person"
      assert texto(html) =~ "＋ Link a person…"
    end
  end

  describe "a busca (§3.5)" do
    test "diz o escopo, e que NÃO cria pessoa", ctx do
      view = abrir(ctx)
      render_click(view, "abrir_vinculo", %{})
      t = texto(render(view))

      assert t =~ "step 1 · find the person"
      assert t =~ "people already collected"

      assert t =~ "does not create a person", """
      Pessoa existe porque uma coleta a viu. Uma tela que criasse pessoa faria a plataforma
      afirmar existência que ninguém observou.
      """
    end

    test "a busca vazia NÃO é erro, e diz o que faria achar alguém", ctx do
      view = abrir(ctx)
      render_click(view, "abrir_vinculo", %{})
      t = texto(render_change(view, "buscar_para_vincular", %{"q" => "ninguem"}))

      assert t =~ "No collected person matches"
      assert t =~ "is not an error"
      assert t =~ "a collection that reaches the tool"
    end
  end

  describe "os seis vereditos, ANTES do botão (§3.5)" do
    test "1 · sem nada aqui: permitido, e as contagens não somam", ctx do
      pessoa(ctx, "ana")
      view = abrir(ctx)
      render_click(view, "abrir_vinculo", %{})
      t = texto(render_change(view, "buscar_para_vincular", %{"q" => "ana"}))

      assert t =~ "link allowed"
      assert t =~ "do not add up across teams"
    end

    test "2 · já é membro: RECUSA inerte, e oferece declarar o papel", ctx do
      p = pessoa(ctx, "ana")

      {:ok, _} =
        EO.declare_team_membership(
          ctx.tenant,
          ctx.equipe.id,
          p.id,
          %{organizational_role_id: ctx.papel.id},
          ctx.admin.id
        )

      view = abrir(ctx)
      render_click(view, "abrir_vinculo", %{})
      html = render_change(view, "buscar_para_vincular", %{"q" => "ana"})
      t = texto(html)

      assert t =~ "link refused"
      assert t =~ "already a member"

      assert t =~ "does not create a second one", """
      O que falta é o PAPEL, e declarar completa AQUELE vínculo. A recusa aponta o ato certo —
      recusa que não oferece caminho manda a pessoa procurar.
      """

      assert html =~ "btn-dash", "e o botão fica no lugar, inerte"
    end

    test "3 · vínculo numa subequipe: permitido, e a contagem NÃO muda", ctx do
      {:ok, squad} = EO.declare_subteam(ctx.tenant, ctx.equipe, "Squad Azul", ctx.admin.id)
      p = pessoa(ctx, "ana")

      {:ok, _} =
        EO.declare_team_membership(
          ctx.tenant,
          squad.id,
          p.id,
          %{organizational_role_id: ctx.papel.id},
          ctx.admin.id
        )

      view = abrir(ctx)
      render_click(view, "abrir_vinculo", %{})
      t = texto(render_change(view, "buscar_para_vincular", %{"q" => "ana"}))

      assert t =~ "allowed — a different fact"
      assert t =~ "Squad Azul"

      assert t =~ "member count does not change", """
      A consequência não óbvia, escrita ANTES do ato: ela já era contada pela squad. Descobrir
      isso depois é ver o número não mexer sem saber por quê.
      """
    end

    test "6 · a origem deixou de mostrar: permitido, e é o caso da FR-003", ctx do
      pessoa(ctx, "sumida", sumiu?: true)
      view = abrir(ctx)
      render_click(view, "abrir_vinculo", %{})
      t = texto(render_change(view, "buscar_para_vincular", %{"q" => "sumida"}))

      assert t =~ "allowed — read the mark first"
      assert t =~ "stopped showing"
      assert t =~ "the case FR-003 exists for"
    end
  end

  describe "o formulário (§3.5, passo 2)" do
    setup ctx do
      p = pessoa(ctx, "ana")
      view = abrir(ctx)
      render_click(view, "abrir_vinculo", %{})
      render_change(view, "buscar_para_vincular", %{"q" => "ana"})
      render_click(view, "escolher_para_vincular", %{"person-id" => p.id})
      %{p: p, view: view}
    end

    test "o papel é obrigatório, e a razão está escrita", %{view: view} do
      html = render(view)

      assert texto(html) =~ "role in this team"
      assert texto(html) =~ "— required"
      assert html =~ "required", "o campo é `required` de facto, e não só no rótulo"

      assert texto(html) =~ "cannot tell apart from an observed one", """
      A razão do papel não é de formulário: vínculo vigente sem papel e sem origem é a única
      forma que a plataforma não distingue do observado — e ocupa a vaga do índice parcial.
      """
    end

    test "a data é opcional, e vazia fica DESCONHECIDA — nunca hoje", %{view: view} do
      t = texto(render(view))

      assert t =~ "empty = start unknown"
      assert t =~ "never filled with today"
    end

    test "diz o que cria e o que NÃO faz", %{view: view} do
      t = texto(render(view))

      assert t =~ "what this creates"
      assert t =~ "What it does not do"
      assert t =~ "changes nothing at the source"
      assert t =~ "does not become an observed link"
    end

    test "declarar cria o vínculo, com papel e sem data", %{view: view, p: p} = ctx do
      html = render_submit(view, "declarar_vinculo", %{"role_id" => ctx.papel.id, "since" => ""})

      assert texto(html) =~ "is now linked to this team"

      agora = DateTime.utc_now(:second)
      membros = EO.team_members_at(ctx.tenant, ctx.equipe.id, agora)

      assert Enum.any?(membros, &(&1.person_id == p.id)), "a pessoa entrou na equipe"

      vinculo = Enum.find(membros, &(&1.person_id == p.id))

      assert is_nil(vinculo.started_at), """
      Data em branco fica NULA. Preenchê-la com hoje afirmaria um começo que ninguém declarou.
      """

      assert vinculo.papel_declarado?, "e o papel foi declarado"
    end

    test "declarar COM data guarda a data", %{view: view, p: p} = ctx do
      render_submit(view, "declarar_vinculo", %{
        "role_id" => ctx.papel.id,
        "since" => "2026-01-15"
      })

      membros = EO.team_members_at(ctx.tenant, ctx.equipe.id, DateTime.utc_now(:second))
      vinculo = Enum.find(membros, &(&1.person_id == p.id))

      assert DateTime.to_date(vinculo.started_at) == ~D[2026-01-15]
    end

    test "sem papel, o domínio RECUSA e a tela diz o motivo", %{view: view} do
      html = render_submit(view, "declarar_vinculo", %{"role_id" => "", "since" => ""})

      assert texto(html) =~ "papel", "a recusa nomeia o que falta"
    end
  end
end
