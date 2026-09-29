defmodule TheBand.Tenants.UserSessionsTableTest do
  @moduledoc """
  A tabela de sessões — feature 064, T009.

  O que a tabela recusa **por si**, sem depender de quem escreve nela: dois registros com o
  mesmo resumo, e uma sessão com o `user_id` de um tenant e o `tenant_id` de outro (S9).
  """
  use TheBand.DataCase, async: true

  alias TheBand.Repo
  alias TheBand.Tenants.Schemas.UserSession
  alias TheBandWeb.ConnCase

  defp sessao(tenant_id, user_id, hash \\ :crypto.strong_rand_bytes(32)) do
    %UserSession{}
    |> UserSession.changeset(%{
      tenant_id: tenant_id,
      user_id: user_id,
      token_hash: hash,
      password_epoch: 0
    })
    |> Repo.insert()
  end

  test "uma sessão válida é gravada, aberta e sem o bruto" do
    {tenant, user} = ConnCase.tenant_with_admin()
    assert {:ok, s} = sessao(tenant.id, user.id)
    assert s.ended_at == nil
    assert byte_size(s.token_hash) == 32
  end

  test "dois registros com o mesmo resumo são recusados pelo banco" do
    {tenant, user} = ConnCase.tenant_with_admin()
    hash = :crypto.strong_rand_bytes(32)
    {:ok, _} = sessao(tenant.id, user.id, hash)

    assert {:error, cs} = sessao(tenant.id, user.id, hash)
    assert {"has already been taken", _} = cs.errors[:token_hash]
  end

  test "a sessão com o user_id de um tenant e o tenant_id de outro é recusada pelo banco" do
    {tenant_a, user_a} = ConnCase.tenant_with_admin()
    {tenant_b, _} = ConnCase.tenant_with_admin()

    assert {:error, cs} = sessao(tenant_b.id, user_a.id)
    assert {"does not exist", _} = cs.errors[:user_id]
    assert {:ok, _} = sessao(tenant_a.id, user_a.id)
  end

  test "o inspect não mostra o resumo" do
    {tenant, user} = ConnCase.tenant_with_admin()
    {:ok, s} = sessao(tenant.id, user.id)
    refute inspect(s) =~ inspect(s.token_hash)
  end

  test "apagar a conta apaga as sessões dela" do
    {tenant, user} = ConnCase.tenant_with_admin()
    {:ok, s} = sessao(tenant.id, user.id)

    Repo.delete!(user)
    refute Repo.get(UserSession, s.id)
  end
end
