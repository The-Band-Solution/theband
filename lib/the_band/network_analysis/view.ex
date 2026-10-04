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
  5. a 7. — hubs, comunidades e papel — são chamados por T037, T040 e T046 a partir de
     `ve_posicao_de?/2`;
  8. **DS1 (b)**: posição de **outra** pessoa só com escopo concedido que a alcança, ou com a
     administração; a própria pessoa vê a sua sempre;
  9. **DS5 (b)**: alcance vazio, ou só a própria pessoa: o grafo vem `{:recortado, :no_reach}`;
  10. o grau normalizado não aparece com alcance parcial (FR-033): o nó da visão não o carrega.

  Depende de: nenhuma ontologia.
  """

  @type alcance :: :todas | {:algumas, MapSet.t()}

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
            | {:ausente, :no_edge_in_window}
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
          optional(:gone) => MapSet.t()
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

    Map.merge(base, corpo)
  end

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
      community: no["community"],
      links_outside_reach?: ligado_fora?
    }
  end

  # A medida gravada (data-model §1.2), com o motivo da ausência como átomo conhecido — nunca
  # criado a partir do dado. Leitura gravada antes da medida existir: não calculada, e não 0.
  defp medida(%{"value" => v}) when is_number(v), do: {:ok, v}
  defp medida(%{"absent" => "network_too_small"}), do: {:ausente, :network_too_small}
  defp medida(nil), do: {:ausente, :not_computed}

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
