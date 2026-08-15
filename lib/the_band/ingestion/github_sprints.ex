defmodule TheBand.Ingestion.GithubSprints do
  @moduledoc """
  Coleta as caixas de tempo dos quadros e associa as issues a elas (feature 024).

  ## Duas passadas, e a ordem é dependência de dado

  Primeiro as **caixas**, depois as **issues dentro delas**: o vínculo precisa do
  `sprint_id`, que só existe depois de a caixa estar gravada. Não é preferência de
  desenho — inverter não funciona.

  ## Por que esta fase não cabe na janela da feature 020

  A janela pula repositório sem push desde a última revisão. **A caixa de tempo não
  pertence ao repositório**: pertence ao quadro, que cruza repositórios e não tem
  `pushedAt`. Um quadro pode ganhar sprint novo sem que nenhum repositório receba
  commit.

  O custo foi medido em 2026-08-15: **1 ponto de cota** para descobrir os campos dos 26
  quadros. A segunda passada só roda nos que têm campo de iteração — 11 dos 26 —, e o
  DevOps, o maior, tem 677 itens em sete páginas.

  ## Todo campo de iteração vira sprint

  Decisão da pessoa mantenedora. `Sprint`, `Iteration` e `Quarter` entram todos, e o
  nome do campo é gravado: somar caixas de 14 e de 90 dias sem distingui-las produziria
  uma contagem que mistura granularidades.
  """
  require Logger

  alias TheBand.Ingestion
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.Continuum.SRO
  alias TheBand.WorkItems

  # O atributo precisa ser registrado, ou o compilador o trata como esquecido e reprova
  # em `--warnings-as-errors`.
  Module.register_attribute(__MODULE__, :sobelow_skip, accumulate: true)

  @page_size 100

  @doc """
  Coleta as caixas de tempo da organização e associa as issues.

  Recebe o mesmo `ctx` das outras fases. **Não** encerra o `sync`.
  """
  @spec collect(map()) :: {:ok, map()} | {:error, term()}
  def collect(ctx) do
    with {:ok, quadros} <- buscar_quadros(ctx) do
      resultado = Enum.map(quadros, &percorrer_quadro(ctx, &1))

      {:ok,
       %{
         boards: length(quadros),
         boards_with_iteration: Enum.count(resultado, &(&1.sprints > 0)),
         sprints: Enum.sum(Enum.map(resultado, & &1.sprints)),
         links: Enum.sum(Enum.map(resultado, & &1.links)),
         # Quantos quadros ficaram de fora, e é informação: 15 dos 26 medidos não usam
         # caixas de tempo, e isso é diferente de a coleta ter falhado neles.
         boards_without_iteration: Enum.count(resultado, &(&1.sprints == 0))
       }}
    end
  end

  # ------------------------------------------------------- primeira passada: as caixas

  defp buscar_quadros(ctx) do
    vars = %{organization: ctx.tool.organization_login}

    case Client.graphql(ctx.tool.instance_url, ctx.token, ler(:iteracoes), vars) do
      {:ok, %{data: %{"organization" => %{"projectsV2" => %{"nodes" => nodes}}}}} ->
        {:ok, nodes || []}

      # O cliente já normaliza os erros de GraphQL em `{:error, {:graphql_errors, _}}`
      # — casar `%{errors: _}` aqui nunca aconteceria, e o dialyzer disse isso.
      {:error, motivo} ->
        {:error, motivo}

      # **Resposta de forma inesperada devolve erro, e não estoura.** Sem esta cláusula,
      # um `CaseClauseError` derrubava a sincronização inteira — e esta fase existe
      # justamente para não derrubar: pessoas, repositórios e issues já estão gravados.
      #
      # Devolver erro **nomeando o que veio** é diferente de engolir: a fase falha, o
      # motivo vai para o log, e a coleta seguinte tenta de novo.
      outro ->
        {:error, {:resposta_inesperada, outro}}
    end
  end

  defp percorrer_quadro(ctx, quadro) do
    campos = campos_de_iteracao(quadro)

    if campos == [] do
      # **Quadro sem campo de iteração não tem itens consultados.** São 15 dos 26
      # medidos, e pedir os itens deles seria gasto sem resposta. Não é erro, e não
      # entra na contagem de falhas.
      %{sprints: 0, links: 0}
    else
      sprints = Enum.flat_map(campos, &gravar_caixas(ctx, quadro, &1))
      links = associar_issues(ctx, quadro, sprints)
      %{sprints: length(sprints), links: links}
    end
  end

  defp campos_de_iteracao(quadro) do
    (get_in(quadro, ["fields", "nodes"]) || [])
    |> Enum.filter(&(&1["__typename"] == "ProjectV2IterationField"))
  end

  defp gravar_caixas(ctx, quadro, campo) do
    config = campo["configuration"] || %{}

    # Os dois conjuntos entram, e `completed` distingue: pedir só um perderia metade
    # da história — o DevOps tem 32 concluídas contra 7 em curso.
    em_curso = Enum.map(config["iterations"] || [], &{&1, false})
    concluidas = Enum.map(config["completedIterations"] || [], &{&1, true})

    for {iteracao, concluida?} <- em_curso ++ concluidas,
        {:ok, sprint} <- [gravar_caixa(ctx, quadro, campo, iteracao, concluida?)] do
      {campo["name"], sprint}
    end
  end

  defp gravar_caixa(ctx, quadro, campo, iteracao, concluida?) do
    resultado =
      SRO.record_sprint(ctx.tenant, %{
        connected_tool_id: ctx.tool.id,
        board_number: quadro["number"],
        board_title: quadro["title"],
        field_name: campo["name"],
        title: iteracao["title"],
        started_on: Date.from_iso8601!(iteracao["startDate"]),
        # A duração da ITERAÇÃO, e não a do campo: `Sprint 10` tem 3 dias num campo
        # de 14, medido em 2026-08-15.
        duration_days: iteracao["duration"],
        completed: concluida?,
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        # O id da iteração é curto e **local ao campo** — `d8d2574c`. Compor com o id
        # do campo é o que impede dois campos do mesmo quadro colidirem.
        source_external_id: "#{campo["id"]}:#{iteracao["id"]}"
      })

    case resultado do
      {:ok, sprint} ->
        ctx.sync |> Ingestion.reload() |> Ingestion.tally(sprint.outcome || :unchanged)
        {:ok, sprint}

      {:error, changeset} ->
        Logger.warning(
          "caixa de tempo recusada no quadro ##{quadro["number"]}: #{inspect(changeset.errors)}"
        )

        :erro
    end
  end

  # ------------------------------------------------- segunda passada: as issues dentro

  defp associar_issues(ctx, quadro, sprints) do
    case paginar_itens(ctx, quadro["number"]) do
      {:ok, itens} ->
        vincular(ctx, sprints, itens)

      # **A consulta falhou, e por isso nada é marcado.** Sem esta distinção, uma falha
      # de rede esvaziaria todos os sprints do quadro — a plataforma concluiria que as
      # issues saíram, quando ela é que não conseguiu olhar.
      {:error, motivo} ->
        Logger.warning(
          "itens do quadro ##{quadro["number"]} não vieram, e nada foi marcado: " <>
            inspect(motivo, limit: 3)
        )

        0
    end
  end

  defp vincular(ctx, sprints, itens) do
    por_chave = Map.new(sprints, fn {campo, s} -> {{campo, s.title}, s} end)
    externos = WorkItems.issue_ids_by_external_id(ctx.tenant)

    vinculos =
      for item <- itens,
          issue_id = externos[get_in(item, ["content", "id"])],
          not is_nil(issue_id),
          valor <- valores_de_iteracao(item),
          sprint = por_chave[{get_in(valor, ["field", "name"]), valor["title"]}],
          not is_nil(sprint) do
        {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, sprint.id, issue_id)
        {sprint.id, issue_id}
      end

    marcar_ausentes(ctx, sprints, vinculos)
    length(vinculos)
  end

  # A marca é **por sprint**, e nunca por tenant: marcar por tenant atingiria caixas que
  # esta execução nunca olhou — é a L19, e na feature 020 o mesmo descuido teria marcado
  # 4261 vínculos falsos.
  defp marcar_ausentes(ctx, sprints, vinculos) do
    observadas = Enum.group_by(vinculos, &elem(&1, 0), &elem(&1, 1))

    for {_campo, sprint} <- sprints do
      {:ok, _} =
        SRO.mark_issues_no_longer_in_sprint(
          ctx.tenant,
          sprint.id,
          Map.get(observadas, sprint.id, []),
          ctx.started_at
        )
    end
  end

  defp valores_de_iteracao(item) do
    (get_in(item, ["fieldValues", "nodes"]) || [])
    |> Enum.filter(&(&1["title"] && get_in(&1, ["field", "name"])))
  end

  defp paginar_itens(ctx, numero, cursor \\ nil, acumulado \\ []) do
    vars = %{
      organization: ctx.tool.organization_login,
      number: numero,
      page_size: @page_size,
      after: cursor
    }

    case Client.graphql(ctx.tool.instance_url, ctx.token, ler(:itens), vars) do
      {:ok, %{data: %{"organization" => %{"projectV2" => %{"items" => itens}}}}} ->
        acumulado = acumulado ++ (itens["nodes"] || [])

        if get_in(itens, ["pageInfo", "hasNextPage"]) do
          paginar_itens(ctx, numero, get_in(itens, ["pageInfo", "endCursor"]), acumulado)
        else
          {:ok, acumulado}
        end

      # Devolver o acumulado aqui faria falha de rede e quadro vazio ficarem
      # indistinguíveis — e a marca de ausência esvaziaria os sprints por causa de uma
      # consulta que não voltou.
      {:error, motivo} ->
        {:error, motivo}
    end
  end

  # **Não há caminho dinâmico**: cada cláusula traz o arquivo literal, e a função só
  # aceita dois átomos. O Sobelow aponta assim mesmo — a heurística dele marca todo
  # `File.read!` sobre `Path.join`, sem distinguir literal de variável —, e a anotação
  # nomeia o achado em vez de desligar a verificação.
  #
  # É a mesma postura do coletor de issues, com uma diferença a favor: lá o nome é
  # interpolado, aqui nem isso existe.
  @sobelow_skip ["Traversal.FileModule"]
  defp ler(consulta) do
    arquivo =
      case consulta do
        :iteracoes -> "project_iterations.graphql"
        :itens -> "project_items.graphql"
      end

    :the_band
    |> :code.priv_dir()
    |> Path.join("connectors/github/queries/#{arquivo}")
    |> File.read!()
  end
end
