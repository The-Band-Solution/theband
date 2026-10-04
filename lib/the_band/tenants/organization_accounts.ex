defmodule TheBand.Tenants.OrganizationAccounts do
  @moduledoc """
  As contas da organização, declaradas pela administração — feature 076, T025 (FR-007; research.md
  R14; R8 da segurança; A20; `contracts/fronteiras.md`, *Contas da organização*).

  A origem apresenta a conta da organização (o caso `LEDS` da referência) como `User`. Nada no
  payload a distingue de uma pessoa, e por isso a plataforma a reconhece por **declaração** de quem
  administra o tenant, e nunca por inferência. A conta declarada não é nó nas duas redes da
  análise; é contada no motivo `organization_account`.

  ## Quem pode, e o que se recusa

  - só a administração **deste** tenant, relida no banco a cada ato
    (`PapelDeAdministrador.exigir_ator/2`): a struct da tela não vale, porque um rebaixado com a
    aba aberta continuaria declarando (S1 da 072);
  - pessoa de outro tenant, inexistente e id malformado dão o mesmo `:not_found`;
  - a pessoa da própria conta de quem declara é recusada (`:own_person`): ninguém se tira da rede;
  - pessoa com elo vigente com uma conta da plataforma é recusada
    (`:linked_to_platform_account`): quem entra na plataforma é gente, e declará-la *conta da
    organização* a tiraria da rede sem que ela soubesse.

  Declarar, revogar e cada recusa registram evento em `AccessEvents`, com tenant, conta que agiu,
  pessoa e resultado.

  ## O que não expõe

  A lista, para quem não administra (a área diz só **quantas**, R8); e a declaração não muda
  `eo_people.account_type`, que a coleta reescreve a cada passada.

  Depende de: EO (a pessoa existe neste tenant, e o nome para a lista). Privado a `TheBand.Tenants`.
  """
  import Ecto.Query

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.Access.OrganizationAccountDeclaration, as: Declaracao
  alias TheBand.Tenants.AccessEvents
  alias TheBand.Tenants.PapelDeAdministrador
  alias TheBand.Tenants.Tenant
  alias TheBand.Tenants.User

  @type declaration_view :: %{
          id: Ecto.UUID.t(),
          person_id: Ecto.UUID.t(),
          person_name: String.t() | nil,
          reason: String.t(),
          declared_by: String.t() | nil,
          declared_at: DateTime.t()
        }

  @doc "Declara a pessoa como conta da organização. Só a administração deste tenant."
  @spec declare(Tenant.t(), term(), String.t(), User.t()) ::
          {:ok, Declaracao.t()}
          | {:error,
             :not_admin
             | :not_found
             | :linked_to_platform_account
             | :own_person
             | Ecto.Changeset.t()}
  def declare(%Tenant{} = tenant, person_id, reason, %User{} = actor) do
    resultado =
      with :ok <- administra(tenant, actor),
           {:ok, id} <- pessoa_do_tenant(tenant, person_id),
           :ok <- nao_e_a_propria(actor, id),
           :ok <- sem_elo(tenant, id) do
        %Declaracao{}
        |> Declaracao.changeset(%{
          tenant_id: tenant.id,
          person_id: id,
          reason: reason,
          declared_by_user_id: actor.id,
          declared_at: DateTime.utc_now(:second)
        })
        |> Repo.insert()
      end

    registrar(:conta_da_organizacao_declarada, tenant, actor, person_id, resultado)
  end

  @doc "Revoga a declaração vigente. A linha fica, com quem revogou e quando."
  @spec revoke(Tenant.t(), term(), User.t()) ::
          {:ok, Declaracao.t()} | {:error, :not_admin | :not_found}
  def revoke(%Tenant{id: tenant_id} = tenant, declaration_id, %User{} = actor) do
    resultado =
      with :ok <- administra(tenant, actor),
           {:ok, id} <- Ecto.UUID.cast(declaration_id) |> ou_nao_encontrada(),
           %Declaracao{} = vigente <-
             Repo.one(
               from d in Declaracao,
                 where: d.id == ^id and d.tenant_id == ^tenant_id and is_nil(d.revoked_at)
             ) || {:error, :not_found} do
        vigente |> Declaracao.revoke_changeset(actor.id) |> Repo.update()
      end

    registrar(
      :conta_da_organizacao_revogada,
      tenant,
      actor,
      pessoa_revogada(resultado),
      resultado
    )
  end

  defp pessoa_revogada({:ok, declaracao}), do: declaracao.person_id
  defp pessoa_revogada(_recusa), do: nil

  @doc """
  As pessoas declaradas como conta da organização, vigentes, deste tenant. Para o cálculo das
  redes: não confere quem pede, porque não chega a tela nenhuma (só o job o chama).
  """
  @spec ids(Tenant.t()) :: MapSet.t()
  def ids(%Tenant{id: tenant_id}) do
    Repo.all(
      from d in Declaracao,
        where: d.tenant_id == ^tenant_id and is_nil(d.revoked_at),
        select: d.person_id
    )
    |> MapSet.new()
  end

  @doc "A lista das declarações vigentes, com quem declarou e quando. Só a administração."
  @spec list(Tenant.t(), User.t()) :: {:ok, [declaration_view()]} | {:error, :not_admin}
  def list(%Tenant{id: tenant_id} = tenant, %User{} = actor) do
    with :ok <- administra(tenant, actor) do
      declaracoes =
        Repo.all(
          from d in Declaracao,
            where: d.tenant_id == ^tenant_id and is_nil(d.revoked_at),
            order_by: [asc: d.declared_at, asc: d.id]
        )

      nomes = EO.people_names(tenant, Enum.map(declaracoes, & &1.person_id))
      contas = Tenants.users_by_id(tenant)

      {:ok,
       Enum.map(declaracoes, fn d ->
         %{
           id: d.id,
           person_id: d.person_id,
           person_name: Map.get(nomes, d.person_id),
           reason: d.reason,
           declared_by: quem(Map.get(contas, d.declared_by_user_id)),
           declared_at: d.declared_at
         }
       end)}
    end
  end

  defp administra(%Tenant{id: tenant_id}, %User{tenant_id: tenant_id, id: actor_id}) do
    case PapelDeAdministrador.exigir_ator(tenant_id, actor_id) do
      :ok -> :ok
      _ -> {:error, :not_admin}
    end
  end

  # Conta de outro tenant nunca administra este, mesmo sendo admin lá.
  defp administra(_tenant, _actor), do: {:error, :not_admin}

  defp pessoa_do_tenant(tenant, person_id) do
    with {:ok, id} <- Ecto.UUID.cast(person_id) |> ou_nao_encontrada() do
      if Map.has_key?(EO.account_types(tenant, [id]), id),
        do: {:ok, id},
        else: {:error, :not_found}
    end
  end

  defp ou_nao_encontrada({:ok, id}), do: {:ok, id}
  defp ou_nao_encontrada(:error), do: {:error, :not_found}

  defp nao_e_a_propria(actor, id) do
    case Tenants.person_of_user(actor) do
      {:ok, ^id} -> {:error, :own_person}
      _ -> :ok
    end
  end

  defp sem_elo(tenant, id) do
    if Tenants.user_of_person(tenant, id),
      do: {:error, :linked_to_platform_account},
      else: :ok
  end

  defp quem(nil), do: nil
  defp quem(%User{} = u), do: u.name || u.email

  # O evento, e o resultado devolvido como veio. Só ids e átomos chegam ao log.
  defp registrar(ato, tenant, actor, person_id, resultado) do
    AccessEvents.conta_da_organizacao(
      ato,
      tenant.id,
      actor.id,
      texto_ou_nil(person_id),
      motivo(resultado)
    )

    resultado
  end

  # Só id válido chega ao log: o id malformado vem de fora, e texto livre numa linha de log é
  # injeção esperando acontecer.
  defp texto_ou_nil(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp motivo({:ok, _}), do: :ok
  defp motivo({:error, motivo}) when is_atom(motivo), do: motivo
  defp motivo({:error, %Ecto.Changeset{}}), do: :invalid
end
