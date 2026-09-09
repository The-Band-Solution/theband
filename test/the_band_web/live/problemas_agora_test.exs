defmodule TheBandWeb.ProblemasAgoraTest do
  @moduledoc """
  *Problemas agora* — spec 060, FR-065 a FR-069 (US8).

  ## As três asserções que carregam este arquivo

  1. **zero não é a mesma coisa que não conferido** (FR-067). *Conferido, nada encontrado*
     diz que a plataforma tinha o insumo, olhou e não achou; *não conferido* diz que o insumo
     não é coletado. Apresentados como número, os dois seriam **zero** — e são afirmações
     opostas. É a razão de dois dos oito cartões não terem número nenhum;
  2. **o limiar está escrito no cartão, e a origem dele também** (FR-066, FR-069). "46
     issues" é um número sem pergunta; "46 issues abertas há mais de 30 dias" é uma. E a
     origem é a regra na base de conhecimento, porque limiar em constante muda num diff e
     ninguém percebe que a plataforma passou a afirmar outra coisa;
  3. **nenhum limiar vive em constante de módulo** (FR-069). Os dois novos vêm de
     `team.dashboard.thresholds`; o da parada **reusa** `profile.thresholds.stale_open_work`,
     que já existia — declarar um segundo seria a plataforma discordando de si mesma.

  ## E a que a seção existe para impedir

  Um zero mudo. Um cartão que mostra `0` sem dizer qual dos dois zeros ele é convida a
  concluir que está tudo bem — e metade das vezes o que ele diz é que ninguém olhou.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles.Material
  alias TheBand.Repo
  alias TheBand.Teams.ProblemsNow
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    org = cenario.organization
    {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Plataforma", admin.id)
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
        name: String.capitalize(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{}
      })

    {:ok, _} =
      EO.declare_role(ctx.tenant, ctx.equipe.id, p.id, {:existente, ctx.papel.id}, ctx.admin.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -400, :day)
      )

    p
  end

  defp issue(ctx, externo, pessoa, dias_atras) do
    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 1_000_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "issue #{externo}",
        state: "OPEN",
        external_created_at: DateTime.add(DateTime.utc_now(:second), -dias_atras, :day),
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

  defp painel(ctx), do: live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

  describe "a seção existe, e vem antes das medidas (FR-065)" do
    test "aparece no painel, com os oito cartões", ctx do
      {:ok, _live, html} = painel(ctx)

      assert html =~ "Problems now"

      for titulo <- [
            "Issues open beyond the threshold",
            "Code changes waiting for a first human review",
            "Pipeline failing now on the default branch",
            "Assigned tasks past the stop threshold",
            "People with no open task",
            "Members with no declared role",
            "Work outside any declared project",
            "Structure anomalies"
          ] do
        assert html =~ titulo, "falta o cartão: #{titulo}"
      end
    end

    test "vem ANTES do burn e das pessoas — a ordem é o requisito", ctx do
      {:ok, _live, html} = painel(ctx)

      {pos_problemas, _} = :binary.match(html, "Problems now")
      {pos_burn, _} = :binary.match(html, "Burn-up and burn-down")

      assert pos_problemas < pos_burn, """
      Quem abre o painel pergunta primeiro *o que precisa do meu olhar hoje*, e uma medida de
      fluxo responde outra coisa. Pôr isto depois faria quem gerencia rolar a página para
      chegar ao que veio buscar.
      """
    end
  end

  describe "zero NÃO é a mesma coisa que não conferido (FR-067)" do
    test "sem nada, os cartões contados dizem 'checked, nothing found'", ctx do
      {:ok, _live, html} = painel(ctx)

      assert html =~ "checked, nothing found", """
      Zero mudo convida a concluir que está tudo bem. *Conferido, nada encontrado* é uma
      afirmação: a plataforma tinha o insumo, olhou, e não achou.
      """
    end

    test "os dois cartões sem insumo dizem 'not checked' e O QUE FALTA", ctx do
      {:ok, _live, html} = painel(ctx)

      assert html =~ "not checked"

      # O pipeline falhando agora: os insumos são coletados, a consulta não existe.
      assert html =~ "the inputs are collected", """
      *Não conferido* sem dizer o que falta é tão mudo quanto um zero. O cartão nomeia a
      lacuna — aqui, que a consulta não existe embora o dado exista.
      """

      # E o trabalho fora de projeto: a regra que o nomeia não existe.
      assert html =~ "no declared project of this team"
    end

    test "o cartão sem insumo NÃO mostra número — nem zero", ctx do
      cartoes = ProblemsNow.cartoes(ctx.tenant, [ctx.equipe.id], %{})

      pipeline = Enum.find(cartoes, &(&1.id == :pipeline_falhando))
      fora = Enum.find(cartoes, &(&1.id == :fora_de_projeto))

      assert match?({:nao_conferido, _}, pipeline.resultado)

      assert match?({:nao_conferido, _}, fora.resultado), """
      Zero aqui afirmaria que todo o trabalho está dentro de projeto declarado — e é
      exatamente o oposto do que este cartão existe para revelar: a diferença entre "a
      plataforma não sabe" e "a organização não declarou".
      """
    end
  end

  describe "o limiar está no cartão, e vem da base (FR-066, FR-069)" do
    test "cada cartão diz o limiar e a regra que o declara", ctx do
      {:ok, _live, html} = painel(ctx)

      assert html =~ "open for more than #{ProblemsNow.issue_open_days()} days"
      assert html =~ "waiting for more than #{ProblemsNow.review_wait_days()} days"
      assert html =~ "open for more than #{Material.stale_days()} days"

      # E a origem, para quem quiser mudar saber onde.
      assert html =~ "team.dashboard.thresholds · open_issue_age"
      assert html =~ "team.dashboard.thresholds · review_wait"
      assert html =~ "profile.thresholds · stale_open_work"
    end

    test "os dois limiares novos vêm do YAML, com os valores confirmados em 2026-09-07", _ctx do
      assert ProblemsNow.issue_open_days() == 30
      assert ProblemsNow.review_wait_days() == 7
    end

    test "o limiar de parada é REUSADO, e não declarado uma segunda vez", _ctx do
      assert Material.stale_days() == 90, """
      A parada usa `profile.thresholds.stale_open_work`, que já existia. Declarar um segundo
      limiar de parada seria a mesma pergunta com dois números em telas diferentes — a
      plataforma discordando de si mesma.
      """
    end
  end

  describe "as contagens são de FATO, e batem com o dado" do
    test "issue aberta além do limiar conta; a de ontem não", ctx do
      ana = pessoa(ctx, "ana")

      issue(ctx, "velha", ana, 60)
      issue(ctx, "outra-velha", ana, 45)
      issue(ctx, "nova", ana, 1)

      cartoes = ProblemsNow.cartoes(ctx.tenant, [ctx.equipe.id], %{})
      antigas = Enum.find(cartoes, &(&1.id == :issues_antigas))

      assert {:contado, 2, _} = antigas.resultado, """
      Duas passaram de 30 dias, uma não. O limiar é o que separa — e é ele que torna o número
      interpretável.
      """
    end

    test "item de DOIS responsáveis conta uma vez nas paradas", ctx do
      ana = pessoa(ctx, "ana")
      bia = pessoa(ctx, "bia")

      i = issue(ctx, "compartilhada", ana, 200)

      Repo.insert!(%IssueAssignee{
        tenant_id: ctx.tenant.id,
        collected_issue_id: i.id,
        login: bia.login,
        person_id: bia.id
      })

      {:ok, _live, html} = painel(ctx)

      # O cartão das paradas usa `uniq_by` na issue: dois responsáveis, um item.
      [_antes, secao] = String.split(html, "Assigned tasks past the stop threshold", parts: 2)
      [cartao, _depois] = String.split(secao, "</div>", parts: 2)

      assert cartao =~ ">1<", """
      Item de dois responsáveis conta UMA vez, como conta uma vez na equipe (057 FR-008).
      Contar por designação daria 2, e o número diria mais itens parados do que existem.
      """
    end

    test "pessoa sem tarefa aberta é contada, e quem tem não", ctx do
      ana = pessoa(ctx, "ana")
      _bia = pessoa(ctx, "bia")
      issue(ctx, "da-ana", ana, 10)

      {:ok, _live, html} = painel(ctx)

      [_antes, secao] = String.split(html, "People with no open task", parts: 2)
      [cartao, _depois] = String.split(secao, "</div>", parts: 2)

      assert cartao =~ ">1<", "a Bia não tem tarefa aberta; a Ana tem"
    end
  end

  describe "o cartão com número leva à lista (FR-068)" do
    test "o cartão de membros sem papel leva à aba Estrutura", ctx do
      # Vínculo observado: sem papel declarado.
      {:ok, ana} =
        EO.upsert_person_from_source(ctx.tenant, %{
          login: "carol",
          name: "Carol",
          account_type: "person",
          source_system: "github",
          source_instance: "https://github.com",
          source_endpoint: "/users/carol",
          external_id: "U_carol",
          collected_at: DateTime.utc_now(:second),
          payload: %{}
        })

      {:ok, _} =
        EO.record_team_membership_evidence(ctx.tenant, %{
          person_id: ana.id,
          team_id: ctx.equipe.id,
          person_external_id: ana.external_id,
          team_external_id: ctx.equipe.external_id,
          platform_access_level: "MEMBER",
          source_system: "github",
          source_instance: "https://github.com",
          observed_at: DateTime.utc_now(:second)
        })

      {:ok, live, _html} = painel(ctx)

      assert has_element?(live, ~s|a[href="/teams/#{ctx.equipe.id}?tab=structure"]|), """
      Cartão com número maior que zero leva à lista do que contou (FR-068). O papel não
      declarado se resolve na Estrutura, e é para lá que o cartão aponta.
      """
    end
  end
end
