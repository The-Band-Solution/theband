defmodule TheBand.Tenants.MudancaDePapel do
  @moduledoc """
  Promover e rebaixar administrador — spec 072, T006 e T010 (FR-001 a FR-005, FR-007, FR-008).
  Contrato em `specs/072-papel-de-administrador/contracts/papel.md`.

  Depende de: nenhuma ontologia. Usa o guarda de `TheBand.Tenants.PapelDeAdministrador`.

  Cada ato é uma transação: o guarda (trava os admins ativos, confere o ator, relê o alvo), a
  escrita de `users.role` e o episódio, que o trigger adiado do banco exige na mesma transação.
  Depois do `commit`, e só depois, o aviso às telas abertas do rebaixado e o evento de acesso.
  """
  import Ecto.Query

  alias TheBand.Repo
  alias TheBand.Tenants.{AccessEvents, PapelDeAdministrador, Sessions, Tenant, User}
  alias TheBand.Tenants.Schemas.AccountRoleChange

  @type motivo ::
          :nao_autorizado
          | :not_found
          | :ultimo_admin_ativo
          | {:estado_mudou, AccountRoleChange.t() | nil}
          | :conta_desativada

  @doc "Promove a administrador uma conta ativa da organização."
  @spec promover(Tenant.t(), Ecto.UUID.t(), User.t(), keyword()) ::
          {:ok, AccountRoleChange.t()} | {:error, motivo()}
  def promover(%Tenant{} = tenant, user_id, %User{} = ator, opcoes \\ []),
    do: mudar(tenant, user_id, ator, "admin", opcoes)

  @doc """
  Rebaixa a membro um administrador da organização, nunca o último ativo. Um administrador
  desativado também pode ser rebaixado (Q1, decidida em 2026-10-03), e não conta para o guarda.
  """
  @spec rebaixar(Tenant.t(), Ecto.UUID.t(), User.t(), keyword()) ::
          {:ok, AccountRoleChange.t()} | {:error, motivo()}
  def rebaixar(%Tenant{} = tenant, user_id, %User{} = ator, opcoes \\ []),
    do: mudar(tenant, user_id, ator, "member", opcoes)

  defp mudar(tenant, user_id, ator, para, opcoes) do
    Repo.transaction(fn ->
      with {:ok, travado} <- PapelDeAdministrador.travar(tenant.id, ator.id, user_id),
           :ok <- cabe(travado, para) do
        escrever(tenant, travado.alvo, ator, para, opcoes[:note])
      else
        {:error, motivo} -> Repo.rollback(motivo)
      end
    end)
    |> depois_do_commit(tenant, user_id, ator, para)
  end

  # D5 do protótipo: quem chegou atrasado lê quem mudou antes dele, e quando.
  defp cabe(%{alvo: %User{role: para} = alvo}, para),
    do: {:error, {:estado_mudou, ultimo_episodio(alvo.id)}}

  defp cabe(%{alvo: %User{disabled_at: desativada}}, "admin") when not is_nil(desativada),
    do: {:error, :conta_desativada}

  defp cabe(travado, "member") do
    if PapelDeAdministrador.ultimo_admin_ativo?(travado),
      do: {:error, :ultimo_admin_ativo},
      else: :ok
  end

  defp cabe(_travado, "admin"), do: :ok

  defp ultimo_episodio(user_id) do
    Repo.one(
      from(c in AccountRoleChange,
        where: c.user_id == ^user_id,
        order_by: [desc: c.inserted_at, desc: c.id],
        limit: 1
      )
    )
  end

  defp escrever(tenant, alvo, ator, para, nota) do
    {1, _} =
      Repo.update_all(from(u in User, where: u.id == ^alvo.id and u.role == ^alvo.role),
        set: [role: para, updated_at: DateTime.utc_now(:second)]
      )

    Repo.insert!(%AccountRoleChange{
      tenant_id: tenant.id,
      user_id: alvo.id,
      changed_by_user_id: ator.id,
      from_role: alvo.role,
      to_role: para,
      note: nota_ou_nil(nota)
    })
  end

  defp nota_ou_nil(nota) when is_binary(nota),
    do: if(String.trim(nota) == "", do: nil, else: String.trim(nota))

  defp nota_ou_nil(_), do: nil

  # FR-008: o aviso só depois do `commit`, no tópico da conta (#1042). A tela aberta do rebaixado
  # relê a conta e sai da área de administração. A nota nunca vai ao log (FR-007).
  defp depois_do_commit({:ok, ep}, tenant, user_id, ator, para) do
    if para == "member", do: Sessions.avisar_encerramento({:conta, user_id})

    AccessEvents.ato_administrativo(
      if(para == "admin", do: :conta_promovida, else: :conta_rebaixada),
      user_id,
      tenant.id,
      por: ator.id,
      de: ep.from_role,
      para: ep.to_role
    )

    {:ok, ep}
  end

  defp depois_do_commit({:error, motivo}, tenant, user_id, ator, para) do
    AccessEvents.ato_administrativo(:papel_recusado, user_id, tenant.id,
      por: ator.id,
      para: para,
      motivo: if(is_tuple(motivo), do: elem(motivo, 0), else: motivo)
    )

    {:error, motivo}
  end

  @doc """
  O último episódio de cada conta para `admin` e o último para `member` (T011, a célula
  `Management`). Conta sem episódio fica fora do mapa, e a tela diz a ausência (Q6).
  """
  @spec resumo_por_conta(Tenant.t(), [Ecto.UUID.t()]) :: %{
          Ecto.UUID.t() => %{
            ate_admin: AccountRoleChange.t() | nil,
            ate_membro: AccountRoleChange.t() | nil
          }
        }
  def resumo_por_conta(%Tenant{id: tenant_id}, ids) do
    from(c in AccountRoleChange,
      where: c.tenant_id == ^tenant_id and c.user_id in ^ids,
      distinct: [c.user_id, c.to_role],
      order_by: [c.user_id, c.to_role, desc: c.inserted_at, desc: c.id]
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn ep, acc ->
      chave = if ep.to_role == "admin", do: :ate_admin, else: :ate_membro

      Map.update(
        acc,
        ep.user_id,
        %{ate_admin: nil, ate_membro: nil} |> Map.put(chave, ep),
        &Map.put(&1, chave, ep)
      )
    end)
  end

  @doc """
  As mudanças de papel da organização, da mais nova à mais antiga, e quantas há ao todo (T010; Q5:
  as 20 mais recentes por padrão). Com quem mudou e quem agiu carregados só por nome e e-mail.
  """
  @spec listar(Tenant.t(), keyword()) :: %{mudancas: [AccountRoleChange.t()], total: integer()}
  def listar(%Tenant{id: tenant_id}, opcoes \\ []) do
    base = from(c in AccountRoleChange, where: c.tenant_id == ^tenant_id)
    so_o_nome = from(u in User, select: struct(u, [:id, :name, :email]))

    mudancas =
      Repo.all(
        from(c in base,
          order_by: [desc: c.inserted_at, desc: c.id],
          limit: ^Keyword.get(opcoes, :limit, 20),
          preload: [user: ^so_o_nome, changed_by_user: ^so_o_nome]
        )
      )

    %{mudancas: mudancas, total: Repo.aggregate(base, :count)}
  end
end
