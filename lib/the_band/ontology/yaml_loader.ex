defmodule TheBand.Ontology.YamlLoader do
  @moduledoc """
  Lê a base de conhecimento em `priv/knowledge_base/`.

  Usa `yaml_elixir`, que é Erlang puro. A escolha está registrada em
  research.md R2: um NIF com falha de segmentação derrubaria a máquina virtual
  inteira, e a base é lida na inicialização — um YAML malformado passaria de erro
  tratável a indisponibilidade do sistema.
  """

  @type artifact :: %{
          kind: atom(),
          id: String.t(),
          path: String.t(),
          data: map(),
          payload: map()
        }

  @doc "Diretório raiz da base de conhecimento, resolvido a partir da configuração."
  @spec root() :: String.t()
  def root do
    :the_band
    |> Application.get_env(TheBand.Ontology.KnowledgeBase, [])
    |> Keyword.get(:path, "priv/knowledge_base")
    |> Path.expand(File.cwd!())
  end

  @doc """
  Carrega todos os artefatos da base.

  Devolve `{:ok, artifacts}` ou `{:error, reasons}` — nunca uma carga parcial
  silenciosa. Base inválida não pode gerar aplicação funcionando com o modelo
  pela metade (research.md R4).
  """
  @spec load_all(String.t()) :: {:ok, [artifact()]} | {:error, [String.t()]}
  def load_all(root \\ root()) do
    files = Path.wildcard(Path.join(root, "**/*.yaml"))

    {artifacts, errors} =
      Enum.reduce(files, {[], []}, fn file, {ok, bad} ->
        case load_file(file, root) do
          {:ok, artifact} -> {[artifact | ok], bad}
          {:error, reason} -> {ok, [reason | bad]}
        end
      end)

    case errors do
      [] -> {:ok, Enum.reverse(artifacts)}
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  @spec load_file(String.t(), String.t()) :: {:ok, artifact()} | {:error, String.t()}
  def load_file(path, root \\ root()) do
    relative = Path.relative_to(path, root)

    case YamlElixir.read_from_file(path) do
      {:ok, data} when is_map(data) ->
        {kind, id} = classify(data, relative)
        {:ok, %{kind: kind, id: id, path: relative, data: data, payload: payload(data, kind)}}

      {:ok, other} ->
        {:error, "#{relative}: raiz do YAML não é um mapa, e sim #{inspect(other)}"}

      # YamlElixir devolve sempre uma exceção no ramo de erro; uma cláusula
      # genérica depois desta seria código morto.
      {:error, error} ->
        {:error, "#{relative}: #{Exception.message(error)}"}
    end
  end

  @doc """
  Achata o artefato num mapa só.

  Os arquivos da base não têm uma forma única: em `measurement` e
  `information_need` tudo vive aninhado sob a chave do tipo, enquanto em
  `mapping` e `module` os campos são **irmãos** dela — `source`, `target`,
  `provenance` e `concepts` ficam no topo. Ler qualquer um dos dois formatos
  como se fosse o outro devolve campo ausente onde ele existe.
  """
  @spec payload(map(), atom()) :: map()
  def payload(data, kind) do
    top = Atom.to_string(kind)

    case Map.get(data, top) do
      nested when is_map(nested) -> Map.merge(Map.delete(data, top), nested)
      _ -> data
    end
  end

  # A chave de topo nomeia o tipo do artefato: `mapping:`, `derivation_rule:`,
  # `measurement:`, `information_need:`, `module:`, `ontology:`, `manifest`...
  defp classify(data, relative) do
    case Map.keys(data) do
      [top] when is_binary(top) ->
        {kind_from(top), id_from(data[top], relative)}

      keys ->
        top = Enum.find(keys, &(&1 in known_tops())) || "unknown"
        {kind_from(top), id_from(data[top], relative)}
    end
  end

  defp known_tops do
    ~w(mapping derivation_rule measurement information_need module ontology
       knowledge_base transformation competency_questions)
  end

  defp kind_from(top) when is_binary(top), do: String.to_atom(top)
  defp kind_from(_), do: :unknown

  defp id_from(%{"id" => id}, _relative) when is_binary(id), do: id
  defp id_from(_, relative), do: relative
end
