defmodule TheBand.WorkItems.CustoDaVigenteTest do
  @moduledoc """
  O custo de resolver a promoção vigente, e a invariante que ele não pode quebrar
  (T008 e T010, feature 013).

  ## Por que o teste mede linhas lidas, e não milissegundos

  Relógio dentro da suíte reprova em CI carregada e passa em máquina ociosa — é a **L22**: gate que
  compara duas execuções não sabe dizer se alguma funcionou. O que se mede aqui é **quantas linhas
  de `issue_promotions` o banco leu**, que é o número que a feature existe para derrubar.

  ## E a invariante, que é o que impede a troca silenciosa

  `count_collected == soma(count_by_promotion) + soma(count_gaps_by_reason)` está no `@moduledoc` de
  `Queries` desde a feature 005. Trocar `inner` por `left` nas contagens faria a soma **passar** do
  total, e nada falharia — o número simplesmente ficaria maior que a realidade.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Repo
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    %{tenant: tenant, cenario: cenario}
  end

  describe "a invariante das contagens" do
    test "o total coletado fecha com promovidas mais lacunas", ctx do
      total = WorkItems.count_collected(ctx.tenant)
      promovidas = ctx.tenant |> WorkItems.count_by_promotion() |> soma()
      lacunas = ctx.tenant |> WorkItems.count_gaps_by_reason() |> soma()

      assert total == promovidas + lacunas, """
      A soma das classificadas passou do total coletado.

      É o que aconteceria se as contagens passassem a usar `left` no lugar de `inner`: a issue sem
      promoção entraria nos dois lados da soma. Nada falharia — a tela mostraria um número maior
      que a realidade.
      """
    end

    test "issue sem promoção não desloca a invariante", ctx do
      {:ok, _} =
        WorkItems.record_collected_issue(ctx.tenant, %{
          observed_repository_id: ctx.cenario.observed_repository_id,
          number: 9_200,
          title: "sem promoção",
          state: "OPEN",
          issue_type: "Spike",
          source_system: "github",
          source_instance: "https://github.com",
          external_id: "I_9200"
        })

      total = WorkItems.count_collected(ctx.tenant)
      promovidas = ctx.tenant |> WorkItems.count_by_promotion() |> soma()
      lacunas = ctx.tenant |> WorkItems.count_gaps_by_reason() |> soma()

      assert total == promovidas + lacunas + 1, """
      A issue que nenhuma regra promoveu não ficou de fora das contagens.

      Ela não é de conceito nenhum e não tem motivo de lacuna registrado — é trabalho coletado e
      não classificado, e some das duas contagens de propósito.
      """
    end
  end

  describe "o custo não cresce com o histórico" do
    test "dobrar as promoções não dobra as linhas lidas", ctx do
      simples = linhas_de_promocao_lidas(ctx.tenant)
      antes = Repo.aggregate(TheBand.WorkItems.Schemas.IssuePromotion, :count)

      dobrar_historico(ctx)

      depois = Repo.aggregate(TheBand.WorkItems.Schemas.IssuePromotion, :count)
      dobrado = linhas_de_promocao_lidas(ctx.tenant)

      assert depois > antes, "o histórico não foi dobrado — o teste não mediu o que diz medir"

      assert simples > 0, """
      A medida de linhas lidas deu zero, e um teste que compara zero com zero passa sempre.

      Ou o `EXPLAIN` não achou `issue_promotions` no plano — o que seria a consulta ter deixado de
      olhar a promoção —, ou a extração do número quebrou. Nos dois casos, o que passou não foi a
      garantia.
      """

      assert dobrado <= simples * 1.5, """
      Dobrar o histórico de promoções dobrou o trabalho da consulta.

      Foi exatamente esse crescimento que levou a página de uma pessoa a 6,12 s no dado real: a
      resolução da vigente varria todas as promoções do tenant, e a tabela cresce a cada coleta.

      linhas lidas com histórico simples: #{simples}
      linhas lidas com histórico dobrado: #{dobrado}
      """
    end
  end

  defp soma(mapa), do: mapa |> Map.values() |> Enum.sum()

  # Quantas linhas de `issue_promotions` o banco leu para montar a lista.
  #
  # **O SQL vem por telemetria, e não de dentro do módulo.** Nenhuma função de `Queries` devolve
  # `Ecto.Query` — é a fronteira da ADR 0003 —, então o teste escuta o evento que o Ecto já emite,
  # pega a consulta que a função pública executou, e roda `EXPLAIN (ANALYZE)` sobre ela. Assim o que
  # se mede é o código real, e não uma consulta reescrita à mão que poderia divergir dele.
  defp linhas_de_promocao_lidas(tenant) do
    {sql, params} = capturar_consulta(fn -> WorkItems.list_issues(tenant, limit: 25) end)

    {:ok, %{rows: [[json]]}} =
      Repo.query("EXPLAIN (ANALYZE, FORMAT JSON) " <> sql, params)

    somar_linhas(json)
  end

  # Percorre o plano em vez de casar texto: as chaves do JSON do Postgres vêm em ordem alfabética,
  # e `"Actual Rows"` aparece **antes** de `"Relation Name"` — uma expressão regular escrita na
  # ordem em que a gente lê o plano não casa nunca, e devolve zero em silêncio.
  #
  # **Linhas vezes loops**, e não linhas: em junção lateral o nó roda uma vez por linha externa, e
  # `Actual Rows` é o que ele devolveu **em cada** execução. Contar só as linhas diria que a versão
  # lateral lê duas, quando ela lê duas por issue exibida.
  defp somar_linhas(%{"Plan" => plano}), do: somar_linhas(plano)

  defp somar_linhas(%{} = no) do
    proprio =
      if no["Relation Name"] == "issue_promotions",
        do: trunc((no["Actual Rows"] || 0) * (no["Actual Loops"] || 1)),
        else: 0

    proprio + somar_linhas(no["Plans"] || [])
  end

  defp somar_linhas(lista) when is_list(lista),
    do: lista |> Enum.map(&somar_linhas/1) |> Enum.sum()

  defp somar_linhas(_), do: 0

  defp capturar_consulta(fun) do
    ref = make_ref()
    pai = self()

    handler = fn _evento, _medidas, %{query: query, params: params}, _config ->
      if String.contains?(query, "issue_promotions"), do: send(pai, {ref, query, params})
    end

    :telemetry.attach({__MODULE__, ref}, [:the_band, :repo, :query], handler, nil)
    fun.()
    :telemetry.detach({__MODULE__, ref})

    receive do
      {^ref, sql, params} -> {sql, params}
    after
      0 -> flunk("nenhuma consulta tocou issue_promotions — o teste não mediu o que diz medir")
    end
  end

  defp dobrar_historico(ctx) do
    for {_n, %{pai: pai}} <- ctx.cenario.issues do
      {:ok, _} =
        WorkItems.record_promotion(ctx.tenant, %{
          collected_issue_id: pai.id,
          declared_concept: "Feature",
          derived_concept: "sro.epic",
          rule_id: "dobra",
          rule_version: 1,
          evidence_source: "declared_type",
          promoted_at: DateTime.utc_now(:second)
        })
    end
  end
end
