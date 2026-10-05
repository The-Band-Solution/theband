defmodule TheBand.NetworkAnalysis.View do
  @moduledoc """
  O recorte da leitura pelo alcance de quem consulta — feature 076, T016 (FR-011 a FR-016;
  research.md R10; R1–R6 da segurança; `contracts/algoritmos.md`, `View.build/5`).

  **Puro**: recebe a leitura, o alcance, o alcance **concedido** (DS1), a pessoa de quem consulta
  e os parâmetros, e devolve a visão **sem nomes** (o `Reader` põe os nomes). Muda quando a regra
  de acesso muda, e só então (princípio X).

  ## As regras (R10), com k = `min_group` da base (DS2)

  1. **nós**: alcançados por id; de fora, um agregado por comunidade com ≥ k; os de comunidades
     com < k juntam-se num agregado *"other communities"* se juntarem ≥ k; senão nenhum nó, e o
     alcançado ligado a alguém de fora leva a marca *"has links outside your reach"*;
  2. **id do agregado**: `outside-<n>`, a posição dele na lista desta visão. Opaco, sem relação
     com `person_id` nem hash (A6);
  3. **arestas**: alcançado–alcançado como na leitura; com agregado, a soma por sentido; nada
     dentro de um agregado; nada com quem ficou fora de qualquer agregado;
  4. **supressão complementar**: o número de pessoas da rede e o tamanho dos componentes só
     aparecem com alcance parcial se as pessoas de fora que eles contam forem 0 ou ≥ k;
  5. **hubs** (T040): só pessoas alcançadas cuja posição quem consulta pode ver (DS1), ordenadas
     pela medida da rede inteira, empate pelo id e marcado; nunca a posição na rede inteira, nem
     linha de pessoa de fora. Sem escopo concedido, `{:recortado, :positions_not_granted}`;
  7. papel é chamado por T046 a partir de `ve_posicao_de?/2`;
  6. **comunidades** (T037): um bloco por comunidade com ao menos um alcançado; membros
     alcançados por id; os três mais centrais (`core_size` da base) entre os alcançados, pelo
     grau interno da rede inteira, e só com escopo concedido (DS1); tamanho e ligações da
     comunidade pela regra 4; os de fora agregados só se forem ≥ k. O número de comunidades
     também segue a regra 4, pelas pessoas das comunidades sem nenhum alcançado;
  8. **DS1 (b)**: posição de **outra** pessoa só com escopo concedido que a alcança, ou com a
     administração; a própria pessoa vê a sua sempre;
  9. **DS5 (b)**: alcance vazio, ou só a própria pessoa: o grafo vem `{:recortado, :no_reach}`;
  10. o grau normalizado não aparece com alcance parcial (FR-033): o nó da visão não o carrega.

  Depende de: nenhuma ontologia.
  """

  @type alcance :: :todas | {:algumas, MapSet.t()}

  # Os motivos de ausência que a leitura grava, como átomos conhecidos: o texto da leitura nunca
  # vira átomo (A12, L54). Motivo fora desta lista levanta, e não vira ausência genérica.
  @motivos %{
    "network_too_small" => :network_too_small,
    "did_not_converge" => :did_not_converge,
    "no_reachable_person" => :no_reachable_person,
    "component_too_small" => :component_too_small,
    "no_edge_in_window" => :no_edge_in_window,
    "network_too_large_for_platform" => :network_too_large_for_platform
  }

  @type t :: %{
          reach: :total | :parcial | :nenhum,
          sees_others_positions?: boolean(),
          viewer_person_id: String.t() | nil,
          granted: alcance(),
          people: {:ok, non_neg_integer()} | {:suprimido, :fewer_than_k_outside},
          graph:
            {:ok,
             %{
               nodes: [map()],
               edges: [%{from: String.t(), to: String.t(), weight: pos_integer()}],
               components: {:ok, [pos_integer()]} | {:suprimido, :fewer_than_k_outside}
             }}
            | {:recortado, :no_reach}
            | {:ausente, :no_edge_in_window},
          communities: {:ok, map()} | {:recortado, :no_reach} | {:ausente, atom()}
        }

  @doc """
  A visão da leitura para quem consulta. `params` precisa de `:min_group` (k), e pode trazer
  `:gone` — as pessoas da leitura que não estão mais em EO (apagadas depois do cálculo, R18).

  Com `:todas`, quem saiu de EO vira um agregado *"no longer in the platform"* (comunidade
  `:gone`) sob a mesma regra k, e nunca aparece por id. Com alcance parcial, quem chama já o tirou
  do alcance, e ele é tratado como qualquer pessoa de fora.

  `reach` e `granted` vêm de `Tenants.pessoas_alcancadas/2` e `/3`, calculados **na chamada** de
  quem lê; este módulo não os busca nem os guarda.
  """
  @spec build(map(), alcance(), alcance(), String.t() | nil, %{
          required(:min_group) => pos_integer(),
          optional(:gone) => MapSet.t(),
          optional(:core_size) => pos_integer(),
          optional(:hubs_size) => pos_integer()
        }) :: t()
  def build(leitura, reach, granted, viewer_person_id, %{min_group: k} = params) do
    nos = leitura_nos(leitura)
    alcance = classificar(reach, viewer_person_id)

    base = %{
      reach: alcance,
      sees_others_positions?: ve_outras_posicoes?(granted, viewer_person_id),
      viewer_person_id: viewer_person_id,
      granted: granted
    }

    gone = Map.get(params, :gone, MapSet.new())

    corpo =
      if alcance == :total and Enum.any?(nos, &MapSet.member?(gone, &1["id"])) do
        presentes =
          for n <- nos, not MapSet.member?(gone, n["id"]), into: MapSet.new(), do: n["id"]

        Map.put(
          parcial(leitura, nos, presentes, k, fn _ -> :gone end),
          :people,
          {:ok, length(nos)}
        )
      else
        corpo(alcance, leitura, nos, reach, k)
      end

    base
    |> Map.merge(corpo)
    |> Map.put(
      :communities,
      comunidades(leitura, nos, base, dentro_de(alcance, reach, gone), params)
    )
    |> Map.put(:hubs, hubs(nos, base, dentro_de(alcance, reach, gone), params))
  end

  # Regra 5 (T040; FR-032 a FR-036; R1 da segurança, A3, A11).
  defp hubs(_nos, _base, :nenhum, _params), do: {:recortado, :no_reach}
  defp hubs([], _base, _dentro?, _params), do: {:ausente, :no_edge_in_window}

  defp hubs(_nos, %{sees_others_positions?: false}, _dentro?, _params),
    do: {:recortado, :positions_not_granted}

  defp hubs(nos, base, dentro?, params) do
    tamanho = Map.get(params, :hubs_size, 5)
    candidatos = Enum.filter(nos, &(dentro?.(&1["id"]) and ve_posicao_de?(base, &1["id"])))

    {:ok,
     %{
       degree:
         lista(candidatos, tamanho, &{:ok, &1["degree"]}, fn n ->
           %{out_people: n["out_people"], in_people: n["in_people"]}
         end),
       betweenness: lista(candidatos, tamanho, &medida(&1["betweenness"]), fn _ -> %{} end),
       closeness:
         lista(candidatos, tamanho, &medida(&1["closeness"]), fn n ->
           case n["distance_mean"] do
             %{"value" => m, "reaches" => r} -> %{distance_mean: m, reaches: r}
             _ -> %{}
           end
         end),
       eigenvector:
         candidatos
         |> Enum.group_by(& &1["component"])
         |> Enum.sort()
         |> Enum.map(fn {c, membros} ->
           %{
             component: c,
             rows: lista(membros, tamanho, &medida(&1["eigenvector"]), fn _ -> %{} end)
           }
         end)
     }}
  end

  # Uma lista de hubs: as pessoas com valor, pela medida decrescente, empate pelo id; `tied?`
  # marca quem tem o mesmo valor de um vizinho da lista. Sem ninguém com valor, a ausência com o
  # motivo de quem a tem.
  defp lista(candidatos, tamanho, valor, detalhe) do
    com_valor = for n <- candidatos, {:ok, v} <- [valor.(n)], do: {n, v}

    case com_valor do
      [] ->
        {:ausente, Enum.find_value(candidatos, :no_edge_in_window, &motivo_de(valor.(&1)))}

      _ ->
        linhas =
          com_valor
          |> Enum.sort_by(fn {n, v} -> {-v, n["id"]} end)
          |> Enum.take(tamanho)

        valores = Enum.map(linhas, &elem(&1, 1))

        {:ok,
         Enum.map(linhas, fn {n, v} ->
           %{
             person_id: n["id"],
             value: {:ok, v},
             tied?: Enum.count(valores, &(&1 == v)) > 1 or empatado_fora?(com_valor, v, linhas),
             detail: detalhe.(n)
           }
         end)}
    end
  end

  defp motivo_de({:ausente, motivo}), do: motivo
  defp motivo_de(_valor), do: nil

  # O último da lista empatado com quem ficou de fora dela também é marcado: o corte não decidiu.
  defp empatado_fora?(com_valor, v, linhas) do
    fora = length(com_valor) - length(linhas)

    fora > 0 and
      Enum.count(com_valor, fn {_n, x} -> x == v end) > Enum.count(linhas, &(elem(&1, 1) == v))
  end

  # Quem conta como alcançado nesta visão: com `:todas`, todos menos quem saiu de EO.
  defp dentro_de(:nenhum, _reach, _gone), do: :nenhum
  defp dentro_de(_alcance, :todas, gone), do: fn id -> not MapSet.member?(gone, id) end
  defp dentro_de(_alcance, {:algumas, ids}, _gone), do: &MapSet.member?(ids, &1)

  # Regra 6 (T037; FR-028, FR-029). A modularidade e o Q_rand são da rede inteira, e aparecem
  # sempre que há leitura; o resto é por bloco.
  defp comunidades(_leitura, _nos, _base, :nenhum, _params), do: {:recortado, :no_reach}
  defp comunidades(_leitura, [], _base, _dentro?, _params), do: {:ausente, :no_edge_in_window}

  defp comunidades(leitura, nos, base, dentro?, %{min_group: k} = params) do
    case leitura_comunidades(leitura) do
      [] ->
        # Leitura gravada antes da T035: as comunidades não foram calculadas, e não são zero.
        {:ausente, :not_computed}

      gravadas ->
        grau_interno = Map.new(nos, &{&1["id"], &1["internal_degree"]})
        medidas = leitura_medidas(leitura)

        blocos =
          for c <- gravadas,
              membros = c["members"],
              alcancados = Enum.filter(membros, dentro?),
              alcancados != [],
              do: bloco(c, membros, alcancados, grau_interno, base, k, params)

        escondidas =
          for c <- gravadas, not Enum.any?(c["members"], dentro?), reduce: 0 do
            n -> n + length(c["members"])
          end

        {:ok,
         %{
           count: contagem(length(gravadas), escondidas, k),
           modularity: modularidade(medidas["modularity"]),
           q_rand: aleatorio(medidas["random"]),
           blocks: blocos
         }}
    end
  end

  defp bloco(c, membros, alcancados, grau_interno, base, k, params) do
    fora = length(membros) - length(alcancados)
    mostra? = fora == 0 or fora >= k
    suprimido = {:suprimido, :fewer_than_k_outside}

    %{
      index: c["index"],
      size: if(mostra?, do: {:ok, length(membros)}, else: suprimido),
      internal_edges: if(mostra?, do: {:ok, c["internal_edges"]}, else: suprimido),
      outside_edges: if(mostra?, do: {:ok, c["outside_edges"]}, else: suprimido),
      core: nucleo(alcancados, grau_interno, base, Map.get(params, :core_size, 3)),
      members: alcancados,
      outside:
        cond do
          fora == 0 -> :nenhum
          fora >= k -> {:agregado, fora}
          true -> :sem_agregado
        end
    }
  end

  # DS1: os mais centrais são ordenação por medida, como os hubs; sem escopo concedido, não
  # aparecem. Entre os alcançados, pelo grau interno da rede inteira, empate pelo id.
  defp nucleo(_alcancados, _grau, %{sees_others_positions?: false}, _tamanho),
    do: {:recortado, :positions_not_granted}

  defp nucleo(alcancados, grau, base, tamanho) do
    alcancados
    |> Enum.filter(&ve_posicao_de?(base, &1))
    |> Enum.sort_by(&{-(grau[&1] || 0), &1})
    |> Enum.take(tamanho)
    |> Enum.map(&%{person_id: &1, internal_degree: grau[&1]})
  end

  defp contagem(total, escondidas, k) do
    if escondidas == 0 or escondidas >= k,
      do: {:ok, total},
      else: {:suprimido, :fewer_than_k_outside}
  end

  defp modularidade(%{"value" => q}) when is_number(q), do: {:ok, q}
  defp modularidade(%{"absent" => "no_edge_in_window"}), do: {:ausente, :no_edge_in_window}
  defp modularidade(_), do: {:ausente, :not_computed}

  defp aleatorio(%{"modularity" => %{"value" => v, "graphs_defined" => n}}) when is_number(v),
    do: {:ok, %{value: v, graphs_defined: n}}

  defp aleatorio(%{"absent" => "network_too_large_for_platform"}),
    do: {:ausente, :network_too_large_for_platform}

  defp aleatorio(%{"absent" => "no_edge_in_window"}), do: {:ausente, :no_edge_in_window}
  defp aleatorio(_), do: {:ausente, :not_computed}

  defp leitura_comunidades(leitura),
    do: Map.get(leitura, :communities) || Map.get(leitura, "communities") || []

  defp leitura_medidas(leitura),
    do: Map.get(leitura, :measures) || Map.get(leitura, "measures") || %{}

  @doc """
  Quem consulta pode ver a posição (papel, hubs, núcleo da comunidade) desta pessoa? DS1 (b): a
  própria pessoa sempre; outra, só com escopo concedido que a alcança, ou administração.
  """
  @spec ve_posicao_de?(t(), String.t()) :: boolean()
  def ve_posicao_de?(%{viewer_person_id: viewer}, person_id) when viewer == person_id, do: true
  def ve_posicao_de?(%{granted: :todas}, _person_id), do: true
  def ve_posicao_de?(%{granted: {:algumas, ids}}, person_id), do: MapSet.member?(ids, person_id)

  defp ve_outras_posicoes?(:todas, _viewer), do: true

  defp ve_outras_posicoes?({:algumas, ids}, viewer),
    do: ids |> MapSet.delete(viewer) |> MapSet.size() > 0

  defp classificar(:todas, _viewer), do: :total

  defp classificar({:algumas, ids}, viewer) do
    if ids |> MapSet.delete(viewer) |> MapSet.size() == 0, do: :nenhum, else: :parcial
  end

  defp leitura_nos(leitura), do: Map.get(leitura, :nodes) || Map.get(leitura, "nodes") || []

  defp leitura_arestas(leitura), do: Map.get(leitura, :edges) || Map.get(leitura, "edges") || []

  # DS5 (b): sem alcance, só as medidas da rede; o número de pessoas segue a regra 4.
  defp corpo(:nenhum, _leitura, nos, {:algumas, ids}, k) do
    %{people: pessoas(length(nos), contar_dentro(nos, ids), k), graph: {:recortado, :no_reach}}
  end

  defp corpo(_alcance, _leitura, [], _reach, _k),
    do: %{people: {:ok, 0}, graph: {:ausente, :no_edge_in_window}}

  defp corpo(:total, leitura, nos, :todas, _k) do
    %{
      people: {:ok, length(nos)},
      graph:
        {:ok,
         %{
           nodes: Enum.map(nos, &no_pessoa(&1, false)),
           edges: Enum.map(leitura_arestas(leitura), &aresta/1),
           components: {:ok, tamanhos_dos_componentes(nos)}
         }}
    }
  end

  defp corpo(:parcial, leitura, nos, {:algumas, ids}, k),
    do: parcial(leitura, nos, ids, k, & &1["community"])

  defp parcial(leitura, nos, ids, k, grupo_de) do
    {dentro, fora} = Enum.split_with(nos, &MapSet.member?(ids, &1["id"]))
    {agregados, agregado_de} = agregar(fora, k, grupo_de)
    arestas = leitura_arestas(leitura)

    destino = fn id ->
      cond do
        MapSet.member?(ids, id) and Enum.any?(dentro, &(&1["id"] == id)) -> id
        Map.has_key?(agregado_de, id) -> Map.fetch!(agregado_de, id)
        true -> nil
      end
    end

    ligados_fora =
      for a <- arestas,
          {u, v} <- [{a["source"], a["target"]}, {a["target"], a["source"]}],
          MapSet.member?(ids, u) and not MapSet.member?(ids, v),
          into: MapSet.new(),
          do: u

    arestas_da_visao =
      arestas
      |> Enum.map(fn a -> {destino.(a["source"]), destino.(a["target"]), a["weight"]} end)
      |> Enum.reject(fn {u, v, _} -> is_nil(u) or is_nil(v) or u == v end)
      |> Enum.group_by(fn {u, v, _} -> {u, v} end, fn {_, _, w} -> w end)
      |> Enum.map(fn {{u, v}, pesos} -> %{from: u, to: v, weight: Enum.sum(pesos)} end)
      |> Enum.sort_by(&{&1.from, &1.to})

    %{
      people: pessoas(length(nos), length(dentro), k),
      graph:
        {:ok,
         %{
           nodes:
             Enum.map(dentro, &no_pessoa(&1, MapSet.member?(ligados_fora, &1["id"]))) ++
               agregados,
           edges: arestas_da_visao,
           components: componentes_parciais(nos, ids, k)
         }}
    }
  end

  defp no_pessoa(no, ligado_fora?) do
    %{
      kind: :person,
      id: no["id"],
      degree: no["degree"],
      out_people: no["out_people"],
      in_people: no["in_people"],
      out_weight: no["out_weight"],
      in_weight: no["in_weight"],
      betweenness: medida(no["betweenness"]),
      closeness: medida(no["closeness"]),
      distance_mean: distancia(no["distance_mean"]),
      eigenvector: medida(no["eigenvector"]),
      community: no["community"],
      links_outside_reach?: ligado_fora?
    }
  end

  # A medida gravada (data-model §1.2), com o motivo da ausência como átomo conhecido — nunca
  # criado a partir do dado. Leitura gravada antes da medida existir: não calculada, e não 0.
  defp medida(%{"value" => v}) when is_number(v), do: {:ok, v}

  defp medida(%{"absent" => motivo}) when is_map_key(@motivos, motivo),
    do: {:ausente, @motivos[motivo]}

  defp medida(nil), do: {:ausente, :not_computed}

  defp distancia(%{"value" => m, "reaches" => r}), do: {:ok, %{mean: m, reaches: r}}
  defp distancia(nil), do: {:ausente, :not_computed}
  defp distancia(outra), do: medida(outra)

  defp aresta(a), do: %{from: a["source"], to: a["target"], weight: a["weight"]}

  # Regra 1 e 2: um agregado por comunidade com ≥ k; o resto num "other" se juntar ≥ k. O id é a
  # posição na lista da visão, e nada mais.
  defp agregar(fora, k, grupo_de) do
    por_comunidade = Enum.group_by(fora, grupo_de)

    {grandes, pequenas} =
      por_comunidade
      |> Enum.reject(fn {c, _} -> is_nil(c) end)
      |> Enum.sort_by(fn {c, _} -> {is_atom(c), c} end)
      |> Enum.split_with(fn {_c, membros} -> length(membros) >= k end)

    resto = Enum.flat_map(pequenas, &elem(&1, 1)) ++ Map.get(por_comunidade, nil, [])

    # Sem comunidade calculada (antes da T035), o resto não é "outras comunidades": é só gente
    # de fora, e o agregado diz isso (`community: nil`).
    chave_do_resto = if pequenas == [], do: nil, else: :other

    grupos =
      Enum.map(grandes, fn {c, membros} -> {c, membros} end) ++
        if(length(resto) >= k, do: [{chave_do_resto, resto}], else: [])

    grupos
    |> Enum.with_index(1)
    |> Enum.reduce({[], %{}}, fn {{comunidade, membros}, n}, {nos, de} ->
      id = "outside-#{n}"
      no = %{kind: :outside, id: id, community: comunidade, size: length(membros)}
      {nos ++ [no], Enum.reduce(membros, de, &Map.put(&2, &1["id"], id))}
    end)
  end

  # Regra 4, para o número de pessoas da rede.
  defp pessoas(total, dentro, k) do
    fora = total - dentro
    if fora == 0 or fora >= k, do: {:ok, total}, else: {:suprimido, :fewer_than_k_outside}
  end

  defp contar_dentro(nos, ids), do: Enum.count(nos, &MapSet.member?(ids, &1["id"]))

  defp tamanhos_dos_componentes(nos) do
    nos
    |> Enum.frequencies_by(& &1["component"])
    |> Enum.sort_by(fn {c, _} -> c end)
    |> Enum.map(&elem(&1, 1))
  end

  # Regra 4, por componente: basta um componente contar entre 1 e k − 1 pessoas de fora para a
  # lista inteira sumir — mostrar os outros e esconder um diria qual é.
  defp componentes_parciais(nos, ids, k) do
    fora_por_componente =
      nos
      |> Enum.reject(&MapSet.member?(ids, &1["id"]))
      |> Enum.frequencies_by(& &1["component"])

    if Enum.all?(fora_por_componente, fn {_c, n} -> n >= k end),
      do: {:ok, tamanhos_dos_componentes(nos)},
      else: {:suprimido, :fewer_than_k_outside}
  end
end
