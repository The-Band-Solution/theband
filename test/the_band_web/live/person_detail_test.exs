defmodule TheBandWeb.PersonDetailTest do
  @moduledoc """
  A página da pessoa (T006 a T009).

  ## As três asserções que importam

  1. **o número proibido** — designação e autoria não somam, e o teste procura a soma. É o mesmo
     formato que na feature 006 achou um defeito real: eu exibia 39 ao lado de 9 e 30;
  2. **a palavra proibida** — nenhum texto chama nível de acesso de *role*;
  3. **a contagem de consultas** — oito, e não "um número que não cresce", que passa com 8 e com 80.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    {:ok, pessoa} = pessoa(tenant, "ana")
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario, pessoa: pessoa}
  end

  describe "a página abre" do
    test "com identidade e proveniência", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Ana"
      assert html =~ "U_ana"
      assert html =~ "github"
    end

    test "o nome na lista é link para ela", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people")

      assert html =~ ~p"/people/#{ctx.pessoa.id}", """
      O nome da pessoa não é link, e não existe para onde ir — é o estado de antes desta feature.
      """
    end

    test "pessoa de outro tenant responde não encontrado", ctx do
      # `tenant_with_admin/1` porque `ConnCase` não importa `user_fixture` — e o outro tenant precisa
      # de alguém autenticado para a requisição existir.
      {_outro, outro_user} = tenant_with_admin("outro")
      conn = log_in(build_conn(), outro_user)

      assert {:error, {:live_redirect, %{to: "/people", flash: flash}}} =
               live(conn, ~p"/people/#{ctx.pessoa.id}")

      assert flash["error"] =~ "not found", """
      A mensagem precisa ser **não encontrado**, nunca "sem permissão": confirmar existência já é
      vazamento entre tenants.
      """

      refute flash["error"] =~ "permission"
    end
  end

  describe "as equipes, e o que a plataforma recusou promover" do
    setup ctx do
      org = organization_fixture(ctx.tenant, "acme")
      time = equipe(ctx.tenant, org, "core")
      evidenciar(ctx.tenant, ctx.pessoa, time, "MAINTAINER")
      Map.put(ctx, :time, time)
    end

    test "diz que a evidência não foi promovida, e por quê", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "Core"
      assert html =~ "MAINTAINER"

      assert html =~ "no role is registered yet", """
      A página mostrou a equipe e **não** disse que a plataforma não promoveu o vínculo, nem por quê.

      São 88 evidências e zero vínculos no dado real. Sem a explicação, a tela afirma um vínculo que
      a plataforma recusou — ou faz a recusa parecer defeito.
      """
    end

    test "a explicação MUDA quando existe papel cadastrado", ctx do
      papel(ctx.tenant, "scrum_master")

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      refute html =~ "no role is registered yet", """
      A explicação não mudou depois de um papel ser cadastrado, o que significa que ela é **texto
      fixo**.

      Texto fixo passa a mentir no dia em que a causa muda, e ninguém nota — a frase continua
      plausível. É por isso que o motivo vem do dado.
      """

      assert html =~ "nobody assigned one to this person"
    end

    test "nenhum texto chama nível de acesso de papel", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      [secao] = Regex.run(~r/Teams the source declares.{0,2000}/s, html)

      refute secao =~ ~r/\brole\b/i and not (secao =~ "organisational role") and
               not (secao =~ "not a role"),
             """
             A seção de equipes usa a palavra *role* para o nível de acesso.

             `MAINTAINER` é permissão **na ferramenta**; `sro.scrum_master` é papel **do processo**. Mapear
             um no outro é mapear por semelhança de nome, e contamina toda medida derivada.
             """
    end

    test "o vínculo que saiu aparece, com a data", ctx do
      marcar_ausente(ctx.tenant, ctx.pessoa, ctx.time)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "was in this team until", """
      O vínculo que deixou de ser observado desapareceu, ou aparece como atual.

      **Houve** vínculo e ele não está presente — as duas coisas juntas. Omitir faria a pessoa
      parecer nunca ter estado na equipe.
      """
    end

    test "os três estados se distinguem com a cor removida", ctx do
      [uma | _] = issues(ctx.cenario)
      designar(ctx.tenant, uma, ctx.pessoa)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      formas =
        Regex.scan(~r/class="([^"]*size-2\.5[^"]*)"/, html)
        |> Enum.map(fn [_, classes] ->
          classes
          |> String.split()
          |> Enum.reject(&String.starts_with?(&1, ["text-", "bg-current"]))
          |> Enum.sort()
        end)
        |> Enum.uniq()

      assert length(formas) >= 2, """
      As formas não se distinguem sem a cor: #{inspect(formas)}.

      Observado, derivado e ausente precisam ser distinguíveis por **forma e texto** — cor não conta
      como canal, WCAG 1.4.1.
      """
    end
  end

  describe "o trabalho, sem somar" do
    test "mostra os dois números e NUNCA a soma", ctx do
      issues = issues(ctx.cenario)
      {designadas, restantes} = Enum.split(issues, 4)
      autoradas = Enum.take(restantes, 3)

      Enum.each(designadas, &designar(ctx.tenant, &1, ctx.pessoa))
      Enum.each(autoradas, &autorar(ctx.tenant, &1, ctx.pessoa))

      assert WorkItems.count_assigned_to(ctx.tenant, ctx.pessoa.id) == 4
      assert WorkItems.count_authored_by(ctx.tenant, ctx.pessoa.id) == 3

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ ">4<"
      assert html =~ ">3<"

      refute html =~ ">7<", """
      A página exibiu **7**, que é a soma de 4 designações com 3 autorias.

      Esse número não corresponde a nada: quem abre uma issue não necessariamente trabalha nela. É o
      mesmo defeito que a feature 006 pegou com `refute html =~ ">39<"` — e lá o número somado
      estava na tela porque eu o tinha colocado.
      """
    end

    test "o repositório aparece com nome e como derivado", ctx do
      [uma | _] = issues(ctx.cenario)
      designar(ctx.tenant, uma, ctx.pessoa)

      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "theband", """
      A linha do repositório precisa do **nome**, e não do identificador.

      O nome é de CMPO — a terceira fronteira, que a análise achou faltando — e vem de uma consulta
      virando mapa.
      """

      assert html =~ "derived from assignments", """
      O vínculo pessoa-repositório é **derivado**: a origem nunca o declarou. A página precisa dizer
      de qual evidência ele vem.
      """
    end

    test "as ausências são nomeadas, e não um zero solto", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

      assert html =~ "No issue assigns this person"

      assert html =~ "No issue was opened by this person", """
      Pessoa sem designação e sem autoria precisa ter as **duas** ausências nomeadas. Um `0` solto
      não distingue "não trabalhou" de "a plataforma não sabe".
      """
    end
  end

  describe "o custo da página" do
    test "a página acrescenta oito consultas, e o número não cresce com o dado", ctx do
      issues = issues(ctx.cenario)
      Enum.each(issues, &designar(ctx.tenant, &1, ctx.pessoa))

      # A medida é a **diferença** contra a lista de pessoas, e não o total. Medido em 2026-08-12:
      # `live/2` na lista faz 16 consultas e na página faz 24 — e as 16 são framework e
      # autenticação, em dois renders. A diferença isola o custo **da página**.
      lista = contar_consultas(fn -> live(ctx.conn, ~p"/people") end)
      poucas = contar_consultas(fn -> live(ctx.conn, ~p"/people/#{ctx.pessoa.id}") end)

      # Agora com muito mais trabalho: as partes das issues, todas designadas à mesma pessoa.
      Enum.each(partes(ctx.cenario), &designar(ctx.tenant, &1, ctx.pessoa))
      muitas = contar_consultas(fn -> live(ctx.conn, ~p"/people/#{ctx.pessoa.id}") end)

      assert poucas == muitas, """
      A página fez #{poucas} consultas com poucas issues e #{muitas} com muitas — ela consulta por
      linha.

      É a asserção que mais importa das duas: é o defeito que a feature 007 pagou com 135 consultas
      por render, e o FR-016 existe por causa dele.
      """

      acrescentadas = div(poucas - lista, 2)

      assert acrescentadas <= 8, """
      A página acrescentou #{acrescentadas} consultas por render sobre a lista de pessoas, e o plano
      declara **oito**.

      A conta: `live/2` faz dois renders, então a diferença total (#{poucas} − #{lista}) é dividida
      por dois. "Um número que não cresce" passa com 8 e passa com 80 — por isso o teto é asserido.
      """
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp contar_consultas(fun) do
    ref = make_ref()
    pai = self()

    # **As tabelas do Oban ficam de fora, e não é detalhe.** O handler é global: conta toda consulta
    # do BEAM, e o `Oban.Stager` consulta `oban_jobs` a cada segundo. Um tick dentro da janela vira
    # uma consulta a mais atribuída à página — e o teste reprova com o código certo, em máquina
    # carregada e não na minha. É a L42: mensagem que chega fora de hora entra na contagem errada.
    ignoradas = ~w(oban_jobs oban_peers schema_migrations)

    # A `source` não basta: o Oban consulta por SQL cru, e aí ela vem nula enquanto o texto da
    # consulta diz `oban_jobs`. Sob cobertura a janela alarga, o tick cai dentro dela, e o teste
    # reprova por uma consulta que a tela não fez — foi o que derrubou o job de cobertura no PR
    # #297, com 30 contra 31.
    handler = fn _event, _measures, %{query: query} = meta, _config ->
      if String.starts_with?(query, "SELECT") and to_string(meta[:source]) not in ignoradas and
           not String.contains?(query, "oban_"),
         do: send(pai, {ref, :consulta})
    end

    :telemetry.attach({__MODULE__, ref}, [:the_band, :repo, :query], handler, nil)
    {:ok, _live, _html} = fun.()
    :telemetry.detach({__MODULE__, ref})

    drenar(ref, 0)
  end

  defp drenar(ref, n) do
    receive do
      {^ref, :consulta} -> drenar(ref, n + 1)
    after
      0 -> n
    end
  end

  defp issues(cenario) do
    cenario.issues |> Map.values() |> Enum.map(& &1.pai) |> Enum.sort_by(& &1.number)
  end

  defp partes(cenario) do
    cenario.issues |> Map.values() |> Enum.flat_map(& &1.partes)
  end

  defp pessoa(tenant, login) do
    EO.upsert_person_from_source(tenant, %{
      login: login,
      name: String.capitalize(login),
      account_type: "person",
      source_system: "github",
      source_instance: "https://github.com",
      external_id: "U_#{login}",
      collected_at: DateTime.utc_now(:second)
    })
  end

  defp equipe(tenant, org, slug) do
    {:ok, time} =
      EO.upsert_team_from_source(tenant, %{
        organization_id: org.id,
        name: String.capitalize(slug),
        slug: slug,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "T_#{slug}",
        collected_at: DateTime.utc_now(:second)
      })

    time
  end

  defp evidenciar(tenant, pessoa, time, nivel) do
    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: time.id,
        person_external_id: pessoa.external_id,
        team_external_id: time.external_id,
        platform_access_level: nivel,
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second),
        last_observed_at: DateTime.utc_now(:second)
      })
  end

  defp marcar_ausente(tenant, pessoa, time) do
    import Ecto.Query

    Repo.update_all(
      from(e in "eo_team_membership_evidence",
        where:
          e.tenant_id == type(^tenant.id, :binary_id) and
            e.person_id == type(^pessoa.id, :binary_id) and
            e.team_id == type(^time.id, :binary_id)
      ),
      set: [no_longer_observed_at: DateTime.utc_now(:second)]
    )
  end

  defp papel(tenant, code) do
    Repo.insert_all("eo_organizational_roles", [
      %{
        id: Ecto.UUID.bingenerate(),
        tenant_id: Ecto.UUID.dump!(tenant.id),
        internal_id: code,
        record_version: 1,
        code: code,
        name: String.capitalize(code),
        inserted_at: DateTime.utc_now(:second),
        updated_at: DateTime.utc_now(:second)
      }
    ])
  end

  defp designar(tenant, issue, pessoa) do
    {:ok, _} =
      WorkItems.replace_assignees(tenant, issue.id, [
        %{login: pessoa.login, person_id: pessoa.id}
      ])
  end

  defp autorar(tenant, issue, pessoa) do
    {:ok, _} =
      WorkItems.record_collected_issue(tenant, %{
        observed_repository_id: issue.observed_repository_id,
        number: issue.number,
        title: issue.title,
        state: issue.state,
        issue_type: issue.issue_type,
        author_login: pessoa.login,
        author_person_id: pessoa.id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: issue.external_id
      })
  end
end
