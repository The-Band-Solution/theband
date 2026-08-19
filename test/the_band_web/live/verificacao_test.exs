defmodule TheBandWeb.VerificacaoTest do
  @moduledoc """
  As telas da verificação contínua — feature 037.

  ## As asserções que carregam este arquivo

  1. **as cinco fases aparecem separadas**, e "em andamento" fica fora delas — juntar
     cancelado com falha dobraria a taxa de quebra medida em 2026-08-18;
  2. **execução que a rede não nomeia é dita com essa frase**, nunca escondida — são 399
     das 1.051 coletadas, e omiti-las faria as outras parecerem o total;
  3. **job não coletado é frase diferente de execução sem job**;
  4. o valor cru e o derivado aparecem lado a lado, com o derivado rotulado.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  # O mesmo tamanho de página da tela: a paginação só é renderizada acima dele.
  @por_pagina_da_tela 50

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Verification
  alias TheBand.Verification.Commands

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      repo_id: cenario.observed_repository_id
    }
  end

  defp execucao(tenant, repo_id, attrs) do
    {:ok, v} =
      Commands.record_verification(
        tenant,
        Map.merge(
          %{
            observed_repository_id: repo_id,
            workflow_name: "CI",
            head_sha: "abc12345",
            trigger_event: "push",
            run_status: "completed",
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "run-#{System.unique_integer([:positive])}"
          },
          attrs
        )
      )

    v
  end

  test "a lista separa as cinco fases e mostra o que está rodando fora delas", ctx do
    execucao(ctx.tenant, ctx.repo_id, %{
      conclusion: "cancelled",
      phase: "ciro.interrupted_continuous_integration_process"
    })

    execucao(ctx.tenant, ctx.repo_id, %{run_status: "in_progress", phase: nil})

    {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications")

    assert html =~ "interrupted"
    assert html =~ "not performed"
    assert html =~ "expired"
    # Em andamento tem texto próprio: não é fase, e chamá-la de uma seria dizer que já
    # decidiu.
    assert html =~ "running · no phase yet"
  end

  test "execução que a rede não nomeia é dita, não escondida", ctx do
    execucao(ctx.tenant, ctx.repo_id, %{workflow_name: "Sync to GitLab", process_kinds: []})

    {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications")

    assert html =~ "Sync to GitLab"
    assert html =~ "the network has no concept for this"
  end

  test "filtrar por fase muda a lista sem sair da página", ctx do
    execucao(ctx.tenant, ctx.repo_id, %{
      workflow_name: "que falhou",
      phase: "ciro.unsuccessful_continuous_integration_process"
    })

    execucao(ctx.tenant, ctx.repo_id, %{
      workflow_name: "que passou",
      phase: "ciro.successful_continuous_integration_process"
    })

    {:ok, live, _html} = live(ctx.conn, ~p"/work/verifications")

    html =
      live
      |> element(~s|a[href*="phase=ciro.unsuccessful_continuous_integration_process"]|)
      |> render_click()

    assert html =~ "que falhou"
    refute html =~ "que passou"
  end

  test "sem job coletado, a tela diz isso — e não 'execução sem job'", ctx do
    v = execucao(ctx.tenant, ctx.repo_id, %{})

    {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications/#{v.id}")

    assert html =~ "jobs of this run were not collected"
    assert html =~ "This is not a run without jobs"
  end

  test "o detalhe mostra o cru e o derivado, com o derivado rotulado", ctx do
    v =
      execucao(ctx.tenant, ctx.repo_id, %{
        conclusion: "cancelled",
        phase: "ciro.interrupted_continuous_integration_process",
        process_kinds: ["ciro.continuous_integration_process"],
        attempt: 3
      })

    {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications/#{v.id}")

    # O cru, como a origem entregou.
    assert html =~ "cancelled"
    assert html =~ "What the source said"
    # E a interpretação, marcada como interpretação.
    assert html =~ "ciro.interrupted_continuous_integration_process"
    assert html =~ "derived"
    # Passar na terceira é sucesso, e o número precisa estar visível para isso ser lido.
    assert html =~ "re-run"
  end

  test "execução de outro tenant devolve 'não encontrada', nunca 'sem permissão'", ctx do
    v = execucao(ctx.tenant, ctx.repo_id, %{})
    {_outro_tenant, outro_admin} = tenant_with_admin()
    conn = log_in(build_conn(), outro_admin)

    assert {:error, {:live_redirect, %{to: "/work/verifications", flash: flash}}} =
             live(conn, ~p"/work/verifications/#{v.id}")

    assert flash["error"] =~ "not found"
    refute flash["error"] =~ "permission"
  end

  describe "organização e repositório na tela" do
    test "a lista por organização aparece com repositórios sem CI contados", ctx do
      execucao(ctx.tenant, ctx.repo_id, %{process_kinds: [], workflow_name: "Sync to GitLab"})

      {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications")

      assert html =~ "By organisation"
      # A coluna que a taxa agregada esconderia.
      assert html =~ "repos with no CI"
    end

    test "o repositório mostra total e a parte que é CI, separadas", ctx do
      execucao(ctx.tenant, ctx.repo_id, %{process_kinds: ["ciro.continuous_integration_process"]})
      execucao(ctx.tenant, ctx.repo_id, %{process_kinds: [], workflow_name: "Rollover"})

      {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications")

      assert html =~ "Repositories with runs"
      assert html =~ "of which CI"
    end

    test "a PAGINAÇÃO sobrevive ao filtro de organização", ctx do
      # **É o teste que faltava.** O componente recebia `@org` sem o atributo declarado, e a
      # página morria com `KeyError` — só apareceu ao abrir no navegador, porque nenhum teste
      # tocava aquele caminho. E ele só é renderizado quando há mais registros que uma página.
      for i <- 1..(@por_pagina_da_tela + 1) do
        execucao(ctx.tenant, ctx.repo_id, %{
          workflow_name: "execução #{i}",
          phase: "ciro.successful_continuous_integration_process"
        })
      end

      {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications")

      assert html =~ "next"

      # E com o filtro ligado, que é a combinação que quebrava.
      [org] = Verification.by_organization(ctx.tenant)
      {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications?organization_id=#{org.id}")

      assert html =~ "next"
      assert html =~ "Clear the organisation filter"
    end
  end

  test "a cobertura mostra o estado da ponta, e nomeia o sem-check", ctx do
    {:ok, _} =
      ChangeCommands.record_change_request(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        number: 900,
        title: "entrou sem check",
        state: "MERGED",
        merged_check_state: nil,
        merged_check_contexts: 0,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_900"
      })

    {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications")

    assert html =~ "What the check said about what went in"
    # A frase que o caminho antigo não podia dizer: entrar sem verificação era indistinguível
    # de não conseguirmos medir.
    assert html =~ "no check at all"
    # Trecho curto: o HEEx quebra a frase em linhas, e asserir a frase inteira falha por
    # espaço em branco, não por conteúdo.
    assert html =~ "finding about the process"
    # E o rótulo antigo não pode voltar.
    refute html =~ "verifiable"
  end

  test "a tela por pessoa separa quem teve check de quem não teve", ctx do
    {:ok, pessoa} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: "ana",
        name: "Ana",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_ana",
        collected_at: DateTime.utc_now(:second)
      })

    for {n, estado, contextos} <- [{910, "FAILURE", 2}, {911, nil, 0}] do
      {:ok, _} =
        ChangeCommands.record_change_request(ctx.tenant, %{
          observed_repository_id: ctx.repo_id,
          number: n,
          title: "pr #{n}",
          state: "MERGED",
          author_login: "ana",
          author_person_id: pessoa.id,
          merged_check_state: estado,
          merged_check_contexts: contextos,
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "PR_#{n}"
        })
    end

    {:ok, _live, html} = live(ctx.conn, ~p"/work/verifications/people")

    assert html =~ "Who merged red"
    assert html =~ "had a check"
    assert html =~ "no check"
    # A ressalva vem ANTES da tabela: quem lê a tabela primeiro já formou juízo.
    assert html =~ "A red run on a proposal branch is the process working"
  end

  test "a tela de trabalho leva às verificações", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/work")
    assert html =~ ~s|href="/work/verifications"|
  end
end
