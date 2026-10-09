defmodule TheBand.NetworkAnalysis.TetoTest do
  @moduledoc """
  O teto e o tempo do job — feature 076, T050 (FR-017; research.md R5; `contracts/job.md`,
  `timeout/1` de 120 s).

  `Commands.compute/5` sobre um G(n, m) do tamanho do teto (300 pessoas, 3 000 ligações sem
  direção), nas duas redes e nas três janelas — as seis combinações de um job —, com os
  parâmetros da base. A medida está em `research.md` R5; o teto do teste vem dela, com folga
  (L53: o teto vem da medida dos dois lados).

  Tag `:slow`: o gate o roda; localmente, `mix test --exclude slow` o pula.

  **Defeito a injetar**: a medida dos aleatórios em sequência (`Enum.map/2` no lugar de
  `Task.async_stream/3` em `SmallWorld`); o teto reprova — medido em 2026-10-06, 108,2 s. O
  defeito do texto da tarefa (1 000 aleatórios) também reprova, mas passa antes dos 120 s de
  posse do sandbox e cai por ele, e não pelo assert; 300 aleatórios ficaram em 89,8 s, no limite,
  e por isso não servem de prova.
  """
  use TheBand.DataCase, async: false

  alias TheBand.NetworkAnalysis.Algorithms.Random
  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.Ontology.KnowledgeBase

  @moduletag :slow
  @moduletag timeout: 600_000

  # O teto do teste, em milissegundos (research.md R5). Medido: 105,6 s e 108,2 s sem
  # paralelismo, que passariam perto dos 120 s do job; de 32,9 s a 50,2 s com a medida dos
  # aleatórios em paralelo, numa máquina de 10 núcleos, conforme a carga. O teto fica abaixo do
  # tempo do job, com folga para a máquina do CI, e abaixo do custo sem paralelismo.
  @teto_ms 90_000

  test "as seis combinações de um G(300, 3000) cabem no tempo do job" do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    org = organization_fixture(tenant)
    parametros = Parameters.fetch!()

    n = parametros.size_limit.max_people
    m = parametros.size_limit.max_undirected_edges
    ids = for _i <- 1..n, do: Ecto.UUID.generate()
    {pares, _} = Random.gnm(Random.new(76), n, m)

    arestas =
      for {u, v} <- pares,
          do: %{source: Enum.at(ids, u - 1), target: Enum.at(ids, v - 1), weight: 1}

    entrada = %{
      edges: arestas,
      exclusions: %{"issues" => m},
      people_without_edges: 0,
      source_computed_at: nil,
      provenance: %{}
    }

    {us, {:ok, relator, _ids}} =
      :timer.tc(fn ->
        Commands.compute(tenant, org, DateTime.utc_now(:second), parametros, fn _, _, _ ->
          {:ok, entrada}
        end)
      end)

    ms = div(us, 1000)
    IO.puts("T050: G(#{n}, #{m}), 6 combinações: #{ms} ms")

    # Mediu: as seis foram calculadas, abaixo do teto (σ e Q_rand presentes).
    assert length(relator.readings) == 6
    assert Enum.all?(relator.readings, &(&1.outcome == :computed and &1.absent == []))
    assert ms < @teto_ms, "#{ms} ms passa do teto de #{@teto_ms} ms"
  end
end
