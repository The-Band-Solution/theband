defmodule TheBand.Tenants.Auth do
  @moduledoc """
  Autenticação — contrato em `specs/045-autenticacao-e-acesso/contracts/auth.md`.

  ## A mensagem é uma só, e o relógio também

  Senha errada, e-mail inexistente, usuário do GitHub ambíguo, elo revogado e
  conta sem senha devolvem o MESMO `{:error, :invalid_credentials}` (FR-002).
  E quando não há conta, um hash dummy roda mesmo assim: sem ele, a recusa
  instantânea entregaria pelo tempo o que a mensagem esconde.

  ## O identificador é global, de propósito

  `authenticate/2` não recebe tenant: e-mail é único na plataforma, e o usuário
  do GitHub só identifica quando resolve para exatamente UMA conta com elo
  vigente (FR-019) — a mesma pessoa observada em dois tenants não identifica
  nenhuma, e o e-mail resolve. O tenant SAI da conta autenticada; quem loga
  nunca o escolhe.

  ## Espera crescente, nunca bloqueio (FR-016, research R4)

  Três tentativas livres; depois a janela dobra (2s, 4s, 8s…) até o teto de
  60s. Por conta e no banco: sobrevive a deploy e vale em cluster. A tela mostra
  a mensagem única; o `{:throttled, s}` existe para teste e log.
  """

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO.Schemas.Person
  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @tentativas_livres 3
  @teto_segundos 60

  @spec authenticate(String.t(), String.t()) ::
          {:ok, User.t()}
          | {:error, :invalid_credentials}
          | {:error, {:throttled, pos_integer()}}
  def authenticate(identificador, senha)
      when is_binary(identificador) and is_binary(senha) do
    case resolver(String.trim(identificador)) do
      nil ->
        # O custo do hash roda mesmo sem conta — tempo constante.
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      %User{} = user ->
        verificar(user, senha)
    end
  end

  defp verificar(%User{} = user, senha) do
    with :ok <- fora_da_janela(user) do
      cond do
        is_nil(user.password_hash) ->
          # Conta pré-feature (FR-014): recusa idêntica; a tela orienta em texto
          # público, nunca na resposta do formulário.
          Bcrypt.no_user_verify()
          registrar_falha(user)
          {:error, :invalid_credentials}

        Bcrypt.verify_pass(senha, user.password_hash) ->
          {:ok, registrar_sucesso(user)}

        true ->
          registrar_falha(user)
          {:error, :invalid_credentials}
      end
    end
  end

  defp fora_da_janela(%User{failed_attempts: n, last_failed_at: em}) do
    espera = espera_segundos(n)

    if espera > 0 and em != nil do
      liberacao = DateTime.add(em, espera, :second)
      restante = DateTime.diff(liberacao, DateTime.utc_now(:second), :second)
      if restante > 0, do: {:error, {:throttled, restante}}, else: :ok
    else
      :ok
    end
  end

  defp espera_segundos(tentativas) when tentativas < @tentativas_livres, do: 0

  defp espera_segundos(tentativas),
    do: min(Integer.pow(2, tentativas - @tentativas_livres + 1), @teto_segundos)

  defp registrar_falha(%User{} = user) do
    user
    |> Ecto.Changeset.change(
      failed_attempts: user.failed_attempts + 1,
      last_failed_at: DateTime.utc_now(:second)
    )
    |> Repo.update!()
  end

  defp registrar_sucesso(%User{} = user) do
    user
    |> Ecto.Changeset.change(
      failed_attempts: 0,
      last_failed_at: nil,
      # Garante o token (conta que nunca logou); NÃO o gira — girar é ato de
      # troca de senha, e girar aqui derrubaria as outras sessões a cada login.
      session_token: user.session_token || User.novo_token(),
      logged_in_at: DateTime.utc_now(:second)
    )
    |> Repo.update!()
    |> Repo.preload(:tenant)
  end

  # E-mail primeiro (identidade que sempre vale); senão, o usuário do GitHub
  # pelo elo vigente. Mais de uma conta = não identifica (FR-019).
  defp resolver(identificador) do
    por_email(identificador) || por_login_do_github(identificador)
  end

  # A invariante que sustenta a resolução global: `users.email` tem índice ÚNICO
  # na plataforma inteira (não por tenant). Se um dia e-mail passar a repetir
  # entre tenants, este resolvedor precisa mudar JUNTO — a regra de ambiguidade
  # do username (não identifica) passaria a valer para ele.
  defp por_email(identificador) do
    baixo = String.downcase(identificador)
    Repo.one(from u in User, where: fragment("lower(?)", u.email) == ^baixo, limit: 2)
  rescue
    # Dois e-mails diferindo só em caixa (legado): ambíguo não identifica.
    Ecto.MultipleResultsError -> nil
  end

  defp por_login_do_github(identificador) do
    contas =
      Repo.all(
        from u in User,
          join: p in Person,
          on: p.id == u.person_id and p.tenant_id == u.tenant_id,
          where:
            p.login == ^identificador and not is_nil(u.person_id) and
              is_nil(u.person_revoked_at),
          limit: 2
      )

    case contas do
      [conta] -> conta
      _ -> nil
    end
  end

  @doc "Primeira definição de senha (fluxo da temporária) — contracts/auth.md."
  @spec set_password(Tenant.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def set_password(%Tenant{id: tenant_id}, user_id, senha) do
    case do_tenant(tenant_id, user_id) do
      nil -> {:error, :not_found}
      %User{} = user -> user |> User.senha_changeset(%{password: senha}) |> Repo.update()
    end
  end

  @doc """
  Troca de senha pela própria pessoa: exige a atual (FR-012) e gira o token —
  as outras sessões caem na próxima ação (FR-015).
  """
  @spec change_password(Tenant.t(), Ecto.UUID.t(), String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :invalid_current | :not_found | Ecto.Changeset.t()}
  def change_password(%Tenant{id: tenant_id}, user_id, atual, nova) do
    with %User{} = user <- do_tenant(tenant_id, user_id),
         true <- user.password_hash != nil and Bcrypt.verify_pass(atual, user.password_hash) do
      user |> User.senha_changeset(%{password: nova}) |> Repo.update()
    else
      nil -> {:error, :not_found}
      false -> {:error, :invalid_current}
    end
  end

  @doc """
  Cadastro pelo ato da tela (feature 051): cria a conta E emite a temporária numa
  transação — tudo ou nada. Contrato em `specs/051-cadastro-por-github/contracts/
  contas-e-elo.md`: sem isto o cadastro eram dois cliques, e a falha do segundo
  deixava conta sem senha em silêncio. `create_user/2` permanece para seeds e
  fixtures; este é o caminho de quem administra.

  A temporária volta UMA vez, em claro, para a tela mostrar — nunca logada, nunca
  persistida em claro (mesmas regras do reinício abaixo).
  """
  @spec cadastrar_conta(Tenant.t(), map(), User.t()) ::
          {:ok, {User.t(), String.t()}} | {:error, Ecto.Changeset.t()}
  def cadastrar_conta(%Tenant{id: tenant_id}, attrs, %User{} = _actor) do
    Repo.transaction(fn ->
      with {:ok, user} <-
             %User{}
             |> User.changeset(Map.put(attrs, "tenant_id", tenant_id))
             |> Repo.insert(),
           {:ok, temporaria} <- gravar_temporaria(user) do
        {Repo.get!(User, user.id), temporaria}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Reinício por quem administra (FR-013): devolve a temporária UMA vez — ela não
  é gravada em claro nem logada; a primeira entrada obriga a troca.
  """
  @spec reset_password(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, String.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def reset_password(%Tenant{id: tenant_id}, user_id, _actor_id) do
    case do_tenant(tenant_id, user_id) do
      nil -> {:error, :not_found}
      %User{} = user -> gravar_temporaria(user)
    end
  end

  defp gravar_temporaria(user) do
    temporaria = senha_temporaria()

    case user
         |> User.senha_changeset(%{password: temporaria}, temporary: true)
         |> Repo.update() do
      {:ok, _} -> {:ok, temporaria}
      erro -> erro
    end
  end

  defp do_tenant(tenant_id, user_id) do
    Repo.one(from u in User, where: u.id == ^user_id and u.tenant_id == ^tenant_id)
  end

  # Legível para ditar por telefone: base32 minúscula, sem ambiguidade de caixa.
  defp senha_temporaria do
    :crypto.strong_rand_bytes(10) |> Base.encode32(case: :lower, padding: false)
  end
end
