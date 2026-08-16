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

      _keys ->
        # Duas chaves conhecidas no mesmo arquivo: vence a que **contém**, e conter é ter um
        # mapa por valor. `cdro`, `ciro` e `sro` declaram `competency_questions:` dentro do
        # próprio `ontology.yaml` — a ordem das chaves decidia o tipo, e as três viravam
        # `unknown`, sumindo de todo filtro por `:ontology`. Eram 3 das 12 ontologias da base.
        #
        # O critério é o valor, não o nome: o arquivo de perguntas de competência também tem
        # `ontology:`, só que apontando (`ontology: ciro`), e classificá-lo como ontologia
        # inventaria uma décima terceira. Conteúdo é mapa ou lista; texto é ponteiro.
        top = Enum.find(known_tops(), &conteudo?(data[&1])) || "unknown"
        {kind_from(top), id_from(data[top], relative)}
    end
  end

  # O conjunto de tipos, em ordem de precedência: o que **contém** vem antes do que é contido.
  # `ontology` e `module` têm campos irmãos da chave de topo, e alguns desses irmãos são tipos
  # por direito próprio.
  #
  # A tabela é literal, e não `String.to_existing_atom`. O objetivo de `to_existing_atom` era
  # certo — texto de arquivo não pode criar átomo — mas o efeito era pior do que o problema:
  # a existência do átomo dependia de **qual módulo já tinha sido carregado**. Antes de
  # `app.config`, `:ontology` não existia ainda, as 12 ontologias viravam `unknown`, o mapa de
  # dependências saía vazio e a validação reprovava a base com 124 problemas inventados. Depois
  # de `app.config`, a mesma base passava. Átomo literal existe assim que o módulo carrega, e o
  # resultado deixa de depender da ordem de carga.
  @tops [
    {"ontology", :ontology},
    {"module", :module},
    {"mapping", :mapping},
    {"derivation_rule", :derivation_rule},
    {"measurement", :measurement},
    {"information_need", :information_need},
    {"knowledge_base", :knowledge_base},
    {"transformation", :transformation},
    {"competency_questions", :competency_questions},
    # Os três tipos que a issue #365 tirou de `:unknown`. O AGENTS §8 já os listava entre
    # o que a base representa; a base os tinha, e o carregador não os enxergava — a mesma
    # forma da #320, nos vizinhos dela. `source` é a capacidade declarada de uma fonte
    # externa; `glossary` e `examples` são leitura humana que agora responde a consulta.
    {"source", :source},
    {"glossary", :glossary},
    {"examples", :examples},
    # **Axioma não é regra de derivação, e por isso tem tipo próprio** — issue #320.
    #
    # Os dois vivem sob `priv/knowledge_base/rules/`, e a semelhança do diretório escondeu a
    # diferença: um axioma vem da tese e diz o que a rede **afirma ser verdade**; uma regra de
    # derivação é decisão da plataforma sobre como derivar um valor. Classificá-los juntos
    # faria `list(:derivation_rule)` devolver as duas coisas, e quem perguntasse "quais regras
    # a plataforma decidiu" receberia sete axiomas da tese junto.
    #
    # Antes disto, `rules:` não era nenhum dos tipos conhecidos: os sete axiomas da SRO e os
    # da SPO caíam em `:unknown`, passavam na validação, e **nenhuma consulta por tipo os
    # alcançava**. É o inverso da L57 — lá uma verificação filtrava um tipo que ninguém
    # produzia; aqui um tipo era produzido e ninguém conseguia filtrá-lo.
    {"rules", :axiom}
  ]

  defp known_tops, do: Enum.map(@tops, &elem(&1, 0))

  defp conteudo?(valor), do: is_map(valor) or (is_list(valor) and valor != [])

  defp kind_from(top) when is_binary(top) do
    case List.keyfind(@tops, top, 0) do
      {_, kind} -> kind
      nil -> :unknown
    end
  end

  defp kind_from(_), do: :unknown

  defp id_from(%{"id" => id}, _relative) when is_binary(id), do: id
  defp id_from(_, relative), do: relative
end
