defmodule TheBand.WorkItems.Routing do
  @moduledoc """
  Aplica a regra de roteamento por tipo de issue — a semântica vem do YAML.

  **Nenhum `case` sobre nome de tipo neste módulo.** A regra é semântica, e o princípio
  IV manda que semântica viva em YAML versionado. Um `case` no código tornaria a mudança
  de regra um deploy em vez de um commit revisável na base de conhecimento.

  ## Precedência, e ela é implementada e não só documentada

      regra do tenant, em rules/tenants/<tenant>.yaml    o que ESTA organização usa
        └─ regra global da rede                          o padrão

  A primeira regra que conhece o tipo decide quais conceitos ele pode ser. A do tenant
  vem primeiro porque nomes de tipo são texto livre na organização: uma usa `Feature`,
  outra usa `História`.

  ## Duas coisas diferentes, e confundi-las foi o meu primeiro erro aqui

  **Quais conceitos um tipo pode ser** vem da regra. **Qual deles ele é** vem da
  estrutura, quando a regra oferece mais de um.

  `Feature` nesta organização cobre épico e user story atômica — e o rótulo não afirma
  qual. Logo **não há divergência**: a estrutura não contradiz nada, ela completa o que
  o rótulo não disse.

  `Epic` afirma. Quando a estrutura discorda dele, aí há divergência, e ela é
  registrada — é o dado que a tela mostra.

  ## Duas etapas, e a ordem é a garantia

      1. tipo declarado  → regra da organização, depois tenant, depois global
      2. título, SE a etapa 1 não decidiu → regra da organização apenas

  FR-008 exige que tipo declarado vença regra de título, e a única forma de garantir isso
  é **não chegar** à etapa 2 quando a etapa 1 decidiu. Avaliar as duas e escolher depois
  deixaria a precedência dependente da ordem de comparação — e um dado errado a inverteria
  em silêncio.

  **Regra de título não existe em YAML global.** O catálogo propõe padrões de título, mas
  eles só valem depois de ativados por organização — e ativados, vivem no banco. Isso
  mantém a inferência sobre texto livre sempre como decisão declarada de alguém, nunca como
  padrão da plataforma.

  A confiança sai daqui: etapa 1 grava `high`, etapa 2 grava `medium`. É o vocabulário de
  níveis que a base de conhecimento já usa, e não um número inventado.

  ## O caso que erra quem não lê a regra

  Sub-issues do tipo **tarefa** não tornam a issue épica. Tarefa **atende** a user
  story (`sro.intended_task_planned_to_meet_user_story`), não a compõe. No dado real
  desta organização, três `Feature` com sub-issues são atômicas por isso — e errar aqui
  faz 78 tarefas se ligarem a épicos, violando `sro.rule07`.
  """

  alias TheBand.Mapping.Schemas.MappingRule
  alias TheBand.Ontology.KnowledgeBase

  @global "github.issue_type_routing"
  # Identifica o **mecanismo**, não a regra: qual regra decidiu está em `mapping_rule_id`,
  # e a versão dela em `rule_version`.
  @regra_da_organizacao "organization.issue_mapping_rule"
  @epico "sro.epic"
  @atomica "sro.atomic_user_story"

  @typedoc "O que a regra decidiu sobre uma issue."
  @type decision :: %{
          declared: String.t() | nil,
          derived: String.t() | nil,
          divergence: String.t() | nil,
          divergence_kind: String.t() | nil,
          skip_reason: String.t() | nil,
          skip_detail: String.t() | nil,
          rule_id: String.t(),
          rule_version: pos_integer(),
          evidence_source: String.t() | nil,
          confidence: String.t() | nil,
          mapping_rule_id: Ecto.UUID.t() | nil
        }

  @doc """
  Decide o conceito de uma issue a partir do tipo declarado e da estrutura.

  `issue` precisa de `:issue_type` e `:sub_issue_types` — a lista de tipos das partes.
  A segunda é o que distingue épico de atômica, e sem ela a distinção não é possível.

  `opts[:tenant_rule_id]` põe a regra do tenant à frente da global.

  `opts[:organization_rules]` são as regras que a organização declarou, **já ordenadas por
  posição** — as vigentes, vindas de `Mapping.active_rules/2`. Elas vêm por parâmetro e não
  por consulta aqui dentro: `Routing` decide, e decidir não é ir ao banco. Fosse consulta,
  cada uma das 4471 issues faria a sua.
  """
  @spec decide(map(), keyword()) :: decision()
  def decide(issue, opts \\ []) do
    regras = carregar(opts)
    da_organizacao = Keyword.get(opts, :organization_rules, [])
    tipo = issue[:issue_type]

    case por_tipo_declarado(issue, tipo, da_organizacao, regras) do
      {:ok, decisao} ->
        decisao

      {:sem_conceito, base} ->
        # A etapa 2 só é alcançada aqui. Não há caminho que avalie as duas e escolha
        # depois — é o que torna a precedência estrutura, e não dado.
        por_titulo(issue, da_organizacao, base)
    end
  end

  # Etapa 1: a regra da organização primeiro, depois tenant e global.
  defp por_tipo_declarado(_issue, nil, _da_organizacao, regras),
    do: {:sem_conceito, Map.put(vazio(regras), :skip_reason, "type_absent")}

  defp por_tipo_declarado(issue, tipo, da_organizacao, regras) do
    case regra_que_casa(da_organizacao, "declared_type", tipo) do
      %MappingRule{} = regra ->
        {:ok, decidir_por_regra_da_organizacao(regra, issue, regras, "declared_type", "high")}

      nil ->
        case candidatos(regras, tipo) do
          :unknown ->
            {:sem_conceito,
             Map.merge(vazio(regras), %{skip_reason: "type_unknown", skip_detail: tipo})}

          {conceitos, regra} ->
            {:ok,
             conceitos
             |> decidir(regra, issue, regras)
             |> Map.merge(%{evidence_source: "declared_type", confidence: "high"})}
        end
    end
  end

  # Etapa 2: só regras da organização, e só sobre o título.
  defp por_titulo(issue, da_organizacao, base) do
    case regra_que_casa(da_organizacao, "title", issue[:title]) do
      nil -> base
      regra -> decidir_por_regra_da_organizacao(regra, issue, [], "title", "medium")
    end
  end

  # A primeira regra que casa decide, e "primeira" é por `position` — que é único por
  # organização. Sem ordem determinística, acrescentar regra mudaria a classificação de
  # issues que ninguém tocou.
  defp regra_que_casa(regras, onde, texto) when is_binary(texto) do
    Enum.find(regras, fn regra ->
      regra.where == onde and combina?(regra, texto)
    end)
  end

  defp regra_que_casa(_regras, _onde, _texto), do: nil

  @doc """
  Se o texto casa a regra, pela forma de comparação que ela declara.

  Pública porque a **prévia** usa a mesma função: prévia e efeito por caminhos diferentes
  é o que o SC-007 proíbe.

  `contains "US"` casa `"STATUS"` e `starts_with "US"` não — a diferença é exatamente o
  motivo de a forma ser declarada, e não inferida do texto.
  """
  @spec combina?(MappingRule.t(), String.t() | nil) :: boolean()
  def combina?(_regra, nil), do: false

  def combina?(%MappingRule{how: how} = regra, texto) do
    {alvo, padrao} = caixa(regra, texto)

    case how do
      "equals" -> alvo == padrao
      "starts_with" -> String.starts_with?(alvo, padrao)
      "contains" -> String.contains?(alvo, padrao)
      "regex" -> casa_regex?(regra, texto)
    end
  end

  defp caixa(%MappingRule{case_sensitive: true, pattern: padrao}, texto), do: {texto, padrao}

  defp caixa(%MappingRule{pattern: padrao}, texto),
    do: {String.downcase(texto), String.downcase(padrao)}

  # `Regex.compile/2` e não `compile!/2`: a regra foi validada na gravação, mas uma linha
  # gravada por script ou migração pode não ter passado por lá. Expressão inválida aqui
  # significa **não casa** — nunca exceção no meio da promoção de 4471 issues.
  defp casa_regex?(%MappingRule{pattern: padrao, case_sensitive: sensivel}, texto) do
    opcoes = if sensivel, do: "", else: "i"

    case Regex.compile(padrao, opcoes) do
      {:ok, regex} -> Regex.match?(regex, texto)
      {:error, _} -> false
    end
  end

  # A regra da organização oferece **um** conceito. A estrutura continua decidindo entre
  # épico e atômica quando o conceito é um dos dois: `sro.rule05` diz que não há épico sem
  # partes, e nenhuma regra de texto pode contradizer o axioma.
  defp decidir_por_regra_da_organizacao(regra, issue, regras, fonte, confianca) do
    base = vazio_ou(regras)

    %{
      base
      | declared: regra.target_concept,
        derived: derivado([regra.target_concept], issue),
        rule_id: @regra_da_organizacao,
        rule_version: regra.version
    }
    |> then(fn d ->
      %{
        d
        | divergence: motivo(d.declared, d.derived),
          divergence_kind: tipo_de_divergencia(d.declared, d.derived)
      }
    end)
    |> Map.merge(%{
      evidence_source: fonte,
      confidence: confianca,
      mapping_rule_id: regra.id
    })
  end

  defp carregar(opts) do
    ids = Enum.reject([opts[:tenant_rule_id], Keyword.get(opts, :rule_id, @global)], &is_nil/1)

    Enum.flat_map(ids, fn id ->
      case KnowledgeBase.rule(id) do
        {:ok, regra} -> [regra]
        _ -> []
      end
    end)
  end

  defp vazio([regra | _]) do
    %{
      declared: nil,
      derived: nil,
      divergence: nil,
      divergence_kind: nil,
      skip_reason: nil,
      skip_detail: nil,
      rule_id: regra["id"],
      rule_version: regra["version"],
      evidence_source: nil,
      confidence: nil,
      mapping_rule_id: nil
    }
  end

  # A regra da organização decide sem que nenhuma regra do YAML tenha sido carregada — é o
  # caso da etapa 2, onde a lista chega vazia de propósito.
  defp vazio_ou([]), do: vazio([%{"id" => @regra_da_organizacao, "version" => 1}])
  defp vazio_ou(regras), do: vazio(regras)

  defp candidatos(regras, tipo) do
    Enum.find_value(regras, :unknown, fn regra ->
      case conceitos_do_tipo(regra, tipo) do
        [] -> nil
        conceitos -> {conceitos, regra}
      end
    end)
  end

  # Duas formas de declarar, e as duas são lidas: `type_mapping` na regra do tenant,
  # `routes` na global. Ler só uma faria a precedência existir no documento e não no
  # código — foi o defeito que o teste dos seis casos reais achou.
  defp conceitos_do_tipo(regra, tipo) do
    do_tenant =
      for entrada <- regra["type_mapping"] || [],
          entrada["github_type"] == tipo,
          conceito <- entrada["concepts"],
          do: conceito

    do_global =
      for rota <- regra["routes"] || [],
          tipo in (get_in(rota, ["when", "issue_type_in"]) || []),
          do: rota["target_concept"]

    Enum.uniq(do_tenant ++ do_global)
  end

  defp decidir(conceitos, regra, issue, regras) do
    base = %{vazio(regras) | rule_id: regra["id"], rule_version: regra["version"]}
    declarado = declarado(conceitos)
    derivado = derivado(conceitos, issue)

    %{
      base
      | declared: declarado,
        derived: derivado,
        divergence: motivo(declarado, derivado),
        divergence_kind: tipo_de_divergencia(declarado, derivado)
    }
  end

  # O rótulo afirma um conceito só quando a regra lhe dá um só. Um tipo que cobre épico
  # e atômica não afirma nada sobre qual — e não pode divergir do que não afirmou.
  defp declarado([conceito]), do: conceito
  defp declarado(_ambiguos), do: nil

  defp derivado(conceitos, issue) do
    tem_epico = @epico in conceitos
    tem_atomica = @atomica in conceitos

    cond do
      tem_epico and tem_atomica -> por_estrutura(issue)
      tem_epico -> se_tem_partes(issue, @epico, @atomica)
      # Um tipo que a regra lista só como atômica ainda vira épico quando TEM partes
      # que são user stories. Não é invenção: o `precedence_rationale` da regra global
      # diz exatamente isso — "issue tipo User Story com sub-issues que também são user
      # stories → promovida a sro.epic. A composição a torna épico, independentemente
      # do rótulo". Sem esta cláusula a precedência existiria no YAML e não no código.
      tem_atomica -> se_tem_partes(issue, @epico, @atomica)
      true -> hd(conceitos)
    end
  end

  defp por_estrutura(issue), do: if(partes_user_story(issue) > 0, do: @epico, else: @atomica)

  # `sro.rule05`: épico tem ao menos uma parte. Um tipo que afirma épico sem partes cai
  # para atômica, e a divergência fica registrada.
  defp se_tem_partes(issue, sim, nao),
    do: if(partes_user_story(issue) > 0, do: sim, else: nao)

  # Só partes que **são user stories** compõem. Tarefa atende, não compõe — e é aqui
  # que a distinção vive, num lugar só.
  defp partes_user_story(issue) do
    tarefas = issue[:task_type_names] || ["Task", "Tarefa"]

    (issue[:sub_issue_types] || [])
    |> Enum.reject(&(is_nil(&1) or &1 in tarefas))
    |> length()
  end

  # O tipo classifica o que a frase explica. Os dois primeiros são **axioma aplicado** — a
  # plataforma mudou o conceito e diz por quê; e essa diferença em relação ao mero sinal é
  # o que fica consultável.
  defp tipo_de_divergencia(declarado, derivado) when declarado in [nil, derivado], do: nil
  defp tipo_de_divergencia(@epico, @atomica), do: "epic_without_parts"
  defp tipo_de_divergencia(@atomica, @epico), do: "composition_makes_epic"
  defp tipo_de_divergencia(_declarado, _derivado), do: "label_vs_structure"

  defp motivo(declarado, derivado) when declarado in [nil, derivado], do: nil

  # As frases vão para a tela, e por isso são em inglês.
  defp motivo(@epico, @atomica),
    do:
      "the type said epic and the issue has no parts that are user stories; " <>
        "there is no epic without parts (sro.rule05)"

  defp motivo(@atomica, @epico),
    do:
      "the type said atomic user story and the issue has parts that are user stories; " <>
        "composition makes it an epic (sro.rule05)"

  defp motivo(declarado, derivado),
    do: "the type said #{declarado} and the structure decided #{derivado}"
end
