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
  """

  alias TheBand.Mapping
  alias TheBand.Tenants.Tenant
  alias TheBand.WorkItems

  @tenant_rule "github.issue_type_routing.the_band_solution"

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
