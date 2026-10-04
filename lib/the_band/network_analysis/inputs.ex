defmodule TheBand.NetworkAnalysis.Inputs do
  @moduledoc """
  A função de entrada do cálculo: as arestas de cada rede numa janela — feature 076, T014 (a
  forma) e T028 (a ligação às duas redes; FR-005 a FR-009; research.md R2, R12).

  `Commands.compute/5` recebe as arestas por esta função, e não as busca: a busca de cada rede
  mora no dono dela, e o cálculo não muda quando a fonte muda.

  ## As duas fontes

  - **revisão**: as leituras vigentes da 073 (`ReviewNetwork.current_edges/2`), da mesma janela,
    com o instante delas em `source_computed_at` (R2). Sem leitura da 073 naquela janela,
    `{:ausente, :not_computed}`: nada é gravado, e nunca a de outra janela no lugar. Leitura da
    073 que **não sabe** das contas declaradas vigentes é `{:ausente, :review_reading_outdated}`
    (ver abaixo);
  - **designação**: os pares de `WorkItems.assignment_pairs/3` desde o início da **maior** janela,
    classificados por `AssignmentClassification` com os tipos de EO e as contas declaradas da
    organização, e resumidos por janela pelo instante de **abertura** da issue.

  ## A leitura da 073 desatualizada (E4 da revisão semântica do PR #1383)

  A conta declarada da organização sai das **duas** redes (A7). A rede de designação usa as
  declarações de agora; a de revisão usa as arestas que a 073 gravou. Quando a leitura da 073 foi
  gravada pela versão 1 da `review.network.edge` (o motivo `organization_account` é nulo), ou foi
  calculada **até** a última declaração ou revogação do tenant, as arestas dela podem ter a conta
  declarada como nó, ou deixar fora quem voltou a ser pessoa. Essa leitura não é usada como se
  tivesse medido: a revisão fica `{:ausente, :review_reading_outdated}`, e a sincronização
  seguinte recalcula a 073, que agenda a análise.

  O instante igual conta como desatualizado: os dois são gravados em segundos, e no mesmo segundo
  não se sabe qual veio antes.

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
    mudanca = Tenants.organization_accounts_changed_at(tenant)
    designacao = designacao(tenant, organization_id, now, parametros, contas)

    fn
      "review", dias, _inicio -> revisao(Map.fetch(revisao, dias), pessoas, mudanca)
      "assignment", _dias, inicio -> designacao(designacao, inicio, pessoas)
    end
  end

  @doc """
  Se a leitura da rede de revisão sabe das contas declaradas vigentes: avaliou o motivo
  `organization_account` (não é da versão 1) e foi calculada **depois** da última mudança nas
  declarações (`nil` quando nunca houve). Usada aqui, sobre a leitura da 073, e pelo `Reader`,
  sobre a leitura da análise feita dela.
  """
  @spec review_reading_current?(non_neg_integer() | nil, DateTime.t(), DateTime.t() | nil) ::
          boolean()
  def review_reading_current?(nil, _calculada_em, _mudanca), do: false
  def review_reading_current?(_contagem, _calculada_em, nil), do: true

  def review_reading_current?(_contagem, %DateTime{} = calculada_em, %DateTime{} = mudanca),
    do: DateTime.compare(calculada_em, mudanca) == :gt

  # A leitura da 073 da mesma janela, em arestas da análise.
  defp revisao(:error, _pessoas, _mudanca), do: {:ausente, :not_computed}

  defp revisao({:ok, leitura}, pessoas, mudanca) do
    if review_reading_current?(
         leitura.excluded.organization_account,
         leitura.computed_at,
         mudanca
       ),
       do: revisao_vigente(leitura, pessoas),
       else: {:ausente, :review_reading_outdated}
  end

  defp revisao_vigente(leitura, pessoas) do
    e = leitura.excluded

    {:ok,
     %{
       edges: leitura.edges,
       exclusions: %{
         "pairs" => leitura.reviews + soma(e),
         "self_review" => e.self_review,
         "bot_or_app" => e.bot_or_app,
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
