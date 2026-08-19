defmodule TheBandWeb.VerificationLive.Index do
  @moduledoc """
  `/work/verifications` — as execuções de verificação contínua (feature 037).

  ## O painel mostra CINCO fases, e nenhuma soma com outra

  Bem-sucedido, malsucedido, interrompido, não executado e expirado. As três últimas não
  são falha: cancelar é decisão humana, e somá-las à quebra inflaria a medida com o que
  ninguém quebrou. Medido em 2026-08-18 no primeiro repositório: 55 falhas e 54
  cancelamentos — juntá-las dobraria a taxa.

  ## "A rede não nomeia" é um filtro, não uma sobra

  399 das 1.051 execuções coletadas não são nem verificação nem implantação: são
  espelhamento (`Sync to GitLab`) e automação de quadro (`Sprint Rollover`). A tela as
  lista com esse nome e permite filtrá-las, porque escondê-las faria as outras parecerem
  o todo.
  """
  use TheBandWeb, :live_view

  alias TheBand.Verification

  @por_pagina 50

  @fases [
    {"ciro.successful_continuous_integration_process", "successful", "badge-success"},
    {"ciro.unsuccessful_continuous_integration_process", "unsuccessful", "badge-error"},
    {"ciro.interrupted_continuous_integration_process", "interrupted", "badge-warning"},
    {"ciro.unperformed_continuous_integration_process", "not performed", "badge-ghost"},
    {"ciro.expired_continuous_integration_process", "expired", "badge-warning"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Continuous verification")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(
       fase: params["phase"],
       tipo: params["kind"],
       org: params["organization_id"],
       pagina: pagina_de(params)
     )
     |> load()}
  end

  defp pagina_de(params) do
    case Integer.parse(params["page"] || "1") do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant

    filtro = [
      phase: socket.assigns.fase,
      kind: socket.assigns.tipo,
      organization_id: socket.assigns.org
    ]

    opts =
      filtro ++ [limit: @por_pagina, offset: (socket.assigns.pagina - 1) * @por_pagina]

    socket
    |> assign(por_pagina: @por_pagina)
    |> assign(execucoes: Verification.list(tenant, opts))
    |> assign(encontradas: Verification.count(tenant, filtro))
    |> assign(
      por_fase:
        Verification.by_phase(tenant,
          kind: socket.assigns.tipo,
          organization_id: socket.assigns.org
        )
    )
    |> assign(repositorios: Verification.repositories(tenant))
    |> assign(cobertura: Verification.cobertura(tenant))
    |> assign(organizacoes: Verification.by_organization(tenant))
    |> assign(top_repositorios: Verification.by_repository(tenant, limit: 12))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Continuous verification
        <:subtitle>
          What the automated checks did with each change — {@encontradas} runs
        </:subtitle>
      </.header>

      <%!-- As cinco fases lado a lado, e a que está em andamento por último. Cada uma é um
            filtro: o número sem o caminho para a lista obriga a pessoa a acreditar nele. --%>
      <div class="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-6">
        <.link
          :for={{id, rotulo, cor} <- fases()}
          patch={~p"/work/verifications?#{filtro(@tipo, if(@fase == id, do: nil, else: id), @org)}"}
          class={[
            "rounded-lg border border-base-300 px-3 py-2 hover:border-primary",
            @fase == id && "border-primary bg-base-200"
          ]}
        >
          <span class="block font-mono text-xl tabular-nums">{Map.get(@por_fase, id, 0)}</span>
          <span class={["badge badge-xs", cor]}>{rotulo}</span>
        </.link>

        <%!-- Em andamento NÃO é fase: é a ausência dela. Fica no mesmo painel porque a
              pessoa precisa ver o que está rodando agora, e separada porque somá-la a
              qualquer fase seria dizer que já decidiu. --%>
        <.link
          patch={
            ~p"/work/verifications?#{filtro(@tipo, if(@fase == "running", do: nil, else: "running"), @org)}"
          }
          class={[
            "rounded-lg border border-dashed border-base-300 px-3 py-2 hover:border-primary",
            @fase == "running" && "border-primary bg-base-200"
          ]}
        >
          <span class="block font-mono text-xl tabular-nums">{Map.get(@por_fase, nil, 0)}</span>
          <span class="text-xs opacity-70 italic">running · no phase yet</span>
        </.link>
      </div>

      <%!-- O tipo é DERIVADO dos componentes dos jobs, e o rótulo diz isso. A terceira
            opção existe porque 399 execuções não são nem uma coisa nem outra, e omiti-las
            faria as outras parecerem o total. --%>
      <div class="flex flex-wrap items-center gap-2 text-xs">
        <span class="opacity-60">derived from the jobs:</span>
        <.link
          :for={{valor, rotulo} <- tipos()}
          patch={
            ~p"/work/verifications?#{filtro(if(@tipo == valor, do: nil, else: valor), @fase, @org)}"
          }
          class={["btn btn-xs", if(@tipo == valor, do: "btn-primary", else: "btn-ghost")]}
        >
          {rotulo}
        </.link>
      </div>

      <%!-- POR ORGANIZAÇÃO — um tenant observa mais de uma, e os volumes são muito
            diferentes: 11.444 execuções numa, 2.421 na segunda, 1.510 na terceira. Uma taxa de
            quebra agregada seria dominada pela maior e esconderia as outras duas.

            `no CI` conta repositório observado que nenhuma execução de integração contínua
            tocou. É ausência nomeada por organização, e não some no total — 78 dos 121
            repositórios da maior não têm CI, e isso é o achado, não o resto. --%>
      <section class="rounded-lg border border-base-300 p-3">
        <h2 class="mb-2 text-sm font-semibold">By organisation</h2>

        <div class="overflow-x-auto">
          <table class="table stacked table-sm">
            <thead>
              <tr>
                <th>organisation</th>
                <th>repositories</th>
                <th>runs</th>
                <th>successful</th>
                <th>failed</th>
                <th>repos with no CI</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={o <- @organizacoes} class={@org == o.id && "bg-base-200"}>
                <td data-label="organisation">
                  <%!-- Clicar filtra a lista abaixo. O mesmo link desliga o filtro: sem isso,
                        quem filtrou tem de apagar a barra de endereço para voltar. --%>
                  <.link
                    patch={
                      ~p"/work/verifications?#{filtro(@tipo, @fase, if(@org == o.id, do: nil, else: o.id))}"
                    }
                    class="link link-hover font-medium"
                  >
                    {o.login}
                  </.link>
                </td>
                <td data-label="repositories" class="font-mono text-xs tabular-nums">
                  {o.repositorios}
                </td>
                <td data-label="runs" class="font-mono text-xs tabular-nums">{o.execucoes}</td>
                <td data-label="successful" class="font-mono text-xs tabular-nums">
                  {o.bem_sucedidas}
                </td>
                <td data-label="failed" class="font-mono text-xs tabular-nums text-warning">
                  {o.malsucedidas}
                </td>
                <td data-label="repos with no CI" class="font-mono text-xs tabular-nums">
                  {o.repos_sem_ci}
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <p :if={@org} class="mt-2 text-xs">
          <.link patch={~p"/work/verifications?#{filtro(@tipo, @fase, nil)}"} class="link">
            Clear the organisation filter
          </.link>
        </p>
      </section>

      <%!-- OS REPOSITÓRIOS COM VOLUME. `de_ci` ao lado de `runs` porque a diferença é o que a
            feature 037 descobriu: parte grande das execuções não é integração contínua — é
            espelhamento e automação de quadro. Sem as duas colunas, "1.361 execuções" pareceria
            1.361 verificações. --%>
      <section class="rounded-lg border border-base-300 p-3">
        <h2 class="mb-1 text-sm font-semibold">Repositories with runs</h2>
        <p class="mb-2 text-xs opacity-70">
          The twelve with most runs. <strong>of which CI</strong>
          is the part that is continuous integration — the rest is mirroring, board automation
          and deployment.
        </p>

        <div class="overflow-x-auto">
          <table class="table stacked table-sm">
            <thead>
              <tr>
                <th>repository</th>
                <th>organisation</th>
                <th>runs</th>
                <th>of which CI</th>
                <th>failed</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={r <- @top_repositorios}>
                <td data-label="repository" class="min-w-0 font-medium break-all">
                  <.link
                    patch={
                      ~p"/work/verifications?#{filtro(@tipo, @fase, @org) ++ [{"repository_id", r.id}]}"
                    }
                    class="link link-hover"
                  >
                    {nome_curto(r.qualified_name)}
                  </.link>
                </td>
                <td data-label="organisation" class="text-xs opacity-70">{r.organizacao}</td>
                <td data-label="runs" class="font-mono text-xs tabular-nums">{r.execucoes}</td>
                <td data-label="of which CI" class="font-mono text-xs tabular-nums">{r.de_ci}</td>
                <td data-label="failed" class="font-mono text-xs tabular-nums text-warning">
                  {r.malsucedidas}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <%!-- A COBERTURA — issue #439. Existe porque "não verificável" não é uma frase: são
            cinco, e quatro delas nada tem a ver com o processo da organização.

            Foi a pergunta de quem mantém o projeto — "não entendi o conceito de verificação
            coletada" — que mostrou a lacuna. Sem esta seção, qualquer medida de qualidade
            calculada sobre "integradas" faria quem trabalha em repositório sem CI, ou quem
            trabalhava antes da janela de retenção, aparecer impecável.

            Os cinco motivos são mutuamente exclusivos e a soma fecha. A primeira versão usava
            um contador por motivo, eles se sobrepunham, e a lacuna NOSSA aparecia como 678
            quando são 51. --%>
      <section class="rounded-lg border border-base-300 p-3">
        <h2 class="mb-1 text-sm font-semibold">
          What can be checked at all
          <span class="badge badge-outline badge-warning badge-xs ml-1">derived</span>
        </h2>
        <p class="mb-2 text-xs opacity-70">
          A merged change request is <strong>verifiable</strong> when some commit of it is the
          head of a collected continuous-integration run. When it is not, the reason matters —
          and only one of these is ours.
        </p>

        <div class="grid grid-cols-2 gap-2 sm:grid-cols-5">
          <div
            :for={{rotulo, valor, cor, dica} <- quadros_de_cobertura(@cobertura)}
            class="min-w-0"
            title={dica}
          >
            <span class={["block font-mono text-lg tabular-nums", cor]}>{valor}</span>
            <span class="text-xs opacity-70">{rotulo}</span>
          </div>
        </div>

        <%!-- A frase da retenção é a que mais faltava: sem ela, alguém procura uma coleta que
              nunca poderia existir. --%>
        <p
          :if={@cobertura[:expirada_na_origem] && @cobertura[:expirada_na_origem] > 0}
          class="mt-2 text-xs opacity-70"
        >
          <strong>{@cobertura[:expirada_na_origem]}</strong> were merged before the oldest run
          the source still keeps. That is <strong>not</strong> a gap in collection — GitHub
          discarded those runs, and no sweep can bring them back.
        </p>
      </section>

      <p :if={@encontradas == 0} class="alert">
        No runs match this filter <strong>among what was collected</strong>. {colecao(@repositorios)}
      </p>

      <div :if={@execucoes != []} class="overflow-x-auto">
        <table class="table stacked table-sm">
          <thead>
            <tr>
              <th>run</th>
              <th>phase</th>
              <th>what it is</th>
              <th>trigger</th>
              <th>jobs</th>
              <th>started</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={v <- @execucoes}>
              <td data-label="run">
                <.link
                  navigate={~p"/work/verifications/#{v.id}"}
                  class="link link-hover font-medium"
                >
                  {v.workflow_name || "unnamed workflow"}
                </.link>
                <span class="block font-mono text-xs opacity-60">
                  {String.slice(v.head_sha || "", 0, 7)} · {v.repository}
                </span>
              </td>
              <td data-label="phase"><.fase valor={v.phase} status={v.run_status} /></td>
              <td data-label="what it is" class="text-xs"><.tipos_da valor={v.process_kinds} /></td>
              <td data-label="trigger" class="font-mono text-xs">{v.trigger_event || "—"}</td>
              <td data-label="jobs" class="font-mono text-xs tabular-nums">
                {v.jobs}<span
                  :if={v.jobs == 0}
                  class="ml-1 opacity-60 italic"
                  title="the run was collected; its jobs were not"
                >not collected</span>
              </td>
              <td data-label="started" class="text-xs">{v.started_at}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <.paginacao_simples
        pagina={@pagina}
        por_pagina={@por_pagina}
        total={@encontradas}
        tipo={@tipo}
        fase={@fase}
        org={@org}
      />
    </Layouts.app>
    """
  end

  attr :valor, :string, default: nil
  attr :status, :string, default: nil

  defp fase(assigns) do
    ~H"""
    <span :if={@valor} class={["badge badge-sm", cor_da_fase(@valor)]}>{rotulo_da_fase(@valor)}</span>
    <%!-- Sem fase e terminado é resultado que a regra não decidiu (`neutral`,
          `action_required`); sem fase e rodando é processo que não decidiu nada. As duas
          frases são diferentes porque as situações são. --%>
    <span :if={is_nil(@valor)} class="text-xs opacity-60 italic">
      {if @status == "completed", do: "finished, phase undecided", else: "running"}
    </span>
    """
  end

  attr :valor, :list, default: []

  defp tipos_da(assigns) do
    ~H"""
    <span :for={t <- @valor} class="badge badge-outline badge-xs mr-1">{rotulo_do_tipo(t)}</span>
    <%!-- Ausência NOMEADA: a rede não tem conceito para espelhamento nem automação de
          quadro. Não é falha de coleta, e a frase precisa deixar isso claro. --%>
    <span :if={@valor == []} class="opacity-60 italic">
      the network has no concept for this
    </span>
    """
  end

  attr :pagina, :integer, required: true
  attr :por_pagina, :integer, required: true
  attr :total, :integer, required: true
  attr :tipo, :string, default: nil
  attr :fase, :string, default: nil
  # **O `default: nil` é o que cria o assign**, e é ele que faltava: o template usava `@org` e
  # nem o atributo existia nem a chamada o passava. Conferido removendo os dois — o teste da
  # paginação com filtro reprova com o mesmo `KeyError` que apareceu no navegador.
  attr :org, :string, default: nil

  defp paginacao_simples(assigns) do
    ~H"""
    <div :if={@total > @por_pagina} class="flex items-center justify-between text-xs">
      <.link
        :if={@pagina > 1}
        patch={~p"/work/verifications?#{filtro(@tipo, @fase, @org) ++ [page: @pagina - 1]}"}
        class="btn btn-ghost btn-sm"
      >
        previous
      </.link>
      <span class="opacity-70">
        {(@pagina - 1) * @por_pagina + 1}–{min(@pagina * @por_pagina, @total)} of {@total}
      </span>
      <.link
        :if={@pagina * @por_pagina < @total}
        patch={~p"/work/verifications?#{filtro(@tipo, @fase, @org) ++ [page: @pagina + 1]}"}
        class="btn btn-ghost btn-sm"
      >
        next
      </.link>
    </div>
    """
  end

  defp filtro(tipo, fase, org) do
    [] |> com("kind", tipo) |> com("phase", fase) |> com("organization_id", org)
  end

  # O `owner/` sai do nome na tabela porque a coluna ao lado já diz a organização — repetir os
  # dois faria a coluna de repositório ficar larga sem acrescentar nada.
  defp nome_curto(qualified_name) do
    case String.split(qualified_name, "/", parts: 2) do
      [_owner, nome] -> nome
      _ -> qualified_name
    end
  end

  defp com(lista, _chave, nil), do: lista
  defp com(lista, chave, valor), do: lista ++ [{chave, valor}]

  # A ordem conta a história: o que dá para verificar, o que a origem não guarda mais, o que
  # não sabemos, o que a organização não verifica, e o que falta a nós. Só o último é acionável
  # por quem mantém a plataforma, e ele vem por último de propósito — pôr a lacuna nossa em
  # primeiro sugeriria que ela é a maior, e são 51 de 4.805.
  defp quadros_de_cobertura(cobertura) do
    [
      {"verifiable", cobertura[:verificavel] || 0, "",
       "some commit of the request is the head of a collected CI run"},
      {"source no longer keeps it", cobertura[:expirada_na_origem] || 0, "opacity-60",
       "merged before the oldest run GitHub still retains — no sweep can recover these"},
      {"no commit matched", cobertura[:nao_casou] || 0, "opacity-60",
       "the repository has CI and the request is within the window, and still no commit matched a run — we do not know why"},
      {"repository has no CI", cobertura[:sem_ci] || 0, "",
       "swept, and the repository runs no continuous integration at all — a fact about the organisation"},
      {"not swept yet", cobertura[:nao_percorrido] || 0, "text-warning",
       "our own gap: the repository was never swept for verification"}
    ]
  end

  defp fases, do: @fases

  defp tipos do
    [
      {"ciro.continuous_integration_process", "continuous integration"},
      {"cdro.continuous_deployment_process", "continuous deployment"},
      {"none", "neither — unnamed"}
    ]
  end

  defp rotulo_da_fase(id) do
    case Enum.find(@fases, fn {fase, _, _} -> fase == id end) do
      {_, rotulo, _} -> rotulo
      nil -> id
    end
  end

  defp cor_da_fase(id) do
    case Enum.find(@fases, fn {fase, _, _} -> fase == id end) do
      {_, _, cor} -> cor
      nil -> "badge-ghost"
    end
  end

  defp rotulo_do_tipo("ciro.continuous_integration_process"), do: "integration"
  defp rotulo_do_tipo("cdro.continuous_deployment_process"), do: "deployment"
  defp rotulo_do_tipo(outro), do: outro

  # A frase do vazio distingue "não coletamos" de "não existe" — a mesma regra da casa que
  # vale para toda tela: ausência de erro nunca vira ausência de fato.
  defp colecao(repositorios) do
    percorridos = Enum.count(repositorios, &(&1.collected_at != nil))

    case {percorridos, length(repositorios)} do
      {0, total} ->
        "No repository has been swept for verification yet — #{total} are observed."

      {percorridos, total} when percorridos < total ->
        "#{percorridos} of #{total} observed repositories have been swept; the rest were not collected."

      {_, total} ->
        "All #{total} observed repositories were swept — this is absence of runs, not absence of collection."
    end
  end
end
