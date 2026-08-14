defmodule TheBandWeb.WorkItemLive.Index do
  @moduledoc """
  `/work` — as issues coletadas, o que elas são, e **o que não foi classificado**.

  ## As três seções somam o total, sempre

  Coletadas = promovidas + não promovidas. Quando não soma, a tela mostra o desvio em
  vez de esconder: a diferença significa promoção não registrada, e é defeito de coleta.
  Um cabeçalho que diz 142 sobre uma lista que soma 124 é exatamente o que esta tela
  existe para tornar visível.

  ## A lacuna carrega o nome do tipo

  "tipo desconhecido: 14" não diz onde a regra precisa mudar. "Spike (9), Chore (5)"
  diz. É por isso que `issue_type` é gravado cru e a contagem agrupa por nome.

  ## A divergência não é erro da plataforma

  É sinal sobre o processo do time: épico abandonado sem decomposição, ou user story que
  cresceu e virou épico sem ninguém retipar. Ela só aparece porque a estrutura vence o
  rótulo, e desapareceria se a plataforma gravasse apenas o resultado da promoção.

  ## O que esta tela não mostra, de propósito

    * **soma de épicos com atômicas** — são coisas diferentes: tarefa se liga a atômica,
      e escopo se conta na folha. A soma seria contagem dupla;
    * **percentual de cobertura da promoção** — um número que sobe quando alguém tipa
      issues, e não quando o produto melhora. Vira meta e deixa de medir.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems
  alias TheBandWeb.ConceptLabel
  alias TheBandWeb.EstadoDaTabela

  @por_pagina 50

  # As colunas que esta tabela ordena. É desta lista que sai o átomo — nunca do parâmetro.
  @colunas [:number, :title, :issue_type, :state, :conceito]

  @impl true

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Trabalho")}
  end

  # **O estado da tabela vem do endereço, e não do socket.** Recarregar precisa devolver a
  # mesma tela, e o link precisa levar quem recebe ao que quem mandou estava vendo — issue #292.
  @impl true
  def handle_params(params, _uri, socket) do
    {estado, avisos} = EstadoDaTabela.ler(params, @colunas)

    {:noreply,
     socket
     |> assign(repositorio: repositorio(params))
     |> assign(busca: estado.busca, ordem: estado.ordem, pagina: estado.pagina)
     |> avisar(avisos)
     |> load()}
  end

  defp repositorio(%{"repositorio" => id}) when id not in [nil, ""], do: id
  defp repositorio(_), do: nil

  # Parâmetro que não deu para ler é **dito**. Ignorar em silêncio faria a tela mostrar uma
  # coisa enquanto o endereço diz outra, e quem mandou o link nunca saberia.
  defp avisar(socket, []), do: socket
  defp avisar(socket, avisos), do: put_flash(socket, :error, Enum.join(avisos, " "))

  @impl true
  # Trocar o filtro volta para a primeira página. Manter a página 4 ao filtrar um
  # repositório de 12 issues mostraria uma lista vazia, e quem lê concluiria que não há
  # issues em vez de que está fora do fim.
  def handle_event("filtrar", %{"repositorio" => id}, socket),
    do: {:noreply, push_patch(socket, to: caminho(socket, repositorio: id, pagina: 1))}

  # Buscar volta para a primeira página **sempre**. Ficar na página 12 de um resultado de duas
  # mostraria uma tabela vazia com paginação afirmando que há mais.
  def handle_event("buscar", %{"q" => q}, socket),
    do: {:noreply, push_patch(socket, to: caminho(socket, busca: q, pagina: 1))}

  def handle_event("ordenar", %{"campo" => campo}, socket) do
    ordem = EstadoDaTabela.proxima_ordem(socket.assigns.ordem, campo(campo))

    {:noreply, push_patch(socket, to: caminho(socket, ordem: ordem, pagina: 1))}
  end

  def handle_event("pagina", %{"n" => n}, socket),
    do: {:noreply, push_patch(socket, to: caminho(socket, pagina: String.to_integer(n)))}

  # O átomo vem da lista declarada, e nunca do texto que chegou do navegador.
  defp campo(bruto), do: Enum.find(@colunas, &(Atom.to_string(&1) == bruto))

  defp caminho(socket, mudancas) do
    estado =
      %{
        busca: socket.assigns.busca,
        ordem: socket.assigns.ordem,
        pagina: socket.assigns.pagina
      }
      |> Map.merge(Map.new(Keyword.take(mudancas, [:busca, :ordem, :pagina])))

    repositorio = Keyword.get(mudancas, :repositorio, socket.assigns.repositorio)

    ~p"/work?#{EstadoDaTabela.para_query(estado, repositorio: repositorio)}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Work
        <:subtitle>
          {@coletadas} {plural(@coletadas, "issue")} collected · {@repos_observados} {plural(
            @repos_observados,
            "repository",
            "repositories"
          )} observed
        </:subtitle>
      </.header>

      <%!-- No collect action here, and that is a decision. The Syncs button brings
            everything — people, teams, repositories and issues, in one run. A second place
            to trigger it would produce two readings of "when was this updated", and the
            right answer is one. --%>

      <.empty :if={@coletadas == 0} title={estado_vazio_titulo(@repos_observados)}>
        {estado_vazio_texto(@repos_observados)}
      </.empty>

      <div :if={@coletadas > 0} class="space-y-6">
        <%!-- The deviation is shown in full, not hidden: it means a promotion was never
              recorded, and that is a collection defect rather than a display one. --%>
        <.notice :if={@desvio != 0} kind={:refused} title="The counts do not add up.">
          {@coletadas} collected, {@total_promovido} promoted and {@total_lacuna} not promoted
          — {@desvio} unaccounted for. Some issue has no promotion recorded, and the numbers
          below are smaller than reality.
        </.notice>

        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div class="card bg-base-200">
            <div class="card-body gap-3 p-4 sm:p-5">
              <.metric
                label="promoted"
                value={@total_promovido}
                sub={"of #{@coletadas} collected"}
              />
              <dl class="text-sm">
                <div :for={{conceito, rotulo} <- @conceitos} :if={@promovidas[conceito]}>
                  <.field label={rotulo}>
                    <span class="tabular">{@promovidas[conceito]}</span>
                  </.field>
                </div>
              </dl>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body gap-3 p-4 sm:p-5">
              <.metric label="not promoted" value={@total_lacuna} />
              <p :if={@total_lacuna == 0} class="text-sm text-base-content/70">
                Every type this organisation uses has a route.
              </p>
              <dl :if={@total_lacuna > 0} class="text-sm">
                <div :for={{motivo, n} <- @lacunas}>
                  <.field label={ConceptLabel.motivo(motivo)}>
                    <span class="tabular">{n}</span>
                  </.field>
                </div>
              </dl>
              <%!-- Without the type name the gap says nothing about where the rule must
                    change: "unknown type: 37" answers nothing, "Chore (17)" answers. --%>
              <p :if={@tipos_desconhecidos != []} class="text-xs text-base-content/60">
                {Enum.map_join(@tipos_desconhecidos, ", ", fn {t, c} -> "#{t} (#{c})" end)}
              </p>
            </div>
          </div>

          <div class="card bg-base-200 sm:col-span-2 lg:col-span-1">
            <div class="card-body gap-3 p-4 sm:p-5">
              <.metric label="divergences" value={length(@divergencias)} />
              <p :if={@divergencias == []} class="text-sm text-base-content/70">
                None. Label and structure agree on every issue.
              </p>
              <%!-- Grouped by kind, not merely listed: "12 divergences" says nothing about
                    what to do, "9 tasks with parts, 3 epics without parts" does. Counting
                    by the sentence would need substring matching, which breaks the moment
                    someone improves the wording. --%>
              <dl :if={@por_tipo != %{}} class="text-sm">
                <div :for={{tipo, n} <- @por_tipo}>
                  <.field label={ConceptLabel.divergencia(tipo)}>
                    <span class="tabular">{n}</span>
                    <div class="text-xs text-base-content/60">
                      {if ConceptLabel.divergencia_mudou_conceito?(tipo),
                        do: "concept decided by the axiom",
                        else: "concept kept — signal"}
                    </div>
                  </.field>
                </div>
              </dl>
            </div>
          </div>
        </div>

        <section class="space-y-2">
          <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h3 class="font-semibold">Repositories</h3>
              <%!-- A frase entra UMA vez, e não uma por linha: repetir 39 vezes gastaria a
                    atenção que o motivo de cada uma precisa ter. --%>
              <p :if={@inacessiveis > 0} class="text-xs text-base-content/60">
                {@inacessiveis} {plural(@inacessiveis, "repository", "repositories")} could not be
                reached in the last collection. The platform tries again on every collection.
              </p>
            </div>
            <form phx-change="filtrar">
              <label class="sr-only" for="repo-filter">Filter by repository</label>
              <select
                id="repo-filter"
                name="repositorio"
                class="select select-sm select-bordered w-full sm:w-auto"
              >
                <option value="">all repositories</option>
                <option
                  :for={r <- @repositorios}
                  value={r.observed_repository_id}
                  selected={@repositorio == r.observed_repository_id}
                >
                  {r.name}
                </option>
              </select>
            </form>
          </div>

          <div class="overflow-x-auto">
            <table class="table table-sm stacked">
              <thead>
                <tr>
                  <%!-- The organisation comes before the repository, and that is reading
                        order: two repositories can share a name across organisations, and
                        without the column the list shows `theband` twice saying nothing. --%>
                  <th>organisation</th>
                  <th>repository</th>
                  <th>language</th>
                  <th>branch</th>
                  <th>work</th>
                  <th class="text-right">issues</th>
                  <th>state</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={r <- @repositorios}>
                  <td data-label="organisation" class="text-xs opacity-70">
                    {organizacao(@onde, r)}
                  </td>
                  <%!-- The name opens the detail **inside the platform**, not the source:
                        what matters on click is what was collected. The link to the source
                        lives in there. --%>
                  <td data-label="repository">
                    <.link
                      navigate={~p"/work/repositories/#{r.observed_repository_id}"}
                      class="link link-hover"
                    >
                      {r.name}
                    </.link>
                  </td>
                  <td data-label="language" class="opacity-70">
                    {r.primary_language || "not declared"}
                  </td>
                  <td data-label="branch" class="font-mono text-xs opacity-70">
                    {r.default_branch || "—"}
                  </td>
                  <%!-- The mark answers one question — is there work here? — and never
                        repeats what the `state` column says beside it. Three channels:
                        shape, text, and a screen-reader label. Colour is not a channel
                        (WCAG 1.4.1). --%>
                  <td data-label="work">
                    <span class="inline-flex items-center gap-1.5 text-sm">
                      <span
                        class={[
                          "size-2.5 shrink-0 rounded-[1px]",
                          marca(r, @por_repositorio) == :cheia && "bg-current text-success",
                          marca(r, @por_repositorio) == :vazia &&
                            "border border-current text-base-content/50",
                          marca(r, @por_repositorio) == :desconhecida &&
                            "border border-dashed border-current text-base-content/40"
                        ]}
                        aria-hidden="true"
                      ></span>
                      <span class={marca(r, @por_repositorio) == :cheia || "text-base-content/60"}>
                        {marca_texto(r, @por_repositorio, @com_ausentes)}
                      </span>
                      <span class="sr-only">
                        {marca_rotulo(r, @por_repositorio, @com_ausentes)}
                      </span>
                    </span>
                  </td>
                  <td data-label="issues" class="text-right tabular">
                    {@por_repositorio[r.observed_repository_id] || 0}
                  </td>
                  <%!-- `unreachable` sozinho lê como abandono — e era verdade até a feature 009,
                        porque o repositório marcado era filtrado antes da fase que limparia a
                        marca. Com a data, quem lê distingue falha de agora de problema crônico;
                        com o motivo, decide se age. Em texto, nunca só por cor. --%>
                  <td data-label="state">
                    {situacao(r)}
                    <div
                      :if={r.inaccessible_since && r.inaccessible_reason}
                      class="text-xs text-base-content/60"
                      title={r.inaccessible_reason}
                    >
                      {motivo_curto(r.inaccessible_reason)}
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section class="space-y-2">
          <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <h3 class="font-semibold">Issues</h3>
            <.busca valor={@busca} onde="title and number" />
            <span class="text-sm text-base-content/70">
              {faixa(@pagina, @por_pagina, @encontradas)} of {@encontradas}
              <span :if={@busca != ""}>
                found
              </span>
            </span>
          </div>

          <p :if={@busca != "" and @encontradas == 0} class="alert">
            Nenhuma issue com “{@busca}” no título ou no número. A busca não alcança conceito nem
            repositório — eles têm coluna própria.
          </p>

          <div class="overflow-x-auto">
            <table class="table table-sm stacked">
              <thead>
                <tr>
                  <th>organisation</th>
                  <th>repository</th>
                  <.th_ordenavel campo={:number} rotulo="#" ordem={@ordem} class="text-right" />
                  <.th_ordenavel campo={:title} rotulo="title" ordem={@ordem} />
                  <.th_ordenavel campo={:issue_type} rotulo="type at source" ordem={@ordem} />
                  <th class="text-right">parts at source</th>
                  <.th_ordenavel campo={:conceito} rotulo="promoted to" ordem={@ordem} />
                </tr>
              </thead>
              <tbody>
                <tr :for={i <- @issues}>
                  <td data-label="organisation" class="text-xs opacity-70">
                    {origem(@onde, i).organizacao}
                  </td>
                  <td data-label="repository" class="text-xs">{origem(@onde, i).repositorio}</td>
                  <td data-label="#" class="text-right tabular">
                    <.link navigate={~p"/work/issues/#{i.id}"} class="link link-hover">
                      {i.number}
                    </.link>
                  </td>
                  <td data-label="title" class="max-w-sm sm:truncate">
                    <.link navigate={~p"/work/issues/#{i.id}"} class="link link-hover">
                      {i.title}
                    </.link>
                  </td>
                  <td data-label="type at source">
                    <span :if={i.issue_type} class="badge badge-xs badge-ghost">
                      {i.issue_type}
                    </span>
                    <span :if={is_nil(i.issue_type)} class="text-xs opacity-60">none</span>
                  </td>
                  <td data-label="parts at source" class="text-right tabular text-xs">
                    {i.sub_issue_count}
                  </td>
                  <td data-label="promoted to">
                    <.evidence
                      concept={i.derived_concept}
                      source={i.evidence_source}
                      confidence={i.confidence}
                      skip_reason={i.skip_reason}
                      skip_detail={i.skip_detail}
                    />
                    <div :if={i.divergence_kind} class="text-xs text-warning">
                      {ConceptLabel.divergencia(i.divergence_kind)}
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <.paginacao pagina={@pagina} por_pagina={@por_pagina} total={@encontradas} />
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    opts = filtro(socket.assigns.repositorio)

    # **A busca entra na listagem e no total, e não nos painéis de cima.**
    #
    # Os painéis respondem "o que a plataforma sabe deste escopo" — 4 529 issues, 520 divergências.
    # Filtrá-los pela busca faria os números mudarem enquanto alguém digita, e quem lesse
    # concluiria que a plataforma esqueceu o resto.
    #
    # A listagem responde outra pergunta: "quais destas eu procuro". Só ela filtra.
    da_lista = Keyword.merge(opts, search: socket.assigns.busca, order_by: socket.assigns.ordem)

    coletadas = WorkItems.count_collected(tenant, opts)
    encontradas = WorkItems.count_collected(tenant, da_lista)
    promovidas = WorkItems.count_by_promotion(tenant, opts)
    lacunas = WorkItems.count_gaps_by_reason(tenant, opts)
    total_promovido = soma(promovidas)
    total_lacuna = soma(lacunas)
    repositorios = CMPO.list_observed(tenant)

    socket
    |> assign(
      coletadas: coletadas,
      promovidas: promovidas,
      lacunas: lacunas,
      total_promovido: total_promovido,
      total_lacuna: total_lacuna,
      # A invariante da tela, e ela é exibida quando falha: SC-001.
      desvio: coletadas - total_promovido - total_lacuna,
      tipos_desconhecidos: WorkItems.unknown_types(tenant, opts),
      divergencias: WorkItems.list_divergences(tenant, opts),
      por_tipo: WorkItems.count_divergences_by_kind(tenant, opts),
      encontradas: encontradas,
      issues:
        WorkItems.list_issues(
          tenant,
          da_lista
          |> Keyword.put(:limit, @por_pagina)
          |> Keyword.put(:offset, (socket.assigns.pagina - 1) * @por_pagina)
        ),
      por_pagina: @por_pagina,
      onde: onde(tenant, repositorios),
      repositorios: repositorios,
      repos_observados: length(repositorios),
      por_repositorio: por_repositorio(tenant, repositorios),
      inacessiveis: Enum.count(repositorios, & &1.inaccessible_since),
      com_ausentes:
        WorkItems.repositories_with_absent_issues(
          tenant,
          Enum.map(repositorios, & &1.observed_repository_id)
        ),
      conceitos: ConceptLabel.conceitos()
    )
  end

  defp filtro(nil), do: []
  defp filtro(id), do: [observed_repository_id: id]

  # Repositório e organização vêm de **outros módulos**, e a composição é aqui: a issue
  # é plataforma, o repositório é CMPO, a organização é EO. Uma consulta que juntasse as
  # três tabelas alcançaria schema alheio e quebraria a fronteira que a ADR 0003 impõe —
  # e passaria a quebrar a cada mudança de derivação.
  defp onde(tenant, repositorios) do
    orgs = Map.new(EO.list_organizations(tenant), &{&1.id, &1.login || &1.name})

    Map.new(repositorios, fn r ->
      {r.observed_repository_id,
       %{repositorio: r.name, organizacao: Map.get(orgs, r.organization_id, "—")}}
    end)
  end

  defp origem(onde, issue),
    do: Map.get(onde, issue.observed_repository_id, %{repositorio: "—", organizacao: "—"})

  # O mesmo mapa que a listagem de issues usa. Uma segunda consulta aqui poderia devolver
  # nome diferente do que a linha da issue mostra, para a mesma organização.
  defp organizacao(onde, repositorio),
    do: Map.get(onde, repositorio.observed_repository_id, %{organizacao: "—"}).organizacao

  defp faixa(_pagina, _por_pagina, 0), do: "0"

  defp faixa(pagina, por_pagina, total) do
    inicio = (pagina - 1) * por_pagina + 1
    "#{inicio}–#{min(pagina * por_pagina, total)}"
  end

  # para desenhar a tela, e a marca de trabalho precisa do mesmo número — ler de novo
  # faria 270. A contagem passa a ser de issues **vigentes**, e a mudança de significado
  # está declarada em R3 da pesquisa: a coluna e a marca leem o mesmo mapa, que é o que
  # FR-010 exige.
  #
  # O mapa **não** tem chave para repositório sem issue. Quem lê usa `|| 0` no markup, e o
  # zero ali significa "nenhuma issue vigente"; "não se sabe" vem de `issues_collected_at`.
  defp por_repositorio(tenant, repositorios) do
    WorkItems.count_collected_by_repository(
      tenant,
      Enum.map(repositorios, & &1.observed_repository_id)
    )
  end

  defp soma(mapa), do: mapa |> Map.values() |> Enum.sum()

  # Os rótulos vivem em `TheBandWeb.ConceptLabel`, e não aqui: três telas mostram os
  # mesmos conceitos, e com a lista copiada em cada uma `sro.epic` viraria "épico" numa e
  # "epic" na outra.
  defp plural(1, singular, _plural), do: singular
  defp plural(_n, _singular, plural), do: plural
  defp plural(n, singular), do: plural(n, singular, singular <> "s")

  # Três estados vazios diferentes. Um texto só para os três faria alguém concluir que o
  # time não trabalha — FR-036.
  # Three different empty states. One text for all three would let someone conclude the
  # team does not work — FR-036.
  defp estado_vazio_titulo(0), do: "No issue collection has run yet."
  defp estado_vazio_titulo(_), do: "No repository in this organisation has issues."

  defp estado_vazio_texto(0),
    do:
      "Connect a tool and sync. Repositories are discovered from the organisation — " <>
        "you do not need to connect them one by one."

  defp estado_vazio_texto(n),
    do:
      "#{n} repositories were observed and none has issues. That is different from not " <>
        "having collected: the collection ran, and the result is empty."

  # A ordem é **a contagem primeiro**, e errá-la faz a tela mentir sobre 41 repositórios.
  #
  # Depois da migração todos os 135 observados têm `issues_collected_at` nulo, porque
  # nenhuma coleta anterior registrou a data — e 41 deles têm issues dentro, um com 2514.
  # Decidir pela data antes da contagem diria `not collected yet` sobre eles: a plataforma
  # afirmando que nunca olhou um repositório de que ela tem 2514 issues coletadas.
  #
  # A data só decide quando a contagem é zero. Foi o achado A1 da análise, e é FR-005a.
  defp marca(repositorio, contagens) do
    cond do
      contagem(repositorio, contagens) > 0 -> :cheia
      repositorio.issues_collected_at -> :vazia
      true -> :desconhecida
    end
  end

  # O quarto texto, que não é um quarto estado da marca: houve trabalho e ele não está
  # vigente. "no issues" ali afirmaria que nunca existiu, e apagaria o fato de que existiu
  # — a mesma distinção que `no_longer_observed_at` carrega no banco.
  defp marca_texto(repositorio, contagens, com_ausentes) do
    case marca(repositorio, contagens) do
      :cheia ->
        "#{contagem(repositorio, contagens)} #{plural(contagem(repositorio, contagens), "issue")}"

      :vazia ->
        if teve_trabalho?(repositorio, com_ausentes),
          do: "no current work",
          else: "collected, no issues"

      # "not collected yet" **afirmaria** que a coleta não ocorreu, e a plataforma não sabe
      # isso: `nil` significa que não há registro. Medido no dado real logo depois da
      # migração — 94 repositórios com a data nula, e 61 deles a coleta de fato visitou e
      # não achou nada. Dizer "não coletado" sobre eles seria a tela afirmando o que ela
      # não observou, que é o defeito oposto ao que a marca existe para evitar.
      :desconhecida ->
        "no collection recorded"
    end
  end

  # O rótulo do leitor de tela diz o estado **por extenso**, e não repete o texto visível:
  # quem ouve não tem a forma nem a coluna ao lado para completar o sentido.
  defp marca_rotulo(repositorio, contagens, com_ausentes) do
    case marca(repositorio, contagens) do
      :cheia ->
        "has collected work"

      :vazia ->
        if teve_trabalho?(repositorio, com_ausentes),
          do: "no current work: issues were collected before and none of them is present now",
          else: "no work: issues were collected and none were found"

      :desconhecida ->
        "unknown: there is no record of an issue collection for this repository"
    end
  end

  defp teve_trabalho?(repositorio, com_ausentes),
    do: MapSet.member?(com_ausentes, repositorio.observed_repository_id)

  defp contagem(repositorio, contagens),
    do: Map.get(contagens, repositorio.observed_repository_id, 0)

  defp situacao(%{excluded_at: at}) when not is_nil(at), do: "excluded by the tenant"

  defp situacao(%{inaccessible_since: at}) when not is_nil(at),
    do: "unreachable since #{Calendar.strftime(at, "%d %b")}"

  defp situacao(%{archived_at: at}) when not is_nil(at), do: "archived at the source"
  defp situacao(_), do: "observed"

  # Truncado na exibição, com o texto completo no `title`: o motivo real tem 228 caracteres, e
  # numa tabela de 135 linhas ele domina a linha. Isto **não** substitui a truncagem na borda —
  # aquela impede a queda, esta cuida da leitura.
  defp motivo_curto(motivo) when byte_size(motivo) > 80, do: String.slice(motivo, 0, 80) <> "…"
  defp motivo_curto(motivo), do: motivo
end
