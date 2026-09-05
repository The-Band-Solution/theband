defmodule TheBand.Ingestion.GithubVerifications do
  @moduledoc """
  Coleta as execuções de verificação contínua — feature 037, issue #401.

  Instancia `ciro.continuous_integration_process` pelo mapeamento
  `github.workflow_run.to.ciro.continuous_integration_process`, e cada job pelo
  `github.workflow_job.to.ciro.*`. Roda como fase da mesma sincronização das demais.

  ## Um job por execução, e por que o custo se paga

  Os jobs saem de uma requisição REST por execução — medido em 2026-08-18: 427 execuções
  no repositório principal, e nenhuma outra chamada os traz em lote. O custo se paga
  porque é no job que mora o que a CIRO quer saber: **quais processos componentes** a
  execução materializou, e qual deles quebrou. Sem os jobs, "o CI falhou" seria tudo o
  que a plataforma poderia dizer.

  ## Actions desligado é ausência nomeada, não falha

  Repositório sem Actions responde 404 na rota de execuções. Isso é fato sobre o
  repositório — ninguém configurou verificação contínua —, e vai para `without_ci` no
  resumo. Contá-lo como inalcançável faria a tela dizer "não coletado" onde a resposta é
  "não existe".
  """

  require Logger

  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Verification.{Classification, Commands}

  import Ecto.Query

  @por_pagina 100

  @doc """
  Coleta as verificações, repositório a repositório. Mesmo `ctx` das demais fases.

  Nunca devolve erro: falha num repositório vira `unreachable` no resumo e log — os
  demais seguem, e a próxima coleta tenta de novo (L29).
  """
  @spec collect(map()) :: {:ok, map()} | {:snooze, non_neg_integer()}
  def collect(ctx) do
    ctx = Map.put(ctx, :pessoas, EO.person_ids_by_login(ctx.tenant))
    repositorios = repositorios_observados(ctx.tenant.id, ctx.tool.id)

    case coletar_em_paralelo(ctx, repositorios) do
      # PASSO 3 do algoritmo (ADR 0006, item 5): a janela fechou no meio. A etapa
      # devolve a espera em vez de um resumo parcial que o job leria como "acabou".
      {:sem_janela, reset} ->
        {:snooze, segundos_ate(reset)}

      resultados ->
        {:ok, resumo(repositorios, resultados)}
    end
  end

  defp resumo(repositorios, resultados) do
    %{
      repositories: length(repositorios),
      # Nunca zero disfarçando "acabou": é o que diz à próxima passada que há trabalho.
      runs_without_jobs: Enum.sum(Enum.map(resultados, & &1.sem_jobs)),
      verifications: Enum.sum(Enum.map(resultados, & &1.execucoes)),
      components: Enum.sum(Enum.map(resultados, & &1.jobs)),
      monolithic_jobs: Enum.sum(Enum.map(resultados, & &1.monoliticos)),
      unnamed_components: Enum.sum(Enum.map(resultados, & &1.sem_nome)),
      without_ci: Enum.count(resultados, &(&1.estado == :sem_ci)),
      # Separado de `unreachable` porque as duas frases são diferentes: janela esgotada
      # é "volte daqui a pouco", e inalcançável é "algo está errado com este
      # repositório". Somá-las fez 160 repositórios saudáveis parecerem quebrados na
      # primeira medição, em 2026-08-18.
      rate_limited: Enum.count(resultados, &(&1.estado == :sem_janela)),
      unreachable: Enum.count(resultados, &(&1.estado == :inalcancavel))
    }
  end

  # Um minuto de folga sobre o reset: reabrir no instante exato às vezes ainda recusa.
  defp segundos_ate(%DateTime{} = reset),
    do: max(DateTime.diff(reset, DateTime.utc_now(), :second) + 60, 60)

  defp segundos_ate(_desconhecido), do: 900

  # A concorrência, e o teto — ADR 0006, item 3.
  #
  # Esta é a etapa mais cara da coleta: **uma requisição por execução** para trazer os
  # jobs. É onde o paralelismo mais rende, e é a única fase que não depende de nenhuma
  # outra — por isso foi a primeira escolhida na ADR.
  #
  # Teto 5: o pool do Ecto tem 10 conexões, e estourá-lo trava a aplicação inteira.
  # Configurável para MEDIR — ADR 0006, Verificação 1. A comparação honesta exige rodar os
  # mesmos repositórios com concorrência 1 e com 5, e trocar o atributo entre as rodadas
  # obrigaria a recompilar, o que mata a coleta em curso. O padrão continua sendo 5, e o
  # motivo do teto está na ADR: o pool do Ecto tem 10 conexões.
  # PAUSA PREVENTIVA no balde REST — o análogo do `pause_needed?` da GraphQL, que esta
  # etapa nunca teve. A execução atual está gravada inteira; o que se decide é se vale
  # pedir a PRÓXIMA. Com `remaining` abaixo da margem, não vale: as tarefas em voo ainda
  # vão gastar até `concorrencia` requisições, e a margem é para elas.
  defp pausar_se_a_janela_encurtou(%{remaining: r, reset: %DateTime{} = reset}, resultado)
       when is_integer(r) do
    if r < margem_da_janela(), do: {:sem_janela, reset}, else: resultado
  end

  defp pausar_se_a_janela_encurtou(_janela, resultado), do: resultado

  defp concorrencia, do: Application.get_env(:the_band, :concorrencia_da_coleta, 5)

  # A margem é duas vezes a concorrência — a mesma regra do `pause_needed?` da GraphQL
  # (`remaining < cost * 2`): as tarefas em voo ainda vão gastar até `concorrencia`
  # requisições depois da decisão, e a segunda metade é a folga.
  defp margem_da_janela, do: concorrencia() * 2
  @timeout_por_repositorio :timer.minutes(10)

  # PASSO 1 do algoritmo (ADR 0006, item 5): PARAR no primeiro rate limit.
  #
  # Medido em 2026-09-05: ao bater na cota, a etapa seguia para o próximo repositório — que
  # falhava igual, gastando mais uma requisição. Foram 98 seguidas, e depois 125 em cinco
  # segundos. Cada uma conta contra a cota secundária, e nenhuma trouxe nada.
  #
  # `reduce_while` sobre o stream: as tarefas já em voo terminam (o `halt` não as mata), as
  # não iniciadas nunca começam. O que já foi coletado está gravado; o que não foi fica sem
  # checkpoint, e a retomada sabe onde continuar.
  defp coletar_em_paralelo(ctx, repositorios) do
    TheBand.Ingestion.TaskSupervisor
    |> Task.Supervisor.async_stream_nolink(repositorios, &coletar_repositorio(ctx, &1),
      max_concurrency: concorrencia(),
      ordered: false,
      timeout: @timeout_por_repositorio,
      on_timeout: :kill_task
    )
    |> Enum.reduce_while([], fn tarefa, acc ->
      case resultado_da_tarefa(tarefa) do
        %{estado: :sem_janela, reset: reset} -> {:halt, {:sem_janela, reset}}
        resultado -> {:cont, [resultado | acc]}
      end
    end)
  end

  defp resultado_da_tarefa({:ok, resultado}), do: resultado

  # Tarefa morta — exceção ou tempo esgotado. Tratá-la como sucesso faria o resumo dizer
  # que o repositório foi alcançado, e `unreachable` sairia menor do que a realidade.
  # Vira o mesmo estado que a falha já produzia no caminho sequencial.
  defp resultado_da_tarefa({:exit, motivo}) do
    Logger.warning("verificações de um repositório não completaram: #{inspect(motivo)}")

    %{estado: :inalcancavel, execucoes: 0, jobs: 0, sem_jobs: 0, monoliticos: 0, sem_nome: 0}
  end

  # **Filtra pela FERRAMENTA, não só pelo tenant** — issue #446.
  #
  # Um tenant pode ter mais de uma organização conectada, e o dado sempre soube de quem é
  # cada repositório: `observed_repositories.connected_tool_id` é gravado por
  # `GithubWorkItems` na hora de observar. As fases seguintes ignoravam a coluna e
  # percorriam o tenant inteiro.
  #
  # Medido em 2026-08-19: 3 ferramentas com 121, 25 e 14 repositórios: sincronizar as três
  # percorria 480 em vez de 160, concorrentemente, **e cada uma usava a própria credencial
  # para repositórios das outras duas**. Onde a credencial errada recebia 404, a fase
  # marcava o repositório como percorrido e vazio — ausência de ACESSO lida como ausência
  # de dado, que é a confusão que a casa mais combate.
  defp repositorios_observados(tenant_id, tool_id) do
    Repo.all(
      from r in "observed_repositories",
        join: f in "cmpo_source_repositories",
        on: f.id == r.source_repository_id,
        where:
          r.tenant_id == type(^tenant_id, :binary_id) and
            r.connected_tool_id == type(^tool_id, :binary_id) and is_nil(r.excluded_at),
        select: %{
          id: type(r.id, :binary_id),
          qualified_name: f.qualified_name,
          verifications_collected_at: r.verifications_collected_at
        }
    )
  end

  defp coletar_repositorio(ctx, repo) do
    inicio = DateTime.utc_now(:second)

    case paginar(ctx, repo, desde(repo)) do
      {:ok, runs} ->
        case gravar_runs(ctx, repo, runs) do
          # A janela fechou no MEIO das execuções. O que já tem jobs está gravado; o
          # checkpoint não avança; o reset sobe para a etapa parar.
          {:sem_janela, reset} ->
            vazio(:sem_janela) |> Map.put(:reset, reset)

          resultado ->
            marcar_se_completo(repo, inicio, resultado)
            Map.merge(%{estado: :ok, execucoes: length(runs)}, resultado)
        end

      {:error, :not_found_at_source} ->
        # Actions desligado. Marca o checkpoint: o repositório FOI percorrido, e a
        # resposta foi "não há verificação contínua aqui".
        Commands.touch_repository(repo.id, inicio)
        vazio(:sem_ci)

      # JANELA ESGOTADA não é repositório quebrado — medido em 2026-09-05.
      #
      # O estado `:sem_janela` existia no contador e **nada o produzia**: o rate limit
      # reativo caía no ramo geral abaixo e virava `:inalcancavel`. Na coleta real, 98
      # repositórios saudáveis foram contados como inalcançáveis, e o resumo informou
      # `rate_limited: 0` — exatamente o que o comentário do contador diz que não pode
      # acontecer, e pela segunda vez (a primeira foi medida em 2026-08-18, com 160).
      #
      # A frase importa: "volte daqui a pouco" e "algo está errado com este repositório"
      # levam a ações opostas. Quem lê `unreachable: 98` vai investigar 98 repositórios
      # que não têm nada.
      {:error, {:rate_limited, reset}} ->
        Logger.info(
          "verificações de #{repo.qualified_name} adiadas: janela reabre em #{inspect(reset)}"
        )

        vazio(:sem_janela) |> Map.put(:reset, reset)

      {:error, reason} ->
        Logger.warning("verificações de #{repo.qualified_name} não coletadas: #{inspect(reason)}")

        vazio(:inalcancavel)
    end
  end

  defp vazio(estado) do
    %{estado: estado, execucoes: 0, jobs: 0, monoliticos: 0, sem_nome: 0, sem_jobs: 0}
  end

  # **O checkpoint só avança com os jobs todos coletados**, e a diferença não é
  # cosmética: o incremental filtra por `created >=`, então execução deixada para trás
  # nunca mais é revisitada. Marcar o repositório com jobs faltando perderia esses jobs
  # para sempre — e a tela diria "execução sem job", que é outra coisa.
  #
  # É a L29 na forma dela: falha transitória não grava estado permanente.
  defp marcar_se_completo(repo, inicio, %{sem_jobs: 0}) do
    Commands.touch_repository(repo.id, inicio)
  end

  defp marcar_se_completo(repo, _inicio, %{sem_jobs: faltando}) do
    Logger.warning(
      "#{repo.qualified_name}: #{faltando} execuções sem jobs coletados — checkpoint NÃO avançado"
    )

    :ok
  end

  # O incremental é por data, e a origem filtra: `created=>=AAAA-MM-DD`. Um dia a menos
  # que o checkpoint porque o filtro é por dia, e cortar no mesmo dia perderia as
  # execuções das horas seguintes à última passada.
  defp desde(%{verifications_collected_at: nil}), do: nil

  defp desde(%{verifications_collected_at: quando}) do
    quando |> NaiveDateTime.to_date() |> Date.add(-1)
  end

  # PASSO 4 do algoritmo (ADR 0006, item 5): retomar de onde parou, e não recomeçar.
  #
  # Uma execução COMPLETA que já tem jobs no banco não muda mais — refazer a requisição
  # de jobs dela é gastar cota para gravar o que já está gravado. Era o que a retomada
  # fazia: refazia as mesmas 3 316 requisições e caía no mesmo buraco, no mesmo lugar,
  # para sempre.
  #
  # UMA consulta por repositório, e não uma por execução: o conjunto vem antes do laço.
  defp gravar_runs(ctx, repo, runs) do
    ja_completas = execucoes_completas_com_jobs(ctx.tenant.id, repo.id)

    Enum.reduce_while(runs, zero(), fn run, acc ->
      if MapSet.member?(ja_completas, to_string(run["id"])) do
        {:cont, acc}
      else
        passo_da_execucao(ctx, repo, run, acc)
      end
    end)
  end

  defp passo_da_execucao(ctx, repo, run, acc) do
    case gravar_run(ctx, repo, run) do
      {:sem_janela, _reset} = parada -> {:halt, parada}
      resultado -> {:cont, somar(acc, resultado)}
    end
  end

  defp execucoes_completas_com_jobs(tenant_id, repo_id) do
    Repo.all(
      from v in "collected_verifications",
        join: c in "verification_components",
        on: c.collected_verification_id == v.id,
        where:
          v.tenant_id == type(^tenant_id, :binary_id) and
            v.observed_repository_id == type(^repo_id, :binary_id) and
            v.run_status == "completed",
        distinct: true,
        select: v.external_id
    )
    |> MapSet.new()
  end

  defp zero, do: %{jobs: 0, monoliticos: 0, sem_nome: 0, sem_jobs: 0}

  # Os jobs vêm ANTES do registro da execução, e a ordem é o que permite derivar o tipo:
  # `process_kinds` sai dos componentes dos jobs, e gravar a execução primeiro obrigaria a
  # voltar para atualizá-la — dois caminhos de escrita para o mesmo fato.
  defp gravar_run(ctx, repo, run) do
    case Client.run_jobs(ctx.tool.instance_url, ctx.token, repo.qualified_name, run["id"]) do
      {:ok, %{jobs: jobs, janela: janela}} ->
        classificados =
          Enum.map(jobs, &{&1, Classification.componentes(&1["name"], etapas_de(&1))})

        tipos = Classification.tipos(Enum.map(classificados, &elem(&1, 1)))
        verificacao = registrar_execucao(ctx, repo, run, tipos)

        resultado =
          Enum.reduce(classificados, zero(), fn par, acc ->
            somar(acc, gravar_job(ctx, verificacao, par, tipos))
          end)

        pausar_se_a_janela_encurtou(janela, resultado)

      # A janela fechou AQUI. Antes: marcava `sem_jobs` e seguia para a próxima execução,
      # que falhava igual — 586 vezes numa coleta. Agora para, e a execução NÃO é gravada
      # sem jobs: ela não existe ainda no banco, e a retomada a trará inteira.
      {:error, {:rate_limited, reset}} ->
        {:sem_janela, reset}

      {:error, reason} ->
        # Sem os jobs não há como derivar o tipo, e derivá-lo de outra coisa seria
        # inventá-lo. A execução é gravada com a lista vazia e a tela a mostra como
        # "jobs não coletados" — frase diferente de "execução sem jobs".
        Logger.warning("jobs da execução #{run["id"]} não coletados: #{inspect(reason)}")
        registrar_execucao(ctx, repo, run, [])
        %{zero() | sem_jobs: 1}
    end
  end

  defp etapas_de(job), do: Enum.map(job["steps"] || [], & &1["name"])

  defp registrar_execucao(ctx, repo, run, tipos) do
    {:ok, verificacao} =
      Commands.record_verification(ctx.tenant, %{
        observed_repository_id: repo.id,
        workflow_name: run["name"],
        workflow_path: run["path"],
        head_sha: run["head_sha"],
        head_branch: run["head_branch"],
        # Crus, como a origem entrega — a tradução fica ao lado, nunca no lugar.
        trigger_event: run["event"],
        run_status: run["status"],
        conclusion: run["conclusion"],
        phase: Classification.fase(run["status"], run["conclusion"]),
        process_kinds: tipos,
        attempt: run["run_attempt"] || 1,
        external_started_at: parse_datetime(run["run_started_at"] || run["created_at"]),
        external_finished_at: fim_de(run),
        actor_login: get_in(run, ["actor", "login"]),
        actor_person_id: ctx.pessoas[get_in(run, ["actor", "login"])],
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        external_id: to_string(run["id"]),
        raw_payload: Map.drop(run, ["repository", "head_repository"])
      })

    verificacao
  end

  defp gravar_job(ctx, verificacao, {job, componentes}, tipos) do
    {:ok, _} =
      Commands.record_component(ctx.tenant, %{
        collected_verification_id: verificacao.id,
        job_name: job["name"],
        conclusion: job["conclusion"],
        phase: Classification.fase(job["status"], job["conclusion"]),
        components: componentes,
        step_names: etapas_de(job),
        external_started_at: parse_datetime(job["started_at"]),
        external_finished_at: parse_datetime(job["completed_at"]),
        external_id: to_string(job["id"])
      })

    %{
      zero()
      | jobs: 1,
        monoliticos: if(Classification.monolitico?(componentes), do: 1, else: 0),
        sem_nome: if(Classification.sem_nome?(componentes, tipos), do: 1, else: 0)
    }
  end

  # Soma pelas CHAVES DE `zero()`, e não por uma lista escrita à mão: a versão escrita à
  # mão esqueceu `sem_jobs` quando ele foi acrescentado, e o guarda do checkpoint passou a
  # quebrar em qualquer repositório com execução — sem nenhum teste notar, porque a fase
  # só é alcançada com repositório observado.
  defp somar(a, b) do
    Map.new(zero(), fn {chave, _} -> {chave, Map.fetch!(a, chave) + Map.fetch!(b, chave)} end)
  end

  # A execução em andamento não tem fim, e `updated_at` não é fim — é a última mexida.
  # Usar um pelo outro inventaria duração para o que ainda está rodando.
  defp fim_de(%{"status" => "completed"} = run), do: parse_datetime(run["updated_at"])
  defp fim_de(_run), do: nil

  defp parse_datetime(nil), do: nil

  defp parse_datetime(valor) do
    case DateTime.from_iso8601(valor) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp paginar(ctx, repo, desde, pagina \\ 1, acumulado \\ []) do
    opcoes = [page: pagina, per_page: @por_pagina, since: desde]

    case Client.workflow_runs(ctx.tool.instance_url, ctx.token, repo.qualified_name, opcoes) do
      {:ok, %{runs: []}} ->
        {:ok, acumulado}

      {:ok, %{runs: runs}} ->
        acumulado = acumulado ++ runs

        if length(runs) < @por_pagina do
          {:ok, acumulado}
        else
          paginar(ctx, repo, desde, pagina + 1, acumulado)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
