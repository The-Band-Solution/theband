defmodule TheBandWeb.ProfileRunLive.Index do
  @moduledoc """
  `/profiles` — a geração automática dos perfis: se está ligada, e o que cada rodada fez.

  Só perfil `admin`.

  ## Tela própria, e não uma aba de outra

  Três perguntas diferentes, três telas — princípio X. `/ai` responde *com que conta
  trabalhamos*; `/syncs` responde *o que foi coletado*; esta responde *a geração automática
  está funcionando*.

  Juntar automação e credencial pareceria econômico e produziria o efeito errado: ligar a
  automação e configurar a chave viram o mesmo gesto, quando um é decisão sobre pessoas e o
  outro é decisão sobre dinheiro.

  ## Uma rodada que não executou não é uma rodada sem gente

  *"Nunca ligou"*, *"executou e não gerou ninguém"* e *"encerrou no meio"* são três fatos
  diferentes, e a tela os diz com frases diferentes. Achatá-los faria a organização acreditar
  que não há quem gerar quando, na verdade, ninguém ligou.
  """

  use TheBandWeb, :live_view

  alias TheBand.Profiles.{Automation, Run, Runs}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Runs.subscribe(socket.assigns.current_tenant)

    {:ok,
     socket
     |> assign(page_title: "Profile generation")
     |> assign(report: nil, report_run_id: nil)
     |> carregar()}
  end

  # Cada checkpoint da rodada chega aqui, e a tela recarrega do banco — o progresso anda
  # sozinho, sem ninguém apertar reload. Só o id trafega; duas fontes do mesmo fato
  # divergiriam.
  @impl true
  def handle_info({:rodada, _run_id}, socket), do: {:noreply, carregar(socket)}

  # O report "por que não gerou para todos?" — calculado NO CLIQUE, nunca no mount:
  # são até 50 checagens leves, e a resposta é do estado de agora.
  @impl true
  def handle_event("abrir_report", %{"run_id" => run_id}, socket) do
    tenant = socket.assigns.current_tenant

    with {:ok, run} <- Runs.get(tenant, run_id) do
      {:noreply,
       assign(socket,
         report: Runs.skipped_with_reasons(tenant, run),
         report_run_id: run_id
       )}
    end
  end

  def handle_event("fechar_report", _params, socket),
    do: {:noreply, assign(socket, report: nil, report_run_id: nil)}

  def handle_event("enable", _params, socket) do
    case Automation.enable(socket.assigns.current_tenant, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Automatic generation is on. A first run started right away.")
         |> carregar()}

      {:error, :no_credential} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This organisation has no provider key of its own. A run would have to spend the " <>
             "installation's key, and that would put one organisation's usage on another's " <>
             "bill. Save a key first."
         )}

      {:error, :already_enabled} ->
        {:noreply, socket |> put_flash(:error, "It is already on.") |> carregar()}

      {:error, motivo} ->
        {:noreply, put_flash(socket, :error, "Could not turn it on: #{inspect(motivo)}")}
    end
  end

  def handle_event("disable", _params, socket) do
    case Automation.disable(socket.assigns.current_tenant, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Automatic generation is off from the next run on. A run in progress is not " <>
             "interrupted — half the people generated is a state no screen can name."
         )
         |> carregar()}

      {:error, :not_enabled} ->
        {:noreply, socket |> put_flash(:error, "It is already off.") |> carregar()}
    end
  end

  def handle_event("run_now", _params, socket) do
    tenant = socket.assigns.current_tenant

    case Runs.start(tenant, trigger: :manual, requested_by: socket.assigns.current_user) do
      {:ok, _run} ->
        {:noreply, socket |> put_flash(:info, "Run started.") |> carregar()}

      {:error, :already_running} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "A run is already in progress. Two at once would write two profiles from the same " <>
             "material, and the table keeps both."
         )}

      {:error, :no_credential} ->
        {:noreply, put_flash(socket, :error, "This organisation has no provider key of its own.")}

      {:error, motivo} ->
        {:noreply, put_flash(socket, :error, "Could not start the run: #{inspect(motivo)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Profile generation
        <:subtitle>
          Whether this organisation writes competence profiles on its own, and what each run did.
        </:subtitle>
        <:actions>
          <.button :if={@estado == :never_enabled} phx-click="enable">Turn on</.button>
          <.button :if={match?({:disabled, _}, @estado)} phx-click="enable">Turn on</.button>
          <button
            :if={match?({:enabled, _}, @estado)}
            class="btn btn-outline btn-sm"
            phx-click="disable"
            data-confirm="Turn automatic generation off? It stops from the next run on; a run in progress finishes."
          >
            Turn off
          </button>
        </:actions>
      </.header>

      <div class="card bg-base-200 p-6 space-y-3">
        <div class="text-sm font-semibold">State</div>

        <div :if={match?({:enabled, _}, @estado)} class="space-y-1">
          <span class="badge badge-success">on</span>
          <p class="text-sm opacity-80">
            Turned on by {autor(@estado)} on {quando(@estado)}. The round runs on the 1st of each
            month at 03:00, and writes a new profile only for people whose work moved.
          </p>
        </div>

        <div :if={match?({:disabled, _}, @estado)} class="space-y-1">
          <span class="badge">off</span>
          <p class="text-sm opacity-80">
            Turned off by {autor(@estado)} on {quando(@estado)}. Nothing runs, and no profile is
            written on its own.
          </p>
        </div>

        <%!-- "Nunca ligou" é diferente de "desligada": a segunda tem autor, e a primeira é a
              ausência de qualquer ato. A `FR-018a` existe para que subir a versão não escreva
              sobre ninguém, e a tela precisa mostrar que foi isso que aconteceu. --%>
        <div :if={@estado == :never_enabled}>
          <.absent reason="Never turned on — no profile is written on its own in this organisation." />
        </div>

        <%!-- A rodada a mão gera para TODO MUNDO com material — emenda de 2026-08-16 à
              FR-004. O custo aparece antes do clique, porque uma rodada completa foi medida
              em milhões de tokens de entrada: quem clica decide gastando, não descobrindo. --%>
        <button
          :if={match?({:enabled, _}, @estado)}
          class="btn btn-xs btn-outline w-fit"
          phx-click="run_now"
          data-confirm="A run asked for by hand writes a new profile for EVERY person with material — the change rule only applies to the monthly run. This spends provider tokens for the whole organisation. Start it?"
        >
          run now — everyone
        </button>
      </div>

      <div class="card bg-base-200 p-6">
        <div class="text-sm font-semibold mb-3">Runs</div>

        <div :if={@rodadas == []}>
          <.absent reason="No run yet — which is not the same as a run that generated nobody." />
        </div>

        <%!-- A barra só existe para a rodada aberta. O numerador é a contagem de entradas —
              derivada, como os nove números —, e o denominador é o plano gravado na seleção.
              Plano ainda nulo é "não sabemos o total": a barra fica indeterminada, nunca em
              zero, porque zero diria "nada a fazer" onde a verdade é "selecionando". --%>
        <div :for={run <- @rodadas} :if={run.finished_at == nil} class="mb-4 space-y-1">
          <div class="flex items-center justify-between text-sm">
            <span class="font-medium">Run in progress</span>
            <span :if={run.people_selected} class="font-mono text-xs">
              {@resumos[run.id].considered} of {run.people_selected} people
            </span>
            <span :if={is_nil(run.people_selected)} class="text-xs opacity-70">
              selecting who enters…
            </span>
          </div>
          <progress
            :if={run.people_selected}
            class="progress progress-primary w-full"
            value={@resumos[run.id].considered}
            max={run.people_selected}
          ></progress>
          <progress :if={is_nil(run.people_selected)} class="progress w-full"></progress>
          <p class="text-xs opacity-60">
            Each step is a person: generated, skipped or failed — the table below counts them
            apart. A generation takes 25 to 60 seconds per person.
          </p>
        </div>

        <table :if={@rodadas != []} class="table table-sm stacked">
          <thead>
            <tr>
              <th>started</th>
              <th>state</th>
              <th>origin</th>
              <th>considered</th>
              <th>generated</th>
              <th>skipped</th>
              <th>failed</th>
              <th>input tokens</th>
            </tr>
          </thead>
          <tbody>
            <%= for run <- @rodadas do %>
              <tr>
                <td data-label="started" class="font-mono text-xs">{run.started_at}</td>
                <td data-label="state">
                  <span class={[
                    "badge badge-sm",
                    run.outcome == "completed" && "badge-success",
                    run.outcome == "ended_early" && "badge-error"
                  ]}>
                    {estado_da_rodada(run)}
                  </span>
                  <div :if={run.ended_reason} class="text-xs opacity-70">{run.ended_reason}</div>
                </td>
                <%!-- A origem aparece **aqui**, e nunca na aba da pessoa: um perfil gerado pela
                    rodada é igual a um pedido a mão, e quem lê não deve ter razão para
                    confiar mais num do que no outro — `FR-015`. --%>
                <td data-label="origin" class="text-xs">{origem(run)}</td>
                <td data-label="considered" class="font-mono">{@resumos[run.id].considered}</td>
                <td data-label="generated" class="font-mono">{@resumos[run.id].generated}</td>
                <td data-label="skipped" class="text-xs">
                  <div>no material: {@resumos[run.id].skipped.no_material}</div>
                  <div>no new work: {@resumos[run.id].skipped.no_new_work}</div>
                  <div>observation ended: {@resumos[run.id].skipped.observation_ended}</div>
                </td>
                <td data-label="failed" class="font-mono">{@resumos[run.id].failed}</td>
                <td data-label="input tokens" class="font-mono">
                  {milhar(@resumos[run.id].input_tokens)}
                </td>
                <td data-label="">
                  <button
                    :if={@resumos[run.id].considered > @resumos[run.id].generated}
                    class="btn btn-ghost btn-xs"
                    phx-click={if @report_run_id == run.id, do: "fechar_report", else: "abrir_report"}
                    phx-value-run_id={run.id}
                  >
                    {if @report_run_id == run.id, do: "hide", else: "why not everyone?"}
                  </button>
                </td>
              </tr>
              <tr :if={@report_run_id == run.id and @report != nil}>
                <td colspan="9" class="painel bg-base-300/30 p-4">
                  <p class="mb-2 text-xs opacity-70">
                    Person by person, with the reason <strong>as of now</strong> — recomputed on
                    read, like everything observed. Someone whose material changed since the run
                    shows as "would generate today".
                  </p>
                  <div class="grid gap-1 sm:grid-cols-2">
                    <div :for={p <- @report} class="flex items-baseline gap-2 text-sm">
                      <span class={[
                        "badge badge-xs shrink-0",
                        p.motivo == :geraria_hoje && "badge-success",
                        p.motivo == :no_assignment && "badge-warning",
                        p.motivo not in [:geraria_hoje, :no_assignment] && "badge-ghost"
                      ]}>
                        {p.motivo}
                      </span>
                      <.link navigate={~p"/people/#{p.person_id}"} class="link link-hover font-medium">
                        {p.name}
                      </.link>
                      <span class="text-xs opacity-60">{p.detalhe}</span>
                    </div>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <p class="text-xs opacity-60 mt-3">
          The three skip reasons are counted apart on purpose: <strong>no material</strong>
          means the record does not sustain a profile, <strong>no new work</strong>
          means the existing text still says what there is to say, and
          <strong>observation ended</strong>
          means the platform no longer watches that person. A single total would hide which one
          needs action.
        </p>
        <p class="text-xs opacity-60 mt-2">
          <strong>Failures are not a skip reason.</strong>
          Skipping is the platform deciding not to write; failing is it having tried and not
          managed to.
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp carregar(socket) do
    tenant = socket.assigns.current_tenant
    rodadas = Runs.list(tenant)

    socket
    |> assign(estado: Automation.state(tenant))
    |> assign(rodadas: rodadas)
    |> assign(resumos: Map.new(rodadas, &{&1.id, Runs.summary(&1)}))
  end

  defp autor({_, %{by: nil}}), do: "somebody no longer registered"
  defp autor({_, %{by: user}}), do: user.email

  defp quando({_, %{at: at}}), do: DateTime.truncate(at, :second)

  # 651338 lê como telefone; 651,338 lê como contagem. O separador segue a tela, em inglês.
  defp milhar(n) when is_integer(n) do
    n
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp milhar(outro), do: outro

  defp estado_da_rodada(%Run{finished_at: nil}), do: "running"
  defp estado_da_rodada(%Run{outcome: "completed"}), do: "completed"
  defp estado_da_rodada(%Run{outcome: "ended_early"}), do: "ended early"
  defp estado_da_rodada(%Run{}), do: "finished"

  defp origem(%Run{trigger: "cron"}), do: "monthly"
  defp origem(%Run{trigger: "manual"}), do: "asked for"
end
