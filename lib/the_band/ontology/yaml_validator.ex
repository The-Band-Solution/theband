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

  alias TheBand.Ontology.SchemaCheck
  alias TheBand.Ontology.YamlLoader

  @secret_markers ~w(ghp_ github_pat_ gho_ xoxb- -----BEGIN)

  @doc """
  Valida a lista de artefatos. Devolve `:ok` ou `{:error, problemas}`.
  """
  @spec validate([YamlLoader.artifact()]) :: :ok | {:error, [String.t()]}
  def validate(artifacts) do
    indice = indexar(artifacts)

    problems =
      Enum.concat([
        duplicate_ids(artifacts),
        missing_provenance(artifacts),
        secrets(artifacts),
        # ---------------------------------------------------------------- #177
        # As verificações que só o Python fazia. A paridade existe porque **aviso de
        # verificação pulada é reprovação, não observação** — a L23: o validador Python
        # depende do `.venv`, e o dia em que a provisão falhar o gate passa medindo menos.
        ids_fora_do_padrao(indice),
        referencias_de_conceito(indice),
        referencias_de_relacao(indice),
        papel_sem_fundamento(indice),
        modulos_ausentes(artifacts),
        perguntas_de_competencia(artifacts, indice),
        medidas_sem_necessidade(artifacts),
        mapeamentos_incompletos(artifacts),
        vinculos_sem_lastro(artifacts, indice),
        SchemaCheck.problems(artifacts),
        base_vazia(artifacts)
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

  # ------------------------------------------------------------------- índice
  #
  # Conceitos e relações vivem dentro dos módulos, e quase toda verificação precisa
  # perguntar "este id existe?". Montar o índice **uma vez** é o que separa esta validação
  # de uma varredura por referência — são 220 conceitos e 144 relações.
  defp indexar(artifacts) do
    modulos = Enum.filter(artifacts, &(&1.kind == :module))

    conceitos =
      for m <- modulos,
          c <- List.wrap(m.data["concepts"]),
          is_map(c),
          into: %{},
          do:
            {c["id"], %{ontologia: get_in(m.data, ["module", "ontology"]), dado: c, path: m.path}}

    relacoes =
      for m <- modulos,
          r <- List.wrap(m.data["relations"]),
          is_map(r),
          into: %{},
          do:
            {r["id"], %{ontologia: get_in(m.data, ["module", "ontology"]), dado: r, path: m.path}}

    # **A dependência é lida do declarado, não deduzida do uso.**
    #
    # A primeira versão desta função montava o mapa a partir das referências encontradas nos
    # módulos — e aí toda referência virava a sua própria autorização: o mapa dizia que `ciro`
    # depende de `cmpo` porque `ciro` usa `cmpo`, e a verificação nunca reprovava.
    #
    # A declaração vive no `ontology.yaml`, em `dependencies`, e é ela que a ontologia assume.
    dependencias =
      for o <- artifacts,
          o.kind == :ontology,
          into: %{},
          # `dependencies` e `modules` ficam na **raiz** do arquivo, e não dentro de
          # `ontology:` — ler no lugar errado devolve lista vazia, e a verificação passa a
          # reprovar toda referência entre ontologias. Foi o que aconteceu na primeira
          # execução: 11 falsos positivos, todos em ontologias que declaram a dependência.
          do:
            {get_in(o.data, ["ontology", "id"]),
             o.data |> Map.get("dependencies") |> List.wrap() |> MapSet.new()}

    %{conceitos: conceitos, relacoes: relacoes, dependencias: dependencias}
  end

  # `ontologia.conceito`, minúsculas. **Id é contrato**: mapeamentos, regras e perguntas de
  # competência apontam para ele, e mudá-lo depois quebra referência em silêncio.
  defp ids_fora_do_padrao(%{conceitos: conceitos, relacoes: relacoes}) do
    padrao = ~r/^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$/

    Enum.flat_map(Map.merge(conceitos, relacoes), fn {id, %{path: path}} ->
      if is_binary(id) and Regex.match?(padrao, id),
        do: [],
        else: ["#{path}: id fora do padrão `ontologia.conceito`: #{inspect(id)}"]
    end)
  end

  # `parent` e `is_role_of` existem — e a ontologia que os usa **declara** dependência da
  # que os define. Referenciar sem declarar é a dependência escondida que o princípio IX
  # proíbe.
  defp referencias_de_conceito(indice) do
    Enum.flat_map(indice.conceitos, fn {id, %{dado: c, path: path}} ->
      classificacao = c["classification"] || %{}
      # Os dois lados pelo mesmo critério: o prefixo do id. Misturar — dono pelo módulo,
      # referência pelo prefixo — foi o que produziu os falsos positivos.
      onto = ontologia_de(indice, id)

      Enum.flat_map(["parent", "is_role_of"], fn campo ->
        problema_de_referencia(indice, id, campo, classificacao[campo], onto, path)
      end)
    end)
  end

  defp referencias_de_relacao(indice) do
    Enum.flat_map(indice.relacoes, fn {id, %{dado: r, path: path}} ->
      onto = ontologia_de(indice, id)

      Enum.flat_map(["source", "target"], fn lado ->
        problema_de_referencia(indice, id, lado, r[lado], onto, path)
      end)
    end)
  end

  defp problema_de_referencia(_indice, _id, _campo, nil, _onto, _path), do: []

  defp problema_de_referencia(indice, id, campo, ref, onto, path) do
    cond do
      not Map.has_key?(indice.conceitos, ref) ->
        ["#{path}: #{id}.#{campo} aponta para #{ref}, que não existe"]

      ontologia_de(indice, ref) != onto and
          not MapSet.member?(
            Map.get(indice.dependencias, onto, MapSet.new()),
            ontologia_de(indice, ref)
          ) ->
        [
          "#{path}: #{id} usa #{ref}, e #{onto} não declara dependência de #{ontologia_de(indice, ref)}"
        ]

      true ->
        []
    end
  end

  # A ontologia de um id sai do **prefixo dele**, e não do módulo onde ele foi encontrado.
  #
  # O id é `ontologia.conceito` por contrato — a primeira verificação desta lista existe para
  # garantir isso. Derivar do módulo parecia mais seguro e era mais frágil: um módulo sem
  # `module.ontology` fazia a ontologia virar `nil`, e aí **toda** referência dele reprovava por
  # dependência não declarada. Foram 130 falsos positivos na primeira execução.
  defp ontologia_de(_indice, id) when is_binary(id), do: id |> String.split(".") |> List.first()
  defp ontologia_de(_indice, _id), do: nil

  # Em UFO, um `role` é antirrígido e especializa o kind de onde herda identidade. Papel sem
  # `is_role_of` nem `parent` **não tem identidade**, e a tabela derivada dele não sabe a quem
  # pertence.
  defp papel_sem_fundamento(indice) do
    Enum.flat_map(indice.conceitos, fn {id, %{dado: c, path: path}} ->
      classificacao = c["classification"] || %{}

      if classificacao["ontouml_stereotype"] == "role" and
           is_nil(classificacao["is_role_of"]) and is_nil(classificacao["parent"]) do
        ["#{path}: #{id} é `role` e não alcança o tipo rígido que lhe dá identidade"]
      else
        []
      end
    end)
  end

  # Módulo listado no `ontology.yaml` que não tem arquivo é promessa sem lastro: quem lê a
  # ontologia conta com um conceito que ninguém carregou.
  defp modulos_ausentes(artifacts) do
    carregados =
      artifacts
      |> Enum.filter(&(&1.kind == :module))
      |> MapSet.new(&get_in(&1.data, ["module", "id"]))

    artifacts
    |> Enum.filter(&(&1.kind == :ontology))
    |> Enum.flat_map(fn artifact ->
      artifact.data
      |> Map.get("modules")
      |> List.wrap()
      |> Enum.reject(
        &(&1 in carregados or "#{get_in(artifact.data, ["ontology", "id"])}.#{&1}" in carregados)
      )
      |> Enum.map(&"#{artifact.path}: módulo #{&1} está listado e não tem arquivo")
    end)
  end

  # Pergunta de competência que aponta para conceito inexistente é pergunta que a plataforma
  # **não** consegue responder — e o catálogo diria que consegue.
  defp perguntas_de_competencia(artifacts, indice) do
    artifacts
    |> Enum.filter(&(&1.kind == :competency_questions))
    |> Enum.flat_map(fn artifact ->
      artifact.data
      |> Map.get("competency_questions", [])
      |> List.wrap()
      |> Enum.filter(&is_map/1)
      |> Enum.flat_map(fn q ->
        (List.wrap(q["concepts"]) ++ List.wrap(q["relations"]))
        |> Enum.filter(&is_binary/1)
        |> Enum.reject(&(Map.has_key?(indice.conceitos, &1) or Map.has_key?(indice.relacoes, &1)))
        |> Enum.map(&"#{artifact.path}: #{q["id"]} referencia #{&1}, que não existe")
      end)
    end)
  end

  # Medida sem necessidade de informação declarada é número sem pergunta — e o `AGENTS.md`
  # proíbe indicador que não responde a nada.
  defp medidas_sem_necessidade(artifacts) do
    necessidades =
      artifacts
      |> Enum.filter(&(&1.kind == :information_need))
      |> MapSet.new(& &1.id)

    artifacts
    |> Enum.filter(&(&1.kind == :measurement))
    |> Enum.flat_map(fn artifact ->
      medida = artifact.data["measurement"] || %{}

      referencias =
        medida
        |> Map.get("answers_information_need")
        |> List.wrap()
        |> Enum.reject(&MapSet.member?(necessidades, &1))
        |> Enum.map(&"#{artifact.path}: #{medida["id"]} responde a #{&1}, que não existe")

      # **Limitação é parte da medida, não observação sobre ela.** Um número sem o que ele não
      # cobre é usado como se cobrisse tudo.
      limitacoes =
        if List.wrap(medida["limitations"]) == [],
          do: ["#{artifact.path}: #{medida["id"]} não declara `limitations`"],
          else: []

      referencias ++ limitacoes
    end)
  end

  # O mapeamento é onde a semântica atravessa a fronteira, e é o lugar onde silêncio custa
  # mais: sem `equivalence`, ninguém sabe se a tradução é exata; sem `limitations`, o que ela
  # **não** cobre vira surpresa na consulta.
  defp mapeamentos_incompletos(artifacts) do
    artifacts
    |> Enum.filter(&(&1.kind == :mapping))
    |> Enum.flat_map(&declaracoes_ausentes/1)
  end

  defp declaracoes_ausentes(artifact) do
    semantica = artifact.data["semantics"] || %{}

    [
      {semantica["equivalence"] in [nil, ""], "mapeamento não declara `semantics.equivalence`"},
      {semantica["justification"] in [nil, ""],
       "mapeamento não declara `semantics.justification`"},
      {List.wrap(artifact.data["limitations"]) == [],
       "mapeamento não declara `limitations` — o que ele não cobre"}
    ]
    |> Enum.filter(&elem(&1, 0))
    |> Enum.map(&"#{artifact.path}: #{elem(&1, 1)}")
  end

  # Vínculo prometido por mapeamento precisa de lastro na ontologia.
  #
  # Cada entrada de `relations:` afirma que o conceito alvo do mapeamento se liga a outro
  # conceito. Sem lastro, o mapeamento promete um caminho que a ontologia não tem, o derivador
  # não gera coluna alguma, e alguém acaba escrevendo a coluna à mão — foi assim que
  # `eo_people.organization_id` ficou nula em 100% dos registros (achado F6 da feature 002).
  #
  # São três lastros aceitos, e a ordem importa: relação declarada, regra de derivação, ou
  # limitação que **nomeie o conceito** do outro lado. Frase genérica não serve — passaria em
  # qualquer mapeamento, e o gate viraria carimbo.
  defp vinculos_sem_lastro(artifacts, indice) do
    artifacts
    |> Enum.filter(&(&1.kind == :mapping))
    |> Enum.flat_map(fn artifact ->
      id = get_in(artifact.data, ["mapping", "id"])
      alvo = get_in(artifact.data, ["target", "concept"])

      artifact.data
      |> Map.get("relations")
      |> vinculos()
      |> Enum.flat_map(&problema_de_vinculo(&1, indice, artifact, id, alvo))
    end)
  end

  defp vinculos(relations) when is_map(relations),
    do: Enum.filter(relations, &is_map(elem(&1, 1)))

  defp vinculos(_), do: []

  defp problema_de_vinculo({nome, rel}, indice, artifact, id, alvo) do
    outro = rel["target_concept"]

    cond do
      is_nil(outro) ->
        []

      not Map.has_key?(indice.conceitos, outro) ->
        ["#{artifact.path}: #{id}: relations.#{nome} aponta para conceito inexistente #{outro}"]

      declara_outra_ontologia?(rel, outro) ->
        [
          "#{artifact.path}: #{id}: relations.#{nome} declara target_ontology " <>
            "'#{rel["target_ontology"]}' e conceito de '#{ontologia_de(indice, outro)}'"
        ]

      lastro?(artifact, indice, alvo, outro) ->
        []

      true ->
        [
          "#{artifact.path}: #{id}: relations.#{nome} promete vínculo #{alvo} → #{outro} " <>
            "sem relação declarada, sem derivation.rule_id, e sem limitação que nomeie #{outro}"
        ]
    end
  end

  defp declara_outra_ontologia?(rel, outro) do
    onto = rel["target_ontology"]
    is_binary(onto) and outro |> String.split(".") |> List.first() != onto
  end

  defp lastro?(artifact, indice, alvo, outro) do
    # Alvo que não existe no índice já é reprovado por `mapeamentos_incompletos`; repetir aqui
    # produziria dois problemas para a mesma causa.
    is_nil(alvo) or not Map.has_key?(indice.conceitos, alvo) or
      not is_nil(get_in(artifact.data, ["derivation", "rule_id"])) or
      relacao_entre?(indice, alvo, outro) or
      Enum.any?(List.wrap(artifact.data["limitations"]), &String.contains?(inspect(&1), outro))
  end

  # Existe relação declarada entre os dois, em qualquer direção — considerando os supertipos de
  # cada lado. A relação de EO sai de `eo.organizational_team`, e o mapeamento pode alvejar o
  # subkind; ignorar a especialização reprovaria vínculo legítimo.
  defp relacao_entre?(indice, a, b) do
    lado_a = com_supertipos(indice, a)
    lado_b = com_supertipos(indice, b)

    Enum.any?(indice.relacoes, fn {_id, %{dado: r}} ->
      (r["source"] in lado_a and r["target"] in lado_b) or
        (r["source"] in lado_b and r["target"] in lado_a)
    end)
  end

  # Sobe, e **só** sobe. Relação declarada no supertipo vale para o subtipo — toda equipe
  # organizacional é equipe. O inverso é falso: aceitar a descida transformaria a verificação
  # em carimbo.
  defp com_supertipos(indice, id), do: indice |> subida(id, []) |> Enum.uniq()

  defp subida(indice, id, vistos) do
    if id in vistos or not Map.has_key?(indice.conceitos, id) do
      [id]
    else
      classificacao = get_in(indice.conceitos, [id, :dado, "classification"]) || %{}

      # A base usa `parent`; `specializes` fica aceito porque o schema o admite em outros
      # pontos, e ler só um dos dois produziria falso positivo silencioso.
      pais = List.wrap(classificacao["parent"] || classificacao["specializes"])

      [id | Enum.flat_map(pais, &subida(indice, &1, [id | vistos]))]
    end
  end

  # Base sem artefato **aprova**, e é justamente por isso que precisa dizer: aprovar em
  # silêncio sobre nada é o sucesso silencioso na forma mais pura.
  defp base_vazia([]), do: ["a base de conhecimento não tem artefato algum"]
  defp base_vazia(_), do: []

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
