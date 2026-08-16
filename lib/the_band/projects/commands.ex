defmodule TheBand.Projects.Commands do
  @moduledoc """
  Escrita dos quadros, campos, itens e valores — feature 004 F7. Privado à fronteira
  `TheBand.Projects`.

  Toda escrita é idempotente pela Application Reference ou pela identidade declarada,
  e reobservar limpa a marca de ausência — quem devolve vigência é a coleta, como em
  `WorkItems`.
  """

  import Ecto.Query

  alias TheBand.Ontology.Continuum.SRO
  alias TheBand.Ontology.SEON.SPO
  alias TheBand.Projects.Schemas.{FieldDefinition, FieldValue, Item, Iteration, ObservedProject}
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type promotion_target :: {:sprint, Ecto.UUID.t()} | {:intended_process, Ecto.UUID.t()}

  @doc """
  Grava um quadro observado. Idempotente pela Application Reference.

  **Não aceita `spo_project_id` nem campo de promoção algum** — a ausência do parâmetro
  é o que impede alguém promover por engano (FR-020). A assinatura não dá caminho.
  """
  @spec record_observed_project(Tenant.t(), map()) ::
          {:ok, ObservedProject.t()} | {:error, Ecto.Changeset.t()}
  def record_observed_project(%Tenant{id: tenant_id}, attrs) do
    upsert(
      ObservedProject,
      [
        tenant_id: tenant_id,
        source_system: attrs[:source_system],
        source_instance: attrs[:source_instance],
        source_external_id: attrs[:source_external_id]
      ],
      attrs,
      tenant_id
    )
  end

  @doc """
  Grava a definição de um campo configurável.

  **A identidade é `field_external_id`, nunca `name`** (FR-027): renomear atualiza a
  mesma linha, e o mapeamento declarado por tenant sobrevive ao rename.
  """
  @spec record_field_definition(Tenant.t(), map()) ::
          {:ok, FieldDefinition.t()} | {:error, Ecto.Changeset.t()}
  def record_field_definition(%Tenant{id: tenant_id}, attrs) do
    upsert(
      FieldDefinition,
      [
        tenant_id: tenant_id,
        observed_project_id: attrs[:observed_project_id],
        field_external_id: attrs[:field_external_id]
      ],
      attrs,
      tenant_id
    )
  end

  @doc """
  Grava um item do quadro.

  `collected_issue_id` **nulo é aceito**: rascunho não tem issue por trás, e vai com
  `is_draft: true` (FR-022). Registrado, nunca descartado — e nunca promovido.
  """
  @spec record_item(Tenant.t(), map()) :: {:ok, Item.t()} | {:error, Ecto.Changeset.t()}
  def record_item(%Tenant{id: tenant_id}, attrs) do
    upsert(
      Item,
      [
        tenant_id: tenant_id,
        source_system: attrs[:source_system],
        source_instance: attrs[:source_instance],
        source_external_id: attrs[:source_external_id]
      ],
      attrs,
      tenant_id
    )
  end

  @doc """
  Grava o valor de um campo em um item.

  `raw_value` sempre; `interpreted_as` **apenas** quando o chamador o passa a partir de
  mapeamento declarado (FR-025). Esta função não interpreta nada — interpretar por nome
  aqui seria o antipadrão que a FR-024 proíbe.
  """
  @spec record_item_field_value(Tenant.t(), map()) ::
          {:ok, FieldValue.t()} | {:error, Ecto.Changeset.t()}
  def record_item_field_value(%Tenant{id: tenant_id}, attrs) do
    upsert(
      FieldValue,
      [
        tenant_id: tenant_id,
        project_item_id: attrs[:project_item_id],
        project_field_definition_id: attrs[:project_field_definition_id]
      ],
      attrs,
      tenant_id
    )
  end

  @doc """
  Grava uma iteração e devolve **o que ela virou** — o par pretendida/ocorrida.

  A promoção é decidida pela regra `github.iteration_started`: início já passado vira
  `sro.sprint`; futuro vira `spo.specific_intended_project_process`. O retorno diz qual
  foi porque quem chama precisa saber, e reler a linha seria um segundo caminho de
  derivação.

  **A transição pretendida→sprint acontece aqui, na coleta** (FR-030a): a mesma
  identidade externa encontrada já iniciada ganha o sprint e o registro pretendido é
  marcado como não mais observado — nunca apagado.
  """
  @spec record_iteration(Tenant.t(), map()) ::
          {:ok, %{iteration: Iteration.t(), promoted_to: promotion_target()}}
          | {:error, Ecto.Changeset.t()}
  def record_iteration(%Tenant{} = tenant, attrs) do
    if iniciada?(attrs[:start_date]) do
      promover_a_sprint(tenant, attrs)
    else
      promover_a_pretendido(tenant, attrs)
    end
  end

  @doc """
  Marca a iteração removida da configuração do quadro — FR-031.

  Marcada, nunca apagada: apagar destruiria a resposta a "o que foi feito naquele
  sprint" e a "o que foi planejado e nunca aconteceu". Os itens dela **não** voltam ao
  product backlog.
  """
  @spec record_iteration_absent(Tenant.t(), Ecto.UUID.t(), DateTime.t()) ::
          {:ok, Iteration.t()}
  def record_iteration_absent(%Tenant{id: tenant_id}, iteration_id, %DateTime{} = desde) do
    iteracao = Repo.get_by!(Iteration, id: iteration_id, tenant_id: tenant_id)

    iteracao
    |> Iteration.changeset(%{
      no_longer_in_configuration_at: iteracao.no_longer_in_configuration_at || desde
    })
    |> Repo.update()
  end

  # ---------------------------------------------------------------- promoções

  # A condição é a da regra `github.iteration_started`, e é uma só: `startDate` já
  # passou. Não é heurística — é a diferença entre planejado e ocorrido, que SPO e SRO
  # tratam como conceitos distintos no modelo inteiro.
  defp iniciada?(%Date{} = inicio), do: Date.compare(inicio, Date.utc_today()) != :gt

  defp promover_a_sprint(tenant, attrs) do
    with {:ok, sprint} <-
           SRO.record_sprint(tenant, %{
             board_number: attrs[:board_number],
             board_title: attrs[:board_title],
             field_name: attrs[:field_name],
             title: attrs[:title],
             started_on: attrs[:start_date],
             duration_days: attrs[:duration_days],
             completed: attrs[:completed] || false,
             source_system: attrs[:source_system],
             source_instance: attrs[:source_instance],
             source_external_id: attrs[:source_external_id],
             collected_at: attrs[:collected_at]
           }),
         {:ok, iteracao} <- gravar_iteracao(tenant, attrs, sprint_id: sprint.id) do
      transicionar_pretendido(tenant, attrs)
      {:ok, %{iteration: iteracao, promoted_to: {:sprint, sprint.id}}}
    end
  end

  defp promover_a_pretendido(%Tenant{} = tenant, attrs) do
    with {:ok, processo} <-
           SPO.record_intended_process(tenant, %{
             internal_id: attrs[:source_external_id],
             title: attrs[:title],
             planned_start_on: attrs[:start_date],
             duration_days: attrs[:duration_days],
             source_system: attrs[:source_system],
             source_instance: attrs[:source_instance],
             source_external_id: attrs[:source_external_id],
             collected_at: attrs[:collected_at],
             last_observed_at: attrs[:collected_at]
           }),
         {:ok, iteracao} <- gravar_iteracao(tenant, attrs, intended_id: processo.id) do
      {:ok, %{iteration: iteracao, promoted_to: {:intended_process, processo.id}}}
    end
  end

  # A iteração aponta para exatamente um destino. Na transição pretendida→sprint a
  # linha é a MESMA (identidade campo:iteração no quadro) e o destino troca — o
  # registro do processo pretendido permanece, marcado.
  defp gravar_iteracao(%Tenant{id: tenant_id}, attrs, destino) do
    chaves = [
      tenant_id: tenant_id,
      observed_project_id: attrs[:observed_project_id],
      field_external_id: attrs[:field_external_id],
      iteration_external_id: attrs[:iteration_external_id]
    ]

    destino_attrs =
      case destino do
        [sprint_id: id] -> %{sro_sprint_id: id, spo_intended_process_id: nil}
        [intended_id: id] -> %{sro_sprint_id: nil, spo_intended_process_id: id}
      end

    upsert(Iteration, chaves, Map.merge(atomizar(attrs), destino_attrs), tenant_id)
  end

  # FR-030a: a iteração que era pretendida e começou vira sprint na coleta. O registro
  # pretendido não é apagado — é marcado como não mais observado, porque a intenção
  # existiu e a resposta a "o que foi planejado?" precisa dela.
  defp transicionar_pretendido(%Tenant{id: tenant_id}, attrs) do
    from(p in "spo_intended_project_processes",
      where:
        p.tenant_id == ^tenant_id and
          p.source_external_id == ^attrs[:source_external_id] and
          p.source_system == ^attrs[:source_system] and
          is_nil(p.no_longer_observed_at)
    )
    |> Repo.update_all(set: [no_longer_observed_at: attrs[:collected_at]])
  end

  # ---------------------------------------------------------------- upsert comum

  # O mesmo desenho de `WorkItems.record_collected_issue/2`: busca pela identidade,
  # reescreve preservando `collected_at`, e reobservar limpa a marca de ausência.
  defp upsert(schema, chaves, attrs, tenant_id) do
    base = Repo.get_by(schema, chaves) || struct(schema)
    agora = DateTime.utc_now(:second)

    atualizado =
      atomizar(attrs)
      |> Map.take(campos_do(schema))
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:collected_at, base.collected_at || attrs[:collected_at] || agora)
      |> Map.put(:last_observed_at, agora)
      |> limpar_marca(schema)

    base
    |> schema.changeset(atualizado)
    |> Repo.insert_or_update()
  end

  defp limpar_marca(attrs, Iteration), do: attrs
  defp limpar_marca(attrs, FieldValue), do: attrs
  defp limpar_marca(attrs, _schema), do: Map.put(attrs, :no_longer_observed_at, nil)

  defp campos_do(schema), do: schema.__schema__(:fields)

  defp atomizar(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
