defmodule TheBandWeb.ChangeLive.Commits do
  @moduledoc """
  `/people/:id/commits` — os commits de uma pessoa (feature 033).

  A seção da página da pessoa mostra os dez mais recentes; esta tela mostra todos, com
  busca. E **inclui os commits em que a pessoa é co-autora**: o escopo passa pelos
  autores, nunca por uma coluna do commit — quem só participa pelo trailer
  `Co-Authored-By` apareceria vazio de outro jeito.
  """
  use TheBandWeb, :live_view

  alias TheBand.Changes
  alias TheBand.Ontology.SEON.EO
  alias TheBandWeb.TabelaLive, as: Tabela

  @por_pagina 50
  @tabelas [{"commits", [], nil}]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case EO.fetch_person(tenant, id) do
      {:ok, pessoa} ->
        {:ok,
         assign(socket, page_title: "Commits · #{pessoa.name || pessoa.login}", pessoa: pessoa)}

      # Id de outro tenant devolve "não encontrada", nunca "sem permissão".
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Person not found.") |> push_navigate(to: ~p"/people")}
    end
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{pessoa: nil}} = socket), do: {:noreply, socket}

  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Tabela.aplicar(params, @tabelas) |> load()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  defp caminho(socket, id, mudancas),
    do: ~p"/people/#{socket.assigns.pessoa.id}/commits?#{Tabela.query(socket, id, mudancas)}"

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    estado = socket.assigns.tabelas["commits"]
    pessoa_id = socket.assigns.pessoa.id

    opts = [
      person_id: pessoa_id,
      search: estado.busca,
      limit: @por_pagina,
      offset: (estado.pagina - 1) * @por_pagina
    ]

    socket
    |> assign(por_pagina: @por_pagina)
    |> assign(commits: Changes.list_commits(tenant, opts))
    |> assign(
      encontrados: Changes.count_commits(tenant, person_id: pessoa_id, search: estado.busca)
    )
    |> assign(forma: elem(Changes.interpretar_busca(estado.busca || ""), 0))
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
        %{rotulo: "People", destino: ~p"/people"},
        %{rotulo: @pessoa.name || @pessoa.login, destino: ~p"/people/#{@pessoa.id}"},
        %{rotulo: "commits", destino: nil}
      ]} />

      <.header>
        Commits · {@pessoa.name || @pessoa.login}
        <:subtitle>
          {@encontrados} collected — including the ones where they are a <strong>co-author</strong>, not the author Git records
        </:subtitle>
      </.header>

      <.busca
        valor={@tabelas["commits"].busca}
        onde="commit message, SHA, request number or person"
        tabela="commits"
      />

      <p :if={@forma != :vazia} class="mt-1 mb-3 font-mono text-xs opacity-70">
        {frase_da_forma(@forma)}
      </p>

      <p :if={@encontrados == 0} class="alert">
        <span :if={@tabelas["commits"].busca in [nil, ""]}>
          No commit collected for this person. Commits are collected through change requests —
          a commit pushed straight to the branch is not here yet.
        </span>
        <span :if={@tabelas["commits"].busca not in [nil, ""]}>
          Nothing matches “{@tabelas["commits"].busca}” among this person's collected commits.
        </span>
      </p>

      <div :if={@commits != []} class="overflow-x-auto">
        <table class="table stacked table-sm">
          <thead>
            <tr>
              <th>commit</th>
              <th>request</th>
              <th>lines</th>
              <th>when</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={c <- @commits}>
              <td data-label="commit">
                <span class="font-mono text-xs opacity-60">{String.slice(c.sha, 0, 8)}</span>
                <span class="ml-1">{c.headline}</span>
              </td>
              <td data-label="request" class="text-xs">
                <.link
                  :if={c.change_request_id}
                  navigate={~p"/work/changes/#{c.change_request_id}"}
                  class="link link-hover font-mono"
                >
                  #{c.change_request_number}
                </.link>
                <%!-- Commit sem solicitação é representável e hoje não é coletado — dizer
                      isso é diferente de deixar a célula vazia. --%>
                <span :if={is_nil(c.change_request_id)} class="opacity-60 italic">
                  outside a request
                </span>
              </td>
              <td data-label="lines" class="font-mono text-xs tabular-nums">
                <span :if={c.additions} class="text-success">+{c.additions}</span>
                <span :if={c.deletions} class="text-error">−{c.deletions}</span>
              </td>
              <td data-label="when" class="text-xs">{c.committed_at}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <.paginacao
        pagina={@tabelas["commits"].pagina}
        por_pagina={@por_pagina}
        total={@encontrados}
        tabela="commits"
      />
    </Layouts.app>
    """
  end

  defp frase_da_forma(:sha), do: "looks like a SHA · searching by prefix"

  defp frase_da_forma(:numero),
    do: "a number · searching the change request that carries the commit"

  defp frase_da_forma(:pessoa), do: "starts with @ · searching co-authors too"

  defp frase_da_forma(:palavras),
    do: "words · searching the commit message — every word must match"

  defp frase_da_forma(_), do: ""
end
