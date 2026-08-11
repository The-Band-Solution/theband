defmodule TheBandWeb.WorkItemLive.Show do
  @moduledoc """
  `/trabalho/issues/:id` — uma issue: o que a origem disse, e o que a plataforma decidiu.

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
        {:ok, socket |> assign(page_title: "##{issue.number}") |> carregar(issue)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Issue não encontrada.")
         |> push_navigate(to: ~p"/trabalho")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        <span class="font-mono opacity-60">#{@issue.number}</span> {@issue.title}
        <:subtitle>
          {@repositorio_nome} · {@organizacao} · {estado(@issue)}
        </:subtitle>
        <:actions>
          <.link navigate={~p"/trabalho/repositorios/#{@issue.observed_repository_id}"}>
            <.button class="btn-outline btn-sm">issues do repositório</.button>
          </.link>
          <a :if={@url_origem} href={@url_origem} target="_blank" rel="noopener">
            <.button class="btn-outline btn-sm">ver na origem</.button>
          </a>
        </:actions>
      </.header>

      <div :if={@issue.no_longer_observed_at} class="alert mt-6 block">
        <div class="font-semibold">Esta issue não apareceu na última coleta.</div>
        <p class="text-sm opacity-80">
          Marcada em {data(@issue.no_longer_observed_at)}. O registro permanece: ausência
          marca, nunca apaga.
        </p>
      </div>

      <%!-- A contagem que a origem declara **não** aparece ao lado das duas relações, e
            a razão é o SC-004: ela é exatamente a soma delas neste caso, e um leitor
            veria "39 partes" ao lado de 9 e 30 e concluiria que composição e atendimento
            são a mesma coisa contada duas vezes.

            O que aparece é o que a soma esconderia: parte declarada que a plataforma
            **não tem**. Essa é lacuna de coleta, e no caso normal não imprime nada. --%>
      <div :if={@partes_faltando > 0} class="alert alert-warning mt-6 block">
        <div class="font-semibold">A origem declara partes que a plataforma não tem.</div>
        <p class="text-sm">
          {@partes_faltando} de {@issue.sub_issue_count} não foram coletadas — parte em
          repositório fora do escopo observado, ou coleta que não a alcançou. As seções
          abaixo mostram só o que existe aqui.
        </p>
      </div>

      <%!-- O aviso do axioma vem antes de tudo, porque muda como se lê o resto. --%>
      <div :if={@violacao} class="alert alert-warning mt-6 block">
        <div class="font-semibold">Vínculo em desacordo com a ontologia.</div>
        <p class="text-sm">{WorkItems.rule07_explanation(@violacao)}</p>
      </div>

      <div class="mt-6 grid gap-6 lg:grid-cols-3">
        <div class="lg:col-span-2 space-y-6">
          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">Descrição</h3>
              <%!-- `nil` é "nunca coletado"; `""` é "a origem não tem corpo". Um texto
                    só para os dois faria alguém concluir que a issue está vazia quando
                    o que falta é reobservar. --%>
              <p :if={is_nil(@issue.body)} class="text-sm opacity-70">
                Corpo não coletado. Esta issue foi observada antes de a plataforma passar
                a pedir o corpo à origem, e o valor aparecerá na próxima coleta desta
                organização.
              </p>
              <p :if={@issue.body == ""} class="text-sm opacity-70">
                A issue não tem descrição na origem.
              </p>
              <p :if={@issue.body not in [nil, ""]} class="text-sm whitespace-pre-wrap">
                {@issue.body}
              </p>
            </div>
          </div>

          <%!-- Composição. Seção própria, com o nome da relação — FR-015. --%>
          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">
                Composição <span class="opacity-60">{length(@composicao)}</span>
              </h3>
              <p class="text-xs opacity-70">
                <span class="font-mono">sro.epic_composed_of_user_story</span> — as user
                stories que <strong>compõem</strong> esta issue.
              </p>
              <p :if={@composicao == []} class="text-sm opacity-70 mt-1">
                Nenhuma. {sem_composicao(@issue)}
              </p>
              <.lista_de_issues :if={@composicao != []} issues={@composicao} />
            </div>
          </div>

          <%!-- Atendimento. Outra seção, outra contagem, nunca somadas — FR-016. --%>
          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">
                Atendimento <span class="opacity-60">{length(@atendimento)}</span>
              </h3>
              <p class="text-xs opacity-70">
                <span class="font-mono">sro.intended_task_planned_to_meet_user_story</span>
                — as tarefas que <strong>atendem</strong>
                a esta issue. Elas não a compõem,
                e é por isso que esta contagem nunca é somada à de cima.
              </p>
              <p :if={@atendimento == []} class="text-sm opacity-70 mt-1">
                Nenhuma tarefa atende a esta issue.
              </p>
              <.lista_de_issues :if={@atendimento != []} issues={@atendimento} />
            </div>
          </div>

          <div :if={@sem_promocao != []} class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">
                Partes não promovidas <span class="opacity-60">{length(@sem_promocao)}</span>
              </h3>
              <p class="text-xs opacity-70">
                A origem declara a relação e a plataforma não decidiu o conceito destas
                partes. Elas estão coletadas: o que falta é regra de mapeamento.
              </p>
              <.lista_de_issues issues={@sem_promocao} />
            </div>
          </div>

          <div :if={@recusados != []} class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">
                Vínculos recusados <span class="opacity-60">{length(@recusados)}</span>
              </h3>
              <p class="text-xs opacity-70">
                Recusados na coleta, e registrados. As duas issues envolvidas continuam
                coletadas: recusa-se o vínculo, nunca a issue.
              </p>
              <ul class="text-sm mt-2 space-y-2">
                <li :for={r <- @recusados}>
                  {ConceptLabel.recusa(r.reason)}
                  <div :if={r.cycle_path} class="text-xs font-mono opacity-70">
                    {r.cycle_path}
                  </div>
                  <div :if={r.child_external_id} class="text-xs opacity-70">
                    parte fora do escopo: {r.child_external_id}
                  </div>
                </li>
              </ul>
            </div>
          </div>
        </div>

        <div class="space-y-6">
          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">Promoção</h3>
              <dl class="text-sm space-y-1">
                <.campo rotulo="conceito">
                  <span :if={@issue.derived_concept}>{ConceptLabel.rotulo(@issue.derived_concept)}</span>
                  <span :if={is_nil(@issue.derived_concept)} class="opacity-70">
                    não promovida — {ConceptLabel.motivo(@issue.skip_reason)}{if @issue.skip_detail,
                      do: ": #{@issue.skip_detail}"}
                  </span>
                </.campo>
                <.campo rotulo="classificação">
                  {classificacao(@issue)}
                </.campo>
                <.campo rotulo="tipo na origem">{@issue.issue_type || "—"}</.campo>
                <.campo rotulo="regra">
                  <span class="font-mono text-xs">{@issue.rule_id || "—"}</span>
                  <span :if={@issue.rule_version} class="opacity-60">v{@issue.rule_version}</span>
                </.campo>
                <.campo :if={@issue.divergence_reason} rotulo="divergência">
                  <span class="text-warning">{@issue.divergence_reason}</span>
                </.campo>
              </dl>
              <p :if={@issue.divergence_reason} class="text-xs opacity-70 mt-1">
                Não é erro da plataforma: a estrutura vence o rótulo, e a divergência é
                sinal sobre o processo do time.
              </p>
            </div>
          </div>

          <div :if={@pai} class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">{rotulo_do_pai(@issue)}</h3>
              <.link
                navigate={~p"/trabalho/issues/#{@pai.id}"}
                class="link link-hover text-sm"
              >
                <span class="font-mono">#{@pai.number}</span> {@pai.title}
              </.link>
              <div class="text-xs opacity-70">
                {ConceptLabel.rotulo(@pai.derived_concept) || "não promovida"}
              </div>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">Como a origem descreve</h3>
              <dl class="text-sm space-y-1">
                <.campo rotulo="autor">
                  {@autor_nome || @issue.author_login || "—"}
                  <span :if={@autor_nome && @issue.author_login} class="opacity-60 text-xs">
                    {@issue.author_login}
                  </span>
                  <%!-- Login sem pessoa ligada é declaração, não falha: a pessoa não
                        foi coletada, e criá-la a partir da issue produziria registro
                        sem proveniência. --%>
                  <div
                    :if={@issue.author_login && is_nil(@issue.author_person_id)}
                    class="text-xs opacity-60"
                  >
                    pessoa não coletada
                  </div>
                </.campo>
                <.campo rotulo="designados">
                  <span :if={@issue.assignees == []} class="opacity-70">ninguém designado</span>
                  <ul :if={@issue.assignees != []} class="space-y-0.5">
                    <li :for={a <- @issue.assignees}>
                      {@nomes[a.person_id] || a.login}
                      <span :if={is_nil(a.person_id)} class="text-xs opacity-60">
                        (pessoa não coletada)
                      </span>
                    </li>
                  </ul>
                </.campo>
                <.campo rotulo="rótulos">
                  <span :if={@issue.labels == []} class="opacity-70">nenhum</span>
                  <span :for={l <- @issue.labels} class="badge badge-xs badge-ghost mr-1">
                    {l.name}
                  </span>
                </.campo>
                <.campo rotulo="marco">{@issue.milestone_title || "fora de marco"}</.campo>
                <.campo rotulo="quadros">
                  {if @issue.project_titles == [],
                    do: "fora de quadro",
                    else: Enum.join(@issue.project_titles, ", ")}
                </.campo>
                <.campo rotulo="comentários">{@issue.comment_count}</.campo>
                <.campo rotulo="reações">{@issue.reaction_count}</.campo>
              </dl>
              <p class="text-xs opacity-60 mt-2">
                A contagem de comentários é coletada; o conteúdo não. Comentário é
                entidade própria, e coletá-lo multiplicaria o consumo da origem por issue.
              </p>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">Datas</h3>
              <dl class="text-sm space-y-1">
                <.campo rotulo="criada na origem">{data(@issue.external_created_at)}</.campo>
                <.campo rotulo="atualizada na origem">{data(@issue.external_updated_at)}</.campo>
                <.campo rotulo="fechada na origem">
                  {data(@issue.external_closed_at) || "aberta"}
                </.campo>
                <.campo rotulo="primeira coleta">{data(@issue.collected_at)}</.campo>
                <.campo rotulo="última observação">{data(@issue.last_observed_at)}</.campo>
              </dl>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body">
              <h3 class="font-semibold">
                Histórico de promoção <span class="opacity-60">{length(@historico)}</span>
              </h3>
              <p class="text-xs opacity-70">
                Append-only: cada decisão é uma linha, e a vigente é a última.
              </p>
              <ol class="text-sm mt-2 space-y-2">
                <li :for={h <- @historico}>
                  <span class="font-medium">
                    {ConceptLabel.rotulo(h.derived_concept) ||
                      "não promovida — #{ConceptLabel.motivo(h.skip_reason)}"}
                  </span>
                  <span :if={h.current} class="badge badge-xs badge-primary ml-1">vigente</span>
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

  attr :rotulo, :string, required: true
  slot :inner_block, required: true

  defp campo(assigns) do
    ~H"""
    <div class="flex justify-between gap-3">
      <dt class="opacity-60 shrink-0">{@rotulo}</dt>
      <dd class="text-right">{render_slot(@inner_block)}</dd>
    </div>
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
            <.link navigate={~p"/trabalho/issues/#{i.id}"} class="link link-hover">
              {i.title}
            </.link>
          </td>
          <td class="text-xs opacity-70 w-40">
            {ConceptLabel.rotulo(i.derived_concept) || ConceptLabel.motivo(i.skip_reason) || "—"}
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

  defp onde(_tenant, nil, _issue),
    do: %{repositorio_nome: "repositório não encontrado", organizacao: "—", url_origem: nil}

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
    do: "fechada#{motivo_do_fechamento(issue.state_reason)}"

  defp estado(%{state: estado}), do: String.downcase(estado)

  # `COMPLETED` e `NOT_PLANNED` são fechamentos diferentes, e a diferença é do time.
  defp motivo_do_fechamento("COMPLETED"), do: " · concluída"
  defp motivo_do_fechamento("NOT_PLANNED"), do: " · não planejada"
  defp motivo_do_fechamento(nil), do: ""
  defp motivo_do_fechamento(outro), do: " · #{String.downcase(outro)}"

  defp classificacao(%{classification: :epic}), do: "épico — tem partes que são user stories"

  defp classificacao(%{classification: :atomic_user_story}),
    do: "atômica — nenhuma parte é user story"

  # Ausência de decomposição é declarada, e o texto muda com o conceito: um épico sem
  # partes é sinal; uma tarefa sem partes é o normal.
  defp sem_composicao(%{derived_concept: "sro.epic"}),
    do: "Um épico sem partes coletadas é sinal de decomposição que não chegou à origem."

  defp sem_composicao(%{sub_issue_count: n}) when n > 0,
    do: "A origem declara #{n} partes, e nenhuma foi promovida a user story."

  defp sem_composicao(_), do: "A origem não declara partes."

  defp rotulo_do_pai(%{derived_concept: "sro.intended_scrum_development_task"}),
    do: "Atende a"

  defp rotulo_do_pai(_), do: "Faz parte de"

  defp data(nil), do: nil
  defp data(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
end
