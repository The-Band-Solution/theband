defmodule TheBand.VerificationTest do
  @moduledoc """
  A verificação contínua — feature 037.

  ## As asserções que carregam este arquivo

  1. **cancelado não é falha**: as três fases decididas em 2026-08-18 existem, e nenhuma
     delas cai em `unsuccessful` — contá-las como quebra dobraria a taxa;
  2. **em andamento não tem fase, e isso é diferente de não coletado**;
  3. o **tipo é derivado dos jobs**, e execução sem componente reconhecido fica sem tipo —
     nunca "integração contínua por padrão";
  4. `ci.ap02` **só vale dentro de execução de CI**: o job `sync` de uma automação de
     quadro não é antipadrão, e contá-lo produziria 751 defeitos falsos;
  5. o vínculo com a solicitação é o **SHA**, sem tabela intermediária.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.ContadorDeConsultas
  alias TheBand.Verification
  alias TheBand.Verification.{Classification, Commands}

  setup do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{tenant: tenant, admin: admin, repo_id: cenario.observed_repository_id}
  end

  defp execucao(tenant, repo_id, attrs) do
    {:ok, v} =
      Commands.record_verification(
        tenant,
        Map.merge(
          %{
            observed_repository_id: repo_id,
            workflow_name: "CI",
            head_sha: "abc1234",
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

  defp job(tenant, verificacao, attrs) do
    {:ok, c} =
      Commands.record_component(
        tenant,
        Map.merge(
          %{
            collected_verification_id: verificacao.id,
            job_name: "build",
            external_id: "job-#{System.unique_integer([:positive])}"
          },
          attrs
        )
      )

    c
  end

  describe "as fases" do
    test "cancelado, pulado e expirado têm fase própria, e nenhuma é insucesso" do
      assert Classification.fase("completed", "cancelled") ==
               "ciro.interrupted_continuous_integration_process"

      assert Classification.fase("completed", "skipped") ==
               "ciro.unperformed_continuous_integration_process"

      assert Classification.fase("completed", "timed_out") ==
               "ciro.expired_continuous_integration_process"

      # A asserção que importa: nenhuma das três é malsucedida. Se alguém "simplificar"
      # o mapeamento juntando-as, este teste cai — e é para isso que ele existe.
      refute Classification.fase("completed", "cancelled") =~ "unsuccessful"
      refute Classification.fase("completed", "skipped") =~ "unsuccessful"
      refute Classification.fase("completed", "timed_out") =~ "unsuccessful"
    end

    test "em andamento não tem fase" do
      assert Classification.fase("in_progress", nil) == nil
      assert Classification.fase("queued", nil) == nil
    end

    test "resultado que a regra não decide fica sem fase, e não vira sucesso" do
      assert Classification.fase("completed", "neutral") == nil
      assert Classification.fase("completed", "action_required") == nil
    end
  end

  describe "os componentes e o tipo da execução" do
    test "um job reconhecido em dois processos devolve os dois" do
      componentes = Classification.componentes("quality-gates", ["mix test", "mix credo"])

      assert "ciro.continuous_test_process" in componentes
      assert "ciro.continuous_inspection_process" in componentes
      assert Classification.monolitico?(componentes)
    end

    test "job que constrói e implanta no mesmo lugar é monolítico" do
      # O caso real: 502 jobs `Deploy backoffice` com as etapas `Build production bundle`
      # e `Deploy to Vercel production` juntas, medido em 2026-08-18.
      componentes =
        Classification.componentes("Deploy backoffice", [
          "Build production bundle",
          "Deploy to Vercel production"
        ])

      assert "ciro.continuous_build_process" in componentes
      assert "cdro.deployment_activity" in componentes
      assert Classification.monolitico?(componentes)
    end

    test "subir artefato do build NÃO é entrega contínua" do
      # `artifact` foi removido do padrão porque casava com `Upload Pages artifact` e
      # produzia 238 entregas que não existem.
      componentes =
        Classification.componentes("build", ["Build documentation site", "Upload Pages artifact"])

      assert componentes == ["ciro.continuous_build_process"]
      refute Classification.monolitico?(componentes)
    end

    test "execução sem componente reconhecido fica sem tipo, nunca CI por padrão" do
      assert Classification.componentes("sync", ["Mirror to GitLab"]) == []
      assert Classification.tipos([[], []]) == []
    end

    test "execução com build e deploy é integração E implantação" do
      tipos =
        Classification.tipos([
          ["ciro.continuous_build_process"],
          ["cdro.deployment_activity"]
        ])

      assert tipos == [
               "ciro.continuous_integration_process",
               "cdro.continuous_deployment_process"
             ]
    end

    test "job sem componente só é antipadrão dentro de execução de CI" do
      refute Classification.sem_nome?([], [])
      refute Classification.sem_nome?([], ["cdro.continuous_deployment_process"])
      assert Classification.sem_nome?([], ["ciro.continuous_integration_process"])
    end
  end

  describe "a leitura" do
    test "o painel conta cada fase separada, e em andamento entra como nil", ctx do
      execucao(ctx.tenant, ctx.repo_id, %{
        conclusion: "success",
        phase: "ciro.successful_continuous_integration_process"
      })

      execucao(ctx.tenant, ctx.repo_id, %{
        conclusion: "cancelled",
        phase: "ciro.interrupted_continuous_integration_process"
      })

      execucao(ctx.tenant, ctx.repo_id, %{run_status: "in_progress", conclusion: nil, phase: nil})

      por_fase = Verification.by_phase(ctx.tenant)

      assert por_fase["ciro.successful_continuous_integration_process"] == 1
      assert por_fase["ciro.interrupted_continuous_integration_process"] == 1
      # A chave nula é o que está rodando — colapsá-la em zero apagaria isso.
      assert por_fase[nil] == 1
    end

    test "a contagem de jobs é derivada das entradas, não de contador", ctx do
      v = execucao(ctx.tenant, ctx.repo_id, %{})
      job(ctx.tenant, v, %{job_name: "build"})
      job(ctx.tenant, v, %{job_name: "test"})

      assert [%{jobs: 2}] = Verification.list(ctx.tenant)
    end

    test "filtrar por 'none' lista as execuções que a rede não nomeia", ctx do
      execucao(ctx.tenant, ctx.repo_id, %{
        workflow_name: "Sync to GitLab",
        process_kinds: []
      })

      execucao(ctx.tenant, ctx.repo_id, %{
        workflow_name: "CI",
        process_kinds: ["ciro.continuous_integration_process"]
      })

      assert [%{workflow_name: "Sync to GitLab"}] = Verification.list(ctx.tenant, kind: "none")
      assert Verification.count(ctx.tenant, kind: "none") == 1
    end

    test "filtrar por 'running' encontra o que não tem fase", ctx do
      execucao(ctx.tenant, ctx.repo_id, %{run_status: "in_progress", phase: nil})

      execucao(ctx.tenant, ctx.repo_id, %{
        phase: "ciro.successful_continuous_integration_process"
      })

      assert Verification.count(ctx.tenant, phase: "running") == 1
    end

    test "outro tenant não enxerga a execução — 'não encontrada', não 'sem permissão'", ctx do
      v = execucao(ctx.tenant, ctx.repo_id, %{})
      {outro, _} = tenant_with_admin()

      assert Verification.get(outro, v.id) == nil
      assert Verification.list(outro) == []
    end

    test "o antipadrão de job sem nome só conta dentro de execução de CI", ctx do
      automacao =
        execucao(ctx.tenant, ctx.repo_id, %{workflow_name: "Rollover", process_kinds: []})

      job(ctx.tenant, automacao, %{job_name: "sync", components: []})

      ci =
        execucao(ctx.tenant, ctx.repo_id, %{
          process_kinds: ["ciro.continuous_integration_process"]
        })

      job(ctx.tenant, ci, %{job_name: "mistério", components: []})

      # `sync` fica de fora: não é job mal escrito, é execução que não é CI.
      assert [%{job_name: "mistério"}] = Verification.unnamed_jobs(ctx.tenant)
    end

    test "o monolítico é agrupado por job, não por execução", ctx do
      # O antipadrão é do SCRIPT: listar por execução repetiria a mesma ocorrência
      # centenas de vezes e faria um defeito parecer muitos.
      for _ <- 1..3 do
        v = execucao(ctx.tenant, ctx.repo_id, %{})

        job(ctx.tenant, v, %{
          job_name: "Deploy backoffice",
          components: ["ciro.continuous_build_process", "cdro.deployment_activity"]
        })
      end

      assert [%{job_name: "Deploy backoffice", occurrences: 3}] =
               Verification.monolithic_jobs(ctx.tenant)
    end
  end

  describe "o custo" do
    test "a lista custa o mesmo com uma execução e com vinte", ctx do
      v = execucao(ctx.tenant, ctx.repo_id, %{})
      job(ctx.tenant, v, %{})
      uma = ContadorDeConsultas.contar(fn -> Verification.list(ctx.tenant) end)

      for _ <- 1..19 do
        outra = execucao(ctx.tenant, ctx.repo_id, %{})
        job(ctx.tenant, outra, %{})
      end

      vinte = ContadorDeConsultas.contar(fn -> Verification.list(ctx.tenant) end)

      # A contagem de jobs é subconsulta na mesma consulta, não uma por linha — o defeito
      # da feature 007 (135 consultas por render) nasceu exatamente assim.
      assert vinte == uma
    end

    test "o detalhe custa duas consultas, com um job ou com vinte", ctx do
      v = execucao(ctx.tenant, ctx.repo_id, %{})
      job(ctx.tenant, v, %{})

      um =
        ContadorDeConsultas.contar(fn ->
          Verification.get(ctx.tenant, v.id)
          Verification.components_of(ctx.tenant, v.id)
        end)

      for _ <- 1..19, do: job(ctx.tenant, v, %{})

      vinte =
        ContadorDeConsultas.contar(fn ->
          Verification.get(ctx.tenant, v.id)
          Verification.components_of(ctx.tenant, v.id)
        end)

      assert um == 2
      assert vinte == 2
    end
  end

  describe "a decomposição por organização e repositório" do
    test "conta repositório sem CI separado, e ele não some no total", ctx do
      # É o achado que uma taxa agregada esconderia: 78 dos 121 repositórios da maior
      # organização do piloto não têm CI nenhum, e repositório sem execução não aparece em
      # nenhuma contagem de execução.
      execucao(ctx.tenant, ctx.repo_id, %{
        process_kinds: ["ciro.continuous_integration_process"],
        phase: "ciro.successful_continuous_integration_process"
      })

      assert [org] = Verification.by_organization(ctx.tenant)
      assert org.execucoes == 1
      assert org.bem_sucedidas == 1
      # O cenário observa um repositório só, e ele TEM CI agora.
      assert org.repos_sem_ci == 0
    end

    test "execução que não é CI não faz o repositório contar como tendo CI", ctx do
      # `Sync to GitLab` e `Sprint Rollover` são execuções, e não verificam nada. Contá-las
      # faria o repositório parecer verificado.
      execucao(ctx.tenant, ctx.repo_id, %{process_kinds: [], workflow_name: "Sync to GitLab"})

      assert [org] = Verification.by_organization(ctx.tenant)
      assert org.execucoes == 1
      assert org.repos_sem_ci == 1
    end

    test "o repositório separa o total de execuções do que é CI", ctx do
      execucao(ctx.tenant, ctx.repo_id, %{process_kinds: ["ciro.continuous_integration_process"]})
      execucao(ctx.tenant, ctx.repo_id, %{process_kinds: ["cdro.continuous_deployment_process"]})
      execucao(ctx.tenant, ctx.repo_id, %{process_kinds: []})

      assert [r] = Verification.by_repository(ctx.tenant)
      # Sem as duas colunas, "3 execuções" pareceria 3 verificações.
      assert r.execucoes == 3
      assert r.de_ci == 1
    end

    test "repositório sem execução nenhuma não aparece na lista", ctx do
      # `having: count > 0`. Listar os 160 observados com zero em tudo afogaria os que têm
      # volume — e o estado da coleta por repositório tem tela própria.
      assert Verification.by_repository(ctx.tenant) == []
    end

    test "filtrar por organização restringe a lista e o painel de fases", ctx do
      execucao(ctx.tenant, ctx.repo_id, %{
        phase: "ciro.successful_continuous_integration_process"
      })

      [org] = Verification.by_organization(ctx.tenant)

      assert Verification.count(ctx.tenant, organization_id: org.id) == 1
      assert Verification.by_phase(ctx.tenant, organization_id: org.id) |> map_size() == 1

      # Organização de outro tenant não devolve nada — e "nada", não erro de permissão.
      {outro, _} = tenant_with_admin()
      assert Verification.count(outro, organization_id: org.id) == 0
    end
  end

  describe "o rastro até a solicitação" do
    test "o elo é o SHA do commit, sem tabela de vínculo", ctx do
      %{change_request_id: cr_id, sha: sha} = solicitacao_com_commit(ctx.tenant, ctx.repo_id)

      execucao(ctx.tenant, ctx.repo_id, %{
        head_sha: sha,
        phase: "ciro.unsuccessful_continuous_integration_process"
      })

      assert [%{phase: "ciro.unsuccessful_continuous_integration_process"}] =
               Verification.for_change_request(ctx.tenant, cr_id)
    end

    test "solicitação sem execução coletada devolve vazio, e vazio não é falha", ctx do
      %{change_request_id: cr_id} = solicitacao_com_commit(ctx.tenant, ctx.repo_id)
      assert Verification.for_change_request(ctx.tenant, cr_id) == []
    end
  end

  describe "o estado da coleta por repositório" do
    test "distingue não percorrido de percorrido sem execução", ctx do
      assert [%{collected_at: nil, verifications: 0}] = Verification.repositories(ctx.tenant)

      Commands.touch_repository(ctx.repo_id, DateTime.utc_now(:second))

      assert [%{collected_at: %NaiveDateTime{}, verifications: 0}] =
               Verification.repositories(ctx.tenant)
    end
  end

  defp solicitacao_com_commit(tenant, repo_id) do
    {:ok, cr} =
      TheBand.Changes.Commands.record_change_request(tenant, %{
        observed_repository_id: repo_id,
        number: 1,
        title: "uma mudança",
        state: "MERGED",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_1"
      })

    sha = "deadbee"

    {:ok, _} =
      TheBand.Changes.Commands.record_commit(tenant, %{
        change_request_id: cr.id,
        observed_repository_id: repo_id,
        sha: sha,
        message_headline: "faz a coisa",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: sha
      })

    %{change_request_id: cr.id, sha: sha}
  end
end
