defmodule TheBand.Tenants do
  @moduledoc """
  Organizações clientes e suas pessoas usuárias.

  Toda função de leitura de dado coletado, em qualquer módulo, recebe um
  `%Tenant{}` — nunca o busca do dicionário de processo. É o que torna o filtro
  de tenant verificável em revisão em vez de presumido (constituição, princípio V).
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Access
  alias TheBand.Tenants.Auth
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  # Feature 045 — contratos em specs/045-autenticacao-e-acesso/contracts/.
  defdelegate authenticate(identificador, senha), to: Auth
  defdelegate set_password(tenant, user_id, senha), to: Auth
  defdelegate change_password(tenant, user_id, atual, nova), to: Auth
  defdelegate reset_password(tenant, user_id, actor_id), to: Auth
  defdelegate cadastrar_conta(tenant, attrs, actor), to: Auth

  defdelegate scopes(tenant, user), to: Access
  defdelegate pode_declarar_estrutura(tenant, user, nivel, alvo_id), to: Access
  defdelegate pode_ver(tenant, user, person_id), to: Access
  defdelegate grant_scope(tenant, user_id, level, target_id, actor), to: Access, as: :grant
  defdelegate revoke_scope(tenant, grant_id, actor), to: Access, as: :revoke
  defdelegate operacional?(tenant, user), to: Access

  @spec list_tenants() :: [Tenant.t()]
  def list_tenants, do: Repo.all(from t in Tenant, order_by: t.name)

  @spec fetch(Ecto.UUID.t()) :: {:ok, Tenant.t()} | {:error, :not_found}
  def fetch(id) do
    case Repo.get(Tenant, id) do
      nil -> {:error, :not_found}
      tenant -> {:ok, tenant}
    end
  end

  @spec get_by_slug(String.t()) :: Tenant.t() | nil
  def get_by_slug(slug), do: Repo.get_by(Tenant, slug: slug)

  @spec create_tenant(map()) :: {:ok, Tenant.t()} | {:error, Ecto.Changeset.t()}
  def create_tenant(attrs) do
    %Tenant{} |> Tenant.changeset(attrs) |> Repo.insert()
  end

  @spec list_users(Tenant.t()) :: [User.t()]
  def list_users(%Tenant{id: tenant_id}) do
    Repo.all(from u in User, where: u.tenant_id == ^tenant_id, order_by: u.email)
  end

  @doc """
  As pessoas do tenant, por id.

  Existe para a tela resolver **quem** tomou uma decisão registrada — encerrar uma
  sincronização presa, por exemplo — sem uma consulta por linha.
  """
  @spec users_by_id(Tenant.t()) :: %{Ecto.UUID.t() => User.t()}
  def users_by_id(%Tenant{} = tenant), do: Map.new(list_users(tenant), &{&1.id, &1})

  @spec list_all_users() :: [User.t()]
  def list_all_users do
    Repo.all(from u in User, order_by: u.email, preload: [:tenant])
  end

  @spec fetch_user(Ecto.UUID.t()) :: {:ok, User.t()} | {:error, :not_found}
  def fetch_user(id) do
    case Repo.get(User, id) |> Repo.preload(:tenant) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @spec create_user(Tenant.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(%Tenant{id: tenant_id}, attrs) do
    %User{}
    |> User.changeset(Map.put(attrs, "tenant_id", tenant_id))
    |> Repo.insert()
  end

  @doc """
  A própria pessoa edita o próprio nome (feature 045, FR-012). SÓ o nome: e-mail
  identifica a entrada, papel é gestão, elo é acesso — cada um tem o seu ato.
  """
  @spec update_name(Tenant.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, User.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_name(%Tenant{id: tenant_id}, user_id, nome) do
    with {:ok, user} <- usuaria_do_tenant(tenant_id, user_id) do
      user
      |> Ecto.Changeset.cast(%{name: nome}, [:name])
      |> Repo.update()
      |> case do
        {:ok, atualizada} -> {:ok, Repo.preload(atualizada, :tenant)}
        erro -> erro
      end
    end
  end

  @doc """
  A conta com elo VIGENTE para esta pessoa, ou nil — feature 051, contrato
  `contas-e-elo.md`. Leitura estreita chamada SÓ no caminho do `{:error, :taken}`
  de `declare_person/4`, para a recusa nomear a conta dona (cenário 3 da US2);
  zero custo no caminho feliz. A corrida continua segura pelo índice único parcial
  — esta função dá o NOME, o banco dá a garantia.
  """
  @spec user_of_person(Tenant.t(), Ecto.UUID.t()) :: User.t() | nil
  def user_of_person(%Tenant{id: tenant_id}, person_id) do
    Repo.one(
      from u in User,
        where:
          u.tenant_id == ^tenant_id and u.person_id == ^person_id and
            is_nil(u.person_revoked_at)
    )
  end

  @doc """
  Declara qual pessoa observada é esta conta — issue #369, FR-012c.

  O elo é o que permite a plataforma responder "esse painel é o seu" e "essa pessoa é da
  equipe que você lidera". Sem ele, nenhum dos três casos da regra de visibilidade é
  computável — nem o da própria pessoa.

  ## Quem pode chamar

  Esta função NÃO verifica papel de plataforma. Quem chama é responsável por exigir admin, e
  a tela exige — a verificação vive lá porque é lá que a pessoa está, e um segundo lugar de
  autorização é um lugar a mais para divergir.

  **O elo concede visibilidade.** Apontar a própria conta para outra pessoa observada é
  passar a ver o painel dela. Não é campo de cadastro: é ato de acesso.

  ## Substituir revoga antes

  Declarar sobre um elo vigente encerra o anterior e grava o novo na mesma transação. Sem
  isso, uma falha entre as duas deixaria a conta sem elo algum, e ela perderia o próprio
  painel sem nada ter sido pedido.
  """
  @spec declare_person(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, User.t()} | {:error, :not_found | :taken | Ecto.Changeset.t()}
  def declare_person(%Tenant{id: tenant_id}, user_id, person_id, actor_id) do
    with {:ok, user} <- usuaria_do_tenant(tenant_id, user_id) do
      user
      |> gravar_elo(person_id, actor_id)
      |> desfecho_do_elo()
    end
  end

  defp gravar_elo(user, person_id, actor_id),
    do: Repo.transaction(fn -> aplicar_elo(user, person_id, actor_id) end)

  defp aplicar_elo(user, person_id, actor_id) do
    agora = DateTime.utc_now(:second)
    user = encerrar_elo_vigente(user, actor_id, agora)

    user
    |> User.elo_da_pessoa_changeset(%{
      person_id: person_id,
      person_declared_by_user_id: actor_id,
      person_declared_at: agora,
      person_revoked_by_user_id: nil,
      person_revoked_at: nil
    })
    |> Repo.update()
    |> case do
      {:ok, atualizada} -> atualizada
      {:error, erro} -> Repo.rollback(erro)
    end
  end

  # Recarregar entre revogar e declarar não é zelo: `revogar_elo/3` escreve por
  # `update_all`, e a struct em memória fica velha. Um campo cujo valor novo é igual ao da
  # struct velha NÃO entra nas mudanças do changeset — enquanto o banco já o mudou. É assim
  # que `person_declared_by_user_id` ficaria nulo com `person_id` preenchido, violando a
  # CHECK que existe justamente para impedir isso.
  defp encerrar_elo_vigente(user, actor_id, agora) do
    if User.elo_vigente?(user) do
      revogar_elo(user, actor_id, agora)
      Repo.get!(User, user.id)
    else
      user
    end
  end

  defp desfecho_do_elo({:ok, atualizada}), do: {:ok, atualizada}
  defp desfecho_do_elo({:error, %Ecto.Changeset{} = cs}), do: {:error, conflito(cs)}
  defp desfecho_do_elo(outro), do: outro

  @doc """
  Revoga o elo. Marca, e nunca apaga.

  "Desde quando essa conta via esse painel" só tem resposta se o encerramento preservar o
  começo — e retirar acesso é justamente o que se audita. Por isso `person_id` FICA, e é
  `person_revoked_at` que o tira de circulação.
  """
  @spec revoke_person(Tenant.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, User.t()} | {:error, :not_found | :not_declared}
  def revoke_person(%Tenant{id: tenant_id}, user_id, actor_id) do
    with {:ok, user} <- usuaria_do_tenant(tenant_id, user_id) do
      if User.elo_vigente?(user) do
        revogar_elo(user, actor_id, DateTime.utc_now(:second))
        {:ok, Repo.get!(User, user.id)}
      else
        {:error, :not_declared}
      end
    end
  end

  @doc """
  Qual conta é esta pessoa observada — issue #369.

  Devolve `{:ok, user}` ou `:not_declared`, e **nunca `nil`**: a tela precisa distinguir
  "essa pessoa é a conta X" de "não sabemos quem essa pessoa é", porque a segunda tem
  remédio — declarar — e a primeira não.
  """
  @spec user_for_person(Tenant.t(), Ecto.UUID.t()) :: {:ok, User.t()} | :not_declared
  def user_for_person(%Tenant{id: tenant_id}, person_id) do
    case Repo.one(
           from u in User,
             where:
               u.tenant_id == ^tenant_id and u.person_id == type(^person_id, :binary_id) and
                 is_nil(u.person_revoked_at)
         ) do
      nil -> :not_declared
      user -> {:ok, user}
    end
  end

  @doc """
  Qual pessoa observada é esta conta — o outro lado do elo.

  Devolve o `person_id`, ou `:not_declared`. É por aqui que a regra de visibilidade começa:
  sem esta resposta, nem o painel da própria pessoa é alcançável.
  """
  @spec person_of_user(User.t()) :: {:ok, Ecto.UUID.t()} | :not_declared
  def person_of_user(%User{} = user) do
    if User.elo_vigente?(user), do: {:ok, user.person_id}, else: :not_declared
  end

  @doc """
  Quantas contas têm elo declarado, e quantas existem — a lacuna, dita como lacuna.

  `1 de 2` e `1` afirmam coisas diferentes: o primeiro diz que uma conta ainda não alcança
  painel nenhum.
  """
  @spec elo_coverage(Tenant.t()) :: %{declaradas: non_neg_integer(), contas: non_neg_integer()}
  def elo_coverage(%Tenant{id: tenant_id}) do
    Repo.one(
      from u in User,
        where: u.tenant_id == ^tenant_id,
        select: %{
          contas: count(u.id),
          declaradas: filter(count(u.id), not is_nil(u.person_id) and is_nil(u.person_revoked_at))
        }
    )
  end

  # O `person_id` FICA na linha revogada, e é `revoked_at` que o tira de circulação. Zerar
  # perderia QUAL pessoa a conta era — sobraria "desde quando" e sumiria "quem", que é a
  # metade que se pergunta primeiro. O índice parcial já exclui a linha revogada.
  defp revogar_elo(user, actor_id, agora) do
    Repo.update_all(
      from(u in User, where: u.id == type(^user.id, :binary_id)),
      set: [
        person_revoked_by_user_id: actor_id,
        person_revoked_at: agora,
        updated_at: agora
      ]
    )
  end

  defp usuaria_do_tenant(tenant_id, user_id) do
    case Repo.get_by(User, id: user_id, tenant_id: tenant_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  defp conflito(%Ecto.Changeset{errors: erros} = cs) do
    if match?({_, [constraint: :unique, constraint_name: _]}, erros[:person_id]),
      do: :taken,
      else: cs
  end
end
