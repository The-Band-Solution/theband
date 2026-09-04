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

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.ContadorDeConsultas
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Repo
  alias TheBand.Verification
  alias TheBand.Verification.{Classification, Commands}

  setup do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    %{
      tenant: tenant,
      admin: admin,
      repo_id: cenario.observed_repository_id,
      tool_id: cenario.tool.id
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

  describe "o estado da ponta que entrou" do
    # `statusCheckRollup` da ponta, e não o casamento por `head_sha` — issue #439. O casamento
    # achava 284 vermelhas; a ponta acha 221 das INTEGRADAS, e responde 1.705 que entraram sem
    # check nenhum, que o outro caminho chamava de "não dá para saber".
    # As pessoas precisam existir: `red_by_person` exige `author_person_id` não nulo, porque a
    # participação é de pessoa e não de string — login o GitHub deixa renomear.
    defp pessoa(tenant, login) do
      {:ok, p} =
        EO.upsert_person_from_source(tenant, %{
          login: login,
          name: login,
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "U_#{login}",
          collected_at: DateTime.utc_now(:second)
        })

      p
    end

    defp solicitacao_com_ponta(ctx, numero, attrs) do
      ana = pessoa(ctx.tenant, "ana")
      bia = pessoa(ctx.tenant, "bia")

      {:ok, pr} =
        ChangeCommands.record_change_request(
          ctx.tenant,
          Map.merge(
            %{
              observed_repository_id: ctx.repo_id,
              number: numero,
              title: "solicitação #{numero}",
              state: "MERGED",
              author_login: "ana",
              author_person_id: ana.id,
              merged_by_login: "bia",
              merged_by_person_id: bia.id,
              source_system: "github",
              source_instance: "https://github.com",
              external_id: "PR_ponta_#{numero}"
            },
            attrs
          )
        )

      pr
    end

    test "as quatro respostas são distintas, e nenhuma é 'não sei' disfarçada", ctx do
      solicitacao_com_ponta(ctx, 1, %{merged_check_state: "SUCCESS", merged_check_contexts: 3})
      solicitacao_com_ponta(ctx, 2, %{merged_check_state: "FAILURE", merged_check_contexts: 2})
      # Nulo COM zero contextos é nenhum check ter rodado — fato sobre o processo.
      solicitacao_com_ponta(ctx, 3, %{merged_check_state: nil, merged_check_contexts: 0})
      # Nulo SEM contagem é não medimos ainda.
      solicitacao_com_ponta(ctx, 4, %{merged_check_state: nil, merged_check_contexts: nil})
      solicitacao_com_ponta(ctx, 5, %{merged_check_state: "PENDING", merged_check_contexts: 1})

      c = Verification.cobertura_pela_ponta(ctx.tenant)

      assert c[:verde] == 1
      assert c[:vermelha] == 1
      assert c[:sem_check] == 1
      assert c[:nao_medido] == 1

      # `PENDING` não é verde nem vermelho: contá-lo de um lado afirmaria resultado que não houve.
      assert c[:em_curso] == 1
    end

    test "ERROR conta como vermelho, junto com FAILURE", ctx do
      solicitacao_com_ponta(ctx, 10, %{merged_check_state: "ERROR", merged_check_contexts: 1})

      assert Verification.cobertura_pela_ponta(ctx.tenant)[:vermelha] == 1
    end

    test "por pessoa separa quem teve check de quem não teve", ctx do
      solicitacao_com_ponta(ctx, 20, %{merged_check_state: "FAILURE", merged_check_contexts: 2})
      solicitacao_com_ponta(ctx, 21, %{merged_check_state: nil, merged_check_contexts: 0})
      solicitacao_com_ponta(ctx, 22, %{merged_check_state: nil, merged_check_contexts: nil})

      assert [p] = Verification.red_by_person(ctx.tenant)

      assert p.merged == 3
      assert p.verified == 1
      # A coluna que o caminho antigo não tinha: entrar sem verificação é achado, não lacuna.
      assert p.no_check == 1
      assert p.not_measured == 1
      assert p.red == 1
    end

    test "as duas participações são medidas separadas", ctx do
      solicitacao_com_ponta(ctx, 30, %{merged_check_state: "FAILURE", merged_check_contexts: 1})

      assert [autor] = Verification.red_by_person(ctx.tenant)
      assert [integrador] = Verification.red_by_integrator(ctx.tenant)

      # Mesma solicitação, dois papéis, duas listas — somá-las apontaria para a pessoa errada.
      assert autor.login == "ana"
      assert integrador.login == "bia"
      assert autor.red == 1 and integrador.red == 1
    end

    test "solicitação não integrada não entra", ctx do
      solicitacao_com_ponta(ctx, 40, %{
        state: "OPEN",
        merged_check_state: "FAILURE",
        merged_check_contexts: 1
      })

      # A máxima fala de INTEGRADO com verificação vermelha. Vermelho num ramo aberto é o
      # processo funcionando.
      assert Verification.cobertura_pela_ponta(ctx.tenant) == %{}
      assert Verification.red_by_person(ctx.tenant) == []
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
      ChangeCommands.record_change_request(tenant, %{
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

  describe "a verificação sobre os commits da pessoa — feature 044" do
    test "separa passou de quebrou, e conta em UMA consulta", ctx do
      p = pessoa_044(ctx, "quem-commita")
      commit_044(ctx, "sha_ok", p)
      commit_044(ctx, "sha_ruim", p)

      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_ok", conclusion: "success"})
      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_ruim", conclusion: "failure"})

      consultas = ContadorDeConsultas.contar(fn -> Verification.por_pessoa(ctx.tenant, p.id) end)

      assert consultas == 1, """
      A verificação custou #{consultas} consultas, e tem de custar UMA.

      O primeiro desenho usava duas — `join` para os números dela, e uma segunda passagem
      para a parcela do tenant. A página da pessoa foi a 27 por render, e o teto é 26.
      `left_join` nos três responde tudo numa.
      """

      assert %{passou: 1, quebrou: 1, outras: 0} = Verification.por_pessoa(ctx.tenant, p.id)
    end

    test "`skipped` e `cancelled` NÃO são passou nem quebrou", ctx do
      p = pessoa_044(ctx, "quem-commita")
      commit_044(ctx, "sha_pulado", p)

      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_pulado", conclusion: "skipped"})
      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_pulado", conclusion: "cancelled"})

      assert %{passou: 0, quebrou: 0, outras: 2} = Verification.por_pessoa(ctx.tenant, p.id), """
      Execução pulada ou cancelada entrou em passou ou quebrou.

      As duas palavras afirmam RESULTADO, e pular ou cancelar não é resultado — ninguém
      verificou nada. Somá-las a qualquer um dos dois afirmaria verificação que não houve.
      """
    end

    test "conta EXECUÇÕES, e não commits — a nova tentativa conta duas vezes", ctx do
      p = pessoa_044(ctx, "quem-commita")
      commit_044(ctx, "sha_retry", p)

      execucao(ctx.tenant, ctx.repo_id, %{
        head_sha: "sha_retry",
        conclusion: "failure",
        attempt: 1
      })

      execucao(ctx.tenant, ctx.repo_id, %{
        head_sha: "sha_retry",
        conclusion: "success",
        attempt: 2
      })

      assert %{passou: 1, quebrou: 1} = Verification.por_pessoa(ctx.tenant, p.id), """
      A nova tentativa foi achatada com a primeira.

      Um commit, duas execuções: quebrou e depois passou. Contar "um commit" perderia que
      alguém precisou tentar de novo, e a tela é obrigada a dizer que conta execuções.
      """
    end

    test "co-autoria CONTA, e a mesma execução aparece nas duas pessoas", ctx do
      autora = pessoa_044(ctx, "autora")
      coautora = pessoa_044(ctx, "coautora")

      commit_044(ctx, "sha_duplo", autora, coautora)
      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_duplo", conclusion: "success"})

      assert %{passou: 1} = Verification.por_pessoa(ctx.tenant, autora.id)

      assert %{passou: 1} = Verification.por_pessoa(ctx.tenant, coautora.id), """
      A co-autora não recebeu a execução.

      `cmpo.stakeholder_performed_commit` declara `many` na origem, e ignorar o co-autor
      apagaria participação real. A consequência — a soma das páginas excede o total — é
      declarada, e não corrigida.
      """
    end

    test "commit com DOIS autores não dobra a contagem de nenhum deles", ctx do
      autora = pessoa_044(ctx, "autora")
      coautora = pessoa_044(ctx, "coautora")

      commit_044(ctx, "sha_duplo", autora, coautora)
      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_duplo", conclusion: "success"})

      assert %{passou: 1} = Verification.por_pessoa(ctx.tenant, autora.id), """
      A contagem dobrou para quem tem co-autoria.

      A junção produz uma linha por autor do commit. Sem `count(:distinct)`, uma execução
      sobre commit de duas pessoas contaria duas vezes para cada uma.
      """
    end

    test "a parcela sem autoria vai AO LADO, e não entra nos números da pessoa", ctx do
      p = pessoa_044(ctx, "quem-commita")
      commit_044(ctx, "sha_dela", p)

      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_dela", conclusion: "success"})
      # Execução sem commit coletado — o caso de `schedule` e `workflow_dispatch`.
      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_orfao", conclusion: "failure"})

      r = Verification.por_pessoa(ctx.tenant, p.id)

      assert %{passou: 1, quebrou: 0, sem_autoria_no_tenant: 1} = r, """
      A execução órfã entrou nos números da pessoa, ou sumiu do relatório.

      Medido em 2026-08-27: 7.313 de 15.671 execuções — 47% — não casam com pessoa alguma.
      Ela vai ao lado, e nunca descontada nem somada: é contexto sobre o alcance da medida.
      """
    end

    test "a mesma pessoa com dois logins no commit conta a execução uma vez", ctx do
      p = pessoa_044(ctx, "dois-logins")

      {:ok, c} =
        ChangeCommands.record_commit(ctx.tenant, %{
          observed_repository_id: ctx.repo_id,
          sha: "sha_dois_papeis",
          message_headline: "commit sha_dois_papeis",
          external_committed_at: ~U[2026-06-01 10:00:00Z],
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "C_sha_dois_papeis"
        })

      # `replace_commit_authors/3` deduplica por LOGIN, não por pessoa — e uma pessoa
      # pode ter mais de um login do GitHub apontando para o mesmo registro (conta
      # pessoal e conta de trabalho). São duas linhas de autoria legítimas, com o mesmo
      # `author_person_id`, e `commit_authors` não tem índice único sobre (commit, pessoa).
      :ok =
        ChangeCommands.replace_commit_authors(ctx.tenant, c.id, [
          autor_044(p, true),
          %{autor_044(p, false) | author_login: "#{p.login}-trabalho"}
        ])

      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_dois_papeis", conclusion: "success"})

      assert %{passou: 1} = Verification.por_pessoa(ctx.tenant, p.id), """
      Uma execução virou duas porque a pessoa consta duas vezes na autoria do commit.

      É a junção que multiplica, e não o dado: uma execução, um commit, duas linhas de
      autoria. Sem `count(:distinct)` a página mostra o dobro para quem tem dois logins
      do GitHub no mesmo commit.

      Medido em 2026-08-27: zero pares duplicados no banco de desenvolvimento, e nenhum
      índice impedindo o primeiro.
      """
    end

    test "commit de OUTRO repositório com o mesmo sha não é atribuído", ctx do
      p = pessoa_044(ctx, "quem-commita")

      # O commit vive no repositório do cenário; a execução, em outro. Mesma soma.
      commit_044(ctx, "sha_compartilhado", p)
      outro_repo = outro_repositorio_044(ctx)

      execucao(ctx.tenant, outro_repo, %{head_sha: "sha_compartilhado", conclusion: "failure"})

      assert %{passou: 0, quebrou: 0, sem_autoria_no_tenant: 1} =
               Verification.por_pessoa(ctx.tenant, p.id),
             """
             A execução de outro repositório foi atribuída ao commit desta pessoa.

             Fork, espelho e cherry-pick produzem a mesma soma em repositórios diferentes. Sem o
             repositório na junção, a execução aparece na página de quem não a disparou.

             Medido em 2026-08-27: eram 3 execuções em 8.662. Poucas, e atribuição errada do
             mesmo jeito.
             """
    end

    test "outro tenant não alcança verificação nenhuma daqui", ctx do
      p = pessoa_044(ctx, "quem-commita")
      commit_044(ctx, "sha_dela", p)
      execucao(ctx.tenant, ctx.repo_id, %{head_sha: "sha_dela", conclusion: "success"})

      outro = TheBand.DataCase.tenant_fixture("outra-044v")

      assert %{passou: 0, quebrou: 0, sem_autoria_no_tenant: 0} =
               Verification.por_pessoa(outro, p.id),
             """
             A verificação vazou entre tenants.

             Consulta sem filtro de tenant é bug de segurança, não de correção — princípio V.
             """
    end
  end

  defp pessoa_044(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        ctx.tenant,
        Map.merge(source_attrs("U_044v_#{login}"), %{
          name: login,
          login: login,
          account_type: "person"
        })
      )

    p
  end

  defp commit_044(ctx, sha, autora, coautora \\ nil) do
    {:ok, c} =
      ChangeCommands.record_commit(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        sha: sha,
        message_headline: "commit #{sha}",
        external_committed_at: ~U[2026-06-01 10:00:00Z],
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "C_#{sha}"
      })

    # As chaves são as do schema — `author_login`, `author_person_id`, `is_primary` —, e
    # não nomes curtos: `replace_commit_authors/3` repassa o mapa direto ao changeset.
    autores =
      [autor_044(autora, true)] ++ if(coautora, do: [autor_044(coautora, false)], else: [])

    :ok = ChangeCommands.replace_commit_authors(ctx.tenant, c.id, autores)
    c
  end

  defp outro_repositorio_044(ctx) do
    org = organization_fixture(ctx.tenant, "The-Band-Solution")

    {:ok, repo} =
      CMPO.upsert_source_repository_from_source(ctx.tenant, %{
        organization_id: org.id,
        name: "outro-044",
        qualified_name: "acme/outro-044",
        url: "https://github.com/acme/outro-044",
        default_branch: "main",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "R_outro_044"
      })

    {:ok, observado} =
      CMPO.observe_repository(
        ctx.tenant,
        ctx.tool_id,
        repo.id
      )

    observado.id
  end

  defp autor_044(pessoa, principal?) do
    %{
      author_login: pessoa.login,
      author_person_id: pessoa.id,
      author_name: pessoa.name,
      is_primary: principal?
    }
  end

  # ───────────────────────── feature 058, US3 — a taxa do pipeline da equipe ───

  describe "a taxa do pipeline da equipe (058, T013-T015)" do
    test "equipe sem projeto declarado devolve o RELATOR, e não uma taxa de zero", ctx do
      equipe = equipe_058(ctx, "Sem projeto")

      assert {:sem_projeto, %{equipe: "Sem projeto"}} =
               Verification.team_pipeline_rate(ctx.tenant, equipe.id),
             """
             Uma taxa de zero diria que o pipeline falhou. A verdade é outra: a plataforma
             não sabe de quais repositórios esta equipe cuida, e a recusa NOMEIA o elo que
             falta (FR-013a, SC-007).
             """
    end

    test "a execução de quem está FORA da equipe conta — o caminho é o repositório", ctx do
      equipe = equipe_058(ctx, "Dados")
      _ligacao = ligar_projeto_e_repo(ctx, equipe)
      forasteira = pessoa_058(ctx, "forasteira")

      execucao(ctx.tenant, ctx.repo_id, %{
        phase: "ciro.successful_continuous_integration_process",
        conclusion: "success",
        actor_login: forasteira.login,
        actor_person_id: forasteira.id,
        external_started_at: DateTime.add(DateTime.utc_now(:second), -3, :day)
      })

      {:ok, taxa} = Verification.team_pipeline_rate(ctx.tenant, equipe.id)

      assert taxa.sucesso == 1, """
      A execução disparada por alguém de fora não contou. O ator é quem apertou o botão,
      e não quem cuida do código: uma equipe cujo CI roda por agendamento apareceria
      quase vazia (FR-013, R1).
      """

      assert taxa.caminho == "repository → project → team"
    end

    test "as cinco fases contam separadas, e nenhuma soma a falha", ctx do
      equipe = equipe_058(ctx, "Dados")
      _ligacao = ligar_projeto_e_repo(ctx, equipe)

      for {fase, conclusao} <- [
            {"ciro.successful_continuous_integration_process", "success"},
            {"ciro.unsuccessful_continuous_integration_process", "failure"},
            {"ciro.interrupted_continuous_integration_process", "cancelled"},
            {"ciro.unperformed_continuous_integration_process", "skipped"},
            {"ciro.expired_continuous_integration_process", "timed_out"}
          ] do
        execucao(ctx.tenant, ctx.repo_id, %{
          phase: fase,
          conclusion: conclusao,
          external_started_at: DateTime.add(DateTime.utc_now(:second), -2, :day)
        })
      end

      {:ok, taxa} = Verification.team_pipeline_rate(ctx.tenant, equipe.id)

      assert %{sucesso: 1, falha: 1, interrompida: 1, nao_executada: 1, expirada: 1} = taxa

      assert taxa.execucoes_consideradas == 5

      assert taxa.percentual == 50.0, """
      O percentual veio #{inspect(taxa.percentual)}. Ele é sucesso sobre as que produziram
      RESULTADO — 1 de 2 —, e não sobre as cinco: dividir pelas cinco faria a taxa cair a
      cada cancelamento, e culparia o pipeline por decisão humana (FR-015).
      """

      assert taxa.denominador_do_percentual == 2
    end

    test "em andamento fica fora do numerador e do denominador (SC-008)", ctx do
      equipe = equipe_058(ctx, "Dados")
      _ligacao = ligar_projeto_e_repo(ctx, equipe)

      execucao(ctx.tenant, ctx.repo_id, %{
        phase: "ciro.successful_continuous_integration_process",
        conclusion: "success",
        external_started_at: DateTime.add(DateTime.utc_now(:second), -2, :day)
      })

      execucao(ctx.tenant, ctx.repo_id, %{
        phase: nil,
        run_status: "in_progress",
        conclusion: nil,
        external_started_at: DateTime.add(DateTime.utc_now(:second), -1, :hour)
      })

      {:ok, taxa} = Verification.team_pipeline_rate(ctx.tenant, equipe.id)

      assert taxa.em_andamento == 1
      assert taxa.execucoes_consideradas == 1
      assert taxa.denominador_do_percentual == 1
      assert taxa.percentual == 100.0
    end

    test "nada com resultado devolve percentual nil, e não zero", ctx do
      equipe = equipe_058(ctx, "Dados")
      _ligacao = ligar_projeto_e_repo(ctx, equipe)

      execucao(ctx.tenant, ctx.repo_id, %{
        phase: "ciro.interrupted_continuous_integration_process",
        conclusion: "cancelled",
        external_started_at: DateTime.add(DateTime.utc_now(:second), -2, :day)
      })

      {:ok, taxa} = Verification.team_pipeline_rate(ctx.tenant, equipe.id)

      assert taxa.percentual == nil, """
      Zero diria que tudo falhou. Não há o que dividir: uma execução cancelada não
      produziu resultado nenhum (FR-018).
      """

      assert taxa.execucoes_consideradas == 1
    end

    test "repositório desligado conta no intervalo em que esteve ligado, e não fora", ctx do
      equipe = equipe_058(ctx, "Dados")
      ligacao = ligar_projeto_e_repo(ctx, equipe)

      # A equipe está no projeto desde 500 dias atrás; o repositório esteve ligado
      # ao projeto de 400 a 300 dias atrás.
      recuar_vinculo(
        "spo_project_teams",
        ligacao.vinculo_equipe,
        DateTime.add(DateTime.utc_now(:second), -500, :day),
        nil
      )

      recuar_vinculo(
        "spo_project_repositories",
        ligacao.vinculo_repo,
        DateTime.add(DateTime.utc_now(:second), -400, :day),
        DateTime.add(DateTime.utc_now(:second), -300, :day)
      )

      execucao(ctx.tenant, ctx.repo_id, %{
        phase: "ciro.successful_continuous_integration_process",
        conclusion: "success",
        external_started_at: DateTime.add(DateTime.utc_now(:second), -350, :day)
      })

      dentro =
        Verification.team_pipeline_rate(ctx.tenant, equipe.id,
          desde: DateTime.add(DateTime.utc_now(:second), -420, :day),
          ate: DateTime.add(DateTime.utc_now(:second), -280, :day)
        )

      fora =
        Verification.team_pipeline_rate(ctx.tenant, equipe.id,
          desde: DateTime.add(DateTime.utc_now(:second), -30, :day),
          ate: DateTime.utc_now(:second)
        )

      assert {:ok, %{sucesso: 1}} = dentro
      assert {:ok, %{sucesso: 0, repositorios: 0}} = fora
    end

    test "a consulta não junta em eo_people pelo ator", _ctx do
      fonte = File.read!("lib/the_band/verification.ex")

      [_antes, depois] = String.split(fonte, "def team_pipeline_rate", parts: 2)
      [corpo, _resto] = String.split(depois, "\n  @doc", parts: 2)

      refute corpo =~ "actor_person_id", """
      `actor_person_id` apareceu no caminho da taxa. Ele responde *quem disparou*, e não
      *quem cuida do código* — usá-lo produziria uma segunda taxa com o mesmo rótulo e
      denominador diferente (L67, FR-013b).
      """
    end

    test "outro tenant não recebe execução nenhuma (SC-010)", ctx do
      equipe = equipe_058(ctx, "Dados")
      _ligacao = ligar_projeto_e_repo(ctx, equipe)

      execucao(ctx.tenant, ctx.repo_id, %{
        phase: "ciro.successful_continuous_integration_process",
        conclusion: "success",
        external_started_at: DateTime.add(DateTime.utc_now(:second), -2, :day)
      })

      {outro, _} = tenant_with_admin()

      assert {:sem_projeto, _} = Verification.team_pipeline_rate(outro, equipe.id)
    end
  end

  defp equipe_058(ctx, nome) do
    org = organization_fixture(ctx.tenant, "acme-#{System.unique_integer([:positive])}")
    {:ok, equipe} = EO.declare_structural_team(ctx.tenant, org.id, nome, ctx.admin.id)
    equipe
  end

  defp pessoa_058(ctx, login) do
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

  defp ligar_projeto_e_repo(ctx, equipe) do
    {:ok, projeto} = SPO.create_project(ctx.tenant, %{name: "Alfa"}, ctx.admin.id)
    {:ok, vinculo_equipe} = SPO.link_team(ctx.tenant, projeto.id, equipe.id, ctx.admin.id)
    {:ok, vinculo_repo} = SPO.link_repository(ctx.tenant, projeto.id, ctx.repo_id, ctx.admin.id)
    %{projeto: projeto, vinculo_equipe: vinculo_equipe, vinculo_repo: vinculo_repo}
  end

  # Os dois vínculos nascem com `linked_at` = agora. Recuar a ponta é o que permite
  # montar a matriz de datas — e sem recuar a da EQUIPE, o teste do repositório
  # desligado mede outra coisa: a equipe não estava no projeto naquele intervalo.
  defp recuar_vinculo(tabela, vinculo, desde, ate) do
    Repo.update_all(
      from(x in tabela, where: x.id == type(^vinculo.id, :binary_id)),
      set: [linked_at: desde, unlinked_at: ate]
    )
  end
end
