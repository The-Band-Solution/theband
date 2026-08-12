defmodule TheBand.Mapping.Decision do
  @moduledoc """
  Decide o conceito de um lote de issues — **o caminho único da prévia e do recálculo**.

  A prévia conta; o recálculo grava. Fora isso, é a mesma função sobre os mesmos dados.

  Duas implementações fariam a prévia mentir: alguém aprovaria uma regra vendo "3 issues
  mudariam" e reclassificaria 900. É o SC-007, e ele exige que a diferença entre prévia e
  efeito seja **zero**.

  ## Por que os tipos das partes vêm junto

  A classificação épico/atômica depende das partes, e decidir sem elas daria atômica para
  tudo. O grafo vem numa consulta e a decisão é em memória — uma consulta por issue seriam
  4471 idas ao banco.

  ## A terceira etapa: a estrutura

  Depois do tipo declarado e da regra de título, o que sobra é classificado pela **posição
  no grafo de decomposição**:

      folha                       → tarefa
      só tem partes que são tarefas → user story atômica
      tem parte que é user story    → épico

  É a regra que a pessoa mantenedora enunciou, e está declarada em
  `rules/github_issue_structure_routing.yaml`.

  **É a evidência mais fraca, e vem por último por isso.** Uma folha pode ser uma tarefa, e
  pode ser uma user story que ninguém decompôs — a estrutura não distingue as duas. Grava
  confiança `low`, e qualquer tipo declarado a vence.

  A resolução é de baixo para cima e **memoizada**: o conceito de um pai depende do dos
  filhos, e sem memória a mesma subárvore seria recalculada por ramo.
  """

  alias TheBand.Mapping
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems

  @tenant_rule "github.issue_type_routing.the_band_solution"
  @regra_estrutural "github.issue_structure_routing"
  @tarefa "sro.intended_scrum_development_task"
  @atomica "sro.atomic_user_story"
  @epico "sro.epic"
  # O limite existe para o caso patológico de o grafo já estar cíclico no banco — inserido
  # por script ou por versão anterior à recusa de ciclo. Sem ele, a subida não terminaria.
  @profundidade_maxima 10

  @typedoc "O que a decisão produziu para uma issue."
  @type resultado :: %{issue: map(), decisao: map()}

  @doc """
  Decide para todas as issues da organização, com as regras informadas.

  `regras` vem por parâmetro para que a prévia possa passar uma regra **que ainda não foi
  gravada** — é exatamente o que a prévia é: o efeito de uma regra antes de ela existir.
  """
  @spec decidir_lote(Tenant.t(), Ecto.UUID.t(), [struct()]) :: [resultado()]
  def decidir_lote(%Tenant{} = tenant, organization_id, regras) do
    issues = Mapping.issues_for_decision(tenant, organization_id)
    tipos = tipos_das_partes(tenant, issues)

    declaradas =
      Enum.map(issues, fn issue ->
        decisao =
          WorkItems.decide(
            %{
              issue_type: issue.issue_type,
              title: issue.title,
              sub_issue_types: Map.get(tipos, issue.id, [])
            },
            tenant_rule_id: @tenant_rule,
            organization_rules: regras
          )

        %{issue: issue, decisao: decisao}
      end)

    completar_por_estrutura(tenant, declaradas)
  end

  @doc """
  Preenche, **pela estrutura**, o que as duas primeiras etapas não decidiram — e **registra
  a divergência** quando o que elas decidiram discorda da estrutura.

  ## Por que não trocar o conceito

  Medido no dado real: 9 issues com título `[TASK]` têm partes, e 319 com título `[US` ou
  `[FEATURE]` são folhas. Fazer a estrutura vencer custaria **319 declarações do time**
  para consertar **9** — e o erro seria do tipo pior, silencioso e em massa, porque uma
  user story que ninguém decompôs é indistinguível de uma tarefa.

  ## Por que nem sequer seria correto

  `sro.rule05` é axioma e a plataforma já o aplica: não há épico sem partes, e a composição
  torna épico. Mas **nenhum axioma proíbe tarefa com partes** — `sro.rule07` proíbe tarefa
  *atender* épico, que é a relação de atendimento, não a de composição. Tarefa com
  sub-issues é **não modelada**, e não inválida.

  Trocar o conceito por causa disso seria a plataforma inventando axioma.

  ## O que ela faz

  Registra em `divergence_reason` — o mesmo campo que já diz "o rótulo e a estrutura
  discordam" para épico sem partes. Vira sinal sobre o processo do time, visível na issue e
  na lista de divergências, e nada é corrigido em silêncio.
  """
  @spec completar_por_estrutura(Tenant.t(), [resultado()]) :: [resultado()]
  def completar_por_estrutura(%Tenant{} = tenant, resultados) do
    filhos =
      tenant
      |> WorkItems.list_links()
      |> Enum.group_by(& &1.parent_issue_id, & &1.child_issue_id)

    presentes = MapSet.new(resultados, & &1.issue.id)
    ja_decidido = Map.new(resultados, &{&1.issue.id, &1.decisao.derived})
    versao = versao_da_regra()

    {finais, _memoria} =
      Enum.map_reduce(resultados, %{}, fn %{issue: issue, decisao: decisao} = linha, memoria ->
        {conceito, memoria} = por_estrutura(issue.id, filhos, presentes, ja_decidido, memoria, 0)

        decisao =
          if decisao.derived,
            do: anotar_divergencia(decisao, conceito, filhos, presentes, issue.id),
            else: estrutural(decisao, conceito, versao)

        {%{linha | decisao: decisao}, memoria}
      end)

    finais
  end

  # De baixo para cima, com memória: o conceito do pai depende do dos filhos, e sem memória
  # a mesma subárvore seria recalculada uma vez por ramo que a alcança.
  defp por_estrutura(_id, _filhos, _presentes, _decidido, memoria, @profundidade_maxima),
    do: {@tarefa, memoria}

  defp por_estrutura(id, filhos, presentes, decidido, memoria, nivel) do
    case Map.fetch(memoria, id) do
      {:ok, conceito} -> {conceito, memoria}
      :error -> calcular(id, filhos, presentes, decidido, memoria, nivel)
    end
  end

  defp calcular(id, filhos, presentes, decidido, memoria, nivel) do
    # Parte fora do escopo observado tem vínculo e não tem issue aqui. Contá-la como filha
    # faria a issue virar épico por causa de algo que a plataforma não tem.
    partes =
      filhos
      |> Map.get(id, [])
      |> Enum.filter(&MapSet.member?(presentes, &1))

    {conceito, memoria} =
      case partes do
        [] -> {@tarefa, memoria}
        _ -> conceito_das_partes(partes, filhos, presentes, decidido, memoria, nivel)
      end

    {conceito, Map.put(memoria, id, conceito)}
  end

  defp conceito_das_partes(partes, filhos, presentes, decidido, memoria, nivel) do
    {conceitos, memoria} =
      Enum.map_reduce(partes, memoria, fn parte, acc ->
        conceito_da_parte(parte, filhos, presentes, decidido, acc, nivel)
      end)

    {se_compoe(conceitos), memoria}
  end

  defp conceito_da_parte(parte, filhos, presentes, decidido, memoria, nivel) do
    case Map.get(decidido, parte) do
      nil -> por_estrutura(parte, filhos, presentes, decidido, memoria, nivel + 1)
      ja_decidido -> {ja_decidido, memoria}
    end
  end

  # Tarefa **atende**, não compõe. Uma issue cujas partes são todas tarefas é atômica; basta
  # uma parte ser user story ou épico para ela ser épico — é o `sro.rule05`.
  defp se_compoe(conceitos) do
    if Enum.any?(conceitos, &(&1 in [@atomica, @epico])), do: @epico, else: @atomica
  end

  # A divergência é **acrescentada**, nunca substitui a que já existe: a de `sro.rule05`
  # explica a mesma issue por outro ângulo, e apagá-la perderia informação.
  defp anotar_divergencia(decisao, estrutural, filhos, presentes, id) do
    partes =
      filhos
      |> Map.get(id, [])
      |> Enum.filter(&MapSet.member?(presentes, &1))
      |> length()

    case divergencia_estrutural(decisao.derived, estrutural, partes) do
      nil ->
        decisao

      {tipo, motivo} ->
        %{
          decisao
          | divergence: juntar(decisao.divergence, motivo),
            # O tipo do axioma aplicado tem precedência sobre o do sinal: quando as duas
            # divergências existem, a que mudou o conceito é a que classifica a linha.
            divergence_kind: decisao.divergence_kind || tipo
        }
    end
  end

  defp divergencia_estrutural(mesmo, mesmo, _partes), do: nil

  defp divergencia_estrutural(@tarefa, _estrutural, partes) when partes > 0,
    do:
      {"task_with_parts",
       "classificada como tarefa e tem #{partes} #{plural(partes)} coletada#{if partes > 1, do: "s"}; " <>
         "tarefa com partes não é modelada pela SRO — o conceito foi mantido, e isto é " <>
         "sinal sobre como o time escreve as issues"}

  defp divergencia_estrutural(@atomica, @tarefa, 0),
    do:
      {"user_story_without_parts",
       "classificada como user story atômica e não tem partes nem tarefas coletadas ligadas " <>
         "a ela; pode ser user story ainda não decomposta, e por isso o conceito foi mantido"}

  defp divergencia_estrutural(_derivado, _estrutural, _partes), do: nil

  defp plural(1), do: "parte"
  defp plural(_), do: "partes"

  defp juntar(nil, motivo), do: motivo
  defp juntar(existente, motivo), do: existente <> "; e " <> motivo

  defp estrutural(base, conceito, versao) do
    %{
      base
      | derived: conceito,
        declared: nil,
        divergence: nil,
        divergence_kind: nil,
        skip_reason: nil,
        skip_detail: nil,
        rule_id: @regra_estrutural,
        rule_version: versao,
        evidence_source: "structure",
        confidence: "low"
    }
  end

  defp versao_da_regra do
    case KnowledgeBase.rule(@regra_estrutural) do
      {:ok, regra} -> regra["version"]
      :error -> 1
    end
  end

  @doc """
  As regras vigentes da organização, com uma **candidata** inserida na posição dela.

  A candidata entra ordenada, e não no fim: a prévia precisa mostrar o efeito da regra
  **na posição em que ela vai valer**. Mostrá-la no fim daria um número e gravar daria
  outro, quando alguma regra anterior casasse as mesmas issues.
  """
  @spec com_candidata(Tenant.t(), Ecto.UUID.t(), struct() | nil) :: [struct()]
  def com_candidata(tenant, organization_id, nil),
    do: Mapping.active_rules(tenant, organization_id)

  def com_candidata(tenant, organization_id, candidata) do
    tenant
    |> Mapping.active_rules(organization_id)
    |> Enum.reject(&(&1.id == candidata.id))
    |> Kernel.++([candidata])
    |> Enum.sort_by(& &1.position)
  end

  @doc """
  Se a decisão **muda o conceito** da issue em relação à promoção vigente.

  É o número que interessa a quem lê a prévia: FR-022 pergunta quantas issues *mudariam de
  conceito*, e não quantas linhas serão escritas.
  """
  @spec mudou_conceito?(map(), map() | nil) :: boolean()
  def mudou_conceito?(decisao, nil), do: not is_nil(decisao.derived)
  def mudou_conceito?(decisao, vigente), do: decisao.derived != vigente.derived_concept

  @doc """
  Se a decisão difere da vigente em **qualquer aspecto registrado**.

  Diferente de `mudou_conceito?/2`, e a diferença é real: uma issue pode manter o conceito
  e mudar a proveniência — foi decidida pela regra da organização em vez da regra global.
  Isso é fato novo, e append-only o registra.

  As duas funções existem porque os dois números são diferentes, e **as duas são usadas
  pela prévia e pelo recálculo**. Uma comparação em cada lugar foi o defeito que o teste do
  SC-007 pegou: a prévia dizia 1 e o recálculo gravava 90.
  """
  @spec mudou_registro?(map(), map() | nil) :: boolean()
  def mudou_registro?(_decisao, nil), do: true

  def mudou_registro?(decisao, vigente) do
    decisao.derived != vigente.derived_concept or
      decisao.skip_reason != vigente.skip_reason or
      decisao.mapping_rule_id != vigente.mapping_rule_id or
      decisao.evidence_source != vigente.evidence_source
  end

  defp tipos_das_partes(tenant, issues) do
    por_id = Map.new(issues, &{&1.id, &1.issue_type})

    tenant
    |> WorkItems.list_links()
    |> Enum.group_by(& &1.parent_issue_id, &por_id[&1.child_issue_id])
  end
end
