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
  alias TheBand.Projects

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
       # Seletor de quadro é estado próprio: abrir os dois ao mesmo tempo no mesmo projeto
       # é legítimo, e um `picker` só obrigaria a fechar um para abrir o outro.
       picker_quadro: nil,
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

  def handle_event("abrir_picker_quadro", %{"project_id" => pid}, socket),
    do: {:noreply, assign(socket, picker_quadro: pid, erro: nil)}

  def handle_event("fechar_picker_quadro", _params, socket),
    do: {:noreply, assign(socket, picker_quadro: nil)}

  # **Sem seleção múltipla, ao contrário do seletor de repositório.** São 26 quadros contra
  # 160 repositórios, e associar quadro é decisão que se toma um de cada vez — a lista do
  # projeto é curta por natureza.
  def handle_event("associar_quadro", %{"project_id" => pid, "board_id" => bid}, socket) do
    SPO.link_board(socket.assigns.current_tenant, pid, bid, socket.assigns.current_user.id)
    {:noreply, load(socket)}
  end

  def handle_event("desassociar_quadro", %{"link_id" => id}, socket) do
    SPO.unlink_board(socket.assigns.current_tenant, id, socket.assigns.current_user.id)
    {:noreply, load(socket)}
  end

  def handle_event("declarar_criterio", params, socket) do
    %{"project_id" => pid, "event_type" => tipo} = params

    case SPO.declare_start_criterion(
           socket.assigns.current_tenant,
           {:project, pid},
           tipo,
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Start criterion declared: #{tipo}.")
         |> load()}

      # Erro previsto vira FRASE, e a frase diz por quê — FR-015.
      {:error, :unknown_event_type} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "The platform has not collected that event. Only what it observes can be declared."
         )}

      {:error, motivo} ->
        {:noreply, put_flash(socket, :error, "Could not declare: #{inspect(motivo)}")}
    end
  end

  def handle_event("revogar_criterio", %{"project_id" => pid}, socket) do
    case SPO.revoke_start_criterion(
           socket.assigns.current_tenant,
           {:project, pid},
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Criterion revoked. The declaration stays in the record.")
         |> load()}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "There was no criterion to revoke.")}
    end
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
          # **Um projeto pode ter mais de um quadro** — decisão de 2026-08-24, issue #367.
          # Antes disto o projeto tinha zero, e a entrega lida pelo quadro corrente fazia
          # dez meses do Conecta Fapes sumirem.
          quadros:
            tenant
            |> SPO.list_project_boards(p.id)
            |> Enum.map(fn q ->
              Map.put(
                q,
                :criterio,
                SPO.start_criterion_for(tenant, {:board, q.observed_project_id})
              )
            end),
          # Issue #370: o critério do projeto, e quais quadros vão ignorá-lo.
          criterio: SPO.start_criterion_for(tenant, {:project, p.id}),
          quadros_com_criterio: SPO.boards_overriding(tenant, p.id),
          # FR-004 e FR-009: quantas issues estão sem instante, e por qual das TRÊS
          # ausências. Um total agregado não diz a ninguém o que fazer.
          inicio: SPO.start_status(tenant, p.id),
          contagem: SPO.count_project_issues(tenant, p.id),
          # Feature 028: as organizações filtram o seletor, e as equipes dizem quem
          # trabalha — com a proveniência junto, porque declarada ≠ observada.
          organizacoes: SPO.list_project_organizations(tenant, p.id),
          equipes: SPO.list_project_teams(tenant, p.id),
          # Issue #505: quem esteve neste projeto e QUANDO — a interseção do período na
          # equipe com o período da equipe no projeto. Resolvida na leitura, nunca gravada.
          participacao: SPO.project_participation(tenant, p.id)
        })
      end)

    assign(socket,
      projetos: com_dados,
      # Issue #367: com volume, abertas e período. Escolher entre 26 quadros pelo título
      # sozinho é escolher no escuro — e o quadro que carrega os dez meses mais antigos do
      # projeto é justamente o que tem `[DEPRECATED]` no nome.
      quadros_do_tenant: Projects.boards_with_evidence(tenant),
      # Só o que a coleta traz, com volume — FR-012. Nenhum vem recomendado.
      tipos_de_evento: SPO.collected_event_types(tenant),
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

  # O resto da casa escreve `2026-06-10 18:24`. O ISO cru — com `T` e `Z` — apareceu no
  # percurso da T024 ao lado das outras datas, e destoava.
  defp instante(nil), do: "—"
  defp instante(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp instante(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

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
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_tenant={@current_tenant}
      nav_area={assigns[:nav_area]}
    >
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
              <%!-- ═══ QUEM ESTEVE NESTE PROJETO, E QUANDO — issue #505 ═══
                    A interseção de dois períodos que já existiam separados. Nenhuma das duas
                    colunas responde sozinha, e a resposta não estava em tela nenhuma. --%>
              <div :if={p.equipes != []} class="mt-3 rounded border border-base-300 p-2">
                <p class="text-xs uppercase tracking-wide opacity-60">
                  Who was on this project, and when · {length(p.participacao)} people
                </p>

                <p :if={p.participacao == []} class="mt-1 text-xs opacity-70">
                  The teams are associated, but no membership overlaps the period the team was
                  on the project. Someone may have left the team before it joined — that is an
                  answer, not a gap.
                </p>

                <ul class="mt-1 space-y-1">
                  <li :for={pessoa <- p.participacao} class="text-xs">
                    <span class="font-medium">{pessoa.name}</span>
                    <%!-- Uma linha por janela, e nunca fundidas: jan–mar mais jul–set não é
                          jan–set, e fundir afirmaria abril, maio e junho. --%>
                    <span :for={j <- pessoa.janelas} class="ml-1 opacity-70">
                      <span :if={j.started_at}>{Calendar.strftime(j.started_at, "%Y-%m-%d")}</span>
                      <%!-- Começo nulo é DESCONHECIDO, e não a data do vínculo. Fim nulo é EM
                            CURSO. Os dois nulos são coisas diferentes, e a frase é diferente. --%>
                      <em :if={is_nil(j.started_at)}>entry date never recorded</em>
                      → <span :if={j.ended_at}>{Calendar.strftime(j.ended_at, "%Y-%m-%d")}</span>
                      <strong :if={is_nil(j.ended_at)}>still on it</strong>
                      <span class="font-mono opacity-60">· {j.team_name}</span>
                    </span>
                  </li>
                </ul>

                <p class="mt-1 text-xs opacity-60">
                  A person is on the project <strong>through a team</strong>: the window starts
                  the later of the two dates and ends the earlier. Two teams give two windows,
                  and they are not merged — merging would claim months nobody was there.
                </p>
              </div>

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

            <%!-- ═══ O CRITÉRIO DE INÍCIO — issue #370 ═══
                  Vem antes dos quadros porque é o que dá sentido a eles: sem critério, o
                  quadro é lista, e não medida. --%>
            <div>
              <h4 class="text-xs uppercase tracking-wide opacity-60">Start criterion</h4>

              <p class="mt-1 text-sm">
                <span :if={p.criterio}>
                  Work starts when
                  <span class="badge badge-outline badge-sm font-mono">{p.criterio.event_type}</span>
                  happens · declared {instante(p.criterio.declared_at)}
                </span>
                <%!-- FR-015: a ausência é FRASE, e a frase diz o que fazer. Um código de
                      motivo obrigaria quem lê a procurar o que ele significa. --%>
                <span :if={is_nil(p.criterio)} class="opacity-70">
                  No criterion declared. Until one is, this project has
                  <strong>no start instant</strong>
                  — and throughput, work in progress and cycle time have nothing to measure
                  from. Choose the event below.
                </span>
              </p>

              <%!-- FR-014: dizer quais quadros vão IGNORAR esta declaração, ANTES de gravar.
                    Depois seria informação inútil. --%>
              <div :if={p.quadros_com_criterio != []} class="alert alert-warning mt-2 block text-xs">
                <p>
                  <strong>{length(p.quadros_com_criterio)} board(s) will ignore this</strong>
                  — they declared their own, and the board wins over the project:
                </p>
                <ul class="mt-1 space-y-0.5">
                  <li :for={q <- p.quadros_com_criterio} class="font-mono">
                    {q.title} → {q.event_type}
                  </li>
                </ul>
              </div>

              <form phx-submit="declarar_criterio" class="mt-2 flex flex-wrap items-end gap-2">
                <input type="hidden" name="project_id" value={p.id} />
                <label class="fieldset">
                  <span class="label-text text-xs">event that marks the start</span>
                  <%!-- Só o que a coleta traz, com o VOLUME de cada um — FR-012. E nenhum
                        vem pré-selecionado: mostrar volume é informar, recomendar seria
                        escolher, e a FR-007 da feature 022 proíbe a plataforma escolher. --%>
                  <select name="event_type" class="select select-sm select-bordered" required>
                    <option value="">choose…</option>
                    <option :for={t <- @tipos_de_evento} value={t.event_type}>
                      {t.event_type} — {t.occurrences} observed
                    </option>
                  </select>
                </label>
                <.button type="submit" variant="primary" class="btn-sm">
                  {if p.criterio, do: "Replace", else: "Declare"}
                </.button>
                <button
                  :if={p.criterio}
                  type="button"
                  class="btn btn-ghost btn-sm"
                  phx-click="revogar_criterio"
                  phx-value-project_id={p.id}
                  data-confirm="Revoke it? Activities lose their start instant until a new one is declared."
                >
                  revoke
                </button>
              </form>

              <p class="mt-1 text-xs opacity-60">
                Which event means "work started" is a <strong>convention of this organisation</strong>,
                not a fact any source provides — so the platform records the choice instead of
                making it. Replacing keeps the previous declaration in the record.
              </p>

              <%!-- ─── O que a declaração alcança — T013, FR-004 e FR-009 ───
                    Separado por ausência, e nunca somado: `sem_criterio` se resolve
                    declarando, `criterio_ambiguo` desassociando um quadro, e
                    `evento_nao_coletado` coletando. Três ações diferentes, e um total
                    agregado esconderia as três. --%>
              <div :if={p.inicio.total > 0} class="mt-3 rounded border border-base-300 p-2">
                <p class="text-xs uppercase tracking-wide opacity-60">
                  Start instant · {p.inicio.total} issues reached
                </p>
                <ul class="mt-1 space-y-1 text-xs">
                  <li class="tabular-nums">
                    <strong>{p.inicio.com_instante}</strong> have a start instant.
                  </li>
                  <li :if={p.inicio.sem_criterio > 0} class="tabular-nums">
                    <strong>{p.inicio.sem_criterio}</strong>
                    have none because no criterion applies to them — <em>declare one above</em>, on this project or on their board.
                  </li>
                  <li :if={p.inicio.evento_nao_coletado > 0} class="tabular-nums">
                    <strong>{p.inicio.evento_nao_coletado}</strong>
                    have none because the declared event was never observed on them — <em>collect again</em>, or the event genuinely never happened.
                  </li>
                  <li :if={p.inicio.ambiguas != []} class="tabular-nums">
                    <strong>{length(p.inicio.ambiguas)}</strong>
                    have none because two boards tie — <em>unlink one of them</em>, listed below.
                  </li>
                </ul>

                <%!-- T019: ambiguidade é TRABALHO, e não erro. Contar não permite resolver:
                      quem administra precisa da issue, dos quadros e da data. --%>
                <div :if={p.inicio.ambiguas != []} class="mt-2">
                  <p class="text-xs">
                    <strong>Waiting on a decision.</strong>
                    When an issue sits on more than one board, the criterion that applies comes
                    from the board <strong>most recently linked to the project</strong>
                    — linking
                    the new board last is already the gesture that says which one is current.
                  </p>
                  <%!-- FR-017: a explicação vive NO PONTO DA DECISÃO, e o empate aparece aqui.
                        Ela também está na tela do quadro, e repetir é barato — mandar quem lê
                        procurar noutra tela não é. O percurso da T024 achou essa falta. --%>
                  <p class="mt-1 text-xs">
                    These tied: they were linked to two boards <strong>at the same instant</strong>,
                    so there is no most recent one, and both boards declared a criterion. The
                    platform <strong>does not pick one</strong>
                    — picking would be choosing on your behalf, where nobody would look for it.
                  </p>
                  <%!-- Corte declarado, e nunca silencioso: no percurso da T024 este projeto
                        tinha 399 empates, e 399 linhas num cartão não são lidas. A linha
                        seguinte diz quantas ficaram de fora — omitir o corte faria a lista
                        parecer completa. --%>
                  <ul class="mt-1 space-y-1">
                    <li :for={a <- Enum.take(p.inicio.ambiguas, 20)} class="text-xs">
                      <span class="font-mono">{a.title}</span>
                      <span class="opacity-60">
                        — {Enum.map_join(a.quadros, " · ", & &1.title)} · linked {instante(
                          hd(a.quadros).linked_at
                        )}
                      </span>
                    </li>
                  </ul>
                  <p :if={length(p.inicio.ambiguas) > 20} class="mt-1 text-xs opacity-70">
                    and {length(p.inicio.ambiguas) - 20} more, not listed here. They tie the same
                    way — unlinking one of the two boards resolves all of them at once.
                  </p>
                </div>
              </div>
            </div>

            <%!-- Os quadros vêm ANTES dos repositórios porque é por eles que a entrega é
                  lida. Um projeto sem quadro alcança issue por repositório e não alcança
                  sprint nenhum. --%>
            <div>
              <h4 class="text-xs uppercase tracking-wide opacity-60">Boards</h4>
              <p :if={p.quadros == []} class="mt-1 text-sm opacity-70">
                No board associated. The project reaches no sprint until one is — <strong>and a project may have more than one</strong>.
              </p>
              <ul class="mt-1 flex flex-wrap gap-2">
                <li :for={q <- p.quadros} class="badge badge-outline gap-2">
                  <span class="font-mono text-xs">{q.title}</span>
                  <%!-- Fechado na origem NÃO é desvinculado: é o quadro encerrado que
                        carrega o histórico que a #367 mostrou sumindo. --%>
                  <span :if={q.closed} class="text-xs italic opacity-60">closed</span>
                  <%!-- FR-013: a proveniência acompanha o número. Quadro com critério próprio
                        prevalece sobre o do projeto, e quem lê precisa ver isso na linha. --%>
                  <span :if={q.criterio} class="badge badge-primary badge-xs font-mono">
                    {q.criterio.event_type}
                  </span>
                  <span class="text-xs opacity-60 tabular-nums">{q.items}</span>
                  <button
                    phx-click="desassociar_quadro"
                    phx-value-link_id={q.id}
                    class="cursor-pointer"
                  >
                    ×
                  </button>
                </li>
              </ul>

              <.button
                :if={@picker_quadro != p.id}
                phx-click="abrir_picker_quadro"
                phx-value-project_id={p.id}
                class="btn-outline btn-sm mt-2"
              >
                Associate boards
              </.button>

              <div :if={@picker_quadro == p.id} class="mt-2 rounded-lg border border-base-300 p-3">
                <ul class="max-h-60 space-y-1 overflow-y-auto">
                  <li :for={q <- quadros_disponiveis(@quadros_do_tenant, p)}>
                    <button
                      phx-click="associar_quadro"
                      phx-value-project_id={p.id}
                      phx-value-board_id={q.id}
                      class="w-full cursor-pointer rounded px-2 py-1 text-left text-sm hover:bg-base-200"
                    >
                      <span class="font-mono text-xs">{q.title}</span>
                      <span :if={q.closed} class="ml-1 text-xs italic opacity-60">closed</span>
                      <span
                        :if={q.no_longer_observed_at}
                        class="ml-1 text-xs italic opacity-60"
                      >
                        no longer at the source
                      </span>
                      <%!-- A evidência, e nunca uma recomendação: quantos itens, quantos
                            seguem abertos, e o período que o quadro cobre. --%>
                      <span class="ml-1 block text-xs opacity-60 tabular-nums">
                        {q.itens} items · {q.abertas} still open{periodo(q)}
                      </span>
                    </button>
                  </li>
                </ul>
                <p
                  :if={quadros_disponiveis(@quadros_do_tenant, p) == []}
                  class="text-sm opacity-70"
                >
                  Every observed board is already associated with this project.
                </p>
                <.button phx-click="fechar_picker_quadro" class="btn-ghost btn-xs mt-2">
                  close
                </.button>
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
  # Os quadros que ainda não são deste projeto. **O mesmo quadro pode servir a mais de um
  # projeto** — o filtro é por projeto, e não global: excluir da lista o que já está em
  # outro projeto impediria o caso que a decisão de 2026-08-24 declara possível.
  # Quadro sem issue nenhuma não ganha período inventado: sai sem a frase, e a ausência
  # aparece como ausência. Um intervalo com as duas pontas iguais diria que o quadro
  # cobre um instante, que é outra coisa.
  defp periodo(%{primeira: nil}), do: ""

  defp periodo(%{primeira: inicio, ultima: fim}),
    do: " · #{Calendar.strftime(inicio, "%b/%Y")} to #{Calendar.strftime(fim, "%b/%Y")}"

  defp quadros_disponiveis(todos, projeto) do
    ja = MapSet.new(projeto.quadros, & &1.observed_project_id)
    Enum.reject(todos, &MapSet.member?(ja, &1.id))
  end
end
