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

  import TheBandWeb.Components.DataTable

  alias TheBand.Configuration
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems
  alias TheBandWeb.ConceptLabel
  alias TheBandWeb.TabelaLive, as: Tabela

  @por_pagina 50

  # As colunas que esta tabela ordena. É desta lista que sai o átomo — nunca do parâmetro.
  # As tabelas desta tela: `{id, colunas ordenáveis, prefixo}`. A de vínculos recusados fica
  # de fora — são exceções, e a ordem delas é a do motivo, não a de uma coluna.
  @tabelas [{"issues", [:number, :title, :issue_type, :state, :conceito], nil}]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    # Repositório de outro tenant devolve "não encontrado", nunca "sem permissão".
    case CMPO.fetch_observed(tenant, id) do
      {:error, :not_found} ->
        {:ok,
         socket
         |> assign(repositorio: nil)
         |> put_flash(:error, "Repository not found.")
         |> push_navigate(to: ~p"/work")}

      {:ok, repositorio} ->
        {:ok,
         socket
         |> assign(page_title: repositorio.name, repositorio: repositorio)
         # `observed_repository_id`, e não `id`: a estrutura que a consulta devolve junta
         # repositório-fonte com observação, e não tem chave `id` — foi um `KeyError` na
         # tela, pego rodando o app e não pelos testes.
         |> assign(
           branches: Configuration.branches_of(tenant, repositorio.observed_repository_id)
         )
         |> assign(
           resumo_de_branches:
             Configuration.resumo_do_repositorio(tenant, repositorio.observed_repository_id)
         )}
    end
  end

  # O estado da tabela vem do endereço — recarregar devolve a mesma tela, e o link leva quem
  # recebe ao que quem mandou estava vendo (issue #292).
  @impl true
  def handle_params(_params, _uri, %{assigns: %{repositorio: nil}} = socket),
    do: {:noreply, socket}

  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Tabela.aplicar(params, @tabelas) |> carregar()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("ordenar", params, socket), do: Tabela.ordenar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  # T058 (#384): a decisão de excluir existia inteira no domínio desde a 004 — e nenhuma
  # tela a chamava. Zero de 160 repositórios excluídos por falta de caminho, não de
  # vontade. O autor vai gravado, e recolocar em observação é ato separado.
  def handle_event("excluir", _params, %{assigns: %{current_user: %{role: "admin"}}} = socket) do
    caso =
      CMPO.exclude_from_observation(
        socket.assigns.current_tenant,
        socket.assigns.repositorio.observed_repository_id,
        socket.assigns.current_user.id
      )

    case caso do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Excluded from observation. The next collection skips it; nothing is marked absent."
         )
         |> recarregar_repositorio()}

      {:error, motivo} ->
        {:noreply, put_flash(socket, :error, "Could not exclude: #{inspect(motivo)}")}
    end
  end

  def handle_event("incluir", _params, %{assigns: %{current_user: %{role: "admin"}}} = socket) do
    caso =
      CMPO.include_in_observation(
        socket.assigns.current_tenant,
        socket.assigns.repositorio.observed_repository_id
      )

    case caso do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Back under observation. The next collection brings it again.")
         |> recarregar_repositorio()}

      {:error, motivo} ->
        {:noreply, put_flash(socket, :error, "Could not include: #{inspect(motivo)}")}
    end
  end

  defp recarregar_repositorio(socket) do
    {:ok, repositorio} =
      CMPO.fetch_observed(
        socket.assigns.current_tenant,
        socket.assigns.repositorio.observed_repository_id
      )

    assign(socket, repositorio: repositorio)
  end

  defp caminho(socket, id, mudancas) do
    ~p"/work/repositories/#{socket.assigns.repositorio.id}?#{Tabela.query(socket, id, mudancas)}"
  end

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
          <%!-- T058: só admin decide, o efeito é dito ANTES do clique, e o autor fica
                gravado. Excluído não marca ausência — a plataforma parou de olhar, e isso
                não é o dado ter sumido (FR-005). --%>
          <button
            :if={@current_user.role == "admin" && is_nil(@repositorio.excluded_at)}
            class="btn btn-outline btn-sm btn-warning"
            phx-click="excluir"
            data-confirm="Exclude this repository from observation? The next collection skips it. Its issues stay readable and are NOT marked absent — the platform stops looking, which is different from the data being gone."
          >
            Exclude from observation
          </button>
          <button
            :if={@current_user.role == "admin" && @repositorio.excluded_at}
            class="btn btn-outline btn-sm"
            phx-click="incluir"
            data-confirm="Put this repository back under observation? The next collection brings it again."
          >
            Observe again
          </button>
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
        <h3 class="font-semibold mb-2">Issues</h3>

        <.data_table
          id="issues"
          rows={@issues}
          estado={@tabelas["issues"]}
          por_pagina={@por_pagina}
          total={@encontradas}
          onde="title and number"
          vazio="No issue matches this search."
        >
          <:col :let={i} field={:number} label="#" class="text-right font-mono">{i.number}</:col>
          <:col :let={i} field={:title} label="title" class="max-w-md">
            <.link navigate={~p"/work/issues/#{i.id}"} class="link link-hover">{i.title}</.link>
            <div :if={i.no_longer_observed_at} class="text-xs opacity-60">
              did not show up in the last collection
            </div>
          </:col>
          <:col :let={i} field={:issue_type} label="type at source">
            <span :if={i.issue_type} class="badge badge-xs badge-ghost">{i.issue_type}</span>
            <span :if={is_nil(i.issue_type)} class="text-xs opacity-60">none</span>
          </:col>
          <:col :let={i} field={:state} label="state" class="text-xs opacity-70">
            {String.downcase(i.state)}
          </:col>
          <:col :let={i} label="parts at source" class="text-right font-mono text-xs">
            {i.sub_issue_count}
          </:col>
          <:col :let={i} field={:conceito} label="promoted to">
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
          </:col>
          <:col :let={i} label="part of" class="max-w-xs">
            <.parte_de vinculos={vinculos(i, @pais, @repositorio, @nomes)} />
          </:col>
        </.data_table>
      </div>

      <%!-- AS LINHAS DE DESENVOLVIMENTO — `cmpo.branch`. O mapeamento existia desde a
            versão 1 e nunca havia sido coletado (issue #440).

            A tela responde o PRESENTE, e diz isso: branch mergeada é apagada na origem, e o
            histórico dela vive no `source_branch` das solicitações. Medido em 2026-08-19:
            2.468 nomes citados pelas solicitações contra 815 branches vivas — 85% dos nomes
            não têm entidade, porque a linha deixou de existir.

            E nenhum rótulo diz "abandonada": a plataforma sabe quando foi o último commit e
            não sabe se alguém pretende voltar. Diz os dias, e quem lê decide. --%>
      <section>
        <h2 class="mb-1 text-sm font-semibold">Development lines</h2>
        <p class="mb-3 text-xs opacity-70">
          The branches that <strong>exist now</strong>. A merged branch is deleted at the
          source — the lines a change request passed through live in its record, not here.
        </p>

        <p :if={is_nil(@repositorio.branches_collected_at)} class="alert">
          <strong>Branches were not collected for this repository yet.</strong>
          This is absence of collection, not absence of branches.
        </p>

        <div :if={@repositorio.branches_collected_at} class="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <div class="rounded-lg border border-base-300 px-3 py-2">
            <span class="block font-mono text-xl tabular-nums">{@resumo_de_branches.vivas}</span>
            <span class="text-xs opacity-70">open now</span>
          </div>
          <div class="rounded-lg border border-base-300 px-3 py-2">
            <span class="block font-mono text-xl tabular-nums">{@resumo_de_branches.protegidas}</span>
            <span class="text-xs opacity-70">protected</span>
          </div>
          <%!-- O corte vai DECLARADO no rótulo: corte escondido faz quem lê achar que é
                propriedade do dado, e não escolha de quem mediu. --%>
          <div class="rounded-lg border border-base-300 px-3 py-2">
            <span class="block font-mono text-xl tabular-nums text-warning">
              {@resumo_de_branches.paradas}
            </span>
            <span class="text-xs opacity-70">no commit in 90 days</span>
          </div>
          <div class="rounded-lg border border-base-300 px-3 py-2">
            <span class="block font-mono text-xl tabular-nums">
              {@repositorio.branches_total || "—"}
            </span>
            <span class="text-xs opacity-70">the source reports</span>
          </div>
        </div>

        <div :if={@branches != []} class="mt-3 overflow-x-auto">
          <table class="table stacked table-sm">
            <thead>
              <tr>
                <th>branch</th>
                <th>head</th>
                <th>last commit</th>
                <th>policy</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={b <- @branches}>
                <%!-- `break-all` porque nome de branch é uma palavra só e pode ter 70
                      caracteres: `features/apqi-task-backend-notificar-bolsistas-…` levou o
                      documento a 551px num viewport de 390, medido no navegador. --%>
                <td data-label="branch" class="min-w-0 font-medium break-all">
                  {b.name}
                  <span :if={b.is_default} class="badge badge-ghost badge-xs ml-1">default</span>
                </td>
                <td data-label="head" class="font-mono text-xs">
                  {String.slice(b.head_sha || "", 0, 7)}
                </td>
                <td data-label="last commit" class="text-xs">
                  <span :if={b.head_committed_at}>{b.head_committed_at}</span>
                  <%!-- Sem data é a origem que não soube datar, nunca zero dias. --%>
                  <span :if={is_nil(b.head_committed_at)} class="italic opacity-60">
                    the source gave no date
                  </span>
                  <span :if={b.dias_sem_commit && b.dias_sem_commit > 90} class="ml-1 text-warning">
                    {b.dias_sem_commit}d
                  </span>
                </td>
                <td data-label="policy" class="text-xs">
                  <span :if={b.is_protected} class="badge badge-outline badge-xs">protected</span>
                  <span :if={not b.is_protected} class="opacity-60">—</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
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

    # Mesma separação da lista de trabalho: os painéis respondem o que o repositório tem, e a
    # listagem responde quais destas eu procuro. Só a segunda filtra.
    estado = socket.assigns.tabelas["issues"]
    da_lista = Keyword.merge(opts, search: estado.busca, order_by: estado.ordem)

    coletadas = WorkItems.count_collected(tenant, opts)
    encontradas = WorkItems.count_collected(tenant, da_lista)
    promovidas = WorkItems.count_by_promotion(tenant, opts)
    lacunas = WorkItems.count_gaps_by_reason(tenant, opts)
    total_promovido = soma(promovidas)
    total_lacuna = soma(lacunas)

    issues =
      WorkItems.list_issues(
        tenant,
        da_lista
        |> Keyword.put(:limit, @por_pagina)
        |> Keyword.put(:offset, (estado.pagina - 1) * @por_pagina)
      )

    socket
    |> assign(
      coletadas: coletadas,
      promovidas: promovidas,
      lacunas: lacunas,
      total_promovido: total_promovido,
      total_lacuna: total_lacuna,
      desvio: coletadas - total_promovido - total_lacuna,
      encontradas: encontradas,
      # `@por_pagina` dentro do template é **assign**, não atributo de módulo — sem esta linha o
      # render levanta `KeyError`. A página da pessoa já carrega o mesmo comentário, e o teste
      # pegou de novo.
      por_pagina: @por_pagina,
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
      "The collection lost reach before listing issues. Absence of access is not absence of data."

  defp vazio_texto(_),
    do: "The collection ran and the result is empty — different from not having collected."

  defp situacao(%{excluded_at: at}) when not is_nil(at), do: "excluded from observation"

  defp situacao(%{inaccessible_since: at}) when not is_nil(at), do: "unreachable"

  defp situacao(%{archived_at: at}) when not is_nil(at), do: "archived at the source"
  defp situacao(_), do: "observed"

  defp data(nil), do: nil
  defp data(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
end
