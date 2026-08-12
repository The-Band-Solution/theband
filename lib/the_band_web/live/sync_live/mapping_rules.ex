defmodule TheBandWeb.SyncLive.MappingRules do
  @moduledoc """
  As regras de mapeamento de uma organização — componente da tela de sincronização.

  ## Por que aqui, e não em página própria

  A lacuna **nasce da coleta**. Quem acabou de sincronizar e viu "3406 não promovidas" está
  a um clique de resolver; uma página separada obrigaria a lembrar que ela existe e a
  escolher a organização de novo. Decisão da pessoa mantenedora — FR-050, FR-052.

  ## A tensão com o princípio X, e como se resolve

  A tela de sincronização responde *"a coleta está funcionando"*; as regras respondem *"o
  que a plataforma entende"*. São duas perguntas, e o princípio X diz que uma tela mostra
  uma coisa.

  A resolução não é ignorar o princípio: é **componente com responsabilidade única e
  cabeçalho próprio**, alcançado a partir da organização. A tela hospeda; a hospedagem fica
  visivelmente separada do relatório de execução — FR-051.

  Misturar as regras ao cartão da execução repetiria o erro do resumo de trabalho que
  apareceu dentro do cartão de cada sync: o número parecia da execução e era do tenant.

  ## O que NÃO é sugerido, e é o ponto

  `[Devops]` tem 340 issues, `[Back-end]` 256, `[QA]` 97 — prefixos que dizem **quem faz**
  ou **em que área**, não **o que é**. Eles aparecem numa lista **separada**, propondo a
  recusa. Sugerir regra para eles daria ao produto 340 user stories que são rótulos de
  equipe, e conceito errado é pior que conceito ausente: a medida passa a existir e a
  mentir.
  """

  use TheBandWeb, :live_component

  alias TheBand.Mapping
  alias TheBandWeb.ConceptLabel

  @impl true
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_new(:previa, fn -> nil end) |> carregar()}
  end

  @impl true
  def handle_event("ativar", %{"chave" => chave}, socket) do
    %{tenant: tenant, organization_id: org, actor_id: actor} = socket.assigns

    case Mapping.activate_catalog_rule(tenant, org, chave, actor) do
      {:ok, _regra} -> {:noreply, socket |> put_flash_component(:info, ativada()) |> carregar()}
      {:error, motivo} -> {:noreply, assign(socket, erro: humanizar(motivo))}
    end
  end

  def handle_event("ativar_todas", _params, socket) do
    %{tenant: tenant, organization_id: org, actor_id: actor} = socket.assigns
    {:ok, criadas} = Mapping.activate_all_proposals(tenant, org, actor)

    {:noreply,
     socket
     |> put_flash_component(:info, "#{length(criadas)} rules activated, with you as the author.")
     |> carregar()}
  end

  def handle_event("desativar", %{"id" => id}, socket) do
    %{tenant: tenant, actor_id: actor} = socket.assigns
    {:ok, _} = Mapping.deactivate_rule(tenant, id, actor)

    {:noreply,
     socket
     |> put_flash_component(:info, "Rule deactivated. It stays readable.")
     |> carregar()}
  end

  def handle_event("nao_e_tipo", %{"padrao" => padrao}, socket) do
    %{tenant: tenant, organization_id: org, actor_id: actor} = socket.assigns
    {:ok, _} = Mapping.declare_not_a_type(tenant, org, padrao, actor)

    {:noreply,
     socket
     |> put_flash_component(:info, "#{padrao} recorded as not being a type.")
     |> carregar()}
  end

  def handle_event("reverter", %{"id" => id}, socket) do
    %{tenant: tenant, actor_id: actor} = socket.assigns
    {:ok, _} = Mapping.revert_not_a_type(tenant, id, actor)
    {:noreply, carregar(socket)}
  end

  # A prévia usa a **mesma** função de decisão do recálculo. Prévia e efeito por caminhos
  # diferentes é o que faz alguém aprovar vendo 3 e reclassificar 900.
  def handle_event("prever", %{"regra" => params}, socket) do
    %{tenant: tenant, organization_id: org} = socket.assigns

    case Mapping.preview(tenant, org, atomizar(params)) do
      {:ok, previa} -> {:noreply, assign(socket, previa: previa, erro: nil, form: params)}
      {:error, motivo} -> {:noreply, assign(socket, previa: nil, erro: humanizar(motivo))}
    end
  end

  def handle_event("criar", %{"regra" => params}, socket) do
    %{tenant: tenant, organization_id: org, actor_id: actor} = socket.assigns

    case Mapping.create_rule(tenant, org, atomizar(params), actor) do
      {:ok, _regra} ->
        {:noreply,
         socket
         |> put_flash_component(:info, "Rule created. The recalculation is queued.")
         |> assign(previa: nil, erro: nil)
         |> carregar()}

      {:error, motivo} ->
        {:noreply, assign(socket, previa: nil, erro: humanizar(motivo))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mt-8 border-t-4 border-base-300 pt-6">
      <%!-- Cabeçalho próprio, e a separação é visível: o relatório de execução responde
            "a coleta está funcionando"; isto responde "o que a plataforma entende". --%>
      <.header>
        Mapping rules · {@organization_login}
        <:subtitle>
          What this organisation declares each source text to mean.
        </:subtitle>
        <:actions>
          <.button phx-click="fechar_mapeamento" class="btn-ghost btn-sm">Close</.button>
        </:actions>
      </.header>

      <div :if={@erro} class="alert alert-error mt-4 block">
        <div class="font-semibold">The rule was not accepted.</div>
        <p class="text-sm">{@erro}</p>
      </div>

      <div class="alert mt-4 block">
        <div class="font-semibold">
          {@lacuna.sem_conceito} of {@lacuna.total} issues still without a concept
        </div>
        <p class="text-sm opacity-80">
          {@lacuna.promovidas} promoted. While an issue has no concept it enters no measure —
          and the product does not know what it is.
        </p>
        <div :if={@lacuna.tipos != []} class="text-sm mt-1">
          declared types with no route:
          <span class="font-mono">
            {Enum.map_join(@lacuna.tipos, ", ", fn {t, n} -> "#{t} (#{n})" end)}
          </span>
        </div>
      </div>

      <div class="mt-6 grid gap-6 lg:grid-cols-2">
        <div class="card bg-base-200">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h3 class="font-semibold">
                Catalogue proposals
                <span class="opacity-60">{Enum.count(@propostas, &(&1.state == :proposed))}</span>
              </h3>
              <.button
                :if={Enum.any?(@propostas, &(&1.state == :proposed))}
                phx-click="ativar_todas"
                phx-target={@myself}
                class="btn-sm btn-primary"
              >
                Activate all
              </.button>
            </div>
            <p class="text-xs opacity-70">
              They arrive <strong>proposed</strong>, never active: activating them by default
              would promote thousands of issues with nobody deciding. The catalogue saves the
              writing, not the decision.
            </p>

            <table class="table table-sm mt-2">
              <tbody>
                <tr :for={p <- @propostas}>
                  <td class="font-mono text-xs">{p.pattern}</td>
                  <td class="text-xs opacity-70">{onde(p.where)}</td>
                  <td class="text-sm">{ConceptLabel.rotulo(p.target_concept)}</td>
                  <td class="text-right font-mono text-xs">
                    <span :if={p.would_match > 0}>{p.would_match}</span>
                    <%!-- Zero é "não aplicável a esta organização", e não erro: um catálogo
                          com 10 entradas mostraria 10 avisos numa organização que usa três
                          convenções. --%>
                    <span :if={p.would_match == 0} class="opacity-50">n/a here</span>
                  </td>
                  <td class="text-right">
                    <span :if={p.state == :activated} class="badge badge-xs">active</span>
                    <span :if={p.state == :edited} class="badge badge-xs badge-warning">
                      edited
                    </span>
                    <.button
                      :if={p.state == :proposed}
                      phx-click="ativar"
                      phx-value-chave={p.catalog_key}
                      phx-target={@myself}
                      class="btn-xs btn-outline"
                    >
                      Activate
                    </.button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="font-semibold">
              Not a type <span class="opacity-60">{length(@nao_tipo)}</span>
            </h3>
            <%!-- Lista SEPARADA, e é o ponto: aqui a ação proposta é recusar, não mapear. --%>
            <p class="text-xs opacity-70">
              These prefixes say <strong>who does it</strong> or <strong>in which area</strong>,
              not what the issue is. Mapping them as types would produce records with the wrong
              concept — and a wrong concept is worse than a missing one: the measure starts
              existing, and lying.
            </p>

            <table class="table table-sm mt-2">
              <tbody>
                <tr :for={p <- @nao_tipo}>
                  <td class="font-mono text-xs">{p.pattern}</td>
                  <td class="text-right font-mono text-xs">{p.would_match}</td>
                  <td class="text-right">
                    <.button
                      phx-click="nao_e_tipo"
                      phx-value-padrao={p.pattern}
                      phx-target={@myself}
                      class="btn-xs btn-outline"
                    >
                      Not a type
                    </.button>
                  </td>
                </tr>
              </tbody>
            </table>

            <div :if={@declarados != []} class="mt-3">
              <h4 class="text-sm font-semibold">Already declared</h4>
              <ul class="text-sm space-y-1 mt-1">
                <li :for={d <- @declarados} class="flex items-center justify-between">
                  <span class="font-mono text-xs">{d.pattern}</span>
                  <.button
                    phx-click="reverter"
                    phx-value-id={d.id}
                    phx-target={@myself}
                    class="btn-xs btn-ghost"
                  >
                    Revert
                  </.button>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-6 card bg-base-200">
        <div class="card-body">
          <h3 class="font-semibold">
            Active rules <span class="opacity-60">{length(@regras)}</span>
          </h3>
          <p :if={@regras == []} class="text-sm opacity-70">
            No rule declared. Activate a proposal above, or write your own.
          </p>
          <p :if={@regras != []} class="text-xs opacity-70">
            In the order they are applied. The first match decides — and the order is visible
            precisely so that adding a rule does not change the classification silently.
          </p>

          <table :if={@regras != []} class="table table-sm">
            <thead>
              <tr>
                <th class="text-right">#</th>
                <th>where</th>
                <th>how</th>
                <th>text</th>
                <th>promotes to</th>
                <th class="text-right">issues</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={r <- @regras} class={if(!r.active, do: "opacity-50")}>
                <td class="font-mono">{r.position}</td>
                <td class="text-xs">{onde(r.where)}</td>
                <td class="text-xs">{como(r.how)}</td>
                <td class="font-mono text-xs">{r.pattern}</td>
                <td class="text-sm">{ConceptLabel.rotulo(r.target_concept)}</td>
                <td class="text-right font-mono text-xs">{r.promoted_count}</td>
                <td class="text-right">
                  <span :if={!r.active} class="badge badge-xs">inactive</span>
                  <.button
                    :if={r.active}
                    phx-click="desativar"
                    phx-value-id={r.id}
                    phx-target={@myself}
                    class="btn-xs btn-ghost"
                  >
                    Deactivate
                  </.button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="mt-6 card bg-base-200">
        <div class="card-body">
          <h3 class="font-semibold">New rule</h3>
          <form id="nova-regra" phx-change="prever" phx-submit="criar" phx-target={@myself}>
            <div class="grid gap-3 sm:grid-cols-5">
              <select name="regra[where]" class="select select-sm select-bordered">
                <option value="declared_type">in the declared type</option>
                <option value="title">in the title</option>
              </select>
              <select name="regra[how]" class="select select-sm select-bordered">
                <option value="equals">equals</option>
                <option value="starts_with">starts with</option>
                <option value="contains">contains</option>
                <option value="regex">regular expression</option>
              </select>
              <input
                type="text"
                name="regra[pattern]"
                placeholder="[TASK]"
                class="input input-sm input-bordered font-mono"
              />
              <select name="regra[target_concept]" class="select select-sm select-bordered">
                <option :for={{id, rotulo} <- ConceptLabel.conceitos()} value={id}>{rotulo}</option>
              </select>
              <.button type="submit" class="btn-sm btn-primary" disabled={@previa == nil}>
                Create rule
              </.button>
            </div>
          </form>

          <%!-- A prévia mostra DOIS números, e eles são diferentes: casar 900 e mudar 900
                é muito diferente de casar 900 e mudar 3. Mostrar só o primeiro esconderia
                o caso perigoso. --%>
          <div :if={@previa} class="alert mt-3 block">
            <div class="font-semibold">
              {@previa.matched} issues match · {@previa.would_change} would change concept
            </div>
            <p :if={@previa.would_change == 0} class="text-sm opacity-80">
              No issue would change concept. The rule is valid and would make no difference
              right now — which is different from being wrong.
            </p>
            <ul :if={@previa.sample != []} class="text-xs opacity-80 mt-1 space-y-0.5">
              <li :for={titulo <- @previa.sample}>{titulo}</li>
            </ul>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp carregar(socket) do
    %{tenant: tenant, organization_id: org} = socket.assigns

    assign(socket,
      propostas: Mapping.list_proposals(tenant, org),
      nao_tipo: Enum.filter(Mapping.not_type_patterns(tenant, org), &(&1.would_match > 0)),
      declarados: Mapping.list_not_a_type(tenant, org),
      regras: Mapping.list_rules(tenant, org),
      lacuna: Mapping.gap_summary(tenant, org),
      erro: Map.get(socket.assigns, :erro)
    )
  end

  defp put_flash_component(socket, tipo, mensagem) do
    send(self(), {:mapping_flash, tipo, mensagem})
    socket
  end

  defp atomizar(params) do
    Map.new(params, fn
      {"case_sensitive", v} -> {:case_sensitive, v in ["true", "on", true]}
      {k, v} -> {String.to_existing_atom(k), v}
    end)
  end

  defp ativada, do: "Rule activated, with you as the author. The recalculation is queued."

  defp onde("declared_type"), do: "declared type"
  defp onde("title"), do: "title"
  defp onde(outro), do: outro

  defp como("equals"), do: "equals"
  defp como("starts_with"), do: "starts with"
  defp como("contains"), do: "contains"
  defp como("regex"), do: "regular expression"
  defp como(outro), do: outro

  defp humanizar({:invalid_pattern, motivo}), do: Mapping.explain_refusal(motivo)

  defp humanizar({:unknown_concept, id}),
    do: "concept #{id} does not exist in the knowledge base"

  defp humanizar(:unknown_entry), do: "this proposal no longer exists in the catalogue"

  defp humanizar(%Ecto.Changeset{} = changeset) do
    changeset.errors
    |> Enum.map_join("; ", fn {campo, {mensagem, _}} -> "#{campo}: #{mensagem}" end)
  end
end
