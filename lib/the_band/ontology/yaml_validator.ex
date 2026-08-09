defmodule TheBand.Ontology.YamlValidator do
  @moduledoc """
  Verificações de integridade sobre os artefatos já lidos.

  Não substitui o validador completo em `scripts/validate_knowledge_base.py`,
  que confere os artefatos contra os JSON Schemas. Aqui ficam as verificações que
  o carregador de boot precisa fazer de qualquer forma, e que por isso são de
  graça: proveniência presente, identificadores únicos, mapeamento apontando para
  ontologia conhecida, e nenhum segredo no YAML.

  A dívida está declarada em `specs/001-github-eo-ingestion/plan.md`,
  Complexity Tracking.
  """

  alias TheBand.Ontology.YamlLoader

  @secret_markers ~w(ghp_ github_pat_ gho_ xoxb- -----BEGIN)

  @doc """
  Valida a lista de artefatos. Devolve `:ok` ou `{:error, problemas}`.
  """
  @spec validate([YamlLoader.artifact()]) :: :ok | {:error, [String.t()]}
  def validate(artifacts) do
    problems =
      Enum.concat([
        duplicate_ids(artifacts),
        missing_provenance(artifacts),
        secrets(artifacts)
      ])

    case problems do
      [] -> :ok
      _ -> {:error, problems}
    end
  end

  @doc """
  Verifica a direção de dependência entre ontologias: do específico para o geral.

  `EO → SRO`, `SPO → CIRO` e `SysSwO → CDRO` são proibidas (AGENTS.md §6,
  constituição princípio I).
  """
  @spec dependency_problems([YamlLoader.artifact()]) :: [String.t()]
  def dependency_problems(artifacts) do
    layer = %{
      "ufo" => 0,
      "eo" => 1,
      "spo" => 1,
      "sys_swo" => 1,
      "rsro" => 2,
      "cmpo" => 2,
      "roost" => 2,
      "qapo" => 2,
      "osdef" => 2,
      "sro" => 3,
      "ciro" => 3,
      "cdro" => 4
    }

    artifacts
    |> Enum.filter(&(&1.kind == :module))
    |> Enum.flat_map(fn artifact ->
      owner = get_in(artifact.data, ["module", "ontology"])
      owner_rank = Map.get(layer, owner)

      artifact
      |> referenced_ontologies()
      |> Enum.filter(fn ref ->
        rank = Map.get(layer, ref)
        owner_rank && rank && ref != owner && rank > owner_rank
      end)
      |> Enum.map(fn ref ->
        "#{artifact.path}: #{owner} referencia #{ref}, que é mais específica — " <>
          "a dependência vai do específico para o geral"
      end)
    end)
  end

  defp referenced_ontologies(artifact) do
    artifact.data
    |> collect_ids()
    |> Enum.map(&(&1 |> String.split(".") |> List.first()))
    |> Enum.uniq()
  end

  defp collect_ids(value) when is_map(value) do
    Enum.flat_map(value, fn {_k, v} -> collect_ids(v) end)
  end

  defp collect_ids(value) when is_list(value), do: Enum.flat_map(value, &collect_ids/1)

  defp collect_ids(value) when is_binary(value) do
    if Regex.match?(~r/^[a-z_]+\.[a-z0-9_]+$/, value), do: [value], else: []
  end

  defp collect_ids(_), do: []

  defp duplicate_ids(artifacts) do
    artifacts
    |> Enum.reject(&(&1.kind in [:unknown, :knowledge_base]))
    |> Enum.group_by(& &1.id)
    |> Enum.filter(fn {_id, list} -> length(list) > 1 end)
    |> Enum.map(fn {id, list} ->
      "identificador duplicado #{id} em: " <> Enum.map_join(list, ", ", & &1.path)
    end)
  end

  # A proveniência tem duas formas na base, e confundi-las produz erro falso.
  #
  # Em medida, necessidade de informação e regra de derivação ela responde "de
  # onde veio esta declaração" — daí `source_type`. Em mapeamento ela responde
  # "o que precisa ser preservado do dado ingerido" — daí `preserve_raw_payload`
  # e `required_fields`, que é o que sustenta FR-011 e FR-012.
  defp missing_provenance(artifacts), do: Enum.flat_map(artifacts, &provenance_problems/1)

  defp provenance_problems(%{kind: :mapping, payload: payload, path: path}) do
    case payload do
      %{"provenance" => %{"required_fields" => fields}} when is_list(fields) ->
        missing_reference_fields(path, fields)

      _ ->
        ["#{path}: mapeamento sem provenance.required_fields"]
    end
  end

  defp provenance_problems(%{kind: kind, payload: payload, path: path})
       when kind in [:measurement, :information_need, :derivation_rule] do
    case payload do
      %{"provenance" => %{"source_type" => type}} when is_binary(type) -> []
      _ -> ["#{path}: proveniência ausente ou sem source_type"]
    end
  end

  defp provenance_problems(_artifact), do: []

  defp missing_reference_fields(path, fields) do
    case ~w(source_system source_instance external_id collected_at) -- fields do
      [] -> []
      faltando -> ["#{path}: proveniência sem #{Enum.join(faltando, ", ")}"]
    end
  end

  defp secrets(artifacts) do
    Enum.flat_map(artifacts, fn artifact ->
      raw = inspect(artifact.data, limit: :infinity, printable_limit: :infinity)

      @secret_markers
      |> Enum.filter(&String.contains?(raw, &1))
      |> Enum.map(&"#{artifact.path}: possível segredo no YAML (marcador #{&1})")
    end)
  end
end
