defmodule TheBandWeb.ChangeLive.File do
  @moduledoc """
  `/work/files?path=...` — a história de um arquivo (feature 035, issue #429).

  **A pergunta que esta tela existe para responder**: *quem mexeu neste arquivo, e por
  qual issue?* Cada linha é uma cópia (`cmpo.artifact_copy`) e traz a cadeia inteira
  declarada na rede: cópia → commit → solicitação → issue → pessoa.

  O caminho vem na query string, e não no path, porque caminho de arquivo tem barras: um
  `:path` no roteador não casaria `lib/the_band/changes.ex`.
  """
  use TheBandWeb, :live_view

  alias TheBand.Changes
  alias TheBand.Ontology.SEON.EO

  @impl true
  def mount(_params, _session, socket) do
    # O resumo é do tenant inteiro e não muda com a busca: uma consulta no mount, e
    # nenhuma por render.
    {:ok,
     socket
     |> assign(page_title: "File history", caminho: nil, copias: [], pessoas: [])
     |> assign(resumo: Changes.resumo_de_arquivos(socket.assigns.current_tenant))}
  end

  @impl true
  def handle_params(%{"path" => caminho}, _uri, socket) when caminho not in [nil, ""] do
    tenant = socket.assigns.current_tenant
    copias = Changes.history_of_path(tenant, caminho)
    pessoas = Changes.people_who_touched(tenant, caminho)

    {:noreply,
     socket
     |> assign(page_title: Path.basename(caminho), caminho: caminho)
     |> assign(copias: copias, pessoas: pessoas)
     |> assign(nomes: nomes(tenant, copias, pessoas))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, caminho: nil, copias: [], pessoas: [], nomes: %{})}
  end

  @impl true
  def handle_event("buscar", %{"q" => caminho}, socket),
    do: {:noreply, push_patch(socket, to: ~p"/work/files?path=#{caminho}")}

  # Uma consulta de nomes para a tela inteira.
  defp nomes(tenant, copias, pessoas) do
    ids =
      (Enum.flat_map(copias, fn c -> Enum.map(c.autores, & &1.person_id) end) ++
         Enum.map(pessoas, & &1.person_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    EO.people_names(tenant, ids)
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
      <Layouts.work_tabs active={:files} />
      <.header>
        File history
        <:subtitle>
          Who changed a file, and for which issue — each row is one version the source recorded
        </:subtitle>
      </.header>

      <%!-- O painel diz o tamanho do que a plataforma conhece ANTES de alguém procurar:
            sem ele, uma busca sem resultado é indistinguível de coleta que não rodou.
            `commits` é o denominador honesto — são 8.194 dos 16.416 commits, e o resto
            **não foi coletado**, que é diferente de não ter tocado arquivo nenhum. --%>
      <div class="grid grid-cols-3 gap-2">
        <div class="rounded-lg border border-base-300 px-3 py-2">
          <span class="block font-mono text-xl tabular-nums">{@resumo.caminhos}</span>
          <span class="text-xs opacity-70">file paths known</span>
        </div>
        <div class="rounded-lg border border-base-300 px-3 py-2">
          <span class="block font-mono text-xl tabular-nums">{@resumo.copias}</span>
          <span class="text-xs opacity-70">versions recorded</span>
        </div>
        <div class="rounded-lg border border-base-300 px-3 py-2">
          <span class="block font-mono text-xl tabular-nums">{@resumo.commits}</span>
          <span class="text-xs opacity-70">commits swept for files</span>
        </div>
      </div>

      <.busca valor={@caminho || ""} onde="the exact file path" tabela="files" />

      <p :if={is_nil(@caminho)} class="mt-3 text-sm opacity-70">
        Paste a file path to see its history. Paths come from a change request's commits —
        <.link navigate={~p"/work/changes"} class="link">start from a change request</.link>
        if you don't have one at hand.
      </p>

      <div :if={@caminho} class="mt-3">
        <p class="mb-3 font-mono text-sm">{@caminho}</p>

        <p :if={@copias == []} class="alert">
          No version of <span class="font-mono">{@caminho}</span> was collected.
          The first pass over every commit may still be running — <strong>not collected
          yet</strong> is different from never having changed, and the path has to match
          exactly.
        </p>

        <div :if={@copias != []} class="grid gap-4 lg:grid-cols-3">
          <div class="min-w-0 lg:col-span-2">
            <h3 class="mb-2 text-sm font-semibold">
              {length(@copias)} version(s), most recent first
            </h3>

            <div :for={c <- @copias} class="border-t border-base-300 py-2">
              <div class="flex flex-wrap items-baseline gap-x-2 text-sm">
                <span class={[
                  "badge badge-xs shrink-0 font-mono",
                  c.change == "added" && "badge-success badge-outline",
                  c.change == "removed" && "badge-error badge-outline",
                  c.change not in ["added", "removed"] && "badge-ghost"
                ]}>
                  {c.change}
                </span>
                <span class="font-mono text-xs opacity-60">{String.slice(c.sha, 0, 8)}</span>
                <span>{c.headline}</span>
              </div>

              <div class="mt-0.5 flex flex-wrap items-baseline gap-x-3 text-xs opacity-70">
                <span class="tabular-nums">{c.committed_at}</span>
                <span class="font-mono tabular-nums">+{c.additions} −{c.deletions}</span>
                <span :for={a <- c.autores} class="flex items-baseline gap-1">
                  <.link
                    :if={a.person_id}
                    navigate={~p"/people/#{a.person_id}"}
                    class="link link-hover"
                  >
                    {@nomes[a.person_id] || a.login}
                  </.link>
                  <span :if={is_nil(a.person_id)}>{a.login || a.name}</span>
                  <span :if={not a.is_primary} class="badge badge-ghost badge-xs">co-author</span>
                </span>
              </div>

              <%!-- A CADEIA COMPLETA numa linha: é a resposta a "por qual issue este
                    arquivo mudou", e ela existe porque cada elo é relação declarada. --%>
              <div class="mt-0.5 flex flex-wrap items-baseline gap-x-2 text-xs">
                <.link
                  :if={c.change_request_id}
                  navigate={~p"/work/changes/#{c.change_request_id}"}
                  class="link link-hover font-mono"
                >
                  #{c.change_request_number}
                </.link>
                <span :for={i <- c.issues} class="flex items-baseline gap-1">
                  <span class="opacity-50">for</span>
                  <.link navigate={~p"/work/issues/#{i.id}"} class="link link-hover">
                    #{i.number} {i.title}
                  </.link>
                </span>
                <span :if={c.issues == [] and c.change_request_id} class="opacity-60 italic">
                  the request closes no issue
                </span>
              </div>
            </div>
          </div>

          <div class="card min-w-0 bg-base-200">
            <div class="card-body gap-2 p-4">
              <div class="flex flex-wrap items-center gap-2">
                <h3 class="card-title text-base">Who touched it</h3>
                <span class="badge badge-outline badge-sm gap-1 text-warning">
                  <span class="size-2.5 shrink-0 rounded-[1px] outline outline-1 -outline-offset-1 outline-current bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"></span>
                  derived — counted over collected versions
                </span>
              </div>
              <p class="text-xs text-base-content/70">
                <%!-- Uma pessoa só num arquivo é sinal de concentração de conhecimento —
                      e é leitura sobre o REGISTRO, nunca sobre quem sabe o quê. --%>
                Ordered by how many versions each person authored. One name alone is a
                signal about the <strong>record</strong>, not about who knows the code.
              </p>

              <div
                :for={p <- @pessoas}
                class="flex items-baseline gap-2 border-t border-base-300 pt-1.5 text-sm"
              >
                <span class="w-8 shrink-0 text-right font-mono text-xs tabular-nums opacity-70">
                  {p.copias}×
                </span>
                <.link :if={p.person_id} navigate={~p"/people/#{p.person_id}"} class="link link-hover">
                  {@nomes[p.person_id] || p.login}
                </.link>
                <span :if={is_nil(p.person_id)}>
                  {p.login || "author no longer at the source"}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
