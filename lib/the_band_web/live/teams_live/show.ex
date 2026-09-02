defmodule TheBandWeb.TeamsLive.Show do
  @moduledoc """
  `/teams/:id` — integrantes observados de uma equipe (US3).

  O nível de acesso é rotulado como **acesso na plataforma**, nunca como papel ou
  cargo. O rótulo é parte do contrato: chamá-lo de papel na tela desfaria na
  interface a distinção que o modelo se deu ao trabalho de preservar.
  """

  use TheBandWeb, :live_view

  import TheBandWeb.Components.DataTable

  alias TheBand.Forecast
  alias TheBand.Mapping.Antipatterns
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Profiles
  alias TheBand.Tenants
  alias TheBand.WorkItems
  alias TheBandWeb.TabelaLive, as: Tabela

  # Oito semanas. Escolher o período é trabalho separado, e um seletor sem
  # período fechado reabriria a questão do denominador móvel (L86).
  @janela_em_dias 56
  @por_pagina 50

  # O papel organizacional fica fora das colunas ordenáveis: ele é **derivado** de haver ou não
  # vínculo promovido, e não coluna da consulta. Ordenar por ele exigiria ordenar por uma
  # ausência, o que a lista já diz em texto.
  @tabelas [{"members", [:name, :platform_access_level, :observed_at, :last_observed_at], nil}]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case Enum.find(EO.list_teams(tenant), &(&1.id == id)) do
      # FR-027 — id de outro tenant não devolve o registro; devolve 404.
      nil ->
        {:ok,
         socket
         |> put_flash(:error, dgettext("errors", "Team not found."))
         |> push_navigate(to: ~p"/teams")}

      team ->
        {:ok, assign(socket, page_title: team.name, team: team)}
    end
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{team: nil}} = socket), do: {:noreply, socket}

  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Tabela.aplicar(params, @tabelas) |> load()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("ordenar", params, socket), do: Tabela.ordenar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  def handle_event(
        "associar_projeto",
        %{"project_id" => pid},
        %{assigns: %{current_user: %{role: "admin"}}} = socket
      )
      when pid != "" do
    {:ok, _} =
      SPO.link_team(
        socket.assigns.current_tenant,
        pid,
        socket.assigns.team.id,
        socket.assigns.current_user.id
      )

    {:noreply, carregar_projetos(socket)}
  end

  # A subequipe HERDA a organização da mãe, e isso não é conveniência: quem tem
  # escopo nesta equipe declara DENTRO dela, e não em qualquer lugar da
  # organização. Oferecer um seletor de organização aqui faria a autoridade subir.
  def handle_event("criar_subequipe", %{"name" => nome}, socket) do
    tenant = socket.assigns.current_tenant
    mae = socket.assigns.team
    ator = socket.assigns.current_user

    case Tenants.pode_declarar_estrutura(tenant, ator, :organization, mae.organization_id) do
      {:ok, _} ->
        with {:ok, filha} <-
               EO.declare_structural_team(tenant, mae.organization_id, String.trim(nome), ator.id),
             {:ok, _} <- EO.compose_teams(tenant, filha.id, mae.id, ator.id) do
          {:noreply,
           socket
           |> put_flash(
             :info,
             dgettext("sistema", "Team %{nome} declared inside this one.", nome: filha.name)
           )
           |> load()}
        else
          {:error, motivo} when is_binary(motivo) -> {:noreply, put_flash(socket, :error, motivo)}
        end

      {:nao, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("errors", "You have no scope to declare a team here.")
         )}
    end
  end

  def handle_event("descompor", %{"part_id" => parte}, socket) do
    tenant = socket.assigns.current_tenant
    mae = socket.assigns.team
    ator = socket.assigns.current_user

    case Tenants.pode_declarar_estrutura(tenant, ator, :organization, mae.organization_id) do
      {:ok, _} ->
        case EO.decompose_teams(tenant, parte, mae.id, ator.id) do
          {:ok, _} ->
            {:noreply,
             socket |> put_flash(:info, dgettext("sistema", "Composition ended.")) |> load()}

          {:error, motivo} ->
            {:noreply, put_flash(socket, :error, motivo)}
        end

      {:nao, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("errors", "You have no scope to declare a team here.")
         )}
    end
  end

  def handle_event("associar_projeto", _params, socket), do: {:noreply, socket}

  def handle_event(
        "desassociar_projeto",
        %{"link_id" => lid},
        %{assigns: %{current_user: %{role: "admin"}}} = socket
      ) do
    {:ok, _} =
      SPO.unlink_team(socket.assigns.current_tenant, lid, socket.assigns.current_user.id)

    {:noreply, carregar_projetos(socket)}
  end

  def handle_event("promover", params, socket) do
    escolhas = escolhas_de(params)

    resultados =
      Enum.map(escolhas, fn {evidence_id, papel, data} ->
        EO.promote_evidence(
          socket.assigns.current_tenant,
          evidence_id,
          papel_escolhido(papel),
          socket.assigns.current_user.id,
          started_at: data_ou_nil(data)
        )
      end)

    {:noreply,
     socket
     |> put_flash(tipo_do_resultado(resultados), frase_do_resultado(resultados, params))
     |> load()}
  end

  # As linhas escolhidas, na forma `{evidence_id, papel, data}`.
  #
  # `apenas` diz o que o botão pediu: um id de evidência, ou `"todas"`. E **linha sem papel
  # escolhido não entra** — é o que faz "confirmar todas" pular em vez de recusar.
  defp escolhas_de(%{"apenas" => "todas"} = params) do
    papeis = Map.get(params, "papel", %{})
    datas = Map.get(params, "started_at", %{})

    papeis
    |> Enum.reject(fn {_id, papel} -> papel in [nil, ""] end)
    |> Enum.map(fn {id, papel} -> {id, papel, Map.get(datas, id)} end)
  end

  defp escolhas_de(%{"apenas" => id} = params) do
    papel = get_in(params, ["papel", id])

    if papel in [nil, ""],
      do: [],
      else: [{id, papel, get_in(params, ["started_at", id])}]
  end

  defp escolhas_de(_), do: []

  # **Nenhum desfecho some.** Confirmadas, puladas e recusadas aparecem na mesma frase — e a
  # contagem de puladas é o que impede quem clicou em "confirmar todas" de achar que
  # confirmou tudo.
  defp frase_do_resultado([], %{"apenas" => "todas"} = params) do
    quantas = params |> Map.get("papel", %{}) |> map_size()

    dgettext("errors", "Nothing confirmed: no role was chosen in any of the %{quantas} rows.",
      quantas: quantas
    )
  end

  defp frase_do_resultado([], _params),
    do: dgettext("errors", "Choose a role before confirming.")

  defp frase_do_resultado(resultados, params) do
    ok = Enum.count(resultados, &match?({:ok, _}, &1))
    erros = Enum.reject(resultados, &match?({:ok, _}, &1))

    puladas =
      case params do
        %{"apenas" => "todas"} ->
          params |> Map.get("papel", %{}) |> map_size() |> Kernel.-(length(resultados))

        _ ->
          0
      end

    [
      dgettext("sistema", "%{ok} membership(s) recorded", ok: ok),
      puladas > 0 &&
        dgettext("sistema", "%{puladas} skipped for having no role chosen", puladas: puladas),
      erros != [] &&
        dgettext("errors", "%{quantos} refused: %{motivos}",
          quantos: length(erros),
          motivos: Enum.map_join(erros, "; ", &motivo/1)
        )
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  # Erro entre acertos ainda é erro: a cor da mensagem segue o pior desfecho, e não o
  # primeiro. Uma linha recusada no meio de nove aceitas passaria batida em verde.
  defp tipo_do_resultado(resultados) do
    if Enum.any?(resultados, &(not match?({:ok, _}, &1))), do: :error, else: :info
  end

  # Cada recusa vira uma FRASE. Um código de motivo na tela obrigaria quem lê a procurar o
  # que ele significa.
  defp motivo({:error, :role_from_another_organization}),
    do: "that role belongs to another organisation"

  defp motivo({:error, :already_promoted}), do: "already became a membership"
  defp motivo({:error, :no_longer_observed}), do: "the source no longer shows this person here"
  defp motivo({:error, :already_allocated}), do: "this person already holds that role here"
  defp motivo({:error, outro}), do: inspect(outro)

  defp caminho(socket, id, mudancas),
    do: ~p"/teams/#{socket.assigns.team.id}?#{Tabela.query(socket, id, mudancas)}"

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    team = socket.assigns.team
    estado = socket.assigns.tabelas["members"]

    opts = [search: estado.busca]

    socket
    |> assign(por_pagina: @por_pagina)
    |> assign(
      members:
        EO.list_team_members(
          tenant,
          team.id,
          opts ++
            [
              order_by: estado.ordem,
              limit: @por_pagina,
              offset: (estado.pagina - 1) * @por_pagina
            ]
        )
    )
    |> assign(encontradas: EO.count_team_members(tenant, team.id, opts))
    |> assign(pending_role: EO.count_evidence_pending_role(tenant, team_id: team.id))
    |> carregar_promocao()
    |> carregar_competencias()
  end

  # Campo vazio é **desconhecido**, e nunca a data de hoje. Inventá-la afirmaria que a pessoa
  # assumiu o papel agora, e o que se sabe é que ninguém disse quando.
  defp data_ou_nil(""), do: nil
  defp data_ou_nil(nil), do: nil

  defp data_ou_nil(texto) do
    case Date.from_iso8601(texto) do
      {:ok, data} -> DateTime.new!(data, ~T[00:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  # Issue #317: as evidências que esperam confirmação, e os papéis com que confirmá-las.
  #
  # `pending_evidence/2` **não devolve** o nível de acesso da plataforma. A garantia é do
  # contrato, e não desta função: nenhum template pode exibir o que não chega até ele.
  defp carregar_promocao(socket) do
    tenant = socket.assigns.current_tenant
    team = socket.assigns.team

    papeis =
      if team.organization_id,
        do:
          tenant
          |> EO.list_organization_roles(team.organization_id)
          |> Enum.reject(& &1.hidden_at),
        else: []

    partes = EO.team_parts(tenant, team.id)

    socket
    |> assign(contem: partes)
    |> assign(faz_parte_de: EO.team_wholes(tenant, team.id))
    |> carregar_linhas(partes)
    |> assign(pendentes: EO.pending_evidence(tenant, team.id))
    |> assign(papeis_para_promover: papeis)
  end

  # As linhas da equipe COMPOSTA — feature 057, US2.
  #
  # Uma linha por subequipe, mais a dos membros diretos. **Nenhum total**: a mesma
  # pessoa pode pertencer a duas subequipes e a mesma tarefa aparecer nas duas, e
  # somar contaria duas vezes.
  #
  # `composta?` exige DUAS ou mais partes. Com uma só, a equipe segue como simples
  # com uma composição declarada — comparar uma linha com nada não é comparação.
  #
  # A ordem é por trabalho parado, do maior para o menor (SC-005): sem critério
  # declarado, "identificar em menos de 30 segundos" depende de sorte na ordem
  # alfabética. Ordenar NÃO é somar — cada linha continua com o número dela.
  defp carregar_linhas(socket, partes) when length(partes) < 2 do
    socket
    |> assign(composta?: false, linhas: [])
    |> carregar_detalhe()
  end

  defp carregar_linhas(socket, partes) do
    tenant = socket.assigns.current_tenant
    team = socket.assigns.team
    agora = DateTime.utc_now()

    subequipes =
      Enum.map(partes, fn p ->
        tenant
        |> WorkItems.team_snapshot(p.team_id, agora)
        |> Map.merge(%{nome: p.name, direta?: false})
      end)

    diretos =
      tenant
      |> WorkItems.team_snapshot(team.id, agora)
      |> Map.merge(%{nome: team.name <> " · direct members", direta?: true})

    linhas = Enum.sort_by(subequipes, & &1.paradas, :desc) ++ [diretos]

    # A tela composta é para comparar. O detalhe — séries, burn, previsão e
    # pessoas — vive na tela de cada subequipe (FR-011).
    assign(socket, composta?: true, linhas: linhas, detalhe: nil)
  end

  # O DETALHE da subequipe — feature 057, US3, US4, US5 e US6.
  #
  # Só carrega quando a equipe NÃO é composta: são as duas telas que a spec
  # descreve, e a rota é uma só porque a pergunta é uma só — como está esta
  # equipe. O que muda é o que a equipe é.
  defp carregar_detalhe(socket) do
    tenant = socket.assigns.current_tenant
    team = socket.assigns.team
    agora = DateTime.utc_now()
    desde = DateTime.add(agora, -@janela_em_dias, :day)

    serie =
      WorkItems.team_state_changes_by_period(tenant, team.id, :semana,
        desde: desde,
        ate: agora
      )

    aberto_inicial = WorkItems.team_open_at(tenant, team.id, desde)
    tarefas = WorkItems.team_open_tasks_by_person(tenant, team.id, agora)
    membros = EO.team_members_at(tenant, team.id, agora)

    assign(socket,
      detalhe: %{
        serie: serie,
        burn: WorkItems.burn(serie, aberto_inicial),
        aberto_inicial: aberto_inicial,
        previsao:
          Forecast.monte_carlo(serie, aberto: WorkItems.team_open_at(tenant, team.id, agora)),
        piso: Forecast.piso(),
        pessoas: Enum.map(membros, &Map.put(&1, :tarefas, Map.get(tarefas, &1.person_id, [])))
      }
    )
  end

  # ------------------------------------------- as seções do detalhe (feature 057)

  # O BURN — feature 057, US5. Duas séries num ÚNICO eixo, e o que resta como a
  # REGIÃO entre elas, hachurada porque é derivada (FR-027).
  #
  # Uma terceira linha desenharia o mesmo fato duas vezes e convidaria a lê-la
  # contra uma linha de base que ela não tem. O campo `aberto` existe e é o mesmo
  # número que a altura da faixa representa — o que a regra proíbe é apresentá-lo
  # como série.
  attr :detalhe, :map, required: true

  defp burn_da_equipe(assigns) do
    assigns = assign(assigns, :pontos, pontos_do_burn(assigns.detalhe.burn))

    ~H"""
    <section class="card bg-base-200 p-4">
      <h2 class="text-sm font-semibold">Burn-up and burn-down</h2>
      <p class="mt-1 text-xs opacity-70">
        8 weeks · cumulative opened and closed. The hatched band between them is the work
        still open — it is derived from the two series, not a third line.
      </p>

      <p :if={@detalhe.serie == []} class="mt-3 text-sm opacity-70">
        No week of this team falls inside the collected period, so there is no series to
        draw — which is not the same as a series of zeros.
      </p>

      <svg
        :if={@pontos}
        viewBox="0 0 560 170"
        class="mt-3 w-full"
        role="img"
        aria-label={"Cumulative opened and closed over #{length(@detalhe.burn)} weeks. The band between them is the work still open, #{@pontos.aberto_final} at the end."}
      >
        <defs>
          <pattern
            id="burn-hachura"
            width="6"
            height="6"
            patternTransform="rotate(135)"
            patternUnits="userSpaceOnUse"
          >
            <line
              x1="0"
              y1="0"
              x2="0"
              y2="6"
              stroke="currentColor"
              stroke-width="1.4"
              class="text-primary"
              opacity="0.38"
            />
          </pattern>
        </defs>
        <polygon points={@pontos.faixa} fill="url(#burn-hachura)" />
        <polyline
          points={@pontos.escopo}
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class="text-primary"
        />
        <polyline
          points={@pontos.feito}
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class="text-warning"
        />
      </svg>

      <div :if={@pontos} class="mt-2 flex flex-wrap gap-4 text-xs">
        <span class="flex items-center gap-1.5">
          <span class="inline-block h-1 w-4 rounded bg-primary"></span> opened, cumulative
        </span>
        <span class="flex items-center gap-1.5">
          <span class="inline-block h-1 w-4 rounded bg-warning"></span> closed, cumulative
        </span>
        <span class="opacity-70">
          still open: <span class="font-mono tabular-nums">{@pontos.aberto_final}</span>
        </span>
      </div>

      <details :if={@pontos} class="mt-2">
        <summary class="cursor-pointer text-xs opacity-70">see as a table</summary>
        <table class="table table-xs mt-2">
          <thead>
            <tr>
              <th>week</th><th class="text-right">opened</th><th class="text-right">closed</th><th class="text-right">
                still open
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={b <- @detalhe.burn}>
              <td class="font-mono text-xs">{b.periodo}</td>
              <td class="text-right font-mono tabular-nums">{b.escopo}</td>
              <td class="text-right font-mono tabular-nums">{b.feito}</td>
              <td class="text-right font-mono tabular-nums">{b.aberto}</td>
            </tr>
          </tbody>
        </table>
      </details>

      <div class="mt-3 rounded border border-dashed border-base-300 p-3 text-sm">
        <p>
          The cumulative opened starts at
          <span class="font-mono tabular-nums">{@detalhe.aberto_inicial}</span>
          —
          the items already open when the window began. Starting from zero would measure only
          the items born inside these eight weeks, and call that the open work.
        </p>
        <p class="mt-2 opacity-80">
          There is <strong>no committed scope</strong> here, so this does not answer whether a
          sprint finishes. And <em>closed</em> is the issue being closed at the source — an act
          of the tool, not a declared end criterion. A task abandoned and one finished look the
          same here.
        </p>
      </div>
    </section>
    """
  end

  # A PREVISÃO — feature 057, US6. Faixa com sua confiança, nunca data.
  attr :detalhe, :map, required: true

  defp previsao_da_equipe(assigns) do
    ~H"""
    <section class="card bg-base-200 p-4">
      <h2 class="text-sm font-semibold">Delivery forecast</h2>
      <div class="mt-1">
        <span class="badge badge-outline badge-sm gap-1 text-warning">
          <span class="size-2.5 shrink-0 rounded-[1px] outline outline-1 -outline-offset-1 outline-current bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"></span>
          derived — simulated from this team's own history
        </span>
      </div>

      <%!-- Abaixo do piso a plataforma RECUSA e diz o que falta. Uma faixa larga
            apresentada com rótulo de 85% empresta autoridade a ruído. --%>
      <div :if={match?({:sem_historico, _}, @detalhe.previsao)} class="mt-3 text-sm">
        <% {:sem_historico, falta} = @detalhe.previsao %>
        <p>
          <strong>No forecast yet.</strong>
          It needs <span class="font-mono tabular-nums">{falta.semanas_exigidas}</span>
          weeks of history and <span class="font-mono tabular-nums">{falta.fechadas_exigidas}</span>
          closed items; this team has <span class="font-mono tabular-nums">{falta.semanas}</span>
          and <span class="font-mono tabular-nums">{falta.fechadas}</span>.
        </p>
        <p class="mt-2 opacity-80">
          Below that, the range would cover almost the whole horizon. Refusing says more than a
          number nobody could act on.
        </p>
      </div>

      <div :if={match?({:ok, _}, @detalhe.previsao)} class="mt-3 space-y-3">
        <% {:ok, p} = @detalhe.previsao %>
        <p class="text-sm opacity-80">
          {p.rodadas} runs, each drawing a week of throughput at random from the weeks this team
          actually had. No estimates.
        </p>

        <table class="table table-sm">
          <thead>
            <tr>
              <th>hypothesis</th><th class="text-right">50%</th><th class="text-right">85%</th><th class="text-right">
                95%
              </th><th class="text-right">did not finish</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>if nothing new opened</td>
              <td class="text-right font-mono tabular-nums">{semana_ou_traco(p.congelado.p50)}</td>
              <td class="text-right font-mono tabular-nums">{semana_ou_traco(p.congelado.p85)}</td>
              <td class="text-right font-mono tabular-nums">{semana_ou_traco(p.congelado.p95)}</td>
              <td class="text-right font-mono tabular-nums">{p.congelado.nao_concluiram}</td>
            </tr>
            <tr>
              <td>if work keeps arriving as it has</td>
              <td class="text-right font-mono tabular-nums">{semana_ou_traco(p.vivo.p50)}</td>
              <td class="text-right font-mono tabular-nums">{semana_ou_traco(p.vivo.p85)}</td>
              <td class="text-right font-mono tabular-nums">{semana_ou_traco(p.vivo.p95)}</td>
              <td class="text-right font-mono tabular-nums">{p.vivo.nao_concluiram}</td>
            </tr>
          </tbody>
        </table>

        <div class="rounded border border-dashed border-base-300 p-3 text-sm">
          <p>
            Work arrives at
            <span class="font-mono tabular-nums">{Float.round(p.ritmo.abre_por_semana, 1)}</span>
            a week and leaves at <span class="font-mono tabular-nums">{Float.round(p.ritmo.fecha_por_semana, 1)}</span>.
            The two hypotheses answer different questions, and both can be true at once.
          </p>
          <p class="mt-2 opacity-80">
            A dash means <strong>unknown</strong>, not far away: those runs did not finish inside
            the {p.horizonte_semanas}-week horizon, and a large number would read as a date.
          </p>
          <p class="mt-2 opacity-80">
            Read <em>85%</em> as the line from what we have seen — never as a date that was
            promised. The simulation assumes the period ahead resembles the one observed: same
            people, same kind of work.
          </p>
        </div>
      </div>
    </section>
    """
  end

  # AS PESSOAS — feature 057, US4. TODAS as tarefas abertas, e nenhuma eleita
  # como "atual": qual delas é a atual é julgamento que o dado não faz.
  attr :detalhe, :map, required: true

  defp pessoas_da_equipe(assigns) do
    ~H"""
    <section class="card bg-base-200 p-4">
      <h2 class="text-sm font-semibold">What each person is on</h2>
      <p class="mt-1 text-xs opacity-70">
        Every open task assigned, with how long it has been open. Time counts from when the
        item was opened — the source does not record when someone took it on.
      </p>

      <p :if={@detalhe.pessoas == []} class="mt-3 text-sm opacity-70">
        No one has a declared membership in this team right now.
      </p>

      <div :for={p <- @detalhe.pessoas} class="mt-3 border-t border-base-300 pt-2">
        <div class="flex flex-wrap items-baseline gap-2">
          <.link navigate={~p"/people/#{p.person_id}"} class="link link-hover font-semibold">
            {p.name || p.login}
          </.link>
          <span :if={is_nil(p.started_at)} class="badge badge-ghost badge-xs">
            start date unknown
          </span>
        </div>

        <%!-- Ausência DITA, e a pessoa não some da lista (FR-021). --%>
        <p :if={p.tarefas == []} class="ml-4 text-sm opacity-70">No open task assigned</p>

        <div :for={t <- p.tarefas} class="ml-4 flex flex-wrap items-baseline gap-2 text-sm">
          <span class="font-mono text-xs opacity-70">{t.external_id}</span>
          <.link navigate={~p"/work/issues/#{t.issue_id}"} class="link link-hover flex-1">
            {t.titulo}
          </.link>
          <span class={["font-mono text-xs tabular-nums", t.parada? && "font-semibold text-warning"]}>
            {t.aberta_ha_dias}d
          </span>
          <span :if={t.parada?} class="badge badge-outline badge-xs text-warning">stale</span>
        </div>
      </div>

      <div class="mt-3 rounded border border-dashed border-base-300 p-3 text-sm">
        <p>
          A task with more than one person responsible <strong>appears once for each</strong>.
          Summing these lines would overcount the team, and the team's own numbers are measured
          separately rather than derived from them.
        </p>
        <p class="mt-2 opacity-80">
          <em>Stale</em> past 90 days is an invitation to ask, not a verdict: it says the board
          has not been told anything about that item in three months.
        </p>
      </div>
    </section>
    """
  end

  # A geometria do burn, calculada aqui e não no template: o template desenha o
  # que recebe, e uma expressão aritmética dentro do HEEx é onde erro de eixo se
  # esconde.
  defp pontos_do_burn([]), do: nil

  defp pontos_do_burn(burn) do
    largura = 560
    altura = 150
    limite = max(Enum.max(Enum.map(burn, & &1.escopo)), 1) * 1.12
    passo = if length(burn) > 1, do: largura / (length(burn) - 1), else: 0

    coord = fn valores ->
      valores
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {v, i} ->
        "#{Float.round(i * passo, 1)},#{Float.round(altura - v / limite * altura, 1)}"
      end)
    end

    escopo = coord.(Enum.map(burn, & &1.escopo))
    feito = coord.(Enum.map(burn, & &1.feito))

    %{
      escopo: escopo,
      feito: feito,
      faixa: escopo <> " " <> (feito |> String.split(" ") |> Enum.reverse() |> Enum.join(" ")),
      aberto_final: List.last(burn).aberto
    }
  end

  # Traço, e não um número grande: nulo diz desconhecido.
  defp semana_ou_traco(nil), do: "—"
  defp semana_ou_traco(n), do: "week #{n}"

  # O valor do `<option>` carrega a ORIGEM junto do identificador, porque papel do catálogo
  # ainda não usado **não tem id**. Sem isso, a tela teria de materializar antes de promover —
  # e materializar sem promover deixaria lixo se a promoção falhasse.
  defp valor_do_papel(%{id: nil, origem: {:catalogo, conceito}}), do: "catalogo:" <> conceito
  defp valor_do_papel(%{id: id}), do: "existente:" <> id

  defp papel_escolhido("catalogo:" <> conceito), do: {:catalogo, conceito}
  defp papel_escolhido("existente:" <> id), do: {:existente, id}

  # Feature 029: a leitura de competências da equipe — contada dos perfis vigentes,
  # nunca gerada. Carregada no load porque a evolução usa o mesmo histórico.
  defp carregar_competencias(socket) do
    tenant = socket.assigns.current_tenant
    team = socket.assigns.team

    cobertura = Profiles.team_coverage(tenant, team.id)

    membros_ids =
      tenant
      |> EO.list_team_members(team.id, include_no_longer_observed: false)
      |> Enum.map(& &1.person.id)
      |> Enum.uniq()

    socket
    |> assign(cobertura: cobertura)
    |> assign(resumo_equipe: Profiles.team_summary(cobertura))
    |> assign(evolucao: Profiles.team_evolution(tenant, team.id))
    |> assign(antipadroes: Antipatterns.detect_for_team(tenant, membros_ids))
    |> carregar_projetos()
  end

  # Os projetos da equipe — o vínculo é o mesmo da feature 028, agora acessível dos dois
  # lados: quem pensa "o projeto tem equipes" associa em /projects; quem pensa "a equipe
  # trabalha em projetos" associa aqui. Uma tabela só; dois caminhos até ela.
  defp carregar_projetos(socket) do
    tenant = socket.assigns.current_tenant
    team = socket.assigns.team

    vinculados = projetos_da_equipe(tenant, team.id)
    ids = MapSet.new(vinculados, & &1.project_id)

    socket
    |> assign(projetos_da_equipe: vinculados)
    |> assign(projetos_disponiveis: Enum.reject(SPO.list_projects(tenant), &(&1.id in ids)))
  end

  defp projetos_da_equipe(tenant, team_id), do: SPO.list_team_projects(tenant, team_id)

  # A seta diz a direção sem obrigar a comparar os dois números — e igual é travessão,
  # nunca seta para não sugerir movimento que não houve (#403, mockup da proposta 029).
  defp tendencia(%{primeiro: p, ultimo: u}) when u > p, do: "▲"
  defp tendencia(%{primeiro: p, ultimo: u}) when u < p, do: "▼"
  defp tendencia(_), do: "—"

  # As competências que a evolução acompanha: as do topo da cobertura de hoje.
  defp series_de_evolucao(cobertura, evolucao) do
    nomes = cobertura.competencias |> Enum.take(5) |> Enum.map(& &1.nome)

    for nome <- nomes do
      pontos = Enum.map(evolucao, &Map.get(&1.cobertura, nome, 0))
      %{nome: nome, pontos: pontos, primeiro: List.first(pontos, 0), ultimo: List.last(pontos, 0)}
    end
  end

  defp titulo_do_antipadrao("process.ap01.closed_without_movement"),
    do: "Closed without ever being moved"

  defp titulo_do_antipadrao("process.ap02.moved_after_closing"),
    do: "Moved after it was closed"

  defp titulo_do_antipadrao("process.ap03.assigned_and_never_started"),
    do: "Assigned and never started"

  defp titulo_do_antipadrao("process.ap04.movement_without_assignee"),
    do: "Moved with nobody assigned"

  defp titulo_do_antipadrao(id), do: id

  # A matriz só ganha colunas quando algum domínio alcança DUAS pessoas — antes disso,
  # colunas de domínios únicos escondem todo mundo que não é dono delas.
  defp matriz_agrega?(cobertura),
    do: Enum.any?(cobertura.competencias, &(&1.total_pessoas >= 2))

  # As linhas da matriz: uma por pessoa com perfil, alfabética, com o mapa nome→tarefas.
  defp pessoas_da_matriz(cobertura) do
    cobertura.competencias
    |> Enum.flat_map(fn c -> Enum.map(c.pessoas, &{&1, c.nome}) end)
    |> Enum.group_by(fn {p, _} -> {p.person_id, p.name} end, fn {p, nome} -> {nome, p.tarefas} end)
    |> Enum.map(fn {{pid, name}, pares} ->
      %{person_id: pid, name: name, tarefas: Map.new(pares)}
    end)
    |> Enum.sort_by(& &1.name)
  end

  # O polyline do sparkline: x distribuído, y invertido (0 embaixo), com margem.
  defp sparkline(pontos) do
    maximo = max(Enum.max(pontos, fn -> 1 end), 1)
    n = length(pontos)

    pontos
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {v, i} ->
      x = if n == 1, do: 100, else: 4 + i * (192 / (n - 1))
      y = 23 - v / maximo * 18
      "#{Float.round(x * 1.0, 1)},#{Float.round(y * 1.0, 1)}"
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_tenant={@current_tenant}
      nav_area={assigns[:nav_area]}
      operacao_menu={assigns[:operacao_menu]}
    >
      <.breadcrumb niveis={[
        %{rotulo: "Teams", destino: ~p"/teams"},
        %{rotulo: @team.name, destino: nil}
      ]} />
      <.header>
        {@team.name}
        <:subtitle>
          {@encontradas} {if @encontradas == 1, do: "member", else: "members"} · {@pending_role} with no organisational role assigned
        </:subtitle>
      </.header>

      <%!-- A EQUIPE COMPOSTA — feature 057, US2. Uma linha por subequipe, mais a
            dos membros diretos, e NENHUM total.

            Não somar é decisão, e não lacuna: a mesma pessoa pode pertencer a duas
            subequipes e a mesma tarefa aparecer nas duas. O texto abaixo da tabela
            diz isso, porque sem ele a ausência de total parece esquecimento e
            alguém acrescenta o total depois.

            **Nenhum gráfico aqui** (FR-011): esta tela é para comparar, e
            comparação se faz em números alinhados. Os gráficos vivem na tela da
            subequipe. --%>
      <section :if={@composta?} class="card bg-base-200 p-4">
        <h2 class="text-sm font-semibold">Teams inside this one</h2>
        <p class="mt-1 text-xs opacity-70">
          Ordered by stopped work, so the row that needs a conversation comes first.
        </p>

        <table class="table table-sm mt-3">
          <thead>
            <tr>
              <th>team</th>
              <th class="text-right">members</th>
              <th class="text-right">open</th>
              <th class="text-right">closed · 8w</th>
              <th class="text-right">stopped</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={l <- @linhas}>
              <td>
                <.link :if={not l.direta?} navigate={~p"/teams/#{l.team_id}"} class="link">
                  {l.nome}
                </.link>
                <span :if={l.direta?} class="opacity-80">{l.nome}</span>
              </td>
              <%!-- Ausência NOMEADA, nunca zero (FR-012). Uma subequipe sem trabalho
                    no período não teve zero itens: não houve o que observar, e as
                    duas coisas levam a decisões diferentes. --%>
              <td :if={l.sem_trabalho?} colspan="4" class="text-xs opacity-70">
                No work observed in the period — which is not the same as zero.
              </td>
              <td :if={not l.sem_trabalho?} class="text-right font-mono tabular-nums">
                {l.membros}
              </td>
              <td :if={not l.sem_trabalho?} class="text-right font-mono tabular-nums">
                {l.abertas}
              </td>
              <td :if={not l.sem_trabalho?} class="text-right font-mono tabular-nums">
                {l.fechadas_na_janela}
              </td>
              <td :if={not l.sem_trabalho?} class="text-right font-mono tabular-nums">
                <span class={if l.paradas > 0, do: "text-warning font-semibold"}>{l.paradas}</span>
              </td>
            </tr>
          </tbody>
        </table>

        <div class="mt-3 rounded border border-dashed border-base-300 p-3">
          <h3 class="text-xs font-semibold tracking-wide uppercase opacity-70">
            why these rows are not added up
          </h3>
          <p class="mt-1 text-sm">
            The same person can belong to <strong>two sub-teams</strong>, and the same task can
            appear in both. A total would count each of them twice, and nobody could reconcile
            it with the work that exists. Each row is measured on its own.
          </p>
          <p class="mt-2 text-sm opacity-80">
            Charts live on each sub-team's own screen. This one is for comparing, and comparing
            is done in aligned numbers.
          </p>
        </div>
      </section>

      <%!-- O DETALHE da subequipe. Só existe quando a equipe não é composta: são as
            duas telas da spec, numa rota só, porque a pergunta é a mesma — como
            está esta equipe. --%>
      <div :if={@detalhe} class="space-y-4">
        <.burn_da_equipe detalhe={@detalhe} />
        <.previsao_da_equipe detalhe={@detalhe} />
        <.pessoas_da_equipe detalhe={@detalhe} />
      </div>

      <section class="card bg-base-200 p-4">
        <h2 class="text-sm font-semibold">Structure</h2>

        <div :if={@faz_parte_de != []} class="mt-2 text-sm">
          <span class="opacity-70">Part of:</span>
          <span :for={m <- @faz_parte_de} class="ml-1">
            <.link navigate={~p"/teams/#{m.team_id}"} class="link">{m.name}</.link>
          </span>
        </div>

        <div class="mt-3">
          <span class="text-sm opacity-70">Contains:</span>
          <p :if={@contem == []} class="text-sm opacity-60">
            No team inside this one.
          </p>
          <ul :if={@contem != []} class="mt-1 space-y-1">
            <li :for={f <- @contem} class="flex items-center gap-2 text-sm">
              <.link navigate={~p"/teams/#{f.team_id}"} class="link">{f.name}</.link>
              <span class="opacity-60 text-xs">since {f.desde}</span>
              <button
                phx-click="descompor"
                phx-value-part_id={f.team_id}
                class="btn btn-xs btn-ghost text-error"
                data-confirm="The team keeps existing — only the composition ends."
              >
                remove from here
              </button>
            </li>
          </ul>
        </div>

        <form phx-submit="criar_subequipe" class="mt-4 flex flex-wrap items-end gap-3">
          <label class="form-control">
            <span class="label-text text-xs">Declare a team inside this one</span>
            <input type="text" name="name" required class="input input-sm input-bordered" />
          </label>
          <button type="submit" class="btn btn-sm">Declare inside</button>
          <span class="text-xs opacity-60">
            It inherits this team's organisation — a team is declared inside what you already reach.
          </span>
        </form>
      </section>

      <.data_table
        id="members"
        rows={@members}
        estado={@tabelas["members"]}
        por_pagina={@por_pagina}
        total={@encontradas}
        onde="name and login"
        vazio="This team has no member observed at the source."
        class="table stacked"
      >
        <:col :let={member} field={:name} label="person">
          <%!-- Nome e login levam ao **mesmo** lugar: são duas grafias da mesma pessoa, e
                obrigar quem lê a descobrir qual das duas é clicável seria pedir que ele
                adivinhe. A participação pode ter acabado; a pessoa continua existindo. --%>
          <.link
            navigate={~p"/people/#{member.person.id}"}
            class={[
              "link link-hover font-medium underline decoration-dotted",
              member.no_longer_observed_at && "opacity-50"
            ]}
          >
            {member.person.name}
          </.link>
          <div :if={member.person.login} class="text-xs opacity-60">
            <.link navigate={~p"/people/#{member.person.id}"} class="link link-hover">
              @{member.person.login}
            </.link>
          </div>
          <div :if={member.no_longer_observed_at} class="text-xs opacity-60">
            no longer observed since {member.no_longer_observed_at}
          </div>
        </:col>
        <:col :let={member} field={:platform_access_level} label="access at the platform">
          <span class="badge badge-sm badge-ghost font-mono">
            {member.platform_access_level}
          </span>
        </:col>
        <:col :let={member} label="organisational role">
          <span :if={member.pending_role} class="text-xs opacity-60">pending</span>
          <span :if={!member.pending_role} class="text-xs">assigned</span>
        </:col>
        <:col :let={member} field={:observed_at} label="observed at" class="text-xs">
          {member.observed_at}
        </:col>
        <:col :let={member} field={:last_observed_at} label="last observation" class="text-xs">
          {member.last_observed_at}
        </:col>
      </.data_table>

      <%!-- ═══ A PROMOÇÃO — issue #317 ═══
            Seção separada da tabela de membros, e a separação é o ponto. Ali o nível de
            acesso aparece **rotulado como acesso**, porque é observação. Aqui ele NÃO
            aparece: é onde a decisão de papel acontece, e exibi-lo faria dele uma dica.
            A garantia é do contrato — `pending_evidence/2` não devolve o campo. --%>
      <section :if={@pendentes != []} class="mt-8 space-y-3">
        <h3 class="text-base font-semibold">
          {length(@pendentes)} participation(s) waiting for confirmation
        </h3>
        <p class="text-sm opacity-70">
          The platform observed that these people belong to this team. It does not know which
          <strong>role</strong>
          they hold — no source provides that. Choose the role and confirm; the record keeps who
          confirmed it and when.
        </p>

        <%!-- **Um formulário só**, e não um por linha. É o que permite confirmar várias de
              uma vez sem espelhar o estado dos seletores em `assigns` — o navegador já
              guarda o que foi escolhido, e duplicar isso no servidor criaria duas fontes que
              podem discordar.

              O botão diz QUAL linha: `name="apenas"` com o id da evidência, ou `"todas"`. --%>
        <form phx-submit="promover" id="promover" class="space-y-2">
          <ul class="space-y-2">
            <li :for={p <- @pendentes} class="card bg-base-200 p-3">
              <div class="flex flex-wrap items-end gap-2">
                <div class="min-w-40 flex-1">
                  <div class="font-medium">{p.person_name}</div>
                  <div :if={p.person_login} class="text-xs opacity-60">@{p.person_login}</div>
                </div>

                <label class="fieldset">
                  <span class="label-text text-xs">role</span>
                  <%!-- **Começa vazio.** Nenhum papel vem pré-selecionado, por critério nenhum
                        — e menos ainda pelo nível de acesso, que nem chega aqui.

                        Sem `required`: com o botão de confirmar todas, linha sem papel é
                        PULADA, e não impedimento. `required` bloquearia o envio inteiro por
                        causa de uma linha que ninguém quis preencher. --%>
                  <select name={"papel[#{p.id}]"} class="select select-sm select-bordered">
                    <option value="">choose…</option>
                    <option :for={papel <- @papeis_para_promover} value={valor_do_papel(papel)}>
                      {papel.name}
                    </option>
                  </select>
                </label>

                <label class="fieldset">
                  <span class="label-text text-xs">assumed the role on</span>
                  <%!-- Vem preenchido com hoje como PONTO DE PARTIDA, e é editável. A origem
                        não sabe desde quando a pessoa está na equipe — carimbar hoje sem
                        permitir correção afirmaria algo falso para quem entrou há um ano.
                        Esvaziar é permitido, e significa DESCONHECIDO. --%>
                  <input
                    type="date"
                    name={"started_at[#{p.id}]"}
                    value={Date.to_iso8601(Date.utc_today())}
                    class="input input-sm input-bordered"
                  />
                </label>

                <button type="submit" name="apenas" value={p.id} class="btn btn-primary btn-sm">
                  Confirm
                </button>
              </div>
            </li>
          </ul>

          <%!-- Confirmar todas: só as linhas COM papel escolhido. As demais são puladas, e a
                mensagem diz quantas — pular em silêncio faria quem clicou achar que confirmou
                tudo. --%>
          <div class="flex flex-wrap items-center gap-3 pt-1">
            <button type="submit" name="apenas" value="todas" class="btn btn-primary btn-sm">
              Confirm all
            </button>
            <span class="text-xs opacity-70">
              Confirms only the rows where a role was chosen. The others are left as they are,
              and the result says how many.
            </span>
          </div>
        </form>

        <p class="text-xs opacity-60">
          Leaving the date empty is allowed, and means <strong>unknown</strong>
          — never today. The platform does not guess when someone took a role on.
        </p>
      </section>

      <div class="alert text-sm">
        <div>
          <p class="font-semibold">Por que o papel organizacional aparece como pendente</p>
          <p>
            <span class="font-mono">MAINTAINER</span>
            e <span class="font-mono">MEMBER</span>
            are team administration levels at the platform: they say who can manage members and
            permissions. They do not say whether the person is a developer, a tester, a designer
            or a manager. Treating them as a role would produce a catalogue matching no real
            function. The link stays recorded as evidence until the organisation assigns the role.
          </p>
        </div>
      </div>

      <%!-- Projetos da equipe — o vínculo da 028, acessível também deste lado. --%>
      <section class="mt-8 space-y-3">
        <h3 class="text-base font-semibold">Projects</h3>
        <p :if={@projetos_da_equipe == []} class="text-sm opacity-70">
          This team is not associated with any project — "who works on this project" has no
          answer through it yet.
        </p>
        <ul class="flex flex-wrap gap-2">
          <li :for={pr <- @projetos_da_equipe} class="badge badge-outline gap-2">
            <.link navigate={~p"/projects"} class="link link-hover">{pr.nome}</.link>
            <button
              :if={@current_user.role == "admin"}
              phx-click="desassociar_projeto"
              phx-value-link_id={pr.link_id}
              class="cursor-pointer"
            >
              ×
            </button>
          </li>
        </ul>
        <form
          :if={@current_user.role == "admin" and @projetos_disponiveis != []}
          id="associar-projeto"
          phx-change="associar_projeto"
        >
          <select name="project_id" class="select select-sm select-bordered">
            <option value="">associate with a project…</option>
            <option :for={p <- @projetos_disponiveis} value={p.id}>{p.name}</option>
          </select>
        </form>
      </section>

      <%!-- Antipadrões do processo nas issues dos membros — pedido da pessoa mantenedora
            em 2026-08-16: a tela da equipe ALERTA onde o processo range. As máximas vêm
            da base de conhecimento; "não avaliado" e "nada encontrado" nunca se
            confundem — afirmar saúde sobre issues que ninguém olhou seria o antipadrão
            desta própria tela. --%>
      <section class="mt-8 space-y-3">
        <h3 class="text-base font-semibold">Process warnings</h3>
        <p class="text-sm opacity-70">
          Antipatterns found in the issues assigned to this team's members. They are not
          judgements about people — they say the record of the process is incomplete, and
          the cost is that the organisation loses the measurement.
        </p>

        <p
          :if={@antipadroes.avaliadas == 0 and @antipadroes.nao_avaliadas > 0}
          class="text-sm opacity-70"
        >
          None of the {@antipadroes.nao_avaliadas} issues has collected board movement, so
          nothing was evaluated — which is not the same as finding nothing.
        </p>

        <p
          :if={@antipadroes.avaliadas > 0 and @antipadroes.achados == []}
          class="text-sm opacity-70"
        >
          Nothing found in the {@antipadroes.avaliadas} issues that could be evaluated.
        </p>

        <ul :if={@antipadroes.achados != []} class="space-y-1 text-sm">
          <li :for={a <- @antipadroes.achados} class="flex items-baseline gap-2">
            <span class="badge badge-sm badge-warning">{a.count}</span>
            <span class="font-medium">{titulo_do_antipadrao(a.id)}</span>
            <span class="font-mono text-xs opacity-60">{a.id}</span>
          </li>
        </ul>

        <p
          :if={@antipadroes.avaliadas > 0 and @antipadroes.nao_avaliadas > 0}
          class="text-xs opacity-60"
        >
          Evaluated over {@antipadroes.avaliadas} issues; {@antipadroes.nao_avaliadas} had
          no collected movement and were not evaluated.
        </p>
      </section>

      <%!-- ============ Feature 029: competências da equipe ============
            Tudo aqui é DERIVADO DE DERIVADO: contagem sobre perfis escritos por modelo.
            A contagem é exata; o que ela conta é derivado — as duas verdades aparecem.
            Sem ranking de pessoas (FR-006a): a matriz junta leituras individuais. --%>
      <section class="mt-8 space-y-4">
        <div class="flex flex-wrap items-baseline justify-between gap-2">
          <h3 class="text-base font-semibold">Skills — read from what people did</h3>
          <span class="badge badge-outline badge-warning gap-2 text-xs">
            <span
              class="inline-block h-3 w-3 rounded-sm border border-current"
              style="background: repeating-linear-gradient(135deg, transparent 0 3px, currentColor 3px 4px);"
            ></span>
            derived — counted over model-written profiles
          </span>
        </div>

        <div :if={@cobertura.com_perfil == 0} class="card bg-base-200 p-6">
          <.absent reason="No member of this team has a profile yet — there is nothing to count. Coverage appears after the first profiles are generated." />
        </div>

        <div :if={@cobertura.com_perfil > 0} class="grid gap-4 lg:grid-cols-2">
          <div class="card bg-base-200 p-5">
            <h4 class="mb-1 text-sm font-semibold">Coverage per skill</h4>
            <p class="mb-3 text-xs opacity-70">
              how many of the {@cobertura.membros} members demonstrate each one · current profiles
            </p>
            <div class="space-y-2">
              <div
                :for={c <- @cobertura.competencias}
                class="grid grid-cols-[1fr_max-content] items-center gap-x-3 gap-y-1 text-sm sm:grid-cols-[minmax(8rem,18rem)_1fr_max-content]"
              >
                <%!-- No telefone o rótulo ocupa a linha inteira e a barra vem embaixo:
                      rótulo de até 18rem em 390px deixava a barra com ~40px — lasca,
                      não medida (visto em 2026-08-17). --%>
                <span class="col-span-2 break-words sm:col-span-1">{c.nome}</span>
                <div class="h-3 rounded-sm bg-base-300">
                  <div
                    class="h-3 rounded-sm bg-primary"
                    style={"width: #{round(c.total_pessoas / max(@cobertura.membros, 1) * 100)}%; min-width: 4px;"}
                  >
                  </div>
                </div>
                <span class="font-mono text-xs tabular-nums opacity-70">
                  {c.total_pessoas}/{@cobertura.membros}
                </span>
              </div>
            </div>
          </div>

          <div class="card bg-base-200 p-5">
            <h4 class="mb-1 text-sm font-semibold">What this team demonstrates — computed</h4>
            <p class="mb-3 text-xs opacity-70">
              sentences assembled from the counts, never written by a model
            </p>
            <ul class="space-y-2 border-l-2 border-warning pl-3 text-sm">
              <li :for={f <- @resumo_equipe}>{f.frase}</li>
            </ul>
          </div>
        </div>

        <div :if={@cobertura.com_perfil > 0} class="card bg-base-200 p-5">
          <h4 class="mb-1 text-sm font-semibold">Evolution — coverage per profile generation</h4>
          <%!-- Um mês só de geração não é série — mas esconder a seção afirmaria que a
                evolução não existe como leitura. A ausência é nomeada, com o que a faria
                aparecer (#403; era o estado da base real em 2026-08-17). --%>
          <p :if={length(@evolucao) <= 1} class="text-sm opacity-70">
            All current profiles were generated within a single month — evolution appears
            from the second generation month on. The monthly round writes it by itself.
          </p>
          <p :if={length(@evolucao) > 1} class="mb-3 text-xs opacity-70">
            people with the skill in the profile current at each month with a generation ·
            a skill leaving the series is <em>evidence not renewed</em>, never regression ·
            the 5 widest-covered skills of today; the coverage list above has them all
          </p>
          <div :if={length(@evolucao) > 1} class="space-y-2">
            <div
              :for={serie <- series_de_evolucao(@cobertura, @evolucao)}
              class="grid grid-cols-[1fr_max-content] items-center gap-x-3 gap-y-1 text-sm sm:grid-cols-[minmax(8rem,14rem)_1fr_max-content]"
            >
              <span class="col-span-2 break-words sm:col-span-1">{serie.nome}</span>
              <svg
                viewBox="0 0 200 26"
                preserveAspectRatio="none"
                class="h-6 w-full"
                role="img"
                aria-label={"#{serie.nome}: de #{serie.primeiro} para #{serie.ultimo} pessoas"}
              >
                <polyline
                  points={sparkline(serie.pontos)}
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  class="text-primary"
                />
              </svg>
              <span class="font-mono text-xs tabular-nums opacity-70">
                {serie.primeiro} → {serie.ultimo} {tendencia(serie)}<span
                  :if={serie.primeiro == 0 and serie.ultimo > 0}
                  class="text-success"
                > new</span>
              </span>
            </div>
          </div>
        </div>

        <%!-- A FORMA segue o dado: matriz só quando há sobreposição — colunas de domínios
              únicos fazem quem não é dono delas virar travessão, e a tela parece dizer que
              só uma pessoa trabalha (visto no time IA em 2026-08-16: todos com dezenas de
              tarefas, e a matriz mostrando só o Tadeu). Sem sobreposição, lista por pessoa. --%>
        <div
          :if={@cobertura.com_perfil > 0 and not matriz_agrega?(@cobertura)}
          class="card bg-base-200 p-5"
        >
          <h4 class="mb-1 text-sm font-semibold">Who demonstrates what</h4>
          <p class="mb-3 text-xs opacity-70">
            per person, because no domain repeats across people yet — the count is
            <strong>completed tasks</strong>
            evidencing each skill. Alphabetical; no ranking.
          </p>
          <div class="space-y-3">
            <div :for={pessoa <- pessoas_da_matriz(@cobertura)} class="text-sm">
              <.link navigate={~p"/people/#{pessoa.person_id}"} class="link link-hover font-medium">
                {pessoa.name}
              </.link>
              <span class="ml-2 inline-flex flex-wrap gap-1.5 align-middle">
                <span
                  :for={{nome, tarefas} <- Enum.sort_by(pessoa.tarefas, &elem(&1, 0))}
                  class="badge badge-sm badge-primary badge-outline gap-1"
                >
                  {nome} <span class="font-mono tabular-nums">{tarefas}</span>
                </span>
              </span>
            </div>
            <div :for={p <- @cobertura.sem_perfil} class="text-sm italic opacity-60">
              {p.name} — no profile yet; no row is not no skill
            </div>
          </div>
        </div>

        <div
          :if={@cobertura.com_perfil > 0 and matriz_agrega?(@cobertura)}
          class="card bg-base-200 p-5"
        >
          <h4 class="mb-1 text-sm font-semibold">Who demonstrates what</h4>
          <p class="mb-3 text-xs opacity-70">
            the cell is the count of <strong>completed tasks</strong> evidencing the skill —
            delivery, never promise. People in alphabetical order; no ranking.
          </p>
          <div class="overflow-x-auto">
            <table class="table table-xs">
              <thead>
                <tr>
                  <th>member</th>
                  <th :for={c <- @cobertura.competencias} class="text-center">
                    {c.nome}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr :for={pessoa <- pessoas_da_matriz(@cobertura)}>
                  <td>
                    <.link
                      navigate={~p"/people/#{pessoa.person_id}"}
                      class="link link-hover font-medium"
                    >
                      {pessoa.name}
                    </.link>
                  </td>
                  <td
                    :for={c <- @cobertura.competencias}
                    class="text-center font-mono tabular-nums"
                  >
                    <%= if t = pessoa.tarefas[c.nome] do %>
                      <span class="badge badge-sm badge-primary badge-outline">{t}</span>
                    <% else %>
                      <span class="opacity-30">—</span>
                    <% end %>
                  </td>
                </tr>
                <tr :for={p <- @cobertura.sem_perfil} class="opacity-60">
                  <td class="italic">{p.name}</td>
                  <td colspan={length(@cobertura.competencias)} class="text-xs italic">
                    no profile yet — no row is not no skill
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <p :if={@cobertura.sem_perfil != [] and @cobertura.com_perfil > 0} class="text-xs opacity-70">
          {length(@cobertura.sem_perfil)} of {@cobertura.membros} members have no profile yet —
          coverage above is a floor, never a ceiling. Members come from source-declared evidence.
        </p>
      </section>
    </Layouts.app>
    """
  end
end
