defmodule TheBandWeb.PeopleLive.Show do
  @moduledoc """
  `/people/:id` — o que a plataforma sabe sobre uma pessoa.

  ## A tela mostra três coisas onde uma tela comum mostraria uma

  Medido em 2026-08-12: **88 evidências** de vínculo pessoa-equipe e **zero** vínculos
  materializados, porque o vínculo da ontologia exige papel e nenhum papel foi cadastrado.

  | esconder | produziria |
  |---|---|
  | a evidência | 75 pessoas sem equipe nenhuma, o que é falso |
  | a não promoção | a tela afirmando um vínculo que a plataforma recusou |
  | o motivo | a recusa parecendo defeito da plataforma |

  ## Designação e autoria nunca somam

  São 4 232 designações e 4 241 autorias no dado real, e a soma **não corresponde a nada**: quem
  abre uma issue não necessariamente trabalha nela, e quem trabalha nela raramente é quem abriu.

  ## Três fronteiras, compostas aqui

  `EO` responde pela pessoa e pelas equipes, `WorkItems` pelo trabalho, e `CMPO` pelo **nome** do
  repositório. Nenhuma lê a tabela da outra: a composição acontece aqui, na borda de apresentação,
  como já acontece em `RepositoryLive.Show`.

  O nome do repositório vem de **uma** consulta virando mapa — consultar por repositório é o
  defeito que a feature 007 pagou com 135 consultas por render.
  """

  use TheBandWeb, :live_view

  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems

  @por_pagina 25

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case EO.fetch_person(tenant, id) do
      # Pessoa de outro tenant devolve não encontrado — nunca "sem permissão", porque confirmar
      # existência já é vazamento entre tenants.
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Person not found.") |> push_navigate(to: ~p"/people")}

      {:ok, pessoa} ->
        {:ok, socket |> assign(pessoa: pessoa, page_title: pessoa.name || pessoa.login) |> load()}
    end
  end

  @impl true
  def handle_event("pagina", %{"n" => n}, socket) do
    {:noreply, socket |> assign(pagina: String.to_integer(n)) |> load()}
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    pessoa = socket.assigns.pessoa
    pagina = socket.assigns[:pagina] || 1

    repositorios = WorkItems.repositories_of_person(tenant, pessoa.id)

    socket
    |> assign(
      pagina: pagina,
      # `@por_pagina` dentro do template é **assign**, não atributo de módulo — e sem esta linha o
      # render levanta `KeyError`. O teste pegou.
      por_pagina: @por_pagina,
      organizacoes: EO.list_person_organizations(tenant, pessoa.id),
      # A organização derivada **do trabalho**, e ela responde outra pergunta.
      #
      # `list_person_organizations/2` sobe por equipe: pessoa → equipe → organização. Quem saiu da
      # organização antes de a plataforma existir nunca esteve numa equipe, e apareceria com zero
      # organizações — falso de outra maneira, porque ela trabalhou lá.
      #
      # A segunda cadeia é observada de ponta a ponta: pessoa → issue → repositório → organização.
      # Nenhum elo é inferido. A tela exibe as duas **separadas**, porque "é membro" e "trabalhou"
      # são afirmações diferentes, e somá-las faria "quem é da organização" responder com gente que
      # ninguém admitiu.
      organizacoes_por_trabalho: organizacoes_do_trabalho(tenant, repositorios, pessoa.id),
      equipes: EO.list_person_teams(tenant, pessoa.id),
      papeis: EO.count_roles(tenant),
      designadas: WorkItems.count_assigned_to(tenant, pessoa.id),
      abertas: WorkItems.count_authored_by(tenant, pessoa.id),
      repositorios: repositorios,
      # Uma consulta, virando mapa: é o mesmo `onde/2` da feature 007. O nome do repositório é de
      # CMPO, e `WorkItems` juntar a tabela dele quebraria a fronteira.
      nomes: nomes_de_repositorio(tenant),
      issues:
        WorkItems.list_issues(tenant,
          assigned_to: pessoa.id,
          limit: @por_pagina,
          offset: (pagina - 1) * @por_pagina
        )
    )
  end

  # As organizações dos repositórios em que a pessoa trabalhou, **menos** aquelas em que ela já
  # aparece por equipe: repetir a mesma organização nas duas listas faria quem lê somar.
  defp organizacoes_do_trabalho(tenant, repositorios, person_id) do
    por_equipe =
      tenant
      |> EO.list_person_organizations(person_id)
      |> MapSet.new(& &1.id)

    observados = Map.new(CMPO.list_observed(tenant), &{&1.observed_repository_id, &1})

    repositorios
    |> Enum.map(&Map.get(observados, &1.observed_repository_id))
    |> Enum.reject(
      &(is_nil(&1) or is_nil(&1.organization_id) or
          MapSet.member?(por_equipe, &1.organization_id))
    )
    |> Enum.group_by(& &1.organization_id)
    |> Enum.map(fn {organization_id, repos} ->
      %{
        organizacao: EO.fetch_organization!(tenant, organization_id),
        repositorios: length(repos)
      }
    end)
  end

  defp nomes_de_repositorio(tenant) do
    Map.new(CMPO.list_observed(tenant), fn r ->
      {r.observed_repository_id, %{name: r.name, qualified_name: r.qualified_name}}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_tenant={@current_tenant}>
      <.header>
        {@pessoa.name || @pessoa.login}
        <:subtitle>
          <span :if={@pessoa.login}>@{@pessoa.login} · </span>{@pessoa.account_type} · observed since {@pessoa.collected_at}
        </:subtitle>
        <:actions>
          <.link navigate={~p"/people"} class="btn btn-ghost btn-sm">back to people</.link>
        </:actions>
      </.header>

      <div class="space-y-6">
        <%!-- Proveniência primeiro: de onde veio, com que identificador, e desde quando. É o que
              permite conferir a pessoa contra a origem. --%>
        <section class="card bg-base-200">
          <div class="card-body gap-3 p-4 sm:p-5">
            <h3 class="font-semibold">Where this came from</h3>
            <dl class="grid gap-2 sm:grid-cols-2">
              <.field label="source">{@pessoa.source_system} · {@pessoa.source_instance}</.field>
              <.field label="identifier at source">
                <span class="font-mono text-xs">{@pessoa.external_id}</span>
              </.field>
              <.field label="first observed">{@pessoa.collected_at}</.field>
              <.field label="last observed">{@pessoa.last_observed_at}</.field>
              <.field :if={@organizacoes != []} label="organisations">
                {Enum.map_join(@organizacoes, ", ", & &1.login)}
                <div class="text-xs opacity-60">observed through team membership</div>
              </.field>
              <%!-- Dito com a evidência, e sem a palavra "membro": a plataforma observou o trabalho,
                    não o pertencimento. Quem saiu antes de ela começar a olhar nunca esteve numa
                    equipe, e o trabalho ficou. --%>
              <.field :if={@organizacoes_por_trabalho != []} label="worked at">
                <div :for={o <- @organizacoes_por_trabalho}>
                  {o.organizacao.login}
                  <span class="text-xs opacity-60">
                    derived from work in {o.repositorios} repositor{if o.repositorios == 1,
                      do: "y",
                      else: "ies"} — not a declared membership
                  </span>
                </div>
              </.field>
            </dl>
            <p :if={@pessoa.no_longer_observed_at} class="text-sm">
              No longer observed since {@pessoa.no_longer_observed_at}. The platform saw this person
              before, and does not see them now.
            </p>
          </div>
        </section>

        <%!-- As equipes, com o que a origem declara E o que a plataforma recusou promover. As três
              coisas juntas: sem a segunda a tela afirma um vínculo que não existe; sem a terceira, a
              recusa parece defeito. --%>
        <section class="space-y-2">
          <div>
            <h3 class="font-semibold">Teams the source declares</h3>
            <p class="text-xs text-base-content/60">
              {explicacao_da_promocao(@equipes, @papeis)}
            </p>
          </div>

          <.empty :if={@equipes == []} title="No team is declared for this person.">
            The source does not place them in any team. This is what the source says — not a gap in
            the collection.
          </.empty>

          <div :if={@equipes != []} class="overflow-x-auto">
            <table class="table table-sm stacked">
              <thead>
                <tr>
                  <th>team</th>
                  <th>organisation</th>
                  <%!-- "access at the tool", nunca "role": MAINTAINER é permissão na ferramenta, e
                        papel é conceito do processo. Chamá-lo de papel aqui desfaria na interface a
                        distinção que o modelo preserva. --%>
                  <th>access at the tool</th>
                  <th>relation</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={equipe <- @equipes}>
                  <td data-label="team">
                    <.link navigate={~p"/teams/#{equipe.team_id}"} class="link link-hover">
                      {equipe.team_name}
                    </.link>
                  </td>
                  <td data-label="organisation" class="text-xs opacity-70">
                    {equipe.organization_login || "not declared"}
                  </td>
                  <td data-label="access at the tool">
                    <span class="font-mono text-xs">{equipe.platform_access_level || "—"}</span>
                  </td>
                  <td data-label="relation">
                    <.origem forma={forma_da_equipe(equipe)} texto={texto_da_equipe(equipe)} />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <%!-- O trabalho: dois números, e a soma deles não aparece em lugar nenhum. Quem abre uma
              issue não necessariamente trabalha nela. --%>
        <section class="space-y-2">
          <h3 class="font-semibold">Work</h3>

          <div class="grid gap-4 sm:grid-cols-2">
            <div class="card bg-base-200">
              <div class="card-body gap-2 p-4">
                <.metric label="assigned to" value={@designadas} sub="issues the source assigns" />
                <p :if={@designadas == 0} class="text-xs text-base-content/60">
                  No issue assigns this person. The platform has not seen them assigned to anything.
                </p>
              </div>
            </div>
            <div class="card bg-base-200">
              <div class="card-body gap-2 p-4">
                <.metric label="opened by" value={@abertas} sub="issues they created" />
                <p :if={@abertas == 0} class="text-xs text-base-content/60">
                  No issue was opened by this person. Opening and working on an issue are different
                  things, and this is the first one.
                </p>
              </div>
            </div>
          </div>

          <%!-- O repositório é DERIVADO: a origem nunca declarou que a pessoa trabalha nele. A
                marca hachurada e o texto dizem de qual evidência ele vem. --%>
          <div :if={@repositorios != []} class="overflow-x-auto">
            <table class="table table-sm stacked">
              <thead>
                <tr>
                  <th>repository</th>
                  <th class="text-right">assigned</th>
                  <th class="text-right">opened</th>
                  <th>relation</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={r <- @repositorios}>
                  <td data-label="repository">
                    <.link
                      navigate={~p"/work/repositories/#{r.observed_repository_id}"}
                      class="link link-hover"
                    >
                      {nome_do_repositorio(@nomes, r.observed_repository_id)}
                    </.link>
                  </td>
                  <td data-label="assigned" class="text-right tabular">{r.assigned}</td>
                  <td data-label="opened" class="text-right tabular">{r.authored}</td>
                  <td data-label="relation">
                    <.origem forma={:hachurada} texto={evidencia_do_repositorio(r)} />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div :if={@issues != []} class="space-y-2">
            <div class="flex items-center justify-between">
              <h4 class="text-sm font-medium">Issues assigned to this person</h4>
              <span class="text-sm text-base-content/70">
                {faixa(@pagina, @designadas)} of {@designadas}
              </span>
            </div>
            <div class="overflow-x-auto">
              <table class="table table-xs stacked">
                <thead>
                  <tr>
                    <th class="text-right">#</th>
                    <th>title</th>
                    <th>state</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={issue <- @issues}>
                    <td data-label="#" class="text-right tabular">{issue.number}</td>
                    <td data-label="title">
                      <.link navigate={~p"/work/issues/#{issue.id}"} class="link link-hover">
                        {issue.title}
                      </.link>
                    </td>
                    <td data-label="state" class="text-xs opacity-70">
                      {String.downcase(issue.state || "")}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <nav :if={@designadas > @por_pagina} class="flex items-center gap-2">
              <button
                class="btn btn-sm btn-outline"
                disabled={@pagina <= 1}
                phx-click="pagina"
                phx-value-n={@pagina - 1}
              >
                Previous
              </button>
              <span class="text-sm text-base-content/70">page {@pagina}</span>
              <button
                class="btn btn-sm btn-outline"
                disabled={@pagina * @por_pagina >= @designadas}
                phx-click="pagina"
                phx-value-n={@pagina + 1}
              >
                Next
              </button>
            </nav>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  # A origem da relação — três formas, com texto e rótulo de leitor de tela.
  #
  # **Privado desta tela**, e não em `TheBandWeb.UI`: há dois usos aqui — equipes e repositórios —,
  # que é o limiar do projeto. Sobe para `UI` no segundo consumidor **fora** desta tela.
  #
  # Não reusa `<.evidence>` de propósito: ela responde "de onde veio este **conceito**", e a
  # pergunta aqui é "de onde veio esta **relação**". A mesma forma para as duas perguntas gastaria
  # a precisão da gramática no lugar em que ela é o produto.
  attr :forma, :atom, required: true
  attr :texto, :string, required: true

  defp origem(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1.5 text-sm">
      <span
        class={[
          "size-2.5 shrink-0 rounded-[1px]",
          @forma == :solida && "bg-current text-success",
          @forma == :hachurada &&
            "text-success outline outline-1 -outline-offset-1 outline-current bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]",
          @forma == :tracejada && "border border-dashed border-current text-base-content/50"
        ]}
        aria-hidden="true"
      ></span>
      <span class={@forma == :tracejada && "text-base-content/60"}>{@texto}</span>
      <span class="sr-only">{rotulo(@forma)}</span>
    </span>
    """
  end

  defp rotulo(:solida), do: "observed: the source declares this relation"
  defp rotulo(:hachurada), do: "derived: the platform inferred this relation from collected work"
  defp rotulo(:tracejada), do: "absent: this relation existed and is not present now"

  # A equipe que saiu é **tracejada**, e a mesma lista carrega as duas formas: é por isso que este
  # componente tem dois usos na tela, e não três.
  defp forma_da_equipe(%{no_longer_observed_at: at}) when not is_nil(at), do: :tracejada
  defp forma_da_equipe(_equipe), do: :solida

  defp texto_da_equipe(%{no_longer_observed_at: at}) when not is_nil(at),
    do: "was in this team until #{Calendar.strftime(at, "%d %b %Y")}"

  defp texto_da_equipe(%{promoted?: true}), do: "membership recorded"
  defp texto_da_equipe(_equipe), do: "declared at the source, not promoted"

  # A explicação vem do **dado**, e não de texto fixo: um texto dizendo "nenhum papel cadastrado"
  # passaria a mentir no dia em que alguém cadastrasse papel, e ninguém notaria — a frase
  # continuaria plausível.
  defp explicacao_da_promocao([], _papeis),
    do: "The source places this person in no team."

  defp explicacao_da_promocao(equipes, papeis) do
    nao_promovidas = Enum.count(equipes, &(&1.promoted? == false))

    cond do
      nao_promovidas == 0 ->
        "Every declared team has a recorded membership."

      papeis == 0 ->
        "#{nao_promovidas} of these are declared by the source and not recorded as memberships: " <>
          "a membership needs an organisational role, and no role is registered yet. " <>
          "Access at the tool is a permission, not a role."

      true ->
        "#{nao_promovidas} of these are declared by the source and not recorded as memberships: " <>
          "roles exist, and nobody assigned one to this person in this team yet."
    end
  end

  defp evidencia_do_repositorio(%{assigned: a, authored: o}) when a > 0 and o > 0,
    do: "derived from assignments and authorship"

  defp evidencia_do_repositorio(%{assigned: a}) when a > 0, do: "derived from assignments"
  defp evidencia_do_repositorio(_r), do: "derived from authorship"

  defp nome_do_repositorio(nomes, id) do
    case Map.get(nomes, id) do
      nil -> "repository no longer observed"
      %{name: name} -> name
    end
  end

  defp faixa(pagina, total) do
    inicio = (pagina - 1) * @por_pagina + 1
    "#{inicio}–#{min(pagina * @por_pagina, total)}"
  end
end
