defmodule TheBand.NetworkAnalysis.Reader do
  @moduledoc """
  A única porta da análise de rede para quem consulta — feature 076, T017 (FR-002, FR-013,
  FR-015; R13, R18 da segurança; `contracts/network-analysis.md`, `read/4`, `selection/1`,
  `options/0`).

  ## O alcance é recalculado a cada chamada

  `Tenants.pessoas_alcancadas/2` e `/3` são chamadas **aqui**, em cada `read/4`. Nunca recebidas
  de fora nem guardadas no processo da tela (A22): o alcance perdido some na leitura seguinte.

  ## Os parâmetros do endereço são texto, e nunca átomo

  `selection/1` compara cada parâmetro como **texto exato** com as listas da base; fora delas, o
  padrão, sem dizer que era inválido. Nenhum `String.to_atom/1` nem `String.to_existing_atom/1`
  (A12, L54).

  ## Ordem de `read/4`

  1. a organização por id **e** tenant (`EO.fetch_organization/2`): outro tenant, inexistente e id
     malformado dão o mesmo `{:error, :not_found}`;
  2. a leitura vigente de `(tenant, organização, rede, janela)`; sem ela, `{:ausente,
     :not_computed}`; mais velha que a maior janela, `{:ausente, :stale}` (R18) — nunca a de
     outra rede ou janela no lugar. Na rede de revisão, a leitura feita de uma leitura da 073 que
     não sabe das contas declaradas vigentes (versão 1, ou calculada até a última declaração ou
     revogação) é `{:ausente, :review_reading_outdated}` (E4 da revisão semântica do PR #1383;
     `Inputs.review_reading_current?/3`): a conta declarada seria nó numa rede e não na outra;
  3. os nomes das pessoas da leitura, numa consulta (`EO.people_names/2`); quem não está mais em
     EO sai do alcance e é tratado como pessoa de fora (R18);
  4. os dois alcances, nesta chamada;
  5. `View.build/5`;
  6. a coleta mais nova que a leitura (073, Q3);
  7. as contagens da rede (T029), com as exclusões e as pessoas sem aresta **só para quem alcança
     todos**: são sobre a organização inteira, gente de fora do alcance incluída (como a 073, Q5);
  8. o número de contas declaradas da organização (R14), sem dizer quais.

  Número fixo de consultas, independente do tamanho da rede (L38).

  Papel e percentil entram com a tarefa que os calcula (T045). As posições, a faixa de cor e os
  nomes escritos no desenho são decididos aqui (`desenhar/3`, T033).

  Depende de: EO (organização, nomes), CMPO (coleta mais nova), Tenants (alcance),
  `Algorithms.Layout` e `Algorithms.Projection` (o desenho da visão parcial).
  """

  alias TheBand.NetworkAnalysis.Algorithms.Layout
  alias TheBand.NetworkAnalysis.Algorithms.Position
  alias TheBand.NetworkAnalysis.Algorithms.Projection
  alias TheBand.NetworkAnalysis.Inputs
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.NetworkAnalysis.Queries
  alias TheBand.NetworkAnalysis.View
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @dia 86_400

  # As duas vistas do grafo (FR-026). Vocabulário da tela, e não valor da base: não muda o que a
  # plataforma afirma, só como desenha.
  @vistas ["weighted", "communities"]

  @type selection :: %{network: String.t(), window: pos_integer(), view: String.t()}

  @doc "As listas fechadas para a tela desenhar os seletores. A tela nunca as escreve."
  @spec options() :: %{
          networks: %{allowed: [String.t()], default: String.t()},
          windows: %{allowed: [pos_integer()], default: pos_integer()},
          views: %{allowed: [String.t()], default: String.t()},
          eigenvector: %{max_iterations: pos_integer(), tolerance_per_node: float()}
        }
  def options, do: options(Parameters.fetch!())

  @doc false
  @spec options(Parameters.t()) :: map()
  def options(parametros) do
    %{
      networks: %{allowed: parametros.networks, default: parametros.default_network},
      windows: %{allowed: parametros.windows, default: parametros.default_window},
      views: %{allowed: @vistas, default: hd(@vistas)},
      # Para a frase do autovetor que não assentou dizer as rodadas e a tolerância (3.4.4, T053).
      eigenvector: Map.take(parametros.eigenvector, [:max_iterations, :tolerance_per_node])
    }
  end

  @doc """
  Normaliza os parâmetros do endereço. Cada um é comparado como texto exato com a lista; fora
  dela, o padrão. Nenhum átomo é criado.
  """
  @spec selection(%{optional(String.t()) => term()}) :: selection()
  def selection(params), do: selection(params, Parameters.fetch!())

  @doc false
  @spec selection(map(), Parameters.t()) :: selection()
  def selection(params, parametros) when is_map(params) do
    %{
      network: escolher(params["network"], parametros.networks, parametros.default_network),
      window:
        escolher(
          params["window"],
          parametros.windows,
          parametros.default_window,
          &Integer.to_string/1
        ),
      view: escolher(params["view"], @vistas, hd(@vistas))
    }
  end

  defp escolher(valor, lista, padrao, como_texto \\ & &1)

  defp escolher(valor, lista, padrao, como_texto) when is_binary(valor),
    do: Enum.find(lista, padrao, &(como_texto.(&1) == valor))

  defp escolher(_valor, _lista, padrao, _como_texto), do: padrao

  @doc """
  A visão recortada da organização, na rede e janela escolhidas, com os parâmetros da base. É o
  que a fachada expõe como `read/4`.
  """
  @spec read(Tenant.t(), User.t(), term(), selection()) ::
          {:ok, map()}
          | {:ausente, :not_computed | :stale | :review_reading_outdated}
          | {:error, :not_found}
  def read(tenant, user, organization_id, selecao),
    do: read(tenant, user, organization_id, selecao, Parameters.fetch!())

  @doc false
  @spec read(Tenant.t(), User.t(), term(), selection(), Parameters.t()) ::
          {:ok, map()}
          | {:ausente, :not_computed | :stale | :review_reading_outdated}
          | {:error, :not_found}
  def read(%Tenant{} = tenant, %User{} = user, organization_id, selecao, parametros) do
    %{network: rede, window: dias} = selecao

    with {:ok, organizacao} <- EO.fetch_organization(tenant, organization_id),
         {:ok, leitura} <- vigente(tenant, organizacao.id, rede, dias, parametros) do
      ids = Enum.map(leitura.nodes, & &1["id"])
      nomes = EO.people_names(tenant, ids)
      gone = for id <- ids, not Map.has_key?(nomes, id), into: MapSet.new(), do: id

      reach = sem(Tenants.pessoas_alcancadas(tenant, user), gone)
      granted = sem(Tenants.pessoas_alcancadas(tenant, user, origem: :concedida), gone)
      viewer = pessoa_de(user)

      visao =
        View.build(leitura, reach, granted, viewer, %{
          min_group: parametros.min_group,
          gone: gone,
          core_size: parametros.community_core_size,
          hubs_size: parametros.hubs_size
        })

      {:ok,
       visao
       |> com_papeis(leitura, parametros, nomes)
       |> Map.drop([:granted, :viewer_person_id])
       |> nomear(nomes)
       |> nomear_comunidades(nomes, parametros)
       |> nomear_hubs(nomes)
       |> criterio(parametros)
       |> desenhar(leitura, parametros)
       |> Map.merge(%{
         counts: contagens(leitura, visao),
         declared_organization_accounts: contas_declaradas(tenant, organizacao.id),
         provenance: proveniencia(leitura, visao.reach),
         organization_id: organizacao.id,
         network: rede,
         window_days: dias,
         window_start: leitura.window_start,
         window_end: leitura.window_end,
         computed_at: leitura.computed_at,
         newer_collection: coleta_mais_nova(tenant, organizacao.id, leitura.computed_at)
       })}
    end
  end

  # O papel e os percentis (T045, T046; R17, DS1): derivados AQUI, pela regra vigente, sobre a rede
  # inteira, e nunca gravados. Entram só onde a visão permite: no nó do grafo e na lista de
  # posições, para os alcançados cuja posição quem consulta pode ver; a própria pessoa sempre.
  defp com_papeis(visao, leitura, parametros, nomes) do
    papeis = papeis(leitura, parametros)

    visao =
      Map.put(
        visao,
        :position_rule,
        Map.take(parametros.position, [
          :min_people,
          :high_above,
          :median_above,
          :low_below,
          :labels
        ])
      )

    papel_de = fn id ->
      if View.ve_posicao_de?(visao, id),
        do: Map.fetch!(papeis, id),
        else: {:recortado, :positions_not_granted}
    end

    case visao.graph do
      {:ok, grafo} ->
        nos =
          Enum.map(grafo.nodes, fn
            %{kind: :person, id: id} = no -> Map.put(no, :role, papel_de.(id))
            no -> no
          end)

        posicoes =
          for %{kind: :person} = no <- nos do
            %{
              person_id: no.id,
              name: Map.fetch!(nomes, no.id),
              community: no.community,
              degree: no.degree,
              role: no.role
            }
          end
          |> Enum.sort_by(&{String.downcase(&1.name), &1.person_id})

        %{visao | graph: {:ok, %{grafo | nodes: nos}}}
        |> Map.put(:positions, {:ok, posicoes})

      {:recortado, :no_reach} ->
        Map.put(visao, :positions, {:recortado, :no_reach})

      {:ausente, motivo} ->
        Map.put(visao, :positions, {:ausente, motivo})
    end
  end

  defp papeis(leitura, parametros) do
    leitura.nodes
    |> Map.new(fn n ->
      {n["id"], %{degree: n["degree"], betweenness: medida_lida(n["betweenness"])}}
    end)
    |> Position.roles(parametros.position)
  end

  defp medida_lida(%{"value" => v}) when is_number(v), do: {:ok, v}
  defp medida_lida(_ausente), do: {:ausente, :not_computed}

  @doc """
  O perfil de uma pessoa nas duas redes, na janela escolhida (T047; FR-013, FR-014, FR-047 a
  FR-049; DS1, DS3 (a); `contracts/network-analysis.md`, `profile/5`). É o que a fachada expõe.
  """
  @spec profile(Tenant.t(), User.t(), term(), term(), selection()) ::
          {:ok, map()} | {:error, :not_found}
  def profile(tenant, user, organization_id, person_id, selecao),
    do: profile(tenant, user, organization_id, person_id, selecao, Parameters.fetch!())

  @doc false
  @spec profile(Tenant.t(), User.t(), term(), term(), selection(), Parameters.t()) ::
          {:ok, map()} | {:error, :not_found}
  def profile(%Tenant{} = tenant, %User{} = user, organization_id, person_id, selecao, parametros) do
    viewer = pessoa_de(user)

    # Abre se, e só se, a pessoa está no alcance DESTA chamada (`pessoas_alcancadas/2`) ou é a de
    # quem consulta. `pode_ver/3` não decide nada aqui (FR-013, A10). Outro tenant, inexistente,
    # fora do alcance e id que não é UUID dão o mesmo `:not_found` (FR-014).
    with {:ok, organizacao} <- EO.fetch_organization(tenant, organization_id),
         {:ok, id} <- uuid(person_id),
         reach = Tenants.pessoas_alcancadas(tenant, user),
         true <- id == viewer or alcanca?(reach, id),
         %{^id => nome} <- EO.people_names(tenant, [id]) do
      granted = Tenants.pessoas_alcancadas(tenant, user, origem: :concedida)
      base = %{granted: granted, viewer_person_id: viewer}

      redes =
        Map.new(parametros.networks, fn rede ->
          {rede,
           perfil_na_rede(
             tenant,
             organizacao.id,
             rede,
             selecao.window,
             id,
             reach,
             base,
             parametros
           )}
        end)

      {:ok, %{person_id: id, name: nome, networks: redes}}
    else
      _ -> {:error, :not_found}
    end
  end

  defp uuid(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> :error
    end
  end

  defp uuid(_id), do: :error

  defp alcanca?(:todas, _id), do: true
  defp alcanca?({:algumas, ids}, id), do: MapSet.member?(ids, id)

  defp perfil_na_rede(tenant, organization_id, rede, dias, id, reach, base, parametros) do
    with {:ok, leitura} <- vigente(tenant, organization_id, rede, dias, parametros),
         %{} = no <- Enum.find(leitura.nodes, &(&1["id"] == id)) do
      papel =
        if View.ve_posicao_de?(base, id),
          do: Map.fetch!(papeis(leitura, parametros), id),
          else: {:recortado, :positions_not_granted}

      nomes = EO.people_names(tenant, leitura.nodes |> Enum.map(& &1["id"]))
      dentro? = fn outro -> Map.has_key?(nomes, outro) and alcanca?(reach, outro) end

      para = for a <- leitura.edges, a["source"] == id, do: {a["target"], a["weight"]}
      de = for a <- leitura.edges, a["target"] == id, do: {a["source"], a["weight"]}

      {:ok,
       %{
         out_people: no["out_people"],
         in_people: no["in_people"],
         degree: {:ok, no["degree"]},
         betweenness: medida_lida(no["betweenness"]),
         role: papel,
         community: no["community"],
         to: pares(para, dentro?, nomes),
         from: pares(de, dentro?, nomes),
         to_outside_reach: fora(para, dentro?),
         from_outside_reach: fora(de, dentro?),
         to_total: para |> Enum.map(&elem(&1, 1)) |> Enum.sum(),
         from_total: de |> Enum.map(&elem(&1, 1)) |> Enum.sum(),
         # A linha da leitura de cada rede no perfil (3.0.5, T053).
         computed_at: leitura.computed_at,
         window_start: leitura.window_start,
         window_end: leitura.window_end,
         window_days: dias
       }}
    else
      nil -> {:ausente, :no_edges_in_window}
      {:ausente, motivo} -> {:ausente, motivo}
    end
  end

  # Os pares com alcançados, por nome, ordenados pelo peso (FR-048), empate pelo nome.
  defp pares(lista, dentro?, nomes) do
    for {outro, w} <- lista, dentro?.(outro) do
      %{person_id: outro, name: Map.fetch!(nomes, outro), weight: w}
    end
    |> Enum.sort_by(&{-&1.weight, String.downcase(&1.name), &1.person_id})
  end

  # FR-049: os pares de fora só somados, sem nome e sem número por pessoa.
  defp fora(lista, dentro?) do
    case for({outro, w} <- lista, not dentro?.(outro), do: w) do
      [] -> :nenhum
      pesos -> {:agregado, Enum.sum(pesos)}
    end
  end

  defp vigente(tenant, organization_id, rede, dias, parametros) do
    case Queries.current(tenant, organization_id, rede, dias) do
      nil ->
        {:ausente, :not_computed}

      leitura ->
        # R18: leitura mais velha que a maior janela não é mostrada. Relativa ao relógio de agora,
        # e não ao da leitura: é a idade dela que importa.
        limite = DateTime.add(DateTime.utc_now(), -Enum.max(parametros.windows) * @dia, :second)

        cond do
          DateTime.compare(leitura.computed_at, limite) == :lt -> {:ausente, :stale}
          desatualizada?(tenant, leitura) -> {:ausente, :review_reading_outdated}
          true -> {:ok, leitura}
        end
    end
  end

  defp desatualizada?(tenant, %{network: "review"} = leitura) do
    not Inputs.review_reading_current?(
      leitura.exclusions["organization_account"],
      leitura.source_computed_at,
      Tenants.organization_accounts_changed_at(tenant)
    )
  end

  defp desatualizada?(_tenant, _leitura), do: false

  # Quem saiu de EO sai do alcance (R18): com alcance parcial, é de fora.
  defp sem(:todas, _gone), do: :todas
  defp sem({:algumas, ids}, gone), do: {:algumas, MapSet.difference(ids, gone)}

  defp pessoa_de(user) do
    case Tenants.person_of_user(user) do
      {:ok, person_id} -> person_id
      _ -> nil
    end
  end

  defp nomear(%{graph: {:ok, grafo}} = visao, nomes) do
    nos =
      Enum.map(grafo.nodes, fn
        %{kind: :person, id: id} = no -> Map.put(no, :name, Map.fetch!(nomes, id))
        no -> no
      end)

    %{visao | graph: {:ok, %{grafo | nodes: nos}}}
  end

  defp nomear(visao, _nomes), do: visao

  # Os membros alcançados por nome, na ordem do nome (FR-034: a lista é por nome, e nunca por
  # medida); os mais centrais na ordem da medida, que é a deles. As faixas citadas da
  # modularidade vêm da base, com a fonte que a tela escreve (FR-031).
  defp nomear_comunidades(%{communities: {:ok, c}} = visao, nomes, parametros) do
    blocos =
      Enum.map(c.blocks, fn b ->
        membros =
          b.members
          |> Enum.map(&%{person_id: &1, name: Map.fetch!(nomes, &1)})
          |> Enum.sort_by(&{String.downcase(&1.name), &1.person_id})

        nucleo =
          case b.core do
            {:recortado, _} = r -> r
            lista -> Enum.map(lista, &Map.put(&1, :name, Map.fetch!(nomes, &1.person_id)))
          end

        %{b | members: membros, core: nucleo}
      end)

    %{
      visao
      | communities:
          {:ok, Map.merge(c, %{blocks: blocos, thresholds: parametros.modularity_thresholds})}
    }
  end

  defp nomear_comunidades(visao, _nomes, _parametros), do: visao

  # As listas de hubs ficam na ordem da medida (FR-034: são o único ranking, por terem sido
  # pedidas); aqui só ganham o nome.
  defp nomear_hubs(%{hubs: {:ok, h}} = visao, nomes) do
    com_nome = fn
      {:ok, linhas} ->
        {:ok, Enum.map(linhas, &Map.put(&1, :name, Map.fetch!(nomes, &1.person_id)))}

      ausente ->
        ausente
    end

    %{
      visao
      | hubs:
          {:ok,
           %{
             degree: com_nome.(h.degree),
             betweenness: com_nome.(h.betweenness),
             closeness: com_nome.(h.closeness),
             eigenvector: Enum.map(h.eigenvector, &%{&1 | rows: com_nome.(&1.rows)})
           }}
    }
  end

  defp nomear_hubs(visao, _nomes), do: visao

  # FR-043: o critério σ > limiar da base, dito como critério; σ ausente não decide nada.
  defp criterio(%{small_world: sw} = visao, parametros) do
    limiar = parametros.small_world.criterion_threshold

    criterio =
      case sw.sigma do
        {:ok, %{value: v}} -> if v > limiar, do: :meets, else: :does_not_meet
        _ -> nil
      end

    %{visao | small_world: Map.merge(sw, %{criterion: criterio, threshold: limiar})}
  end

  # O que o desenho precisa, decidido aqui e não na tela (T031, T033; R9, R16):
  #
  # - **posições**: as gravadas na leitura só quando a visão é a rede inteira (alcance total, sem
  #   agregado). Com alcance parcial — ou com agregado de quem saiu de EO —, recalculadas sobre o
  #   grafo DA VISÃO, com a mesma semente: as da rede inteira diriam onde estão as pessoas de fora
  #   (R2 da segurança; FR-022). Acima do teto, ausentes, com o motivo da leitura;
  # - **faixa de cor** da intermediação, pela regra da base; ausente, sem faixa;
  # - **nome escrito** nos `labelled_nodes` mais ligados entre as pessoas DA VISÃO — que são só as
  #   alcançadas (O1 da revisão semântica 3) —, empate pelo id, como `hubs_list_size`.
  defp desenhar(%{graph: {:ok, grafo}} = visao, leitura, parametros) do
    pessoas = for %{kind: :person} = no <- grafo.nodes, do: no

    escritos =
      pessoas
      |> Enum.sort_by(&{-&1.degree, &1.id})
      |> Enum.take(parametros.layout.labelled_nodes)
      |> MapSet.new(& &1.id)

    nos =
      Enum.map(grafo.nodes, fn
        %{kind: :person} = no ->
          Map.merge(no, %{
            band: faixa(no.betweenness, parametros.color_bands),
            labelled?: MapSet.member?(escritos, no.id)
          })

        no ->
          no
      end)

    bandas = for b <- parametros.color_bands, do: %{code: b["code"], label: b["label"]}

    %{
      visao
      | graph:
          {:ok,
           Map.merge(grafo, %{
             nodes: nos,
             layout: posicoes(visao.reach, grafo, leitura, parametros),
             bands: bandas
           })}
    }
  end

  defp desenhar(visao, _leitura, _parametros), do: visao

  defp posicoes(alcance, grafo, leitura, parametros) do
    gravadas = Map.new(leitura.nodes, &{&1["id"], &1})
    rede_inteira? = alcance == :total and Enum.all?(grafo.nodes, &(&1.kind == :person))

    cond do
      Map.has_key?(leitura.measures["layout"] || %{}, "absent") ->
        {:ausente, :network_too_large_for_platform}

      rede_inteira? and Enum.all?(grafo.nodes, &Map.has_key?(gravadas[&1.id], "x")) ->
        {:ok, Map.new(grafo.nodes, &{&1.id, {gravadas[&1.id]["x"], gravadas[&1.id]["y"]}})}

      true ->
        adjacencia =
          grafo.edges
          |> Enum.map(&%{source: &1.from, target: &1.to, weight: &1.weight})
          |> Projection.undirected()
          |> Map.fetch!(:adjacency)

        {:ok,
         Layout.fruchterman_reingold(
           Enum.map(grafo.nodes, & &1.id),
           adjacencia,
           Map.take(parametros.layout, [:seed, :iterations])
         )}
    end
  end

  # A faixa da regra `betweenness_color_bands`: limites inclusivos (`from`, `to`) e exclusivos
  # (`from_exclusive`, `to_exclusive`), como a base os declara.
  defp faixa({:ok, v}, bandas) do
    Enum.find_value(bandas, fn b ->
      if dentro?(v, b), do: b["code"]
    end) || raise "betweenness_color_bands não cobre #{v}"
  end

  defp faixa(_ausente, _bandas), do: nil

  defp dentro?(v, b) do
    (is_nil(b["from"]) or v >= b["from"]) and
      (is_nil(b["from_exclusive"]) or v > b["from_exclusive"]) and
      (is_nil(b["to"]) or v <= b["to"]) and
      (is_nil(b["to_exclusive"]) or v < b["to_exclusive"])
  end

  defp coleta_mais_nova(tenant, organization_id, computed_at) do
    tenant
    |> CMPO.list_observed(organization_id: organization_id)
    |> Enum.map(& &1.changes_collected_at)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(DateTime, fn -> nil end)
    |> case do
      %DateTime{} = corte ->
        if DateTime.compare(corte, computed_at) == :gt, do: {:em, corte}, else: :nenhuma

      nil ->
        :nenhuma
    end
  end

  # As contagens da rede (US2; FR-007, FR-008). Ausência é dita: sem aresta, o número de arestas
  # é ausente, e nunca 0. As exclusões e as pessoas sem aresta são da organização inteira, e só
  # quem alcança todos as lê (073, Q5); com alcance parcial, a regra, e nenhum número.
  defp contagens(leitura, visao) do
    exclusoes = leitura.exclusions || %{}
    arestas = length(leitura.edges)

    %{
      items: positivo(itens(leitura.network, exclusoes), :none_in_window),
      edges: positivo(arestas, :no_edge_in_window),
      exclusions: exclusoes_vistas(visao.reach, exclusoes),
      people: visao.people,
      people_without_edges: sem_aresta(visao.reach, leitura.people_without_edges)
    }
  end

  # Issues da janela na designação; revisões (pares contáveis) na revisão.
  defp itens("assignment", exclusoes), do: Map.get(exclusoes, "issues", 0)
  defp itens("review", exclusoes), do: Map.get(exclusoes, "pairs", 0)

  defp positivo(n, _motivo) when is_integer(n) and n > 0, do: {:ok, n}
  defp positivo(_n, motivo), do: {:ausente, motivo}

  defp exclusoes_vistas(:total, exclusoes) do
    if Map.get(exclusoes, "pairs", 0) == 0 and Map.get(exclusoes, "issues", 0) == 0,
      do: {:ausente, :none_in_window},
      else: {:ok, Map.drop(exclusoes, ["pairs", "issues"])}
  end

  defp exclusoes_vistas(_alcance, _exclusoes), do: {:recortado, :regra}

  defp sem_aresta(:total, nil), do: {:ausente, :no_edge_in_window}
  defp sem_aresta(:total, n), do: {:ok, n}
  defp sem_aresta(_alcance, _n), do: {:recortado, :regra}

  # Só o que a tela diz da proveniência nesta fatia: quantas designações tinham conta de tipo não
  # gravado (R13), e só para quem alcança todos — é contagem sobre a organização inteira.
  defp proveniencia(leitura, alcance) do
    Map.merge(proveniencia_de_contas(leitura, alcance), %{
      seed: Map.get(leitura.provenance, "seed"),
      generator: Map.get(leitura.provenance, "generator"),
      random_graphs: Map.get(leitura.provenance, "random_graphs")
    })
  end

  defp proveniencia_de_contas(leitura, :total) do
    %{
      knowledge_versions: Map.get(leitura.provenance, "knowledge_versions", %{}),
      account_type_unknown: Map.get(leitura.provenance, "account_type_unknown"),
      source_computed_at: leitura.source_computed_at
    }
  end

  defp proveniencia_de_contas(leitura, _alcance) do
    %{
      knowledge_versions: Map.get(leitura.provenance, "knowledge_versions", %{}),
      account_type_unknown: nil,
      source_computed_at: leitura.source_computed_at
    }
  end

  # O número de contas declaradas que são pessoas desta organização (R14), sem dizer quais.
  defp contas_declaradas(tenant, organization_id) do
    tenant
    |> EO.organization_person_ids(organization_id)
    |> MapSet.new()
    |> MapSet.intersection(Tenants.organization_account_ids(tenant))
    |> MapSet.size()
  end
end
