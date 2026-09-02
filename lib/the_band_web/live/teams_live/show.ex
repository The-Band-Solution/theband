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
  alias TheBand.Tenants
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

    socket
    |> assign(contem: EO.team_parts(tenant, team.id))
    |> assign(faz_parte_de: EO.team_wholes(tenant, team.id))
    |> assign(pendentes: EO.pending_evidence(tenant, team.id))
    |> assign(papeis_para_promover: papeis)
  end

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
