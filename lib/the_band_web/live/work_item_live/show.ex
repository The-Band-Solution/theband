defmodule TheBandWeb.WorkItemLive.Show do
  @moduledoc """
  `/work/issues/:id` — uma issue: o que a origem disse, e o que a plataforma decidiu.

  ## Uma coisa, e ela é "esta issue"

  Princípio X. A tela não lista issues, não configura mapeamento e não dispara coleta —
  para tudo isso existe outro lugar. O que ela responde é *"o que se sabe desta issue, e
  de onde isso veio"*.

  ## Composição e atendimento aparecem separadas, e nunca somadas

  São relações ontologicamente distintas: `sro.epic_composed_of_user_story` **compõe**;
  `sro.intended_task_planned_to_meet_user_story` **atende**. Num épico com 3 user stories
  e 36 tarefas, esta tela mostra 3 numa seção e 36 na outra — **39 não aparece em lugar
  nenhum**.

  Uma contagem de "39 filhas" seria mais curta e apagaria a distinção que a plataforma
  existe para preservar: tarefa não faz parte de user story, atende a ela.

  ## Corpo ausente: `nil` e `""` não são a mesma coisa

  A origem devolve `""` para issue sem corpo, e a plataforma grava `nil` para issue que
  **nunca teve o corpo pedido** — coletada antes desta feature. A tela declara os dois
  casos com palavras diferentes, porque "sem descrição" e "não reobservada" pedem ações
  diferentes de quem lê.

  É a L13 aplicada à exibição: distinguir vazio de ausente já custou um CI vermelho.

  ## O corpo é texto, nunca marcação

  A coleta pede `bodyText`, e o HEEx escapa o que interpola. Nenhum caminho desta tela
  injeta HTML da origem — SC-011.

  ## O que esta tela não faz

    * **não consulta a origem** — tudo vem do banco (FR-033). Abrir detalhe de issue não
      pode gastar cota da API, senão navegar pelo produto o esgota;
    * **não edita** — a issue é o que a origem disse;
    * **não despromove por violação de axioma** — o inválido é o vínculo. Despromover
      esconderia a issue justamente onde o problema está visível.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems
  alias TheBandWeb.ConceptLabel

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    # Issue de outro tenant devolve "não encontrada", nunca "sem permissão": dizer
    # "sem permissão" confirmaria que o recurso existe.
    case WorkItems.fetch_issue(tenant, id) do
      {:ok, issue} ->
        {:ok,
         socket
         |> assign(page_title: "##{issue.number}")
         |> carregar(issue)
         |> assign_caminho(issue)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Issue not found.")
         |> push_navigate(to: ~p"/work")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        <span class="font-mono opacity-60">#{@issue.number}</span> {@issue.title}
        <:subtitle>{@repositorio_nome} · {@organizacao} · {estado(@issue)}</:subtitle>
        <:actions>
          <.link navigate={~p"/work/repositories/#{@issue.observed_repository_id}"}>
            <.button class="btn-outline btn-sm">Repository issues</.button>
          </.link>
          <a :if={@url_origem} href={@url_origem} target="_blank" rel="noopener">
            <.button class="btn-outline btn-sm">View at source</.button>
          </a>
        </:actions>
      </.header>

      <.notice
        :if={@issue.no_longer_observed_at}
        kind={:gap}
        title="This issue did not show up in the last collection."
      >
        Marked on {data(@issue.no_longer_observed_at)}. The record stays: absence marks, it never
        deletes.
      </.notice>

      <%!-- The count the source declares does NOT sit beside the two relations, and the
            reason is SC-004: here it is exactly their sum, and a reader would see "39 parts"
            next to 9 and 30 and conclude the two sections count the same thing twice.

            What does show up is what the sum would hide: a declared part the platform does
            not have. In the normal case it prints nothing. --%>
      <.notice
        :if={@partes_faltando > 0}
        kind={:gap}
        title="The source declares parts the platform does not have."
      >
        {@partes_faltando} of {@issue.sub_issue_count} were not collected — a part in a repository
        outside the observed scope, or a collection that did not reach it. The sections below show
        only what exists here.
      </.notice>

      <%!-- The axiom warning comes before everything, because it changes how the rest reads. --%>
      <.notice :if={@violacao} kind={:divergence} title="Link at odds with the ontology.">
        {WorkItems.rule07_explanation(@violacao)}
      </.notice>

      <.notice
        :if={@issue.divergence_reason}
        kind={:divergence}
        title={ConceptLabel.divergencia(@issue.divergence_kind) || "Label and structure disagree"}
      >
        {@issue.divergence_reason}
        <%!-- The two sentences say opposite things, which is why the kind matters: in one the
              platform CHANGED the concept by axiom, in the other it KEPT it on purpose. One
              text for both cases would let someone assume a correction that never happened. --%>
        <p :if={ConceptLabel.divergencia_mudou_conceito?(@issue.divergence_kind)} class="mt-1 text-xs">
          The concept was decided by the structure: an SRO axiom contradicts the label, and the
          axiom wins.
        </p>
        <p
          :if={not ConceptLabel.divergencia_mudou_conceito?(@issue.divergence_kind)}
          class="mt-1 text-xs"
        >
          The concept was kept. This is not a platform error — it is a signal about the team's
          process, and correcting it here would mean deciding for whoever wrote the issue.
        </p>
      </.notice>

      <div class="grid gap-6 lg:grid-cols-3">
        <div class="space-y-6 lg:col-span-2">
          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">Description</h3>
              <%!-- `nil` is "never collected"; `""` is "the source has no body". One text for
                    both would let someone conclude the issue is empty when what is missing is
                    a re-observation. --%>
              <p :if={is_nil(@issue.body)} class="text-sm text-base-content/70">
                Body not collected. This issue was observed before the platform started asking the
                source for the body, and the value will appear on this organisation's next
                collection.
              </p>
              <p :if={@issue.body == ""} class="text-sm text-base-content/70">
                The issue has no description at the source.
              </p>
              <p :if={@issue.body not in [nil, ""]} class="whitespace-pre-wrap text-sm">
                {@issue.body}
              </p>
            </div>
          </div>

          <%!-- Composition. Its own section, with the relation named — FR-015. --%>
          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">
                Composition <span class="opacity-60">{length(@composicao)}</span>
              </h3>
              <p class="text-xs text-base-content/70">
                <span class="font-mono">sro.epic_composed_of_user_story</span>
                — the user stories that <strong>compose</strong>
                this issue.
              </p>
              <p :if={@composicao == []} class="text-sm text-base-content/70">
                None. {sem_composicao(@issue)}
              </p>
              <.lista_de_issues :if={@composicao != []} issues={@composicao} />
            </div>
          </div>

          <%!-- Attendance. Another section, another count, never added — FR-016. --%>
          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">
                Attendance <span class="opacity-60">{length(@atendimento)}</span>
              </h3>
              <p class="text-xs text-base-content/70">
                <span class="font-mono">sro.intended_task_planned_to_meet_user_story</span>
                — the tasks that <strong>attend</strong>
                this issue. They do not compose it, and
                that is why this count is never added to the one above.
              </p>
              <p :if={@atendimento == []} class="text-sm text-base-content/70">
                No task attends this issue.
              </p>
              <.lista_de_issues :if={@atendimento != []} issues={@atendimento} />
            </div>
          </div>

          <div :if={@sem_promocao != []} class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">
                Parts with no concept <span class="opacity-60">{length(@sem_promocao)}</span>
              </h3>
              <p class="text-xs text-base-content/70">
                The source declares the relation and the platform has not decided what these parts
                are. They are collected: what is missing is a mapping rule.
              </p>
              <.lista_de_issues issues={@sem_promocao} />
            </div>
          </div>

          <div :if={@recusados != []} class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">
                Refused links <span class="opacity-60">{length(@recusados)}</span>
              </h3>
              <p class="text-xs text-base-content/70">
                Refused during collection, and recorded. Both issues remain collected: the link is
                refused, never the issue.
              </p>
              <ul class="mt-1 space-y-2 text-sm">
                <li :for={r <- @recusados}>
                  {ConceptLabel.recusa(r.reason)}
                  <div :if={r.cycle_path} class="font-mono text-xs opacity-70">{r.cycle_path}</div>
                  <div :if={r.child_external_id} class="text-xs opacity-70">
                    part outside the observed scope: {r.child_external_id}
                  </div>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">Promotion</h3>
              <dl>
                <.field label="concept">
                  <.evidence
                    concept={@issue.derived_concept}
                    source={@issue.evidence_source}
                    confidence={@issue.confidence}
                    skip_reason={@issue.skip_reason}
                    skip_detail={@issue.skip_detail}
                  />
                </.field>
                <.field label="evidence">{ConceptLabel.fonte(@issue.evidence_source)}</.field>
                <.field label="classification">{classificacao(@issue)}</.field>
                <.field label="type at source">{@issue.issue_type || "none"}</.field>
                <.field label="rule">
                  <span class="font-mono text-xs">{@issue.rule_id || "—"}</span>
                  <span :if={@issue.rule_version} class="opacity-60">v{@issue.rule_version}</span>
                </.field>
              </dl>
            </div>
          </div>

          <div :if={@pai} class="card bg-base-200">
            <div class="card-body gap-1 p-4 sm:p-5">
              <h3 class="font-semibold">{rotulo_do_pai(@issue)}</h3>
              <.link navigate={~p"/work/issues/#{@pai.id}"} class="link link-hover text-sm">
                <span class="font-mono">#{@pai.number}</span> {@pai.title}
              </.link>
              <div class="text-xs opacity-70">
                {ConceptLabel.rotulo(@pai.derived_concept) || "no concept"}
              </div>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">As the source describes it</h3>
              <dl>
                <.field label="author">
                  <%!-- A ligação é **condicional**, e é o que separa esta feature de um defeito:
                        são 288 aparições cujo login a plataforma nunca coletou como pessoa, e um
                        `<.link>` incondicional produziria clique que promete e não entrega. --%>
                  <.link
                    :if={@issue.author_person_id}
                    navigate={~p"/people/#{@issue.author_person_id}"}
                    class="link link-hover underline decoration-dotted"
                  >
                    {@autor_nome || @issue.author_login}
                  </.link>
                  <span :if={is_nil(@issue.author_person_id)}>
                    {@autor_nome || @issue.author_login || "—"}
                  </span>
                  <%!-- A login with no linked person is a declaration, not a failure: the
                        person was not collected, and creating them from the issue would
                        produce a record with no provenance. --%>
                  <div
                    :if={@issue.author_login && is_nil(@issue.author_person_id)}
                    class="text-xs opacity-60"
                  >
                    person not collected
                  </div>
                </.field>
                <.field label="assignees">
                  <.absent :if={@issue.assignees == []} reason="nobody assigned" />
                  <ul :if={@issue.assignees != []} class="space-y-0.5">
                    <li :for={a <- @issue.assignees}>
                      <.link
                        :if={a.person_id}
                        navigate={~p"/people/#{a.person_id}"}
                        class="link link-hover underline decoration-dotted"
                      >
                        {@nomes[a.person_id] || a.login}
                      </.link>
                      <span :if={is_nil(a.person_id)}>{a.login}</span>
                      <span :if={is_nil(a.person_id)} class="text-xs opacity-60">
                        (person not collected)
                      </span>
                    </li>
                  </ul>
                </.field>
                <.field label="labels">
                  <.absent :if={@issue.labels == []} reason="none" />
                  <span :for={l <- @issue.labels} class="badge badge-xs badge-ghost mr-1">
                    {l.name}
                  </span>
                </.field>
                <.field label="milestone">
                  <.absent :if={is_nil(@issue.milestone_title)} reason="not in a milestone" />
                  <span :if={@issue.milestone_title}>{@issue.milestone_title}</span>
                </.field>
                <.field label="boards">
                  <.absent :if={@issue.project_titles == []} reason="not on a board" />
                  <span :if={@issue.project_titles != []}>
                    {Enum.join(@issue.project_titles, ", ")}
                  </span>
                </.field>
                <.field label="comments">{@issue.comment_count}</.field>
                <.field label="reactions">{@issue.reaction_count}</.field>
              </dl>
              <p class="mt-1 text-xs opacity-60">
                The comment count is collected; the content is not. A comment is an entity of its
                own, and collecting them would multiply what the source is asked for per issue.
              </p>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">Dates</h3>
              <dl>
                <.field label="created at source">{data(@issue.external_created_at) || "—"}</.field>
                <.field label="updated at source">{data(@issue.external_updated_at) || "—"}</.field>
                <.field label="closed at source">{data(@issue.external_closed_at) || "open"}</.field>
                <.field label="first collected">{data(@issue.collected_at)}</.field>
                <.field label="last observed">{data(@issue.last_observed_at)}</.field>
              </dl>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">
                Promotion history <span class="opacity-60">{length(@historico)}</span>
              </h3>
              <p class="text-xs text-base-content/70">
                Append-only: every decision is a row, and the current one is the last.
              </p>
              <ol class="mt-1 space-y-2 text-sm">
                <li :for={h <- @historico}>
                  <span class="font-medium">
                    {ConceptLabel.rotulo(h.derived_concept) ||
                      ConceptLabel.indefinida(h.skip_reason, h.skip_detail)}
                  </span>
                  <span :if={h.current} class="badge badge-xs badge-primary ml-1">current</span>
                  <div class="text-xs opacity-70">
                    {data(h.promoted_at)} · <span class="font-mono">{h.rule_id}</span>
                    <span :if={h.rule_version}>v{h.rule_version}</span>
                  </div>
                </li>
              </ol>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :issues, :list, required: true

  defp lista_de_issues(assigns) do
    ~H"""
    <table class="table table-sm mt-1">
      <tbody>
        <tr :for={i <- @issues}>
          <td class="font-mono w-16">#{i.number}</td>
          <td>
            <.link navigate={~p"/work/issues/#{i.id}"} class="link link-hover">
              {i.title}
            </.link>
          </td>
          <td class="text-xs opacity-70 w-40">
            {ConceptLabel.rotulo(i.derived_concept) ||
              ConceptLabel.indefinida(i.skip_reason, i.skip_detail)}
          </td>
          <td class="text-xs opacity-60 w-20">
            {if i.sub_issue_count > 0, do: "#{i.sub_issue_count} partes"}
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp carregar(socket, issue) do
    tenant = socket.assigns.current_tenant
    pai = WorkItems.fetch_parent(tenant, issue.id)
    repositorio = repositorio(tenant, issue.observed_repository_id)
    nomes = nomes(tenant, issue)

    socket
    |> assign(
      issue: issue,
      pai: pai,
      # A verificação do axioma é a **mesma função** que a tela do repositório usa em
      # lote. Dois caminhos discordariam, e uma tela avisaria o que a outra nega.
      violacao: violacao(issue, pai),
      composicao: WorkItems.list_composition(tenant, issue.id),
      atendimento: WorkItems.list_attendance(tenant, issue.id),
      sem_promocao: WorkItems.list_unpromoted_parts(tenant, issue.id),
      recusados: WorkItems.list_refused_for(tenant, issue.id),
      historico: WorkItems.promotion_history(tenant, issue.id),
      partes_faltando: partes_faltando(tenant, issue),
      nomes: nomes,
      autor_nome: nomes[issue.author_person_id]
    )
    |> assign(onde(tenant, repositorio, issue))
  end

  # `fetch_observed/2` devolve `{:ok, _}` ou `{:error, :not_found}`, e a tela trata a
  # segunda como ausência de contexto — não como falha: a issue existe e continua
  # consultável mesmo se o repositório dela deixou de ser observado.
  defp repositorio(tenant, id) do
    case CMPO.fetch_observed(tenant, id) do
      {:ok, repositorio} -> repositorio
      {:error, :not_found} -> nil
    end
  end

  # Declaradas menos as que existem aqui, em qualquer das três listas. Nunca negativo: a
  # origem pode declarar menos do que a plataforma vinculou quando a contagem dela e as
  # sub-issues vêm de páginas diferentes.
  defp partes_faltando(tenant, issue) do
    presentes =
      length(WorkItems.list_composition(tenant, issue.id)) +
        length(WorkItems.list_attendance(tenant, issue.id)) +
        length(WorkItems.list_unpromoted_parts(tenant, issue.id))

    max(issue.sub_issue_count - presentes, 0)
  end

  defp violacao(issue, pai) do
    case WorkItems.rule07(issue.derived_concept, pai && pai.derived_concept) do
      :ok -> nil
      {:violation, forma} -> forma
    end
  end

  # O nome da pessoa vem pela API pública de EO: `WorkItems` guarda a **referência** e
  # não alcança `eo_people`. É a regra da fronteira do princípio IX em leitura.
  defp nomes(tenant, issue) do
    ids =
      [issue.author_person_id | Enum.map(issue.assignees, & &1.person_id)]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    EO.people_names(tenant, ids)
  end

  # **O caminho depende de onde a pessoa veio, e o padrão é o estrutural.**
  #
  # A issue pertence a um repositório **e** aparece na lista de trabalho. Quem chegou pela lista do
  # repositório veio de outro lugar que quem chegou por `/work` — e uma migalha fixa diria um
  # caminho que ninguém percorreu.
  #
  # Sem percurso — endereço colado, ou recarregar —, vale o **estrutural**: o repositório é o dono
  # da issue, e é a resposta verdadeira quando não se sabe a outra.
  defp assign_caminho(socket, issue) do
    veio_do_repositorio? =
      case get_connect_params(socket)["referrer"] || socket.assigns[:referrer] do
        url when is_binary(url) -> String.contains?(url, "/work/repositories/")
        _ -> false
      end

    niveis =
      [%{rotulo: "Work", destino: ~p"/work"}] ++
        caminho_do_repositorio(socket, issue, veio_do_repositorio?) ++
        [%{rotulo: "##{issue.number}", destino: nil}]

    assign(socket, caminho: niveis)
  end

  # O repositório entra no caminho **sempre que se sabe qual é** — vindo dele ou não. É o que a
  # spec chama de caminho estrutural, e é o padrão quando não há percurso.
  defp caminho_do_repositorio(socket, issue, _veio?) do
    case socket.assigns[:repositorio_nome] do
      nil ->
        []

      "repository not found" ->
        []

      nome ->
        [%{rotulo: nome, destino: ~p"/work/repositories/#{issue.observed_repository_id}"}]
    end
  end

  defp onde(_tenant, nil, _issue),
    do: %{repositorio_nome: "repository not found", organizacao: "—", url_origem: nil}

  defp onde(tenant, repositorio, issue) do
    organizacao =
      tenant
      |> EO.list_organizations()
      |> Enum.find(&(&1.id == repositorio.organization_id))

    %{
      repositorio_nome: repositorio.name,
      organizacao: (organizacao && (organizacao.login || organizacao.name)) || "—",
      # A URL da issue é composta do repositório e do número. O número serve para exibir
      # e localizar — nunca para identificar —, e aqui é exatamente o caso de localizar.
      url_origem: repositorio.url && "#{repositorio.url}/issues/#{issue.number}"
    }
  end

  defp estado(%{state: "CLOSED"} = issue),
    do: "closed#{motivo_do_fechamento(issue.state_reason)}"

  defp estado(%{state: estado}), do: String.downcase(estado)

  # `COMPLETED` e `NOT_PLANNED` são fechamentos diferentes, e a diferença é do time.
  defp motivo_do_fechamento("COMPLETED"), do: " · completed"
  defp motivo_do_fechamento("NOT_PLANNED"), do: " · not planned"
  defp motivo_do_fechamento(nil), do: ""
  defp motivo_do_fechamento(outro), do: " · #{String.downcase(outro)}"

  defp classificacao(%{classification: :epic}), do: "epic — it has parts that are user stories"

  defp classificacao(%{classification: :atomic_user_story}),
    do: "atomic — no part is a user story"

  # Ausência de decomposição é declarada, e o texto muda com o conceito: um épico sem
  # partes é sinal; uma tarefa sem partes é o normal.
  defp sem_composicao(%{derived_concept: "sro.epic"}),
    do: "An epic with no collected parts signals a decomposition that never reached the source."

  defp sem_composicao(%{sub_issue_count: n}) when n > 0,
    do: "The source declares #{n} parts, and none was promoted to a user story."

  defp sem_composicao(_), do: "The source declares no parts."

  defp rotulo_do_pai(%{derived_concept: "sro.intended_scrum_development_task"}), do: "Attends"

  defp rotulo_do_pai(_), do: "Part of"

  defp data(nil), do: nil
  defp data(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
end
