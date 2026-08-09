defmodule TheBand.Jobs.ReprocessMappings do
  @moduledoc """
  Reaplica os mapeamentos corrigidos aos dados já coletados (FR-017).

  Fila `:transformation`, separada da `:ingestion` de propósito: um lote grande de
  reprocessamento não pode bloquear a coleta, que depende de janela de API e não
  pode esperar.

  **Nenhuma chamada à origem acontece aqui.** O worker delega a
  `TheBand.SemanticIntegration`, que não conhece o cliente do GitHub.
  """

  use Oban.Worker, queue: :transformation, max_attempts: 3, unique: [period: 60, fields: [:args]]

  alias TheBand.SemanticIntegration
  alias TheBand.Tenants

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id} = args}) do
    # O tenant vem nos args e é validado antes de qualquer coisa acontecer.
    with {:ok, tenant} <- Tenants.fetch(tenant_id) do
      opts = raw_entity_type_opts(args)

      case SemanticIntegration.reprocess_mappings(tenant, opts) do
        {:ok, report} ->
          Logger.info("reprocessamento concluído: #{inspect(report)}")
          SemanticIntegration.broadcast_report(tenant, report)
          :ok

        {:error, :no_raw_payloads} ->
          # Único erro de lote possível, e não é falha: significa que ainda não
          # houve coleta. Repetir o job não mudaria isso, então ele é descartado
          # em vez de reagendado.
          SemanticIntegration.broadcast_report(tenant, %{error: :no_raw_payloads})
          {:cancel, :no_raw_payloads}
      end
    end
  end

  defp raw_entity_type_opts(%{"raw_entity_type" => type}) when is_binary(type),
    do: [raw_entity_type: type]

  defp raw_entity_type_opts(_args), do: []
end
