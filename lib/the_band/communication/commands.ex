defmodule TheBand.Communication.Commands do
  @moduledoc """
  Gravação da nota da comunicação — feature 030.

  O mesmo contrato das demais coletas: upsert idempotente por identidade externa,
  reobservar limpa a marca, sumir marca e nunca apaga.
  """

  alias TheBand.Communication.Schemas.CollectedIssueComment
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  import Ecto.Query

  @doc """
  Grava (ou reobserva) um comentário coletado.

  Devolve `{:ok, comment}`. A identidade é `[tenant, external_id]` — o número da issue
  não participa (L25: número não identifica).
  """
  @spec record_comment(Tenant.t(), map()) ::
          {:ok, CollectedIssueComment.t()} | {:error, Ecto.Changeset.t()}
  def record_comment(%Tenant{id: tenant_id}, attrs) do
    now = DateTime.utc_now(:second)

    base =
      Repo.get_by(CollectedIssueComment,
        tenant_id: tenant_id,
        external_id: attrs[:external_id]
      ) || %CollectedIssueComment{}

    base
    |> CollectedIssueComment.changeset(
      attrs
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put(:collected_at, base.collected_at || now)
      |> Map.put(:last_observed_at, now)
      # Reobservar limpa a marca — quem devolve vigência é a coleta.
      |> Map.put(:no_longer_observed_at, nil)
    )
    |> Repo.insert_or_update()
  end

  @doc """
  Marca como não mais observados os comentários de uma issue que a página completa da
  origem NÃO trouxe de volta. Marca, nunca apaga — comentário apagado na origem some da
  API, e o que a plataforma afirma é "não reobservado", não "não existiu".

  Só é chamada quando a página cobriu a issue inteira (totalCount conferido): com
  truncamento, não marcar nada é a resposta honesta.
  """
  @spec mark_unobserved_comments(Tenant.t(), Ecto.UUID.t(), [String.t()]) :: non_neg_integer()
  def mark_unobserved_comments(%Tenant{id: tenant_id}, collected_issue_id, observed_external_ids) do
    now = DateTime.utc_now(:second)

    {marcados, _} =
      Repo.update_all(
        from(c in CollectedIssueComment,
          where:
            c.tenant_id == ^tenant_id and
              c.collected_issue_id == ^collected_issue_id and
              is_nil(c.no_longer_observed_at) and
              c.external_id not in ^observed_external_ids
        ),
        set: [no_longer_observed_at: now]
      )

    marcados
  end
end
