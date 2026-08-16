defmodule TheBand.Ontology.KnowledgeBase do
  @moduledoc """
  Carrega a base de conhecimento no boot, para ETS de leitura concorrente.

  Decisão em research.md R4. As alternativas descartadas: compile time exigiria
  recompilar a cada alteração de YAML, e a base é revisada por quem não compila
  o projeto; leitura por requisição é desperdício, já que a base muda em deploy e
  não em runtime.

  **Falha no carregamento é falha de boot.** Base inválida não pode gerar
  aplicação funcionando com o modelo pela metade.
  """

  use GenServer

  require Logger

  alias TheBand.Ontology.YamlLoader
  alias TheBand.Ontology.YamlValidator

  @table :the_band_knowledge_base
  @index :the_band_knowledge_base_index

  # ---------------------------------------------------------------- API pública

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Devolve o mapeamento pelo identificador declarado no YAML."
  @spec mapping(String.t()) :: {:ok, map()} | :error
  def mapping(id), do: fetch(:mapping, id)

  @doc "Devolve a regra de derivação pelo identificador."
  @spec rule(String.t()) :: {:ok, map()} | :error
  def rule(id), do: fetch(:derivation_rule, id)

  @doc """
  Os axiomas da rede, um a um — issue #320.

  `list(:axiom)` devolve **arquivos**, e cada arquivo carrega sete axiomas dentro de `rules`.
  Quem pergunta pelos axiomas quer os axiomas, e não os dois arquivos que os contêm — por isso
  esta função achata.

  Sem ela, a `sro.rule07` só existia **escrita no código**: a semântica vivia no YAML e ninguém
  conseguia perguntar a ela, que é o princípio IV cumprido pela metade.
  """
  @spec axioms() :: [map()]
  def axioms do
    :axiom
    |> list()
    |> Enum.flat_map(fn payload -> Map.get(payload, "rules", []) end)
  end

  @doc """
  Um axioma pelo identificador declarado — `"sro.rule07..."`.

  Devolve `:error` quando não existe, como as demais consultas por identificador. Casar por
  prefixo seria conveniente e erraria: `sro.rule01` e `sro.rule01x` são identificadores
  diferentes, e o prefixo devolveria o primeiro que aparecesse.
  """
  @spec axiom(String.t()) :: {:ok, map()} | :error
  def axiom(id) do
    case Enum.find(axioms(), &(Map.get(&1, "id") == id)) do
      nil -> :error
      axioma -> {:ok, axioma}
    end
  end

  @doc "Lista os artefatos de um tipo — `:mapping`, `:derivation_rule`, `:measurement`..."
  @spec list(atom()) :: [map()]
  def list(kind) do
    case :ets.lookup(@index, kind) do
      [{^kind, ids}] -> Enum.flat_map(ids, &fetch_into_list(kind, &1))
      [] -> []
    end
  end

  defp fetch_into_list(kind, id) do
    case fetch(kind, id) do
      {:ok, data} -> [data]
      :error -> []
    end
  end

  @doc """
  Os identificadores de todos os conceitos da rede — 220 na base atual.

  Existe para o comando que grava regra de mapeamento poder recusar conceito que não
  existe. Sem esta consulta, a validação seria uma lista fixa no código, e ela divergiria
  da base no primeiro conceito novo — a semântica vive no YAML (princípio IV), e quem
  pergunta "este conceito existe?" tem de perguntar a ela.

  Os conceitos vivem nos artefatos de **módulo**, e não de ontologia: a ontologia declara
  os módulos, e o módulo declara os conceitos.
  """
  @spec concept_ids() :: MapSet.t(String.t())
  def concept_ids do
    :module
    |> list()
    |> Enum.flat_map(fn modulo -> modulo["concepts"] || [] end)
    |> MapSet.new(& &1["id"])
  end

  @doc "Se o identificador de conceito existe na base carregada."
  @spec concept?(String.t() | nil) :: boolean()
  def concept?(nil), do: false
  def concept?(id), do: MapSet.member?(concept_ids(), id)

  @doc "Contagem por tipo de artefato, para diagnóstico e para a Mix task."
  @spec stats() :: %{atom() => non_neg_integer()}
  def stats do
    @index
    |> :ets.tab2list()
    |> Map.new(fn {kind, ids} -> {kind, length(ids)} end)
  end

  defp fetch(kind, id) do
    case :ets.lookup(@table, {kind, id}) do
      [{{^kind, ^id}, data}] -> {:ok, data}
      [] -> :error
    end
  end

  # ------------------------------------------------------------------- GenServer

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :protected, read_concurrency: true])
    :ets.new(@index, [:named_table, :set, :protected, read_concurrency: true])

    case load() do
      {:ok, artifacts} ->
        publish(artifacts)
        Logger.info("base de conhecimento carregada: #{length(artifacts)} artefatos")
        {:ok, %{count: length(artifacts)}}

      {:error, problems} ->
        # Não há degradação graciosa possível aqui: seguir com a base pela metade
        # produziria transformação semântica silenciosamente errada.
        {:stop, {:invalid_knowledge_base, problems}}
    end
  end

  @doc """
  Lê e valida a base, sem publicar em ETS.

  A separação existe para que `mix knowledge.validate` possa rodar sem o
  supervisor no ar — a Mix task valida, a `init/1` valida e publica.
  """
  @spec load(String.t()) :: {:ok, [YamlLoader.artifact()]} | {:error, [String.t()]}
  def load(root \\ YamlLoader.root()) do
    with {:ok, artifacts} <- YamlLoader.load_all(root),
         :ok <- YamlValidator.validate(artifacts) do
      {:ok, artifacts}
    end
  end

  defp publish(artifacts) do
    Enum.each(artifacts, fn artifact ->
      :ets.insert(@table, {{artifact.kind, artifact.id}, artifact.payload})
    end)

    artifacts
    |> Enum.group_by(& &1.kind, & &1.id)
    |> Enum.each(fn {kind, ids} -> :ets.insert(@index, {kind, ids}) end)
  end
end
