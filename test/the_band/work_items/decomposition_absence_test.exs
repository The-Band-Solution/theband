defmodule TheBand.WorkItems.DecompositionAbsenceTest do
  @moduledoc """
  `mark_decomposition_links_no_longer_observed/3` — o vínculo que a origem não declara
  mais (T001 a T004, issue #263).

  ## O que este teste mede, e por que quase tudo aqui é `refute`

  O defeito desta família **não levanta erro**: a plataforma continua afirmando uma
  decomposição que a origem largou, e a tela fica com cara de completa. Marcar demais tem
  a mesma assinatura — nada falha, e observação verdadeira desaparece.

  Por isso quatro dos seis casos asserem **ausência de efeito**: outro repositório
  intacto, outro tenant intacto, vínculo revisto intacto, e marca antiga não reescrita.

  A medida de 2026-08-12 que originou a feature: 1 666 vínculos, **0** marcados, e **52**
  que a última coleta não reviu — com pai e filha ainda vigentes nos 52.
  """
  use TheBand.DataCase, async: true

  import Ecto.Query
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Repo
  alias TheBand.WorkItems
  alias TheBand.WorkItems.Schemas.DecompositionLink

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    %{tenant: tenant, cenario: cenario}
  end

  describe "o corte" do
    test "marca o vínculo que a execução não reviu", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      vinculo = vinculo(pai, parte)
      recuar(vinculo, minutos: 30)

      assert {:ok, 1} =
               WorkItems.mark_decomposition_links_no_longer_observed(
                 ctx.tenant,
                 ctx.cenario.observed_repository_id,
                 corte()
               )

      assert recarregar(vinculo).no_longer_observed_at
    end

    test "não marca o vínculo revisto durante a própria execução", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      vinculo = vinculo(pai, parte)

      # Cada vínculo fica anterior ao corte — é o estado de quem não foi revisto.
      recuar_todos(30)

      # E este é revisto: `record_decomposition_link/2` carimba com o instante da escrita,
      # sempre **posterior** ao início da execução. É por isso que o corte é o início e não
      # "agora": cortar por "agora" marcaria o vínculo que a execução acabou de renovar.
      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: pai.id,
          child_issue_id: parte.id
        })

      {:ok, marcados} =
        WorkItems.mark_decomposition_links_no_longer_observed(
          ctx.tenant,
          ctx.cenario.observed_repository_id,
          corte()
        )

      assert marcados > 0, "os que não foram revistos precisavam ser marcados"
      refute recarregar(vinculo).no_longer_observed_at
    end

    test "a data gravada é o instante em que se notou, não o corte", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      vinculo = vinculo(pai, parte)
      recuar(vinculo, minutos: 30)
      corte = DateTime.add(agora(), -600, :second)

      {:ok, 1} =
        WorkItems.mark_decomposition_links_no_longer_observed(
          ctx.tenant,
          ctx.cenario.observed_repository_id,
          corte
        )

      marca = recarregar(vinculo).no_longer_observed_at

      assert DateTime.compare(marca, corte) == :gt, """
      A marca recebeu o instante do corte, e não o instante em que a ausência foi notada.

      `mark_issues_no_longer_observed/3`, `replace_assignees/3` e `replace_labels/3` gravam
      `DateTime.utc_now/1`. Gravar o `started_at` aqui daria à mesma coluna dois significados
      em tabelas vizinhas, e qualquer pergunta que atravessasse as duas compararia coisas
      diferentes.
      """
    end
  end

  describe "o escopo" do
    test "não alcança o vínculo cujo pai está em outro repositório", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      vinculo = vinculo(pai, parte)
      recuar(vinculo, minutos: 30)

      outro = repositorio_observado(ctx.tenant, ctx.cenario, "outro-repo")

      assert {:ok, 0} =
               WorkItems.mark_decomposition_links_no_longer_observed(
                 ctx.tenant,
                 outro,
                 corte()
               )

      refute recarregar(vinculo).no_longer_observed_at, """
      Coletar um repositório marcou vínculo declarado por outro.

      Quem declara a decomposição é o **pai** — as partes vêm dentro dele. São 57 os
      vínculos cuja filha está em outro repositório, e escopar pela filha os marcaria toda
      vez que o repositório dela fosse coletado sem o do pai.
      """
    end

    test "não alcança vínculo de outro tenant", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      recuar(vinculo(pai, parte), minutos: 30)

      vizinho = tenant_fixture()
      cenario_vizinho = cenario_real(vizinho, "Outra-Org")
      %{pai: pai_vizinho, partes: [parte_vizinha | _]} = cenario_vizinho.issues[3]
      do_vizinho = vinculo(pai_vizinho, parte_vizinha)
      recuar(do_vizinho, minutos: 30)

      assert {:ok, 1} =
               WorkItems.mark_decomposition_links_no_longer_observed(
                 ctx.tenant,
                 ctx.cenario.observed_repository_id,
                 corte()
               )

      refute recarregar(do_vizinho).no_longer_observed_at, """
      A marca atravessou a fronteira do tenant.

      O escopo do `UPDATE` chega pelo `parent_issue_id`, e sem o filtro de tenant um
      identificador de outro tenant passaria — o que a constituição trata como bug de
      segurança, não de correção.
      """
    end
  end

  describe "a idempotência" do
    test "a segunda chamada não marca nada e não muda data nenhuma", ctx do
      %{pai: pai, partes: partes} = ctx.cenario.issues[3]
      for parte <- partes, do: recuar(vinculo(pai, parte), minutos: 30)

      {:ok, primeira} =
        WorkItems.mark_decomposition_links_no_longer_observed(
          ctx.tenant,
          ctx.cenario.observed_repository_id,
          corte()
        )

      assert primeira == length(partes)
      antes = datas(ctx.tenant)

      assert {:ok, 0} =
               WorkItems.mark_decomposition_links_no_longer_observed(
                 ctx.tenant,
                 ctx.cenario.observed_repository_id,
                 corte()
               )

      assert datas(ctx.tenant) == antes, """
      A segunda coleta reescreveu a data de vínculos já marcados.

      O que se registra é **quando deixou de ser visto**, não quando se olhou de novo. Uma
      data que avança a cada coleta transformaria "sumiu ontem" em "sumiu agora".
      """
    end

    test "coleta posterior não reescreve a data de quem já estava marcado", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      vinculo = vinculo(pai, parte)
      recuar(vinculo, minutos: 30)

      {:ok, 1} =
        WorkItems.mark_decomposition_links_no_longer_observed(
          ctx.tenant,
          ctx.cenario.observed_repository_id,
          corte()
        )

      marcado_em = recarregar(vinculo).no_longer_observed_at

      # Um corte posterior alcança **todos** os vínculos que a execução não reviu — o que
      # está certo, e por isso a asserção não é sobre a contagem. É sobre a data de quem
      # já estava marcado: essa não se toca.
      {:ok, _outros} =
        WorkItems.mark_decomposition_links_no_longer_observed(
          ctx.tenant,
          ctx.cenario.observed_repository_id,
          DateTime.add(agora(), 60, :second)
        )

      assert DateTime.compare(recarregar(vinculo).no_longer_observed_at, marcado_em) == :eq, """
      A data de um vínculo já ausente foi reescrita por coleta posterior.

      `is_nil(no_longer_observed_at)` no `WHERE` existe para isso. Sem ele, "sumiu na coleta
      das 9h" viraria "sumiu na coleta das 18h" a cada execução, e a data deixaria de
      responder a pergunta que ela existe para responder.
      """
    end
  end

  describe "a ressurreição" do
    test "o vínculo que volta a ser declarado volta a vigente, com a observação original", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      vinculo = vinculo(pai, parte)
      observado_em = vinculo.observed_at
      recuar(vinculo, minutos: 30)

      {:ok, 1} =
        WorkItems.mark_decomposition_links_no_longer_observed(
          ctx.tenant,
          ctx.cenario.observed_repository_id,
          corte()
        )

      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: pai.id,
          child_issue_id: parte.id
        })

      renovado = recarregar(vinculo)

      refute renovado.no_longer_observed_at, "quem devolve vigência é a coleta"

      assert DateTime.compare(renovado.observed_at, observado_em) == :eq, """
      A ressurreição reescreveu a data da **primeira** observação.

      `base.observed_at || now` existe para isso: o vínculo que voltou é o mesmo vínculo, e
      perder quando ele foi visto pela primeira vez apagaria metade da proveniência.
      """
    end
  end

  defp agora, do: DateTime.utc_now(:second)

  # O corte é sempre **passado**, e nunca `agora()`: montar o cenário leva centenas de
  # milissegundos e atravessa a virada do segundo, e um corte no instante da chamada
  # alcançaria vínculos que a fixture acabou de gravar. Quinze minutos atrás separa o que
  # foi recuado de propósito do que a montagem escreveu.
  defp corte, do: DateTime.add(agora(), -15 * 60, :second)

  defp recuar_todos(minutos) do
    Repo.update_all(
      from(l in DecompositionLink),
      set: [last_observed_at: DateTime.add(agora(), -minutos * 60, :second)]
    )
  end

  defp vinculo(pai, parte) do
    Repo.get_by!(DecompositionLink, parent_issue_id: pai.id, child_issue_id: parte.id)
  end

  defp recarregar(%DecompositionLink{id: id}), do: Repo.get!(DecompositionLink, id)

  # Recuar o "visto pela última vez" é como se monta, no banco, o que a origem produz ao
  # parar de declarar a parte: o vínculo fica com carimbo anterior ao início da coleta.
  defp recuar(%DecompositionLink{id: id}, minutos: minutos) do
    Repo.update_all(
      from(l in DecompositionLink, where: l.id == ^id),
      set: [last_observed_at: DateTime.add(agora(), -minutos * 60, :second)]
    )
  end

  defp datas(_tenant) do
    Repo.all(
      from(l in DecompositionLink,
        select: {l.id, l.no_longer_observed_at},
        order_by: l.id
      )
    )
  end

  defp repositorio_observado(tenant, cenario, nome) do
    {:ok, repo} =
      CMPO.upsert_source_repository_from_source(tenant, %{
        organization_id: cenario.organization.id,
        name: nome,
        qualified_name: "The-Band-Solution/#{nome}",
        url: "https://github.com/The-Band-Solution/#{nome}",
        default_branch: "main",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "R_#{nome}"
      })

    {:ok, observado} = CMPO.observe_repository(tenant, cenario.tool.id, repo.id)
    observado.id
  end
end
