defmodule TheBandWeb.WorkItemLive.Index do
  @moduledoc """
  `/trabalho` — as issues coletadas, o que elas são, e **o que não foi classificado**.

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

  @conceitos [
    {"sro.epic", "épico"},
    {"sro.atomic_user_story", "user story atômica"},
    {"sro.intended_scrum_development_task", "tarefa pretendida"},
    {"osdef.defect", "defeito"}
  ]

  @motivos %{
    "type_absent" => "sem tipo na origem",
    "type_unknown" => "tipo desconhecido",
    "sub_issues_unavailable" => "sub-issues indisponíveis"
  }

  @impl true
  @por_pagina 50

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Trabalho", repositorio: nil, pagina: 1)
     |> load()}
  end

  @impl true
  # Trocar o filtro volta para a primeira página. Manter a página 4 ao filtrar um
  # repositório de 12 issues mostraria uma lista vazia, e quem lê concluiria que não há
  # issues em vez de que está fora do fim.
  def handle_event("filtrar", %{"repositorio" => ""}, socket),
    do: {:noreply, socket |> assign(repositorio: nil, pagina: 1) |> load()}

  def handle_event("filtrar", %{"repositorio" => id}, socket),
    do: {:noreply, socket |> assign(repositorio: id, pagina: 1) |> load()}

  def handle_event("pagina", %{"n" => n}, socket) do
    {:noreply, socket |> assign(pagina: String.to_integer(n)) |> load()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Trabalho
        <:subtitle>
          {@coletadas} {if @coletadas == 1, do: "issue coletada", else: "issues coletadas"} · {@repos_observados} {if @repos_observados ==
                                                                                                                        1,
                                                                                                                      do:
                                                                                                                        "repositório observado",
                                                                                                                      else:
                                                                                                                        "repositórios observados"}
        </:subtitle>
      </.header>

      <%!-- Sem botão de coletar aqui: sincronizar traz tudo, e a sincronização tem
            tela própria. Dois lugares para disparar a mesma coleta produziriam duas
            leituras de "quando isto foi atualizado". --%>
      <div class="mt-4">
        <.link navigate={~p"/sincronizacoes"} class="btn btn-sm btn-outline">
          sincronizar
        </.link>
        <span class="text-sm opacity-70 ml-2">
          pessoas, equipes, repositórios e issues vêm na mesma coleta
        </span>
      </div>

      <div :if={@coletadas == 0} class="alert mt-6 block">
        <div class="font-semibold">{estado_vazio_titulo(@repos_observados)}</div>
        <p class="text-sm opacity-80 mt-1">{estado_vazio_texto(@repos_observados)}</p>
      </div>

      <div :if={@coletadas > 0} class="mt-6 space-y-6">
        <%!-- A diferença aparece em vermelho em vez de ser escondida: ela significa
              promoção não registrada, e é defeito de coleta, não de exibição. --%>
        <div :if={@desvio != 0} class="alert alert-error block">
          <div class="font-semibold">As contagens não somam.</div>
          <p class="text-sm">
            {@coletadas} coletadas, {@total_promovido} promovidas e {@total_lacuna} não
            promovidas — sobram {@desvio}. Alguma issue não tem promoção registrada, e
            os números abaixo são menores que a realidade.
          </p>
        </div>

        <div class="grid gap-6 md:grid-cols-3">
          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">
                Promovidas <span class="opacity-60">{@total_promovido}</span>
              </h3>
              <table class="table table-sm">
                <tbody>
                  <tr :for={{conceito, rotulo} <- @conceitos} :if={@promovidas[conceito]}>
                    <td>{rotulo}</td>
                    <td class="text-right font-mono">{@promovidas[conceito]}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">
                Não promovidas <span class="opacity-60">{@total_lacuna}</span>
              </h3>
              <p :if={@total_lacuna == 0} class="text-sm opacity-70">
                Todos os tipos usados por esta organização têm rota.
              </p>
              <table :if={@total_lacuna > 0} class="table table-sm">
                <tbody>
                  <tr :for={{motivo, n} <- @lacunas}>
                    <td>
                      {motivo_legivel(motivo)}
                      <%!-- Sem o nome do tipo, a lacuna não diz onde a regra
                            precisa mudar. --%>
                      <div :if={motivo == "type_unknown"} class="text-xs opacity-70">
                        {Enum.map_join(@tipos_desconhecidos, ", ", fn {t, c} -> "#{t} (#{c})" end)}
                      </div>
                    </td>
                    <td class="text-right font-mono">{n}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">
                Divergências <span class="opacity-60">{length(@divergencias)}</span>
              </h3>
              <p :if={@divergencias == []} class="text-sm opacity-70">
                Nenhuma. Em todas as issues, o tipo declarado e a estrutura concordam.
              </p>
              <p :if={@divergencias != []} class="text-xs opacity-70">
                Não é erro da plataforma: é sinal sobre o processo. A estrutura vence o
                rótulo, e é isto que aparece.
              </p>
              <ul :if={@divergencias != []} class="text-sm space-y-2 mt-1">
                <li :for={d <- Enum.take(@divergencias, 6)}>
                  <span class="font-mono">#{d.number}</span>
                  <span class="badge badge-xs badge-warning">{d.issue_type}</span>
                  → {rotulo(d.derived_concept)}
                  <div class="text-xs opacity-70">{d.divergence_reason}</div>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between mb-2">
            <h3 class="font-semibold">Repositórios</h3>
            <form phx-change="filtrar">
              <select name="repositorio" class="select select-sm select-bordered">
                <option value="">todos</option>
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

          <table class="table table-sm">
            <thead>
              <tr>
                <th>repositório</th>
                <th>linguagem</th>
                <th>ramo</th>
                <th class="text-right">issues</th>
                <th>situação</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={r <- @repositorios}>
                <td>
                  <a href={r.url} target="_blank" rel="noopener" class="link link-hover">
                    {r.name}
                  </a>
                </td>
                <td class="opacity-70">{r.primary_language || "—"}</td>
                <td class="opacity-70 font-mono text-xs">{r.default_branch || "—"}</td>
                <td class="text-right font-mono">
                  {@por_repositorio[r.observed_repository_id] || 0}
                </td>
                <td>{situacao(r)}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div>
          <div class="flex items-center justify-between mb-2">
            <h3 class="font-semibold">Issues</h3>
            <span class="text-sm opacity-70">
              {faixa(@pagina, @por_pagina, @coletadas)} de {@coletadas}
            </span>
          </div>
          <table class="table table-sm">
            <thead>
              <tr>
                <th>organização</th>
                <th>repositório</th>
                <th>#</th>
                <th>título</th>
                <th>tipo na origem</th>
                <th>partes</th>
                <th>promovida a</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={i <- @issues}>
                <td class="text-xs opacity-70">{origem(@onde, i).organizacao}</td>
                <td class="text-xs">{origem(@onde, i).repositorio}</td>
                <td class="font-mono">{i.number}</td>
                <td class="max-w-sm truncate">{i.title}</td>
                <td>
                  <span :if={i.issue_type} class="badge badge-xs badge-ghost">{i.issue_type}</span>
                  <span :if={is_nil(i.issue_type)} class="text-xs opacity-60">—</span>
                </td>
                <td class="font-mono text-xs">{i.sub_issue_count}</td>
                <td>
                  <span :if={i.derived_concept} class="text-sm">{rotulo(i.derived_concept)}</span>
                  <span :if={i.skip_reason} class="text-sm opacity-60">
                    {motivo_legivel(i.skip_reason)}{if i.skip_detail, do: ": #{i.skip_detail}"}
                  </span>
                  <div :if={i.divergence_reason} class="text-xs text-warning">
                    contra o rótulo {i.declared_concept && rotulo(i.declared_concept)}
                  </div>
                </td>
              </tr>
            </tbody>
          </table>

          <div class="flex items-center gap-2 mt-3">
            <button
              class="btn btn-sm btn-outline"
              disabled={@pagina == 1}
              phx-click="pagina"
              phx-value-n={@pagina - 1}
            >
              anterior
            </button>
            <span class="text-sm opacity-70">
              página {@pagina} de {ultima_pagina(@coletadas, @por_pagina)}
            </span>
            <button
              class="btn btn-sm btn-outline"
              disabled={@pagina >= ultima_pagina(@coletadas, @por_pagina)}
              phx-click="pagina"
              phx-value-n={@pagina + 1}
            >
              próxima
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    opts = filtro(socket.assigns.repositorio)

    coletadas = WorkItems.count_collected(tenant, opts)
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
      issues:
        WorkItems.list_issues(
          tenant,
          opts
          |> Keyword.put(:limit, @por_pagina)
          |> Keyword.put(:offset, (socket.assigns.pagina - 1) * @por_pagina)
        ),
      por_pagina: @por_pagina,
      onde: onde(tenant, repositorios),
      repositorios: repositorios,
      repos_observados: length(repositorios),
      por_repositorio: por_repositorio(tenant, repositorios),
      conceitos: @conceitos
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

  defp faixa(_pagina, _por_pagina, 0), do: "0"

  defp faixa(pagina, por_pagina, total) do
    inicio = (pagina - 1) * por_pagina + 1
    "#{inicio}–#{min(pagina * por_pagina, total)}"
  end

  defp ultima_pagina(0, _por_pagina), do: 1
  defp ultima_pagina(total, por_pagina), do: ceil(total / por_pagina)

  defp por_repositorio(tenant, repositorios) do
    Map.new(repositorios, fn r ->
      {r.observed_repository_id,
       WorkItems.count_collected(tenant, observed_repository_id: r.observed_repository_id)}
    end)
  end

  defp soma(mapa), do: mapa |> Map.values() |> Enum.sum()

  defp rotulo(conceito) do
    Enum.find_value(@conceitos, conceito, fn {id, rotulo} -> id == conceito && rotulo end)
  end

  defp motivo_legivel(motivo), do: Map.get(@motivos, motivo, motivo)

  # Três estados vazios diferentes. Um texto só para os três faria alguém concluir que o
  # time não trabalha — FR-036.
  defp estado_vazio_titulo(0), do: "Nenhuma coleta de issues ocorreu ainda."
  defp estado_vazio_titulo(_), do: "Nenhum repositório desta organização tem issues."

  defp estado_vazio_texto(0),
    do:
      "Conecte uma ferramenta e sincronize. Os repositórios são descobertos a partir " <>
        "da organização — não é preciso conectar cada um."

  defp estado_vazio_texto(n),
    do:
      "#{n} repositórios foram observados e nenhum tem issue. Isso é diferente de não " <>
        "ter coletado: a coleta ocorreu e o resultado é vazio."

  defp situacao(%{excluded_at: at}) when not is_nil(at),
    do: "excluído pelo tenant"

  defp situacao(%{inaccessible_since: at, inaccessible_reason: motivo}) when not is_nil(at),
    do: "inacessível — #{motivo}"

  defp situacao(%{archived_at: at}) when not is_nil(at), do: "arquivado na origem"
  defp situacao(_), do: "observado"
end
