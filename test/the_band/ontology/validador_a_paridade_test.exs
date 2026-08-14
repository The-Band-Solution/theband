defmodule TheBand.Ontology.ValidadorAParidadeTest do
  @moduledoc """
  Feature 018 — o validador Elixir faz as mesmas verificações que o Python (#177).

  O teste que interessa aqui **não** é "a base passa". Base passando prova que o validador
  não reprova nada — inclusive um validador que não verifica coisa alguma passaria. Cada
  verificação é exercida contra uma violação construída de propósito, e a que não reprovar
  está morta.
  """
  use ExUnit.Case, async: true

  alias TheBand.Ontology.SchemaCheck
  alias TheBand.Ontology.YamlLoader
  alias TheBand.Ontology.YamlValidator

  # Um artefato mínimo, no formato que o carregador devolve.
  defp artefato(kind, id, data), do: artefato(kind, id, data, "fake/#{kind}-#{id}.yaml")

  defp artefato(kind, id, data, path) do
    %{kind: kind, id: id, path: path, data: data, payload: YamlLoader.payload(data, kind)}
  end

  defp ontologia(id, dependencias) do
    artefato(:ontology, id, %{"ontology" => %{"id" => id}, "dependencies" => dependencias})
  end

  defp modulo(ontologia, conceitos, relacoes \\ []) do
    artefato(
      :module,
      "#{ontologia}.mod",
      %{
        "module" => %{"id" => "#{ontologia}.mod", "ontology" => ontologia},
        "concepts" => conceitos,
        "relations" => relacoes
      },
      "fake/#{ontologia}/mod.yaml"
    )
  end

  defp conceito(id, classificacao \\ %{}), do: %{"id" => id, "classification" => classificacao}

  # Um mapeamento completo — o que falta nele é só o lastro do vínculo, que é o que cada
  # teste mede. Alvo padrão `spo.developer`, sem relação declarada até `ufo.agent`.
  defp mapeamento_com_vinculo(outro, extra, alvo \\ "spo.developer") do
    dados =
      Map.merge(
        %{
          "mapping" => %{"id" => "m_vinculo"},
          "target" => %{"concept" => alvo},
          "semantics" => %{"equivalence" => "exact", "justification" => "j"},
          "limitations" => ["nenhuma"],
          "provenance" => %{
            "required_fields" => ~w(source_system source_instance external_id collected_at)
          },
          "relations" => %{"pertence_a" => %{"target_concept" => outro}}
        },
        extra
      )

    artefato(:mapping, "m_vinculo", dados)
  end

  defp problemas(artefatos) do
    case YamlValidator.validate(artefatos) do
      :ok -> []
      {:error, p} -> p
    end
  end

  # Uma base pequena e **válida**. Cada teste a quebra num ponto só, e é essa a diferença
  # que o teste mede.
  defp base_valida do
    [
      ontologia("ufo", []),
      ontologia("spo", ["ufo"]),
      modulo("ufo", [conceito("ufo.agent", %{"ontouml_stereotype" => "kind"})]),
      modulo(
        "spo",
        [
          conceito("spo.developer", %{"ontouml_stereotype" => "role", "is_role_of" => "ufo.agent"}),
          # Sem relação declarada até `spo.developer` — é o par que os testes de lastro usam.
          conceito("spo.ticket", %{"ontouml_stereotype" => "kind"})
        ],
        [%{"id" => "spo.works_on", "source" => "spo.developer", "target" => "ufo.agent"}]
      )
    ]
  end

  describe "a base do repositório" do
    test "passa nas treze verificações" do
      {:ok, artefatos} = YamlLoader.load_all(YamlLoader.root())

      assert YamlValidator.validate(artefatos) == :ok
    end

    test "as doze ontologias são reconhecidas como ontologia" do
      {:ok, artefatos} = YamlLoader.load_all(YamlLoader.root())

      arquivos = Enum.filter(artefatos, &String.ends_with?(&1.path, "ontology.yaml"))
      classificadas = Enum.filter(arquivos, &(&1.kind == :ontology))

      assert length(arquivos) == length(classificadas), """
      Arquivo de ontologia classificado como outra coisa: #{Enum.map_join(arquivos -- classificadas, ", ", & &1.path)}

      `cdro`, `ciro` e `sro` declaram `competency_questions:` dentro do próprio `ontology.yaml`.
      Enquanto o tipo saía da ordem das chaves, as três viravam `unknown` — e, invisíveis para o
      filtro por `:ontology`, o mapa de dependências não as continha. Toda referência delas
      reprovava por dependência não declarada, com a declaração ali no arquivo.
      """
    end

    test "o arquivo de perguntas de competência não é confundido com ontologia" do
      {:ok, artefatos} = YamlLoader.load_all(YamlLoader.root())

      perguntas = Enum.filter(artefatos, &(&1.kind == :competency_questions))

      # `ontology: ciro` no topo do arquivo aponta para a ontologia, não a declara.
      assert perguntas != [], "nenhum arquivo de perguntas de competência foi reconhecido"
      refute Enum.any?(perguntas, &String.ends_with?(&1.path, "/ontology.yaml"))
    end
  end

  describe "cada verificação reprova a sua violação" do
    test "id fora do padrão `ontologia.conceito`" do
      artefatos = base_valida() ++ [modulo("ufo", [conceito("UFO::Agent")])]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "id fora do padrão"))
    end

    test "conceito aponta para pai inexistente" do
      artefatos =
        base_valida() ++
          [modulo("ufo", [conceito("ufo.robot", %{"parent" => "ufo.inexistente"})])]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "aponta para ufo.inexistente"))
    end

    test "conceito usa outra ontologia sem declarar a dependência" do
      artefatos =
        [ontologia("ufo", []), ontologia("spo", [])] ++
          [
            modulo("ufo", [conceito("ufo.agent", %{"ontouml_stereotype" => "kind"})]),
            modulo("spo", [conceito("spo.dev", %{"parent" => "ufo.agent"})])
          ]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "spo não declara dependência de ufo"))
    end

    test "a dependência declarada autoriza a referência" do
      # O outro lado da mesma verificação. Sem ele, um validador que reprovasse **toda**
      # referência entre ontologias passaria no teste acima — foi exatamente o defeito que
      # produziu 124 problemas inventados.
      refute Enum.any?(problemas(base_valida()), &(&1 =~ "não declara dependência"))
    end

    test "relação aponta para conceito inexistente" do
      artefatos =
        base_valida() ++
          [
            modulo("ufo", [], [
              %{"id" => "ufo.rel", "source" => "ufo.agent", "target" => "ufo.fantasma"}
            ])
          ]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "aponta para ufo.fantasma"))
    end

    test "papel sem `is_role_of` nem `parent` não tem identidade" do
      artefatos =
        base_valida() ++
          [modulo("ufo", [conceito("ufo.revisor", %{"ontouml_stereotype" => "role"})])]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "não alcança o tipo rígido"))
    end

    test "módulo listado no `ontology.yaml` e sem arquivo" do
      artefatos =
        base_valida() ++
          [
            artefato(:ontology, "eo", %{
              "ontology" => %{"id" => "eo"},
              "modules" => ["equipes_que_nunca_existiram"]
            })
          ]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "está listado e não tem arquivo"))
    end

    test "pergunta de competência referencia conceito inexistente" do
      artefatos =
        base_valida() ++
          [
            artefato(:competency_questions, "ufo.cq", %{
              "ontology" => "ufo",
              "competency_questions" => [%{"id" => "CQ1", "concepts" => ["ufo.miragem"]}]
            })
          ]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "CQ1 referencia ufo.miragem"))
    end

    test "medida responde a necessidade de informação inexistente" do
      artefatos =
        base_valida() ++
          [
            artefato(:measurement, "m1", %{
              "measurement" => %{
                "id" => "m1",
                "answers_information_need" => ["ni.que.nao.existe"],
                "limitations" => ["nenhuma"]
              },
              "provenance" => %{"source_type" => "thesis"}
            })
          ]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "responde a ni.que.nao.existe"))
    end

    test "medida sem `limitations` é número usado como se cobrisse tudo" do
      artefatos =
        base_valida() ++
          [
            artefato(:measurement, "m2", %{
              "measurement" => %{"id" => "m2", "answers_information_need" => []},
              "provenance" => %{"source_type" => "thesis"}
            })
          ]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "não declara `limitations`"))
    end

    test "mapeamento sem equivalência, justificativa e limitações" do
      artefatos =
        base_valida() ++
          [
            artefato(:mapping, "map1", %{
              "mapping" => %{"id" => "map1"},
              "provenance" => %{
                "required_fields" => ~w(source_system source_instance external_id collected_at)
              }
            })
          ]

      problemas = problemas(artefatos)

      assert Enum.any?(problemas, &(&1 =~ "semantics.equivalence"))
      assert Enum.any?(problemas, &(&1 =~ "semantics.justification"))
      assert Enum.any?(problemas, &(&1 =~ "mapeamento não declara `limitations`"))
    end

    test "identificador duplicado" do
      artefatos = base_valida() ++ [ontologia("ufo", [])]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "identificador duplicado ufo"))
    end

    test "proveniência ausente" do
      artefatos =
        base_valida() ++ [artefato(:measurement, "m3", %{"measurement" => %{"id" => "m3"}})]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "proveniência ausente"))
    end

    test "segredo no YAML" do
      artefatos =
        base_valida() ++
          [artefato(:mapping, "vazado", %{"mapping" => %{"token" => "ghp_" <> "0123456789"}})]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "possível segredo no YAML"))
    end

    test "vínculo prometido por mapeamento sem lastro na ontologia" do
      assert Enum.any?(
               problemas(base_valida() ++ [mapeamento_com_vinculo("spo.ticket", %{})]),
               &(&1 =~ "promete vínculo spo.developer → spo.ticket")
             )
    end

    test "relação declarada é lastro" do
      # `spo.works_on` liga developer a agent na base válida.
      refute Enum.any?(
               problemas(
                 base_valida() ++ [mapeamento_com_vinculo("ufo.agent", %{}, "spo.developer")]
               ),
               &(&1 =~ "promete vínculo")
             )
    end

    test "limitação que nomeia o conceito é lastro; frase genérica não" do
      nomeia =
        mapeamento_com_vinculo("spo.ticket", %{"limitations" => ["sem lastro para spo.ticket"]})

      generica = mapeamento_com_vinculo("spo.ticket", %{"limitations" => ["há limitações"]})

      refute Enum.any?(problemas(base_valida() ++ [nomeia]), &(&1 =~ "promete vínculo"))

      assert Enum.any?(problemas(base_valida() ++ [generica]), &(&1 =~ "promete vínculo")),
             "frase genérica passaria em qualquer mapeamento, e o gate viraria carimbo"
    end

    test "vínculo aponta para conceito inexistente" do
      artefatos = base_valida() ++ [mapeamento_com_vinculo("ufo.nunca_existiu", %{})]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "aponta para conceito inexistente"))
    end

    test "target_ontology discorda do prefixo do conceito" do
      vinculo = %{"target_concept" => "ufo.agent", "target_ontology" => "spo"}

      artefatos =
        base_valida() ++
          [
            artefato(:mapping, "m_onto", %{
              "mapping" => %{"id" => "m_onto"},
              "target" => %{"concept" => "spo.developer"},
              "semantics" => %{"equivalence" => "exact", "justification" => "j"},
              "limitations" => ["nenhuma"],
              "provenance" => %{
                "required_fields" => ~w(source_system source_instance external_id collected_at)
              },
              "relations" => %{"v" => vinculo}
            })
          ]

      assert Enum.any?(problemas(artefatos), &(&1 =~ "declara target_ontology 'spo'"))
    end

    test "base sem artefato algum diz isso, em vez de aprovar em silêncio" do
      assert Enum.any?(problemas([]), &(&1 =~ "não tem artefato algum"))
    end
  end

  describe "forma do artefato contra o JSON Schema" do
    # Um schema mínimo do tipo `measurement`, com o mesmo nome de arquivo que o carregador
    # usa para casar schema e artefato.
    defp schema_de_medida(propriedades, extra \\ %{}) do
      schema =
        Map.merge(
          %{
            "type" => "object",
            "required" => ["measurement"],
            "additionalProperties" => false,
            "properties" => %{"measurement" => propriedades}
          },
          extra
        )

      %{
        kind: :unknown,
        id: "measurement.schema",
        path: "schemas/measurement.schema.yaml",
        data: schema,
        payload: schema
      }
    end

    defp medida(dados), do: artefato(:measurement, "m", %{"measurement" => dados})

    test "campo inventado não entra na base sem ninguém notar" do
      schema =
        schema_de_medida(%{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{"id" => %{"type" => "string"}}
        })

      problemas = SchemaCheck.problems([schema, medida(%{"id" => "m", "inventado" => 1})])

      assert Enum.any?(problemas, &(&1 =~ "campo inventado não está declarado no schema"))
    end

    test "campo obrigatório ausente" do
      schema = schema_de_medida(%{"type" => "object", "required" => ["id"]})

      assert Enum.any?(
               SchemaCheck.problems([schema, medida(%{})]),
               &(&1 =~ "campo obrigatório id ausente")
             )
    end

    test "tipo errado" do
      schema =
        schema_de_medida(%{"type" => "object", "properties" => %{"id" => %{"type" => "string"}}})

      assert Enum.any?(
               SchemaCheck.problems([schema, medida(%{"id" => 42})]),
               &(&1 =~ "esperava string, veio integer")
             )
    end

    test "valor fora do enum" do
      schema =
        schema_de_medida(%{
          "type" => "object",
          "properties" => %{"scale" => %{"enum" => ["nominal", "ordinal"]}}
        })

      assert Enum.any?(
               SchemaCheck.problems([schema, medida(%{"scale" => "chutômetro"})]),
               &(&1 =~ "fora de")
             )
    end

    test "construto que este validador não implementa reprova, em vez de ser ignorado" do
      # É a diferença entre "não verifiquei" e "está certo". Ignorar em silêncio faria o
      # schema crescer para além do que o gate mede, sem ninguém perceber.
      schema = schema_de_medida(%{"type" => "object", "maxProperties" => 2})

      assert Enum.any?(
               SchemaCheck.problems([schema, medida(%{"id" => "m"})]),
               &(&1 =~ "construto maxProperties não é verificado")
             )
    end

    test "sem schema algum carregado, a verificação diz que não rodou" do
      assert Enum.any?(
               SchemaCheck.problems([medida(%{"id" => "m"})]),
               &(&1 =~ "a verificação de forma não rodou")
             )
    end

    test "artefato conforme não produz problema" do
      schema =
        schema_de_medida(%{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{"id" => %{"type" => "string"}}
        })

      assert SchemaCheck.problems([schema, medida(%{"id" => "m"})]) == []
    end
  end

  describe "todos os problemas são relatados — FR-003" do
    test "duas violações diferentes aparecem juntas" do
      artefatos =
        base_valida() ++
          [modulo("ufo", [conceito("UFO::Agent"), conceito("ufo.x", %{"parent" => "ufo.nada"})])]

      problemas = problemas(artefatos)

      # Parar no primeiro problema faria a segunda correção depender de outra rodada — e
      # esconderia quantas violações a base tem de verdade.
      assert Enum.any?(problemas, &(&1 =~ "id fora do padrão"))
      assert Enum.any?(problemas, &(&1 =~ "aponta para ufo.nada"))
    end
  end
end
