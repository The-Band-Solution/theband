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

  import TheBandWeb.Components.DataTable

  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems
  alias TheBandWeb.TabelaLive, as: Tabela
  alias TheBandWeb.WorkCharts

  @por_pagina 25

  # As tabelas desta tela: `{id, colunas ordenáveis, prefixo do parâmetro}`.
  #
  # A lista de colunas é declarada, e o átomo do parâmetro sai **dela** — nunca do texto
  # recebido, que aceitaria qualquer átomo já existente.
  #
  # O prefixo `nil` é o da tabela principal: ela usa `q`, `ordem`, `dir` e `pagina`, que é o
  # endereço da feature 019. A tabela de repositórios, quando for convertida, entra aqui com
  # prefixo próprio.
  @tabelas [{"issues", [:number, :title, :state], nil}]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant = socket.assigns.current_tenant

    case EO.fetch_person(tenant, id) do
      # Pessoa de outro tenant devolve não encontrado — nunca "sem permissão", porque confirmar
      # existência já é vazamento entre tenants.
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Person not found.") |> push_navigate(to: ~p"/people")}

      {:ok, pessoa} ->
        {:ok, assign(socket, pessoa: pessoa, page_title: pessoa.name || pessoa.login)}
    end
  end

  # O estado da tabela mora no endereço — feature 019. A carga acontece aqui, e não no
  # `mount`, porque buscar e ordenar chegam por `push_patch`: no `mount` elas nunca seriam
  # relidas, e a tela mostraria o resultado da primeira visita para sempre.
  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> Tabela.aplicar(params, @tabelas) |> load()}
  end

  @impl true
  def handle_event("buscar", params, socket), do: Tabela.buscar(params, socket, &caminho/3)
  def handle_event("ordenar", params, socket), do: Tabela.ordenar(params, socket, &caminho/3)
  def handle_event("pagina", params, socket), do: Tabela.pagina(params, socket, &caminho/3)

  defp caminho(socket, id, mudancas) do
    ~p"/people/#{socket.assigns.pessoa.id}?#{Tabela.query(socket, id, mudancas)}"
  end

  defp load(socket) do
    tenant = socket.assigns.current_tenant
    pessoa = socket.assigns.pessoa
    estado = socket.assigns.tabelas["issues"]
    pagina = estado.pagina

    repositorios = WorkItems.repositories_of_person(tenant, pessoa.id)
    cobertura = WorkItems.timeline_coverage(tenant, pessoa.id)

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
      # Os papéis **declarados** — vigentes e encerrados. Esconder o encerrado apagaria
      # história: quem saiu do papel continua tendo desempenhado.
      papeis_declarados: EO.list_person_roles(tenant, pessoa.id),
      # **Duas contagens, e elas respondem coisas diferentes.** `designadas` é quantas issues
      # a pessoa tem — o número do cartão, que não muda quando alguém busca. `encontradas` é
      # quantas a busca vigente alcançou, e é ele que a paginação usa: paginar sobre o total
      # afirmaria páginas que a busca não tem.
      designadas: WorkItems.count_assigned_to(tenant, pessoa.id),
      # O painel da pessoa — feature 023.
      #
      # `timeline_coverage/2` devolve o par de uma vez, e não em duas chamadas para pegar
      # cada metade: ela já consulta duas vezes por dentro, e chamá-la duas vezes dobraria
      # isso. O teste-guarda de custo desta tela conta consultas por render.
      designadas_abertas: elem(cobertura, 1),
      cobertura_observada: elem(cobertura, 0),
      cobertura_total: elem(cobertura, 1),
      meses: WorkItems.closed_by_month(tenant, pessoa.id),
      idades: WorkItems.open_age_buckets(tenant, pessoa.id),
      lead_time: WorkItems.lead_time(tenant, pessoa.id),
      encontradas:
        WorkItems.count_collected(tenant, assigned_to: pessoa.id, search: estado.busca),
      abertas: WorkItems.count_authored_by(tenant, pessoa.id),
      repositorios: repositorios,
      # Uma consulta, virando mapa: é o mesmo `onde/2` da feature 007. O nome do repositório é de
      # CMPO, e `WorkItems` juntar a tabela dele quebraria a fronteira.
      nomes: nomes_de_repositorio(tenant),
      issues:
        WorkItems.list_issues(tenant,
          assigned_to: pessoa.id,
          search: estado.busca,
          order_by: estado.ordem,
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
      <.breadcrumb niveis={[
        %{rotulo: "People", destino: ~p"/people"},
        %{rotulo: @pessoa.name || @pessoa.login, destino: nil}
      ]} />
      <.header>
        {@pessoa.name || @pessoa.login}
        <:subtitle>
          <span :if={@pessoa.login}>@{@pessoa.login} · </span>{@pessoa.account_type} · observed since {@pessoa.collected_at}
        </:subtitle>
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

        <%!-- **O papel declarado, e ele vem antes da participação observada de propósito.**

              As duas coisas ficam separadas porque são de naturezas diferentes: o papel é
              declaração humana, e nenhuma origem o fornece; a participação é observação. Uma
              tela que mostrasse "Developer" sem dizer que alguém digitou aquilo transformaria
              declaração em observação — e é o oposto do que a plataforma inteira defende.

              A ordem — declarado primeiro — é porque é o que responde "o que esta pessoa faz",
              e a participação responde "onde a origem a mostra". --%>
        <section :if={@papeis_declarados != []} class="space-y-2">
          <div>
            <h3 class="font-semibold">Roles declared for this person</h3>
            <p class="text-xs text-base-content/60">
              Declared by someone in this organisation — no source provides organisational role.
            </p>
          </div>

          <div class="overflow-x-auto">
            <table class="table table-sm stacked">
              <thead>
                <tr>
                  <th>role</th>
                  <th>team</th>
                  <th>from</th>
                  <th>until</th>
                  <th>declared by</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={papel <- @papeis_declarados} class={papel.ended_at && "opacity-60"}>
                  <td data-label="role">
                    <span class="font-medium">{papel.role_name}</span>
                    <div class="text-xs opacity-60 font-mono">{papel.role_code}</div>
                  </td>
                  <td data-label="team" class="text-sm">{papel.team_name}</td>
                  <%!-- Sem data não vira "hoje": ninguém disse quando, e inventar afirmaria
                        que a alocação começou agora. --%>
                  <td data-label="from" class="text-xs">
                    <span :if={papel.started_at}>{papel.started_at}</span>
                    <.absent :if={is_nil(papel.started_at)} reason="not stated" />
                  </td>
                  <td data-label="until" class="text-xs">
                    <span :if={papel.ended_at}>{papel.ended_at}</span>
                    <span :if={is_nil(papel.ended_at)} class="badge badge-sm badge-success">
                      current
                    </span>
                  </td>
                  <td data-label="declared by" class="text-xs opacity-70">
                    <span :if={papel.declared_by}>{papel.declared_by}</span>
                    <.absent :if={is_nil(papel.declared_by)} reason="author not recorded" />
                  </td>
                </tr>
              </tbody>
            </table>
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

          <%!-- A cobertura vem ANTES de qualquer número derivado, e não como rodapé.
                Medido em 2026-08-15: 5 de 53 repositórios têm timeline. Uma pessoa com 152
                issues abertas podia ter nenhuma observada — e mostrar "0 atividades" ali
                diria que ela não trabalhou, quando concluiu 199 no histórico. --%>
          <.notice
            :if={@cobertura_total > 0 and @cobertura_observada < @cobertura_total}
            kind={:gap}
            title={
              if @cobertura_observada == 0,
                do: "The platform has not collected the timeline for any of this person's open work.",
                else: "The timeline covers part of this person's open work."
            }
          >
            <p>
              {@cobertura_observada} of {@cobertura_total} open issues are in repositories whose
              timeline was collected.
            </p>
            <p class="mt-1 text-xs">
              <strong>The two charts below do not depend on this.</strong>
              They come from the issue's own dates, which have full coverage. What is missing is the
              sequence of movements — and that is what cycle time would need.
            </p>
          </.notice>

          <div class="grid gap-4 lg:grid-cols-3">
            <div class="card bg-base-200 lg:col-span-2">
              <div class="card-body gap-2 p-4">
                <h4 class="text-sm font-medium">
                  Issues completed over time
                  <span class="opacity-60">{@lead_time && @lead_time.count} in total</span>
                </h4>
                <p :if={@meses == []} class="text-xs text-base-content/60">
                  This person has not closed any issue the platform has seen.
                </p>
                <WorkCharts.por_mes :if={@meses != []} serie={@meses} />
                <p class="text-xs text-base-content/60">
                  Counted by close date, from the issue itself — it does not depend on the timeline.
                </p>
              </div>
            </div>

            <div class="card bg-base-200">
              <div class="card-body gap-2 p-4">
                <h4 class="text-sm font-medium">
                  Age of open work <span class="opacity-60">{@designadas_abertas} open</span>
                </h4>
                <p :if={@designadas_abertas == 0} class="text-xs text-base-content/60">
                  Nothing assigned and open right now.
                </p>
                <WorkCharts.por_faixa :if={@designadas_abertas > 0} faixas={@idades} />
                <p class="text-xs text-base-content/60">
                  Days since the issue was created. The only forward-looking measure here — the
                  others count the past, this one shows what is sitting still now.
                </p>
              </div>
            </div>
          </div>

          <div :if={@lead_time} class="card bg-base-200">
            <div class="card-body gap-2 p-4">
              <h4 class="text-sm font-medium">Lead time of completed issues</h4>
              <div class="flex flex-wrap gap-8">
                <.metric label="median" value={"#{@lead_time.median}d"} sub="half closed faster" />
                <.metric label="p85" value={"#{@lead_time.p85}d"} sub="the slow tail" />
                <.metric label="issues" value={@lead_time.count} sub="closed and counted" />
              </div>
              <%!-- Lead time e cycle time NÃO são a mesma coisa, e a tela diz isso onde o
                    número aparece — não numa nota de rodapé que ninguém lê. --%>
              <p class="text-xs text-base-content/60">
                <strong>This is lead time, not cycle time.</strong>
                It counts from creation to close, including the time nobody touched the issue. Cycle
                time needs to know when work started, and that decision has not been made — swapping
                one for the other would have you decide on a number that answers a different question.
              </p>
              <p class="text-xs text-base-content/60">
                Median and p85, never the mean: one issue sitting for 400 days moves the mean and
                leaves the median where it is.
              </p>
            </div>
          </div>

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

          <div :if={@designadas > 0} class="space-y-2">
            <h4 class="text-sm font-medium">Issues assigned to this person</h4>

            <.data_table
              id="issues"
              rows={@issues}
              estado={@tabelas["issues"]}
              por_pagina={@por_pagina}
              total={@encontradas}
              onde="title and number"
              class="table table-xs stacked"
              vazio="No issue matches this search."
            >
              <:col :let={issue} field={:number} label="#" class="text-right tabular">
                {issue.number}
              </:col>
              <:col :let={issue} field={:title} label="title">
                <.link navigate={~p"/work/issues/#{issue.id}"} class="link link-hover">
                  {issue.title}
                </.link>
              </:col>
              <:col :let={issue} field={:state} label="state" class="text-xs opacity-70">
                {String.downcase(issue.state || "")}
              </:col>
            </.data_table>
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
end
