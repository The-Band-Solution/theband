defmodule TheBand.NetworkAnalysis.AssignmentClassificationTest do
  @moduledoc """
  Cada designação em exatamente um destino — feature 076, T024 (US2, cenários 1 a 4; regra
  `assignment.network.edge`; research.md R12, R13).

  Os cinco cenários da US2 e o invariante da regra: soma dos pesos + as quatro exclusões = pares.
  """
  use ExUnit.Case, async: true

  alias TheBand.NetworkAnalysis.AssignmentClassification, as: C

  @inicio ~U[2026-09-01 00:00:00Z]
  @dentro ~U[2026-09-15 00:00:00Z]

  @ana "00000000-0000-0000-0000-00000000000a"
  @bia "00000000-0000-0000-0000-00000000000b"
  @caio "00000000-0000-0000-0000-00000000000c"
  @dora "00000000-0000-0000-0000-00000000000d"
  @robo "00000000-0000-0000-0000-0000000000b0"
  @org "00000000-0000-0000-0000-0000000000a0"
  @org_e_robo "00000000-0000-0000-0000-0000000000ab"

  @tipos %{
    @ana => "person",
    @bia => "person",
    @caio => "person",
    @dora => "person",
    @robo => "bot",
    @org => "person",
    # Uma conta que é as duas coisas: máquina em EO e declarada como da organização.
    @org_e_robo => "bot"
  }

  @contas MapSet.new([@org, @org_e_robo])

  defp par(issue, autor, responsavel, extra \\ %{}) do
    Map.merge(
      %{
        collected_issue_id: issue,
        opened_at: @dentro,
        assigned: true,
        author_person_id: autor,
        author_account_type: "person",
        assignee_person_id: responsavel,
        assignee_account_type: "person"
      },
      extra
    )
  end

  defp resumo(pares), do: pares |> C.classify(@tipos, @contas) |> C.summarize(@inicio)

  defp invariante!(%{edges: arestas, exclusions: e}) do
    pesos = arestas |> Enum.map(& &1.weight) |> Enum.sum()
    motivos = Enum.sum(for m <- C.order(), do: Map.fetch!(e, m))
    assert pesos + motivos == e["pairs"]
  end

  test "cen. 1: Ana → Bia com peso 4 e Ana → Caio com peso 2" do
    pares =
      for(i <- 1..4, do: par("i#{i}", @ana, @bia)) ++
        for(i <- 5..6, do: par("i#{i}", @ana, @caio))

    r = resumo(pares)

    assert r.edges == [
             %{source: @ana, target: @bia, weight: 4},
             %{source: @ana, target: @caio, weight: 2}
           ]

    assert r.exclusions["issues"] == 6
    invariante!(r)
  end

  test "cen. 2: a auto-designação não vira aresta e é contada" do
    r = resumo([par("i1", @ana, @ana), par("i2", @ana, @bia)])
    assert r.edges == [%{source: @ana, target: @bia, weight: 1}]
    assert r.exclusions["self_assignment"] == 1
    invariante!(r)
  end

  test "cen. 3: bot e conta da organização contados por motivo, sem login" do
    nao_ligado_bot = par("i3", nil, @bia, %{author_account_type: "bot"})

    r =
      resumo([
        par("i1", @robo, @bia),
        par("i2", @ana, @org),
        nao_ligado_bot,
        par("i4", @ana, @bia)
      ])

    assert r.exclusions["bot_or_app"] == 2
    assert r.exclusions["organization_account"] == 1
    assert r.edges == [%{source: @ana, target: @bia, weight: 1}]
    invariante!(r)
  end

  test "cen. 4: três responsáveis dão três arestas de peso 1, exceto o próprio autor" do
    r = resumo([par("i1", @ana, @bia), par("i1", @ana, @caio), par("i1", @ana, @ana)])

    assert r.edges == [
             %{source: @ana, target: @bia, weight: 1},
             %{source: @ana, target: @caio, weight: 1}
           ]

    assert r.exclusions["self_assignment"] == 1
    assert r.exclusions["issues"] == 1
    invariante!(r)
  end

  test "a conta que é máquina e da organização conta UMA vez, como máquina" do
    r = resumo([par("i1", @ana, @org_e_robo)])
    assert r.exclusions["bot_or_app"] == 1
    assert r.exclusions["organization_account"] == 0
    assert r.exclusions["pairs"] == 1
    invariante!(r)
  end

  test "sem pessoa ligada: tipo gravado person, e tipo nulo contado à parte" do
    r =
      resumo([
        par("i1", nil, @bia, %{author_account_type: "person"}),
        par("i2", nil, @bia, %{author_account_type: nil}),
        # Pessoa de outro tenant: não está no mapa de tipos, falha fechada.
        par("i3", "00000000-0000-0000-0000-0000000000ff", @bia)
      ])

    assert r.exclusions["unlinked_person"] == 3
    assert r.account_type_unknown == 1
    assert r.edges == []
    invariante!(r)
  end

  test "issue sem responsável não é par, e conta em issues_without_assignee" do
    r =
      resumo([
        par("i1", @ana, nil, %{assigned: false, assignee_account_type: nil}),
        par("i2", @ana, @bia)
      ])

    assert r.exclusions["issues_without_assignee"] == 1
    assert r.exclusions["issues"] == 2
    assert r.exclusions["pairs"] == 1
    invariante!(r)
  end

  test "a janela entra pelo instante de abertura" do
    antes = par("i0", @ana, @bia, %{opened_at: ~U[2026-08-31 23:59:59Z]})
    r = resumo([antes, par("i1", @ana, @dora)])
    assert r.edges == [%{source: @ana, target: @dora, weight: 1}]
    assert r.exclusions["issues"] == 1
  end

  test "a ordem implementada é a da base" do
    assert C.order() == ~w(bot_or_app organization_account unlinked_person self_assignment)
  end
end
