defmodule TheBand.WorkItems.PersonWorkTest do
  @moduledoc """
  O trabalho derivado de uma pessoa (T003, T004, T005).

  ## O cruzamento que a análise achou

  Há **duas** marcas de ausência — em `collected_issues` e em `issue_assignees` —, e o caso
  "designação vigente numa issue ausente" não tinha regra. Ele tem agora: **a issue manda**, porque
  a pessoa não trabalha no que a plataforma não observa mais.

  E nenhum teste aqui soma designação com autoria: **nada no código deveria poder somá-las.**
  """
  use TheBand.DataCase, async: true

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    {:ok, pessoa} = pessoa(tenant, "ana")
    %{tenant: tenant, cenario: cenario, pessoa: pessoa}
  end

  describe "as duas contagens" do
    test "designação e autoria são contadas separadas", ctx do
      [uma, outra | _] = issues(ctx.cenario)

      designar(ctx.tenant, uma, ctx.pessoa)
      autorar(ctx.tenant, outra, ctx.pessoa)

      assert WorkItems.count_assigned_to(ctx.tenant, ctx.pessoa.id) == 1
      assert WorkItems.count_authored_by(ctx.tenant, ctx.pessoa.id) == 1
    end

    test "designação ausente não conta", ctx do
      [uma | _] = issues(ctx.cenario)
      designar(ctx.tenant, uma, ctx.pessoa)

      # Substituir os designados por lista vazia marca o anterior como ausente — a plataforma não
      # apaga, marca.
      {:ok, _} = WorkItems.replace_assignees(ctx.tenant, uma.id, [])

      assert WorkItems.count_assigned_to(ctx.tenant, ctx.pessoa.id) == 0
    end

    test "issue ausente com designação vigente TAMBÉM não conta", ctx do
      [uma | _] = issues(ctx.cenario)
      designar(ctx.tenant, uma, ctx.pessoa)
      assert WorkItems.count_assigned_to(ctx.tenant, ctx.pessoa.id) == 1

      # A issue sai da observação; a designação continua vigente, porque a marca de ausência é por
      # repositório coletado e não desce para ela.
      depois = DateTime.add(DateTime.utc_now(:second), 1, :second)

      {:ok, _} =
        WorkItems.mark_issues_no_longer_observed(
          ctx.tenant,
          ctx.cenario.observed_repository_id,
          depois
        )

      assert WorkItems.count_assigned_to(ctx.tenant, ctx.pessoa.id) == 0, """
      A issue deixou de ser observada e a designação continuou contando.

      É o caso que a análise achou sem definição, e a regra é: **a issue manda**. A pessoa não
      trabalha no que a plataforma não observa mais — contar isso faria a página afirmar trabalho
      sobre algo que não está mais lá.
      """
    end

    test "autoria em issue ausente não conta", ctx do
      [uma | _] = issues(ctx.cenario)
      autorar(ctx.tenant, uma, ctx.pessoa)

      depois = DateTime.add(DateTime.utc_now(:second), 1, :second)

      {:ok, _} =
        WorkItems.mark_issues_no_longer_observed(
          ctx.tenant,
          ctx.cenario.observed_repository_id,
          depois
        )

      assert WorkItems.count_authored_by(ctx.tenant, ctx.pessoa.id) == 0
    end

    test "não conta pessoa de outro tenant", ctx do
      [uma | _] = issues(ctx.cenario)
      designar(ctx.tenant, uma, ctx.pessoa)
      outro = tenant_fixture()

      assert WorkItems.count_assigned_to(outro, ctx.pessoa.id) == 0
    end
  end

  describe "a invariante das autorias" do
    test "a soma sobre as pessoas fecha com o total de issues com autor", ctx do
      [uma, outra | _] = issues(ctx.cenario)
      {:ok, bea} = pessoa(ctx.tenant, "bea")

      autorar(ctx.tenant, uma, ctx.pessoa)
      autorar(ctx.tenant, outra, bea)

      soma =
        ctx.tenant
        |> EO.list_people()
        |> Enum.map(&WorkItems.count_authored_by(ctx.tenant, &1.id))
        |> Enum.sum()

      com_autor = Repo.aggregate(com_autor_query(ctx.tenant), :count)

      assert soma == com_autor, """
      A soma das autorias por pessoa (#{soma}) não fecha com o total de issues que têm autor
      (#{com_autor}).

      É a invariante que prova que as issues **sem** autor não foram atribuídas a alguém por
      engano — no dado real são 288, e a spec afirma que elas não aparecem em página de pessoa
      nenhuma. Antes da análise essa afirmação não tinha verificação.
      """
    end
  end

  describe "o filtro por pessoa tem dois nomes" do
    test "assigned_to e authored_by devolvem conjuntos diferentes", ctx do
      [uma, outra | _] = issues(ctx.cenario)
      designar(ctx.tenant, uma, ctx.pessoa)
      autorar(ctx.tenant, outra, ctx.pessoa)

      designadas = WorkItems.list_issues(ctx.tenant, assigned_to: ctx.pessoa.id)
      abertas = WorkItems.list_issues(ctx.tenant, authored_by: ctx.pessoa.id)

      assert Enum.map(designadas, & &1.id) == [uma.id]
      assert Enum.map(abertas, & &1.id) == [outra.id]

      refute Enum.map(designadas, & &1.id) == Enum.map(abertas, & &1.id), """
      As duas opções devolveram o mesmo conjunto, o que significa que o filtro está ignorando o
      papel.

      "As issues da pessoa" são três conjuntos, e a união é a que não corresponde a nada — quem
      abre uma issue não necessariamente trabalha nela.
      """
    end
  end

  describe "os repositórios da pessoa" do
    test "vêm agrupados, com as duas contagens separadas", ctx do
      [uma, outra | _] = issues(ctx.cenario)
      designar(ctx.tenant, uma, ctx.pessoa)
      autorar(ctx.tenant, outra, ctx.pessoa)

      assert [linha] = WorkItems.repositories_of_person(ctx.tenant, ctx.pessoa.id)

      assert linha.observed_repository_id == ctx.cenario.observed_repository_id
      assert linha.assigned == 1
      assert linha.authored == 1

      refute Map.has_key?(linha, :total), """
      A linha traz um total, e ele é a soma proibida: designação e autoria não se somam.
      """
    end

    test "não devolve o nome do repositório, e é de propósito", ctx do
      [uma | _] = issues(ctx.cenario)
      designar(ctx.tenant, uma, ctx.pessoa)

      assert [linha] = WorkItems.repositories_of_person(ctx.tenant, ctx.pessoa.id)

      refute Map.has_key?(linha, :name), """
      O nome do repositório é de CMPO, e `WorkItems` juntar `cmpo_source_repositories` quebraria a
      fronteira que o princípio IX protege. Quem chama resolve com **uma** consulta virando mapa.
      """
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp issues(cenario) do
    cenario.issues |> Map.values() |> Enum.map(& &1.pai) |> Enum.sort_by(& &1.number)
  end

  defp pessoa(tenant, login) do
    # `account_type` é o vocabulário da **ontologia** — `person`, `bot`, `app` —, e não o da
    # origem, que diz `User`. E `collected_at` é obrigatório: sem ele a Application Reference fica
    # incompleta, e a proveniência é não negociável.
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

  defp com_autor_query(tenant) do
    import Ecto.Query

    from i in "collected_issues",
      where:
        i.tenant_id == type(^tenant.id, :binary_id) and not is_nil(i.author_person_id) and
          is_nil(i.no_longer_observed_at)
  end
end
