defmodule TheBand.WorkItems.ParentsTest do
  @moduledoc """
  `list_parents/2` — os pais de um conjunto de issues, numa consulta (T002).

  ## As três coisas que este teste mede, e não presume

  1. **uma** consulta para a página inteira — a feature 007 nasceu com 135 por render;
  2. a **ordem**, que `fetch_parent/2` não garante: `limit: 1` sem `order_by` devolve pai arbitrário
     para as 36 issues com mais de um pai;
  3. o vínculo **ausente** vem marcado — e vem porque ausência é marcada, nunca removida.

  ## E o que ele deixa registrado

  Nada no código marca vínculo de decomposição como ausente hoje (issue #263). O teste monta o
  estado direto no banco, porque o caminho de exibição precisa estar pronto **antes** de o dado
  chegar nesse estado — que é o que impede a tela de inventar quando chegar.
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Repo
  alias TheBand.WorkItems
  alias TheBand.WorkItems.Schemas.DecompositionLink

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    cenario = cenario_real(tenant)
    %{tenant: tenant, cenario: cenario}
  end

  describe "o agrupamento" do
    test "cada filha vem com os pais dela, e issue sem pai não vira chave", ctx do
      %{pai: pai, partes: partes} = ctx.cenario.issues[3]
      ids = Enum.map(partes, & &1.id)

      mapa = WorkItems.list_parents(ctx.tenant, ids ++ [pai.id])

      assert map_size(mapa) == length(ids)
      refute Map.has_key?(mapa, pai.id)

      for id <- ids do
        assert [%{id: encontrado, number: numero}] = mapa[id]
        assert encontrado == pai.id
        assert numero == pai.number
      end
    end

    test "o pai vem com o conceito da promoção vigente", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[1]

      assert [%{derived_concept: "sro.epic"}] =
               WorkItems.list_parents(ctx.tenant, [parte.id])[parte.id]

      assert pai.number == 1
    end

    test "lista vazia devolve mapa vazio sem consultar", ctx do
      assert contar_consultas(fn -> WorkItems.list_parents(ctx.tenant, []) end) == 0
    end
  end

  describe "o custo" do
    test "uma consulta, com 50 filhas na entrada", ctx do
      ids = ctx.cenario.issues |> Map.values() |> Enum.flat_map(& &1.partes) |> Enum.map(& &1.id)

      assert length(ids) >= 50

      assert contar_consultas(fn -> WorkItems.list_parents(ctx.tenant, ids) end) == 1
    end
  end

  describe "mais de um pai" do
    test "os dois vêm, na mesma ordem em duas chamadas", ctx do
      %{partes: [parte | _]} = ctx.cenario.issues[3]
      outro = ctx.cenario.issues[4].pai

      {:ok, _} =
        WorkItems.record_decomposition_link(ctx.tenant, %{
          parent_issue_id: outro.id,
          child_issue_id: parte.id
        })

      uma = WorkItems.list_parents(ctx.tenant, [parte.id])[parte.id]
      outra = WorkItems.list_parents(ctx.tenant, [parte.id])[parte.id]

      assert length(uma) == 2
      assert uma == outra
      assert Enum.map(uma, & &1.number) == Enum.sort(Enum.map(uma, & &1.number))
    end
  end

  describe "o vínculo ausente" do
    test "vem, e vem marcado com a data", ctx do
      %{pai: pai, partes: [parte | _]} = ctx.cenario.issues[3]
      quando = ~U[2026-08-01 00:00:00Z]

      Repo.update_all(
        from(l in DecompositionLink,
          where: l.parent_issue_id == ^pai.id and l.child_issue_id == ^parte.id
        ),
        set: [no_longer_observed_at: quando]
      )

      assert [%{no_longer_observed_at: ^quando}] =
               WorkItems.list_parents(ctx.tenant, [parte.id])[parte.id]
    end
  end

  describe "o escopo" do
    test "filha de outro tenant não devolve pai nenhum", ctx do
      %{partes: [parte | _]} = ctx.cenario.issues[3]
      outro = tenant_fixture()

      assert WorkItems.list_parents(outro, [parte.id]) == %{}
    end
  end

  # A mesma contagem por telemetria que `person_detail_test.exs` usa — e é a única forma honesta:
  # "um número que não cresce" passa com 1 e passa com 50.
  defp contar_consultas(fun) do
    ref = make_ref()
    pai = self()

    handler = fn _evento, _medidas, %{query: query}, _config ->
      if String.starts_with?(query, "SELECT"), do: send(pai, {ref, :consulta})
    end

    :telemetry.attach({__MODULE__, ref}, [:the_band, :repo, :query], handler, nil)
    fun.()
    :telemetry.detach({__MODULE__, ref})

    contar(ref, 0)
  end

  defp contar(ref, total) do
    receive do
      {^ref, :consulta} -> contar(ref, total + 1)
    after
      0 -> total
    end
  end
end
