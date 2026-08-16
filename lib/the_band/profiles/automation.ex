defmodule TheBand.Profiles.Automation do
  @moduledoc """
  O estado da geração automática de uma organização, e os dois atos que o mudam — feature 027.

  ## O estado é derivado, e não guardado

  O evento mais recente diz se está ligada. Um booleano em `tenants` guardaria o estado e
  perderia o autor, que a `FR-019` exige nos dois sentidos; um booleano **mais** uma tabela de
  auditoria guardaria o mesmo fato em dois lugares, e eles divergiriam.

  Não é hipótese: a issue #178 corrigiu exatamente esse desenho em `connected_tools`, onde uma
  coluna de situação discordava dos eventos de observação.

  ## Nasce desligada, e isso é requisito de dados

  Organização sem evento **não está ligada** — `FR-018a` e `FR-018c`. É o que faz um deploy
  não passar a escrever texto sobre ninguém: a ausência de evento é a resposta, e não a falta
  de uma migração que preencheria uma coluna.
  """

  import Ecto.Query

  alias TheBand.AI
  alias TheBand.Profiles.{AutomationEvent, Runs}
  alias TheBand.Repo
  alias TheBand.Tenants.{Tenant, User}

  @doc "Se a geração automática está ligada agora."
  @spec enabled?(Tenant.t()) :: boolean()
  def enabled?(%Tenant{} = tenant), do: match?({:enabled, _}, state(tenant))

  @doc """
  O estado **com autor e data**.

  Três respostas, e a terceira não é redundante: *"nunca foi ligada"* e *"foi desligada em
  março por alguém"* pedem frases diferentes na tela, e achatá-las num booleano apagaria quem
  desligou — que é a pergunta que aparece quando os perfis param de aparecer.
  """
  @spec state(Tenant.t()) ::
          {:enabled, %{by: User.t() | nil, at: DateTime.t()}}
          | {:disabled, %{by: User.t() | nil, at: DateTime.t()}}
          | :never_enabled
  def state(%Tenant{} = tenant) do
    case ultimo(tenant) do
      nil -> :never_enabled
      %{event: "enabled"} = e -> {:enabled, %{by: autor(e), at: e.occurred_at}}
      %{event: "disabled"} = e -> {:disabled, %{by: autor(e), at: e.occurred_at}}
    end
  end

  @doc """
  Liga, grava o evento com autor, e **dispara a primeira rodada na hora** — `FR-004a`.

  Quem liga precisa ver o efeito do ato: esperar até o dia 1 para descobrir se funcionou
  transforma a espera em dúvida sobre a plataforma.
  """
  @spec enable(Tenant.t(), User.t()) ::
          {:ok, %{event: AutomationEvent.t(), run: Runs.run()}}
          | {:error, :already_enabled}
          | {:error, :no_credential}
          | {:error, term()}
  def enable(%Tenant{} = tenant, %User{} = ator) do
    cond do
      enabled?(tenant) ->
        {:error, :already_enabled}

      # Ligar sem credencial prometeria uma execução que a `FR-011` proíbe: a rodada de uma
      # organização não pode cair na chave do processo, porque a conta de uma pagaria a outra.
      match?({:error, :not_found}, AI.fetch(tenant)) ->
        {:error, :no_credential}

      true ->
        with {:ok, evento} <- gravar(tenant, "enabled", ator),
             {:ok, run} <- Runs.start(tenant, trigger: :manual, requested_by: ator) do
          {:ok, %{event: evento, run: run}}
        end
    end
  end

  @doc """
  Desliga, a partir da **próxima** rodada — `FR-018b`.

  Rodada em execução não é interrompida no meio: metade das pessoas geradas é um estado que a
  tela não sabe nomear.
  """
  @spec disable(Tenant.t(), User.t()) ::
          {:ok, AutomationEvent.t()} | {:error, :not_enabled}
  def disable(%Tenant{} = tenant, %User{} = ator) do
    if enabled?(tenant), do: gravar(tenant, "disabled", ator), else: {:error, :not_enabled}
  end

  @doc "Os atos, do mais recente para o mais antigo."
  @spec history(Tenant.t()) :: [AutomationEvent.t()]
  def history(%Tenant{id: tenant_id}) do
    Repo.all(
      from e in AutomationEvent,
        where: e.tenant_id == ^tenant_id,
        order_by: [desc: e.occurred_at, desc: e.inserted_at]
    )
  end

  @doc "Os tenants com a geração ligada — é por onde o cron começa."
  @spec enabled_tenants() :: [Tenant.t()]
  def enabled_tenants do
    Enum.filter(TheBand.Tenants.list_tenants(), &enabled?/1)
  end

  defp gravar(%Tenant{id: tenant_id}, evento, %User{id: ator_id}) do
    %AutomationEvent{}
    |> AutomationEvent.changeset(%{
      tenant_id: tenant_id,
      event: evento,
      actor_user_id: ator_id,
      occurred_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  defp ultimo(%Tenant{id: tenant_id}) do
    Repo.one(
      from e in AutomationEvent,
        where: e.tenant_id == ^tenant_id,
        order_by: [desc: e.occurred_at, desc: e.inserted_at],
        limit: 1
    )
  end

  # O ator pode ter sido removido depois do ato. Devolver `nil` é dizer "não sabemos mais
  # quem" — e é diferente de nunca ter havido autor, que o banco não permite.
  defp autor(%AutomationEvent{actor_user_id: nil}), do: nil
  defp autor(%AutomationEvent{actor_user_id: id}), do: Repo.get(User, id)
end
