defmodule TheBand.Mapping.PreviewTest do
  @moduledoc """
  Prévia e recálculo (feature 005, F3).

  O teste que mais importa é o que compara os dois: **a diferença tem de ser zero**.
  Prévia e efeito por caminhos diferentes é o defeito que faz alguém aprovar uma regra
  vendo 3 e reclassificar 900.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.WorkItemsFixtures

  alias TheBand.Jobs.RecomputePromotions
  alias TheBand.Mapping
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    user = user_fixture(tenant)
    %{tenant: tenant, org: cenario.organization.id, user: user, cenario: cenario}
  end

  @tarefa "sro.intended_scrum_development_task"

  describe "a prévia" do
    test "distingue quantas casa de quantas mudariam", %{tenant: t, org: org} do
      # O cenário tem issues tipo `Spike` e sem tipo, e nenhuma promovida por regra.
      # O conceito de destino é **defeito**, e não tarefa: a etapa estrutural já classifica
      # a folha como tarefa, e uma regra que concorda com a estrutura não muda nada. Isso
      # não é falha da regra — é o que `would_change` existe para dizer.
      assert {:ok, previa} =
               Mapping.preview(t, org, %{
                 where: "declared_type",
                 how: "equals",
                 pattern: "Spike",
                 target_concept: "osdef.defect"
               })

      assert previa.matched >= 1
      assert previa.would_change >= 1

      # `matched` sem `would_change` esconderia o caso perigoso: casar 1031 e mudar 1031
      # é muito diferente de casar 1031 e mudar 3.
      assert Map.has_key?(previa, :matched) and Map.has_key?(previa, :would_change)
      assert is_list(previa.sample)
    end

    test "regra que não casa nada devolve zero, e zero não é erro", %{tenant: t, org: org} do
      assert {:ok, previa} =
               Mapping.preview(t, org, %{
                 where: "declared_type",
                 how: "equals",
                 pattern: "TipoQueNinguemUsa",
                 target_concept: @tarefa
               })

      assert previa.matched == 0

      assert previa.would_change == 0, """
      Regra que não casa nada não muda nada — mesmo que o recálculo, ao rodar, vá mudar
      outras issues pela etapa estrutural. Atribuir essas mudanças à regra faria a prévia
      culpar a regra errada.
      """
    end

    test "recusa o padrão inválido antes de contar qualquer coisa", %{tenant: t, org: org} do
      assert {:error, {:invalid_pattern, :matches_empty}} =
               Mapping.preview(t, org, %{
                 where: "title",
                 how: "regex",
                 pattern: ".*",
                 target_concept: @tarefa
               })
    end
  end

  describe "prévia contra efeito" do
    test "a prévia bate com o recálculo, e a diferença é zero",
         %{tenant: t, org: org, user: u} do
      attrs = %{
        where: "declared_type",
        how: "equals",
        pattern: "Spike",
        target_concept: "osdef.defect"
      }

      {:ok, previa} = Mapping.preview(t, org, attrs)
      {:ok, _regra} = Mapping.create_rule(t, org, attrs, u.id)
      {:ok, efeito} = Mapping.recompute(t, org)

      assert efeito.written == previa.rows_to_write, """
      A prévia disse que #{previa.rows_to_write} linhas seriam gravadas e o recálculo
      gravou #{efeito.written}.

      É o SC-007. Prévia e efeito por caminhos diferentes faz alguém aprovar uma regra
      vendo um número e reclassificar outro.
      """

      assert previa.would_change > 0, """
      `would_change` mede o efeito **da regra** — com ela contra sem ela —, e não o do
      recálculo. Comparar com o que está gravado atribuiria à regra tudo o que a etapa
      estrutural decide, e ela decidiria de todo modo.
      """
    end
  end

  describe "o recálculo" do
    test "é idempotente: a segunda execução não grava nada",
         %{tenant: t, org: org, user: u} do
      {:ok, _} =
        Mapping.create_rule(
          t,
          org,
          %{where: "declared_type", how: "equals", pattern: "Spike", target_concept: @tarefa},
          u.id
        )

      {:ok, primeira} = Mapping.recompute(t, org)
      {:ok, segunda} = Mapping.recompute(t, org)

      assert primeira.written > 0

      assert segunda.written == 0, """
      Executar duas vezes sobre o mesmo estado gravou linha nova.

      Sem a comparação com a vigente, cada execução dobra o histórico e a tela passa a
      mostrar dezenas de decisões idênticas — FR-027.
      """
    end

    test "grava promoção nova preservando a anterior, e registra a proveniência",
         %{tenant: t, org: org, user: u, cenario: c} do
      issue = c.issues[202].pai
      antes = length(WorkItems.promotion_history(t, issue.id))

      {:ok, regra} =
        Mapping.create_rule(
          t,
          org,
          %{where: "declared_type", how: "equals", pattern: "Spike", target_concept: @tarefa},
          u.id
        )

      {:ok, _} = Mapping.recompute(t, org)

      historico = WorkItems.promotion_history(t, issue.id)
      assert length(historico) == antes + 1

      vigente = List.last(historico)
      assert vigente.current
      assert vigente.derived_concept == @tarefa

      {:ok, detalhe} = WorkItems.fetch_issue(t, issue.id)
      assert detalhe.derived_concept == @tarefa

      # A proveniência é o que distingue decisão por campo declarado de inferência.
      [linha] =
        TheBand.Repo.all(
          Ecto.Query.from(p in "issue_promotions",
            where:
              p.collected_issue_id == type(^issue.id, Ecto.UUID) and not is_nil(p.mapping_rule_id),
            select: %{
              evidence_source: p.evidence_source,
              confidence: p.confidence,
              mapping_rule_id: type(p.mapping_rule_id, Ecto.UUID)
            }
          )
        )

      assert linha.evidence_source == "declared_type"
      assert linha.confidence == "high"
      assert linha.mapping_rule_id == regra.id
    end

    test "promoção por título registra confiança menor", %{tenant: t, org: org, user: u} do
      {:ok, _} =
        Mapping.create_rule(
          t,
          org,
          %{where: "title", how: "starts_with", pattern: "issue #", target_concept: @tarefa},
          u.id
        )

      {:ok, efeito} = Mapping.recompute(t, org)
      assert efeito.concept_changed > 0

      linhas =
        TheBand.Repo.all(
          Ecto.Query.from(p in "issue_promotions",
            where: p.evidence_source == "title",
            select: p.confidence,
            distinct: true
          )
        )

      assert linhas == ["medium"], """
      Inferência sobre título vale menos que campo declarado, e quem lê precisa poder
      saber — princípio III, FR-013.
      """
    end
  end

  describe "o job" do
    test "gravar regra enfileira o recálculo na fila transformation",
         %{tenant: t, org: org, user: u} do
      {:ok, _} =
        Mapping.create_rule(
          t,
          org,
          %{where: "declared_type", how: "equals", pattern: "Spike", target_concept: @tarefa},
          u.id
        )

      [job] = TheBand.Repo.all(Oban.Job)

      assert job.queue == "transformation", """
      Fila declarada e não configurada faz o job ficar `available` para sempre, e a
      interface diz "enfileirado" sem nada acontecer. Já aconteceu com uma fila `:sync`.
      """

      assert job.worker == "TheBand.Jobs.RecomputePromotions"
      assert job.state in ["available", "scheduled"]
    end

    test "executa e avisa a tela com os DOIS números", %{tenant: t, org: org, user: u} do
      Mapping.subscribe(t)

      {:ok, _} =
        Mapping.create_rule(
          t,
          org,
          %{where: "declared_type", how: "equals", pattern: "Spike", target_concept: @tarefa},
          u.id
        )

      [job] = TheBand.Repo.all(Oban.Job)

      # **Executa de verdade, e com o log ligado.** O teste anterior só conferia o
      # enfileiramento, e por isso o job estourava `Protocol.UndefinedError` na interpolação
      # do resultado sem nenhum teste reprovar: `Mapping.recompute/2` devolve mapa, e o job
      # tratava como inteiro. O trabalho era feito três vezes e o job terminava `discarded`.
      #
      # Elevar o nível não é adorno, e a opção `:level` do `capture_log` **não serve**: ela
      # filtra o que é capturado, não o que o Logger emite. `config :logger, level: :warning`
      # no teste faz `Logger.info/1` não avaliar o argumento — a macro sai antes de
      # interpolar. Sem `Logger.configure/1`, um defeito dentro da interpolação de um
      # `Logger.info` é invisível a teste **por configuração**, e este era.
      nivel = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: nivel) end)

      log =
        capture_log(fn ->
          assert :ok = RecomputePromotions.perform(%Oban.Job{args: job.args})
        end)

      assert log =~ "linhas gravadas", """
      A frase do log nomeia o que cada número é. `#{inspect(log)}` não a contém — se ela
      mudar, mude aqui também, mas não deixe passar mapa interpolado como se fosse inteiro.
      """

      assert_received {:promotions_recomputed, ^org, resultado}

      assert %{written: _, concept_changed: _} = resultado, """
      O aviso carrega os dois números, e eles são diferentes: `written` inclui a issue que
      manteve o conceito e mudou de proveniência. Mandar um número só faria a tela dizer
      que N issues mudaram de significado quando não mudaram.
      """
    end

    test "o aviso vai para tópico que a tela assina", %{tenant: t, org: org} do
      # O job emitia em `"tenant:<id>"`, que ninguém assinava — e o `handle_info` genérico
      # da tela engolia a mensagem sem sinal nenhum. Emitir para tópico sem assinante é o
      # mesmo que não emitir, com a agravante de parecer resolvido no código.
      Mapping.subscribe(t)
      Mapping.broadcast(t.id, {:promotions_recomputed, org, %{written: 1, concept_changed: 1}})

      assert_received {:promotions_recomputed, ^org, %{written: 1, concept_changed: 1}}

      refute_received _qualquer_outra
    end
  end
end
