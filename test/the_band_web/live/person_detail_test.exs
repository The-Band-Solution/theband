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

    # Issue #369: sem o elo a aba de trabalho fecha, e o teste mediria a tela errada.
    elo_de_identidade(tenant, user, pessoa)

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
      papel(ctx.tenant, organization_fixture(ctx.tenant, "papeis"), "scrum_master")

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
      q_lista = contar_consultas(fn -> live(ctx.conn, ~p"/people") end)
      q_poucas = contar_consultas(fn -> live(ctx.conn, ~p"/people/#{ctx.pessoa.id}") end)

      # Agora com muito mais trabalho: as partes das issues, todas designadas à mesma pessoa.
      Enum.each(partes(ctx.cenario), &designar(ctx.tenant, &1, ctx.pessoa))
      q_muitas = contar_consultas(fn -> live(ctx.conn, ~p"/people/#{ctx.pessoa.id}") end)

      {lista, poucas, muitas} = {length(q_lista), length(q_poucas), length(q_muitas)}

      assert poucas == muitas, """
      A página fez #{poucas} consultas com poucas issues e #{muitas} com muitas — ela consulta por
      linha.

      É a asserção que mais importa das duas: é o defeito que a feature 007 pagou com 135 consultas
      por render, e o FR-016 existe por causa dele.

      O que mudou entre as duas medições:

      #{diferenca(q_poucas, q_muitas)}
      """

      acrescentadas = div(poucas - lista, 2)

      # **A linha de base subiu de 8 para 15, e as sete têm nome.**
      #
      # A feature 023 acrescentou o painel da pessoa, e cada medida é uma consulta:
      #
      #   1. cobertura da timeline — observadas e total **numa consulta só**;
      #   2. concluídas por mês;
      #   3. idade do trabalho aberto;
      #   4. lead time;
      #   5. as issues designadas, para a avaliação de antipadrão;
      #   6. os designados delas, em lote;
      #   7. as atividades delas, em lote.
      #
      # As três últimas são a US4, e o lote é o ponto: `detect/2` por issue seriam 152
      # consultas numa pessoa real. **A asserção acima é a que prova isso** — `poucas ==
      # muitas` depois de designar todas as partes.
      #
      # **E de 15 para 18 na feature 026**, com as três nomeadas:
      #
      #   8. o perfil vigente da pessoa — existe, ou não;
      #   9. quando **não** existe: há geração pendente, e há material para gerar;
      #  10. as tarefas designadas e abertas há mais que o limiar.
      #
      # A décima vale **sempre**, e não só quando há perfil: a lista é sobre o trabalho da
      # pessoa, e não sobre o perfil dela. Ela morava dentro do cartão do perfil, cercada de
      # blocos hachurados, e é fato observado — misturava proveniência num produto que existe
      # para separar as duas.
      #
      # Derivá-la da tabela de issues que a página já lista seria melhor, e **não dá**: a
      # tabela é paginada, e a lista precisa do conjunto inteiro.
      #
      # A nona é duas perguntas numa consulta cada. `check` só acontece quando **não** há
      # perfil — com perfil a recusa não é exibida, e pagá-la seria custo por render sem
      # consumidor.
      #
      # **Há uma décima que este teste não mede, e dizê-lo é o que mantém a conta honesta.**
      # `tasks_since/3` conta quantas tarefas fecharam desde o recorte gravado, e só roda
      # quando existe perfil — a pessoa deste cenário não tem. Então o pior caso real é 18,
      # não 17, e ele acontece na página de quem já tem perfil.
      #
      # Medir os dois cenários exigiria gerar um perfil aqui, o que traria a borda do
      # provedor para dentro de um teste de custo de página. A troca é consciente: o que o
      # guard protege é o número **não crescer com o dado**, e nenhuma das dez cresce.
      #
      # **A primeira versão desta seção custava três a mais, e este teste pegou.** A tela
      # chamava `Material.build/2` para decidir se mostrava um botão — quatro consultas, e
      # com elas o texto inteiro das tarefas, a cada render. Virou `Material.check/2`, que
      # traz só o tamanho de cada corpo. A tentação era subir o teto; o defeito era da tela.
      #
      # **E de 18 para 19 na feature 030**, com a décima primeira nomeada:
      #
      #  11. a participação em discussões — as issues em que a pessoa comentou, agregadas
      #      por issue numa consulta só (`Discussions.participation_of/3`).
      #
      # Ela vale **sempre**, como a décima: é o trabalho que designação nenhuma registra,
      # e sete das 24 pessoas sem designação do tenant real só aparecem por ela. Agregar
      # por issue no banco é o que a mantém em uma: uma consulta por discussão seriam 50
      # numa pessoa real.
      #
      # A classificação das paradas (silêncio × conversa antiga × recente) NÃO acrescenta:
      # ela reusa `last_act_for_issues/2` para todas as paradas de uma vez, e a consulta
      # de quais repositórios têm comentários coletados entra no mesmo par de renders.
      #
      # **E de 19 para 22 na feature 032**, com as três nomeadas — e elas são três porque
      # a ontologia separa três atos:
      #
      #  12. as solicitações que a pessoa ABRIU (cmpo.stakeholder_submitted_change_request);
      #  13. as que ela INTEGROU (cmpo.stakeholder_performed_checkin);
      #  14. os commits que ela EXECUTOU (cmpo.stakeholder_performed_commit), incluindo
      #      aqueles em que é co-autora.
      #
      # Uma consulta só, com `union`, juntaria o que a rede separa: submeter, integrar e
      # commitar são participações distintas, e a tela as mostra distintas. O custo de
      # três é o preço de não achatar — e nenhuma delas cresce com o dado.
      #
      # **E de 23 para 26 pela feature 044**, com TRÊS — e o plano tinha previsto duas.
      #
      # O erro de contagem está registrado porque é instrutivo: `plan.md` mediu os dois
      # AGREGADOS e esqueceu a listagem, que a tarefa T004 acrescentou depois. A conta certa
      # só apareceu rodando este teste, que é para o que ele serve.
      #
      #  17. a participação da pessoa na solicitação de mudança —
      #      `Changes.participacao_da_pessoa/2`. Devolve SEIS contagens numa consulta:
      #      abriu, revisou, integrou, e os três vereditos. Seis consultas levariam a
      #      página a 30, e o `filter (where ...)` do Postgres responde numa passagem;
      #
      #  18. a listagem das solicitações que a pessoa REVISOU — o terceiro papel em
      #      `Changes.by_person/3`, que já listava abriu e integrou;
      #
      #  19. o desfecho das verificações sobre os commits dela —
      #      `Verification.por_pessoa/2`. Devolve QUATRO números numa consulta: passou,
      #      quebrou, outras, e a parcela do tenant sem autoria identificada.
      #
      #      O primeiro desenho usava duas — `join` para os números dela, e uma segunda
      #      passagem para a parcela do tenant. `left_join` nos três responde tudo numa,
      #      e a página baixou de 27 para 26.
      #
      # **Não dava para derivar nenhuma das duas.** Nenhuma consulta desta página tocava
      # `collected_change_requests` com filtro de pessoa: `mudancas` traz as listas, e não
      # as contagens; e a contagem sobre a lista mentiria, porque a lista é truncada em 10.
      #
      # **E de 22 para 23 pelo burn-down**, com uma consulta e uma só:
      #
      #  16. até quando o trabalho ABERTO desta pessoa foi planejado —
      #      `prazo_do_trabalho_aberto/2`, o `data_end` da decisão de 2026-08-27.
      #
      # Ela devolve TRÊS respostas numa consulta: o maior `ended_on` entre as caixas do
      # trabalho aberto, quantas issues abertas não estão em caixa nenhuma, e se aquelas
      # caixas são sprint ou horizonte de planejamento (issue #514). Uma consulta por
      # resposta seriam três.
      #
      # **Não dava para derivar.** As séries por período saem de `collected_issues`, e
      # nenhuma consulta desta página tocava `sro_sprints` para esta pessoa. O burn-up e o
      # burn-down em si DERIVAM — `burn/1` e `projecao/1` acumulam a série em memória, e
      # custam zero. Foi a saída tentada primeiro, e ela não alcança uma data declarada.
      #
      # **E a vaga anterior foi ocupada pela #369**, com uma consulta e não três:
      #
      #  15. as contas do tenant — `Tenants.list_users/1`.
      #
      # Ela serve TRÊS coisas na tela do elo: a lista para escolher qual conta é esta
      # pessoa, qual delas já é, e a cobertura (`0 de 2`). Uma consulta por resposta seriam
      # três, e o primeiro desenho fez isso — o teto acusou em 24, e as outras duas passaram
      # a sair em memória das contas que já vieram inteiras.
      #
      # **A página está agora EXATAMENTE no teto.** A próxima consulta acrescentada aqui
      # reprova este teste, e é de propósito: quem acrescentar decide entre justificar o
      # acréscimo e nomeá-lo, ou derivar do que já foi carregado — como a #369 fez, e como
      # o burn-up e o burn-down fizeram.
      #
      # Subir o teto sem essa conta seria enfraquecer o gate, e é antipadrão declarado neste
      # projeto. O que o mantém honesto é o número ser medido e cada acréscimo nomeado.
      assert acrescentadas <= 27, """
      A página acrescentou #{acrescentadas} consultas por render sobre a lista de pessoas, e a
      linha de base medida é **vinte e sete** — oito da tela original, sete do painel da
      023, três do perfil da 026, uma da participação em discussões da 030, três das
      mudanças da 032 (abriu, integrou, commitou — a rede separa os três atos), uma da #369
      (as contas do tenant, que servem a escolha, o elo vigente e a cobertura de uma vez),
      uma do burn-down (o `data_end` do trabalho aberto), **três da feature 044** (a
      participação na mudança com seis contagens numa só, a listagem das revisadas, e o
      desfecho das verificações com quatro números numa só), e **uma da feature 048** (o
      estado da chave do provedor, que os botões de geração dizem ANTES do clique — sem
      derivação possível: a credencial não sai de nenhuma consulta que a página já faz).

      A página está EXATAMENTE no teto. Se tu acrescentou uma consulta, a primeira saída é
      derivar do que já foi carregado — foi o que o burn-up e o burn-down fizeram, e por isso
      custaram zero. Subir o número só depois de essa saída não existir, e nomeando a conta.

      O que a página faz além da lista:

      #{diferenca(q_lista, q_poucas)}

      A conta: `live/2` faz dois renders, então a diferença total (#{poucas} − #{lista}) é dividida
      por dois. "Um número que não cresce" passa com 8 e passa com 80 — por isso o teto é asserido.
      """
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp contar_consultas(fun) do
    TheBand.ContadorDeConsultas.listar(fn ->
      {:ok, _live, _html} = fun.()
    end)
  end

  # A diferença entre duas medições, com o que entrou e o que saiu.
  defp diferenca(antes, depois) do
    a = Enum.frequencies(antes)
    d = Enum.frequencies(depois)

    (Map.keys(a) ++ Map.keys(d))
    |> Enum.uniq()
    |> Enum.map(fn k -> {k, Map.get(d, k, 0) - Map.get(a, k, 0)} end)
    |> Enum.reject(fn {_k, delta} -> delta == 0 end)
    |> Enum.sort_by(fn {_k, delta} -> -abs(delta) end)
    |> Enum.map_join("\n", fn {k, delta} ->
      "  #{String.pad_leading("#{if delta > 0, do: "+", else: ""}#{delta}", 4)}  #{k}"
    end)
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

  # Inserção direta: o teste quer a linha, não o fluxo. Desde a issue #317 a linha exige
  # `organization_id` e **uma origem** — aqui vale o conceito da rede, porque `scrum_master` é
  # um dos quatro que a SRO nomeia.
  defp papel(tenant, organization, code) do
    Repo.insert_all("eo_organizational_roles", [
      %{
        id: Ecto.UUID.bingenerate(),
        tenant_id: Ecto.UUID.dump!(tenant.id),
        organization_id: Ecto.UUID.dump!(organization.id),
        internal_id: code,
        record_version: 1,
        code: code,
        name: String.capitalize(code),
        catalog_concept_id: "sro.#{code}_role",
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
