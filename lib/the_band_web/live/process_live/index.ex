defmodule TheBandWeb.ProcessLive.Index do
  @moduledoc """
  `/process` — o que a plataforma observa do processo executado, e o que ela não mede.

  ## Uma coisa, e ela é "o processo desta organização"

  Princípio X. Esta tela **não** responde "o que aconteceu com esta issue" — isso é
  `/work/issues/:id`. O que ela responde é *"que tipos de evento e que estados de quadro
  existem aqui, com que frequência, e o que isso impede de medir"*.

  A separação não é estética. O antipadrão `process.ap05` é do **quadro**, e não de uma
  issue: mostrá-lo na página da issue faria parecer que aquela issue tem um problema,
  quando o problema atinge todas as issues do quadro igualmente.

  ## Por que a lista de estados existe

  Ela é o que permite alguém **declarar** qual movimentação marca o início do trabalho —
  FR-007 e FR-010. A plataforma recusa escolher sozinha, e quem vai escolher precisa ver
  o vocabulário real do quadro antes.

  E é ela que torna o `process.ap05` visível: um quadro cujos estados não incluem nenhum
  que signifique "em andamento" não permite medir cycle time de issue nenhuma.

  ## O aviso que aparece sempre não é aviso

  Quando o quadro **tem** estado de andamento, nada é sinalizado — SC-008. Um alerta
  constante treina quem lê a ignorá-lo, e é justamente o alerta que importa quando
  aparece.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.SPO

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant
    estados = SPO.count_board_states(tenant)

    {:ok,
     socket
     |> assign(page_title: "Process")
     |> assign(
       tipos: SPO.count_activity_types(tenant),
       estados: estados,
       sem_andamento?: estados != [] and not Enum.any?(estados, &SPO.andamento?(&1.state)),
       duplicados: duplicados(estados)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        Process
        <:subtitle>
          What the platform observes of the executed process — and what it cannot measure
        </:subtitle>
      </.header>

      <%!-- O sinal do ap05 vem ANTES das listas, porque ele muda como elas se leem: os
            estados abaixo deixam de ser um vocabulário e passam a ser a evidência. --%>
      <.notice
        :if={@sem_andamento?}
        kind={:divergence}
        title="This board has no state that means work in progress."
      >
        <p>
          Cycle time is impossible for <strong>every issue on this board</strong>, not just some.
          There is no instant that marks the start, because there is no state that represents it.
        </p>
        <p class="mt-1 text-xs">
          WIP does not exist either: counting what sits before the work counts who has not started,
          and counting what sits after counts who has finished. Neither is work in progress.
        </p>
        <p class="mt-1 text-xs">
          <span class="font-mono">process.ap05</span>
          — it is fixed on the board, by adding a state, and only for issues moved after that.
          Issues that already went through the old flow do not gain movement retroactively.
        </p>
      </.notice>

      <.notice
        :if={@duplicados != []}
        kind={:divergence}
        title="Two states may mean the same thing."
      >
        <p>
          <span :for={{par, i} <- Enum.with_index(@duplicados)}>
            <span :if={i > 0}>, </span>
            <span class="font-mono">{elem(par, 0)}</span>
            and <span class="font-mono">{elem(par, 1)}</span>
          </span>
        </p>
        <p class="mt-1 text-xs">
          <%!-- A plataforma NÃO decide que dois nomes significam o mesmo. Ela mostra e
                alguém confirma — pela mesma razão de a alocação de papel ser declaração
                humana. Duas etapas parecidas podem ser distintas de verdade. --%>
          <span class="font-mono">process.ap06</span>
          — the platform does not decide this: it shows what it observed, and someone confirms.
          If they do mean the same thing, every count by state is split in two, and wrong
          <em>downwards</em>
          — which is the kind of wrong that looks plausible.
        </p>
      </.notice>

      <div class="grid gap-6 lg:grid-cols-2">
        <div class="card bg-base-200">
          <div class="card-body gap-2 p-4 sm:p-5">
            <h3 class="font-semibold">
              Board states <span class="opacity-60">{length(@estados)}</span>
            </h3>
            <p class="text-xs text-base-content/70">
              This is what lets someone declare which movement marks the start of work. The
              platform will not choose on its own.
            </p>

            <p :if={@estados == []} class="text-sm opacity-70">
              No board movement collected yet. This does not mean the process is healthy — it
              means the platform has not looked.
            </p>

            <table :if={@estados != []} class="table table-sm mt-1">
              <tbody>
                <tr :for={e <- @estados}>
                  <td class="font-mono">{e.state}</td>
                  <td class="w-20 text-right opacity-70">{e.count}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body gap-2 p-4 sm:p-5">
            <h3 class="font-semibold">
              Activity types <span class="opacity-60">{length(@tipos)}</span>
            </h3>
            <p class="text-xs text-base-content/70">
              The type is recorded as the source names it. The ones with no concept are the
              point: they say what the network does not name yet.
            </p>

            <p :if={@tipos == []} class="text-sm opacity-70">
              No activity collected yet.
            </p>

            <table :if={@tipos != []} class="table table-sm mt-1">
              <tbody>
                <tr :for={t <- @tipos}>
                  <td class="font-mono text-xs">{t.type}</td>
                  <td class="text-xs opacity-70">
                    <span :if={t.concept}>{t.concept}</span>
                    <span :if={is_nil(t.concept)} class="badge badge-xs badge-ghost">
                      unnamed by the network
                    </span>
                  </td>
                  <td class="w-16 text-right opacity-70">{t.count}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Pares que **podem** significar o mesmo: mesma sequência de letras e dígitos, ignorando
  # caixa, espaço e separador. É o caso medido — `To Do` e `Todo`.
  #
  # Deliberadamente estreito. Um critério de similaridade acharia `Refinamento` parecido
  # com `Refinado` e a tela passaria a sugerir fusões erradas, que é pior que não sugerir:
  # sugestão errada custa a confiança de quem lê as certas.
  defp duplicados(estados) do
    estados
    |> Enum.group_by(&normalizar(&1.state))
    |> Enum.filter(fn {_chave, grupo} -> length(grupo) > 1 end)
    |> Enum.map(fn {_chave, grupo} ->
      [a, b | _] = Enum.map(grupo, & &1.state)
      {a, b}
    end)
  end

  defp normalizar(estado) do
    estado
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/u, "")
  end
end
