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
     |> put_flash_component(:info, "#{length(criadas)} regras ativadas, com você como autora.")
     |> carregar()}
  end

  def handle_event("desativar", %{"id" => id}, socket) do
    %{tenant: tenant, actor_id: actor} = socket.assigns
    {:ok, _} = Mapping.deactivate_rule(tenant, id, actor)

    {:noreply,
     socket
     |> put_flash_component(:info, "Regra desativada. Ela continua consultável.")
     |> carregar()}
  end

  def handle_event("nao_e_tipo", %{"padrao" => padrao}, socket) do
    %{tenant: tenant, organization_id: org, actor_id: actor} = socket.assigns
    {:ok, _} = Mapping.declare_not_a_type(tenant, org, padrao, actor)

    {:noreply,
     socket
     |> put_flash_component(:info, "#{padrao} registrado como não sendo tipo.")
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
         |> put_flash_component(:info, "Regra criada. O recálculo foi enfileirado.")
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
        Regras de mapeamento · {@organization_login}
        <:subtitle>
          O que esta organização declarou que cada texto da origem significa.
        </:subtitle>
        <:actions>
          <.button phx-click="fechar_mapeamento" class="btn-ghost btn-sm">fechar</.button>
        </:actions>
      </.header>

      <div :if={@erro} class="alert alert-error mt-4 block">
        <div class="font-semibold">A regra não foi aceita.</div>
        <p class="text-sm">{@erro}</p>
      </div>

      <div class="alert mt-4 block">
        <div class="font-semibold">
          {@lacuna.sem_conceito} de {@lacuna.total} issues ainda sem conceito
        </div>
        <p class="text-sm opacity-80">
          {@lacuna.promovidas} promovidas. Enquanto uma issue não tem conceito, ela não entra
          em nenhuma medida — e o produto não sabe o que ela é.
        </p>
        <div :if={@lacuna.tipos != []} class="text-sm mt-1">
          tipos declarados sem rota:
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
                Propostas do catálogo
                <span class="opacity-60">{Enum.count(@propostas, &(&1.state == :proposed))}</span>
              </h3>
              <.button
                :if={Enum.any?(@propostas, &(&1.state == :proposed))}
                phx-click="ativar_todas"
                phx-target={@myself}
                class="btn-sm btn-primary"
              >
                ativar todas
              </.button>
            </div>
            <p class="text-xs opacity-70">
              Chegam <strong>propostas</strong>, nunca ativas: ativá-las por padrão promoveria
              milhares de issues sem ninguém decidir. O catálogo economiza a escrita, não a
              decisão.
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
                    <span :if={p.would_match == 0} class="opacity-50">n/a aqui</span>
                  </td>
                  <td class="text-right">
                    <span :if={p.state == :activated} class="badge badge-xs">ativada</span>
                    <span :if={p.state == :edited} class="badge badge-xs badge-warning">
                      editada
                    </span>
                    <.button
                      :if={p.state == :proposed}
                      phx-click="ativar"
                      phx-value-chave={p.catalog_key}
                      phx-target={@myself}
                      class="btn-xs btn-outline"
                    >
                      ativar
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
              Não são tipo <span class="opacity-60">{length(@nao_tipo)}</span>
            </h3>
            <%!-- Lista SEPARADA, e é o ponto: aqui a ação proposta é recusar, não mapear. --%>
            <p class="text-xs opacity-70">
              Estes prefixos dizem <strong>quem faz</strong> ou <strong>em que área</strong>,
              não o que a issue é. Mapeá-los como tipo produziria registros com conceito
              errado — e conceito errado é pior que conceito ausente: a medida passa a existir
              e a mentir.
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
                      não é tipo
                    </.button>
                  </td>
                </tr>
              </tbody>
            </table>

            <div :if={@declarados != []} class="mt-3">
              <h4 class="text-sm font-semibold">Já declarados</h4>
              <ul class="text-sm space-y-1 mt-1">
                <li :for={d <- @declarados} class="flex items-center justify-between">
                  <span class="font-mono text-xs">{d.pattern}</span>
                  <.button
                    phx-click="reverter"
                    phx-value-id={d.id}
                    phx-target={@myself}
                    class="btn-xs btn-ghost"
                  >
                    reverter
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
            Regras vigentes <span class="opacity-60">{length(@regras)}</span>
          </h3>
          <p :if={@regras == []} class="text-sm opacity-70">
            Nenhuma regra declarada. Ative uma proposta acima, ou escreva a sua.
          </p>
          <p :if={@regras != []} class="text-xs opacity-70">
            Na ordem em que são aplicadas. A primeira que casa decide — e a ordem é visível
            justamente para que acrescentar regra não mude a classificação em silêncio.
          </p>

          <table :if={@regras != []} class="table table-sm">
            <thead>
              <tr>
                <th>#</th>
                <th>onde</th>
                <th>como</th>
                <th>texto</th>
                <th>promove a</th>
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
                  <span :if={!r.active} class="badge badge-xs">desativada</span>
                  <.button
                    :if={r.active}
                    phx-click="desativar"
                    phx-value-id={r.id}
                    phx-target={@myself}
                    class="btn-xs btn-ghost"
                  >
                    desativar
                  </.button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="mt-6 card bg-base-200">
        <div class="card-body">
          <h3 class="font-semibold">Nova regra</h3>
          <form id="nova-regra" phx-change="prever" phx-submit="criar" phx-target={@myself}>
            <div class="grid gap-3 sm:grid-cols-5">
              <select name="regra[where]" class="select select-sm select-bordered">
                <option value="declared_type">no tipo declarado</option>
                <option value="title">no título</option>
              </select>
              <select name="regra[how]" class="select select-sm select-bordered">
                <option value="equals">igual a</option>
                <option value="starts_with">começa com</option>
                <option value="contains">contém</option>
                <option value="regex">expressão regular</option>
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
                criar regra
              </.button>
            </div>
          </form>

          <%!-- A prévia mostra DOIS números, e eles são diferentes: casar 900 e mudar 900
                é muito diferente de casar 900 e mudar 3. Mostrar só o primeiro esconderia
                o caso perigoso. --%>
          <div :if={@previa} class="alert mt-3 block">
            <div class="font-semibold">
              {@previa.matched} issues casam · {@previa.would_change} mudariam de conceito
            </div>
            <p :if={@previa.would_change == 0} class="text-sm opacity-80">
              Nenhuma issue mudaria de conceito. A regra é válida e não faria diferença
              agora — o que é diferente de estar errada.
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

  defp ativada, do: "Regra ativada, com você como autora. O recálculo foi enfileirado."

  defp onde("declared_type"), do: "tipo declarado"
  defp onde("title"), do: "título"
  defp onde(outro), do: outro

  defp como("equals"), do: "igual a"
  defp como("starts_with"), do: "começa com"
  defp como("contains"), do: "contém"
  defp como("regex"), do: "expressão regular"
  defp como(outro), do: outro

  defp humanizar({:invalid_pattern, motivo}), do: Mapping.explain_refusal(motivo)

  defp humanizar({:unknown_concept, id}),
    do: "o conceito #{id} não existe na base de conhecimento"

  defp humanizar(:unknown_entry), do: "esta proposta não existe mais no catálogo"

  defp humanizar(%Ecto.Changeset{} = changeset) do
    changeset.errors
    |> Enum.map_join("; ", fn {campo, {mensagem, _}} -> "#{campo}: #{mensagem}" end)
  end
end
