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

  @doc """
  Completa os atributos com o que o mapeamento não declara — e não deveria.

  Dois complementos, ambos derivados do payload e nenhum deles atributo do
  conceito:

    * **nome a partir do login.** Conta sem nome preenchido é registrada mesmo
      assim, identificada pelo login. Não é atributo novo: é a mesma propriedade
      `name`, com a origem de segunda escolha declarada aqui em vez de escondida
      num `||` no meio da ingestão;
    * **tipo de conta.** Vem de `__typename`, que é metadado do GraphQL, não campo
      do usuário. Declará-lo no mapeamento faria parecer que a origem tem um
      atributo "é bot", e ela não tem.

  Vive aqui, e não em cada chamador, porque coleta e reprocessamento precisam
  produzir **exatamente** os mesmos atributos a partir do mesmo payload. Duas
  cópias divergiriam, e a divergência apareceria como registro "atualizado" num
  reprocessamento que não deveria mudar nada.
  """
  @spec complete(map(), String.t(), map()) :: map()
  def complete(attrs, "github.organization", node) do
    attrs
    |> Map.put(:login, node["login"])
    |> Map.put_new(:name, node["login"])
  end

  def complete(attrs, "github.team", node) do
    attrs
    |> Map.put(:type, "organizational_team")
    |> Map.put_new(:name, node["name"] || node["slug"])
    |> Map.put(:slug, node["slug"])
    |> Map.put(:external_created_at, parse_datetime(node["createdAt"]))
  end

  def complete(attrs, _person_like, node) do
    attrs
    |> Map.put(:login, node["login"])
    |> Map.put(:name, node["name"] || node["login"])
    |> Map.put(:account_type, account_type(node))
  end

  # O nome do atributo vem do YAML de mapeamento e vira chave de changeset — ou seja, campo de
  # schema, definido em **compilação**. `to_existing_atom` aproveita isso duas vezes: fecha a
  # porta para exaustão de átomos, e faz um `source_path` com nome errado falhar em vez de
  # produzir uma chave que nenhum changeset aceita e que some no `cast`.
  defp atomo_de_campo(nome) do
    String.to_existing_atom(nome)
  rescue
    ArgumentError ->
      # `reraise`, e não `raise`: preserva a pilha original, que é o que diz **qual mapeamento**
      # estava sendo aplicado quando o nome não existia.
      reraise ArgumentError.exception(
                "o mapeamento declara o atributo \"#{nome}\", que não existe em nenhum schema"
              ),
              __STACKTRACE__
  end

  @doc "Classifica a conta a partir do `__typename` e do sufixo do login."
  @spec account_type(map()) :: String.t()
  def account_type(%{"__typename" => "Bot"}), do: "bot"
  def account_type(%{"__typename" => "App"}), do: "app"

  def account_type(%{"login" => login}) when is_binary(login) do
    if String.ends_with?(login, "[bot]"), do: "bot", else: "person"
  end

  def account_type(_node), do: "person"

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> DateTime.truncate(datetime, :second)
      _ -> nil
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
          value -> Map.put(acc, atomo_de_campo(name), value)
        end
      end)

    relations =
      mapping
      |> Map.get("relations", %{})
      |> Enum.reduce(%{}, fn {name, spec}, acc ->
        case dig(node, spec["source_path"]) do
          nil -> acc
          value -> Map.put(acc, atomo_de_campo(name <> "_external_id"), value)
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
