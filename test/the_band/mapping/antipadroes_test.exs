defmodule TheBand.Mapping.AntipadroesTest do
  @moduledoc """
  Os quatro antipadrões de instância, lidos da base de conhecimento (T012).

  ## O caso que mais importa não é nenhum dos quatro

  É o quinto: **zero detectados com zero movimentação coletada é dito como "não olhei"**,
  e não como "processo saudável". As duas situações produzem a mesma lista vazia e dizem
  coisas opostas.

  É o limite escrito no próprio `process_antipatterns.yaml`, e é a L57 — a mesma família
  de defeito que já apareceu quatro vezes neste projeto.

  ## E a automação não conta como trabalho

  Um cartão que o robô moveu para `Done` ao fechar a issue não diz que alguém trabalhou
  nela: diz que a issue fechou. 160 das 357 movimentações medidas em 2026-08-14 são de
  robô, e sem essa distinção quase metade dos sinais seria lida como esforço humano.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Mapping.Antipatterns
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    %{tenant: tenant, issue: cenario.issues[1].pai}
  end

  defp mover(tenant, issue, login, at) do
    {:ok, _} =
      SPO.record_activity(tenant, %{
        activity_type: "ProjectV2ItemStatusChangedEvent",
        concept_id: "spo.performed_project_activity",
        occurred_at: at,
        subject_type: "issue",
        subject_id: issue.id,
        source_system: "github",
        source_instance: "https://github.com",
        performer_login: login,
        payload: %{"previousStatus" => "Backlog", "status" => "Done"}
      })
  end

  defp designar(tenant, issue) do
    {:ok, _} = WorkItems.replace_assignees(tenant, issue.id, [%{login: "alguem", person_id: nil}])
  end

  defp fechar(issue, at) do
    issue
    |> Ecto.Changeset.change(external_closed_at: at)
    |> Repo.update!()
  end

  defp ids(tenant, issue) do
    {:ok, achados} = Antipatterns.detect(tenant, issue.id)
    Enum.map(achados, & &1.id)
  end

  describe "o que a lista vazia significa" do
    test "sem movimentação coletada, a resposta é 'não olhei'", ctx do
      designar(ctx.tenant, ctx.issue)

      assert Antipatterns.detect(ctx.tenant, ctx.issue.id) ==
               {:nao_olhei, :sem_movimentacao_coletada},
             """
             A detecção devolveu lista vazia onde não havia nada para olhar.

             `{:ok, []}` e `{:nao_olhei, _}` produzem a mesma lista na tela e dizem coisas
             opostas: "o processo está registrado direito" e "a plataforma não coletou
             movimentação". Confundi-las é o limite escrito no próprio YAML, e a L57.
             """
    end

    test "com movimentação e nada errado, a resposta é lista vazia de verdade", ctx do
      designar(ctx.tenant, ctx.issue)
      mover(ctx.tenant, ctx.issue, "alguem", ~U[2026-08-10 09:00:00Z])

      assert {:ok, []} = Antipatterns.detect(ctx.tenant, ctx.issue.id), """
      Uma issue designada, movida por pessoa e ainda aberta foi acusada de antipadrão.

      Este é o caso limpo, e ele precisa passar limpo: um detector que acusa sempre não
      distingue nada.
      """
    end
  end

  describe "ap01 — concluída sem ter sido movida" do
    test "fechada, designada, e só o robô moveu", ctx do
      designar(ctx.tenant, ctx.issue)
      issue = fechar(ctx.issue, ~U[2026-08-14 13:01:06Z])

      # O caso medido em 2026-08-14 nas issues #98 e #100: a única movimentação é do
      # robô, no fechamento.
      mover(ctx.tenant, issue, "github-project-automation", ~U[2026-08-14 13:01:06Z])

      assert "process.ap01.closed_without_movement" in ids(ctx.tenant, issue), """
      A movimentação do robô foi contada como trabalho humano.

      Um cartão que a automação moveu para `Done` ao fechar a issue diz que a issue
      fechou, e não que alguém trabalhou nela — R2. Contá-la aqui apagaria o antipadrão
      exatamente nas issues onde ele é real.
      """
    end

    test "fechada depois de uma pessoa ter movido não é antipadrão", ctx do
      designar(ctx.tenant, ctx.issue)
      issue = fechar(ctx.issue, ~U[2026-08-14 13:01:06Z])
      mover(ctx.tenant, issue, "alguem", ~U[2026-08-12 09:00:00Z])

      refute "process.ap01.closed_without_movement" in ids(ctx.tenant, issue)
    end
  end

  describe "ap02 — movida depois de concluída" do
    test "a pessoa moveu o cartão depois do fechamento", ctx do
      designar(ctx.tenant, ctx.issue)
      issue = fechar(ctx.issue, ~U[2026-08-12 09:00:00Z])
      mover(ctx.tenant, issue, "alguem", ~U[2026-08-14 13:01:06Z])

      assert "process.ap02.moved_after_closing" in ids(ctx.tenant, issue)
    end

    test "o robô arrumando o quadro no fechamento não é isso", ctx do
      designar(ctx.tenant, ctx.issue)
      issue = fechar(ctx.issue, ~U[2026-08-12 09:00:00Z])
      mover(ctx.tenant, issue, "github-project-automation", ~U[2026-08-12 09:00:01Z])

      refute "process.ap02.moved_after_closing" in ids(ctx.tenant, issue), """
      A automação foi acusada de registrar trabalho ao final.

      O `ap02` é sobre alguém acertar o quadro depois de terminar. O robô movendo o
      cartão um segundo depois do fechamento é o funcionamento normal da automação, e
      acusá-lo transformaria o achado em ruído em toda issue fechada.
      """
    end
  end

  describe "ap03 — designada e nunca iniciada" do
    test "aberta, designada, e nenhuma pessoa moveu", ctx do
      designar(ctx.tenant, ctx.issue)
      mover(ctx.tenant, ctx.issue, "github-project-automation", ~U[2026-08-10 09:00:00Z])

      assert "process.ap03.assigned_and_never_started" in ids(ctx.tenant, ctx.issue), """
      Uma issue designada há tempo, aberta e nunca movida por pessoa não foi apontada.

      É a diferença entre designado e em progresso, e é ela que torna o WIP verdadeiro
      possível: contar as designadas como WIP infla a medida com trabalho que ninguém
      começou.
      """
    end
  end

  describe "ap04 — movida sem ninguém designado" do
    test "a pessoa moveu e não há designado", ctx do
      mover(ctx.tenant, ctx.issue, "alguem", ~U[2026-08-10 09:00:00Z])

      assert "process.ap04.movement_without_assignee" in ids(ctx.tenant, ctx.issue)
    end
  end

  describe "a regra vem da base, e não do código" do
    test "as quatro máximas do YAML são todas avaliadas", ctx do
      {:ok, regra} = KnowledgeBase.rule("process.antipatterns")
      declaradas = Enum.map(regra["antipatterns"], & &1["id"])

      designar(ctx.tenant, ctx.issue)
      mover(ctx.tenant, ctx.issue, "alguem", ~U[2026-08-10 09:00:00Z])

      # Se uma máxima nova entrar no YAML sem avaliação, `viola?/2` levanta — e é
      # deliberado. Devolver `false` a esconderia: quem a escrevesse veria zero achados e
      # concluiria que o processo está limpo, quando ninguém a avaliou.
      assert {:ok, _} = Antipatterns.detect(ctx.tenant, ctx.issue.id), """
      Uma máxima declarada na base não tem avaliação no código, e a detecção levantou.

      Isso é o comportamento correto — o teste falhando aqui significa que alguém
      acrescentou uma máxima ao YAML e ainda não a implementou.
      """

      assert length(declaradas) == 4
    end
  end

  describe "o isolamento entre tenants" do
    test "a issue de outro tenant não é avaliada", ctx do
      outro = tenant_fixture()

      assert {:error, :not_found} = Antipatterns.detect(outro, ctx.issue.id)
    end
  end
end
