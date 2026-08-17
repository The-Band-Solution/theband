defmodule TheBandWeb.TeamsLive.Show do
  @moduledoc """
  `/teams/:id` — integrantes observados de uma equipe (US3).

  O nível de acesso é rotulado como **acesso na plataforma**, nunca como papel ou
  cargo. O rótulo é parte do contrato: chamá-lo de papel na tela desfaria na
  interface a distinção que o modelo se deu ao trabalho de preservar.
  """

  use TheBandWeb, :live_view

  import TheBandWeb.Components.DataTable

  alias TheBand.Mapping.Antipatterns
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Profiles
  alias TheBandWeb.TabelaLive, as: Tabela

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
        {:ok, socket |> put_flash(:error, "Team not found.") |> push_navigate(to: ~p"/teams")}

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
    |> carregar_competencias()
  end

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
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
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
                class="grid grid-cols-[minmax(8rem,18rem)_1fr_max-content] items-center gap-3 text-sm"
              >
                <span class="break-words">{c.nome}</span>
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

        <div :if={@cobertura.com_perfil > 0 and length(@evolucao) > 1} class="card bg-base-200 p-5">
          <h4 class="mb-1 text-sm font-semibold">Evolution — coverage per profile generation</h4>
          <p class="mb-3 text-xs opacity-70">
            people with the skill in the profile current at each month with a generation ·
            a skill leaving the series is <em>evidence not renewed</em>, never regression ·
            the 5 widest-covered skills of today; the coverage list above has them all
          </p>
          <div class="space-y-2">
            <div
              :for={serie <- series_de_evolucao(@cobertura, @evolucao)}
              class="grid grid-cols-[minmax(8rem,14rem)_1fr_max-content] items-center gap-3 text-sm"
            >
              <span class="break-words">{serie.nome}</span>
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
                {serie.primeiro} → {serie.ultimo}
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
