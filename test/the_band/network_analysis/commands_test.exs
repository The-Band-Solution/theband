defmodule TheBand.NetworkAnalysis.CommandsTest do
  @moduledoc """
  O cálculo e a substituição das leituras da análise — feature 076, T014 (FR-017, FR-018; R4, R5,
  R10; A15, A16, A18, A19, A21).

  As arestas entram pela função de entrada, como em produção (`Commands.compute/5`); os
  parâmetros são os da base real, com o teto trocado só no caso de A16.

  ## As asserções que carregam este arquivo, um caso por cenário

  - **controle**: o primeiro cálculo grava as seis leituras com graus e componentes;
  - **A15**: com as mesmas arestas, o segundo cálculo diz `:unchanged`, não regrava (mesmo id) e
    só avança `checked_at`;
  - **A16**: acima do teto, σ, Q_rand e layout estão ausentes com
    `network_too_large_for_platform`, e o relator diz quais;
  - **A21**: recalcular a designação com arestas novas mantém a leitura de revisão vigente;
  - **A18**: leitura recusada pelo banco devolve só nomes de campo, sem `person_id`;
  - **A19**: `capture_log` em `:debug` durante o cálculo não tem `person_id`.

  **Defeitos a injetar**, um por vez: ignorar a impressão; tirar o teto; `delete_all` sem a rede;
  `Repo.insert!`; logar o `nodes`.
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog

  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.NetworkAnalysis.Schemas.Reading
  alias TheBand.Ontology.KnowledgeBase

  @agora ~U[2026-10-04 12:00:00Z]

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    org = organization_fixture(tenant)
    [a, b, c] = for _ <- 1..3, do: Ecto.UUID.generate()

    %{tenant: tenant, org: org, ids: [a, b, c], parametros: Parameters.fetch!()}
  end

  defp entrada(arestas) do
    %{
      edges: arestas,
      exclusions: %{"bot_or_app" => 1},
      people_without_edges: 2,
      source_computed_at: nil,
      provenance: %{}
    }
  end

  defp arestas([a, b, c]),
    do: [
      %{source: a, target: b, weight: 3},
      %{source: b, target: a, weight: 1},
      %{source: b, target: c, weight: 2}
    ]

  defp todas(arestas_por_rede),
    do: fn rede, _dias, _inicio -> {:ok, entrada(arestas_por_rede[rede])} end

  # A linha do log em que o id aparece, para a falha dizer de onde ele veio.
  defp trecho(log, id) do
    log |> String.split("\n") |> Enum.find("", &String.contains?(&1, id)) |> String.slice(0, 400)
  end

  defp leituras(tenant) do
    Repo.all(
      from r in Reading,
        where: r.tenant_id == ^tenant.id,
        order_by: [r.network, r.window_days]
    )
  end

  test "controle: grava as seis leituras, com graus e componentes", ctx do
    e = arestas(ctx.ids)

    assert {:ok, relator, ids} =
             Commands.compute(
               ctx.tenant,
               ctx.org,
               @agora,
               ctx.parametros,
               todas(%{"review" => e, "assignment" => e})
             )

    assert length(ids) == 6
    assert Enum.all?(relator.readings, &(&1.outcome == :computed))

    [l | _] = leituras(ctx.tenant)
    assert l.measures["people"] == 3
    assert l.measures["undirected_edges"] == 2
    assert l.measures["components"] == [3]
    [_a, b, _c] = ctx.ids
    no_b = Enum.find(l.nodes, &(&1["id"] == b))
    assert no_b["degree"] == 2
    assert no_b["out_people"] == 2 and no_b["in_people"] == 1
    # T030: a–b–c, b no único caminho entre a e c: 1/((3 − 1)(3 − 2)/2) = 1,0.
    assert no_b["betweenness"] == %{"value" => 1.0}
    assert Enum.find(l.nodes, &(&1["id"] != b))["betweenness"] == %{"value" => 0.0}
    assert l.people_without_edges == 2
  end

  test "A15: as mesmas arestas não regravam; só checked_at avança", ctx do
    e = arestas(ctx.ids)
    entradas = todas(%{"review" => e, "assignment" => e})

    {:ok, _, _} = Commands.compute(ctx.tenant, ctx.org, @agora, ctx.parametros, entradas)
    antes = leituras(ctx.tenant)

    depois_de = DateTime.add(@agora, 900, :second)

    {:ok, relator, ids} =
      Commands.compute(ctx.tenant, ctx.org, depois_de, ctx.parametros, entradas)

    assert ids == []
    assert Enum.all?(relator.readings, &(&1.outcome == :unchanged))

    depois = leituras(ctx.tenant)
    assert Enum.map(depois, & &1.id) == Enum.map(antes, & &1.id)
    assert Enum.all?(depois, &(&1.checked_at == depois_de and &1.computed_at == @agora))
  end

  test "A16: acima do teto, σ, Q_rand e layout ausentes com o motivo", ctx do
    parametros = %{ctx.parametros | size_limit: %{max_people: 2, max_undirected_edges: 3000}}
    e = arestas(ctx.ids)

    {:ok, relator, _} =
      Commands.compute(
        ctx.tenant,
        ctx.org,
        @agora,
        parametros,
        todas(%{"review" => e, "assignment" => e})
      )

    assert Enum.all?(
             relator.readings,
             &(&1.absent == [:sigma, :q_rand, :efficiency_rand, :layout])
           )

    for l <- leituras(ctx.tenant), chave <- ["random", "sigma", "layout"] do
      assert l.measures[chave] == %{"absent" => "network_too_large_for_platform"}
    end

    # Controle: abaixo do teto, nada é marcado ausente por ele.
    {:ok, abaixo, _} =
      Commands.compute(
        ctx.tenant,
        ctx.org,
        @agora,
        ctx.parametros,
        todas(%{"review" => e, "assignment" => tl(e)})
      )

    assert Enum.any?(abaixo.readings, &(&1.absent == []))
  end

  test "A21: recalcular a designação mantém a revisão vigente", ctx do
    e = arestas(ctx.ids)

    {:ok, _, _} =
      Commands.compute(
        ctx.tenant,
        ctx.org,
        @agora,
        ctx.parametros,
        todas(%{"review" => e, "assignment" => e})
      )

    revisao = Enum.filter(leituras(ctx.tenant), &(&1.network == "review"))
    assert length(revisao) == 3

    {:ok, _, ids} =
      Commands.compute(
        ctx.tenant,
        ctx.org,
        @agora,
        ctx.parametros,
        todas(%{"review" => e, "assignment" => tl(e)})
      )

    assert length(ids) == 3
    depois = Enum.filter(leituras(ctx.tenant), &(&1.network == "review"))
    assert Enum.map(depois, & &1.id) == Enum.map(revisao, & &1.id)
  end

  test "A18: leitura recusada devolve só nomes de campo, sem person_id", ctx do
    outro = tenant_fixture()
    org_de_outro = organization_fixture(outro)
    e = arestas(ctx.ids)

    resultado =
      try do
        Commands.compute(
          ctx.tenant,
          org_de_outro,
          @agora,
          ctx.parametros,
          todas(%{"review" => e, "assignment" => e})
        )
      rescue
        erro -> {:levantou, Exception.format(:error, erro, __STACKTRACE__)}
      end

    texto = inspect(resultado)
    for id <- ctx.ids, do: refute(texto =~ id, "o erro contém o person_id #{id}")
    assert resultado == {:error, {:reading_rejected, [:organization_id]}}
  end

  test "A19: o log em :debug durante o cálculo não tem person_id", ctx do
    nivel = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: nivel) end)

    e = arestas(ctx.ids)

    log =
      capture_log([level: :debug], fn ->
        {:ok, _, _} =
          Commands.compute(
            ctx.tenant,
            ctx.org,
            @agora,
            ctx.parametros,
            todas(%{"review" => e, "assignment" => e})
          )
      end)

    for id <- ctx.ids do
      refute log =~ id, "o log contém o person_id #{id}:\n#{trecho(log, id)}"
    end
  end
end
