defmodule TheBand.Jobs.ComputeReviewNetwork do
  @moduledoc """
  O cálculo da rede de revisão de uma organização observada, em segundo plano — feature 073,
  T018 (FR-010; R4, R6 da segurança; `contracts/job.md`).

  ## Confere antes de ler qualquer dado, e cancela sem gravar

  Na ordem: o tenant existe; está ativo; a organização é **deste** tenant, buscada por id e tenant
  juntos. Qualquer falha é `{:cancel, motivo}` e **nenhuma leitura é gravada**: gravar uma leitura
  vazia porque a organização não foi achada faria a tela afirmar que não houve revisão (A10), o
  fallback silencioso da §7.7.

  ## A janela não é argumento

  As três janelas são as da base, calculadas juntas. Nenhum valor vem de fora: argumento a mais é
  ignorado (R6).

  ## Unicidade pelo grupo `:incomplete`, com `:executing` dentro

  Uma organização tem no máximo um cálculo pendente ou rodando, por período infinito, e não os
  30 s de `RecomputePromotions`. O plano queria `:executing` de fora (research.md R9, D7), para
  que a coleta que termina durante um cálculo enfileirasse o seguinte. **O Oban 2.23 recusa**: a
  lista sem os estados incompletos dá aviso de compilação (*"may break uniqueness"*), e o gate
  compila com `--warnings-as-errors`. Fica o grupo `:incomplete`, e o custo é escrito: a coleta
  que termina durante um cálculo não o repete, e a leitura alcança o dado na sincronização
  seguinte (intervalo mínimo de 15 minutos). Corrigido no contrato `job.md` no mesmo commit.

  **O caminho feliz** (registro sem par nem nome, aviso só com ids) é a T019, que espera a base.
  Até lá, `ReviewNetwork.compute/3` levanta (`ReviewNetwork.Parameters`), e ninguém enfileira este
  job: o gatilho na sincronização é a T020.
  """

  use Oban.Worker,
    queue: :transformation,
    max_attempts: 3,
    unique: [
      fields: [:args, :worker],
      keys: [:tenant_id, :organization_id],
      states: :incomplete,
      period: :infinity
    ]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.ReviewNetwork
  alias TheBand.Tenants

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "organization_id" => organization_id}}) do
    with {:ok, tenant} <- tenant(tenant_id),
         :ok <- ativo(tenant),
         {:ok, organizacao} <- organizacao(tenant, organization_id) do
      {:ok, _relator} = ReviewNetwork.compute(tenant, organizacao, DateTime.utc_now(:second))
      :ok
    end
  end

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
  Enfileira o cálculo da organização. Único produtor: a sincronização, ao fim da coleta de
  revisões (T020). Nenhuma tela enfileira (decisão de 2026-10-03, R6).
  """
  @spec enqueue(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(tenant_id, organization_id) do
    %{tenant_id: tenant_id, organization_id: organization_id}
    |> new()
    |> Oban.insert()
  end
end
