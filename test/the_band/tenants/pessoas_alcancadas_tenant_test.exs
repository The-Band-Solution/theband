defmodule TheBand.Tenants.PessoasAlcancadasTenantTest do
  @moduledoc """
  `Access.pessoas_alcancadas/2` não concede `:todas` a administrador de outra organização — #1181
  (S10 da avaliação de segurança da 072). As outras cláusulas de admin do módulo já comparavam o
  tenant; esta não.
  """
  use TheBand.DataCase, async: true

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Tenants

  test "o administrador alcança todas as pessoas da própria organização" do
    {tenant, admin} = tenant_with_admin()
    assert Tenants.pessoas_alcancadas(tenant, admin) == :todas
  end

  test "o administrador de outra organização não alcança todas" do
    {_dele, admin_de_fora} = tenant_with_admin()
    {outro, _admin} = tenant_with_admin()

    assert {:algumas, alcancadas} = Tenants.pessoas_alcancadas(outro, admin_de_fora)
    assert MapSet.size(alcancadas) == 0
  end
end
