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
     |> assign(fase: params["phase"], tipo: params["kind"], pagina: pagina_de(params))
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
    filtro = [phase: socket.assigns.fase, kind: socket.assigns.tipo]

    opts =
      filtro ++ [limit: @por_pagina, offset: (socket.assigns.pagina - 1) * @por_pagina]

    socket
    |> assign(por_pagina: @por_pagina)
    |> assign(execucoes: Verification.list(tenant, opts))
    |> assign(encontradas: Verification.count(tenant, filtro))
    |> assign(por_fase: Verification.by_phase(tenant, kind: socket.assigns.tipo))
    |> assign(repositorios: Verification.repositories(tenant))
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
          patch={~p"/work/verifications?#{filtro(@tipo, if(@fase == id, do: nil, else: id))}"}
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
            ~p"/work/verifications?#{filtro(@tipo, if(@fase == "running", do: nil, else: "running"))}"
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
          patch={~p"/work/verifications?#{filtro(if(@tipo == valor, do: nil, else: valor), @fase)}"}
          class={["btn btn-xs", if(@tipo == valor, do: "btn-primary", else: "btn-ghost")]}
        >
          {rotulo}
        </.link>
      </div>

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

  defp paginacao_simples(assigns) do
    ~H"""
    <div :if={@total > @por_pagina} class="flex items-center justify-between text-xs">
      <.link
        :if={@pagina > 1}
        patch={~p"/work/verifications?#{filtro(@tipo, @fase) ++ [page: @pagina - 1]}"}
        class="btn btn-ghost btn-sm"
      >
        previous
      </.link>
      <span class="opacity-70">
        {(@pagina - 1) * @por_pagina + 1}–{min(@pagina * @por_pagina, @total)} of {@total}
      </span>
      <.link
        :if={@pagina * @por_pagina < @total}
        patch={~p"/work/verifications?#{filtro(@tipo, @fase) ++ [page: @pagina + 1]}"}
        class="btn btn-ghost btn-sm"
      >
        next
      </.link>
    </div>
    """
  end

  defp filtro(tipo, fase) do
    [] |> com("kind", tipo) |> com("phase", fase)
  end

  defp com(lista, _chave, nil), do: lista
  defp com(lista, chave, valor), do: lista ++ [{chave, valor}]

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
