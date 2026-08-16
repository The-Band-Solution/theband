defmodule TheBand.Ingestion.GithubProjects do
  @moduledoc """
  Coleta os quadros inteiros — entidade, campos, itens, valores e iterações. Sprint 017,
  T047 a T056. Substitui `GithubSprints`, preservando o que a 024 provou: a promoção
  iteração-iniciada→sprint, a identidade `campo:iteração`, os vínculos issue↔sprint e a
  marca de ausência **por sprint**.

  ## As três passadas, e a ordem é dependência de dado

  1. **quadros e campos** — a entidade nasce aqui, e os campos com ela;
  2. **iterações** — roteadas por `Projects.record_iteration`, que decide sprint ou
     processo pretendido e faz a transição (FR-029, FR-030, FR-030a);
  3. **itens e valores** — cada item ligado à issue já coletada, rascunho registrado
     (FR-022), todo valor cru, `interpreted_as` só com mapeamento declarado (FR-025).

  ## Organização sem quadros é resposta (FR-040)

  `projects: 0` com `without_projects: true` no resumo — declarado, e não coleta vazia
  por falha. Descobrir depois de três dias de sincronização sem resultado é o risco que
  o backlog registrava.
  """

  require Logger

  Module.register_attribute(__MODULE__, :sobelow_skip, accumulate: true)

  alias TheBand.Ingestion
  alias TheBand.Integrations.GitHub.Client
  alias TheBand.Ontology.Continuum.SRO
  alias TheBand.Projects
  alias TheBand.WorkItems

  @page_size 100

  @doc """
  Coleta os quadros da organização e tudo que eles carregam.

  Recebe o mesmo `ctx` das outras fases. **Não** encerra o `sync`.
  """
  @spec collect(map()) :: {:ok, map()} | {:error, term()}
  def collect(ctx) do
    with {:ok, quadros} <- buscar_quadros(ctx) do
      mapeamentos = Projects.field_mappings(ctx.tenant)
      resultado = Enum.map(quadros, &percorrer_quadro(ctx, &1, mapeamentos))

      {:ok,
       %{
         projects: length(quadros),
         # FR-040: zero quadros é resposta declarada, e não falha silenciosa.
         without_projects: quadros == [],
         fields: soma(resultado, :fields),
         items: soma(resultado, :items),
         drafts: soma(resultado, :drafts),
         values: soma(resultado, :values),
         sprints: soma(resultado, :sprints),
         intended: soma(resultado, :intended),
         links: soma(resultado, :links)
       }}
    end
  end

  defp soma(resultado, chave), do: resultado |> Enum.map(&Map.get(&1, chave, 0)) |> Enum.sum()

  # ------------------------------------------------------ primeira passada: os quadros

  defp buscar_quadros(ctx, cursor \\ nil, acumulado \\ []) do
    vars = %{organization: ctx.tool.organization_login, after: cursor}

    case Client.graphql(ctx.tool.instance_url, ctx.token, ler(:quadros), vars) do
      {:ok, %{data: %{"organization" => %{"projectsV2" => pagina}}}} ->
        acumulado = acumulado ++ (pagina["nodes"] || [])

        if get_in(pagina, ["pageInfo", "hasNextPage"]) do
          buscar_quadros(ctx, get_in(pagina, ["pageInfo", "endCursor"]), acumulado)
        else
          {:ok, acumulado}
        end

      {:error, motivo} ->
        {:error, motivo}

      # Resposta de forma inesperada devolve erro nomeando o que veio — a fase falha, o
      # motivo vai para o log, e a coleta seguinte tenta de novo. Sem isto, um
      # CaseClauseError derrubava a sincronização inteira.
      outro ->
        {:error, {:resposta_inesperada, outro}}
    end
  end

  defp percorrer_quadro(ctx, quadro, mapeamentos) do
    {:ok, observado} =
      Projects.record_observed_project(ctx.tenant, %{
        connected_tool_id: ctx.tool.id,
        number: quadro["number"],
        title: quadro["title"],
        closed: quadro["closed"] || false,
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        source_external_id: quadro["id"],
        collected_at: ctx.started_at
      })

    campos = get_in(quadro, ["fields", "nodes"]) || []
    definicoes = gravar_campos(ctx, observado, campos)
    {sprints, intended} = gravar_iteracoes(ctx, observado, quadro, campos)

    {items, drafts, values, links} =
      gravar_itens(ctx, observado, quadro, definicoes, sprints, mapeamentos)

    %{
      fields: map_size(definicoes),
      items: items,
      drafts: drafts,
      values: values,
      sprints: length(sprints),
      intended: intended,
      links: links
    }
  end

  # ------------------------------------------------------------------- os campos

  defp gravar_campos(ctx, observado, campos) do
    for campo <- campos, campo["id"] != nil, into: %{} do
      {:ok, definicao} =
        Projects.record_field_definition(ctx.tenant, %{
          observed_project_id: observado.id,
          field_external_id: campo["id"],
          name: campo["name"],
          data_type: campo["dataType"],
          # Só seleção única tem opções — nos demais fica ausência real.
          options: campo["options"],
          collected_at: ctx.started_at
        })

      {campo["id"], definicao}
    end
  end

  # ----------------------------------------------------------------- as iterações

  defp gravar_iteracoes(ctx, observado, quadro, campos) do
    iteracoes =
      for campo <- campos,
          campo["__typename"] == "ProjectV2IterationField",
          config = campo["configuration"] || %{},
          {iteracao, concluida?} <-
            Enum.map(config["iterations"] || [], &{&1, false}) ++
              Enum.map(config["completedIterations"] || [], &{&1, true}) do
        {:ok, resultado} =
          Projects.record_iteration(ctx.tenant, %{
            observed_project_id: observado.id,
            iteration_external_id: iteracao["id"],
            field_external_id: campo["id"],
            board_number: quadro["number"],
            board_title: quadro["title"],
            field_name: campo["name"],
            title: iteracao["title"],
            start_date: Date.from_iso8601!(iteracao["startDate"]),
            # A duração da ITERAÇÃO, não a do campo: Sprint 10 tem 3 dias num campo de 14.
            duration_days: iteracao["duration"],
            completed: concluida?,
            connected_tool_id: ctx.tool.id,
            source_system: "github",
            source_instance: ctx.tool.instance_url,
            # O id da iteração é curto e local ao campo — compor com o id do campo é o
            # que impede dois campos do mesmo quadro colidirem (decisão da 024, mantida).
            source_external_id: "#{campo["id"]}:#{iteracao["id"]}",
            collected_at: ctx.started_at
          })

        contar_sprint(ctx, resultado)
        resultado
      end

    sprints =
      for %{promoted_to: {:sprint, sprint_id}, iteration: it} <- iteracoes,
          do: {it, sprint_id}

    intended = Enum.count(iteracoes, &match?(%{promoted_to: {:intended_process, _}}, &1))

    marcar_iteracoes_ausentes(ctx, observado, iteracoes)

    {sprints, intended}
  end

  defp contar_sprint(ctx, %{promoted_to: {:sprint, _}}),
    do: ctx.sync |> Ingestion.reload() |> Ingestion.tally(:updated)

  defp contar_sprint(_ctx, _), do: :ok

  # FR-031: a iteração que sumiu da configuração é marcada — **por quadro observado
  # nesta execução**, nunca por tenant (L19: marcaria quadros que a execução não olhou).
  defp marcar_iteracoes_ausentes(ctx, observado, iteracoes) do
    vistas = MapSet.new(iteracoes, & &1.iteration.id)

    ctx.tenant
    |> Projects.list_iterations(observado.id)
    |> Enum.reject(&(&1.id in vistas or &1.no_longer_in_configuration_at != nil))
    |> Enum.each(fn sumida ->
      {:ok, _} = Projects.record_iteration_absent(ctx.tenant, sumida.id, ctx.started_at)
    end)
  end

  # ------------------------------------------------------------ os itens e valores

  defp gravar_itens(ctx, observado, quadro, definicoes, sprints, mapeamentos) do
    case paginar_itens(ctx, quadro["number"]) do
      {:ok, itens} ->
        externos = WorkItems.issue_ids_by_external_id(ctx.tenant)

        gravados =
          for item <- itens do
            gravar_item(ctx, observado, item, externos, definicoes, mapeamentos)
          end

        links = vincular_sprints(ctx, sprints, itens, externos)

        {
          length(gravados),
          Enum.count(gravados, & &1.rascunho),
          Enum.sum(Enum.map(gravados, & &1.valores)),
          links
        }

      # A consulta falhou, e por isso nada é marcado nem contado: uma falha de rede não
      # pode virar "os itens saíram do quadro".
      {:error, motivo} ->
        Logger.warning(
          "itens do quadro ##{quadro["number"]} não vieram: " <> inspect(motivo, limit: 3)
        )

        {0, 0, 0, 0}
    end
  end

  defp gravar_item(ctx, observado, item, externos, definicoes, mapeamentos) do
    tipo = get_in(item, ["content", "__typename"])
    issue_id = externos[get_in(item, ["content", "id"])]
    rascunho = tipo == "DraftIssue"

    {:ok, gravado} =
      Projects.record_item(ctx.tenant, %{
        observed_project_id: observado.id,
        collected_issue_id: unless(rascunho, do: issue_id),
        is_draft: rascunho,
        source_system: "github",
        source_instance: ctx.tool.instance_url,
        source_external_id: item["id"],
        collected_at: ctx.started_at
      })

    valores =
      for valor <- get_in(item, ["fieldValues", "nodes"]) || [],
          campo_id = get_in(valor, ["field", "id"]),
          definicao = definicoes[campo_id],
          bruto = valor_bruto(valor),
          bruto != %{} do
        {:ok, _} =
          Projects.record_item_field_value(ctx.tenant, %{
            project_item_id: gravado.id,
            project_field_definition_id: definicao.id,
            raw_value: bruto,
            # Só com mapeamento declarado (FR-024) — e a FR-046 mora na comparação de
            # tipo: seleção única mapeada para atributo numérico fica crua, recusada.
            interpreted_as:
              Projects.interpretation_for(mapeamentos, campo_id, definicao.data_type),
            collected_at: ctx.started_at
          })

        :ok
      end

    %{rascunho: rascunho, valores: length(valores)}
  end

  # O valor vai CRU, na forma que o tipo do campo devolve. Nenhuma conversão aqui:
  # converter é interpretação, e interpretação exige mapeamento declarado.
  defp valor_bruto(%{"__typename" => "ProjectV2ItemFieldTextValue"} = v),
    do: %{"text" => v["text"]}

  defp valor_bruto(%{"__typename" => "ProjectV2ItemFieldNumberValue"} = v),
    do: %{"number" => v["number"]}

  defp valor_bruto(%{"__typename" => "ProjectV2ItemFieldDateValue"} = v),
    do: %{"date" => v["date"]}

  defp valor_bruto(%{"__typename" => "ProjectV2ItemFieldSingleSelectValue"} = v),
    do: %{"name" => v["name"], "optionId" => v["optionId"]}

  defp valor_bruto(%{"__typename" => "ProjectV2ItemFieldIterationValue"} = v),
    do: %{
      "title" => v["title"],
      "iterationId" => v["iterationId"],
      "startDate" => v["startDate"],
      "duration" => v["duration"]
    }

  defp valor_bruto(_), do: %{}

  # --------------------------------------------- os vínculos issue↔sprint, da 024

  # O mesmo desenho de GithubSprints.vincular/3: o vínculo continua em
  # sro_sprint_issues, porque as telas de sprint (023, 024) leem de lá — e a marca de
  # ausência continua por sprint.
  defp vincular_sprints(ctx, sprints, itens, externos) do
    por_iteracao =
      Map.new(sprints, fn {it, sprint_id} -> {it.iteration_external_id, sprint_id} end)

    vinculos =
      for item <- itens,
          issue_id = externos[get_in(item, ["content", "id"])],
          not is_nil(issue_id),
          valor <- get_in(item, ["fieldValues", "nodes"]) || [],
          valor["__typename"] == "ProjectV2ItemFieldIterationValue",
          sprint_id = por_iteracao[valor["iterationId"]],
          not is_nil(sprint_id) do
        {:ok, _} = SRO.place_issue_in_sprint(ctx.tenant, sprint_id, issue_id)
        {sprint_id, issue_id}
      end

    observadas = Enum.group_by(vinculos, &elem(&1, 0), &elem(&1, 1))

    for {_it, sprint_id} <- sprints do
      {:ok, _} =
        SRO.mark_issues_no_longer_in_sprint(
          ctx.tenant,
          sprint_id,
          Map.get(observadas, sprint_id, []),
          ctx.started_at
        )
    end

    length(vinculos)
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

      {:error, motivo} ->
        {:error, motivo}

      outro ->
        {:error, {:resposta_inesperada, outro}}
    end
  end

  # Os arquivos são fixos — nada de nome interpolado de entrada externa.
  @sobelow_skip ["Traversal.FileModule"]
  defp ler(consulta) do
    arquivo =
      case consulta do
        :quadros -> "project_boards.graphql"
        :itens -> "project_items_full.graphql"
      end

    :the_band
    |> :code.priv_dir()
    |> Path.join("connectors/github/queries/#{arquivo}")
    |> File.read!()
  end
end
