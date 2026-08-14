defmodule TheBand.Ontology.SchemaCheck do
  @moduledoc """
  Confere cada artefato contra o JSON Schema do seu tipo.

  Sem isto, um campo inventado entra na base sem ninguém notar — e a base deixa de ser um
  contrato para virar convenção oral.

  ## Por que um verificador próprio, e não uma biblioteca

  Princípio VIII: o problema é concreto e existe agora — esta era a única das treze
  verificações que só o Python fazia, e depender do Python significa que o dia em que o
  `.venv` falhar o gate passa medindo menos (L23).

  A alternativa era uma dependência de JSON Schema. Ela custaria mais do que resolve: as
  bibliotecas de Elixir param no draft 7, e os schemas da base declaram 2020-12 — a
  divergência apareceria como aprovação, que é o pior modo de falhar. **Os 625 linhas de
  schema usam oito construtos**: `type`, `properties`, `required`, `additionalProperties`,
  `enum`, `pattern`, `minItems`, `anyOf`, mais `$ref` para `common`. É esse subconjunto que
  este módulo implementa.

  O custo está declarado: um construto novo num schema **não** é verificado aqui até ser
  implementado, e por isso `construto_nao_suportado/2` reprova em vez de ignorar. Schema que
  usa o que este módulo não entende falha alto, e não em silêncio.
  """

  # A chave raiz do documento decide o schema. `ontology.yaml` e os arquivos de perguntas de
  # competência têm ambos a chave `ontology` — no primeiro ela é um mapa, no segundo é o id da
  # ontologia a que as perguntas pertencem.
  @por_chave_raiz [
    {"ontology", "ontology"},
    {"module", "module"},
    {"mapping", "mapping"},
    {"information_need", "information-need"},
    {"measurement", "measurement"},
    {"competency_questions", "competency-question"}
  ]

  # Anotações — `$comment`, `title`, `description`, `default` — descrevem, e não restringem.
  # Estão na lista porque a ausência delas aqui viraria reprovação de schema válido.
  @suportados ~w($schema $id $comment title description default type properties required
                 additionalProperties enum pattern minItems minimum anyOf items $ref $defs)

  @doc """
  Devolve a lista de problemas de forma. Lista vazia significa que todos os artefatos com
  schema correspondente estão conformes.
  """
  @spec problems([map()]) :: [String.t()]
  def problems(artifacts) do
    schemas = schemas(artifacts)
    defs = get_in(schemas, ["common", "$defs"]) || %{}

    case schemas do
      mapa when map_size(mapa) == 0 ->
        # Nenhum schema carregado é ausência de verificação, e ausência de verificação não
        # pode passar por aprovação.
        ["nenhum JSON Schema foi carregado — a verificação de forma não rodou"]

      _ ->
        Enum.flat_map(artifacts, &problemas_do_artefato(&1, schemas, defs))
    end
  end

  defp schemas(artifacts) do
    for artifact <- artifacts,
        [_, nome] <- [Regex.run(~r{schemas/([a-z-]+)\.schema\.yaml$}, artifact.path)],
        into: %{},
        do: {nome, artifact.data}
  end

  defp problemas_do_artefato(artifact, schemas, defs) do
    with {:ok, nome} <- schema_de(artifact.data),
         %{} = schema <- Map.get(schemas, nome) do
      artifact.data
      |> validar(schema, "(raiz)", defs)
      |> Enum.map(&"#{artifact.path}: #{nome}: #{&1}")
    else
      _ -> []
    end
  end

  defp schema_de(data) when is_map(data) do
    Enum.find_value(@por_chave_raiz, :nenhum, fn {chave, nome} ->
      cond do
        not Map.has_key?(data, chave) -> nil
        chave == "ontology" and not is_map(data[chave]) -> nil
        true -> {:ok, nome}
      end
    end)
  end

  defp schema_de(_), do: :nenhum

  # ------------------------------------------------------------------ validação

  defp validar(valor, %{"$ref" => ref} = schema, caminho, defs) do
    case resolver(ref, defs) do
      nil -> ["#{caminho}: $ref #{ref} não resolve"]
      alvo -> validar(valor, Map.merge(Map.delete(schema, "$ref"), alvo), caminho, defs)
    end
  end

  defp validar(valor, schema, caminho, defs) when is_map(schema) do
    construto_nao_suportado(schema, caminho) ++
      Enum.flat_map(schema, fn {palavra, regra} ->
        aplicar(palavra, regra, valor, schema, caminho, defs)
      end)
  end

  defp validar(_valor, _schema, _caminho, _defs), do: []

  defp aplicar("type", tipo, valor, _schema, caminho, _defs) do
    if tipo?(valor, tipo), do: [], else: ["#{caminho}: esperava #{tipo}, veio #{tipo_de(valor)}"]
  end

  defp aplicar("required", campos, valor, _schema, caminho, _defs) when is_map(valor) do
    campos
    |> List.wrap()
    |> Enum.reject(&Map.has_key?(valor, &1))
    |> Enum.map(&"#{caminho}: campo obrigatório #{&1} ausente")
  end

  defp aplicar("properties", propriedades, valor, _schema, caminho, defs) when is_map(valor) do
    Enum.flat_map(propriedades, fn {nome, sub} ->
      case Map.fetch(valor, nome) do
        {:ok, v} -> validar(v, sub, junta(caminho, nome), defs)
        :error -> []
      end
    end)
  end

  defp aplicar("additionalProperties", false, valor, schema, caminho, _defs) when is_map(valor) do
    declaradas = Map.keys(schema["properties"] || %{})

    valor
    |> Map.keys()
    |> Kernel.--(declaradas)
    |> Enum.map(&"#{caminho}: campo #{&1} não está declarado no schema")
  end

  defp aplicar("enum", valores, valor, _schema, caminho, _defs) do
    if is_nil(valor) or valor in valores,
      do: [],
      else: ["#{caminho}: #{inspect(valor)} fora de #{inspect(valores)}"]
  end

  defp aplicar("pattern", padrao, valor, _schema, caminho, _defs) when is_binary(valor) do
    case Regex.compile(padrao) do
      {:ok, regex} ->
        if Regex.match?(regex, valor),
          do: [],
          else: ["#{caminho}: #{inspect(valor)} não casa com #{padrao}"]

      {:error, _} ->
        ["#{caminho}: padrão inválido no schema: #{padrao}"]
    end
  end

  defp aplicar("minItems", minimo, valor, _schema, caminho, _defs) when is_list(valor) do
    if length(valor) >= minimo,
      do: [],
      else: ["#{caminho}: precisa de ao menos #{minimo} item(ns), veio #{length(valor)}"]
  end

  defp aplicar("minimum", minimo, valor, _schema, caminho, _defs) when is_number(valor) do
    if valor >= minimo, do: [], else: ["#{caminho}: #{valor} é menor que o mínimo #{minimo}"]
  end

  defp aplicar("items", sub, valor, _schema, caminho, defs) when is_list(valor) do
    valor
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, i} -> validar(item, sub, junta(caminho, i), defs) end)
  end

  defp aplicar("anyOf", alternativas, valor, _schema, caminho, defs) do
    # Basta uma alternativa aceitar. Relatar o erro de todas confundiria mais do que ajuda:
    # a mensagem diz que nenhuma serviu, que é o fato.
    if Enum.any?(alternativas, &(validar(valor, &1, caminho, defs) == [])),
      do: [],
      else: ["#{caminho}: não satisfaz nenhuma das #{length(alternativas)} formas aceitas"]
  end

  defp aplicar(_palavra, _regra, _valor, _schema, _caminho, _defs), do: []

  defp construto_nao_suportado(schema, caminho) do
    schema
    |> Map.keys()
    |> Enum.reject(&(&1 in @suportados))
    |> Enum.map(&"#{caminho}: construto #{&1} não é verificado por este validador")
  end

  defp resolver("the-band/schemas/common#/$defs/" <> nome, defs), do: Map.get(defs, nome)
  defp resolver(_, _), do: nil

  defp junta("(raiz)", parte), do: "#{parte}"
  defp junta(caminho, parte), do: "#{caminho}.#{parte}"

  defp tipo?(nil, _tipo), do: true
  defp tipo?(valor, "object"), do: is_map(valor)
  defp tipo?(valor, "array"), do: is_list(valor)
  defp tipo?(valor, "string"), do: is_binary(valor)
  defp tipo?(valor, "boolean"), do: is_boolean(valor)
  defp tipo?(valor, "integer"), do: is_integer(valor)
  defp tipo?(valor, "number"), do: is_number(valor)
  defp tipo?(valor, tipos) when is_list(tipos), do: Enum.any?(tipos, &tipo?(valor, &1))
  defp tipo?(_valor, _tipo), do: true

  defp tipo_de(valor) when is_map(valor), do: "object"
  defp tipo_de(valor) when is_list(valor), do: "array"
  defp tipo_de(valor) when is_binary(valor), do: "string"
  defp tipo_de(valor) when is_boolean(valor), do: "boolean"
  defp tipo_de(valor) when is_integer(valor), do: "integer"
  defp tipo_de(valor) when is_number(valor), do: "number"
  defp tipo_de(_), do: "desconhecido"
end
