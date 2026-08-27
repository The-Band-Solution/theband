defmodule TheBand.Projects.Queries do
  @moduledoc """
  Leitura dos quadros, campos, itens e valores — feature 004 F7. Privado à fronteira
  `TheBand.Projects`.

  Toda consulta filtra por tenant na cláusula — princípio V: consulta sem filtro de
  tenant é bug de segurança, não de correção.
  """

  import Ecto.Query

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Projects.Schemas.{FieldDefinition, FieldValue, Item, Iteration, ObservedProject}
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc "Os quadros do tenant, por número."
  @spec list_projects(Tenant.t()) :: [ObservedProject.t()]
  def list_projects(%Tenant{id: tenant_id}) do
    Repo.all(
      from p in ObservedProject,
        where: p.tenant_id == ^tenant_id,
        order_by: [asc: p.number]
    )
  end

  @doc "Um quadro pelo id. De outro tenant devolve `:not_found`, nunca 'sem permissão'."
  @spec get_project(Tenant.t(), Ecto.UUID.t()) ::
          {:ok, ObservedProject.t()} | {:error, :not_found}
  def get_project(%Tenant{id: tenant_id}, id) do
    case Repo.get_by(ObservedProject, id: id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      quadro -> {:ok, quadro}
    end
  end

  @doc "As definições de campo de um quadro, pelo nome."
  @spec list_field_definitions(Tenant.t(), Ecto.UUID.t()) :: [FieldDefinition.t()]
  def list_field_definitions(%Tenant{id: tenant_id}, observed_project_id) do
    Repo.all(
      from f in FieldDefinition,
        where: f.tenant_id == ^tenant_id and f.observed_project_id == ^observed_project_id,
        order_by: [asc: f.name]
    )
  end

  @doc "Os itens de um quadro, com a issue quando houver."
  @spec list_items(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def list_items(%Tenant{id: tenant_id}, observed_project_id) do
    Repo.all(
      from i in Item,
        left_join: c in "collected_issues",
        on: c.id == i.collected_issue_id,
        where: i.tenant_id == ^tenant_id and i.observed_project_id == ^observed_project_id,
        order_by: [desc: i.last_observed_at],
        select: %{
          id: i.id,
          is_draft: i.is_draft,
          collected_issue_id: i.collected_issue_id,
          issue_number: c.number,
          issue_title: c.title,
          issue_state: c.state,
          no_longer_observed_at: i.no_longer_observed_at
        }
    )
  end

  @doc """
  Os valores de campo dos itens de um quadro, com o nome do campo junto.

  `interpreted_as` nulo é *não interpretado* — o caso comum, e a tela o mostra assim
  (FR-025). Nenhum valor é convertido por semelhança de nome.
  """
  @spec item_values(Tenant.t(), Ecto.UUID.t()) :: %{Ecto.UUID.t() => [map()]}
  def item_values(%Tenant{id: tenant_id}, observed_project_id) do
    from(v in FieldValue,
      join: f in FieldDefinition,
      on: f.id == v.project_field_definition_id,
      join: i in Item,
      on: i.id == v.project_item_id,
      where: i.tenant_id == ^tenant_id and i.observed_project_id == ^observed_project_id,
      where: v.tenant_id == ^tenant_id,
      select: %{
        project_item_id: v.project_item_id,
        field_name: f.name,
        field_external_id: f.field_external_id,
        raw_value: v.raw_value,
        interpreted_as: v.interpreted_as
      }
    )
    |> Repo.all()
    |> Enum.group_by(& &1.project_item_id)
  end

  @doc "As iterações de um quadro — a razão-fonte, com o destino de cada uma."
  @spec list_iterations(Tenant.t(), Ecto.UUID.t()) :: [Iteration.t()]
  def list_iterations(%Tenant{id: tenant_id}, observed_project_id) do
    Repo.all(
      from it in Iteration,
        where: it.tenant_id == ^tenant_id and it.observed_project_id == ^observed_project_id,
        order_by: [asc: it.start_date]
    )
  end

  @doc """
  Os quadros do tenant com a evidência para associá-los a um projeto — issue #367.

  Volume, quantas issues seguem abertas e o período que o quadro cobre. É o que falta a
  quem escolhe entre 26 quadros: `Conecta Fapes` tem 938 itens de dez/2025 a ago/2026, e
  `[DEPRECATED] ConectaFapes` tem 196 de fev a jul/2025 — o período mais antigo do mesmo
  projeto, e o que a #367 mostrou sumindo quando só o quadro corrente é lido.

  Mostrar volume e período é informar. **Nenhum quadro vem recomendado**, e o nome não
  decide nada: `[DEPRECATED]` no título é texto da origem, não classificação da
  plataforma — quadro encerrado continua carregando o histórico do projeto.
  """
  @spec boards_with_evidence(Tenant.t()) :: [map()]
  def boards_with_evidence(%Tenant{id: tenant_id}) do
    Repo.all(
      from o in ObservedProject,
        left_join: i in Item,
        on: i.observed_project_id == o.id and is_nil(i.no_longer_observed_at),
        left_join: ci in "collected_issues",
        on: ci.id == i.collected_issue_id,
        where: o.tenant_id == ^tenant_id,
        group_by: o.id,
        order_by: [desc: count(i.id), asc: o.number],
        select: %{
          id: type(o.id, :binary_id),
          number: o.number,
          title: o.title,
          closed: o.closed,
          no_longer_observed_at: o.no_longer_observed_at,
          itens: count(i.id),
          # Abertas é `filter`, e não uma segunda consulta: o total sozinho não distingue
          # o quadro encerrado com tudo fechado do quadro vivo com tudo aberto.
          abertas: filter(count(ci.id), ci.state == "OPEN"),
          primeira: type(min(ci.external_created_at), :utc_datetime),
          ultima: type(max(ci.external_created_at), :utc_datetime)
        }
    )
  end

  @doc """
  Os campos de DATA deste quadro, com quantos itens têm valor — issue #368.

  A evidência para declarar qual é o prazo. A sondagem achou **33 pares (quadro, campo) de
  data em 13 nomes e duas línguas**: `End date` é fim planejado num quadro e fim real
  noutro, `Start date` é começo e não prazo, e `End Date` difere de `End date` só na caixa.

  Mostrar quantos itens preenchem cada campo é informar; recomendar seria escolher, e a
  plataforma não escolhe. Campo sem valor nenhum aparece com zero, e não some: campo vazio
  declarado prazo produz issue sem prazo, que é resposta diferente de campo inexistente.
  """
  @spec date_fields(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def date_fields(%Tenant{id: tenant_id}, observed_project_id) do
    Repo.all(
      from d in FieldDefinition,
        left_join: v in FieldValue,
        on: v.project_field_definition_id == d.id,
        where:
          d.tenant_id == ^tenant_id and d.observed_project_id == ^observed_project_id and
            d.data_type == "DATE" and is_nil(d.no_longer_observed_at),
        group_by: [d.id, d.name],
        order_by: [desc: count(v.id), asc: d.name],
        select: %{
          name: d.name,
          preenchidos: count(v.id)
        }
    )
  end

  @doc "Quantos itens o quadro tem — o total contra o qual a SC-009b soma os backlogs."
  @spec count_items(Tenant.t(), Ecto.UUID.t()) :: non_neg_integer()
  def count_items(%Tenant{id: tenant_id}, observed_project_id) do
    Repo.one(
      from i in Item,
        where:
          i.tenant_id == ^tenant_id and i.observed_project_id == ^observed_project_id and
            is_nil(i.no_longer_observed_at),
        select: count(i.id)
    )
  end

  @doc """
  De onde viria a importância — ou a declaração de que não vem de lugar nenhum.

  Devolve `:not_declared` quando nenhum campo do quadro está mapeado para
  `sro.user_story.importance` — que é o caso deste tenant. A função existe para a tela
  poder **dizer** isso (FR-026): ausência declarada é diferente de ausência silenciosa,
  e nenhum outro campo é promovido a substituto.
  """
  @spec importance_source(Tenant.t(), Ecto.UUID.t()) :: {:mapped, String.t()} | :not_declared
  def importance_source(%Tenant{} = tenant, observed_project_id) do
    mapeamentos = field_mappings(tenant)

    tenant
    |> list_field_definitions(observed_project_id)
    |> Enum.find(fn campo ->
      interpretation_for(mapeamentos, campo.field_external_id, campo.data_type) ==
        "sro.user_story.importance"
    end)
    |> case do
      nil -> :not_declared
      campo -> {:mapped, campo.name}
    end
  end

  @doc """
  O mapeamento campo→atributo declarado na base — `FR-024`, issue #180.

  A regra por tenant sobrescreve a global (`github.project_field_mapping.<slug>`), e a
  global é vazia de propósito: o mapeamento é declaração, nunca inferência de nome.

  Cada entrada é `field_external_id => %{"attribute" => a, "field_type" => t}` — o
  `field_type` é a FR-046 em forma de dado: a coleta recusa interpretar quando o tipo do
  campo não é o declarado. **Ausente devolve mapa vazio**: todo valor cru, não
  interpretado — o caso comum, nunca um erro.
  """
  @spec field_mappings(Tenant.t()) :: %{String.t() => map()}
  def field_mappings(%Tenant{slug: slug}) do
    tenant_rule = "github.project_field_mapping." <> String.replace(slug, "-", "_")

    regra =
      case KnowledgeBase.rule(tenant_rule) do
        {:ok, r} -> {:ok, r}
        :error -> KnowledgeBase.rule("github.project_field_mapping")
      end

    case regra do
      {:ok, r} -> get_in(r, ["rules", "fields", "values"]) || %{}
      :error -> %{}
    end
  end

  @doc """
  O atributo que um campo interpreta — ou `nil`, com a FR-046 aplicada.

  Devolve `nil` em três casos que a tela mostra igual (não interpretado) e o registro
  distingue: sem mapeamento; mapeamento cujo `field_type` declarado difere do tipo real
  do campo — mapear seleção única para atributo numérico é **recusado**, nunca honrado —;
  ou entrada malformada.
  """
  @spec interpretation_for(%{String.t() => map()}, String.t(), String.t()) :: String.t() | nil
  def interpretation_for(mapeamentos, field_external_id, data_type) do
    case mapeamentos[field_external_id] do
      %{"attribute" => atributo} = entrada ->
        if entrada["field_type"] in [nil, data_type], do: atributo

      _ ->
        nil
    end
  end

  @doc """
  O product backlog do quadro — itens **sem** iteração atribuída (FR-032).

  A ausência de iteração é o que o define, não um campo separado. A composição é
  **derivada da atribuição** (FR-032b): gravar pertencimento faria o registro divergir
  da origem no instante em que alguém arrastasse um item no quadro.
  """
  @spec product_backlog(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def product_backlog(%Tenant{id: tenant_id} = tenant, observed_project_id) do
    atribuidos = itens_com_iteracao(tenant_id, observed_project_id)

    tenant
    |> list_items(observed_project_id)
    |> Enum.reject(&(&1.id in atribuidos or &1.no_longer_observed_at != nil))
  end

  @doc """
  O sprint backlog de um sprint — itens atribuídos à iteração dele (FR-032a).

  Recebe o **id do sprint**, e não do quadro: o product backlog é do produto visto por
  aquele quadro; o sprint backlog é de um sprint.
  """
  @spec sprint_backlog(Tenant.t(), Ecto.UUID.t()) :: [map()]
  def sprint_backlog(%Tenant{id: tenant_id} = tenant, sprint_id) do
    case Repo.one(
           from it in Iteration,
             where: it.tenant_id == ^tenant_id and it.sro_sprint_id == ^sprint_id
         ) do
      nil ->
        []

      iteracao ->
        ids = itens_da_iteracao(tenant_id, iteracao)

        tenant
        |> list_items(iteracao.observed_project_id)
        |> Enum.filter(&(&1.id in ids and is_nil(&1.no_longer_observed_at)))
    end
  end

  # A atribuição vive no valor do campo de iteração: `raw_value ->> 'iterationId'`.
  # É a mesma verdade que o quadro mostra — derivada a cada leitura, nunca gravada.
  defp itens_com_iteracao(tenant_id, observed_project_id) do
    from(v in FieldValue,
      join: f in FieldDefinition,
      on: f.id == v.project_field_definition_id,
      join: i in Item,
      on: i.id == v.project_item_id,
      where:
        v.tenant_id == ^tenant_id and i.observed_project_id == ^observed_project_id and
          f.data_type == "ITERATION" and
          not is_nil(fragment("? ->> 'iterationId'", v.raw_value)),
      select: v.project_item_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  defp itens_da_iteracao(tenant_id, iteracao) do
    from(v in FieldValue,
      join: f in FieldDefinition,
      on: f.id == v.project_field_definition_id,
      where:
        v.tenant_id == ^tenant_id and
          f.field_external_id == ^iteracao.field_external_id and
          fragment("? ->> 'iterationId'", v.raw_value) == ^iteracao.iteration_external_id,
      select: v.project_item_id
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
