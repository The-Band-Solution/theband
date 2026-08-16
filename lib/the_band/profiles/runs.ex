defmodule TheBand.Profiles.Runs do
  @moduledoc """
  A rodada: abrir, registrar cada desfecho, encerrar, e devolver à tela o que aconteceu.

  Feature 027, `FR-003`, `FR-014`, `FR-016` e `FR-017`.

  ## As contagens são derivadas, e isso é deliberado

  `summary/1` agrega sobre as entradas. Guardar contadores em coluna seria mais rápido e
  criaria o defeito que este repositório já teve duas vezes: dois lugares guardando o mesmo
  fato, e eles discordando depois de uma retentativa. Com 34 entradas por rodada, a agregação
  não se mede.
  """

  import Ecto.Query

  alias TheBand.AI
  alias TheBand.Profiles.{Automation, Run, RunEntry, RunWorker}
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant

  @type run :: Run.t()

  @doc """
  Abre uma rodada e enfileira o job que a executa.

  `opts`: `:trigger` (`:cron` ou `:manual`) e `:requested_by`, obrigatório quando manual.

  `:already_running` vale para a automática **e** para a disparada a mão — `FR-003` —, e cobre
  também a rodada que passou do mês: a seguinte é recusada, não enfileirada em silêncio.
  """
  @spec start(Tenant.t(), keyword()) ::
          {:ok, run()}
          | {:error, :already_running}
          | {:error, :no_credential}
          | {:error, :not_enabled}
          | {:error, Ecto.Changeset.t()}
  def start(%Tenant{} = tenant, opts \\ []) do
    trigger = Keyword.get(opts, :trigger, :manual)
    ator = Keyword.get(opts, :requested_by)

    with :ok <- verificar_automacao(tenant, trigger),
         :ok <- verificar_livre(tenant),
         {:ok, cred} <- credencial(tenant),
         {:ok, run} <- abrir(tenant, trigger, ator, cred) do
      enfileirar(run)
    end
  end

  @doc """
  Grava o desfecho de uma pessoa. É o checkpoint.

  `:already_recorded` vem da constraint única `[rodada, pessoa]`, e é o que faz a retentativa
  do Oban retomar em vez de gerar um segundo texto sobre o mesmo material.
  """
  @spec record(run(), binary(), map()) ::
          {:ok, RunEntry.t()} | {:error, :already_recorded} | {:error, Ecto.Changeset.t()}
  def record(%Run{} = run, person_id, attrs) do
    %RunEntry{}
    |> RunEntry.changeset(
      Map.merge(attrs, %{
        tenant_id: run.tenant_id,
        profile_run_id: run.id,
        person_id: person_id
      })
    )
    |> Repo.insert()
    |> case do
      {:ok, entry} ->
        broadcast(run)
        {:ok, entry}

      {:error, %{errors: erros} = changeset} ->
        classificar(erros, changeset)
    end
  end

  @doc """
  Grava quantas pessoas esta rodada vai percorrer — o denominador da barra de progresso.

  Escrita pelo worker no momento da seleção, nunca pela tela. Na retentativa é regravada
  como `entradas já feitas + restantes`, porque a elegibilidade pode mudar entre tentativas
  e um plano velho mentiria o total.

  **Não é contador de desfecho** — os nove números continuam derivados das entradas. Isto é
  o tamanho do plano, conhecido antes de qualquer desfecho existir.
  """
  @spec plan(run(), non_neg_integer()) :: {:ok, run()}
  def plan(%Run{} = run, total) when is_integer(total) and total >= 0 do
    {:ok, atualizada} =
      run
      |> Ecto.Changeset.change(people_selected: total)
      |> Repo.update()

    broadcast(atualizada)
    {:ok, atualizada}
  end

  @doc """
  Assina o tópico de rodadas do tenant.

  A cada checkpoint gravado, plano definido, rodada aberta ou encerrada chega
  `{:rodada, run_id}` — só o id, porque a tela recarrega do banco e duas fontes do mesmo
  fato divergiriam. O tópico é por tenant: uma organização não recebe o progresso da outra,
  e a `FR-017` vale também para o que trafega em PubSub.
  """
  @spec subscribe(Tenant.t()) :: :ok | {:error, term()}
  def subscribe(%Tenant{id: tenant_id}),
    do: Phoenix.PubSub.subscribe(TheBand.PubSub, topico(tenant_id))

  defp broadcast(%Run{} = run) do
    Phoenix.PubSub.broadcast(TheBand.PubSub, topico(run.tenant_id), {:rodada, run.id})
  end

  defp topico(tenant_id), do: "profile_runs:#{tenant_id}"

  @doc """
  Fecha a rodada.

  `{:ended_early, motivo}` é o caminho da `FR-016`: falha de credencial encerra, porque a
  próxima pessoa falharia pelo mesmo motivo.
  """
  @spec finish(run(), :completed | {:ended_early, String.t()}) :: {:ok, run()}
  def finish(%Run{} = run, :completed), do: fechar(run, "completed", nil)
  def finish(%Run{} = run, {:ended_early, motivo}), do: fechar(run, "ended_early", motivo)

  @doc "A rodada mais recente do tenant. `:never_ran` é resposta, e não lista vazia."
  @spec latest(Tenant.t()) :: {:ok, run()} | {:error, :never_ran}
  def latest(%Tenant{} = tenant) do
    case list(tenant, limit: 1) do
      [run] -> {:ok, run}
      [] -> {:error, :never_ran}
    end
  end

  @doc "As rodadas do tenant, da mais recente para a mais antiga. Sempre por organização."
  @spec list(Tenant.t(), keyword()) :: [run()]
  def list(%Tenant{id: tenant_id}, opts \\ []) do
    Repo.all(
      from r in Run,
        where: r.tenant_id == ^tenant_id,
        order_by: [desc: r.started_at],
        limit: ^Keyword.get(opts, :limit, 20)
    )
  end

  @doc "A rodada aberta do tenant, se houver."
  @spec running(Tenant.t()) :: {:ok, run()} | {:error, :none}
  def running(%Tenant{id: tenant_id}) do
    case Repo.one(from r in Run, where: r.tenant_id == ^tenant_id and is_nil(r.finished_at)) do
      nil -> {:error, :none}
      run -> {:ok, run}
    end
  end

  @doc """
  Os nove números da `FR-014`, derivados das entradas.

  Os motivos vêm nomeados um a um: um total de pulados agregaria o que a `FR-014` manda
  separar, e é o "não elegível" que ela proíbe.
  """
  @spec summary(run()) :: %{
          considered: non_neg_integer(),
          generated: non_neg_integer(),
          skipped: %{
            no_material: non_neg_integer(),
            no_new_work: non_neg_integer(),
            observation_ended: non_neg_integer()
          },
          failed: non_neg_integer(),
          input_tokens: non_neg_integer()
        }
  def summary(%Run{id: run_id}) do
    por_desfecho =
      Repo.all(
        from e in RunEntry,
          where: e.profile_run_id == ^run_id,
          group_by: [e.outcome, e.reason],
          select: {e.outcome, e.reason, count(e.id), coalesce(sum(e.input_tokens), 0)}
      )

    contar = fn desfecho ->
      por_desfecho
      |> Enum.filter(&(elem(&1, 0) == desfecho))
      |> Enum.map(&elem(&1, 2))
      |> Enum.sum()
    end

    pulados =
      Map.new(RunEntry.reasons(), fn motivo ->
        total =
          por_desfecho
          |> Enum.filter(fn {o, r, _, _} -> o == "skipped" and r == motivo end)
          |> Enum.map(&elem(&1, 2))
          |> Enum.sum()

        {String.to_existing_atom(motivo), total}
      end)

    %{
      considered: por_desfecho |> Enum.map(&elem(&1, 2)) |> Enum.sum(),
      generated: contar.("generated"),
      skipped: pulados,
      failed: contar.("failed"),
      input_tokens: por_desfecho |> Enum.map(&elem(&1, 3)) |> Enum.sum()
    }
  end

  @doc "Quem já tem desfecho gravado nesta rodada — o checkpoint que a retentativa lê."
  @spec recorded_person_ids(run()) :: MapSet.t(binary())
  def recorded_person_ids(%Run{id: run_id}) do
    from(e in RunEntry, where: e.profile_run_id == ^run_id, select: e.person_id)
    |> Repo.all()
    |> MapSet.new()
  end

  # ------------------------------------------------------------------ privados

  defp verificar_automacao(_tenant, :manual), do: :ok

  defp verificar_automacao(tenant, :cron) do
    if Automation.enabled?(tenant), do: :ok, else: {:error, :not_enabled}
  end

  defp verificar_livre(tenant) do
    case running(tenant) do
      {:error, :none} -> :ok
      {:ok, _} -> {:error, :already_running}
    end
  end

  # A rodada de uma organização usa a credencial **daquela** organização. Sem ela a rodada não
  # abre, ainda que exista chave no ambiente: a chave do ambiente é da instalação, e usá-la
  # faria a conta de uma organização pagar pela outra — `FR-011`.
  defp credencial(tenant) do
    case AI.fetch(tenant) do
      {:ok, cred} -> {:ok, cred}
      {:error, :not_found} -> {:error, :no_credential}
    end
  end

  defp abrir(%Tenant{id: tenant_id}, trigger, ator, cred) do
    %Run{}
    |> Run.changeset(%{
      tenant_id: tenant_id,
      trigger: Atom.to_string(trigger),
      requested_by_user_id: ator && ator.id,
      started_at: DateTime.utc_now(:second),
      credential_last_four: cred.last_four
    })
    |> Repo.insert()
    |> case do
      {:ok, run} ->
        {:ok, run}

      # A corrida entre duas aberturas simultâneas termina no índice parcial, e não numa
      # leitura anterior: o `verificar_livre` reduz o caso comum, e a constraint fecha o resto.
      {:error, %{errors: [{:tenant_id, _} | _]}} ->
        {:error, :already_running}

      erro ->
        erro
    end
  end

  defp enfileirar(%Run{} = run) do
    case %{run_id: run.id, tenant_id: run.tenant_id} |> RunWorker.new() |> Oban.insert() do
      {:ok, _job} ->
        broadcast(run)
        {:ok, run}

      erro ->
        erro
    end
  end

  defp fechar(%Run{} = run, outcome, motivo) do
    resultado =
      run
      |> Run.changeset(%{
        finished_at: DateTime.utc_now(:second),
        outcome: outcome,
        ended_reason: motivo
      })
      |> Repo.update()

    with {:ok, fechada} <- resultado, do: broadcast(fechada)
    resultado
  end

  defp classificar(erros, changeset) do
    if Keyword.has_key?(erros, :profile_run_id) or Keyword.has_key?(erros, :person_id) do
      {:error, :already_recorded}
    else
      {:error, changeset}
    end
  end

  @doc "Recarrega a rodada do banco — a tela e o worker precisam do estado atual."
  @spec get(Tenant.t(), binary()) :: {:ok, run()} | {:error, :not_found}
  def get(%Tenant{id: tenant_id}, run_id) do
    case Repo.one(from r in Run, where: r.tenant_id == ^tenant_id and r.id == ^run_id) do
      nil -> {:error, :not_found}
      run -> {:ok, run}
    end
  end
end
