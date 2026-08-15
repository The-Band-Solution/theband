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
  alias TheBand.Ontology.SEON.SPO

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Projects", form_aberto: false, erro: nil) |> load()}
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

  def handle_event("associar", %{"project_id" => pid, "repository_id" => rid}, socket) do
    SPO.link_repository(socket.assigns.current_tenant, pid, rid, socket.assigns.current_user.id)
    {:noreply, load(socket)}
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

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    projetos = SPO.list_projects(tenant)
    nomes = Map.new(projetos, &{&1.id, &1.name})

    observados = CMPO.list_observed(tenant)
    nomes_de_repo = Map.new(observados, &{&1.observed_repository_id, &1.name})

    assign(socket,
      projetos:
        Enum.map(projetos, fn p ->
          Map.merge(p, %{
            parent_name: p.parent_id && nomes[p.parent_id],
            repositorios: SPO.list_project_repositories(tenant, p.id),
            contagem: SPO.count_project_issues(tenant, p.id)
          })
        end),
      nomes_de_repo: nomes_de_repo,
      observados: observados
    )
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
              <div class="text-xs opacity-70">
                {periodo(p)}
              </div>
            </div>

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

              <%!-- `id` por projeto: sem ele o LiveView avisa que não consegue recuperar
                    o formulário, e dois formulários iguais na mesma página ficam
                    indistinguíveis para quem os aciona. --%>
              <form
                id={"associar-#{p.id}"}
                phx-submit="associar"
                class="mt-2 flex flex-wrap gap-2"
              >
                <input type="hidden" name="project_id" value={p.id} />
                <select name="repository_id" class="select select-sm select-bordered">
                  <option value="">choose a repository…</option>
                  <option :for={o <- @observados} value={o.observed_repository_id}>
                    {o.name}
                  </option>
                </select>
                <.button type="submit" class="btn-outline btn-sm">Associate</.button>
              </form>
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
