defmodule TheBand.Ingestion.MarcaEscopadaTest do
  @moduledoc """
  A marca de vínculo ausente é escopada pelo que foi **olhado** (T005).

  ## O defeito que este teste impede

  Até 2026-08-14, `mark_decomposition_links_no_longer_observed/3` recebia o
  `observed_repository_id` e marcava os vínculos de **todos** os pais daquele repositório.
  Estava certa por acidente: só dizia a verdade enquanto a coleta era completa.

  Na coleta incremental da feature 020, reler 34 issues de um repositório com 4295 deixaria
  4261 pais sem revisão — e todos os vínculos deles com `last_observed_at` anterior ao corte.

  **A marca não pararia de funcionar. Marcaria tudo.** Os 52 vínculos legitimamente ausentes
  viriam com milhares de falsos, e a plataforma passaria a afirmar que a origem largou uma
  decomposição que ela nunca largou.

  ## A asserção que importa não é a que marca

  É a que **não** marca. Um teste que só confirma "o vínculo largado foi marcado" passa
  igualmente bem com o defeito — porque com o defeito ele é marcado, junto com todos os
  outros. O que distingue os dois é contar quem ficou intacto.
  """
  use TheBand.DataCase, async: false

  alias TheBand.WorkItems

  setup do
    tenant = tenant_fixture()
    %{tenant: tenant, cenario: TheBand.WorkItemsFixtures.cenario_real(tenant)}
  end

  test "marca só os vínculos dos pais percorridos", ctx do
    corte = DateTime.utc_now(:second)

    # Dez pais, cada um com um vínculo que a origem largou — nenhum foi revisto desde antes
    # do corte. É o retrato de um repositório inteiro numa coleta incremental.
    pais = for n <- 1..10, do: pai_com_vinculo_antigo(ctx, n, corte)

    # Um só é percorrido, como aconteceria numa coleta que reencontrou uma issue alterada.
    percorrido = hd(pais)

    assert {:ok, 1} =
             WorkItems.mark_decomposition_links_no_longer_observed(
               ctx.tenant,
               [percorrido],
               corte
             )

    assert marcados(ctx.tenant) == 1, """
    Com o escopo por repositório, este número seria **dez**: os nove pais que a coleta não
    releu teriam seus vínculos marcados como ausentes sem que a origem tivesse dito nada.

    É esta asserção — e não a de que um foi marcado — que distingue o comportamento certo do
    defeito.
    """
  end

  test "lista vazia não marca nada", ctx do
    corte = DateTime.utc_now(:second)
    for n <- 1..5, do: pai_com_vinculo_antigo(ctx, n, corte)

    assert {:ok, 0} =
             WorkItems.mark_decomposition_links_no_longer_observed(ctx.tenant, [], corte)

    assert marcados(ctx.tenant) == 0, """
    Lista vazia é o repositório pulado. Tratá-la como "nenhum pai apareceu, então marque
    tudo" é exatamente o defeito que a assinatura nova existe para impedir — e seria o
    comportamento obtido por esquecimento se isto fosse um parâmetro opcional.
    """
  end

  test "vínculo revisto depois do corte continua vigente", ctx do
    corte = DateTime.utc_now(:second)
    pai = pai_com_vinculo_antigo(ctx, 1, corte)

    # O mesmo pai, revisto agora: o vínculo ganhou data posterior ao corte.
    revisar_vinculo(ctx, pai, DateTime.add(corte, 60, :second))

    assert {:ok, 0} =
             WorkItems.mark_decomposition_links_no_longer_observed(ctx.tenant, [pai], corte)

    assert marcados(ctx.tenant) == 0
  end

  test "vínculo de outro tenant não é tocado", ctx do
    corte = DateTime.utc_now(:second)
    pai = pai_com_vinculo_antigo(ctx, 1, corte)

    outro = tenant_fixture()

    assert {:ok, 0} =
             WorkItems.mark_decomposition_links_no_longer_observed(outro, [pai], corte)

    assert marcados(ctx.tenant) == 0, "o id existe, e é de outro tenant"
  end

  # ---------------------------------------------------------------- montagem

  defp pai_com_vinculo_antigo(ctx, n, corte) do
    pai = issue(ctx, 100 + n)
    filha = issue(ctx, 200 + n)

    {:ok, _} =
      WorkItems.record_decomposition_link(ctx.tenant, %{
        parent_issue_id: pai.id,
        child_issue_id: filha.id,
        relation: "sub_issue",
        source_system: "github",
        source_instance: "https://github.com"
      })

    # A origem parou de declarar: o vínculo ficou com data anterior ao corte.
    revisar_vinculo(ctx, pai, DateTime.add(corte, -3600, :second))

    pai.id
  end

  defp revisar_vinculo(ctx, pai_id, quando) when is_binary(pai_id) do
    Repo.update_all(
      from(l in TheBand.WorkItems.Schemas.DecompositionLink,
        where: l.tenant_id == ^ctx.tenant.id and l.parent_issue_id == ^pai_id
      ),
      set: [last_observed_at: quando]
    )
  end

  defp revisar_vinculo(ctx, %{id: id}, quando), do: revisar_vinculo(ctx, id, quando)

  defp issue(ctx, numero) do
    {:ok, issue} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        number: numero,
        title: "issue #{numero}",
        state: "OPEN",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_#{numero}",
        collected_at: DateTime.utc_now(:second),
        last_observed_at: DateTime.utc_now(:second)
      })

    issue
  end

  defp marcados(tenant) do
    Repo.aggregate(
      from(l in TheBand.WorkItems.Schemas.DecompositionLink,
        where: l.tenant_id == ^tenant.id and not is_nil(l.no_longer_observed_at)
      ),
      :count
    )
  end
end
