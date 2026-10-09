defmodule TheBand.NetworkAnalysis.Parameters do
  @moduledoc """
  Os parâmetros da análise de rede, lidos da base de conhecimento — feature 076, T008 (princípio
  IV; research.md R19; `contracts/network-analysis.md`, *Os parâmetros entram pela fachada*).

  Cinco regras, que mudam por razões diferentes:

  - `network.analysis.parameters` — algoritmos, sementes, amostras, teto, tamanhos de lista;
  - `network.position_role` — percentil, mínimo e cortes do papel (o que se diz de uma pessoa);
  - `assignment.network.edge` — a ordem das exclusões da designação (o significado da aresta);
  - `review.network.parameters` — as janelas, que as duas redes usam
    (`networks.values.windows_from`);
  - `review.network.edge` — só a versão, em `knowledge_versions`: as arestas de revisão são as
    que a 073 gravou por ela, e sem a versão na impressão digital uma leitura da versão 1 e uma
    da 2 com as mesmas arestas seriam a mesma (O1 da revisão semântica do PR #1383).

  **Levanta, e nunca devolve valor de reserva**, quando falta regra, chave ou versão, dizendo qual
  (precedente `ReviewNetwork.Parameters`): em constante, o número muda num diff de código e
  ninguém percebe que a plataforma passou a afirmar outra coisa.

  **O que o código implementa é conferido, e não lido para decidir**: a ordem das exclusões que
  `AssignmentClassification` aplica, o gerador e o modelo dos aleatórios que `Algorithms.Random`
  sorteia, o peso dos aleatórios do Q_rand. Se a base declarar outro, a carga levanta em vez de a
  análise passar a discordar da base em silêncio.

  Depende de: `TheBand.Ontology.KnowledgeBase`.
  """

  alias TheBand.NetworkAnalysis.AssignmentClassification
  alias TheBand.Ontology.KnowledgeBase

  @analise "network.analysis.parameters"
  @papel "network.position_role"
  @aresta "assignment.network.edge"
  @janelas "review.network.parameters"
  @revisao "review.network.edge"
  @necessidade "network.structure"

  # O que o código implementa, nos códigos da base. Conferido, nunca lido para decidir.
  # A ordem das exclusões é a que `AssignmentClassification` implementa (T024): um lugar só.
  @ordem_implementada AssignmentClassification.order()
  @gerador_implementado "exsss"
  @modelo_implementado "gnm"
  @pesos_implementados "shuffled_real_multiset"

  @type t :: %{
          networks: [String.t()],
          default_network: String.t(),
          windows: [pos_integer()],
          default_window: pos_integer(),
          min_group: pos_integer(),
          size_limit: %{max_people: pos_integer(), max_undirected_edges: pos_integer()},
          hubs_size: pos_integer(),
          community_core_size: pos_integer(),
          modularity_thresholds: [number()],
          betweenness_min_people: pos_integer(),
          clustering_min_neighbours: pos_integer(),
          eigenvector: %{
            tolerance_per_node: float(),
            max_iterations: pos_integer(),
            min_component_size: pos_integer()
          },
          small_world: %{
            random_graphs: pos_integer(),
            seed: integer(),
            min_people: pos_integer(),
            criterion_threshold: number(),
            generator: String.t()
          },
          layout: %{seed: integer(), iterations: pos_integer(), labelled_nodes: pos_integer()},
          color_bands: [map()],
          position: %{
            min_people: pos_integer(),
            high_above: number(),
            median_above: number(),
            low_below: number(),
            order: [String.t()],
            labels: map()
          },
          exclusion_order: [String.t()],
          knowledge_versions: %{String.t() => pos_integer()}
        }

  @doc "Os parâmetros da base, ou levanta dizendo a regra e a chave que faltam."
  @spec fetch!() :: t()
  def fetch! do
    necessidade = artefato!(&KnowledgeBase.information_need/1, @necessidade)
    ids = Map.get(necessidade, "candidate_measurements") || falha!(@necessidade, "sem medidas")
    medidas = Map.new(ids, fn id -> {id, artefato!(&KnowledgeBase.measurement/1, id)} end)

    from_rules!(
      %{
        @analise => artefato!(&KnowledgeBase.rule/1, @analise),
        @papel => artefato!(&KnowledgeBase.rule/1, @papel),
        @aresta => artefato!(&KnowledgeBase.rule/1, @aresta),
        @janelas => artefato!(&KnowledgeBase.rule/1, @janelas),
        @revisao => artefato!(&KnowledgeBase.rule/1, @revisao)
      },
      medidas
    )
  end

  @doc """
  Lê e confere as regras e as medidas já carregadas. `regras` é um mapa do id da regra para o
  artefato. Levanta dizendo a regra e a chave quando falta uma, ou quando um valor não é o que a
  regra promete, ou quando difere do que o código implementa.
  """
  @spec from_rules!(%{String.t() => map()}, %{String.t() => map()}) :: t()
  def from_rules!(regras, medidas) do
    a = regra!(regras, @analise)
    p = regra!(regras, @papel)
    e = regra!(regras, @aresta)
    j = regra!(regras, @janelas)
    regra!(regras, @revisao)

    redes = valor!(a, @analise, ~w(networks values allowed))
    textos!(@analise, "networks.allowed", redes)

    unless valor!(a, @analise, ~w(networks values windows_from)) ==
             "review.network.parameters.window_days",
           do:
             falha!(@analise, "networks.windows_from não é review.network.parameters.window_days")

    janelas = valor!(j, @janelas, ~w(window_days values allowed))
    padrao = valor!(j, @janelas, ~w(window_days values default))
    inteiros_positivos!(@janelas, "window_days.allowed", janelas)
    unless padrao in janelas, do: falha!(@janelas, "window_days.default fora da lista")

    ordem = valor!(e, @aresta, ~w(exclusions values order))

    unless ordem == @ordem_implementada,
      do: falha!(@aresta, "exclusions.order difere da que a classificação implementa")

    confere!(a, ~w(small_world values generator), @gerador_implementado)
    confere!(a, ~w(small_world values random_model), @modelo_implementado)
    confere!(a, ~w(modularity_reading values random_weights), @pesos_implementados)

    %{
      networks: redes,
      # A rede padrão é a primeira da lista da base, e não um nome escrito aqui.
      default_network: hd(redes),
      windows: janelas,
      default_window: padrao,
      min_group: positivo!(a, ~w(outside_reach values min_group)),
      size_limit: %{
        max_people: positivo!(a, ~w(size_limit values max_people)),
        max_undirected_edges: positivo!(a, ~w(size_limit values max_undirected_edges))
      },
      hubs_size: positivo!(a, ~w(hubs_list_size values size)),
      community_core_size: positivo!(a, ~w(community_core_size values size)),
      # As faixas CITADAS da modularidade (FR-031): a tela as diz com a fonte, e nunca como adjetivo.
      modularity_thresholds: numeros!(a, ~w(modularity_reading values cited_thresholds)),
      betweenness_min_people: positivo!(a, ~w(betweenness values min_people)),
      clustering_min_neighbours: positivo!(a, ~w(clustering values min_neighbours)),
      eigenvector: %{
        tolerance_per_node: numero!(a, ~w(eigenvector values tolerance_per_node)),
        max_iterations: positivo!(a, ~w(eigenvector values max_iterations)),
        min_component_size: positivo!(a, ~w(eigenvector values min_component_size))
      },
      small_world: %{
        random_graphs: positivo!(a, ~w(small_world values random_graphs)),
        seed: inteiro!(a, ~w(small_world values seed)),
        min_people: positivo!(a, ~w(small_world values min_people)),
        criterion_threshold: numero!(a, ~w(small_world values criterion_threshold)),
        generator: @gerador_implementado
      },
      layout: %{
        seed: inteiro!(a, ~w(layout values seed)),
        iterations: positivo!(a, ~w(layout values iterations)),
        labelled_nodes: positivo!(a, ~w(layout values labelled_nodes))
      },
      color_bands: lista!(a, ~w(betweenness_color_bands values bands)),
      position: %{
        min_people: positivo!(p, ~w(min_people values min_people), @papel),
        high_above: numero!(p, ~w(cuts values high_above), @papel),
        median_above: numero!(p, ~w(cuts values median_above), @papel),
        low_below: numero!(p, ~w(cuts values low_below), @papel),
        order: lista!(p, ~w(cuts values order), @papel),
        labels: valor!(p, @papel, ~w(labels values))
      },
      exclusion_order: ordem,
      knowledge_versions:
        medidas
        |> Map.new(fn {id, medida} -> {id, versao!(medida, id)} end)
        |> Map.merge(
          Map.new(
            [@analise, @papel, @aresta, @janelas, @revisao],
            &{&1, versao!(regras[&1], &1)}
          )
        )
    }
  end

  defp regra!(regras, id),
    do: Map.get(regras, id) || raise("#{id} ausente da base de conhecimento")

  defp artefato!(buscar, id) do
    case buscar.(id) do
      {:ok, artefato} -> artefato
      :error -> raise "#{id} ausente da base de conhecimento"
    end
  end

  defp valor!(regra, id, caminho) do
    case get_in(regra, ["rules" | caminho]) do
      nil -> falha!(id, "#{Enum.join(caminho, ".")} ausente")
      valor -> valor
    end
  end

  defp confere!(regra, caminho, esperado) do
    unless valor!(regra, @analise, caminho) == esperado,
      do: falha!(@analise, "#{Enum.join(caminho, ".")} difere do implementado (#{esperado})")
  end

  defp positivo!(regra, caminho, id \\ @analise) do
    case valor!(regra, id, caminho) do
      v when is_integer(v) and v > 0 -> v
      _ -> falha!(id, "#{Enum.join(caminho, ".")} não é inteiro positivo")
    end
  end

  defp inteiro!(regra, caminho) do
    case valor!(regra, @analise, caminho) do
      v when is_integer(v) -> v
      _ -> falha!(@analise, "#{Enum.join(caminho, ".")} não é inteiro")
    end
  end

  defp numero!(regra, caminho, id \\ @analise) do
    case valor!(regra, id, caminho) do
      v when is_number(v) -> v
      _ -> falha!(id, "#{Enum.join(caminho, ".")} não é número")
    end
  end

  defp lista!(regra, caminho, id \\ @analise) do
    case valor!(regra, id, caminho) do
      [_ | _] = v -> v
      _ -> falha!(id, "#{Enum.join(caminho, ".")} não é lista")
    end
  end

  defp numeros!(regra, caminho) do
    case valor!(regra, @analise, caminho) do
      [_ | _] = v ->
        if Enum.all?(v, &is_number/1),
          do: v,
          else: falha!(@analise, "#{Enum.join(caminho, ".")} não é lista de números")

      _ ->
        falha!(@analise, "#{Enum.join(caminho, ".")} não é lista")
    end
  end

  defp textos!(id, nome, valores) do
    unless is_list(valores) and valores != [] and Enum.all?(valores, &is_binary/1),
      do: falha!(id, "#{nome} não é lista de textos")
  end

  defp inteiros_positivos!(id, nome, valores) do
    unless is_list(valores) and valores != [] and Enum.all?(valores, &(is_integer(&1) and &1 > 0)),
      do: falha!(id, "#{nome} não é lista de inteiros positivos")
  end

  defp versao!(artefato, id) do
    case Map.get(artefato, "version") do
      v when is_integer(v) and v > 0 -> v
      _ -> falha!(id, "version ausente ou inválida")
    end
  end

  defp falha!(id, motivo), do: raise("#{id} inconsistente: #{motivo}")
end
