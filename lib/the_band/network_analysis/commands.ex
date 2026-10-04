defmodule TheBand.NetworkAnalysis.Commands do
  @moduledoc """
  O cálculo da análise de rede de uma organização observada, e a substituição das leituras —
  feature 076, T014 (FR-017, FR-018; R4, R5, R10, R17 da segurança e do plano;
  `contracts/network-analysis.md`, `compute/3`).

  ## O que faz, por rede e janela

  1. pede as arestas à **função de entrada** (`entradas`); T028 a liga às duas redes (revisão da
     073 e designação). Rede sem fonte não grava nada e aparece no relator como ausente;
  2. calcula a **impressão digital** (SHA-256 das arestas canônicas, das exclusões, das pessoas
     sem aresta e das versões da base, R4). Igual à vigente: a leitura não é regravada, só
     `checked_at` avança, e o relator diz `:unchanged` (A15);
  3. aplica o **teto** (R5): acima dele, σ, Q_rand, a eficiência dos aleatórios e o layout ficam
     ausentes com `network_too_large_for_platform` e **não rodam** (A16);
  4. monta a leitura com o que já existe (graus, componentes);
  5. substitui **só** `(tenant, organização, rede, janela)`, numa transação, com `Repo.insert/1`
     (A21, A18).

  ## O que não faz

  Não lê relógio (`now` vem de quem chama), não registra log (o job registra a partir do relator,
  que só tem contagens: A19), e não grava percentil nem papel (R17).

  Depende de: `Algorithms.Projection`, `Algorithms.Betweenness`,
  `Algorithms.Layout`, `Parameters`, `Notices`; nenhuma
  tabela de ontologia.
  """

  import Ecto.Query

  alias TheBand.NetworkAnalysis.Algorithms.Betweenness
  alias TheBand.NetworkAnalysis.Algorithms.Layout
  alias TheBand.NetworkAnalysis.Algorithms.Projection
  alias TheBand.NetworkAnalysis.Inputs
  alias TheBand.NetworkAnalysis.Notices
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.NetworkAnalysis.Queries
  alias TheBand.NetworkAnalysis.Schemas.Reading
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @dia 86_400

  # O que ESTE código deixa de rodar acima do teto, nos nomes do relator — os de
  # `network.analysis.parameters.size_limit.absent_above`. O teste de A16 confere a leitura.
  @acima_do_teto [:sigma, :q_rand, :efficiency_rand, :layout]

  @type entrada :: %{
          edges: [%{source: Ecto.UUID.t(), target: Ecto.UUID.t(), weight: pos_integer()}],
          exclusions: %{String.t() => non_neg_integer() | nil},
          people_without_edges: non_neg_integer() | nil,
          source_computed_at: DateTime.t() | nil,
          provenance: map()
        }

  @type entradas ::
          (String.t(), pos_integer(), DateTime.t() -> {:ok, entrada()} | {:ausente, atom()})

  @type relator :: %{
          readings: [
            %{
              network: String.t(),
              window_days: pos_integer(),
              outcome: :computed | :unchanged | {:ausente, atom()},
              edges: non_neg_integer(),
              people: non_neg_integer(),
              excluded: %{String.t() => non_neg_integer() | nil},
              absent: [atom()],
              duration_ms: non_neg_integer()
            }
          ]
        }

  @doc """
  Calcula com os parâmetros da base e as entradas das duas redes, e avisa, só com ids, que há
  leituras novas. É o que a fachada expõe, e só o job chama.
  """
  @spec compute(Tenant.t(), map(), DateTime.t()) ::
          {:ok, relator()} | {:error, {:reading_rejected, [atom()]}}
  def compute(%Tenant{} = tenant, %{id: organization_id} = organization, now) do
    parametros = Parameters.fetch!()
    entradas = Inputs.for_organization(tenant, organization, now, parametros)

    with {:ok, relator, ids} <- compute(tenant, organization, now, parametros, entradas) do
      # Depois do commit, e só com ids (A11 da 073).
      if ids != [], do: Notices.broadcast(tenant.id, organization_id, ids)
      {:ok, relator}
    end
  end

  @doc """
  Calcula cada rede de `parametros.networks` em cada janela de `parametros.windows`, com as arestas
  que `entradas` devolve, e substitui as leituras que mudaram.

  Devolve o relator só com contagens, e os ids das leituras gravadas (para o aviso). Leitura
  recusada pelo banco desfaz a transação e devolve `{:error, {:reading_rejected, campos}}`, só com
  os **nomes** dos campos (A18).
  """
  @spec compute(Tenant.t(), map(), DateTime.t(), Parameters.t(), entradas()) ::
          {:ok, relator(), [Ecto.UUID.t()]} | {:error, {:reading_rejected, [atom()]}}
  def compute(%Tenant{} = tenant, %{id: organization_id}, %DateTime{} = now, parametros, entradas) do
    agora = DateTime.truncate(now, :second)
    vigentes = Queries.fingerprints(tenant, organization_id)

    planos =
      for rede <- parametros.networks, dias <- Enum.sort(parametros.windows) do
        inicio_relogio = System.monotonic_time(:millisecond)
        inicio = DateTime.add(agora, -dias * @dia, :second)
        janela = %{rede: rede, dias: dias, inicio: inicio, agora: agora}
        plano = planejar(tenant, organization_id, janela, parametros, entradas, vigentes)
        Map.put(plano, :duration_ms, System.monotonic_time(:millisecond) - inicio_relogio)
      end

    with {:ok, gravadas} <- aplicar(tenant, organization_id, planos, agora) do
      {:ok, %{readings: Enum.map(planos, &linha_do_relator/1)}, Enum.map(gravadas, & &1.id)}
    end
  end

  defp planejar(tenant, organization_id, janela, parametros, entradas, vigentes) do
    %{rede: rede, dias: dias, inicio: inicio, agora: agora} = janela

    case entradas.(rede, dias, inicio) do
      {:ausente, motivo} ->
        %{network: rede, window_days: dias, outcome: {:ausente, motivo}, attrs: nil}

      {:ok, entrada} ->
        impressao = impressao_digital(entrada, parametros.knowledge_versions)
        projecao = Projection.undirected(entrada.edges)
        acima? = acima_do_teto?(projecao, parametros.size_limit)

        base = %{
          network: rede,
          window_days: dias,
          entrada: entrada,
          people: length(projecao.nodes),
          absent: if(acima?, do: @acima_do_teto, else: [])
        }

        if Map.get(vigentes, {rede, dias}) == impressao do
          Map.merge(base, %{outcome: :unchanged, attrs: nil})
        else
          contexto = %{rede: rede, dias: dias, inicio: inicio, agora: agora, impressao: impressao}

          attrs =
            leitura(tenant, organization_id, contexto, entrada, projecao, acima?, parametros)

          Map.merge(base, %{outcome: :computed, attrs: attrs})
        end
    end
  end

  # A leitura com o que já existe nesta fatia: graus, componentes (T014), intermediação (T030) e
  # posições (T031). As medidas dos algoritmos entram com as tarefas deles; acima do teto, as que
  # o teto desliga ficam ausentes com o motivo da base, e nunca com valor.
  defp leitura(tenant, organization_id, contexto, entrada, projecao, acima?, parametros) do
    %{rede: rede, dias: dias, inicio: inicio, agora: agora, impressao: impressao} = contexto
    componentes = Projection.components(projecao.adjacency)
    graus = Projection.degrees(entrada.edges)

    intermediacao =
      Betweenness.brandes(projecao.adjacency, %{min_people: parametros.betweenness_min_people})

    # Acima do teto o layout não roda (A16): o nó fica sem x/y, e a leitura diz por quê.
    posicoes =
      if acima?,
        do: %{},
        else:
          Layout.fruchterman_reingold(
            projecao.nodes,
            projecao.adjacency,
            Map.take(parametros.layout, [:seed, :iterations])
          )

    componente_de =
      for {membros, i} <- Enum.with_index(componentes, 1), id <- membros, into: %{}, do: {id, i}

    nos =
      for id <- projecao.nodes do
        g = Map.fetch!(graus, id)

        %{
          "id" => id,
          "out_people" => g.out_people,
          "in_people" => g.in_people,
          "degree" => g.degree,
          "out_weight" => g.out_weight,
          "in_weight" => g.in_weight,
          "component" => Map.fetch!(componente_de, id),
          "betweenness" => medida_gravada(Map.fetch!(intermediacao, id))
        }
        |> com_posicao(Map.get(posicoes, id))
      end

    medidas =
      %{
        "people" => length(projecao.nodes),
        "undirected_edges" => projecao.edges,
        "components" => Enum.map(componentes, &length/1)
      }
      |> Map.merge(if acima?, do: ausentes_por_teto(), else: %{})

    %{
      tenant_id: tenant.id,
      organization_id: organization_id,
      network: rede,
      window_days: dias,
      window_start: inicio,
      window_end: agora,
      computed_at: agora,
      checked_at: agora,
      source_computed_at: entrada.source_computed_at,
      fingerprint: impressao,
      edges:
        entrada.edges |> Enum.sort_by(&{&1.source, &1.target}) |> Enum.map(&aresta_gravada/1),
      exclusions: entrada.exclusions,
      people_without_edges: entrada.people_without_edges,
      nodes: nos,
      communities: [],
      measures: medidas,
      provenance:
        Map.merge(entrada.provenance, %{
          "knowledge_versions" => parametros.knowledge_versions,
          "generator" => parametros.small_world.generator,
          "seed" => parametros.small_world.seed,
          "random_graphs" => parametros.small_world.random_graphs,
          "layout_seed" => parametros.layout.seed,
          "layout_iterations" => parametros.layout.iterations
        })
    }
  end

  defp com_posicao(no, nil), do: no
  defp com_posicao(no, {x, y}), do: Map.merge(no, %{"x" => x, "y" => y})

  # Ausência gravada com o motivo, e nunca 0 (data-model §1.2).
  defp medida_gravada({:ok, v}), do: %{"value" => v}
  defp medida_gravada({:ausente, motivo}), do: %{"absent" => Atom.to_string(motivo)}

  defp acima_do_teto?(%{nodes: nos, edges: arestas}, %{max_people: p, max_undirected_edges: e}),
    do: length(nos) > p or arestas > e

  defp ausentes_por_teto do
    motivo = %{"absent" => "network_too_large_for_platform"}
    %{"random" => motivo, "sigma" => motivo, "layout" => motivo}
  end

  defp aresta_gravada(%{source: s, target: t, weight: w}),
    do: %{"source" => s, "target" => t, "weight" => w}

  @doc """
  A impressão digital de uma entrada: SHA-256, em hexadecimal, da lista canônica das arestas
  (`source|target|weight`, ordenada), das exclusões, das pessoas sem aresta e das versões da base.

  `source_computed_at` **não** entra: a 073 recalcula a cada sincronização, e com as mesmas
  arestas a leitura não muda (R4).
  """
  @spec impressao_digital(entrada(), map()) :: String.t()
  def impressao_digital(entrada, versoes) do
    arestas =
      entrada.edges
      |> Enum.map(&"#{&1.source}|#{&1.target}|#{&1.weight}")
      |> Enum.sort()

    canonico = [
      arestas,
      entrada.exclusions |> Enum.sort(),
      entrada.people_without_edges,
      versoes |> Enum.sort()
    ]

    :sha256 |> :crypto.hash(:erlang.term_to_binary(canonico)) |> Base.encode16(case: :lower)
  end

  # Uma transação para as seis combinações: ou todas as substituições ficam, ou nenhuma muda.
  defp aplicar(%Tenant{id: tenant_id}, organization_id, planos, agora) do
    Repo.transaction(fn ->
      for %{outcome: :unchanged, network: rede, window_days: dias} <- planos do
        tenant_id
        |> mesma(organization_id, rede, dias)
        |> Repo.update_all(set: [checked_at: agora])
      end

      for %{outcome: :computed, network: rede, window_days: dias, attrs: attrs} <- planos do
        # Só a MESMA rede e janela (A21): a chave do delete é a do índice único.
        tenant_id |> mesma(organization_id, rede, dias) |> Repo.delete_all()
        inserir(attrs)
      end
    end)
  end

  defp mesma(tenant_id, organization_id, rede, dias) do
    from r in Reading,
      where:
        r.tenant_id == ^tenant_id and r.organization_id == ^organization_id and
          r.network == ^rede and r.window_days == ^dias
  end

  # Dentro da transação: a recusa desfaz tudo, e o motivo leva só nomes de campo.
  defp inserir(attrs) do
    case %Reading{} |> Reading.changeset(attrs) |> Repo.insert() do
      {:ok, gravada} -> gravada
      {:error, changeset} -> Repo.rollback({:reading_rejected, campos_recusados(changeset)})
    end
  end

  # Só os nomes: o changeset carrega as arestas, e nenhuma chega ao termo que o job devolve ao
  # Oban (R10; A18).
  defp campos_recusados(%Ecto.Changeset{errors: errors}),
    do: errors |> Keyword.keys() |> Enum.uniq() |> Enum.sort()

  # O relator: contagens, nunca par, nome, login nem medida por pessoa (A19).
  defp linha_do_relator(%{outcome: {:ausente, _}} = p) do
    %{
      network: p.network,
      window_days: p.window_days,
      outcome: p.outcome,
      edges: 0,
      people: 0,
      excluded: %{},
      absent: [],
      duration_ms: p.duration_ms
    }
  end

  defp linha_do_relator(p) do
    %{
      network: p.network,
      window_days: p.window_days,
      outcome: p.outcome,
      edges: length(p.entrada.edges),
      people: p.people,
      excluded: p.entrada.exclusions,
      absent: p.absent,
      duration_ms: p.duration_ms
    }
  end
end
