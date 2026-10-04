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

  Papel, percentil e o layout da visão parcial entram com as tarefas que os calculam (T031, T034,
  T045).

  Depende de: EO (organização, nomes), CMPO (coleta mais nova), Tenants (alcance).
  """

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
          views: %{allowed: [String.t()], default: String.t()}
        }
  def options, do: options(Parameters.fetch!())

  @doc false
  @spec options(Parameters.t()) :: map()
  def options(parametros) do
    %{
      networks: %{allowed: parametros.networks, default: parametros.default_network},
      windows: %{allowed: parametros.windows, default: parametros.default_window},
      views: %{allowed: @vistas, default: hd(@vistas)}
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
        View.build(leitura, reach, granted, viewer, %{min_group: parametros.min_group, gone: gone})

      {:ok,
       visao
       |> Map.drop([:granted, :viewer_person_id])
       |> nomear(nomes)
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
  defp proveniencia(leitura, :total) do
    %{
      knowledge_versions: Map.get(leitura.provenance, "knowledge_versions", %{}),
      account_type_unknown: Map.get(leitura.provenance, "account_type_unknown"),
      source_computed_at: leitura.source_computed_at
    }
  end

  defp proveniencia(leitura, _alcance) do
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
