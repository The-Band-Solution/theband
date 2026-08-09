defmodule TheBand.SemanticIntegration.Mapper do
  @moduledoc """
  Aplica os mapeamentos semânticos declarados na base de conhecimento (FR-013).

  A conversão de payload externo em atributos de conceito não vive em código de
  coleta: vem de `priv/knowledge_base/mappings/`, lido no boot. Corrigir um
  mapeamento é editar YAML e reprocessar — não recompilar.

  O que o mapeamento fornece e este módulo usa:

    * `identity.external_id_path` — onde está o identificador na origem;
    * `attributes.<nome>.source_path` — de onde vem cada atributo;
    * `relations.<nome>.source_path` — de onde vem cada referência.

  O que ele **não** faz: inventar campo que o mapeamento não declara. Atributo
  ausente fica ausente, e a limitação já está escrita no próprio YAML.
  """

  alias TheBand.Ontology.KnowledgeBase

  @doc """
  Transforma um nó de payload nos atributos do conceito alvo.

  Devolve `{:ok, attrs}` ou `{:error, motivo}`. O motivo entra no relatório de
  ignorados (FR-028) — nunca é engolido.
  """
  @spec apply_mapping(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def apply_mapping(mapping_id, node) when is_map(node) do
    case KnowledgeBase.mapping(mapping_id) do
      {:ok, mapping} -> {:ok, build(mapping, node)}
      :error -> {:error, "mapeamento #{mapping_id} não existe na base de conhecimento"}
    end
  end

  @doc "Identificador da entidade na origem, conforme `identity.external_id_path`."
  @spec external_id(String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def external_id(mapping_id, node) do
    with {:ok, mapping} <- fetch(mapping_id) do
      case dig(node, get_in(mapping, ["identity", "external_id_path"])) do
        nil -> {:error, "#{mapping_id}: identificador de origem ausente no payload"}
        value -> {:ok, to_string(value)}
      end
    end
  end

  @doc "Conceito alvo declarado no mapeamento — usado para rotear a escrita."
  @spec target_concept(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def target_concept(mapping_id) do
    with {:ok, mapping} <- fetch(mapping_id) do
      case get_in(mapping, ["target", "concept"]) do
        nil -> {:error, "#{mapping_id}: sem target.concept"}
        concept -> {:ok, concept}
      end
    end
  end

  @doc "Versão do mapeamento, gravada junto do payload bruto para sustentar FR-017."
  @spec version(String.t()) :: integer() | nil
  def version(mapping_id) do
    case fetch(mapping_id) do
      {:ok, mapping} -> mapping["version"]
      _ -> nil
    end
  end

  @doc """
  Limitações declaradas no mapeamento.

  Existem para serem lidas, não decoradas: são o que a interface e a
  documentação usam para dizer o que o dado **não** significa.
  """
  @spec limitations(String.t()) :: [String.t()]
  def limitations(mapping_id) do
    case fetch(mapping_id) do
      {:ok, mapping} -> Map.get(mapping, "limitations", [])
      _ -> []
    end
  end

  defp fetch(mapping_id) do
    case KnowledgeBase.mapping(mapping_id) do
      {:ok, mapping} -> {:ok, mapping}
      :error -> {:error, "mapeamento #{mapping_id} não existe na base de conhecimento"}
    end
  end

  defp build(mapping, node) do
    attrs =
      mapping
      |> Map.get("attributes", %{})
      |> Enum.reduce(%{}, fn {name, spec}, acc ->
        case dig(node, spec["source_path"]) do
          nil -> acc
          value -> Map.put(acc, String.to_atom(name), value)
        end
      end)

    relations =
      mapping
      |> Map.get("relations", %{})
      |> Enum.reduce(%{}, fn {name, spec}, acc ->
        case dig(node, spec["source_path"]) do
          nil -> acc
          value -> Map.put(acc, String.to_atom(name <> "_external_id"), value)
        end
      end)

    Map.merge(attrs, relations)
  end

  # Caminho pontuado sobre o payload: "node.login", "organization.teams.nodes.id".
  # Segmento que não existe devolve nil — ausência de campo opcional é comum na
  # origem (e-mail costuma ser nulo por privacidade) e não é erro.
  defp dig(_node, nil), do: nil

  defp dig(node, path) when is_binary(path) do
    path
    |> String.split(".")
    |> Enum.reduce(node, fn
      _segment, nil -> nil
      segment, acc when is_map(acc) -> Map.get(acc, segment)
      _segment, _acc -> nil
    end)
  end
end
