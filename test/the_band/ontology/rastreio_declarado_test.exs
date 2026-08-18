defmodule TheBand.Ontology.RastreioDeclaradoTest do
  @moduledoc """
  O rastreio pessoa → commit → solicitação → escopo é DECLARADO na rede — issue #426.

  ## Por que este teste existe

  Os mapeamentos de PR e commit afirmavam cinco vínculos que nenhuma relação sustentava:
  quem solicitou, quem integrou, quem fez o commit, o commit como parte da solicitação,
  e a solicitação atendendo o item de escopo. O validador da base pegou, e as relações
  foram declaradas em `cmpo.change_traceability` e `sro.scope_traceability`.

  Este teste é o que impede a cadeia de ser desfeita sem que alguém perceba: apagar uma
  relação faria a plataforma voltar a afirmar rastro sem lastro, e nenhum teste de tela
  notaria.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.KnowledgeBase

  setup_all do
    {:ok, _} = KnowledgeBase.load()
    :ok
  end

  defp relacoes do
    :module
    |> KnowledgeBase.list()
    |> Enum.flat_map(&(&1["relations"] || []))
    |> Map.new(fn r -> {r["id"], r} end)
  end

  test "as cinco relações do rastreio existem, e cada uma liga o par certo" do
    r = relacoes()

    esperado = [
      # quem solicitou: participação no ATO, nunca no objeto social
      {"cmpo.stakeholder_submitted_change_request", "spo.project_stakeholder",
       "cmpo.change_request_submission", "participation"},
      {"cmpo.submission_produced_change_request", "cmpo.change_request_submission",
       "cmpo.change_request", "causation"},
      # quem integrou
      {"cmpo.stakeholder_performed_checkin", "spo.project_stakeholder", "cmpo.checkin",
       "participation"},
      {"cmpo.checkin_integrated_change_request", "cmpo.checkin", "cmpo.change_request",
       "association"},
      # quem fez o commit
      {"cmpo.stakeholder_performed_commit", "spo.project_stakeholder",
       "cmpo.commit_artifact_copy", "participation"},
      # o elo do meio
      {"cmpo.commit_accomplished_change_request", "cmpo.commit_artifact_copy",
       "cmpo.change_request", "association"},
      # e o que fecha no escopo
      {"sro.change_request_attends_user_story", "cmpo.change_request", "sro.user_story",
       "association"}
    ]

    for {id, origem, destino, tipo} <- esperado do
      rel = r[id]

      assert rel, """
      A relação #{id} sumiu da rede.

      Sem ela, o mapeamento volta a afirmar o rastro sem relação que o sustente — que é
      o estado que a issue #426 corrigiu.
      """

      assert rel["source"] == origem, "#{id}: origem é #{rel["source"]}, esperada #{origem}"
      assert rel["target"] == destino, "#{id}: destino é #{rel["target"]}, esperado #{destino}"
      assert rel["type"] == tipo, "#{id}: tipo é #{rel["type"]}, esperado #{tipo}"
    end
  end

  test "participação nunca aponta para objeto social — ela exige atividade" do
    r = relacoes()

    participacoes =
      r
      |> Map.values()
      |> Enum.filter(&(&1["type"] == "participation" and String.starts_with?(&1["id"], "cmpo.")))

    assert participacoes != [], "nenhuma participação da CMPO foi encontrada"

    for p <- participacoes do
      refute p["target"] == "cmpo.change_request", """
      #{p["id"]} faz um agente participar de cmpo.change_request.

      Em UFO, participação é relação entre agente e EVENTO. A solicitação é objeto
      social — quem a submete participa do ATO de submeter
      (cmpo.change_request_submission), e é por isso que esse conceito existe.
      """
    end
  end

  test "o commit aceita mais de um autor, e a cardinalidade diz isso" do
    r = relacoes()
    commit = r["cmpo.stakeholder_performed_commit"]

    assert commit["cardinality"]["source"] == "many", """
    A participação no commit aceita um autor só.

    No dado real do The Band TODO commit tem dois — quem escreveu e o agente, pelo
    trailer Co-Authored-By. Cardinalidade `one` faria o modelo mentir sobre autoria
    compartilhada, e o mapeamento coleta `authors` no plural exatamente por isso.
    """
  end

  test "check-in e commit sem solicitação são representáveis — e isso é medida de processo" do
    r = relacoes()

    for id <- [
          "cmpo.checkin_integrated_change_request",
          "cmpo.commit_accomplished_change_request"
        ] do
      assert r[id]["cardinality"]["target"] == "zero_or_one", """
      #{id} exige uma solicitação de mudança.

      Commit direto na branch de destino existe e é comum. Exigir o PR tornaria o modelo
      incapaz de representar o trabalho que ninguém revisou — que é justamente o que uma
      medida de processo precisa enxergar.
      """
    end
  end
end
