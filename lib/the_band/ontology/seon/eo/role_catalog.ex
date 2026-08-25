defmodule TheBand.Ontology.SEON.EO.RoleCatalog do
  @moduledoc """
  Os papéis que a **rede** nomeia, compostos com os que a organização declarou — issue #317.

  ## O catálogo não é tabela

  Os quatro papéis do Scrum vêm da SRO — `sro.product_owner_role`, `sro.scrum_master_role`,
  `sro.developer_role` e `sro.client_role`, todos filhos de `sro.scrum_role`. Eles **não são
  linhas** até alguém usá-los.

  Semear criaria quatro linhas por organização que ninguém declarou, e o número cresceria com
  cada organização nova. Pior: se a SRO renomear um papel, as linhas semeadas **divergiriam da
  rede em silêncio** — e a rede é a fonte da verdade (princípio I).

  Compondo, um papel novo na SRO aparece em todas as organizações na leitura seguinte, sem
  migração. É a propriedade que justifica o custo.

  ## O custo, que vaza para quem chama

  **Papel do catálogo sem linha tem `id: nil`.** É deliberado: um identificador sintético faria
  a tela acreditar que a linha existe, e a promoção falharia com chave estrangeira inválida.

  Por isso `origem` é tupla marcada — `{:catalogo, "sro.scrum_master_role"}` ou
  `{:declarado, user_id}` — e nunca um booleano. O booleano perderia **qual** conceito da SRO
  originou o papel, e a `FR-003` exige a origem visível.

  ## Forma emprestada do `Mapping.Catalog`

  As regras de mapeamento já distinguem catálogo de declaração por um `catalog_key` nulável, e
  já compõem entradas de catálogo com linhas da organização. Reusar a forma é preferível a
  inventar outra: a casa já a provou, e quem conhece uma reconhece a outra.

  **O que não se reusa é o passo de ativação.** Lá a proposta muda dado — reclassifica issues —
  e ativar é decisão de peso. Aqui o papel só passa a existir na lista, e a `FR-002` diz "sem
  cadastro prévio": ativação seria cadastro prévio com outro nome.

  ## O que NUNCA entra no catálogo

  Nível de acesso da plataforma. `MAINTAINER` e `MEMBER` dizem quem pode gerir membros e
  permissões do time — não dizem se a pessoa é programadora, testadora, designer ou gerente.
  `EO.Constraints.platform_access_level_is_not_a_role/1` já os recusa desde a feature 021.
  """

  alias TheBand.Ontology.KnowledgeBase

  @tipo_pai "sro.scrum_role"

  @type entrada :: %{
          code: String.t(),
          name: String.t(),
          concept_id: String.t()
        }

  @doc """
  As entradas do catálogo — os filhos de `sro.scrum_role`, lidos da rede.

  O código é o **sufixo** do identificador: `sro.developer_role` vira `developer_role`. O
  prefixo é da ontologia, e o código pertence à organização que o usa.
  """
  @spec entries() :: [entrada()]
  def entries do
    :module
    |> KnowledgeBase.list()
    |> Enum.flat_map(&Map.get(&1, "concepts", []))
    |> Enum.filter(&filho_de_scrum_role?/1)
    |> Enum.map(fn conceito ->
      id = Map.get(conceito, "id")

      %{
        concept_id: id,
        code: id |> String.split(".") |> List.last(),
        name: Map.get(conceito, "name")
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  @doc "A entrada de um conceito, quando ele ainda é nomeado pela rede."
  @spec fetch_entry(String.t()) :: {:ok, entrada()} | {:error, :not_in_catalog}
  def fetch_entry(concept_id) do
    case Enum.find(entries(), &(&1.concept_id == concept_id)) do
      nil -> {:error, :not_in_catalog}
      entrada -> {:ok, entrada}
    end
  end

  @doc """
  Compõe as entradas do catálogo com as linhas já gravadas da organização.

  Devolve **uma entrada por papel do catálogo**, com `id` preenchido quando a linha existe e
  `nil` quando não. As linhas declaradas pela organização vêm depois, e as linhas cujo
  `catalog_concept_id` a rede **não nomeia mais** vêm marcadas — sumir em silêncio deixaria
  vínculos apontando para nada.
  """
  @spec compose([map()]) :: [map()]
  def compose(linhas) do
    por_conceito =
      Map.new(Enum.filter(linhas, & &1.catalog_concept_id), &{&1.catalog_concept_id, &1})

    do_catalogo =
      Enum.map(entries(), fn entrada ->
        linha = Map.get(por_conceito, entrada.concept_id)

        %{
          id: linha && linha.id,
          code: (linha && linha.code) || entrada.code,
          name: entrada.name,
          origem: {:catalogo, entrada.concept_id},
          hidden_at: linha && linha.hidden_at,
          no_catalogo: true
        }
      end)

    conceitos_vivos = MapSet.new(entries(), & &1.concept_id)

    declarados =
      linhas
      |> Enum.reject(
        &(&1.catalog_concept_id && MapSet.member?(conceitos_vivos, &1.catalog_concept_id))
      )
      |> Enum.map(fn linha ->
        %{
          id: linha.id,
          code: linha.code,
          name: linha.name,
          origem: origem_da_linha(linha),
          hidden_at: linha.hidden_at,
          # A linha cujo conceito a rede não nomeia mais. Os vínculos continuam válidos, e a
          # tela precisa poder dizer que ela saiu do catálogo.
          no_catalogo: false
        }
      end)

    do_catalogo ++ Enum.sort_by(declarados, & &1.name)
  end

  defp origem_da_linha(%{catalog_concept_id: conceito}) when is_binary(conceito),
    do: {:catalogo_removido, conceito}

  defp origem_da_linha(%{declared_by_user_id: autor}), do: {:declarado, autor}

  # Os quatro que herdam de `sro.scrum_role` — e não o próprio, que é o pai abstrato.
  defp filho_de_scrum_role?(conceito) do
    get_in(conceito, ["classification", "parent"]) == @tipo_pai
  end
end
