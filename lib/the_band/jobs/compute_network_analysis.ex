defmodule TheBand.Jobs.ComputeNetworkAnalysis do
  @moduledoc """
  O cálculo da análise de rede de uma organização observada, em segundo plano — feature 076,
  T013 (FR-017, FR-018, FR-054; R4, R7, R10, R15 da segurança; `contracts/job.md`).

  ## Confere antes de ler qualquer dado, e cancela sem gravar

  Na ordem: o tenant existe; está ativo; a organização é **deste** tenant, buscada por id e tenant
  juntos. Qualquer falha é `{:cancel, motivo}` e **nenhuma leitura é gravada** (A14): gravar uma
  leitura vazia porque a organização não foi achada faria a tela afirmar que a rede não tem
  aresta, o fallback silencioso da §7.7.

  ## Argumentos

  Só `tenant_id` e `organization_id`. Qualquer outro (`network`, `window`) é **ignorado**: as
  redes e as janelas são as da base (R6 da 073).

  ## Fila, unicidade e tempo

  Fila própria `:network_analysis`, configurada com concorrência 1 (T010). Unicidade pelo grupo
  `:incomplete`, como a 073 (o Oban 2.23 recusa a lista sem os estados incompletos).
  `timeout/1` de 120 s, **provisório** (R5; confirmado por T050 e pela #1190).

  ## Único produtor

  `ComputeReviewNetwork`, depois do commit da leitura da 073 (R3). Nenhuma tela enfileira.

  ## O registro

  Uma linha por rede e janela, a partir do **relator**: organização, rede, janela, resultado,
  arestas, pessoas, exclusões por motivo, ausências por teto, duração. Nunca par, nome, login,
  papel, comunidade nem medida por pessoa (FR-054, A19). O relator não os carrega.
  """

  use Oban.Worker,
    queue: :network_analysis,
    max_attempts: 3,
    unique: [
      fields: [:args, :worker],
      keys: [:tenant_id, :organization_id],
      states: :incomplete,
      period: :infinity
    ]

  alias TheBand.NetworkAnalysis
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  require Logger

  # Provisório: R5 do plano; T050 mede o pipeline no tamanho do teto e confirma.
  @teto_de_tempo :timer.seconds(120)

  @impl Oban.Worker
  def timeout(_job), do: @teto_de_tempo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "organization_id" => organization_id}}) do
    with {:ok, tenant} <- tenant(tenant_id),
         :ok <- ativo(tenant),
         {:ok, organizacao} <- organizacao(tenant, organization_id) do
      case NetworkAnalysis.compute(tenant, organizacao, DateTime.utc_now(:second)) do
        {:ok, relator} ->
          registrar(tenant.id, organizacao.id, relator)
          :ok

        # Erro de dado: tentar de novo dá o mesmo erro. O motivo só tem nomes de campo, e é o
        # que o Oban grava em `oban_jobs.errors` (R10; A18).
        {:error, {:reading_rejected, _campos} = motivo} ->
          {:cancel, motivo}
      end
    end
  end

  defp registrar(tenant_id, organization_id, %{readings: leituras}) do
    for l <- leituras do
      Logger.info(
        "análise de rede: tenant_id=#{tenant_id} organization_id=#{organization_id} " <>
          "network=#{l.network} window_days=#{l.window_days} outcome=#{resultado(l.outcome)} " <>
          "edges=#{l.edges} people=#{l.people} excluded=#{exclusoes(l.excluded)} " <>
          "absent=#{Enum.join(l.absent, ",")} duration_ms=#{l.duration_ms}"
      )
    end
  end

  defp resultado({:ausente, motivo}), do: "absent:#{motivo}"
  defp resultado(outcome), do: Atom.to_string(outcome)

  defp exclusoes(excluded),
    do: excluded |> Enum.sort() |> Enum.map_join(",", fn {motivo, n} -> "#{motivo}:#{n}" end)

  defp tenant(id) do
    case Tenants.fetch(id) do
      {:ok, tenant} -> {:ok, tenant}
      {:error, :not_found} -> {:cancel, :tenant_not_found}
    end
  end

  defp ativo(tenant) do
    case Tenants.ensure_active(tenant) do
      :ok -> :ok
      {:error, :tenant_inactive} -> {:cancel, :tenant_inactive}
    end
  end

  defp organizacao(tenant, id) do
    case EO.fetch_organization(tenant, id) do
      {:ok, organizacao} -> {:ok, organizacao}
      {:error, :not_found} -> {:cancel, :organization_not_found}
    end
  end

  @doc """
  Enfileira o cálculo da organização. Único produtor: `ComputeReviewNetwork`, depois do commit da
  leitura da 073 (R3). Nenhuma tela enfileira.
  """
  @spec enqueue(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(tenant_id, organization_id) do
    %{tenant_id: tenant_id, organization_id: organization_id}
    |> new()
    |> Oban.insert()
  end
end
