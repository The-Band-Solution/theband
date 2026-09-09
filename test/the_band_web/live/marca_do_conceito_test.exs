defmodule TheBandWeb.MarcaDoConceitoTest do
  @moduledoc """
  A marca do conceito na seção *What each person is on* — pedido da pessoa mantenedora em
  2026-09-08: *"remova os IDs como esse `I_kwDON0TQIs6vA1ZX` na frente das US de cada pessoa
  na tela da equipe e adicione se é um TASK, US ou EPIC"*.

  ## As duas asserções que carregam este arquivo

  1. **o identificador da origem sai da tela.** `I_kwDON0TQIs6vA1ZX` é o `node_id` do GraphQL
     do GitHub: identifica a issue na origem e não diz nada a quem lê. Ocupava o lugar da
     informação que importa antes do título — *o que este item é*;
  2. **a marca vem da PROMOÇÃO**, e não do tipo declarado na origem. A regra
     `github.issue_type_routing` tem precedência `structure_over_declaration`: uma issue tipo
     `Feature` com partes que são user stories é **épico**, e a mesma sem partes é user story
     **atômica**. Nesta base o tipo declarado é nulo em 778 dos 1154 itens abertos, e a
     promoção classifica todos.

  ## E a que ninguém pediu

  `osdef.defect` — **BUG** — aparece com as três. Não estava no pedido e não pode ser
  escondida: são 71 itens abertos no banco de desenvolvimento, e chamá-los de tarefa
  afirmaria algo que a promoção não afirma.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee
  alias TheBand.WorkItems.Schemas.IssuePromotion

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    org = cenario.organization
    {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Plataforma", admin.id)
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    {:ok, ana} =
      EO.upsert_person_from_source(tenant, %{
        login: "ana",
        name: "Ana",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/ana",
        external_id: "U_ana",
        collected_at: DateTime.utc_now(:second),
        payload: %{}
      })

    {:ok, _} =
      EO.declare_role(tenant, equipe.id, ana.id, {:existente, papel.id}, admin.id,
        started_at: DateTime.add(DateTime.utc_now(:second), -300, :day)
      )

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      equipe: equipe,
      ana: ana,
      repo_id: cenario.observed_repository_id
    }
  end

  # O `external_id` é deliberadamente o formato REAL do GitHub — é o que a pessoa
  # mantenedora viu na tela, e é o que este arquivo garante que não volta.
  defp issue(ctx, external_id, conceito, opts \\ []) do
    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: external_id,
        number: :erlang.phash2(external_id, 100_000),
        source_system: "github",
        source_instance: "https://github.com",
        # O título NÃO carrega o `external_id`. Na primeira versão deste arquivo ele carregava,
        # e o `refute` falhava — por culpa do fixture, não da tela. Um teste que planta o que
        # vai procurar não prova nada.
        title: "o título que importa",
        state: "OPEN",
        # O tipo DECLARADO na origem — e a promoção pode discordar dele.
        issue_type: opts[:issue_type],
        external_created_at: DateTime.add(DateTime.utc_now(:second), -10, :day),
        collected_at: DateTime.utc_now(:second)
      })

    Repo.insert!(%IssueAssignee{
      tenant_id: ctx.tenant.id,
      collected_issue_id: i.id,
      login: ctx.ana.login,
      person_id: ctx.ana.id
    })

    if conceito do
      Repo.insert!(%IssuePromotion{
        tenant_id: ctx.tenant.id,
        collected_issue_id: i.id,
        declared_concept: opts[:declarado],
        derived_concept: conceito,
        rule_id: "github.issue_type_routing",
        rule_version: 1,
        promoted_at: DateTime.utc_now(:second)
      })
    end

    i
  end

  defp painel(ctx), do: live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

  describe "o identificador da origem sai da tela" do
    test "o node_id do GitHub não aparece, e o título continua", ctx do
      issue(ctx, "I_kwDON0TQIs6vA1ZX", "sro.atomic_user_story")

      {:ok, _live, html} = painel(ctx)

      refute html =~ "I_kwDON0TQIs6vA1ZX", """
      O `node_id` do GraphQL identifica a issue na ORIGEM e não diz nada a quem lê a tela.
      Ocupava o lugar da informação que importa antes do título — o que o item é.
      """

      assert html =~ "o título que importa", "o título tem de continuar"
    end
  end

  describe "a marca diz o que o item é (US, EPIC, TASK)" do
    test "as três marcas do pedido aparecem, cada uma no seu item", ctx do
      issue(ctx, "I_us", "sro.atomic_user_story")
      issue(ctx, "I_epic", "sro.epic")
      issue(ctx, "I_task", "sro.intended_scrum_development_task")

      {:ok, _live, html} = painel(ctx)

      assert html =~ ">US<" or html =~ "US\n"
      assert html =~ "EPIC"
      assert html =~ "TASK"
    end

    test "cada marca traz o significado em texto, e não só a sigla", ctx do
      issue(ctx, "I_epic", "sro.epic")
      issue(ctx, "I_us", "sro.atomic_user_story")
      issue(ctx, "I_task", "sro.intended_scrum_development_task")

      {:ok, _live, html} = painel(ctx)

      # Três letras sozinhas não ensinam nada a quem chega. O significado vem do `title`, e
      # é o da própria ontologia — não uma paráfrase.
      assert html =~ "a user story with parts", "EPIC sem o que o torna épico"
      assert html =~ "no parts"

      assert html =~ "declared, not necessarily executed", """
      `sro.intended_scrum_development_task` é tarefa PRETENDIDA. Chamá-la de "task" sem dizer
      isso apagaria a distinção que o conceito carrega: issue aberta declara intenção, e issue
      fechada não basta para afirmar execução.
      """
    end

    test "BUG aparece com as três, embora não estivesse no pedido", ctx do
      issue(ctx, "I_bug", "osdef.defect")

      {:ok, _live, html} = painel(ctx)

      assert html =~ "BUG", """
      `osdef.defect` não estava no pedido e não pode ser escondido: são 71 itens abertos no
      banco de desenvolvimento. Chamá-los de tarefa afirmaria algo que a promoção não afirma,
      e omiti-los deixaria o item sem marca alguma.
      """
    end
  end

  describe "a marca vem da PROMOÇÃO, e não do tipo declarado" do
    test "tipo Feature promovido a épico mostra EPIC, e não Feature", ctx do
      # É o caso que a regra `github.issue_type_routing` decide por estrutura: `Feature` com
      # partes que são user stories é épico. A precedência é `structure_over_declaration`.
      issue(ctx, "I_feature_epic", "sro.epic", issue_type: "Feature", declarado: "Feature")

      {:ok, _live, html} = painel(ctx)

      assert html =~ "EPIC"

      refute html =~ ">Feature<", """
      O tipo declarado na origem NÃO é a marca. A regra declara precedência
      `structure_over_declaration`: `Feature` com partes que são user stories é épico, e a
      mesma sem partes é atômica. Mostrar o rótulo da origem desfaria a decisão que a
      promoção tomou.
      """
    end

    test "item SEM promoção diz a ausência, e não supõe tarefa", ctx do
      issue(ctx, "I_sem_promocao", nil)

      {:ok, _live, html} = painel(ctx)

      assert html =~ "the mapping rule did not classify this item", """
      Item sem promoção é o que a regra não classificou — tipo nulo na origem e estrutura que
      não decide. A tela nomeia a ausência em vez de supor tarefa: "chutar aqui contamina toda
      medida de escopo", diz o `fallback_rationale` da própria regra.
      """

      refute html =~ "TASK", "a ausência foi lida como tarefa"
    end

    test "a família do conceito não usa MATIZ de origem nem de estado (Design, 2026-09-08)",
         ctx do
      issue(ctx, "I_us", "sro.atomic_user_story")
      issue(ctx, "I_epic", "sro.epic")
      issue(ctx, "I_task", "sro.intended_scrum_development_task")

      {:ok, _live, html} = painel(ctx)

      # O RECORTE É A MARCA, e não a seção.
      #
      # A primeira versão desta asserção cortava em "What each person is on" e ia até o fim da
      # página — e falhava em `badge-warning`, que está ali de facto: é a marca de **parada**
      # do próprio item. Afirmar sobre a seção afirmava sobre badges que não são o conceito.
      #
      # A marca tem prefixo de classe próprio, e é sobre ele que se afirma.
      marcas = Regex.scan(~r/class="(badge badge-sm font-mono[^"]*)"/, html)
      assert marcas != [], "não achei nenhuma marca de conceito na página"

      classes = Enum.map_join(marcas, " ", &List.last/1)

      # A regra que o Design fixou: **matiz pertence à origem e ao estado**. Não havia matiz
      # livre — azul `info` é *declared*, âmbar é *stale* e habilidade derivada, verdete é
      # *observado/declarado*. Tomar uma delas faria 760 chips afirmarem sobre a taxonomia o
      # que a cor afirma sobre a origem.
      #
      # A distinção é por FORMA: `badge-soft`, que não era usado em lugar nenhum de
      # `lib/the_band_web/`, é a família inteira do conceito.
      assert classes =~ "badge-soft", "a família do conceito perdeu a forma que a distingue"

      for matiz <- ["badge-info", "badge-primary", "badge-success", "badge-warning"] do
        refute classes =~ matiz, """
        `#{matiz}` na marca do conceito toma uma matiz que já significa origem ou estado nesta
        plataforma. A escada do escopo é peso e preenchimento, não cor.

        As classes das marcas nesta página: #{classes}
        """
      end
    end

    test "badge-ghost saiu da marca — era a queixa, e o motivo é mecânico", ctx do
      issue(ctx, "I_task", "sro.intended_scrum_development_task")
      issue(ctx, "I_sem", nil)

      {:ok, _live, html} = painel(ctx)

      classes =
        Regex.scan(~r/class="(badge badge-sm font-mono[^"]*)"/, html)
        |> Enum.map_join(" ", &List.last/1)

      refute classes =~ "badge-ghost", """
      `badge-ghost` é `base-200` sobre `base-100`: 3% de diferença no tema claro, e no escuro o
      chip fica **mais escuro** que a base e lê como buraco. Era exatamente a queixa da pessoa
      mantenedora — "tá sem cor".
      """
    end

    test "as duas ignorâncias têm cláusulas diferentes, e antes dividiam a mesma", ctx do
      issue(ctx, "I_novo", "sro.conceito_que_ninguem_traduziu")
      issue(ctx, "I_sem", nil)

      {:ok, _live, html} = painel(ctx)

      # Conceito que existe e ninguém traduziu ≠ item que a regra não classificou. As duas são
      # tracejadas — tracejado é o *absent* da casa — e se separam pela opacidade.
      assert html =~ "badge-dash text-base-content/80", "o conceito sem tradução"
      assert html =~ "badge-dash text-base-content/60", "o item sem classificação"
    end

    test "conceito novo na base aparece com o identificador, e não em branco", ctx do
      issue(ctx, "I_novo", "sro.conceito_que_ninguem_traduziu")

      {:ok, _live, html} = painel(ctx)

      assert html =~ "sro.conceito_que_ninguem_traduziu", """
      Conceito sem tradução aparece COMO ESTÁ. Desaparecer da tela seria pior que aparecer
      sem tradução — é a mesma decisão de `ConceptLabel`.
      """
    end
  end
end
