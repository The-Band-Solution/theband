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

  ## O caso que erra quem não lê a regra

  Sub-issues do tipo **tarefa** não tornam a issue épica. Tarefa **atende** a user
  story (`sro.intended_task_planned_to_meet_user_story`), não a compõe. No dado real
  desta organização, três `Feature` com sub-issues são atômicas por isso — e errar aqui
  faz 78 tarefas se ligarem a épicos, violando `sro.rule07`.
  """

  alias TheBand.Ontology.KnowledgeBase

  @global "github.issue_type_routing"
  @epico "sro.epic"
  @atomica "sro.atomic_user_story"

  @typedoc "O que a regra decidiu sobre uma issue."
  @type decision :: %{
          declared: String.t() | nil,
          derived: String.t() | nil,
          divergence: String.t() | nil,
          skip_reason: String.t() | nil,
          skip_detail: String.t() | nil,
          rule_id: String.t(),
          rule_version: pos_integer()
        }

  @doc """
  Decide o conceito de uma issue a partir do tipo declarado e da estrutura.

  `issue` precisa de `:issue_type` e `:sub_issue_types` — a lista de tipos das partes.
  A segunda é o que distingue épico de atômica, e sem ela a distinção não é possível.

  `opts[:tenant_rule_id]` põe a regra da organização à frente da global.
  """
  @spec decide(map(), keyword()) :: decision()
  def decide(issue, opts \\ []) do
    regras = carregar(opts)
    tipo = issue[:issue_type]

    case candidatos(regras, tipo) do
      :type_absent -> vazio(regras) |> Map.put(:skip_reason, "type_absent")
      :unknown -> vazio(regras) |> Map.merge(%{skip_reason: "type_unknown", skip_detail: tipo})
      {conceitos, regra} -> decidir(conceitos, regra, issue, regras)
    end
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
      skip_reason: nil,
      skip_detail: nil,
      rule_id: regra["id"],
      rule_version: regra["version"]
    }
  end

  defp candidatos(_regras, nil), do: :type_absent

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

    %{base | declared: declarado, derived: derivado, divergence: motivo(declarado, derivado)}
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

  defp motivo(declarado, derivado) when declarado in [nil, derivado], do: nil

  defp motivo(@epico, @atomica),
    do:
      "tipo indicava épico e a issue não tem partes que sejam user stories; " <>
        "não existe épico sem partes (sro.rule05)"

  defp motivo(@atomica, @epico),
    do:
      "tipo indicava user story atômica e a issue tem partes que são user stories; " <>
        "a composição a torna épico (sro.rule05)"

  defp motivo(declarado, derivado),
    do: "tipo indicava #{declarado} e a estrutura decidiu #{derivado}"
end
