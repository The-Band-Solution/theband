defmodule TheBandWeb.TeamsLive.MedidasDaEquipeTest do
  @moduledoc """
  As três medidas na tela da equipe — feature 058.

  Cada asserção aqui existe porque a ausência da frase correspondente seria
  **invisível**: a tela continuaria bonita, com números que afirmam mais do que a
  plataforma sabe.

  | o que o teste protege | requisito |
  |---|---|
  | quem trabalhou no projeto, com as equipes por onde chegou | FR-007, SC-004 |
  | a marca do período parcialmente desconhecido, **nomeando a borda** | FR-009, SC-005 |
  | a ausência dita em texto, e não lista vazia | FR-011 |
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Quality.Commands, as: QualityCommands
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Verification.Commands, as: VerificationCommands

  setup %{conn: conn} do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    org = cenario.organization
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)
    {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Dados", admin.id)

    %{
      conn: log_in(conn, admin),
      tenant: tenant,
      admin: admin,
      org: org,
      papel: papel,
      equipe: equipe,
      repo_id: cenario.observed_repository_id
    }
  end

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => login}
      })

    p
  end

  # `started_at` nulo é **desconhecido**, e é a única ponta que produz dúvida —
  # `linked_at` é NOT NULL nas duas tabelas de projeto (R2a).
  defp vincular(ctx, equipe, pessoa, desde) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: ctx.papel.id,
        started_at: desde
      })
  end

  defp projeto_ligado(ctx, nome, equipe) do
    {:ok, projeto} = SPO.create_project(ctx.tenant, %{name: nome}, ctx.admin.id)
    {:ok, v} = SPO.link_team(ctx.tenant, projeto.id, equipe.id, ctx.admin.id)
    {projeto, v}
  end

  # O vínculo equipe ↔ projeto nasce com `linked_at` = agora. Para montar a matriz
  # de datas à mão, o teste ajusta a coluna direto — a mesma técnica do teste da
  # consulta, e pela mesma razão: o período é o que está sob teste.
  defp periodo_do_vinculo(vinculo, desde, ate) do
    Repo.update_all(
      from(x in "spo_project_teams", where: x.id == type(^vinculo.id, :binary_id)),
      set: [linked_at: desde, unlinked_at: ate]
    )
  end

  defp dias_atras(n), do: DateTime.add(DateTime.utc_now(:second), -n, :day)

  describe "quem trabalhou no projeto (US2)" do
    test "lista as pessoas com as equipes por onde chegaram", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      {_projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)

      {:ok, live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#quem-trabalhou") |> render()

      assert html =~ "Who worked on these projects"
      # Escopado: "ana" também está na tabela de membros, e sobre a página inteira a
      # asserção passaria com a seção vazia.
      assert secao =~ "Alfa"
      assert secao =~ "ana"
      assert secao =~ "via Dados"
    end

    test "a mesma pessoa por duas equipes aparece uma vez, com as duas nomeadas", ctx do
      {:ok, outra} =
        EO.declare_structural_team(ctx.tenant, ctx.org.id, "Plataforma", ctx.admin.id)

      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      vincular(ctx, outra, ana, dias_atras(200))

      {projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)
      {:ok, _} = SPO.link_team(ctx.tenant, projeto.id, outra.id, ctx.admin.id)

      {:ok, live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      linhas =
        live
        |> element("#quem-trabalhou")
        |> render()
        |> then(&Regex.scan(~r/link link-hover">\s*ana\s*</, &1))

      assert length(linhas) == 1, """
      A pessoa apareceu #{length(linhas)} vezes na seção. Duas linhas somariam a mesma
      pessoa, e quem contasse a lista mediria participações em vez de gente (FR-010).
      """

      assert html =~ "via Dados, Plataforma" or html =~ "via Plataforma, Dados"
    end

    test "vínculo sem data de início traz a marca, e ela NOMEIA a borda que falta", ctx do
      sem_data = pessoa(ctx, "semdata")
      vincular(ctx, ctx.equipe, sem_data, nil)
      {_projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#quem-trabalhou") |> render()

      # A frase INTEIRA, e dentro da seção: "start date" sozinho aparece em mais dois
      # lugares da página — o rodapé desta seção e o badge "start date unknown" da
      # seção de pessoas. Com a asserção solta, trocar o nome da borda por "boundary"
      # passava (achado da revisão de QA do PR #798).
      assert secao =~ "partially unknown: start date", """
      A marca apareceu sem nomear a borda. "Parcial" sozinho diz que há dúvida e não diz
      o que fazer com ela; "start date" diz qual campo preencher (FR-009, SC-005).
      """
    end

    test "vínculo apenas em curso NÃO é marcado — fim nulo é vigente", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      {_projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)

      {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      refute html =~ "partially unknown", """
      A marca apareceu para um vínculo apenas em curso. `fim` nulo é **vigente**, e
      marcá-lo poria a dúvida em quase toda linha até ela deixar de significar alguma
      coisa (FR-009a).
      """
    end

    test "projeto sem interseção no período diz a ausência em texto, e não lista vazia", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      {_projeto, vinculo} = projeto_ligado(ctx, "Alfa", ctx.equipe)
      # A equipe esteve ligada de 400 a 300 dias atrás — fora da janela de 8 semanas.
      periodo_do_vinculo(vinculo, dias_atras(400), dias_atras(300))

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      # A asserção é sobre a SEÇÃO, e não sobre a página: "ana" aparece na tabela
      # de membros da equipe de qualquer jeito, e um refute sobre o HTML inteiro
      # passaria a medir a página errada.
      secao = live |> element("#quem-trabalhou") |> render()

      assert secao =~ "Alfa"

      assert secao =~ "Nobody worked on this project in the window", """
      O projeto ficou sem pessoas e sem frase. Lista vazia sem explicação é
      indistinguível de erro de carregamento (FR-011).
      """

      refute secao =~ "ana"
    end
  end

  describe "a espera por revisão (US1)" do
    test "declara o que a medida descarta, e de onde o tempo conta", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      pr = solicitacao(ctx, 201, ana, dias_atras(10))
      revisao(ctx, pr, DateTime.add(pr.external_created_at, 2, :hour))

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#espera-por-revisao") |> render()

      assert secao =~ "on the day they opened them", """
      A tela não diz que o recorte é pela ABERTURA. Sem essa frase, quem lê supõe que a
      lista é de quem está na equipe hoje, e a medida vira outra (FR-019).
      """

      assert secao =~ "bot review does not end the count", """
      A tela não declara que descarta a revisão de robô (FR-003). O número existiria sem
      dizer o que ele exclui.
      """

      assert secao =~ "2.0h to first human review"
    end

    test "a espera em curso aparece contada ao lado, e não somem nem viram zero", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      _sem_revisao = solicitacao(ctx, 202, ana, dias_atras(12))

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#espera-por-revisao") |> render()

      assert secao =~ "waiting for 12 day(s)"
      assert secao =~ "still waiting"

      assert secao =~ "none reviewed yet", """
      Sem nenhuma revisada a tela precisa dizer que não há mediana. Um "0h" ali afirmaria
      revisão instantânea (FR-018).
      """
    end

    test "duas pessoas com esperas distintas, e o texto que impede reconciliar", ctx do
      ana = pessoa(ctx, "ana")
      bia = pessoa(ctx, "bia")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      vincular(ctx, ctx.equipe, bia, dias_atras(200))

      pr_ana = solicitacao(ctx, 203, ana, dias_atras(9))
      revisao(ctx, pr_ana, DateTime.add(pr_ana.external_created_at, 3, :hour))
      pr_bia = solicitacao(ctx, 204, bia, dias_atras(8))
      revisao(ctx, pr_bia, DateTime.add(pr_bia.external_created_at, 1, :hour))

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#espera-por-revisao") |> render()

      assert secao =~ "ana"
      assert secao =~ "bia"
      assert secao =~ "3.0h to first human review"
      assert secao =~ "1.0h to first human review"

      assert secao =~ "different questions", """
      A tela mostra as duas leituras sem dizer que elas respondem perguntas diferentes.
      Sem a frase, alguém soma a mediana por pessoa com a da equipe (FR-005, FR-020).
      """
    end

    test "quando corta em 200, a tela DIZ que cortou", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(300))

      # 201 para cruzar o teto por uma. O corte silencioso era o achado: uma mediana
      # sobre 200 de 500 é outra medida, apresentada com o mesmo rótulo (revisão de
      # segurança do PR #798).
      for n <- 1..201, do: solicitacao(ctx, 400 + n, ana, dias_atras(rem(n, 50) + 1))

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#espera-por-revisao") |> render()

      assert secao =~ "Showing the most recent 200 requests only", """
      A tela cortou em 200 e não disse. Quem lê a mediana acredita que ela é sobre tudo o
      que houve na janela (FR-018, FR-019).
      """

      assert secao =~ "not over all of them"
    end

    test "com poucas solicitações, a tela NÃO diz que cortou", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(300))
      for n <- 1..3, do: solicitacao(ctx, 700 + n, ana, dias_atras(n))

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#espera-por-revisao") |> render()

      refute secao =~ "Showing the most recent", """
      A tela avisou de um corte que não houve. Aviso que aparece sempre deixa de ser aviso.
      """
    end

    test "equipe sem solicitação diz a ausência, e não zero", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#espera-por-revisao") |> render()

      assert secao =~ "That is not a wait of", """
      Equipe sem solicitação ficou sem frase. Zero afirmaria que a equipe abriu
      solicitações e ninguém esperou (FR-006, FR-018).
      """
    end
  end

  describe "a taxa do pipeline (US3)" do
    test "equipe sem projeto NOMEIA o elo que falta, e não mostra taxa nenhuma", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#taxa-do-pipeline") |> render()

      assert secao =~ "not linked to any project"
      assert secao =~ "team → project"
      assert secao =~ "Dados"

      assert secao =~ "not a rate of zero", """
      A tela precisa dizer POR QUE não há taxa. Zero diria que o pipeline falhou; a
      verdade é que a plataforma não sabe de quais repositórios a equipe cuida (FR-013a).
      """

      # O que não pode aparecer é NÚMERO nenhum — o título da seção continua sendo
      # "Pipeline success rate", e é o painel de números que fica ausente.
      refute secao =~ "runs considered"
      refute secao =~ "%"
    end

    test "com projeto, a taxa vem com o caminho e o TAMANHO DA AMOSTRA", ctx do
      {projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)
      {:ok, _} = SPO.link_repository(ctx.tenant, projeto.id, ctx.repo_id, ctx.admin.id)

      verificacao(ctx, "ciro.successful_continuous_integration_process", "success")
      verificacao(ctx, "ciro.unsuccessful_continuous_integration_process", "failure")
      verificacao(ctx, "ciro.interrupted_continuous_integration_process", "cancelled")

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#taxa-do-pipeline") |> render()

      assert secao =~ "50.0%"

      # O NÚMERO, e não a legenda: trocar o campo renderizado de
      # `denominador_do_percentual` para `repositorios` fazia a tela declarar "over 1
      # run(s)" onde são 2, e os 13 testes deste arquivo passavam (achado da revisão
      # de QA do PR #798).
      assert secao =~ "over 2 run(s) that", """
      O número apareceu sem o tamanho da amostra correto. Uma taxa de 100% sobre três
      execuções não é a mesma afirmação que sobre trezentas (FR-016).
      """

      assert secao =~ "repository → project → team", """
      O caminho não está escrito junto do número. Sem ele, ninguém sabe se a taxa é dos
      repositórios ou de quem disparou (FR-016).
      """

      assert secao =~ "never added to"
    end

    test "a fase interrompida aparece separada, e não somada a falha", ctx do
      {projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)
      {:ok, _} = SPO.link_repository(ctx.tenant, projeto.id, ctx.repo_id, ctx.admin.id)

      verificacao(ctx, "ciro.interrupted_continuous_integration_process", "cancelled")

      {:ok, live, _html} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#taxa-do-pipeline") |> render()

      # A CÉLULA da fase, e não o cabeçalho: `<th>interrupted</th>` renderiza sempre
      # que há execução, e `assert secao =~ "interrupted"` passava mesmo com a fase
      # somada a falha (achado da revisão de QA do PR #798).
      assert secao =~ "over 0 run(s) that"

      # A LINHA da tabela, célula a célula: sucesso 0, falha 0, interrompida 1. Somar a
      # interrompida a "failed" mudaria a segunda célula, e o cabeçalho não denuncia.
      assert secao =~ "<td>0</td><td>0</td><td>1</td><td>0</td><td>0</td>", """
      As cinco fases não vieram separadas. Cancelar é decisão humana, e contá-la como
      quebra inflaria a taxa com o que ninguém quebrou (FR-015).
      """

      # E o que NÃO pode existir: somar a interrompida ao denominador do percentual
      # fazia a tela mostrar "0.0%" — e o travessão do parágrafo do caminho fazia a
      # asserção do travessão passar assim mesmo.
      refute secao =~ "%", """
      Apareceu uma porcentagem sobre uma execução que não produziu resultado. "0%" diria
      que tudo falhou, e o que houve foi um cancelamento (FR-015, FR-018).
      """
    end
  end

  describe "a quebra por pessoa exige alcance sobre a equipe (FR-024, SC-012)" do
    test "conta SEM alcance lê os agregados e NÃO lê login nem número de solicitação", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      pr = solicitacao(ctx, 501, ana, dias_atras(5))
      revisao(ctx, pr, DateTime.add(pr.external_created_at, 4, :hour))

      {:ok, estranha} =
        Tenants.create_user(ctx.tenant, %{
          "email" => "estranha@example.test",
          "name" => "Estranha",
          "role" => "member"
        })

      {:ok, live, _html} = live(log_in(ctx.conn, estranha), ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#espera-por-revisao") |> render()

      # O AGREGADO continua aberto — FR-023 segue de pé: ver não exige administrar.
      assert secao =~ "team median"
      assert secao =~ "still waiting"
      assert secao =~ "4.0h", "a mediana da equipe sumiu junto com a quebra"

      # A quebra por pessoa, não.
      refute secao =~ "#501", """
      O número da solicitação de uma pessoa nomeada apareceu para quem não alcança a
      equipe. A decisão de 2026-08-26 (spec 023, FR-012) diz quem lê o trabalho de
      alguém: a própria pessoa, quem lidera a equipe dela, e quem responde pela
      organização.
      """

      # E a recusa é DITA, nunca silenciosa (FR-024a).
      # O trecho não atravessa quebra de linha nem apóstrofo: o HEEx escapa `'` para
      # `&#39;` e preserva as quebras do template. Uma asserção sobre a frase inteira
      # falharia dizendo "a recusa sumiu" quando ela está lá.
      assert secao =~ "the breakdown is withheld", """
      A quebra sumiu sem explicação. Seção que encolhe sem dizer por quê parece defeito,
      e apresentá-la vazia afirmaria que a equipe não tem solicitações (FR-018).
      """
    end

    test "quem tem VÍNCULO na equipe lê a quebra — colega vê colega", ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      pr = solicitacao(ctx, 502, ana, dias_atras(5))
      revisao(ctx, pr, DateTime.add(pr.external_created_at, 4, :hour))

      # A conta da própria ana: elo com a pessoa, e vínculo vigente na equipe.
      {:ok, conta_da_ana} =
        Tenants.create_user(ctx.tenant, %{
          "email" => "ana@example.test",
          "name" => "ana",
          "role" => "member"
        })

      {:ok, _} = Tenants.declare_person(ctx.tenant, conta_da_ana.id, ana.id, ctx.admin.id)

      {:ok, live, _html} = live(log_in(ctx.conn, conta_da_ana), ~p"/teams/#{ctx.equipe.id}")
      secao = live |> element("#espera-por-revisao") |> render()

      assert secao =~ "#502", "quem está na equipe deixou de ver o trabalho dela"
      assert secao =~ "different questions"
      refute secao =~ "the breakdown is withheld"
    end
  end

  describe "ver não exige administrar (T019, SC-011 emendado em 2026-09-04)" do
    # SC-011 dizia "uma pessoa sem permissão de administrar equipes lê todas as
    # medidas". Como estava escrito, ele **exigia o vazamento**: uma conta sem relação
    # nenhuma também é "uma pessoa sem permissão de administrar", e o teste antigo
    # implementava fielmente o critério errado.
    #
    # A emenda do Product Owner (2026-09-04) acrescenta a fronteira que faltava — com
    # ESCOPO sobre a equipe —, e mantém intacto o que o critério queria dizer:
    # administrar não é pré-requisito para ver.
    test "perfil member COM vínculo lê as três medidas, e não vê os controles de escrita",
         ctx do
      ana = pessoa(ctx, "ana")
      vincular(ctx, ctx.equipe, ana, dias_atras(200))
      {projeto, _v} = projeto_ligado(ctx, "Alfa", ctx.equipe)
      {:ok, _} = SPO.link_repository(ctx.tenant, projeto.id, ctx.repo_id, ctx.admin.id)
      verificacao(ctx, "ciro.successful_continuous_integration_process", "success")

      pr = solicitacao(ctx, 301, ana, dias_atras(5))
      revisao(ctx, pr, DateTime.add(pr.external_created_at, 4, :hour))

      {:ok, member} =
        Tenants.create_user(ctx.tenant, %{
          "email" => "member@example.test",
          "name" => "Member",
          "role" => "member"
        })

      # O vínculo é o que dá alcance sobre a equipe — colega vê colega, sem ninguém
      # conceder nada. Sem ele, esta conta leria os agregados e não a quebra, que é o
      # caso do describe anterior (SC-012).
      pessoa_do_member = pessoa(ctx, "membro")
      vincular(ctx, ctx.equipe, pessoa_do_member, dias_atras(50))
      {:ok, _} = Tenants.declare_person(ctx.tenant, member.id, pessoa_do_member.id, ctx.admin.id)

      # Um projeto NÃO ligado à equipe, para o seletor de associação ter o que oferecer.
      # Sem ele, `@projetos_disponiveis` é vazio e o formulário não renderiza para
      # ninguém — o `refute` passava com a guarda de admin removida, e o teste media a
      # fixture em vez do controle (achado da revisão de QA do PR #798).
      {:ok, _solto} = SPO.create_project(ctx.tenant, %{name: "Beta"}, ctx.admin.id)

      {:ok, live, html} = live(log_in(ctx.conn, member), ~p"/teams/#{ctx.equipe.id}")

      assert html =~ "Who worked on these projects", "US2 não chegou a quem só lê"
      assert html =~ "Waiting for first review", "US1 não chegou a quem só lê"
      assert html =~ "Pipeline success rate", "US3 não chegou a quem só lê"

      assert live |> element("#quem-trabalhou") |> render() =~ "ana"
      # A quebra por pessoa, e não só o agregado: com vínculo, ela é legível.
      espera = live |> element("#espera-por-revisao") |> render()
      assert espera =~ "4.0h"
      assert espera =~ "#301", "quem tem vínculo na equipe deixou de ver a quebra"
      assert live |> element("#taxa-do-pipeline") |> render() =~ "100.0%"

      refute html =~ "associate with a project…", """
      Quem só lê viu o controle de associar projeto. Ler as medidas não exige administrar
      — e administrar não é ver (FR-023).
      """

      # E o outro lado, que é o que prova que o controle EXISTE: sem ele, o refute
      # acima passaria por o formulário nunca renderizar.
      {:ok, _admin_live, html_admin} = live(ctx.conn, ~p"/teams/#{ctx.equipe.id}")

      assert html_admin =~ "associate with a project…", """
      Quem administra deixou de ver o controle. O refute do `member` só significa alguma
      coisa se houver o que esconder.
      """
    end
  end

  defp verificacao(ctx, fase, conclusao) do
    {:ok, v} =
      VerificationCommands.record_verification(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        workflow_name: "CI",
        head_sha: "abc1234",
        trigger_event: "push",
        run_status: "completed",
        conclusion: conclusao,
        phase: fase,
        external_started_at: DateTime.add(DateTime.utc_now(:second), -2, :day),
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "run-#{System.unique_integer([:positive])}"
      })

    v
  end

  defp solicitacao(ctx, numero, autora, aberta_em) do
    {:ok, pr} =
      ChangeCommands.record_change_request(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        number: numero,
        title: "solicitação #{numero}",
        state: "OPEN",
        external_created_at: aberta_em,
        author_login: autora.login,
        author_person_id: autora.id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_#{numero}"
      })

    pr
  end

  defp revisao(ctx, pr, quando) do
    {:ok, a} =
      QualityCommands.record_evaluation(ctx.tenant, %{
        collected_change_request_id: pr.id,
        state: "APPROVED",
        author_login: "revisora",
        author_type: "User",
        external_submitted_at: quando,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PRR_#{System.unique_integer([:positive])}"
      })

    a
  end
end
