defmodule TheBand.Tenants.EncerrarDaOrganizacaoTest do
  @moduledoc """
  Encerrar as sessões de uma organização — spec 070, T046 (FR-004; cenário 5 de `seguranca.md`).
  """
  use TheBand.DataCase, async: true

  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.UserSession
  alias TheBand.Tenants.Sessions

  defp conta(tenant) do
    {:ok, user} =
      Tenants.create_user(tenant, %{
        "email" => "c-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, {sessao, _}} = Sessions.abrir(user)
    sessao
  end

  test "as sessões de A caem, as de B ficam, e os ids encerrados voltam" do
    a = tenant_fixture()
    b = tenant_fixture()
    de_a = [conta(a), conta(a)]
    de_b = [conta(b), conta(b)]

    assert {:ok, ids} = Sessions.encerrar_da_organizacao(a)
    assert Enum.sort(ids) == Enum.sort(Enum.map(de_a, & &1.id))

    for s <- de_a, do: assert(Repo.get!(UserSession, s.id).ended_at)

    abertas_de_b = for s <- de_b, is_nil(Repo.get!(UserSession, s.id).ended_at), do: s
    assert length(abertas_de_b) == 2
  end

  test "encerrar de novo não devolve id nenhum" do
    a = tenant_fixture()
    conta(a)
    {:ok, [_]} = Sessions.encerrar_da_organizacao(a)
    assert Sessions.encerrar_da_organizacao(a) == {:ok, []}
  end
end
