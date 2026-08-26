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

  alias TheBand.Changes
  alias TheBand.Communication.Discussions
  alias TheBand.Mapping.Antipatterns
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
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
      <.breadcrumb niveis={@caminho} />
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

          <%!-- A quarta lista, e ela existe porque as três não cobriam tudo — issue #262.
                Filha promovida a defeito não é composição nem atendimento, e não é "sem
                conceito": a plataforma decidiu o que ela é, e a rede de ontologias é que não
                nomeia essa relação. Eram 33 vínculos invisíveis, e nada falhava. --%>
          <div :if={@relacao_sem_nome != []} class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">
                Parts the ontology does not name
                <span class="opacity-60">{length(@relacao_sem_nome)}</span>
              </h3>
              <p class="text-xs text-base-content/70">
                The platform decided what these parts are, and the ontology network does not name
                the relation between that concept and this one. They are neither composition nor
                attendance — and inventing a name for the relation would be inference by
                resemblance.
              </p>
              <.lista_de_issues issues={@relacao_sem_nome} />
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

          <%!-- ═══ O INSTANTE DE INÍCIO — issue #370, FR-013 e FR-015 ═══
                Fica junto das outras datas porque é uma delas — mas é a única derivada, e
                por isso vem com a origem. As outras a origem informa; esta a organização
                decidiu. --%>
          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">Start instant</h3>
              <p class="text-sm">
                <span :if={match?({:ok, _, _, _}, @inicio)}>
                  <strong>{data(elem(@inicio, 1))}</strong>
                  — the first time
                  <span class="badge badge-outline badge-sm font-mono">{elem(@inicio, 3)}</span>
                  happened on it — <strong>the first</strong>, because a task that went back to
                  the backlog and out again started when it started.
                </span>
                <%!-- Cada ausência tem causa própria e ação própria — FR-009, FR-015. Nenhum
                      código de motivo: quem lê não deveria ter que procurar o que significa. --%>
                <span :if={@inicio == {:missing, :sem_criterio}} class="opacity-70">
                  None. No criterion applies to this issue — neither its boards nor the project
                  they belong to declared one. <strong>Declare one</strong>
                  on the project or the board.
                </span>
                <span :if={match?({:missing, {:evento_nao_coletado, _}}, @inicio)} class="opacity-70">
                  None. The declared criterion is
                  <span class="badge badge-outline badge-sm font-mono">
                    {@inicio |> elem(1) |> elem(1)}
                  </span>
                  and no such event was ever observed on this issue. Either it genuinely never
                  happened, or the collection has not brought it yet.
                </span>
                <span :if={match?({:missing, {:criterio_ambiguo, _}}, @inicio)} class="opacity-70">
                  None. This issue sits on two boards linked to the project <strong>at the same instant</strong>, and both declared a criterion. The
                  platform <strong>does not pick one</strong> — unlink one of them:
                </span>
              </p>

              <%!-- FR-013: a origem é clicável, e leva a quem declarou. Um instante sem origem
                    não pode ser contestado por quem discorda dele. --%>
              <p :if={match?({:ok, _, _, _}, @inicio)} class="text-xs opacity-70">
                Criterion declared by
                <.link
                  :if={match?({:board, _, _}, elem(@inicio, 2))}
                  navigate={~p"/boards/#{@inicio |> elem(2) |> elem(1)}"}
                  class="link"
                >
                  board {@inicio |> elem(2) |> elem(2)}
                </.link>
                <.link
                  :if={match?({:project, _, _}, elem(@inicio, 2))}
                  navigate={~p"/projects"}
                  class="link"
                >
                  project {@inicio |> elem(2) |> elem(2)}
                </.link>
                — the board wins over the project, and only when it declared one of its own.
              </p>

              <ul :if={match?({:missing, {:criterio_ambiguo, _}}, @inicio)} class="text-xs">
                <li :for={q <- @inicio |> elem(1) |> elem(1)} class="font-mono">
                  {q.title} · linked {q.linked_at}
                </li>
              </ul>
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
                Timeline <span class="opacity-60">{length(@timeline)}</span>
              </h3>
              <p class="text-xs text-base-content/70">
                What happened, in the order it happened. The type is recorded as the source names
                it — never translated.
              </p>

              <p :if={@timeline == []} class="text-sm opacity-70">
                No activity collected for this issue yet. That is not the same as nothing having
                happened.
              </p>

              <ol class="mt-1 space-y-2 text-sm">
                <li :for={a <- @timeline}>
                  <span class="font-mono text-xs">{a.activity_type}</span>
                  <span :if={is_nil(a.concept_id)} class="badge badge-xs badge-ghost ml-1">
                    unnamed by the network
                  </span>
                  <div class="text-xs opacity-70">
                    {data(a.occurred_at)} · <span :if={a.performer_login}>{a.performer_login}</span>
                    <%!-- Um evento sem executor humano é EXIBIDO dizendo isso, e nunca
                          omitido: 160 das 357 movimentações medidas são de automação, e
                          escondê-las contaria uma história falsa da issue. --%>
                    <span :if={is_nil(a.performer_id) && a.performer_login} class="opacity-60">
                      · not a known person
                    </span>
                    <span :if={is_nil(a.performer_login)} class="opacity-60">
                      no human performer
                    </span>
                  </div>
                  <div :if={movimentacao?(a)} class="text-xs opacity-70">
                    {estado_anterior(a)} → <span class="font-medium">{a.payload["status"]}</span>
                  </div>
                </li>
              </ol>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">Process</h3>
              <p class="text-xs text-base-content/70">
                <%!-- A frase existe porque um achado sem ela lê como acusação. O que falta
                      é o rastro, e quem fez a tarefa fez a tarefa. --%>
                These are not judgements about people. They say the record of the process is
                incomplete — and the cost is that the organisation loses the measurement.
              </p>

              <p :if={@antipadroes == :nao_olhei} class="text-sm opacity-70">
                <%!-- "Nenhum encontrado" e "não olhei" são frases diferentes, e usar a
                      primeira para a segunda é o defeito que a L57 descreve. --%>
                No board movement has been collected for this issue, so nothing was evaluated.
                This is not the same as finding nothing.
              </p>

              <p :if={@antipadroes == []} class="text-sm opacity-70">
                Nothing found. The issue was assigned, moved by a person, and the sequence holds
                together.
              </p>

              <ul :if={is_list(@antipadroes) and @antipadroes != []} class="space-y-2 text-sm">
                <li :for={a <- @antipadroes}>
                  <span class="font-medium">{titulo_do_antipadrao(a.id)}</span>
                  <div class="text-xs opacity-70">
                    <span class="font-mono">{a.id}</span> · {a.evidence}
                  </div>
                </li>
              </ul>
            </div>
          </div>

          <%!-- A LINHA DO TEMPO — issue, solicitações e commits no mesmo eixo.
                Nenhuma marca é interpolada: cada uma é um instante que a origem
                entregou. O que a lista não responde e esta seção responde é QUANTO
                TEMPO — e onde o trabalho parou. --%>
          <div :if={@linha_do_tempo.solicitacoes != []} class="card bg-base-200">
            <div class="card-body gap-2 p-4">
              <h3 class="card-title text-base">How long it took</h3>
              <p class="text-xs text-base-content/70">
                The issue, the change requests that attend it, and their commits on one axis —
                each mark is an instant the source recorded, never interpolated between them.
              </p>

              <div class="mt-1 space-y-3">
                <div>
                  <div class="flex flex-wrap items-baseline gap-2 text-sm">
                    <span class="font-mono text-xs opacity-60 uppercase">issue</span>
                    <span class="font-medium">#{@issue.number}</span>
                    <span class="text-xs opacity-60">
                      {duracao_em_texto(@issue.external_created_at, @issue.external_closed_at)}
                    </span>
                  </div>
                  <div class="relative mt-1 h-3 rounded-sm bg-base-300">
                    <div
                      class="absolute inset-y-0 rounded-sm bg-primary"
                      style={
                        faixa(@linha_do_tempo, @issue.external_created_at, @issue.external_closed_at)
                      }
                    >
                    </div>
                  </div>
                </div>

                <div :for={s <- @linha_do_tempo.solicitacoes}>
                  <div class="flex flex-wrap items-baseline gap-2 text-sm">
                    <span class="font-mono text-xs opacity-60 uppercase">request</span>
                    <.link navigate={~p"/work/changes/#{s.id}"} class="link link-hover font-medium">
                      #{s.number}
                    </.link>
                    <span class="text-xs opacity-60">
                      {duracao_em_texto(s.created_at, s.merged_at)}
                    </span>
                  </div>
                  <div class="relative mt-1 h-3 rounded-sm bg-base-300">
                    <div
                      class={[
                        "absolute inset-y-0 rounded-sm",
                        if(s.merged_at,
                          do: "bg-primary",
                          else: "border-2 border-dashed border-primary"
                        )
                      ]}
                      style={faixa(@linha_do_tempo, s.created_at, s.merged_at)}
                    >
                    </div>
                    <%!-- Cada commit é um ponto no eixo. Fora do intervalo da solicitação
                          acontece (cherry-pick, rebase) e aparece fora — alinhar seria
                          desenhar bonito às custas do fato. --%>
                    <span
                      :for={c <- commits_da(@linha_do_tempo, s.id)}
                      class="absolute top-1/2 size-2 -translate-y-1/2 rounded-full bg-primary outline-2 outline-base-200"
                      style={ponto(@linha_do_tempo, c.committed_at)}
                      title={"#{String.slice(c.sha, 0, 8)} · #{c.headline}"}
                    ></span>
                  </div>
                </div>
              </div>

              <%!-- O VÃO é a leitura: o tempo entre a issue abrir e a primeira mudança
                    aparecer não tem registro nenhum, e é o que a lista esconde. --%>
              <p :if={@linha_do_tempo.vao_ate_primeira} class="mt-1 text-xs text-base-content/70">
                <strong>{vao_em_texto(@linha_do_tempo.vao_ate_primeira)}</strong>
                between the issue being opened and the first change request — no change is
                recorded in that stretch.
              </p>
            </div>
          </div>

          <%!-- AS SOLICITAÇÕES DE MUDANÇA que atendem esta issue — cmpo.change_request.
                O vínculo é o que a ORIGEM reconheceu das closing keywords; menção no
                texto não entra, porque mencionar e atender são coisas diferentes. --%>
          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4">
              <h3 class="card-title text-base">Change requests</h3>
              <p class="text-xs text-base-content/70">
                The pull requests the source recognised as closing this issue — who asked
                for the change, and who integrated it.
              </p>

              <p :if={not @mudancas_coletadas?} class="text-sm opacity-70">
                No change request has been collected for this repository yet. This is not
                the same as no pull request attending this issue.
              </p>

              <p :if={@mudancas_coletadas? and @mudancas == []} class="text-sm opacity-70">
                Collected, and no change request closes this issue. Work may still exist —
                a closing keyword the source did not recognise looks exactly like this.
              </p>

              <div :for={m <- @mudancas} class="border-t border-base-300 pt-2 text-sm">
                <.link navigate={~p"/work/changes/#{m.id}"} class="link link-hover font-medium">
                  #{m.number} {m.title}
                </.link>
                <div class="mt-0.5 flex flex-wrap items-baseline gap-x-3 text-xs opacity-70">
                  <span class="badge badge-ghost badge-xs">{String.downcase(m.state || "")}</span>
                  <span>
                    opened by
                    <.link
                      :if={m.author_person_id}
                      navigate={~p"/people/#{m.author_person_id}"}
                      class="link link-hover"
                    >
                      {@nomes[m.author_person_id] || m.author_login}
                    </.link>
                    <span :if={is_nil(m.author_person_id)}>{m.author_login || "unknown"}</span>
                  </span>
                  <span :if={m.merged_by_login}>
                    integrated by
                    <.link
                      :if={m.merged_by_person_id}
                      navigate={~p"/people/#{m.merged_by_person_id}"}
                      class="link link-hover"
                    >
                      {@nomes[m.merged_by_person_id] || m.merged_by_login}
                    </.link>
                    <span :if={is_nil(m.merged_by_person_id)}>{m.merged_by_login}</span>
                  </span>
                </div>
              </div>
            </div>
          </div>

          <%!-- A DISCUSSÃO — cmo.comment, observado na origem.
                Os dois vazios são frases diferentes de propósito: "não coletada" e
                "coletada e vazia" dizem coisas opostas sobre a origem, e usar a mesma
                para as duas é o defeito da L57. --%>
          <div class="card bg-base-200">
            <div class="card-body gap-3 p-4">
              <h3 class="card-title text-base">Discussion</h3>
              <p class="text-xs text-base-content/70">
                What was said on the issue at the source, in order — observed, never derived.
                The work that happens in the conversation and never becomes a task lives here.
              </p>

              <p :if={not @discussao_coletada?} class="text-sm opacity-70">
                No discussion has been collected for this repository yet. This is not the same
                as the issue having no comments.
              </p>

              <p :if={@discussao_coletada? and @discussao == []} class="text-sm opacity-70">
                Collected, and this issue has no comments.
              </p>

              <ol :if={@discussao != []} class="space-y-3">
                <li :for={c <- @discussao} class="border-t border-base-300 pt-2 first:border-0">
                  <div class="flex flex-wrap items-baseline gap-x-2 text-sm">
                    <.link
                      :if={c.author_person_id}
                      navigate={~p"/people/#{c.author_person_id}"}
                      class="link link-hover font-medium"
                    >
                      {@nomes[c.author_person_id] || c.author_login}
                    </.link>
                    <span :if={is_nil(c.author_person_id)} class="font-medium">
                      {c.author_login || "author no longer at the source"}
                      <span class="text-xs font-normal opacity-60">(person not collected)</span>
                    </span>
                    <span class="text-xs opacity-60 tabular-nums">{c.published_at}</span>
                    <span :if={c.edited_at} class="text-xs opacity-60">edited</span>
                  </div>
                  <p class="mt-0.5 text-sm whitespace-pre-line text-base-content/80">{c.body}</p>
                </li>
              </ol>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4 sm:p-5">
              <h3 class="font-semibold">Cycle time</h3>
              <%!-- A tela NÃO mostra lead time aqui. São medidas diferentes — lead time
                    inclui o tempo em que ninguém tocou na issue —, e trocá-las em
                    silêncio faria alguém decidir sobre um número que responde outra
                    pergunta (FR-009). --%>
              <p class="text-sm">
                <span class="font-medium">Not available.</span> {falta(@cycle_time)}
              </p>
              <p class="text-xs text-base-content/70">
                {como_resolver(@cycle_time)}
              </p>
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

  # `:nao_olhei` sobrevive até a tela, e não vira lista vazia no caminho: achatá-lo aqui
  # faria "não coletei movimentação" aparecer como "nada encontrado", que é o defeito que
  # a própria detecção existe para não cometer.
  defp antipadroes(issue, atividades) do
    case Antipatterns.evaluate(issue, atividades) do
      {:ok, achados} -> achados
      {:nao_olhei, _motivo} -> :nao_olhei
    end
  end

  defp titulo_do_antipadrao("process.ap01.closed_without_movement"),
    do: "Closed without ever being moved"

  defp titulo_do_antipadrao("process.ap02.moved_after_closing"),
    do: "Moved after it was closed"

  defp titulo_do_antipadrao("process.ap03.assigned_and_never_started"),
    do: "Assigned and never started"

  defp titulo_do_antipadrao("process.ap04.movement_without_assignee"),
    do: "Moved with nobody assigned"

  defp movimentacao?(%{activity_type: "ProjectV2ItemStatusChangedEvent"}), do: true
  defp movimentacao?(_atividade), do: false

  # `previousStatus` vem VAZIO na primeira transição, e não nulo — medido em 2026-08-14.
  # Os dois casos dizem a mesma coisa aqui: o cartão não estava em estado nenhum. Escrever
  # isso é melhor que mostrar uma seta saindo do nada.
  defp estado_anterior(%{payload: %{"previousStatus" => anterior}})
       when is_binary(anterior) and anterior != "",
       do: anterior

  defp estado_anterior(_atividade), do: "no state"

  # As três causas não se resolvem no mesmo lugar, e a tela diz qual é qual. Achatá-las
  # numa frase só faria alguém tentar declarar uma regra para um quadro que não tem
  # estado onde declará-la.
  defp falta({:error, :no_movement_collected}),
    do: "No board movement has been collected for this issue."

  defp falta({:error, :no_state_means_in_progress}),
    do: "This board has no state that means work in progress."

  defp falta({:error, :issue_never_reached_in_progress}),
    do: "This issue never reached a state that means work in progress."

  defp falta({:error, :no_start_rule_declared}),
    do: "Nobody has declared which movement marks the start of work."

  defp como_resolver({:error, :no_movement_collected}),
    do:
      "This is not the same as a healthy process — it means the platform has not looked. " <>
        "Collect the timeline for this repository."

  defp como_resolver({:error, :no_state_means_in_progress}),
    do:
      "This is a structural anti-pattern (process.ap05), and it makes cycle time impossible " <>
        "for every issue on this board — not just this one. It is fixed on the board, by " <>
        "adding a state that means work in progress, and only for issues moved after that."

  defp como_resolver({:error, :issue_never_reached_in_progress}),
    do:
      "The board does have such a state, so this is about this issue and not about the board: " <>
        "it went from waiting straight to finished, and no instant marks when the work began."

  defp como_resolver({:error, :no_start_rule_declared}),
    do:
      "The platform will not choose on its own: picking one would produce a plausible and " <>
        "wrong number that nobody would question. Lead time is not shown in its place — it " <>
        "answers a different question."

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
    atividades = SPO.list_activities(tenant, "issue", issue.id)
    # Os estados do QUADRO, e não os desta issue: a condição do `ap05` é sobre o quadro,
    # e avaliá-la com as movimentações de uma issue afirmaria que o quadro não tem estado
    # de andamento sempre que a issue não passou por um.
    estados_do_quadro = SPO.count_board_states(tenant)
    pai = WorkItems.fetch_parent(tenant, issue.id)
    repositorio = repositorio(tenant, issue.observed_repository_id)
    discussao = Discussions.for_issue(tenant, issue.id)
    mudancas = Changes.for_issue(tenant, issue.id)
    nomes = nomes(tenant, issue, discussao, mudancas)
    inicio = Map.get(SPO.resolve_start(tenant, [issue.id]), issue.id)

    # **As quatro listas, uma vez cada.** `partes_faltando/2` as consultava de novo para contar —
    # três consultas repetidas por render, e a quarta lista teria virado a sétima. Contar o que já
    # está em memória responde a mesma pergunta sem voltar ao banco.
    composicao = WorkItems.list_composition(tenant, issue.id)
    atendimento = WorkItems.list_attendance(tenant, issue.id)
    sem_promocao = WorkItems.list_unpromoted_parts(tenant, issue.id)
    relacao_sem_nome = WorkItems.list_unnamed_relation_parts(tenant, issue.id)

    presentes =
      length(composicao) + length(atendimento) + length(sem_promocao) +
        length(relacao_sem_nome)

    socket
    |> assign(
      issue: issue,
      pai: pai,
      # Feature 042: o instante de início desta issue, resolvido pela escala — e a origem
      # junto, porque a `FR-013` proíbe o número aparecer sozinho.
      inicio: inicio,
      # A verificação do axioma é a **mesma função** que a tela do repositório usa em
      # lote. Dois caminhos discordariam, e uma tela avisaria o que a outra nega.
      violacao: violacao(issue, pai),
      composicao: composicao,
      atendimento: atendimento,
      sem_promocao: sem_promocao,
      relacao_sem_nome: relacao_sem_nome,
      recusados: WorkItems.list_refused_for(tenant, issue.id),
      historico: WorkItems.promotion_history(tenant, issue.id),
      partes_faltando: max(issue.sub_issue_count - presentes, 0),
      nomes: nomes,
      autor_nome: nomes[issue.author_person_id],
      # **Uma consulta, três respostas.** A sequência, o cycle time e a detecção de
      # antipadrão saem todos desta lista; carregá-la por consumidor fazia o render subir
      # de 39 para 48 consultas, e o teste-guarda da feature 007 pegou.
      timeline: atividades,
      cycle_time: SPO.cycle_time(atividades, estados_do_quadro),
      antipadroes: antipadroes(issue, atividades),
      # A discussão (cmo.discussion): os comentários coletados desta issue. `coletada?`
      # separa os dois vazios — "não passou a coleta" e "passou e não há conversa" são
      # fatos diferentes, e usar a mesma frase para os dois é o defeito da L57.
      discussao: discussao,
      discussao_coletada?: discussao_coletada?(repositorio),
      # As solicitações que atendem esta issue — o rastro do escopo para a mudança.
      mudancas: mudancas,
      # A linha do tempo: issue, solicitações e commits no mesmo eixo. Só é montada
      # quando há solicitação — sem ela não há linha, e a seção diz isso.
      linha_do_tempo: Changes.timeline_of_issue(tenant, issue, mudancas),
      mudancas_coletadas?: mudancas_coletadas?(repositorio)
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

  # `comments_collected_at` do repositório observado é o que distingue os dois vazios.
  # Repositório que deixou de ser observado (nil) conta como não coletado: a issue
  # continua consultável, mas nada se afirma sobre a conversa dela.
  defp discussao_coletada?(nil), do: false
  defp discussao_coletada?(repositorio), do: not is_nil(repositorio.comments_collected_at)

  # A posição no eixo é proporcional ao intervalo total observado. Sem `ate` (nada
  # fechado ainda) a faixa vai até o fim: o trabalho segue aberto, e é isso que se vê.
  defp faixa(%{de: nil}, _inicio, _fim), do: "left: 0; right: 0;"

  defp faixa(linha, inicio, fim) do
    total = max(DateTime.diff(linha.ate, linha.de, :second), 1)
    esquerda = posicao(linha, inicio, total)
    direita = if fim, do: posicao(linha, fim, total), else: 100.0

    "left: #{esquerda}%; width: #{max(direita - esquerda, 0.8)}%;"
  end

  defp ponto(%{de: nil}, _quando), do: "left: 0;"

  defp ponto(linha, quando) do
    total = max(DateTime.diff(linha.ate, linha.de, :second), 1)
    "left: calc(#{posicao(linha, quando, total)}% - 4px);"
  end

  defp posicao(_linha, nil, _total), do: 0.0

  defp posicao(linha, instante, total) do
    instante =
      if match?(%NaiveDateTime{}, instante),
        do: DateTime.from_naive!(instante, "Etc/UTC"),
        else: instante

    Float.round(DateTime.diff(instante, linha.de, :second) / total * 100, 2)
  end

  defp commits_da(linha, solicitacao_id),
    do: Enum.filter(linha.commits, &(&1.change_request_id == solicitacao_id))

  defp duracao_em_texto(nil, _fim), do: ""

  defp duracao_em_texto(inicio, nil) do
    inicio =
      if match?(%NaiveDateTime{}, inicio),
        do: DateTime.from_naive!(inicio, "Etc/UTC"),
        else: inicio

    "open for #{vao_em_texto(DateTime.diff(DateTime.utc_now(:second), inicio, :second))}"
  end

  defp duracao_em_texto(inicio, fim) do
    inicio =
      if match?(%NaiveDateTime{}, inicio),
        do: DateTime.from_naive!(inicio, "Etc/UTC"),
        else: inicio

    fim = if match?(%NaiveDateTime{}, fim), do: DateTime.from_naive!(fim, "Etc/UTC"), else: fim
    vao_em_texto(DateTime.diff(fim, inicio, :second))
  end

  # Segundos viram a maior unidade que ainda diz algo — "4 dias" informa, "351.847
  # segundos" faz quem lê dividir de cabeça.
  defp vao_em_texto(segundos) when segundos < 3600, do: "#{div(segundos, 60)} min"
  defp vao_em_texto(segundos) when segundos < 86_400, do: "#{div(segundos, 3600)} h"
  defp vao_em_texto(segundos), do: "#{div(segundos, 86_400)} d"

  defp mudancas_coletadas?(nil), do: false
  defp mudancas_coletadas?(repositorio), do: not is_nil(repositorio.changes_collected_at)

  defp violacao(issue, pai) do
    case WorkItems.rule07(issue.derived_concept, pai && pai.derived_concept) do
      :ok -> nil
      {:violation, forma} -> forma
    end
  end

  # O nome da pessoa vem pela API pública de EO: `WorkItems` guarda a **referência** e
  # não alcança `eo_people`. É a regra da fronteira do princípio IX em leitura.
  # Os autores da discussão entram na MESMA consulta de nomes: uma por render, e não uma
  # por comentário — sem isto, o nome de quem comentou cairia para o login (a tela
  # mostraria duas grafias da mesma pessoa em lugares diferentes).
  defp nomes(tenant, issue, discussao, mudancas) do
    ids =
      [issue.author_person_id | Enum.map(issue.assignees, & &1.person_id)]
      |> Kernel.++(Enum.map(discussao, & &1.author_person_id))
      |> Kernel.++(Enum.flat_map(mudancas, &[&1.author_person_id, &1.merged_by_person_id]))
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
