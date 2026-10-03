defmodule TheBand.ReviewNetwork.Reader do
  @moduledoc """
  A leitura da rede de revisão por quem consulta, recortada pelo alcance **recalculado a cada
  chamada** — feature 073, T016, T023 (FR-013, FR-015; R3, R10 da segurança; A3, A8, A13).

  **Os parâmetros entram como argumento** (`contracts/review-network.md`, *Os parâmetros entram pela
  fachada*). Em produção, quem chama é a fachada `ReviewNetwork.read/4`, que os lê da base; esta
  função não é chamada de fora do módulo.

  A ordem é a do contrato, e cada passo é o que impede um cenário de ataque:

  1. a janela contra a lista fechada, nunca `String.to_atom/1` (A8);
  2. a organização por id **e** tenant, e o mesmo `{:error, :not_found}` para a de outro tenant e a
     inexistente (A3, §11.1);
  3. a leitura vigente da janela; sem ela, `{:ausente, :nao_calculada}`, e nunca a de outra janela;
  4. o alcance, **nesta chamada**: nunca recebido de fora nem guardado (R10, A13);
  5. o recorte (`Slice`) e os nomes das pessoas que sobraram, filtrados pelo tenant;
  6. a coleta de mudanças mais nova que a leitura (Q3).

  Número fixo de consultas, independente do tamanho da rede (L38).

  Depende de: EO (organização, pessoas, nomes), CMPO (repositórios da organização), Tenants
  (alcance).
  """

  alias TheBand.Ontology.SEON.CMPO
  alias TheBand.Ontology.SEON.EO
  alias TheBand.ReviewNetwork.Queries
  alias TheBand.ReviewNetwork.Slice
  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @doc "A visão recortada da rede, com nomes, ordenada por nome e por nada mais (FR-018a)."
  @spec read(Tenant.t(), User.t(), term(), term(), map()) ::
          {:ok, map()} | {:ausente, :nao_calculada} | {:error, :not_found | :janela_invalida}
  def read(%Tenant{} = tenant, %User{} = user, organization_id, window, parametros) do
    with {:ok, dias} <- janela(window, parametros.windows),
         {:ok, organizacao} <- EO.fetch_organization(tenant, organization_id),
         {:ok, leitura} <- vigente(tenant, organizacao.id, dias) do
      alcance = Tenants.pessoas_alcancadas(tenant, user)
      pessoas_da_org = EO.organization_person_ids(tenant, organizacao.id)
      visao = Slice.view(leitura, alcance, parametros, pessoas_da_org)
      nomes = EO.people_names(tenant, ids_nomeados(visao))

      {:ok,
       visao
       |> nomear(nomes)
       |> Map.put(
         :newer_collection,
         coleta_mais_nova(tenant, organizacao.id, leitura.computed_at)
       )}
    end
  end

  # A janela é o inteiro ou o texto decimal EXATO de um valor da lista. "090", "90; drop",
  # "36500", "-1", "abc" e nil são recusados, e nada vira átomo (A8).
  defp janela(dias, permitidas) when is_integer(dias) do
    if dias in permitidas, do: {:ok, dias}, else: {:error, :janela_invalida}
  end

  defp janela(texto, permitidas) when is_binary(texto) do
    case Enum.find(permitidas, &(Integer.to_string(&1) == texto)) do
      nil -> {:error, :janela_invalida}
      dias -> {:ok, dias}
    end
  end

  defp janela(_outro, _permitidas), do: {:error, :janela_invalida}

  defp vigente(tenant, organization_id, dias) do
    case Queries.current(tenant, organization_id, dias) do
      nil -> {:ausente, :nao_calculada}
      leitura -> {:ok, leitura}
    end
  end

  defp ids_nomeados(visao) do
    visao.people
    |> Enum.flat_map(fn p ->
      [p.person_id | Enum.map(p.reviews_of ++ p.reviewed_by, & &1.person_id)]
    end)
    |> Enum.uniq()
  end

  # Pessoa sem nome em EO (id que não é do tenant, ou apagada depois do cálculo) sai da visão: o
  # nome é a defesa em profundidade de R3, item 3, e um id de outro tenant nunca vira linha.
  defp nomear(visao, nomes) do
    pessoas =
      Enum.flat_map(visao.people, fn p ->
        case Map.fetch(nomes, p.person_id) do
          {:ok, nome} ->
            [
              Map.merge(p, %{
                name: nome,
                reviews_of: com_nome(p.reviews_of, nomes),
                reviewed_by: com_nome(p.reviewed_by, nomes)
              })
            ]

          :error ->
            []
        end
      end)

    %{visao | people: Enum.sort_by(pessoas, &{String.downcase(&1.name), &1.person_id})}
  end

  defp com_nome(pares, nomes) do
    pares
    |> Enum.flat_map(fn par ->
      case Map.fetch(nomes, par.person_id) do
        {:ok, nome} -> [Map.put(par, :name, nome)]
        :error -> []
      end
    end)
    |> Enum.sort_by(&{String.downcase(&1.name), &1.person_id})
  end

  # Q3: o corte da coleta de mudanças mais recente da organização (`changes_collected_at`, o início
  # da passada, gravado ao fim dela) contra o instante do cálculo. Erra para o lado de não avisar
  # (research.md R14).
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
end
