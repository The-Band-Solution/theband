defmodule TheBandWeb.ChangeLive.Index do
  @moduledoc """
  `/work/changes` — a lista de solicitações de mudança (feature 033).

  **Existia dado e não existia lista.** Cinco mil solicitações coletadas, alcançáveis só
  pela issue ou pela pessoa — quem perguntasse "o que está aberto há mais tempo?" não
  tinha por onde começar. A pergunta veio de quem mantém o projeto, e é o motivo desta
  tela.

  ## A busca lê a forma, e diz o que decidiu

  Um campo só: SHA, `#número`, `@pessoa` ou palavras livres. `Changes.interpretar_busca/1`
  decide, e a tela **mostra a decisão** ao lado do campo — sem isso, alguém procura um
  número de issue, recebe um commit cujo SHA começa igual, e não entende por quê.
  """
  use TheBandWeb, :live_view

  alias TheBand.Changes
  alias TheBandWeb.TabelaLive, as: Tabela

  @por_pagina 50
  @tabelas [{"changes", [], nil}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Change requests")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Tabela.aplicar(params, @tabelas) |> load()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  defp caminho(socket, id, mudancas), do: ~p"/work/changes?#{Tabela.query(socket, id, mudancas)}"

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    estado = socket.assigns.tabelas["changes"]

    opts = [
      search: estado.busca,
      limit: @por_pagina,
      offset: (estado.pagina - 1) * @por_pagina
    ]

    socket
    |> assign(por_pagina: @por_pagina)
    |> assign(solicitacoes: Changes.list(tenant, opts))
    |> assign(encontradas: Changes.count(tenant, search: estado.busca))
    |> assign(forma: elem(Changes.interpretar_busca(estado.busca || ""), 0))
    |> assign(resumo: Changes.resumo(tenant))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_tenant={@current_tenant}
      nav_area={assigns[:nav_area]}
    >
      <Layouts.work_tabs active={:changes} />
      <.header>
        Change requests
        <:subtitle>
          What was asked to change, who asked, and who integrated it — {@encontradas} found
        </:subtitle>
      </.header>

      <%!-- O PAINEL. "Fechada sem integrar" não some dentro de "fechada": é trabalho
            pedido, revisado e descartado, e somá-lo às integradas apagaria o único número
            que mede desperdício de revisão. --%>
      <div class="grid grid-cols-3 gap-2">
        <div
          :for={{rotulo, valor, cor} <- quadros(@resumo)}
          class="rounded-lg border border-base-300 px-3 py-2"
        >
          <span class={["block font-mono text-xl tabular-nums", cor]}>{valor}</span>
          <span class="text-xs opacity-70">{rotulo}</span>
        </div>
      </div>

      <%!-- O ESCOPO, em painel próprio e com as frases separadas.

            A primeira versão tinha um quadro só, "no issue recognised", com 4.177 — 83%
            das solicitações. **Estava errado**, e quem mantém o projeto pegou pelo volume:
            conferidos contra a origem, dois de três amostrados fechavam issue sim. O
            número somava falha nossa com fato sobre o processo (issue #438).

            Agora são quatro, e a diferença entre eles é a diferença entre acusar a
            organização e admitir a própria lacuna. --%>
      <div class="rounded-lg border border-base-300 p-3">
        <h2 class="mb-1 text-sm font-semibold">
          Link to what was asked
          <span class="badge badge-outline badge-warning badge-xs ml-1">derived</span>
        </h2>
        <p class="mb-2 text-xs opacity-70">
          What the source recognised from the closing keywords — and, separately, what it
          recognised that we have not resolved yet.
        </p>
        <div class="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <div
            :for={{rotulo, valor, cor, dica} <- quadros_de_escopo(@resumo)}
            class="min-w-0"
            title={dica}
          >
            <span class={["block font-mono text-lg tabular-nums", cor]}>{valor}</span>
            <span class="text-xs opacity-70">{rotulo}</span>
          </div>
        </div>
      </div>

      <%!-- O componente da casa já carrega a regra: a tela DECLARA onde procura, porque
            busca que não diz onde faz quem não encontra concluir que o dado não existe. --%>
      <.busca
        valor={@tabelas["changes"].busca}
        onde="title, number, person, branch — or a commit SHA"
        tabela="changes"
      />

      <%!-- A DECISÃO DA BUSCA, dita. Sem ela, procurar "1234" e receber um commit cujo
            SHA começa assim é indistinguível de erro da plataforma. --%>
      <p :if={@forma != :vazia} class="mt-1 mb-3 font-mono text-xs opacity-70">
        {frase_da_forma(@forma)}
      </p>

      <p :if={@tabelas["changes"].busca not in [nil, ""] and @encontradas == 0} class="alert">
        Nothing matches “{@tabelas["changes"].busca}” <strong>among what was collected</strong>.
        Change requests are collected per repository; a commit outside a request is not here yet.
      </p>

      <div :if={@solicitacoes != []} class="overflow-x-auto">
        <table class="table stacked table-sm">
          <thead>
            <tr>
              <th>request</th>
              <th>state</th>
              <th>asked by</th>
              <th>integrated by</th>
              <th>commits</th>
              <th>opened</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={s <- @solicitacoes}>
              <td data-label="request">
                <.link navigate={~p"/work/changes/#{s.id}"} class="link link-hover font-medium">
                  <span class="font-mono opacity-60">#{s.number}</span> {s.title}
                </.link>
              </td>
              <td data-label="state">
                <span class={[
                  "badge badge-sm",
                  s.state == "MERGED" && "badge-success badge-outline",
                  s.state == "OPEN" && "badge-ghost",
                  s.state == "CLOSED" && "badge-error badge-outline"
                ]}>
                  {String.downcase(s.state || "")}
                </span>
              </td>
              <td data-label="asked by" class="text-xs">
                <.link
                  :if={s.author_person_id}
                  navigate={~p"/people/#{s.author_person_id}"}
                  class="link link-hover"
                >
                  {s.author_login}
                </.link>
                <span :if={is_nil(s.author_person_id)}>{s.author_login || "—"}</span>
              </td>
              <td data-label="integrated by" class="text-xs">
                <span :if={s.merged_by_login}>{s.merged_by_login}</span>
                <%!-- Fechada sem integrar é fato sobre o trabalho, não campo vazio. --%>
                <span :if={is_nil(s.merged_by_login)} class="opacity-60 italic">
                  {if s.state == "OPEN", do: "still open", else: "closed without merging"}
                </span>
              </td>
              <td data-label="commits" class="font-mono text-xs tabular-nums">
                {s.commits_collected || 0}<span
                  :if={truncado?(s)}
                  class="text-warning"
                  title="collected fewer than the source reports"
                >/{s.commits_total}</span>
              </td>
              <td data-label="opened" class="text-xs">{s.created_at}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <.paginacao
        pagina={@tabelas["changes"].pagina}
        por_pagina={@por_pagina}
        total={@encontradas}
        tabela="changes"
      />
    </Layouts.app>
    """
  end

  # A ordem conta o ciclo: o que entrou, o que foi descartado, o que ainda está aberto.
  defp quadros(resumo) do
    [
      {"merged", Map.get(resumo, "MERGED", 0), ""},
      {"closed without merging", Map.get(resumo, "CLOSED", 0), "text-warning"},
      {"still open", Map.get(resumo, "OPEN", 0), ""}
    ]
  end

  # As três frases sobre escopo, mais a que é a NOSSA lacuna. Nenhuma soma com outra — foi
  # somá-las que produziu a medida errada de 83%.
  defp quadros_de_escopo(resumo) do
    [
      {"attends an issue", Map.get(resumo, :com_escopo, 0), "",
       "the source recognised a closing issue and we resolved it"},
      {"attends none", Map.get(resumo, :sem_escopo, 0), "",
       "the source recognised no closing issue — a change outside declared scope, common and not a fault"},
      {"issue not collected yet", Map.get(resumo, :escopo_pendente, 0), "text-warning",
       "the source recognised an issue we have not collected — our gap, not the organisation's"},
      {"not measured", Map.get(resumo, :nao_sabemos, 0), "opacity-60",
       "collected before the platform recorded what the source said — unknown, never zero"}
    ]
  end

  defp truncado?(%{commits_total: total, commits_collected: coletados})
       when is_integer(total) and is_integer(coletados),
       do: coletados < total

  defp truncado?(_), do: false

  defp frase_da_forma(:sha),
    do: "looks like a SHA · searching commits, and the request that carries them"

  defp frase_da_forma(:numero),
    do: "a number · searching request numbers (it may exist in more than one repository)"

  defp frase_da_forma(:pessoa), do: "starts with @ · searching who asked and who integrated"

  defp frase_da_forma(:palavras),
    do: "words · searching title, body and branch name — every word must match"

  defp frase_da_forma(_), do: ""
end
