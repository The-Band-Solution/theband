defmodule TheBand.Ontology.SEON.SPO.ItemPhase do
  @moduledoc """
  A declaração do que cada coluna do quadro significa, e a fase que dela decorre — feature 066.

  ## Nada de fase é gravado no item

  A resolução acontece **na leitura**, como em `spo.criterion_determines_start`. Gravar a fase
  no item faria revogar uma declaração deixar para trás milhares de linhas afirmando o que
  ninguém mais declara — e redeclarar exigiria reescrevê-las.

  ## Propor não é decidir

  `vocabulario/2` devolve **toda** opção observada do campo, na ordem observada, com a contagem
  de hoje. Uma opção sem declaração cujo nome casa o vocabulário reconhecido vem com
  `proposta` — e proposta **não vale**: nada muda enquanto ninguém ativa, com autor e instante.
  É o mesmo gesto do catálogo de mapeamento.
  """

  import Ecto.Query

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.SPO.Schemas.ItemPhaseDeclaration, as: Declaracao
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @regra "github.project_item_status"

  @type recusa :: :conceito_nao_admitido | :opcao_nao_observada | :nao_encontrada

  # ------------------------------------------------------------------ comandos

  @doc """
  Declara o que uma opção significa. Declarar sobre uma opção que já tem declaração vigente
  **revoga a anterior e cria a nova na mesma transação** — a tela chama isso de *Replace*.

  Numa transação porque as duas escritas são um ato só: revogar sem criar deixaria a coluna
  sem significado, e criar sem revogar bateria no índice dos vigentes.
  """
  @spec declarar(Tenant.t(), map(), Ecto.UUID.t()) ::
          {:ok, Declaracao.t()} | {:error, Ecto.Changeset.t() | recusa()}
  def declarar(%Tenant{id: tenant_id}, attrs, ator_id) do
    agora = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      attrs
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.merge(%{
        "tenant_id" => tenant_id,
        "declared_by_user_id" => ator_id,
        "declared_at" => agora
      })

    anteriores =
      from(d in Declaracao,
        where:
          d.tenant_id == ^tenant_id and
            d.observed_project_id == ^attrs["observed_project_id"] and
            d.field_external_id == ^attrs["field_external_id"] and
            d.option_external_id == ^attrs["option_external_id"] and
            is_nil(d.revoked_at)
      )

    # `Repo.transaction/1` com `rollback`, como o resto da casa — e não `Ecto.Multi`, que
    # não aparece em lugar nenhum deste código e cujo termo opaco o dialyzer recusa aqui.
    Repo.transaction(fn ->
      Repo.update_all(anteriores,
        set: [revoked_at: agora, revoked_by_user_id: ator_id, updated_at: agora]
      )

      case Repo.insert(Declaracao.declarar_changeset(%Declaracao{}, attrs)) do
        {:ok, declaracao} -> declaracao
        {:error, motivo} -> Repo.rollback(motivo)
      end
    end)
  end

  @doc "Revoga uma declaração vigente. Marca — e nunca apaga."
  @spec revogar(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Declaracao.t()} | {:error, :nao_encontrada | Ecto.Changeset.t()}
  def revogar(%Tenant{id: tenant_id}, declaracao_id, ator_id) do
    agora = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.one(
           from(d in Declaracao,
             where: d.tenant_id == ^tenant_id and d.id == ^declaracao_id and is_nil(d.revoked_at)
           )
         ) do
      nil ->
        {:error, :nao_encontrada}

      declaracao ->
        declaracao
        |> Declaracao.revogar_changeset(%{revoked_by_user_id: ator_id, revoked_at: agora})
        |> Repo.update()
    end
  end

  # ------------------------------------------------------------------ consultas

  @doc "As declarações vigentes de um quadro."
  @spec vigentes(Tenant.t(), Ecto.UUID.t()) :: [Declaracao.t()]
  def vigentes(%Tenant{id: tenant_id}, quadro_id) do
    Repo.all(
      from(d in Declaracao,
        where:
          d.tenant_id == ^tenant_id and d.observed_project_id == ^quadro_id and
            is_nil(d.revoked_at),
        order_by: [asc: d.declared_at]
      )
    )
  end

  @doc """
  As revogadas — a tela as mostra **sob** a vigente, porque "revogar marca" precisa de forma
  na tela e não só no banco.
  """
  @spec revogadas(Tenant.t(), Ecto.UUID.t()) :: [Declaracao.t()]
  def revogadas(%Tenant{id: tenant_id}, quadro_id) do
    Repo.all(
      from(d in Declaracao,
        where:
          d.tenant_id == ^tenant_id and d.observed_project_id == ^quadro_id and
            not is_nil(d.revoked_at),
        order_by: [desc: d.revoked_at]
      )
    )
  end

  @doc """
  O vocabulário observado de um campo de seleção única, na ordem observada, com a contagem de
  hoje, a declaração vigente e a proposta.

  **Toda** opção aparece — inclusive as que ninguém declarou e as que o vocabulário não
  reconhece. Esconder uma opção faria a tela mentir por omissão sobre o que o quadro tem.
  """
  @spec vocabulario(Tenant.t(), Ecto.UUID.t(), String.t()) :: [map()]
  def vocabulario(%Tenant{id: tenant_id} = tenant, quadro_id, field_external_id) do
    declaracoes =
      tenant
      |> vigentes(quadro_id)
      |> Enum.filter(&(&1.field_external_id == field_external_id))
      |> Map.new(&{&1.option_external_id, &1})

    revogadas_por_opcao =
      tenant
      |> revogadas(quadro_id)
      |> Enum.filter(&(&1.field_external_id == field_external_id))
      |> Enum.group_by(& &1.option_external_id)

    contagens = contagem_por_opcao(tenant_id, quadro_id, field_external_id)

    for {opcao, posicao} <- Enum.with_index(opcoes(tenant_id, quadro_id, field_external_id)) do
      id = opcao["id"]
      nome = opcao["name"]
      declaracao = Map.get(declaracoes, id)
      contagem = Map.get(contagens, id, %{itens: 0, abertas: 0, fechadas: 0})

      %{
        field_external_id: field_external_id,
        option_external_id: id,
        option_name: nome,
        position: posicao,
        itens: contagem.itens,
        abertas: contagem.abertas,
        fechadas: contagem.fechadas,
        declaracao: declaracao,
        revogadas: Map.get(revogadas_por_opcao, id, []),
        proposta: if(is_nil(declaracao), do: proposta_para(nome))
      }
    end
  end

  @doc """
  O destino que o vocabulário reconhecido propõe para um nome de opção, ou `nil`.

  Comparação sem caixa e sem acento, como a regra declara. A lista é curta de propósito e erra
  para o lado de **não** propor: propor onde ninguém sabe seria escolher.
  """
  @spec proposta_para(String.t()) :: String.t() | nil
  def proposta_para(nome) when is_binary(nome) do
    alvo = normalizar(nome)

    case KnowledgeBase.rule(@regra) do
      {:ok, %{"proposes" => %{"values" => valores}}} -> destino_para(valores, alvo)
      _ -> nil
    end
  end

  def proposta_para(_), do: nil

  defp destino_para(valores, alvo) do
    Enum.find_value(valores, fn {destino, nomes} ->
      if Enum.any?(nomes, &(normalizar(&1) == alvo)), do: destino
    end)
  end

  @doc """
  A fase de cada item, derivada na leitura — **uma consulta** para qualquer número de itens.

  Devolve uma afirmação **por quadro** em que o item está: o item pode estar em dois quadros
  com declarações contrárias, e escolher uma seria sintetizar o que a casa recusa sintetizar.
  """
  @spec de_itens(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => [map()]}
  def de_itens(_tenant, []), do: %{}

  def de_itens(%Tenant{id: tenant_id}, issue_ids) do
    """
    SELECT pi.collected_issue_id,
           op.id            AS quadro_id,
           op.title         AS quadro_title,
           v.raw_value->>'name'     AS estagio,
           v.raw_value->>'optionId' AS opcao_id,
           d.target_concept AS fase
      FROM project_items pi
      JOIN observed_projects op ON op.id = pi.observed_project_id
      JOIN item_field_values v  ON v.project_item_id = pi.id
      JOIN project_field_definitions f ON f.id = v.project_field_definition_id
      LEFT JOIN spo_item_phase_declarations d
             ON d.tenant_id = pi.tenant_id
            AND d.observed_project_id = pi.observed_project_id
            AND d.field_external_id = f.field_external_id
            AND d.option_external_id = v.raw_value->>'optionId'
            AND d.revoked_at IS NULL
     WHERE pi.tenant_id = $1
       AND pi.collected_issue_id = ANY($2)
       AND f.data_type = 'SINGLE_SELECT'
       AND v.raw_value->>'optionId' IS NOT NULL
    """
    |> Repo.query!([Ecto.UUID.dump!(tenant_id), Enum.map(issue_ids, &Ecto.UUID.dump!/1)])
    |> then(fn %{rows: linhas} ->
      linhas
      |> Enum.map(fn [issue, quadro, titulo, estagio, opcao, fase] ->
        {Ecto.UUID.cast!(issue),
         %{
           quadro_id: Ecto.UUID.cast!(quadro),
           quadro_title: titulo,
           estagio: estagio,
           opcao_id: opcao,
           fase: fase
         }}
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    end)
  end

  @doc """
  O desacordo do quadro: itens concluídos pelo quadro e **abertos** na origem, e fechados na
  origem e **não** concluídos pelo quadro.

  Sem declaração de conclusão, devolve `:nao_declarado` — e a tela escreve a ausência. Zero
  seria mentira: não é que não haja desacordo, é que não há definição.
  """
  @spec desacordo(Tenant.t(), Ecto.UUID.t()) ::
          %{concluidas_abertas: non_neg_integer(), fechadas_nao_concluidas: non_neg_integer()}
          | :nao_declarado
  def desacordo(%Tenant{id: tenant_id} = tenant, quadro_id) do
    concluidas =
      tenant
      |> vigentes(quadro_id)
      |> Enum.filter(&(&1.target_concept == "spo.performed_project_activity.concluida"))

    if concluidas == [] do
      :nao_declarado
    else
      opcoes_concluidas = Enum.map(concluidas, & &1.option_external_id)

      %{rows: [[abertas, fechadas]]} =
        Repo.query!(
          """
          SELECT
            COUNT(*) FILTER (WHERE v.raw_value->>'optionId' = ANY($3) AND ci.state = 'OPEN'),
            COUNT(*) FILTER (WHERE NOT (v.raw_value->>'optionId' = ANY($3)) AND ci.state = 'CLOSED')
            FROM project_items pi
            JOIN collected_issues ci ON ci.id = pi.collected_issue_id
            JOIN item_field_values v ON v.project_item_id = pi.id
            JOIN project_field_definitions f ON f.id = v.project_field_definition_id
           WHERE pi.tenant_id = $1 AND pi.observed_project_id = $2
             AND f.data_type = 'SINGLE_SELECT' AND v.raw_value->>'optionId' IS NOT NULL
          """,
          [Ecto.UUID.dump!(tenant_id), Ecto.UUID.dump!(quadro_id), opcoes_concluidas]
        )

      %{concluidas_abertas: abertas, fechadas_nao_concluidas: fechadas}
    end
  end

  # ------------------------------------------------------------------ privadas

  defp opcoes(tenant_id, quadro_id, field_external_id) do
    Repo.one(
      from(f in "project_field_definitions",
        where:
          f.tenant_id == type(^tenant_id, :binary_id) and
            f.observed_project_id == type(^quadro_id, :binary_id) and
            f.field_external_id == ^field_external_id,
        select: f.options
      )
    ) || []
  end

  defp contagem_por_opcao(tenant_id, quadro_id, field_external_id) do
    %{rows: linhas} =
      Repo.query!(
        """
        SELECT v.raw_value->>'optionId',
               COUNT(*),
               COUNT(*) FILTER (WHERE ci.state = 'OPEN'),
               COUNT(*) FILTER (WHERE ci.state = 'CLOSED')
          FROM project_items pi
          JOIN item_field_values v ON v.project_item_id = pi.id
          JOIN project_field_definitions f ON f.id = v.project_field_definition_id
          LEFT JOIN collected_issues ci ON ci.id = pi.collected_issue_id
         WHERE pi.tenant_id = $1 AND pi.observed_project_id = $2
           AND f.field_external_id = $3 AND v.raw_value->>'optionId' IS NOT NULL
         GROUP BY 1
        """,
        [Ecto.UUID.dump!(tenant_id), Ecto.UUID.dump!(quadro_id), field_external_id]
      )

    Map.new(linhas, fn [id, itens, abertas, fechadas] ->
      {id, %{itens: itens, abertas: abertas, fechadas: fechadas}}
    end)
  end

  defp normalizar(texto) do
    texto
    |> String.downcase()
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/[\x{0300}-\x{036f}]/u, "")
    |> String.replace(~r/[\s_-]+/u, " ")
    |> String.trim()
  end
end
