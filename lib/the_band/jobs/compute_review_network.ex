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

  ## O caminho feliz (T019)

  Calcula as três janelas, registra uma linha por janela só com contagens (FR-021). O aviso no
  tópico do tenant, só com ids (A11), é de `ReviewNetwork.compute/3`, depois do commit. Único produtor: a sincronização, ao fim da coleta de
  revisões (T020).
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

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"tenant_id" => tenant_id, "organization_id" => organization_id}}) do
    with {:ok, tenant} <- tenant(tenant_id),
         :ok <- ativo(tenant),
         {:ok, organizacao} <- organizacao(tenant, organization_id) do
      inicio = System.monotonic_time(:millisecond)

      case ReviewNetwork.compute(tenant, organizacao, DateTime.utc_now(:second)) do
        {:ok, relator} ->
          registrar(
            tenant.id,
            organizacao.id,
            relator,
            System.monotonic_time(:millisecond) - inicio
          )

          :ok

        # Erro de dado, e não de infraestrutura: tentar de novo dá o mesmo erro. O motivo só tem
        # nomes de campo, e é o que o Oban grava em `oban_jobs.errors` (076, R10; A18).
        {:error, {:reading_rejected, _campos} = motivo} ->
          {:cancel, motivo}
      end
    end
  end

  # FR-021, R14: organização, janela, contagens e duração — e NUNCA par, nome, login nem
  # `person_id`. O relator não os carrega, e é por isso que o registro sai dele, e não da leitura.
  defp registrar(tenant_id, organization_id, %{readings: leituras}, duracao) do
    for l <- leituras do
      Logger.info(
        "rede de revisão calculada: tenant_id=#{tenant_id} organization_id=#{organization_id} " <>
          "window_days=#{l.window_days} reviews=#{l.reviews} " <>
          "self_review=#{l.excluded.self_review} bot_or_app=#{l.excluded.bot_or_app} " <>
          "unlinked_person=#{l.excluded.unlinked_person} duration_ms=#{duracao}"
      )
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
