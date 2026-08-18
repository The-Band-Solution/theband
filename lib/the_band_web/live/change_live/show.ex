defmodule TheBandWeb.ChangeLive.Show do
  @moduledoc """
  `/work/changes/:id` — a solicitação de mudança e o que ela realizou (feature 032).

  Fecha o rastreio nos dois sentidos: os **commits** que a realizaram, com todos os
  autores de cada um, e as **issues** que ela atende.

  ## As três pessoas da tela são papéis diferentes

  Quem submeteu, quem integrou e quem executou cada commit aparecem separados porque a
  ontologia os separa — três participações distintas em `cmpo.change_traceability`. No
  dado real do The Band elas coincidem quase sempre numa pessoa só, e **isso é um achado
  sobre o processo**, não uma propriedade do modelo: mostrar os três campos é o que
  permite ver que ninguém revisou.
  """
  use TheBandWeb, :live_view

  alias TheBand.Changes
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Verification

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case Changes.get(tenant, id) do
      {:ok, solicitacao} ->
        commits = Changes.commits_of(tenant, solicitacao.id)
        issues = Changes.attended_issues(tenant, solicitacao.id)

        {:ok,
         socket
         |> assign(page_title: "##{solicitacao.number}")
         |> assign(solicitacao: solicitacao, commits: commits, issues: issues)
         |> assign(verificacoes: Verification.for_change_request(tenant, solicitacao.id))
         |> assign(nomes: nomes(tenant, solicitacao, commits))}

      # Id de outro tenant devolve "não encontrada", nunca "sem permissão": dizer "sem
      # permissão" confirmaria que o recurso existe.
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Change request not found.")
         |> push_navigate(to: ~p"/work")}
    end
  end

  # Uma consulta de nomes para a tela inteira: autor, integrador e cada autor de cada
  # commit. Uma consulta por pessoa seria o defeito da feature 007 numa roupa nova.
  defp nomes(tenant, solicitacao, commits) do
    ids =
      [solicitacao.author_person_id, solicitacao.merged_by_person_id]
      |> Kernel.++(Enum.flat_map(commits, fn c -> Enum.map(c.autores, & &1.person_id) end))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    EO.people_names(tenant, ids)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.breadcrumb niveis={[
        %{rotulo: "Work", destino: ~p"/work"},
        %{rotulo: "##{@solicitacao.number}", destino: nil}
      ]} />

      <.header>
        #{@solicitacao.number} {@solicitacao.title}
        <:subtitle>
          change request · {String.downcase(@solicitacao.state || "")} · {@solicitacao.source_branch} → {@solicitacao.target_branch}
        </:subtitle>
      </.header>

      <div class="grid gap-4 lg:grid-cols-3">
        <div class="card min-w-0 bg-base-200 lg:col-span-2">
          <div class="card-body gap-3 p-4">
            <h3 class="card-title text-base">Commits</h3>
            <p class="text-xs text-base-content/70">
              The acts that carried out this request, in order — each with <strong>every</strong>
              author the source records. A commit with two authors has two.
            </p>

            <p :if={@commits == []} class="text-sm opacity-70">
              No commit collected for this request.
            </p>

            <%!-- Truncamento DITO. Sem esta frase a tela mostraria cinquenta commits como
                  se fossem todos, e "cinquenta" e "os cinquenta primeiros de duzentos"
                  afirmam coisas diferentes sobre o mesmo trabalho. 509 das 5.032
                  solicitações do tenant real caem neste caso. --%>
            <p
              :if={
                @solicitacao.commits_total && @solicitacao.commits_collected &&
                  @solicitacao.commits_collected < @solicitacao.commits_total
              }
              class="text-xs text-warning"
            >
              Showing {@solicitacao.commits_collected} of {@solicitacao.commits_total} commits —
              the rest was not collected, not absent.
            </p>

            <ol :if={@commits != []} class="space-y-3">
              <li :for={c <- @commits} class="border-t border-base-300 pt-2 first:border-0">
                <div class="flex flex-wrap items-baseline gap-x-2">
                  <span class="font-mono text-xs opacity-60">{String.slice(c.sha, 0, 8)}</span>
                  <span class="text-sm font-medium">{c.headline}</span>
                </div>
                <div class="mt-0.5 flex flex-wrap items-baseline gap-x-3 text-xs opacity-70">
                  <span class="tabular-nums">{c.committed_at}</span>
                  <span :if={c.additions} class="font-mono tabular-nums">
                    +{c.additions} −{c.deletions}
                  </span>
                </div>
                <div class="mt-1 flex flex-wrap items-baseline gap-x-3 gap-y-1 text-xs">
                  <span :for={a <- c.autores} class="flex items-baseline gap-1">
                    <.link
                      :if={a.person_id}
                      navigate={~p"/people/#{a.person_id}"}
                      class="link link-hover"
                    >
                      {@nomes[a.person_id] || a.login}
                    </.link>
                    <span :if={is_nil(a.person_id)} class="opacity-70">
                      {a.login || a.name}
                      <span class="opacity-60">(person not collected)</span>
                    </span>
                    <%!-- Co-autoria dita, e não escondida: quem entrou pelo trailer
                          Co-Authored-By participou da mudança, e apresentar como autoria
                          única apagaria isso. --%>
                    <span :if={not a.is_primary} class="badge badge-ghost badge-xs">co-author</span>
                  </span>
                </div>
              </li>
            </ol>
          </div>
        </div>

        <div class="flex min-w-0 flex-col gap-4">
          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4">
              <h3 class="card-title text-base">Who did what</h3>
              <p class="text-xs text-base-content/70">
                Submitting, integrating and committing are different acts — the network
                declares a participation for each. When the same person does all three,
                that is a finding about the process, not a property of the model.
              </p>

              <.field label="submitted by">
                <.link
                  :if={@solicitacao.author_person_id}
                  navigate={~p"/people/#{@solicitacao.author_person_id}"}
                  class="link link-hover"
                >
                  {@nomes[@solicitacao.author_person_id] || @solicitacao.author_login}
                </.link>
                <span :if={is_nil(@solicitacao.author_person_id)}>
                  {@solicitacao.author_login || "author no longer at the source"}
                </span>
              </.field>

              <.field label="integrated by">
                <.link
                  :if={@solicitacao.merged_by_person_id}
                  navigate={~p"/people/#{@solicitacao.merged_by_person_id}"}
                  class="link link-hover"
                >
                  {@nomes[@solicitacao.merged_by_person_id] || @solicitacao.merged_by_login}
                </.link>
                <.absent
                  :if={
                    is_nil(@solicitacao.merged_by_person_id) and is_nil(@solicitacao.merged_by_login)
                  }
                  reason="not integrated — still open or closed without merging"
                />
              </.field>

              <.field label="opened">{@solicitacao.created_at}</.field>
              <.field :if={@solicitacao.merged_at} label="merged">{@solicitacao.merged_at}</.field>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4">
              <h3 class="card-title text-base">Issues it attends</h3>
              <p class="text-xs text-base-content/70">
                What the <strong>source recognised</strong>
                from the closing keywords — never what the text seems to say.
              </p>

              <p :if={@issues == []} class="text-sm opacity-70">
                This request closes no issue. That is common and not a fault — but a
                keyword the source did not recognise looks exactly like this.
              </p>

              <div :for={i <- @issues} class="border-t border-base-300 pt-1.5 text-sm">
                <.link navigate={~p"/work/issues/#{i.id}"} class="link link-hover">
                  #{i.number} {i.title}
                </.link>
                <span class="text-xs opacity-60">{String.downcase(i.state || "")}</span>
              </div>
            </div>
          </div>

          <%!-- A verificação fecha o rastro: issue → solicitação → commit → o que a
                máquina disse sobre esse commit. O elo é o SHA, e não uma tabela de
                vínculo — o identificador já é o vínculo, e guardá-lo de novo seria
                inventar um lugar onde os dois podem divergir. --%>
          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4">
              <h3 class="card-title text-base">What the checks said</h3>

              <p :if={@verificacoes == []} class="text-sm opacity-70">
                No collected run verified these commits. That may mean the repository has
                no continuous verification, or that it was not swept yet — <.link
                  navigate={~p"/work/verifications"}
                  class="link"
                >
                  the verification page separates the two
                </.link>.
              </p>

              <div :for={v <- @verificacoes} class="border-t border-base-300 pt-1.5 text-sm">
                <.link navigate={~p"/work/verifications/#{v.id}"} class="link link-hover">
                  {v.workflow_name || "unnamed workflow"}
                </.link>
                <span class="ml-1 font-mono text-xs opacity-60">
                  {String.slice(v.head_sha || "", 0, 7)}
                </span>
                <span class={["badge badge-xs ml-1", cor_da_fase(v.phase)]}>
                  {rotulo_da_fase(v.phase, v.run_status)}
                </span>
                <%!-- Passar na terceira tentativa é sucesso, e esconder o número faria
                      parecer de primeira. --%>
                <span :if={v.attempt > 1} class="ml-1 text-xs opacity-60">
                  attempt {v.attempt}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Interrompida e não executada NÃO são erro: cancelar é decisão humana, e pintá-las de
  # vermelho ao lado de uma solicitação integrada acusaria o que ninguém quebrou.
  defp cor_da_fase("ciro.successful_continuous_integration_process"), do: "badge-success"
  defp cor_da_fase("ciro.unsuccessful_continuous_integration_process"), do: "badge-error"
  defp cor_da_fase("ciro.interrupted_continuous_integration_process"), do: "badge-warning"
  defp cor_da_fase("ciro.expired_continuous_integration_process"), do: "badge-warning"
  defp cor_da_fase(_outra), do: "badge-ghost"

  defp rotulo_da_fase("ciro.successful_continuous_integration_process", _), do: "passed"
  defp rotulo_da_fase("ciro.unsuccessful_continuous_integration_process", _), do: "failed"
  defp rotulo_da_fase("ciro.interrupted_continuous_integration_process", _), do: "cancelled"
  defp rotulo_da_fase("ciro.unperformed_continuous_integration_process", _), do: "skipped"
  defp rotulo_da_fase("ciro.expired_continuous_integration_process", _), do: "timed out"
  defp rotulo_da_fase(nil, "completed"), do: "phase undecided"
  defp rotulo_da_fase(nil, _), do: "running"
end
