defmodule TheBand.Ontology.Continuum.SRO.Commands do
  @moduledoc """
  Escritas de SRO. Implementação; a fronteira é `TheBand.Ontology.Continuum.SRO`.
  """

  import Ecto.Query

  alias TheBand.Ontology.Continuum.SRO.Schemas.Sprint
  alias TheBand.Ontology.Continuum.SRO.Schemas.SprintIssue
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @doc """
  Grava ou atualiza uma caixa de tempo observada.

  **`:updated` existe aqui**, ao contrário de `SPO.record_activity/2`: uma caixa de tempo
  muda. Alguém renomeia `Sprint 38`, corrige a data de início, e a iteração passa de em
  curso a concluída.

  `ended_on` **não é entrada** — é derivado de início mais duração.
  """
  @spec record_sprint(Tenant.t(), map()) :: {:ok, Sprint.t()} | {:error, Ecto.Changeset.t()}
  def record_sprint(%Tenant{id: tenant_id}, attrs) do
    attrs =
      attrs
      |> normalizar()
      |> Map.put(:tenant_id, tenant_id)
      |> derivar_fim()

    attrs = Map.put(attrs, :internal_id, Sprint.internal_id(attrs))

    case Repo.get_by(Sprint, tenant_id: tenant_id, internal_id: attrs[:internal_id]) do
      nil -> gravar(%Sprint{}, attrs, :created)
      existente -> atualizar(existente, attrs)
    end
  end

  @doc """
  Associa uma issue a uma caixa de tempo.

  Idempotente, e **a mesma issue em duas caixas produz dois vínculos** — é o caso medido
  em 2026-08-15, e não a exceção.
  """
  @spec place_issue_in_sprint(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, SprintIssue.t()} | {:error, Ecto.Changeset.t()}
  def place_issue_in_sprint(%Tenant{id: tenant_id}, sprint_id, collected_issue_id) do
    agora = DateTime.utc_now(:second)

    chave = [
      tenant_id: tenant_id,
      sprint_id: sprint_id,
      collected_issue_id: collected_issue_id
    ]

    case Repo.get_by(SprintIssue, chave) do
      nil ->
        %SprintIssue{}
        |> SprintIssue.changeset(
          Map.merge(Map.new(chave), %{observed_at: agora, last_observed_at: agora})
        )
        |> Repo.insert()
        |> com_resultado(:created)

      existente ->
        # Revê-lo **limpa** a marca de ausência: a issue voltou ao sprint, e manter a
        # marca faria a listagem esconder um vínculo que existe.
        existente
        |> SprintIssue.changeset(%{last_observed_at: agora, no_longer_observed_at: nil})
        |> Repo.update()
        |> com_resultado(if(existente.no_longer_observed_at, do: :updated, else: :unchanged))
    end
  end

  @doc """
  Marca como ausentes os vínculos daquele sprint que a execução **não** observou.

  **Escopado ao sprint**, e nunca ao tenant: marcar por tenant atingiria caixas que a
  execução nunca olhou, que é a **L19** — na feature 020 o mesmo descuido teria marcado
  4261 vínculos falsos.

  Lista vazia devolve zero sem tocar em nada: um sprint sem issue observada nesta
  execução pode ser um sprint que a coleta não percorreu.
  """
  @spec mark_issues_no_longer_in_sprint(
          Tenant.t(),
          Ecto.UUID.t(),
          [Ecto.UUID.t()],
          DateTime.t()
        ) :: {:ok, non_neg_integer()}
  def mark_issues_no_longer_in_sprint(%Tenant{}, _sprint_id, [], _desde), do: {:ok, 0}

  def mark_issues_no_longer_in_sprint(%Tenant{id: tenant_id}, sprint_id, observadas, desde) do
    {quantos, _} =
      from(v in SprintIssue,
        where:
          v.tenant_id == ^tenant_id and v.sprint_id == ^sprint_id and
            v.collected_issue_id not in ^observadas and
            is_nil(v.no_longer_observed_at)
      )
      |> Repo.update_all(set: [no_longer_observed_at: desde, updated_at: desde])

    {:ok, quantos}
  end

  # ------------------------------------------------------------------------ privadas

  defp gravar(struct, attrs, resultado) do
    struct
    |> Sprint.changeset(attrs)
    |> Repo.insert()
    |> com_resultado(resultado)
  end

  # `:unchanged` só quando nada mudou de verdade — comparar campo a campo é o que
  # impede a contagem da execução dizer que tudo foi atualizado a cada coleta.
  defp atualizar(existente, attrs) do
    changeset = Sprint.changeset(existente, attrs)

    resultado = if changeset.changes == %{}, do: :unchanged, else: :updated

    changeset
    |> Repo.update()
    |> com_resultado(resultado)
  end

  defp derivar_fim(%{started_on: inicio, duration_days: dias} = attrs)
       when not is_nil(inicio) and is_integer(dias) and dias > 0 do
    Map.put(attrs, :ended_on, Sprint.ended_on(inicio, dias))
  end

  defp derivar_fim(attrs), do: attrs

  defp com_resultado({:ok, registro}, resultado), do: {:ok, %{registro | outcome: resultado}}
  defp com_resultado(outro, _resultado), do: outro

  defp normalizar(attrs) do
    Map.new(attrs, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
