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

  import Ecto.Query, only: [from: 2]
  import TheBandWeb.Components.DataTable

  alias TheBand.Communication.Discussions
  alias TheBand.Mapping.Antipatterns
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Profiles
  alias TheBand.Profiles.Material
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
        # Assina só quando conectado: no primeiro render, estático, o processo morre em
        # seguida e a assinatura ficaria órfã.
        if connected?(socket), do: Profiles.subscribe(tenant, pessoa.id)

        {:ok, assign(socket, pessoa: pessoa, page_title: pessoa.name || pessoa.login)}
    end
  end

  # **Os dois desfechos chegam aqui**, e é de propósito: anunciar só o sucesso deixaria a
  # tela esperando para sempre um evento que não vem, e "esperando" é indistinguível de
  # "ainda rodando" para quem olha.
  @impl true
  def handle_info({:perfil, :pronto, _person_id}, socket) do
    {:noreply, socket |> put_flash(:info, "Profile ready.") |> load()}
  end

  def handle_info({:perfil, {:falhou, motivo}, _person_id}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Profile generation failed: #{falha(motivo)}")
     |> load()}
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

  def handle_event("gerar_perfil", _params, socket) do
    tenant = socket.assigns.current_tenant
    pessoa = socket.assigns.pessoa

    case Profiles.request(tenant, pessoa.id, socket.assigns.current_user.id) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile requested. It takes about a minute.")
         |> assign(perfil_pendente?: true)}

      # Falha ao enfileirar é falha, e é dita. Silêncio aqui faria a pessoa clicar de novo
      # sem saber que nada aconteceu.
      {:error, motivo} ->
        {:noreply, put_flash(socket, :error, "Could not request: #{inspect(motivo)}")}
    end
  end

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

    perfil = perfil_atual(tenant, pessoa.id)
    {pendente?, possivel} = estado_do_perfil(tenant, pessoa, perfil)

    socket
    |> assign(
      perfil_pendente?: pendente?,
      perfil_possivel: possivel,
      # **FR-016.** Sem isto um perfil de dezembro parece atual em junho, e quem lê decide
      # com texto velho sem saber que é velho. Sai da diferença entre o recorte gravado e o
      # que existe hoje — que é exatamente para isso que o recorte é coluna.
      tarefas_novas: Profiles.tasks_since(tenant, pessoa.id, perfil),
      # Vale **sempre**, e não só com perfil: a lista é sobre o trabalho da pessoa, não sobre
      # o perfil dela. Antes ficava dentro do cartão do perfil e por isso dependia dele.
      paradas: paradas_com_discussao(tenant, Profiles.stale_open(tenant, pessoa.id)),
      participacao: Discussions.participation_of(tenant, pessoa.id, limit: 20),
      dias_parada: Material.stale_days(),
      pagina: pagina,
      # `@por_pagina` dentro do template é **assign**, não atributo de módulo — e sem esta linha o
      # render levanta `KeyError`. O teste pegou.
      por_pagina: @por_pagina,
      organizacoes: EO.list_person_organizations(tenant, pessoa.id),
      # **Os três estados do perfil, e eles são distinguíveis de propósito.** Nunca gerado,
      # pedido e ainda não pronto, e o que existe. Achatá-los faria a tela dizer a mesma
      # frase para situações que pedem coisas diferentes de quem lê.
      #
      # As duas consultas seguintes só acontecem **quando não há perfil**: com perfil na tela
      # nem o botão nem a recusa aparecem, e pagá-las seria custo por render sem consumidor.
      perfil: perfil,
      evolucao_do_perfil: evolucao_do_perfil(tenant, pessoa.id, perfil),
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
      antipadroes: Antipatterns.detect_for_person(tenant, pessoa.id),
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
  defp titulo_do_antipadrao("process.ap01.closed_without_movement"),
    do: "Closed without ever being moved"

  defp titulo_do_antipadrao("process.ap02.moved_after_closing"),
    do: "Moved after it was closed"

  defp titulo_do_antipadrao("process.ap03.assigned_and_never_started"),
    do: "Assigned and never started"

  defp titulo_do_antipadrao("process.ap04.movement_without_assignee"),
    do: "Moved with nobody assigned"

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

          <%!-- A PARTICIPAÇÃO (cmo.discussion_participation) — derivada dos atos
                observados, e por isso hachurada e rotulada. Responde o que designação
                nenhuma responde: o trabalho que acontece na conversa. --%>
          <div class="mt-4 border-t border-base-300 pt-3">
            <div class="mb-2 flex flex-wrap items-center gap-2">
              <h4 class="text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                Discussions they took part in
              </h4>
              <span class="badge badge-outline badge-sm gap-1 text-warning">
                <span class="size-2.5 shrink-0 rounded-[1px] outline outline-1 -outline-offset-1 outline-current bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"></span>
                derived — counted from collected comments
              </span>
            </div>
            <p class="mb-2 text-xs text-base-content/60">
              Commenting is <strong>not</strong>
              a completed task, and this is not a skill claim: it is where the person
              showed up in the conversation — including on issues never assigned to them.
            </p>

            <p :if={@participacao == []} class="text-xs text-base-content/60">
              No comment by this person has been collected. Either they work through other
              channels, or the discussion of their repositories has not been collected yet.
            </p>

            <div
              :for={d <- @participacao}
              class="flex flex-wrap items-baseline gap-x-3 border-t border-base-300 py-1.5 text-sm"
            >
              <span class="w-16 shrink-0 text-right font-mono text-xs opacity-70 tabular-nums">
                {d.atos}×
              </span>
              <.link navigate={~p"/work/issues/#{d.issue_id}"} class="link link-hover">
                {d.title}
              </.link>
              <span class="font-mono text-xs opacity-60 tabular-nums">
                {Calendar.strftime(d.primeiro, "%Y-%m")} → {Calendar.strftime(d.ultimo, "%Y-%m")}
              </span>
            </div>
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
            <%!-- min-w-0: item de grid não encolhe abaixo do conteúdo por padrão, e o SVG de
                  largura fixa arrastava a página inteira para 608px no telefone (visto em
                  2026-08-17). Com min-w-0, quem rola é o overflow-x-auto do gráfico. --%>
            <div class="card min-w-0 bg-base-200 lg:col-span-2">
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

            <div class="card min-w-0 bg-base-200">
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

          <div class="card bg-base-200">
            <div class="card-body gap-2 p-4">
              <h4 class="text-sm font-medium">Process anti-patterns</h4>
              <%!-- A frase vem ANTES dos achados, e não depois: sem ela, "assigned and never
                    started" lê como acusação de quem está designado. --%>
              <p class="text-xs text-base-content/60">
                These are not judgements about people. They say the record of the process is
                incomplete — and the cost is that the organisation loses the measurement.
              </p>

              <%!-- "Não avaliado" e "nada encontrado" produzem a mesma seção vazia e afirmam
                    o oposto. Medido em 2026-08-15: para quase toda pessoa, a maioria das
                    issues cai no primeiro caso. --%>
              <p
                :if={@antipadroes.avaliadas == 0 and @antipadroes.nao_avaliadas > 0}
                class="text-sm text-base-content/70"
              >
                None of this person's {@antipadroes.nao_avaliadas} issues has collected board
                movement, so nothing was evaluated. That is not the same as finding nothing.
              </p>

              <p
                :if={@antipadroes.avaliadas > 0 and @antipadroes.achados == []}
                class="text-sm text-base-content/70"
              >
                Nothing found in the {@antipadroes.avaliadas} issues that could be evaluated.
              </p>

              <ul :if={@antipadroes.achados != []} class="space-y-1 text-sm">
                <li :for={a <- @antipadroes.achados}>
                  <span class="font-medium">{titulo_do_antipadrao(a.id)}</span>
                  <span class="opacity-70">· {a.count}</span>
                  <div class="font-mono text-xs opacity-60">{a.id}</div>
                </li>
              </ul>

              <p
                :if={@antipadroes.avaliadas > 0 and @antipadroes.nao_avaliadas > 0}
                class="text-xs text-base-content/60"
              >
                Evaluated over {@antipadroes.avaliadas} issues; {@antipadroes.nao_avaliadas} had no
                collected movement and were not evaluated.
              </p>
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

            <%!-- **Derivado da listagem, e depois dela.** Estava dentro do cartão do perfil,
                  cercado de blocos hachurados — e é fato observado, não conclusão de modelo.
                  Ali misturava proveniência num produto que existe para separar as duas.

                  Fica sólido, e recalculado a cada leitura: uma tarefa que fechou depois da
                  última geração some daqui, e continuaria num texto gravado. --%>
            <div :if={@paradas != []} class="mt-4 border-t border-base-300 pt-3">
              <h4 class="mb-2 text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                Assigned and open longer than {@dias_parada} days
              </h4>
              <p class="mb-2 text-xs text-base-content/60">
                The origin records no deadline, so this is not lateness — it is work that has
                been open this long and needs a destination.
              </p>
              <%!-- O sinal "parada" tem TRÊS diagnósticos, e eles pedem ações opostas
                    (#400): sem conversa nenhuma é abandono silencioso; conversa antiga é
                    abandono depois de discutir; conversa recente é trabalho vivo com
                    registro desatualizado. Sem os comentários, os três eram a mesma
                    linha. --%>
              <div :for={t <- @paradas} class="border-t border-base-300 py-1.5 text-sm">
                <div class="flex gap-3">
                  <span class="w-16 shrink-0 text-right font-mono text-xs text-error tabular-nums">
                    {t.dias_aberta}d
                  </span>
                  <.link navigate={~p"/work/issues/#{t.id}"} class="link link-hover">
                    {t.titulo}
                  </.link>
                </div>
                <div class="mt-0.5 flex flex-wrap items-baseline gap-2 pl-19 text-xs">
                  <span class={[
                    "badge badge-xs shrink-0",
                    t.conversa == :recente && "badge-success",
                    t.conversa == :antiga && "badge-warning",
                    t.conversa == :silencio && "badge-ghost",
                    t.conversa == :nao_coletada && "badge-ghost badge-outline"
                  ]}>
                    {rotulo_da_conversa(t.conversa)}
                  </span>
                  <span class="opacity-60">{frase_da_conversa(t)}</span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <%!-- O perfil derivado.

              **Hachurado e rotulado em texto**, conforme o design system: cor sozinha reprova
              em WCAG 1.4.1 e, mais que isso, desfaz o produto — a plataforma existe para
              separar o que observou do que concluiu.

              `<.evidence>` não é reusado aqui de propósito. Aquele componente fala o
              vocabulário de promoção de conceito — conceito, fonte, confiança —, e um texto
              escrito por um modelo não tem nenhum dos três. Reusá-lo seria aplicar o padrão
              fora do problema que o motivou. O que se reusa é a **regra**: preenchimento
              hachurado, e rótulo em texto ao lado. --%>
        <section class="card bg-base-200">
          <div class="card-body gap-3 p-4 sm:p-5">
            <h3 class="flex flex-wrap items-center gap-2 font-semibold">
              Profile &amp; growth
              <span class="inline-flex items-center gap-1.5 text-xs font-normal text-warning">
                <span
                  class="size-2.5 shrink-0 rounded-[1px] outline outline-1 -outline-offset-1 outline-current bg-[repeating-linear-gradient(135deg,currentColor_0_2px,transparent_2px_4px)]"
                  aria-hidden="true"
                ></span>
                derived — written by a language model
              </span>
            </h3>

            <%!-- Estado 1: existe perfil.

                  A proveniência vem ANTES do conteúdo, porque quem lê precisa saber o que
                  está lendo antes de acreditar nele. E os números do recorte são
                  **observados** — sólidos, distintos do texto derivado que descrevem. --%>
            <div :if={@perfil} class="space-y-4">
              <dl class="grid gap-2 text-sm sm:grid-cols-2">
                <.field label="model">
                  <span class="font-mono text-xs">{@perfil.model}</span>
                </.field>
                <.field label="generated">{@perfil.generated_at}</.field>
                <.field label="input">
                  {@perfil.tasks_closed} completed · {@perfil.tasks_open} open · {@perfil.tasks_authored_by_other} described by someone else · {@perfil.tasks_shared} shared
                </.field>
                <.field label="citations removed from the summary">
                  {@perfil.citations_removed}
                </.field>
              </dl>

              <%!-- As habilidades: a única parte escaneável. Hachuradas como o resto do
                    derivado, e não sólidas — quem passa os olhos precisa ver que são
                    conclusão antes de ler. --%>
              <div class="flex flex-wrap items-center gap-2">
                <span class="text-xs font-semibold tracking-wide text-warning uppercase">
                  Demonstrated skills
                </span>
                <span
                  :for={h <- @perfil.content["habilidades"]}
                  class="rounded-full border border-dashed border-warning/70 bg-warning/5 px-3 py-1 text-sm text-warning"
                >
                  {h}
                </span>
              </div>

              <div class="space-y-3 rounded-lg border border-dashed border-warning/60 bg-[repeating-linear-gradient(135deg,rgb(var(--color-warning)/0.06)_0_5px,transparent_5px_10px)] p-4">
                <p :for={{_k, texto} <- resumo_em_ordem(@perfil)} class="text-sm leading-relaxed">
                  {texto}
                </p>
              </div>

              <%!-- A trajetória: três períodos de volume igual, e não de duração igual.
                    Períodos de mesma duração comparariam quatro tarefas com noventa. --%>
              <div class="space-y-3">
                <h4 class="text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                  How the work changed
                </h4>
                <div
                  :for={p <- @perfil.content["trajetoria"]}
                  class="grid gap-2 border-t border-base-300 pt-3 sm:grid-cols-[10rem_1fr]"
                >
                  <div class="text-xs text-base-content/60 tabular-nums">
                    <span class="block font-semibold text-base-content">Period {p["periodo"]}</span>
                    {p["meses"]}
                  </div>
                  <div class="space-y-1 text-sm">
                    <div class="font-semibold">{p["titulo"]}</div>
                    <p class="leading-relaxed">{p["texto"]}</p>
                    <div
                      :if={p["tarefas_citadas"] != []}
                      class="font-mono text-xs text-base-content/60"
                    >
                      {Enum.join(p["tarefas_citadas"], " · ")}
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Destaques: o critério fica visível, senão "destaque" vira opinião. --%>
              <div class="space-y-2">
                <h4 class="text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                  Where the evidence is strong
                </h4>
                <p class="text-xs text-base-content/60">
                  Six tasks or more, present in at least two periods, with evidence in the most
                  recent one — all three at once.
                </p>
                <div :for={d <- @perfil.content["destaques"]} class="border-t border-base-300 pt-2">
                  <div class="text-sm font-semibold">{d["dominio"]}</div>
                  <p class="text-sm text-base-content/80">{d["demonstrou"]}</p>
                  <div class="mt-1 flex flex-wrap gap-3 text-xs text-base-content/60 tabular-nums">
                    <span>{d["tarefas"]} tasks</span>
                    <span>periods {Enum.join(d["periodos"], ", ")}</span>
                    <span>latest {d["mais_recente"]}</span>
                    <span :if={d["evidencia"] != []} class="font-mono">
                      #{Enum.join(d["evidencia"], " #")}
                    </span>
                  </div>
                </div>
              </div>

              <%!-- Evolução por geração (#403): a tabela de perfis é somente-acréscimo, e
                    é ela que responde "as tarefas-evidência de cada domínio cresceram entre
                    perfis?". Uma geração só não é série — a ausência é nomeada, nunca
                    escondida. --%>
              <div class="space-y-2">
                <h4 class="text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                  Evolution — task evidence per profile generation
                </h4>
                <p
                  :if={length(@evolucao_do_perfil.geracoes) <= 1}
                  class="text-xs text-base-content/60"
                >
                  One generation so far ({List.first(@evolucao_do_perfil.geracoes)}) — evolution
                  appears from the second on. The monthly round writes it by itself.
                </p>
                <div :if={length(@evolucao_do_perfil.geracoes) > 1} class="space-y-1">
                  <div
                    :for={serie <- @evolucao_do_perfil.series}
                    class="grid grid-cols-[1fr_max-content] items-center gap-x-3 gap-y-1 text-sm sm:grid-cols-[minmax(8rem,16rem)_1fr_max-content]"
                  >
                    <span class="col-span-2 break-words sm:col-span-1">{serie.nome}</span>
                    <svg
                      viewBox="0 0 200 26"
                      preserveAspectRatio="none"
                      class="h-5 w-full"
                      role="img"
                      aria-label={"#{serie.nome}: from #{serie.primeiro} to #{serie.ultimo} evidence tasks"}
                    >
                      <polyline
                        points={pontos_da_serie(serie.pontos)}
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        class="text-primary"
                      />
                    </svg>
                    <span class="font-mono text-xs tabular-nums opacity-70">
                      {serie.primeiro} → {serie.ultimo} {tendencia_da_serie(serie)}<span
                        :if={serie.primeiro == 0 and serie.ultimo > 0}
                        class="text-success"
                      > new</span>
                    </span>
                  </div>
                  <p class="text-xs text-base-content/60">
                    the domains of the current profile, across {length(@evolucao_do_perfil.geracoes)} generations ·
                    a domain absent from an older profile counts 0 there — evidence not yet
                    named, never regression
                  </p>
                </div>
              </div>

              <%!-- Lacunas: cada uma diz **qual** das três formas é, porque as três pedem
                    coisas diferentes. E vazio é resposta, não seção faltando: um relatório
                    que sempre acha um ponto fraco não está lendo. --%>
              <div class="space-y-2">
                <h4 class="text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                  Where it is thin, stale, or stuck
                </h4>
                <p class="text-xs text-base-content/60">
                  A gap in <strong>what was recorded</strong>, not in what the person knows.
                </p>
                <div
                  :for={l <- @perfil.content["lacunas"]}
                  class="grid gap-1 border-t border-base-300 pt-2 sm:grid-cols-[6rem_1fr]"
                >
                  <span class="text-xs font-bold tracking-wide text-warning uppercase">
                    {forma_em_ingles(l["forma"])}
                  </span>
                  <div class="text-sm">
                    <span class="font-semibold">{l["onde"]}</span>
                    <p class="text-base-content/80">{l["observado"]}</p>
                  </div>
                </div>
                <.absent
                  :if={@perfil.content["lacunas"] == []}
                  reason="None of the three forms holds for this record — nothing thin, stale, or stuck was found."
                />
              </div>

              <%!-- O contrapeso, e é ele que dá crédito ao resto. --%>
              <div class="rounded-lg bg-base-300/40 p-4 text-sm">
                <h4 class="mb-1 text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                  What changed in the project, not in this person
                </h4>
                <p class="font-mono text-xs text-base-content/60">{@perfil.baseline_verdict}</p>
                <p class="mt-2 leading-relaxed">{@perfil.content["do_time_nao_da_pessoa"]}</p>
              </div>

              <div :if={@perfil.content["alocacao"] != []} class="space-y-2">
                <h4 class="text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                  Where the evidence supports allocation
                </h4>
                <p class="text-xs text-base-content/60">
                  Where evidence already exists — not where this person should go. That call
                  belongs to whoever knows the demand.
                </p>
                <div
                  :for={a <- @perfil.content["alocacao"]}
                  class="border-t border-base-300 pt-2 text-sm"
                >
                  <span class="font-semibold">{a["dominio"]}</span>
                  <span class="text-xs text-base-content/60 tabular-nums">
                    · {a["tarefas"]} tasks, {a["de"]} to {a["ate"]}
                  </span>
                  <p class="text-base-content/80">{a["demonstrou"]}</p>
                </div>
              </div>

              <div :if={@perfil.content["recomendacoes"] != []} class="space-y-1">
                <h4 class="text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                  What to do with this
                </h4>
                <ul class="list-disc space-y-1 pl-5 text-sm">
                  <li :for={r <- @perfil.content["recomendacoes"]}>{r}</li>
                </ul>
              </div>

              <%!-- Obrigatória: quem decide com base neste texto precisa saber o tamanho do
                    que ele não viu. --%>
              <div class="rounded-lg border border-dashed border-base-300 p-4 text-sm text-base-content/70">
                <h4 class="mb-1 text-xs font-semibold tracking-wide text-base-content/60 uppercase">
                  What this cannot say
                </h4>
                {@perfil.content["nao_alcanca"]}
              </div>

              <%!-- Regerar continua disponível **com perfil na tela**, e é a US4: um perfil
                    de agosto e outro de dezembro contam algo que nenhum dos dois conta
                    sozinho. A tabela é somente-acréscimo, então o anterior não se perde.

                    A frase do egresso acompanha o botão aqui também: sai o mesmo texto de
                    tarefas que saiu da primeira vez, e quem clica precisa saber disso no
                    momento de clicar. --%>
              <div class="flex flex-wrap items-center gap-3 border-t border-base-300 pt-3">
                <button
                  :if={not @perfil_pendente?}
                  type="button"
                  phx-click="gerar_perfil"
                  class="btn btn-sm btn-outline"
                >
                  Generate again
                </button>
                <.absent
                  :if={@perfil_pendente?}
                  reason="A new profile was requested. It appears here on its own when it is done."
                />
                <span :if={not @perfil_pendente?} class="text-xs text-base-content/60">
                  Sends the tasks' titles and descriptions to an external provider again.
                  <span :if={@tarefas_novas > 0}>
                    <strong>{@tarefas_novas}</strong> completed
                    task{if @tarefas_novas == 1, do: "", else: "s"} closed since this one.
                  </span>
                  <span :if={@tarefas_novas == 0}>
                    No task has closed since this one — the text would say the same.
                  </span>
                </span>
              </div>
            </div>

            <%!-- Estado 2: pedido, e ainda não pronto. Distinto de "nunca gerado" porque quem
                  clicou precisa saber que o clique valeu. --%>
            <div :if={is_nil(@perfil) and @perfil_pendente?}>
              <.absent reason="Requested. The model takes about a minute, and this page updates on its own." />
            </div>

            <%!-- Estado 3: nunca gerado, e há material. A frase do egresso acompanha o botão,
                  e não o rodapé: quem decide precisa saber o que sai daqui no momento de
                  decidir. --%>
            <div
              :if={is_nil(@perfil) and not @perfil_pendente? and @perfil_possivel == :ok}
              class="space-y-3"
            >
              <p class="text-sm text-base-content/70">
                No profile yet. Generating one sends the <strong>titles and descriptions</strong>
                of this person's tasks to an external language-model provider.
              </p>
              <button type="button" phx-click="gerar_perfil" class="btn btn-sm btn-primary">
                Generate profile
              </button>
            </div>

            <%!-- Estado 4: não há material. Sem botão, e com os números — a recusa é do
                  registro, nunca da pessoa. --%>
            <div :if={is_nil(@perfil) and not @perfil_pendente? and @perfil_possivel != :ok}>
              <.absent reason={recusa(elem(@perfil_possivel, 1))} />
            </div>
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

  # `pending?` vale nos dois casos: com perfil na tela o botão é "gerar de novo", e ele
  # precisa sumir enquanto a geração nova roda. `check` só quando não há perfil — com perfil
  # a recusa não é exibida, e pagar a consulta seria custo por render sem consumidor.
  defp estado_do_perfil(tenant, pessoa, nil),
    do: {Profiles.pending?(tenant, pessoa.id), Profiles.check(tenant, pessoa.id)}

  defp estado_do_perfil(tenant, pessoa, %{}),
    do: {Profiles.pending?(tenant, pessoa.id), :ok}

  # A ordem dos três parágrafos do resumo é conteúdo: forças, evolução, atenção. Um mapa não
  # tem ordem, e iterar sobre ele daria uma ordem qualquer — trocar atenção por forças mudaria
  # o que a pessoa gestora lê primeiro.
  defp resumo_em_ordem(%{content: %{"resumo" => r}}) do
    for chave <- ~w(forcas evolucao atencao), texto = r[chave], texto not in [nil, ""] do
      {chave, texto}
    end
  end

  defp resumo_em_ordem(_perfil), do: []

  # A interface fala inglês; o modelo escreve em português. Traduzir aqui, e não no schema,
  # mantém o vocabulário da regra em uma língua só.
  # A resolução tripla do sinal "parada" (#400) — uma consulta para TODAS as paradas.
  #
  # `nao_coletada` existe porque ausência de discussão coletada não é ausência de
  # discussão: quando a coleta de comentários nunca passou pelo repositório, a tela diz
  # isso em vez de afirmar silêncio.
  defp paradas_com_discussao(_tenant, []), do: []

  defp paradas_com_discussao(tenant, paradas) do
    ultimos = Discussions.last_act_for_issues(tenant, Enum.map(paradas, & &1.id))
    corte = DateTime.add(DateTime.utc_now(:second), -Material.stale_days(), :day)
    coletados = repositorios_com_comentarios(tenant, paradas)

    Enum.map(paradas, fn t ->
      Map.merge(t, classificar_conversa(ultimos[t.id], corte, MapSet.member?(coletados, t.id)))
    end)
  end

  defp classificar_conversa(nil, _corte, false),
    do: %{conversa: :nao_coletada, atos: 0, ultimo_ato: nil}

  defp classificar_conversa(nil, _corte, true),
    do: %{conversa: :silencio, atos: 0, ultimo_ato: nil}

  defp classificar_conversa(%{atos: atos, ultimo: ultimo}, corte, _coletado) do
    forma = if DateTime.compare(ultimo, corte) == :gt, do: :recente, else: :antiga
    %{conversa: forma, atos: atos, ultimo_ato: ultimo}
  end

  # Quais dessas issues estão em repositório cuja coleta de comentários já passou.
  defp repositorios_com_comentarios(tenant, paradas) do
    ids = Enum.map(paradas, & &1.id)

    TheBand.Repo.all(
      from i in "collected_issues",
        join: o in "observed_repositories",
        on: o.id == i.observed_repository_id,
        where:
          i.tenant_id == type(^tenant.id, :binary_id) and
            i.id in type(^ids, {:array, :binary_id}) and
            not is_nil(o.comments_collected_at),
        select: type(i.id, :binary_id)
    )
    |> MapSet.new()
  end

  defp rotulo_da_conversa(:recente), do: "active discussion"
  defp rotulo_da_conversa(:antiga), do: "stale discussion"
  defp rotulo_da_conversa(:silencio), do: "silent"
  defp rotulo_da_conversa(:nao_coletada), do: "discussion not collected"

  defp frase_da_conversa(%{conversa: :recente, atos: atos, ultimo_ato: ultimo}),
    do:
      "#{atos} comment(s), last on #{Calendar.strftime(ultimo, "%Y-%m-%d")} — the work is alive; the record is not"

  defp frase_da_conversa(%{conversa: :antiga, atos: atos, ultimo_ato: ultimo}),
    do:
      "#{atos} comment(s), none since #{Calendar.strftime(ultimo, "%Y-%m-%d")} — discussed, then left"

  defp frase_da_conversa(%{conversa: :silencio}),
    do: "nobody has commented on it — decide whether it dies or comes back"

  defp frase_da_conversa(%{conversa: :nao_coletada}),
    do: "comments were never collected for this repository — silence here is not evidence"

  # A evolução por geração (#403): para os domínios do perfil VIGENTE, a contagem de
  # tarefas-evidência em cada geração da pessoa — a tabela somente-acréscimo é a série.
  # Domínio ausente numa geração antiga conta 0 ali: evidência ainda não nomeada, nunca
  # regressão. Sem perfil, nem consulta: o consumidor é a seção, e ela não renderiza.
  defp evolucao_do_perfil(_tenant, _person_id, nil), do: %{geracoes: [], series: []}

  defp evolucao_do_perfil(tenant, person_id, perfil) do
    historico =
      TheBand.Repo.all(
        from p in "eo_person_profiles",
          where:
            p.tenant_id == type(^tenant.id, :binary_id) and
              p.person_id == type(^person_id, :binary_id),
          order_by: [asc: p.generated_at],
          select: %{generated_at: p.generated_at, content: p.content}
      )

    geracoes = Enum.map(historico, &mes_da_geracao(&1.generated_at))

    contagens =
      Enum.map(historico, fn g ->
        Map.new(g.content["destaques"] || [], fn d -> {d["dominio"], d["tarefas"] || 0} end)
      end)

    series =
      for d <- perfil.content["destaques"] || [] do
        pontos = Enum.map(contagens, &Map.get(&1, d["dominio"], 0))

        %{
          nome: d["dominio"],
          pontos: pontos,
          primeiro: List.first(pontos, 0),
          ultimo: List.last(pontos, 0)
        }
      end

    %{geracoes: geracoes, series: series}
  end

  defp mes_da_geracao(%NaiveDateTime{} = dt),
    do: dt |> NaiveDateTime.to_date() |> Date.to_string() |> String.slice(0, 7)

  defp mes_da_geracao(%DateTime{} = dt),
    do: dt |> DateTime.to_date() |> Date.to_string() |> String.slice(0, 7)

  defp tendencia_da_serie(%{primeiro: p, ultimo: u}) when u > p, do: "▲"
  defp tendencia_da_serie(%{primeiro: p, ultimo: u}) when u < p, do: "▼"
  defp tendencia_da_serie(_), do: "—"

  # A polilinha da sparkline: x distribuído, y invertido (SVG cresce para baixo).
  defp pontos_da_serie(pontos) do
    maximo = max(Enum.max(pontos, fn -> 1 end), 1)
    n = max(length(pontos) - 1, 1)

    pontos
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {v, i} ->
      x = Float.round(i * 200 / n, 1)
      y = Float.round(23 - v / maximo * 20, 1)
      "#{x},#{y}"
    end)
  end

  defp forma_em_ingles("rala"), do: "thin"
  defp forma_em_ingles("envelhecida"), do: "stale"
  defp forma_em_ingles("trava"), do: "stuck"
  defp forma_em_ingles(outra), do: outra

  defp perfil_atual(tenant, person_id) do
    case EO.current_profile(tenant, person_id) do
      {:ok, perfil} -> perfil
      {:error, :not_found} -> nil
    end
  end

  # As quatro recusas têm quatro frases, porque são quatro fatos. E todas atribuem a falta ao
  # **registro** — "há pouco material registrado" e "esta pessoa produziu pouco" são frases
  # diferentes, e só a primeira é afirmável.
  defp recusa({:below_floor, %{com_corpo: com, piso: piso}}),
    do:
      "Only #{com} completed tasks carry a written description, and #{piso} are needed. " <>
        "This is a gap in what was recorded, not in what was done."

  defp recusa({:period_too_thin, %{contagens: c, piso: piso}}),
    do:
      "The record splits into #{Enum.join(c, "/")} tasks across the three periods, and each " <>
        "needs at least #{piso}. There is work here — there is not enough spread to speak of change."

  defp recusa({:no_text_to_compare, %{medianas: m}}),
    do:
      "Median description length per period is #{Enum.join(m, ", ")} characters. Without text " <>
        "there is no way to tell a change in this person from a change in how the team writes, " <>
        "and a profile without that comparison would assert more than the record supports."

  defp recusa(:no_assignment),
    do: "No current assignment observed for this person, so there is nothing to read from."

  defp recusa(outro), do: "Not available: #{inspect(outro)}"

  # A falha é nomeada, e não despejada. `inspect/1` de um erro do provedor pode trazer o
  # corpo inteiro da resposta para dentro de um flash.
  defp falha({:http, status, _msg}), do: "the provider answered #{status}"
  defp falha({:empty_response, _}), do: "the provider returned no text"
  defp falha({:network, _}), do: "the provider could not be reached"
  defp falha(:missing_credential), do: "no provider credential is configured"
  defp falha({:invalid_json, _}), do: "the provider answered outside the agreed format"
  defp falha(outro) when is_atom(outro), do: to_string(outro)
  defp falha(outro), do: recusa(outro)
end
