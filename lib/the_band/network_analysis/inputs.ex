defmodule TheBand.NetworkAnalysis.Inputs do
  @moduledoc """
  A função de entrada do cálculo: as arestas de cada rede numa janela — feature 076, T014 (a
  forma) e T028 (a ligação às duas redes; FR-005 a FR-009; research.md R2, R12).

  `Commands.compute/5` recebe as arestas por esta função, e não as busca: a busca de cada rede
  mora no dono dela, e o cálculo não muda quando a fonte muda.

  ## As duas fontes

  - **revisão**: as leituras vigentes da 073 (`ReviewNetwork.current_edges/2`), da mesma janela,
    com o instante delas em `source_computed_at` (R2). Sem leitura da 073 naquela janela,
    `{:ausente, :not_computed}`: nada é gravado, e nunca a de outra janela no lugar;
  - **designação**: os pares de `WorkItems.assignment_pairs/3` desde o início da **maior** janela,
    classificados por `AssignmentClassification` com os tipos de EO e as contas declaradas da
    organização, e resumidos por janela pelo instante de **abertura** da issue.

  ## O número fixo de consultas

  Todas as buscas acontecem **uma vez**, ao montar a função, e não a cada rede e janela: o job
  chama a função seis vezes, e seis vezes a mesma consulta seria pagar a mesma resposta (L38).

  ## Pessoas sem aresta (FR-008)

  As pessoas `person` da organização (`EO.organization_person_ids/2`) que não são nó, sem as
  contas declaradas da organização (que não são pessoas na rede). **Nulo** quando a janela não
  tem aresta nenhuma: sem rede, *"sem aresta"* não distingue ninguém, e zero afirmaria que todos
  têm.

  Depende de: ReviewNetwork, WorkItems, CMPO (repositórios da organização), EO (tipos de conta e
  pessoas da organização), Tenants (contas declaradas), sempre pela API pública.
  """

  alias TheBand.NetworkAnalysis.AssignmentClassification
  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.ReviewNetwork
  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems

  @dia 86_400

  @doc "A função de entrada da organização, para as redes e janelas dos parâmetros."
  @spec for_organization(Tenant.t(), map(), DateTime.t(), map()) :: Commands.entradas()
  def for_organization(%Tenant{} = tenant, %{id: organization_id}, %DateTime{} = now, parametros) do
    contas = Tenants.organization_account_ids(tenant)

    pessoas =
      tenant
      |> EO.organization_person_ids(organization_id)
      |> MapSet.new()
      |> MapSet.difference(contas)

    revisao = ReviewNetwork.current_edges(tenant, organization_id)
    designacao = designacao(tenant, organization_id, now, parametros, contas)

    fn
      "review", dias, _inicio -> revisao(Map.fetch(revisao, dias), pessoas)
      "assignment", _dias, inicio -> designacao(designacao, inicio, pessoas)
    end
  end

  # A leitura da 073 da mesma janela, em arestas da análise.
  defp revisao(:error, _pessoas), do: {:ausente, :not_computed}

  defp revisao({:ok, leitura}, pessoas) do
    e = leitura.excluded

    {:ok,
     %{
       edges: leitura.edges,
       exclusions: %{
         "pairs" => leitura.reviews + soma(e),
         "self_review" => e.self_review,
         "bot_or_app" => e.bot_or_app,
         # Nulo na leitura da versão 1 da regra (073): não avaliado, e nunca zero.
         "organization_account" => e.organization_account,
         "unlinked_person" => e.unlinked_person
       },
       people_without_edges: sem_aresta(leitura.edges, pessoas),
       source_computed_at: leitura.computed_at,
       provenance: %{"source" => "review_network_readings"}
     }}
  end

  defp soma(excluidos),
    do: excluidos |> Map.values() |> Enum.reject(&is_nil/1) |> Enum.sum()

  # Os pares da maior janela, classificados uma vez; o resumo por janela é em memória.
  defp designacao(tenant, organization_id, now, parametros, contas) do
    desde = DateTime.add(now, -Enum.max(parametros.windows) * @dia, :second)

    repositorios =
      tenant
      |> CMPO.list_observed(organization_id: organization_id)
      # Repositório tirado da observação não entra, como na 073.
      |> Enum.filter(&is_nil(&1.excluded_at))
      |> Enum.map(& &1.observed_repository_id)

    pares = WorkItems.assignment_pairs(tenant, repositorios, since: desde)

    ids =
      pares
      |> Enum.flat_map(&[&1.author_person_id, &1.assignee_person_id])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    AssignmentClassification.classify(pares, EO.account_types(tenant, ids), contas)
  end

  defp designacao(classificados, inicio, pessoas) do
    resumo = AssignmentClassification.summarize(classificados, inicio)

    {:ok,
     %{
       edges: resumo.edges,
       exclusions: resumo.exclusions,
       people_without_edges: sem_aresta(resumo.edges, pessoas),
       source_computed_at: nil,
       provenance: %{"account_type_unknown" => resumo.account_type_unknown}
     }}
  end

  defp sem_aresta([], _pessoas), do: nil

  defp sem_aresta(arestas, pessoas) do
    nos = arestas |> Enum.flat_map(&[&1.source, &1.target]) |> MapSet.new()
    pessoas |> MapSet.difference(nos) |> MapSet.size()
  end
end
