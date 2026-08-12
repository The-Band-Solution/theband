defmodule TheBand.Mapping.StructureTest do
  @moduledoc """
  A classificação pela estrutura de decomposição (regra de 2026-08-12).

      folha                          → tarefa
      só tem partes que são tarefas  → user story atômica
      tem parte que é user story     → épico

  O teste que carrega a regra é o da **precedência**: a estrutura é a evidência mais fraca
  das três, e não pode sobrescrever tipo declarado. Uma folha tipada `Bug` continua defeito.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Mapping
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    %{tenant: tenant, org: cenario.organization.id, cenario: cenario, user: user_fixture(tenant)}
  end

  @tarefa "sro.intended_scrum_development_task"
  @atomica "sro.atomic_user_story"
  @epico "sro.epic"

  # As regras vigentes da organização, e não uma lista vazia: passar `[]` faria o teste da
  # precedência do título passar por não haver título nenhum a aplicar.
  defp conceito(tenant, org, issue_id) do
    tenant
    |> Mapping.decidir_lote(org, Mapping.active_rules(tenant, org))
    |> Enum.find(&(&1.issue.id == issue_id))
  end

  describe "a regra" do
    test "issue sem tipo e sem partes é tarefa", %{tenant: t, org: org, cenario: c} do
      linha = conceito(t, org, c.issues[203].pai.id)

      assert linha.decisao.derived == @tarefa
      assert linha.decisao.evidence_source == "structure"

      assert linha.decisao.confidence == "low", """
      A estrutura é a evidência mais fraca das três: uma folha pode ser uma tarefa, e pode
      ser uma user story que ninguém decompôs. A estrutura não distingue as duas.
      """
    end

    test "issue cujas partes são todas folhas é user story atômica",
         %{tenant: t, org: org, cenario: c} do
      # #203 não tem partes no cenário; monto o caso: um pai sem tipo com duas folhas sem
      # tipo. As folhas viram tarefa, e o pai vira atômica.
      {pai, _partes} = arvore(t, c, ["", ""])

      linha = conceito(t, org, pai.id)
      assert linha.decisao.derived == @atomica
      assert linha.decisao.confidence == "low"
    end

    test "issue com parte que é user story é épico", %{tenant: t, org: org, cenario: c} do
      {avo, [pai | _]} = arvore(t, c, [""])
      {_pai2, _} = arvore(t, c, ["", ""], pai)

      linha = conceito(t, org, avo.id)

      assert linha.decisao.derived == @epico, """
      A composição é o que torna épico — `sro.rule05`. O neto é tarefa, o filho vira user
      story por ter partes que são tarefas, e o avô vira épico por ter user story.
      """
    end

    test "épico dentro de épico continua épico", %{tenant: t, org: org, cenario: c} do
      {raiz, [meio | _]} = arvore(t, c, [""])
      {_, [neto | _]} = arvore(t, c, [""], meio)
      {_, _} = arvore(t, c, ["", ""], neto)

      assert conceito(t, org, raiz.id).decisao.derived == @epico
      assert conceito(t, org, meio.id).decisao.derived == @epico
    end
  end

  describe "a precedência" do
    test "tipo declarado vence a estrutura", %{tenant: t, org: org, cenario: c} do
      # #200 é `Bug` e não tem partes. Pela estrutura seria tarefa; pelo tipo é defeito.
      linha = conceito(t, org, c.issues[200].pai.id)

      assert linha.decisao.derived == "osdef.defect"
      assert linha.decisao.evidence_source == "declared_type"
      assert linha.decisao.confidence == "high"
    end

    test "regra de título vence a estrutura", %{tenant: t, org: org, user: u, cenario: c} do
      {:ok, _} =
        Mapping.create_rule(
          t,
          org,
          %{
            where: "title",
            how: "starts_with",
            pattern: "issue #203",
            target_concept: @atomica
          },
          u.id
        )

      linha = conceito(t, org, c.issues[203].pai.id)

      assert linha.decisao.derived == @atomica
      assert linha.decisao.evidence_source == "title"
      assert linha.decisao.confidence == "medium"
    end

    test "nenhuma issue fica sem conceito depois da etapa estrutural",
         %{tenant: t, org: org} do
      sem_conceito =
        t
        |> Mapping.decidir_lote(org, Mapping.active_rules(t, org))
        |> Enum.filter(&is_nil(&1.decisao.derived))

      assert sem_conceito == [], """
      A estrutura decide para toda issue: no pior caso, folha vira tarefa.

      Isso muda o significado de "indefinida" — ela passa a existir só onde a issue não tem
      posição no grafo E nenhuma regra a alcança, o que na prática não acontece.
      """
    end
  end

  describe "os limites" do
    test "parte fora do escopo observado não torna a issue épico",
         %{tenant: t, org: org, cenario: c} do
      pai = c.issues[203].pai

      # Vínculo para uma issue que a plataforma não tem: a recusa é registrada, e a issue
      # continua folha. Contá-la faria a issue virar épico por causa do que não existe aqui.
      {:ok, _} =
        WorkItems.recusar(t, %{
          parent_issue_id: pai.id,
          child_external_id: "I_fora_do_escopo",
          reason: "out_of_scope"
        })

      assert conceito(t, org, pai.id).decisao.derived == @tarefa
    end
  end

  describe "a discordância entre rótulo e estrutura" do
    test "tarefa com partes mantém o conceito e ganha divergência",
         %{tenant: t, org: org, user: u, cenario: c} do
      {pai, _} = arvore(t, c, ["", ""])

      {:ok, _} =
        Mapping.create_rule(
          t,
          org,
          %{
            where: "title",
            how: "starts_with",
            pattern: pai.title,
            target_concept: @tarefa
          },
          u.id
        )

      linha = conceito(t, org, pai.id)

      assert linha.decisao.derived == @tarefa, """
      O conceito é MANTIDO. Fazer a estrutura vencer custaria 319 user stories declaradas
      para consertar 9 tarefas com partes — medido no dado real. E nenhum axioma proíbe
      tarefa com partes: `sro.rule07` proíbe tarefa ATENDER épico, que é outra relação.
      """

      assert linha.decisao.divergence =~ "tem 2 partes coletadas"
      assert linha.decisao.divergence =~ "não é modelada"
    end

    test "user story sem partes mantém o conceito e ganha divergência",
         %{tenant: t, org: org, user: u, cenario: c} do
      {:ok, _} =
        Mapping.create_rule(
          t,
          org,
          %{
            where: "title",
            how: "starts_with",
            pattern: "issue #203",
            target_concept: @atomica
          },
          u.id
        )

      linha = conceito(t, org, c.issues[203].pai.id)

      assert linha.decisao.derived == @atomica
      assert linha.decisao.divergence =~ "ainda não decomposta"
    end

    test "quando rótulo e estrutura concordam, não há divergência",
         %{tenant: t, org: org, cenario: c} do
      # #201 é `Task` declarada e é folha: as duas dizem tarefa.
      linha = conceito(t, org, c.issues[201].pai.id)

      assert linha.decisao.derived == @tarefa
      assert linha.decisao.divergence == nil
    end
  end

  # Cria um pai sem tipo com N partes sem tipo, opcionalmente sob um pai já existente.
  defp arvore(tenant, cenario, partes, sob \\ nil) do
    n = System.unique_integer([:positive])

    {:ok, pai} =
      WorkItems.record_collected_issue(tenant, %{
        observed_repository_id: cenario.observed_repository_id,
        number: n,
        title: "sem tipo #{n}",
        state: "OPEN",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_arvore_#{n}"
      })

    filhos =
      for _ <- partes do
        m = System.unique_integer([:positive])

        {:ok, filho} =
          WorkItems.record_collected_issue(tenant, %{
            observed_repository_id: cenario.observed_repository_id,
            number: m,
            title: "sem tipo #{m}",
            state: "OPEN",
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "I_arvore_#{m}"
          })

        {:ok, _} =
          WorkItems.record_decomposition_link(tenant, %{
            parent_issue_id: pai.id,
            child_issue_id: filho.id
          })

        filho
      end

    if sob do
      {:ok, _} =
        WorkItems.record_decomposition_link(tenant, %{
          parent_issue_id: sob.id,
          child_issue_id: pai.id
        })
    end

    {pai, filhos}
  end
end
