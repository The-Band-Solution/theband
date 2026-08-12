defmodule TheBand.Tenants do
  @moduledoc """
  Organizações clientes e suas pessoas usuárias.

  Toda função de leitura de dado coletado, em qualquer módulo, recebe um
  `%Tenant{}` — nunca o busca do dicionário de processo. É o que torna o filtro
  de tenant verificável em revisão em vez de presumido (constituição, princípio V).
  """

  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

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
end
