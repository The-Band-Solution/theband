defmodule TheBand.Tenants.PapelDeAdministrador do
  @moduledoc """
  Quem pode mexer na marca de administrador, e a organização nunca sem nenhum — spec 072, T004
  (FR-002, FR-002a, FR-004; S1, S2 e S3 de `specs/072-papel-de-administrador/seguranca.md`).
  Contrato em `specs/072-papel-de-administrador/contracts/papel.md`.

  Depende de: nenhuma ontologia. Privado a `TheBand.Tenants`.

  ## Um guarda só

  Promover, rebaixar e desativar usam o mesmo `travar/3`, dentro da transação de cada ato:

  1. trava as contas `admin` ativas da organização com `FOR UPDATE`, em ordem de id, para duas
     transações não se travarem em ordem cruzada;
  2. confere que o **ator** está nesse conjunto. A struct que a tela recebeu no `mount` não vale: um
     rebaixado com a aba aberta se promoveria de volta (S2);
  3. trava e **relê** o alvo, e quem chama decide pelo alvo relido. O guarda antigo da desativação
     decidia pelo papel lido antes da trava, e com a promoção uma sequência de três atos deixava a
     organização com zero administradores (S3).
  """
  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.User

  @type travado :: %{alvo: User.t(), admins_ativos: [Ecto.UUID.t()]}

  @doc """
  O guarda, dentro de uma transação. Devolve o alvo relido e os ids dos admins ativos travados, ou
  `:nao_autorizado` (o ator não é admin ativo da organização) e `:not_found` (o alvo não é da
  organização).
  """
  @spec travar(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, travado()} | {:error, :nao_autorizado | :not_found}
  def travar(tenant_id, actor_id, alvo_id) do
    admins =
      Repo.all(
        from(u in User,
          where: u.tenant_id == ^tenant_id and u.role == "admin" and is_nil(u.disabled_at),
          order_by: u.id,
          lock: "FOR UPDATE",
          select: u.id
        )
      )

    if actor_id in admins,
      do: alvo_travado(tenant_id, alvo_id, admins),
      else: {:error, :nao_autorizado}
  end

  defp alvo_travado(tenant_id, alvo_id, admins) do
    case Repo.one(
           from(u in User,
             where: u.id == ^alvo_id and u.tenant_id == ^tenant_id,
             lock: "FOR UPDATE"
           )
         ) do
      nil -> {:error, :not_found}
      alvo -> {:ok, %{alvo: alvo, admins_ativos: admins}}
    end
  end

  @doc """
  O alvo é o último administrador ativo? Decide pela struct relida por `travar/3`, e não pela que
  a tela tinha.
  """
  @spec ultimo_admin_ativo?(travado()) :: boolean()
  def ultimo_admin_ativo?(%{alvo: %User{id: id}, admins_ativos: admins}),
    do: id in admins and length(admins) <= 1

  @doc """
  O ator ainda é administrador ativo da organização? Relido no banco, sem trava. É a conferência
  que os atos de administração que já existem fazem no começo (FR-002a; S1): sem ela, um
  rebaixado com a tela aberta continuava administrando.
  """
  @spec exigir_ator(Ecto.UUID.t(), Ecto.UUID.t() | nil) :: :ok | {:error, :nao_autorizado}
  def exigir_ator(tenant_id, actor_id) when is_binary(actor_id) do
    if Repo.exists?(
         from(u in User,
           where:
             u.id == ^actor_id and u.tenant_id == ^tenant_id and u.role == "admin" and
               is_nil(u.disabled_at)
         )
       ),
       do: :ok,
       else: {:error, :nao_autorizado}
  end

  def exigir_ator(_tenant_id, _actor_id), do: {:error, :nao_autorizado}
end
