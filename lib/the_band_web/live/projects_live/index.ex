defmodule TheBandWeb.ProjectsLive.Index do
  @moduledoc """
  `/projects` — os projetos, seus subprojetos e os repositórios de cada um.

  ## Uma coisa, e ela é "o que este projeto agrupa"

  Princípio X. A tela não lista issues soltas nem configura coleta: ela responde *"quais
  projetos existem, o que cada um agrupa, e quantas issues isso alcança"*.

  ## O formulário não pergunta se o projeto é simples ou complexo

  A fase é **consequência de ter partes**, e antes das partes a pergunta não tem
  resposta. O projeto nasce simples, vira complexo ao ganhar a primeira parte, e volta a
  simples ao perder a última — sem ninguém alterar um campo.

  ## As duas contagens não somam

  Issues que vêm de repositório do próprio projeto e issues que vêm de subprojeto são
  fatos diferentes. Um total escondería de onde o número veio, e é o mesmo motivo pelo
  qual a página da issue separa composição de atendimento.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Projects",
       form_aberto: false,
       erro: nil,
       # Um seletor por vez: qual projeto está escolhendo repositórios, o que foi
       # digitado na busca, e o que está marcado. Um estado por projeto multiplicaria
       # a complexidade sem ninguém precisar de dois abertos ao mesmo tempo.
       picker: nil,
       busca: "",
       marcados: MapSet.new(),
       # Feature 028: qual projeto está em edição, e o rascunho de equipe nova.
       editando: nil,
       nova_equipe: nil
     )
     |> load()}
  end

  @impl true
  def handle_event("abrir_form", _params, socket),
    do: {:noreply, assign(socket, form_aberto: true, erro: nil)}

  def handle_event("fechar_form", _params, socket),
    do: {:noreply, assign(socket, form_aberto: false, erro: nil)}

  def handle_event("criar", %{"name" => nome} = params, socket) do
    attrs = %{
      name: String.trim(nome),
      started_on: data(params["started_on"]),
      ended_on: data(params["ended_on"])
    }

    case SPO.create_project(socket.assigns.current_tenant, attrs, socket.assigns.current_user.id) do
      {:ok, _projeto} ->
        {:noreply, socket |> assign(form_aberto: false, erro: nil) |> load()}

      {:error, changeset} ->
        {:noreply, assign(socket, erro: primeira_mensagem(changeset))}
    end
  end

  def handle_event("abrir_picker", %{"project_id" => pid}, socket),
    do: {:noreply, assign(socket, picker: pid, busca: "", marcados: MapSet.new(), erro: nil)}

  def handle_event("fechar_picker", _params, socket),
    do: {:noreply, assign(socket, picker: nil, busca: "", marcados: MapSet.new())}

  def handle_event("buscar_repo", %{"busca" => termo}, socket),
    do: {:noreply, assign(socket, busca: termo)}

  def handle_event("alternar", %{"repository_id" => rid}, socket) do
    marcados = socket.assigns.marcados

    {:noreply,
     assign(socket,
       marcados:
         if(MapSet.member?(marcados, rid),
           do: MapSet.delete(marcados, rid),
           else: MapSet.put(marcados, rid)
         )
     )}
  end

  @doc false
  def handle_event("marcar_visiveis", %{"project_id" => pid}, socket) do
    visiveis = socket.assigns |> disponiveis(pid) |> Enum.map(& &1.observed_repository_id)

    {:noreply,
     assign(socket, marcados: MapSet.union(socket.assigns.marcados, MapSet.new(visiveis)))}
  end

  # ------------------------------------------------------------ feature 028: gestão

  def handle_event("abrir_edicao", %{"project_id" => pid}, socket),
    do: {:noreply, assign(socket, editando: pid, erro: nil)}

  def handle_event("fechar_edicao", _params, socket),
    do: {:noreply, assign(socket, editando: nil)}

  def handle_event("salvar_edicao", %{"project_id" => pid} = params, socket) do
    caso =
      SPO.update_project(
        socket.assigns.current_tenant,
        pid,
        %{
          name: params["name"],
          started_on: vazio_e_nulo(params["started_on"]),
          ended_on: vazio_e_nulo(params["ended_on"])
        },
        socket.assigns.current_user.id
      )

    case caso do
      {:ok, _} ->
        {:noreply, socket |> assign(editando: nil) |> load()}

      {:error, %Ecto.Changeset{} = ch} ->
        {:noreply, assign(socket, erro: primeira_mensagem(ch))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Project not found.")}
    end
  end

  def handle_event("remover_projeto", %{"project_id" => pid}, socket) do
    caso =
      SPO.remove_project(socket.assigns.current_tenant, pid, socket.assigns.current_user.id)

    case caso do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Project removed. The declaration stays on record; there is no undelete."
         )
         |> load()}

      {:error, :has_parts} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This project has parts. Move or remove the subprojects first — removing in " <>
             "cascade would erase declarations nobody asked to erase."
         )}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Project not found.")}
    end
  end

  def handle_event(
        "associar_organizacao",
        %{"project_id" => pid, "organization_id" => oid},
        socket
      )
      when oid != "" do
    {:ok, _} =
      SPO.link_organization(
        socket.assigns.current_tenant,
        pid,
        oid,
        socket.assigns.current_user.id
      )

    {:noreply, load(socket)}
  end

  def handle_event("associar_organizacao", _params, socket), do: {:noreply, socket}

  def handle_event("desassociar_organizacao", %{"link_id" => lid}, socket) do
    {:ok, _} =
      SPO.unlink_organization(socket.assigns.current_tenant, lid, socket.assigns.current_user.id)

    {:noreply, load(socket)}
  end

  def handle_event("associar_equipe", %{"project_id" => pid, "team_id" => tid}, socket)
      when tid != "" do
    {:ok, _} =
      SPO.link_team(socket.assigns.current_tenant, pid, tid, socket.assigns.current_user.id)

    {:noreply, load(socket)}
  end

  def handle_event("associar_equipe", _params, socket), do: {:noreply, socket}

  def handle_event("desassociar_equipe", %{"link_id" => lid}, socket) do
    {:ok, _} =
      SPO.unlink_team(socket.assigns.current_tenant, lid, socket.assigns.current_user.id)

    {:noreply, load(socket)}
  end

  def handle_event("abrir_nova_equipe", %{"project_id" => pid}, socket),
    do: {:noreply, assign(socket, nova_equipe: pid)}

  def handle_event("fechar_nova_equipe", _params, socket),
    do: {:noreply, assign(socket, nova_equipe: nil)}

  def handle_event("criar_equipe", %{"project_id" => pid, "name" => nome}, socket) do
    tenant = socket.assigns.current_tenant
    ator = socket.assigns.current_user.id

    # Criar e associar são um gesto na tela e dois atos no domínio — a equipe existe por
    # si, e o vínculo é o que a liga ao projeto (e o que justifica o tipo project_team).
    with {:ok, equipe} <- EO.create_declared_team(tenant, nome, ator),
         {:ok, _} <- SPO.link_team(tenant, pid, equipe.id, ator) do
      {:noreply, socket |> assign(nova_equipe: nil) |> load()}
    else
      {:error, %Ecto.Changeset{} = ch} ->
        {:noreply, assign(socket, erro: primeira_mensagem(ch))}
    end
  end

  def handle_event("associar_marcados", %{"project_id" => pid}, socket) do
    tenant = socket.assigns.current_tenant
    autor = socket.assigns.current_user.id

    # **Vários de uma vez**, e é o pedido: com 160 repositórios observados, associar um
    # por vez fecharia o seletor a cada escolha.
    for rid <- socket.assigns.marcados do
      SPO.link_repository(tenant, pid, rid, autor)
    end

    {:noreply, socket |> assign(picker: nil, busca: "", marcados: MapSet.new()) |> load()}
  end

  def handle_event("desassociar", %{"link_id" => id}, socket) do
    SPO.unlink_repository(socket.assigns.current_tenant, id, socket.assigns.current_user.id)
    {:noreply, load(socket)}
  end

  def handle_event("definir_pai", %{"project_id" => pid, "parent_id" => ""}, socket) do
    SPO.clear_parent(socket.assigns.current_tenant, pid)
    {:noreply, socket |> assign(erro: nil) |> load()}
  end

  def handle_event("definir_pai", %{"project_id" => pid, "parent_id" => parent}, socket) do
    case SPO.set_parent(socket.assigns.current_tenant, pid, parent) do
      {:ok, _} ->
        {:noreply, socket |> assign(erro: nil) |> load()}

      # **A recusa nomeia o motivo**, e não diz só que falhou: quem cadastrou precisa
      # saber de quem o projeto já é parte, ou onde o ciclo se fecha.
      {:error, {:already_has_parent, nome}} ->
        {:noreply,
         assign(socket, erro: "This project is already part of #{nome}. Detach it first.")}

      {:error, {:cycle, caminho}} ->
        {:noreply,
         assign(socket, erro: "That would create a cycle: #{Enum.join(caminho, " → ")}")}

      {:error, :not_found} ->
        {:noreply, assign(socket, erro: "Project not found.")}
    end
  end

  defp vazio_e_nulo(""), do: nil
  defp vazio_e_nulo(v), do: v

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    projetos = SPO.list_projects(tenant)
    nomes = Map.new(projetos, &{&1.id, &1.name})

    observados = CMPO.list_observed(tenant)
    nomes_de_repo = Map.new(observados, &{&1.observed_repository_id, &1.name})
    nomes_de_org = Map.new(EO.list_organizations(tenant), &{&1.id, &1.login})

    com_dados =
      Enum.map(projetos, fn p ->
        Map.merge(p, %{
          parent_name: p.parent_id && nomes[p.parent_id],
          repositorios: SPO.list_project_repositories(tenant, p.id),
          contagem: SPO.count_project_issues(tenant, p.id),
          # Feature 028: as organizações filtram o seletor, e as equipes dizem quem
          # trabalha — com a proveniência junto, porque declarada ≠ observada.
          organizacoes: SPO.list_project_organizations(tenant, p.id),
          equipes: SPO.list_project_teams(tenant, p.id)
        })
      end)

    assign(socket,
      projetos: com_dados,
      nomes_de_repo: nomes_de_repo,
      nomes_de_org: nomes_de_org,
      organizacoes_do_tenant: EO.list_organizations(tenant),
      equipes_do_tenant: EO.list_teams(tenant),
      observados: observados,
      ja_associados:
        Map.new(com_dados, fn p ->
          {p.id, MapSet.new(p.repositorios, & &1.observed_repository_id)}
        end)
    )
  end

  @doc false
  # Os que **ainda não** estão no projeto, filtrados pela busca. Excluir os já
  # associados evita a lista oferecer o que não faz nada — e é a diferença entre uma
  # lista de 160 e uma de 160 com quatro inúteis no meio.
  def disponiveis(assigns, project_id) do
    ja = assigns.ja_associados[project_id] || MapSet.new()
    termo = String.downcase(String.trim(assigns.busca))
    orgs = orgs_do_projeto(assigns, project_id)

    assigns.observados
    |> Enum.reject(&MapSet.member?(ja, &1.observed_repository_id))
    # FR-005: com organização associada, o seletor oferece só o que ela alcança. Sem
    # associação, tudo — compatível com os projetos existentes, e a tela diz qual caso é.
    |> Enum.filter(fn r ->
      (orgs == nil or MapSet.member?(orgs, r.organization_id)) and
        (termo == "" or String.contains?(String.downcase(r.qualified_name || r.name), termo))
    end)
  end

  @doc false
  # `nil` = sem associação (sem filtro); MapSet = filtra. A distinção importa: um MapSet
  # vazio filtraria TUDO, e "nenhuma organização associada" não pode significar isso.
  def orgs_do_projeto(assigns, project_id) do
    case Enum.find(assigns.projetos, &(&1.id == project_id)) do
      %{organizacoes: []} -> nil
      %{organizacoes: orgs} -> MapSet.new(orgs, & &1.organization_id)
      nil -> nil
    end
  end

  # Agrupa por organização, porque quem procura repositório pensa por organização —
  # e com 160 numa lista plana ninguém acha nada.
  defp por_organizacao(repos, nomes_de_org) do
    repos
    |> Enum.group_by(& &1.organization_id)
    |> Enum.map(fn {org_id, lista} ->
      {nomes_de_org[org_id] || "sem organização", Enum.sort_by(lista, & &1.name)}
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp data(""), do: nil
  defp data(nil), do: nil

  defp data(iso) do
    case Date.from_iso8601(iso) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp primeira_mensagem(%Ecto.Changeset{errors: [{campo, {msg, _}} | _]}),
    do: "#{campo}: #{msg}"

  defp primeira_mensagem(_changeset), do: "Could not save the project."

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Projects
        <:subtitle>What each project groups, and how many issues that reaches</:subtitle>
        <:actions>
          <.button :if={not @form_aberto} phx-click="abrir_form" class="btn-primary btn-sm">
            New project
          </.button>
        </:actions>
      </.header>

      <.notice :if={@erro} kind={:divergence} title="That change was refused.">
        {@erro}
      </.notice>

      <div :if={@form_aberto} class="card bg-base-200">
        <div class="card-body gap-3 p-4 sm:p-5">
          <h3 class="font-semibold">New project</h3>
          <%!-- **Não pergunta se é simples ou complexo.** A fase é consequência de ter
                partes, e antes das partes a pergunta não tem resposta. --%>
          <form phx-submit="criar" class="grid gap-3 sm:grid-cols-3">
            <label class="sm:col-span-3">
              <span class="text-xs text-base-content/70">name</span>
              <input name="name" required class="input input-bordered w-full" autocomplete="off" />
            </label>
            <label>
              <span class="text-xs text-base-content/70">started on (optional)</span>
              <input type="date" name="started_on" class="input input-bordered w-full" />
            </label>
            <label>
              <span class="text-xs text-base-content/70">ended on (optional)</span>
              <input type="date" name="ended_on" class="input input-bordered w-full" />
            </label>
            <div class="flex items-end gap-2">
              <.button type="submit" class="btn-primary btn-sm">Create</.button>
              <.button type="button" phx-click="fechar_form" class="btn-ghost btn-sm">
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>

      <p :if={@projetos == []} class="text-sm text-base-content/70">
        No project registered yet. A project is declared, never observed — the platform will not
        create one from a repository name or an organisation.
      </p>

      <div class="space-y-4">
        <section :for={p <- @projetos} class="card bg-base-200">
          <div class="card-body gap-3 p-4 sm:p-5">
            <div class="flex flex-wrap items-baseline justify-between gap-3">
              <h3 class="font-semibold">
                {p.name}
                <%!-- A fase é derivada, e o rótulo diz isso: ninguém a escolheu. --%>
                <span class="badge badge-sm ml-1">
                  {if p.phase == :complex, do: "complex", else: "simple"}
                </span>
                <span :if={p.parent_name} class="text-xs font-normal opacity-70">
                  part of {p.parent_name}
                </span>
              </h3>
              <div class="flex items-center gap-2">
                <span class="text-xs opacity-70">{periodo(p)}</span>
                <%!-- Feature 028: editar e remover são de admin, e remover é MARCA —
                      a frase do confirm diz o efeito antes do clique. --%>
                <button
                  :if={@current_user.role == "admin" && @editando != p.id}
                  phx-click="abrir_edicao"
                  phx-value-project_id={p.id}
                  class="btn btn-ghost btn-xs"
                >
                  edit
                </button>
                <button
                  :if={@current_user.role == "admin"}
                  phx-click="remover_projeto"
                  phx-value-project_id={p.id}
                  class="btn btn-ghost btn-xs text-error"
                  data-confirm={"Remove the project \"#{p.name}\"? The declaration stays on record — there is no undelete. A project with parts is refused."}
                >
                  remove
                </button>
              </div>
            </div>

            <form
              :if={@editando == p.id}
              id={"editar-#{p.id}"}
              phx-submit="salvar_edicao"
              class="flex flex-wrap items-end gap-3 rounded-lg border border-base-300 p-3"
            >
              <input type="hidden" name="project_id" value={p.id} />
              <label class="flex flex-col gap-1 text-xs">
                name
                <input name="name" value={p.name} required class="input input-sm input-bordered" />
              </label>
              <label class="flex flex-col gap-1 text-xs">
                started on
                <input
                  type="date"
                  name="started_on"
                  value={p.started_on}
                  class="input input-sm input-bordered"
                />
              </label>
              <label class="flex flex-col gap-1 text-xs">
                ended on
                <input
                  type="date"
                  name="ended_on"
                  value={p.ended_on}
                  class="input input-sm input-bordered"
                />
              </label>
              <.button class="btn-sm">Save</.button>
              <button type="button" phx-click="fechar_edicao" class="btn btn-ghost btn-sm">
                cancel
              </button>
              <p :if={@erro} class="w-full text-sm text-error">{@erro}</p>
            </form>

            <%!-- **As duas contagens não somam.** "Veio de repositório meu" e "veio de
                  subprojeto" são fatos diferentes, e um total esconderia de onde o
                  número veio. --%>
            <div class="flex flex-wrap gap-6 text-sm">
              <span>
                <strong class="tabular">{p.contagem.direct}</strong>
                <span class="opacity-70">issues from its own repositories</span>
              </span>
              <span :if={p.contagem.subproject > 0}>
                <strong class="tabular">{p.contagem.subproject}</strong>
                <span class="opacity-70">from subprojects</span>
              </span>
            </div>

            <div>
              <h4 class="text-xs uppercase tracking-wide opacity-60">Organisations</h4>
              <%!-- FR-004/FR-005: a organização associada FILTRA o seletor de
                    repositórios. Sem associação, o seletor oferece tudo — e diz isso. --%>
              <p :if={p.organizacoes == []} class="mt-1 text-sm opacity-70">
                No organisation associated — the repository picker offers everything.
              </p>
              <ul class="mt-1 flex flex-wrap gap-2">
                <li :for={o <- p.organizacoes} class="badge badge-outline gap-2">
                  <span class="font-mono text-xs">{o.login}</span>
                  <button
                    :if={@current_user.role == "admin"}
                    phx-click="desassociar_organizacao"
                    phx-value-link_id={o.id}
                    class="cursor-pointer"
                  >
                    ×
                  </button>
                </li>
              </ul>
              <form
                :if={@current_user.role == "admin"}
                id={"org-#{p.id}"}
                phx-change="associar_organizacao"
                class="mt-2"
              >
                <input type="hidden" name="project_id" value={p.id} />
                <select name="organization_id" class="select select-sm select-bordered">
                  <option value="">associate an organisation…</option>
                  <option
                    :for={org <- @organizacoes_do_tenant}
                    :if={org.id not in Enum.map(p.organizacoes, & &1.organization_id)}
                    value={org.id}
                  >
                    {org.login}
                  </option>
                </select>
              </form>
            </div>

            <div>
              <h4 class="text-xs uppercase tracking-wide opacity-60">Teams</h4>
              <%!-- FR-008: declarada e observada são proveniências diferentes, e a marca
                    diz qual é. FR-009: a equipe declarada nasce vazia — membro exige
                    papel organizacional (#99/#100), e a tela não esconde isso. --%>
              <p :if={p.equipes == []} class="mt-1 text-sm opacity-70">
                No team associated — "who works on this project" has no answer yet.
              </p>
              <ul class="mt-1 flex flex-wrap gap-2">
                <li :for={e <- p.equipes} class="badge badge-outline gap-2">
                  {e.name}
                  <span :if={e.declared} class="badge badge-xs">declared</span>
                  <span :if={!e.declared} class="badge badge-xs badge-ghost">observed</span>
                  <button
                    :if={@current_user.role == "admin"}
                    phx-click="desassociar_equipe"
                    phx-value-link_id={e.id}
                    class="cursor-pointer"
                  >
                    ×
                  </button>
                </li>
              </ul>
              <div :if={@current_user.role == "admin"} class="mt-2 flex flex-wrap items-center gap-2">
                <form id={"equipe-#{p.id}"} phx-change="associar_equipe">
                  <input type="hidden" name="project_id" value={p.id} />
                  <select name="team_id" class="select select-sm select-bordered">
                    <option value="">associate a team…</option>
                    <option
                      :for={t <- @equipes_do_tenant}
                      :if={t.id not in Enum.map(p.equipes, & &1.team_id)}
                      value={t.id}
                    >
                      {t.name}
                    </option>
                  </select>
                </form>
                <button
                  :if={@nova_equipe != p.id}
                  phx-click="abrir_nova_equipe"
                  phx-value-project_id={p.id}
                  class="btn btn-ghost btn-xs"
                >
                  create a team
                </button>
                <form
                  :if={@nova_equipe == p.id}
                  id={"nova-equipe-#{p.id}"}
                  phx-submit="criar_equipe"
                  class="flex items-center gap-2"
                >
                  <input type="hidden" name="project_id" value={p.id} />
                  <input
                    name="name"
                    required
                    placeholder="team name"
                    class="input input-sm input-bordered"
                  />
                  <.button class="btn-sm">Create</.button>
                  <button type="button" phx-click="fechar_nova_equipe" class="btn btn-ghost btn-sm">
                    cancel
                  </button>
                </form>
                <span :if={@nova_equipe == p.id} class="text-xs opacity-60">
                  born declared and empty — membership needs an organisational role
                </span>
              </div>
            </div>

            <div>
              <h4 class="text-xs uppercase tracking-wide opacity-60">Repositories</h4>
              <p :if={p.repositorios == []} class="mt-1 text-sm opacity-70">
                No repository associated. The project reaches no issue until one is.
              </p>
              <ul class="mt-1 flex flex-wrap gap-2">
                <li :for={r <- p.repositorios} class="badge badge-outline gap-2">
                  <span class="font-mono text-xs">
                    {@nomes_de_repo[r.observed_repository_id] || "unknown"}
                  </span>
                  <button phx-click="desassociar" phx-value-link_id={r.id} class="cursor-pointer">
                    ×
                  </button>
                </li>
              </ul>

              <.button
                :if={@picker != p.id}
                phx-click="abrir_picker"
                phx-value-project_id={p.id}
                class="btn-outline btn-sm mt-2"
              >
                Associate repositories
              </.button>

              <%!-- O seletor: busca, agrupamento por organização e escolha múltipla.
                    Com 160 repositórios observados, um `<select>` simples obrigaria a
                    rolar a lista inteira e a reabrir o formulário a cada escolha. --%>
              <div :if={@picker == p.id} class="mt-2 rounded-lg border border-base-300 p-3">
                <form id={"buscar-#{p.id}"} phx-change="buscar_repo" class="flex gap-2">
                  <input
                    name="busca"
                    value={@busca}
                    placeholder="search by name or organisation…"
                    autocomplete="off"
                    phx-debounce="150"
                    class="input input-sm input-bordered w-full"
                  />
                </form>

                <% disponiveis = disponiveis(assigns, p.id) %>

                <div class="mt-2 flex flex-wrap items-center gap-3 text-xs text-base-content/70">
                  <span>{length(disponiveis)} available</span>
                  <%!-- SC-002: qual dos dois casos está acontecendo é dito, nunca deduzido. --%>
                  <span :if={orgs_do_projeto(assigns, p.id)} class="badge badge-xs badge-outline">
                    filtered by the project's organisations
                  </span>
                  <span :if={!orgs_do_projeto(assigns, p.id)} class="opacity-60">
                    unfiltered — no organisation associated
                  </span>
                  <span :if={MapSet.size(@marcados) > 0} class="font-medium text-base-content">
                    {MapSet.size(@marcados)} selected
                  </span>
                  <button
                    :if={disponiveis != []}
                    phx-click="marcar_visiveis"
                    phx-value-project_id={p.id}
                    class="link link-hover"
                  >
                    select all shown
                  </button>
                </div>

                <p :if={disponiveis == []} class="mt-2 text-sm opacity-70">
                  <%!-- "Nada encontrado" e "tudo já associado" são coisas diferentes, e
                        a frase precisa dizer qual das duas é. --%>
                  {if @busca == "",
                    do: "Every observed repository is already associated with this project.",
                    else: "No repository matches this search."}
                </p>

                <div class="mt-2 max-h-72 space-y-3 overflow-y-auto">
                  <div :for={{org, repos} <- por_organizacao(disponiveis, @nomes_de_org)}>
                    <div class="text-xs font-semibold uppercase tracking-wide opacity-60">
                      {org} <span class="font-normal opacity-70">{length(repos)}</span>
                    </div>
                    <label
                      :for={r <- repos}
                      class="flex cursor-pointer items-center gap-2 py-0.5 text-sm hover:bg-base-300"
                    >
                      <input
                        type="checkbox"
                        class="checkbox checkbox-xs"
                        checked={MapSet.member?(@marcados, r.observed_repository_id)}
                        phx-click="alternar"
                        phx-value-repository_id={r.observed_repository_id}
                      />
                      <span class="font-mono text-xs">{r.name}</span>
                    </label>
                  </div>
                </div>

                <div class="mt-3 flex gap-2">
                  <.button
                    phx-click="associar_marcados"
                    phx-value-project_id={p.id}
                    disabled={MapSet.size(@marcados) == 0}
                    class="btn-primary btn-sm"
                  >
                    Associate {MapSet.size(@marcados)}
                  </.button>
                  <.button phx-click="fechar_picker" class="btn-ghost btn-sm">Cancel</.button>
                </div>
              </div>
            </div>

            <div>
              <h4 class="text-xs uppercase tracking-wide opacity-60">Part of</h4>
              <form
                id={"pai-#{p.id}"}
                phx-change="definir_pai"
                class="mt-1 flex flex-wrap gap-2"
              >
                <input type="hidden" name="project_id" value={p.id} />
                <select name="parent_id" class="select select-sm select-bordered">
                  <option value="">not part of another project</option>
                  <option
                    :for={outro <- @projetos}
                    :if={outro.id != p.id}
                    value={outro.id}
                    selected={p.parent_id == outro.id}
                  >
                    {outro.name}
                  </option>
                </select>
              </form>
            </div>
          </div>
        </section>
      </div>

      <div class="mt-6 rounded-lg border border-base-300 bg-base-200 p-4 text-sm text-base-content/70">
        <strong class="text-base-content">The issues of a project are a traversal.</strong>
        Project → repositories → issues. The platform does not store a project on the issue: two
        sources for the same fact would disagree the day a repository moved between projects.
      </div>
    </Layouts.app>
    """
  end

  defp periodo(%{started_on: nil, ended_on: nil}), do: "dates not informed"
  defp periodo(%{started_on: inicio, ended_on: nil}), do: "since #{inicio}"
  defp periodo(%{started_on: nil, ended_on: fim}), do: "until #{fim}"
  defp periodo(%{started_on: inicio, ended_on: fim}), do: "#{inicio} — #{fim}"
end
