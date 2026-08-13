defmodule TheBandWeb.RepositoryLive.Show do
  @moduledoc """
  `/work/repositories/:id` — um repositório e as issues dele.

  ## Uma coisa, e ela é "este repositório"

  Princípio X. A tela de trabalho responde *"a coleta classificou o quê, no tenant"*; esta
  responde *"o que existe neste repositório"*. Misturar as duas produziria o erro que já
  aconteceu no cartão de sincronização: um número do tenant parecendo ser da execução.

  ## O cabeçalho soma o total, e a soma é a verificação

      coletadas == soma(promovidas por conceito) + soma(não promovidas por motivo)

  Quando não fecha, a tela mostra o desvio em vez de esconder: a diferença significa
  promoção não registrada, e é defeito de coleta.

  ## Vazio não é a mesma coisa que não coletado

  Repositório observado com zero issues teve a coleta ocorrida e resultado vazio.
  Repositório inacessível ou excluído da observação **não foi olhado** — e as issues que
  ele já tinha continuam consultáveis, porque a plataforma parou de olhar e isso não é o
  dado ter sumido.

  ## Os avisos de axioma são do repositório inteiro

  As tarefas cujo pai é épico e as sem pai aparecem aqui em lista, pela mesma função que o
  detalhe de cada issue usa individualmente. A issue permanece promovida: o inválido é o
  vínculo.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems
  alias TheBandWeb.ConceptLabel

  @por_pagina 50

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    # Repositório de outro tenant devolve "não encontrado", nunca "sem permissão".
    case CMPO.fetch_observed(tenant, id) do
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Repository not found.")
         |> push_navigate(to: ~p"/work")}

      {:ok, repositorio} ->
        {:ok,
         socket
         |> assign(page_title: repositorio.name, repositorio: repositorio, pagina: 1)
         |> carregar()}
    end
  end

  @impl true
  def handle_event("pagina", %{"n" => n}, socket),
    do: {:noreply, socket |> assign(pagina: String.to_integer(n)) |> carregar()}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.breadcrumb niveis={[
        %{rotulo: "Work", destino: ~p"/work"},
        %{rotulo: @repositorio.name, destino: nil}
      ]} />
      <.header>
        {@repositorio.name}
        <:subtitle>
          {@organizacao} · {@coletadas} {if @coletadas == 1, do: "issue", else: "issues"} · {situacao(
            @repositorio
          )}
        </:subtitle>
        <:actions>
          <.link navigate={~p"/work"}>
            <.button class="btn-outline btn-sm">All issues</.button>
          </.link>
          <a :if={@repositorio.url} href={@repositorio.url} target="_blank" rel="noopener">
            <.button class="btn-outline btn-sm">View at source</.button>
          </a>
        </:actions>
      </.header>

      <div :if={@repositorio.excluded_at} class="alert mt-6 block">
        <div class="font-semibold">This repository is excluded from observation.</div>
        <p class="text-sm opacity-80">
          The issues below are still readable: the platform stopped looking, and that is
          different from the data being gone. None of them was marked absent because of the
          exclusion.
        </p>
      </div>

      <div :if={@repositorio.inaccessible_since} class="alert alert-warning mt-6 block">
        <div class="font-semibold">Repository unreachable in the last collection.</div>
        <p class="text-sm">
          {@repositorio.inaccessible_reason} — losing reach does not mark the issues as
          absent.
        </p>
      </div>

      <div class="mt-6 grid gap-6 md:grid-cols-3">
        <div class="card bg-base-200 md:col-span-2">
          <div class="card-body">
            <h3 class="font-semibold">What the source reports</h3>
            <dl class="text-sm grid gap-x-6 gap-y-1 sm:grid-cols-2">
              <.field label="qualified name">
                <span class="font-mono text-xs">{@repositorio.qualified_name}</span>
              </.field>
              <.field label="language">{@repositorio.primary_language || "not declared"}</.field>
              <.field label="default branch">
                <span class="font-mono text-xs">{@repositorio.default_branch || "—"}</span>
              </.field>
              <.field label="created at source">
                {data(@repositorio.external_created_at) || "—"}
              </.field>
              <.field label="last push">{data(@repositorio.last_pushed_at) || "—"}</.field>
              <.field label="archived">
                {data(@repositorio.archived_at) || "no"}
              </.field>
              <.field label="first collected">{data(@repositorio.collected_at)}</.field>
              <.field label="last observed">{data(@repositorio.last_observed_at)}</.field>
            </dl>
            <p :if={@repositorio.description} class="text-sm opacity-80 mt-2">
              {@repositorio.description}
            </p>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="font-semibold">By concept</h3>
            <%!-- A soma é a verificação: quando não fecha, a promoção de alguma issue
                  não foi registrada e o número mostrado é menor que a realidade. --%>
            <div :if={@desvio != 0} class="alert alert-error block text-sm">
              The counts do not add up: {@coletadas} collected against {@total_promovido} + {@total_lacuna}. {@desvio} unaccounted for.
            </div>
            <table class="table table-sm">
              <tbody>
                <tr :for={{conceito, rotulo} <- ConceptLabel.conceitos()} :if={@promovidas[conceito]}>
                  <td>{rotulo}</td>
                  <td class="text-right font-mono">{@promovidas[conceito]}</td>
                </tr>
                <tr :for={{motivo, n} <- @lacunas}>
                  <td class="opacity-70">undefined — {ConceptLabel.motivo(motivo)}</td>
                  <td class="text-right font-mono opacity-70">{n}</td>
                </tr>
                <tr class="font-semibold border-t">
                  <td>total</td>
                  <td class="text-right font-mono">{@total_promovido + @total_lacuna}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div
        :if={@violacoes.task_parent_is_epic != [] or @violacoes.task_without_parent != []}
        class="mt-6 grid gap-6 md:grid-cols-2"
      >
        <div :if={@violacoes.task_parent_is_epic != []} class="card bg-base-200">
          <div class="card-body">
            <h3 class="font-semibold">
              Tasks whose parent is an epic
              <span class="opacity-60">{length(@violacoes.task_parent_is_epic)}</span>
            </h3>
            <p class="text-xs opacity-70">
              <span class="font-mono">sro.rule07</span>
              — a task attends an atomic user story. All of them are still promoted: the link is
              what is invalid, not the issue.
            </p>
            <.lista_curta issues={@violacoes.task_parent_is_epic} />
          </div>
        </div>

        <div :if={@violacoes.task_without_parent != []} class="card bg-base-200">
          <div class="card-body">
            <h3 class="font-semibold">
              Tasks with no user story
              <span class="opacity-60">{length(@violacoes.task_without_parent)}</span>
            </h3>
            <p class="text-xs opacity-70">
              The same axiom, violated a different way: there is no user story for these tasks
              to attend. It is not a case of the one above, and it asks for a different action.
            </p>
            <.lista_curta issues={@violacoes.task_without_parent} />
          </div>
        </div>
      </div>

      <div :if={@coletadas == 0} class="alert mt-6 block">
        <div class="font-semibold">{vazio_titulo(@repositorio)}</div>
        <p class="text-sm opacity-80">{vazio_texto(@repositorio)}</p>
      </div>

      <div :if={@coletadas > 0} class="mt-6">
        <div class="flex items-center justify-between mb-2">
          <h3 class="font-semibold">Issues</h3>
          <span class="text-sm opacity-70">{faixa(@pagina, @coletadas)} of {@coletadas}</span>
        </div>
        <div class="overflow-x-auto">
          <table class="table table-sm stacked">
            <thead>
              <tr>
                <th class="text-right">#</th>
                <th>title</th>
                <th>type at source</th>
                <th>state</th>
                <th class="text-right">parts at source</th>
                <th>promoted to</th>
                <th>part of</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={i <- @issues}>
                <td data-label="#" class="text-right font-mono">{i.number}</td>
                <td data-label="title" class="max-w-md">
                  <.link navigate={~p"/work/issues/#{i.id}"} class="link link-hover">
                    {i.title}
                  </.link>
                  <div :if={i.no_longer_observed_at} class="text-xs opacity-60">
                    did not show up in the last collection
                  </div>
                </td>
                <td data-label="type at source">
                  <span :if={i.issue_type} class="badge badge-xs badge-ghost">{i.issue_type}</span>
                  <span :if={is_nil(i.issue_type)} class="text-xs opacity-60">none</span>
                </td>
                <td data-label="state" class="text-xs opacity-70">{String.downcase(i.state)}</td>
                <td data-label="parts at source" class="text-right font-mono text-xs">
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
                <td data-label="part of" class="max-w-xs">
                  <.parte_de vinculos={vinculos(i, @pais, @repositorio, @nomes)} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <nav class="mt-3 flex items-center gap-2" aria-label="Pagination">
          <button
            class="btn btn-sm btn-outline"
            disabled={@pagina == 1}
            phx-click="pagina"
            phx-value-n={@pagina - 1}
          >
            Previous
          </button>
          <span class="text-sm opacity-70">
            page {@pagina} of {ultima_pagina(@coletadas)}
          </span>
          <button
            class="btn btn-sm btn-outline"
            disabled={@pagina >= ultima_pagina(@coletadas)}
            phx-click="pagina"
            phx-value-n={@pagina + 1}
          >
            Next
          </button>
        </nav>
      </div>
    </Layouts.app>
    """
  end

  # A célula da coluna `part of`. **Ausência é nomeada**: 2 899 das 4 529 issues não são parte de
  # nada, e uma célula vazia não distingue isso de "a plataforma não sabe" — ela sabe.
  #
  # Quando há mais de um pai **vigente**, a tela diz que há mais de um em vez de escolher. São 36
  # issues, e é onde uma escolha silenciosa passa despercebida — `fetch_parent/2` faz exatamente
  # essa escolha hoje, com `limit: 1` sem ordem.
  attr :vinculos, :list, required: true

  defp parte_de(assigns) do
    ~H"""
    <span :if={@vinculos == []} class="text-xs opacity-60">not part of anything</span>
    <div :if={@vinculos != []} class="space-y-1">
      <div :if={mais_de_um?(@vinculos)} class="text-xs text-warning">
        {length(vigentes(@vinculos))} parents at the source — the platform does not choose between
        them
      </div>
      <div :for={v <- @vinculos} class="text-sm">
        <.link navigate={~p"/work/issues/#{v.id}"} class="link link-hover">
          <span class="font-mono text-xs">#{v.number}</span> {v.title}
        </.link>
        <div :if={v.repositorio} class="text-xs opacity-60">in {v.repositorio}</div>
        <span class="inline-flex items-center gap-1.5 text-xs">
          <span
            class={[
              "size-2.5 shrink-0 rounded-[1px]",
              is_nil(v.ausente_em) && "bg-current text-success",
              v.ausente_em && "border border-dashed border-current text-base-content/50"
            ]}
            aria-hidden="true"
          ></span>
          <span :if={v.conceito} class="badge badge-xs badge-ghost">{v.conceito}</span>
          <span class={v.ausente_em && "text-base-content/60"}>{v.relacao}</span>
          <span class="sr-only">{rotulo_do_vinculo(v)}</span>
        </span>
        <div :if={v.ausente_em} class="text-xs opacity-60">
          this link is no longer observed since {Calendar.strftime(v.ausente_em, "%d %b %Y")}
        </div>
      </div>
    </div>
    """
  end

  defp rotulo_do_vinculo(%{ausente_em: nil}),
    do: "observed: the source declares this issue is part of that one"

  defp rotulo_do_vinculo(_vinculo),
    do: "absent: this link existed and is not present now"

  # O que a célula precisa, montado fora do template: o conceito do pai (FR-003), a relação
  # decidida pelo axioma (FR-004), e o repositório **só quando difere** — repetir o nome nas outras
  # 1 609 linhas gastaria a atenção que os 57 vínculos de fora precisam ter.
  #
  # `Map.get/3` com `[]`, e não `pais[i.id]`: `list_parents/2` não cria chave para issue sem pai, e
  # o acesso direto levantaria `KeyError` em 2 899 linhas.
  defp vinculos(issue, pais, repositorio, nomes) do
    pais
    |> Map.get(issue.id, [])
    |> Enum.map(fn pai ->
      %{
        id: pai.id,
        number: pai.number,
        title: pai.title,
        conceito: ConceptLabel.rotulo(pai.derived_concept),
        relacao:
          ConceptLabel.relacao(WorkItems.relation(issue.derived_concept, pai.derived_concept)),
        ausente_em: pai.no_longer_observed_at,
        repositorio: outro_repositorio(pai, repositorio, nomes)
      }
    end)
  end

  defp outro_repositorio(
         %{observed_repository_id: mesmo},
         %{observed_repository_id: mesmo},
         _nomes
       ),
       do: nil

  defp outro_repositorio(pai, _repositorio, nomes),
    do: Map.get(nomes, pai.observed_repository_id)

  # **Só o vigente conta.** Um pai vigente mais um vínculo que acabou é **um** pai, não dois — e
  # dizer "2 parents" nesse caso afirmaria uma decomposição que a origem não declara mais.
  defp vigentes(vinculos), do: Enum.reject(vinculos, & &1.ausente_em)

  defp mais_de_um?(vinculos), do: length(vigentes(vinculos)) > 1

  attr :issues, :list, required: true

  defp lista_curta(assigns) do
    ~H"""
    <ul class="text-sm mt-1 space-y-1">
      <li :for={i <- @issues}>
        <.link navigate={~p"/work/issues/#{i.id}"} class="link link-hover">
          <span class="font-mono">#{i.number}</span> {i.title}
        </.link>
      </li>
    </ul>
    """
  end

  defp carregar(socket) do
    tenant = socket.assigns.current_tenant
    opts = [observed_repository_id: socket.assigns.repositorio.observed_repository_id]

    coletadas = WorkItems.count_collected(tenant, opts)
    promovidas = WorkItems.count_by_promotion(tenant, opts)
    lacunas = WorkItems.count_gaps_by_reason(tenant, opts)
    total_promovido = soma(promovidas)
    total_lacuna = soma(lacunas)

    issues =
      WorkItems.list_issues(
        tenant,
        opts
        |> Keyword.put(:limit, @por_pagina)
        |> Keyword.put(:offset, (socket.assigns.pagina - 1) * @por_pagina)
      )

    socket
    |> assign(
      coletadas: coletadas,
      promovidas: promovidas,
      lacunas: lacunas,
      total_promovido: total_promovido,
      total_lacuna: total_lacuna,
      desvio: coletadas - total_promovido - total_lacuna,
      # A mesma função que o detalhe da issue usa, aqui em lote.
      violacoes: WorkItems.rule07_violations(tenant, opts),
      issues: issues,
      # **Uma** consulta para a página inteira, e não uma por linha: são 50 issues por página, e o
      # repositório maior desta organização tem 2 514. A entrada são as issues já listadas.
      pais: WorkItems.list_parents(tenant, Enum.map(issues, & &1.id)),
      # A segunda consulta, e a segunda **fronteira**: o nome do repositório do pai é de CMPO, e
      # `WorkItems` juntar a tabela dele quebraria a ADR 0003. Uma consulta virando mapa, como
      # `nomes_de_repositorio/1` na página da pessoa. Incondicional de propósito: condicioná-la a
      # "existe pai fora daqui" faria o número de consultas variar com o dado.
      nomes: nomes_de_repositorio(tenant),
      organizacao: organizacao(tenant, socket.assigns.repositorio)
    )
  end

  defp nomes_de_repositorio(tenant) do
    Map.new(
      CMPO.list_observed(tenant),
      &{&1.observed_repository_id, &1.qualified_name || &1.name}
    )
  end

  defp organizacao(tenant, repositorio) do
    tenant
    |> EO.list_organizations()
    |> Enum.find(&(&1.id == repositorio.organization_id))
    |> case do
      nil -> "—"
      org -> org.login || org.name
    end
  end

  defp soma(mapa), do: mapa |> Map.values() |> Enum.sum()

  defp faixa(pagina, total) do
    inicio = (pagina - 1) * @por_pagina + 1
    "#{inicio}–#{min(pagina * @por_pagina, total)}"
  end

  defp ultima_pagina(0), do: 1
  defp ultima_pagina(total), do: ceil(total / @por_pagina)

  # Três vazios diferentes, e a diferença importa: um diz que a coleta ocorreu e não achou
  # nada; os outros dois dizem que a plataforma não olhou.
  defp vazio_titulo(%{excluded_at: at}) when not is_nil(at),
    do: "No issue collected, and this repository is out of observation."

  defp vazio_titulo(%{inaccessible_since: at}) when not is_nil(at),
    do: "No issue collected, and the repository is unreachable."

  defp vazio_titulo(_), do: "This repository has no issues."

  defp vazio_texto(%{excluded_at: at}) when not is_nil(at),
    do:
      "The platform stopped looking. Including it back makes the next collection bring the issues."

  defp vazio_texto(%{inaccessible_since: _}),
    do:
      "A coleta perdeu alcance antes de listar issues. Ausência de acesso não é ausência de dado."

  defp vazio_texto(_),
    do: "The collection ran and the result is empty — different from not having collected."

  defp situacao(%{excluded_at: at}) when not is_nil(at), do: "excluded from observation"

  defp situacao(%{inaccessible_since: at}) when not is_nil(at), do: "unreachable"

  defp situacao(%{archived_at: at}) when not is_nil(at), do: "archived at the source"
  defp situacao(_), do: "observed"

  defp data(nil), do: nil
  defp data(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
end
