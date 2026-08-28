defmodule TheBandWeb.VerificationLive.Show do
  @moduledoc """
  `/work/verifications/:id` — uma execução e os processos que ela materializou.

  ## O que a tela existe para responder

  "Quebrou" não diz o que quebrou. Esta tela diz: cada job com os componentes que a regra
  `github.ci_job_routing` reconheceu nele, e a fase de cada um. Quando um job carrega mais
  de um processo, o rótulo do antipadrão aparece **ao lado do job**, e não numa lista
  distante — é ali que a informação serve.

  ## Os quatro valores crus ficam visíveis

  `trigger_event`, `run_status`, `conclusion` e `attempt` são o que a origem entregou;
  fase e tipo são a interpretação. Mostrar os dois é o que permite discordar da tradução
  sem ir ao banco.
  """
  use TheBandWeb, :live_view

  alias TheBand.Verification

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case Verification.get(tenant, id) do
      # "Não encontrada", nunca "sem permissão": dizer que existe e é de outro tenant
      # entregaria a existência dela.
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Verification run not found")
         |> push_navigate(to: ~p"/work/verifications")}

      execucao ->
        {:ok,
         socket
         |> assign(page_title: execucao.workflow_name || "Verification run")
         |> assign(execucao: execucao)
         |> assign(jobs: Verification.components_of(tenant, execucao.id))}
    end
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
      <.header>
        {@execucao.workflow_name || "unnamed workflow"}
        <:subtitle>
          {@execucao.repository} ·
          <span class="font-mono">{String.slice(@execucao.head_sha || "", 0, 7)}</span>
          <span :if={@execucao.head_branch}> on {@execucao.head_branch}</span>
        </:subtitle>
      </.header>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="min-w-0 rounded-lg border border-base-300 p-4">
          <h2 class="mb-2 text-sm font-semibold">What the source said</h2>
          <dl class="grid grid-cols-2 gap-x-3 gap-y-1 font-mono text-xs">
            <dt class="opacity-60">event</dt>
            <dd>{@execucao.trigger_event || "—"}</dd>
            <dt class="opacity-60">status</dt>
            <dd>{@execucao.run_status || "—"}</dd>
            <dt class="opacity-60">conclusion</dt>
            <dd>{@execucao.conclusion || "—"}</dd>
            <%!-- A tentativa importa: passar na terceira é sucesso, não falha, e a máxima
                  `ci.ap03` olha a vigente. Esconder o número faria o sucesso parecer de
                  primeira. --%>
            <dt class="opacity-60">attempt</dt>
            <dd>
              {@execucao.attempt}<span :if={@execucao.attempt > 1} class="ml-1 not-italic opacity-70">(re-run)</span>
            </dd>
          </dl>
        </div>

        <div class="min-w-0 rounded-lg border border-base-300 p-4">
          <h2 class="mb-2 text-sm font-semibold">
            What the platform derived
            <%!-- Derivado ganha rótulo e hachura, sempre: quem lê precisa saber que este
                  valor não veio da origem, e sim de uma regra que pode ser revista. --%>
            <span class="badge badge-outline badge-warning badge-xs ml-1">derived</span>
          </h2>
          <%!-- Empilhado no telefone, duas colunas a partir de `sm:`: os identificadores
                do continuum têm 45 caracteres em mono, e duas colunas de 175px os
                estouravam para fora do cartão — 533px de documento num viewport de 390,
                medido em 2026-08-18. --%>
          <dl class="grid grid-cols-1 gap-x-3 gap-y-1 text-xs sm:grid-cols-[auto_1fr]">
            <dt class="font-mono opacity-60">phase</dt>
            <dd class="min-w-0 break-all">
              <span :if={@execucao.phase} class="font-mono">{@execucao.phase}</span>
              <span :if={is_nil(@execucao.phase)} class="italic opacity-60">
                {if @execucao.run_status == "completed",
                  do: "finished, but the rule does not decide this conclusion",
                  else: "still running — it has decided nothing yet"}
              </span>
            </dd>
            <dt class="font-mono opacity-60">is a</dt>
            <dd class="min-w-0 break-all">
              <span :for={t <- @execucao.process_kinds} class="mr-1 block font-mono">{t}</span>
              <span :if={@execucao.process_kinds == []} class="italic opacity-60">
                neither verification nor deployment — the network has no concept for it
              </span>
            </dd>
          </dl>
        </div>
      </div>

      <section>
        <h2 class="mb-1 text-sm font-semibold">
          Jobs and the processes each one materialised
        </h2>
        <p class="mb-3 text-xs opacity-70">
          Classified from the job name and its step names by rule <span class="font-mono">github.ci_job_routing</span>, with low confidence — the
          structure wins over the declared name.
        </p>

        <p :if={@jobs == []} class="alert">
          <strong>The jobs of this run were not collected.</strong>
          The run itself is here; its jobs are a separate request that did not complete.
          This is not a run without jobs.
        </p>

        <div :if={@jobs != []} class="overflow-x-auto">
          <table class="table stacked table-sm">
            <thead>
              <tr>
                <th>job</th>
                <th>materialises</th>
                <th>result</th>
                <th>steps</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={j <- @jobs}>
                <td data-label="job" class="font-medium">
                  {j.job_name}
                  <%!-- O rótulo do antipadrão vive AO LADO do job, não numa lista à parte:
                        é aqui que ele explica por que o resultado é grosso. --%>
                  <span
                    :if={length(j.components) > 1}
                    class="badge badge-outline badge-warning badge-xs ml-1"
                    title="ci.ap01.monolithic_job — one conclusion for more than one process"
                  >
                    monolithic
                  </span>
                </td>
                <td data-label="materialises" class="text-xs">
                  <span :for={c <- j.components} class="badge badge-ghost badge-xs mr-1">{c}</span>
                  <span :if={j.components == []} class="italic opacity-60">
                    {frase_sem_componente(@execucao.process_kinds)}
                  </span>
                </td>
                <td data-label="result" class="text-xs">
                  <span class="font-mono">{j.conclusion || j_status(j)}</span>
                </td>
                <td data-label="steps" class="text-xs opacity-70">{length(j.step_names)}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <.link navigate={~p"/work/verifications"} class="btn btn-ghost btn-sm">
        Back to verification runs
      </.link>
    </Layouts.app>
    """
  end

  # A mesma célula vazia significa coisas diferentes conforme a execução seja verificação
  # ou não — e chamar as duas de antipadrão produziria 751 defeitos falsos, medido em
  # 2026-08-18.
  defp frase_sem_componente(tipos) do
    if "ciro.continuous_integration_process" in tipos do
      "unnamed — ci.ap02"
    else
      "not a verification job"
    end
  end

  defp j_status(%{finished_at: nil}), do: "running"
  defp j_status(_), do: "—"
end
