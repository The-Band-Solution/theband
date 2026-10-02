defmodule TheBandWeb.SyncLive.Fila do
  @moduledoc """
  O estado da fila em `/syncs` — issue #801, parte 3. Protótipo aprovado em 2026-10-01, em
  `docs/producao/prototipo-fila-parada/`, com a avaliação de segurança ao lado.

  Componentes à parte do `SyncLive.Index`, que já é grande: a tela da coleta e o aviso da fila
  fazem coisas diferentes (princípio X).

  Lê só `TheBand.Saude.leitura/2`, que devolve um agregado escalar da instalação inteira, sem
  tenant, worker nem contagem (achado S3). Com a fila andando, a linha mostra **só** o veredito e
  a hora da conferência (decisão P-1, achado S2): o horário do último job pode ser de outra
  organização. As frases são de tela, em inglês.
  """
  use Phoenix.Component

  @doc "Se a fila está parada: o que desabilita Sync e Reprocess (decisão Q2)."
  @spec parada?(map()) :: boolean()
  def parada?(%{estado: :parada}), do: true
  def parada?(_), do: false

  @doc "A linha da fila andando, ou da instalação sem histórico, ou o aviso de fila parada."
  attr :fila, :map, required: true

  def estado(%{fila: %{estado: :parada}} = assigns), do: aviso(assigns)

  def estado(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-base-content/70">
      <span :if={@fila.estado == :andando} class="inline-flex items-center gap-1.5">
        <.marca forma={:solida} /> <span class="font-medium">observed</span> · Job queue moving
      </span>
      <span :if={@fila.estado == :sem_historico} class="inline-flex items-center gap-1.5">
        <.marca forma={:tracejada} /> <span class="font-medium">absent</span> · no job has run yet
      </span>
      <span>checked {hora(@fila.conferido_em)}</span>
    </div>
    """
  end

  defp aviso(assigns) do
    assigns = assign(assigns, :sem_historico?, assigns.fila.causa == :esperando_mais_antigo)

    ~H"""
    <section
      role="note"
      class="rounded border-2 border-warning bg-warning/10 p-3 sm:p-4 space-y-3"
    >
      <div class="flex items-center gap-2 font-mono text-[0.6875rem] uppercase tracking-wider text-warning">
        <.marca forma={:hachurada} />
        <span :if={!@sem_historico?}>Job queue stalled · derived from the last finished job</span>
        <span :if={@sem_historico?}>Job queue stalled · derived from the oldest waiting job</span>
      </div>

      <h2 :if={!@sem_historico?} class="text-base font-semibold">
        The job queue has not moved for {duracao(@fila.parada_ha_minutos)}
      </h2>
      <h2 :if={@sem_historico?} class="text-base font-semibold">
        No job has ever finished here, and work has waited {duracao(@fila.parada_ha_minutos)}
      </h2>

      <dl class="grid gap-1 text-sm sm:grid-cols-[12rem_1fr]">
        <dt class="opacity-70">last job finished</dt>
        <dd>
          <span :if={@fila.ultimo_completado_em} class="inline-flex items-center gap-1.5">
            {data_hora(@fila.ultimo_completado_em)} <.marca forma={:solida} /> observed
          </span>
          <span :if={is_nil(@fila.ultimo_completado_em)} class="inline-flex items-center gap-1.5">
            <.marca forma={:tracejada} /> none on this installation
          </span>
        </dd>

        <dt :if={@sem_historico?} class="opacity-70">oldest waiting job</dt>
        <dd :if={@sem_historico?} class="inline-flex items-center gap-1.5">
          queued at {data_hora(@fila.esperando_desde)} <.marca forma={:solida} /> observed
        </dd>

        <dt class="opacity-70">stalled since</dt>
        <dd>
          <span class="inline-flex items-center gap-1.5"><.marca forma={:hachurada} /> derived</span>
          <span :if={!@sem_historico?}>
            no job finished for 15 min or more. The scheduler queues work every 5 min, so a
            moving queue finishes something at least that often.
          </span>
          <span :if={@sem_historico?}>work has waited 15 min or more and nothing has ever run.</span>
        </dd>

        <dt class="opacity-70">checked</dt>
        <dd>{hora(@fila.conferido_em)}, updated every minute</dd>
      </dl>

      <div class="text-sm space-y-1">
        <h3 class="font-semibold">What this means here</h3>
        <p :if={!@sem_historico?}>
          Runs marked running below are not advancing. Their status still says running because
          the job that closes stuck runs waits in the same queue.
        </p>
        <p :if={!@sem_historico?}>
          Nothing collected so far is lost: each page is saved after it is processed.
        </p>
        <p :if={@sem_historico?}>
          Background work has not run on this installation since at least {hora(@fila.esperando_desde)}.
        </p>
        <p>
          Sync and Reprocess are paused on this screen until the queue moves. A new run would only
          wait in the queue.
        </p>
      </div>

      <div class="text-sm space-y-1">
        <h3 class="font-semibold">What you can do</h3>
        <ol class="list-decimal space-y-1 pl-5">
          <li>
            Restart the application container. This needs access to the server. If you do not have
            it, send this notice to whoever runs the platform. Before restarting, check that no run
            below is still advancing: restarting stops runs that are working. Steps: runbook,
            stalled queue (docs/producao/runbook.md §11).
          </li>
          <li :if={!@sem_historico?}>
            In production, the container healthcheck already reports unhealthy and /health answers
            503. Whether the server restarts the container by itself has not been measured.
          </li>
          <li>
            This notice clears by itself once a job finishes. If it is still here 15 min after a
            restart, restarting is not the fix: report it with the time shown above.
          </li>
        </ol>
      </div>

      <p class="text-xs opacity-70">
        What this notice does not know: {if @sem_historico?,
          do: "why the queue never started.",
          else: "why the queue stopped."}
      </p>
    </section>
    """
  end

  @doc "A marca ao lado de uma execução `running` quando a fila está parada."
  attr :fila, :map, required: true

  def execucao_parada(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 text-xs text-warning">
      <.marca forma={:hachurada} /> derived · not advancing · queue stalled
    </span>
    """
  end

  @doc """
  As duas afirmações sobre uma execução `running` com a fila parada, lado a lado: o que o
  registro diz e o que a fila diz. E, quando não há trabalho em execução, por que "Close stuck
  sync" não é oferecido.
  """
  attr :fila, :map, required: true
  attr :desde, :any, required: true
  attr :interrompivel?, :boolean, required: true

  def duas_afirmacoes(assigns) do
    ~H"""
    <div class="grid gap-2 text-xs sm:grid-cols-2">
      <div class="rounded border border-base-300 p-2">
        <div class="font-mono uppercase tracking-wide opacity-60">the run record says</div>
        <div>running, since {hora_curta(@desde)}. Nobody closed it.</div>
      </div>
      <div class="rounded border border-warning p-2">
        <div class="font-mono uppercase tracking-wide opacity-60">the queue says</div>
        <div :if={@fila.ultimo_completado_em}>
          no job has finished since {hora_curta(@fila.ultimo_completado_em)}, this run's included.
        </div>
        <div :if={is_nil(@fila.ultimo_completado_em)}>
          no job has ever finished on this installation.
        </div>
      </div>
    </div>
    <p :if={!@interrompivel?} class="text-xs opacity-80">
      Close stuck sync is not offered: this run's work is still in the queue, and closing the record
      would not move it. Restart first.
    </p>
    """
  end

  # As três marcas do design system, com a forma além da cor: sólida é observado, hachurada é
  # derivado, tracejada é ausente.
  attr :forma, :atom, values: [:solida, :hachurada, :tracejada], required: true

  defp marca(assigns) do
    ~H"""
    <span
      class={[
        "inline-block size-2.5 shrink-0 rounded-[1px]",
        @forma == :solida && "bg-current text-success",
        @forma == :hachurada &&
          "outline outline-1 -outline-offset-1 outline-current bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]",
        @forma == :tracejada && "border border-dashed border-current opacity-60"
      ]}
      aria-hidden="true"
    ></span>
    """
  end

  @doc "A duração em minutos, por extenso: `47 min`, `3 h 12 min`, `4 d 2 h`."
  @spec duracao(non_neg_integer() | nil) :: String.t()
  def duracao(nil), do: "an unknown time"
  def duracao(m) when m < 60, do: "#{m} min"

  def duracao(m) when m < 1440 do
    if rem(m, 60) == 0, do: "#{div(m, 60)} h", else: "#{div(m, 60)} h #{rem(m, 60)} min"
  end

  def duracao(m) do
    h = div(rem(m, 1440), 60)
    if h == 0, do: "#{div(m, 1440)} d", else: "#{div(m, 1440)} d #{h} h"
  end

  defp hora(%DateTime{} = t), do: Calendar.strftime(t, "%H:%M:%S UTC")
  defp hora(_), do: "unknown"

  defp hora_curta(%DateTime{} = t), do: Calendar.strftime(t, "%H:%M UTC")
  defp hora_curta(%NaiveDateTime{} = t), do: Calendar.strftime(t, "%H:%M UTC")
  defp hora_curta(_), do: "an unknown time"

  defp data_hora(%DateTime{} = t), do: Calendar.strftime(t, "%Y-%m-%d %H:%M UTC")
  defp data_hora(_), do: "unknown"
end
