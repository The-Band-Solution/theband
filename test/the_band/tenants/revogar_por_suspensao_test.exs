defmodule TheBand.Tenants.RevogarPorSuspensaoTest do
  @moduledoc """
  Revogar os tokens de uma organização suspensa — spec 070, T047 (FR-013, O12; `data-model.md` §6).
  """
  use TheBand.DataCase, async: true

  import TheBand.OperadorFixtures

  alias TheBand.Platform.Suspension
  alias TheBand.Tenants
  alias TheBand.Tenants.ApiTokens
  alias TheBand.Tenants.Schemas.ApiAccessToken, as: Token

  defp token(tenant, admin, rotulo) do
    {:ok, t, _valor} = Tenants.create_api_token(tenant, admin, %{label: rotulo}, admin)
    t
  end

  defp episodio(tenant) do
    {op, _} = operador_pronto()

    Repo.insert!(%Suspension{
      tenant_id: tenant.id,
      suspended_at: DateTime.utc_now(:second),
      suspended_by_operator_id: op.id,
      suspend_reason: "contract_ended"
    })
  end

  setup do
    a = tenant_fixture()
    b = tenant_fixture()
    %{a: a, b: b, admin_a: user_fixture(a), admin_b: user_fixture(b)}
  end

  test "os vigentes de A caem com a cláusula; o já revogado mantém o autor; os de B ficam", ctx do
    vigente = token(ctx.a, ctx.admin_a, "vigente")
    antigo = token(ctx.a, ctx.admin_a, "antigo")

    {:ok, _} =
      Tenants.revoke_api_token(ctx.a, antigo.id, ctx.admin_a, %{revocation_clause: "outro"})

    de_b = token(ctx.b, ctx.admin_b, "de B")
    ep = episodio(ctx.a)

    assert {:ok, 1} = ApiTokens.revogar_por_suspensao(ctx.a, ep.id)

    v = Repo.get!(Token, vigente.id)
    assert v.revoked_at && v.revocation_clause == "organizacao_suspensa"
    assert v.revoked_by_suspension_id == ep.id and v.revoked_by_user_id == nil

    a2 = Repo.get!(Token, antigo.id)
    assert a2.revoked_by_user_id == ctx.admin_a.id and a2.revocation_clause == "outro"
    assert a2.revoked_by_suspension_id == nil

    assert Repo.get!(Token, de_b.id).revoked_at == nil
  end

  test "os dois CHECKs: cláusula sem episódio e episódio sem cláusula são recusados", ctx do
    t = token(ctx.a, ctx.admin_a, "x")
    ep = episodio(ctx.a)
    agora = DateTime.utc_now(:second)

    for {campos, restricao} <- [
          {[revoked_at: agora, revocation_clause: "organizacao_suspensa"],
           "api_access_tokens_clausula_tem_suspensao"},
          {[revoked_at: agora, revocation_clause: "outro", revoked_by_suspension_id: ep.id],
           "api_access_tokens_suspensao_tem_clausula"}
        ] do
      erro =
        assert_raise Postgrex.Error, fn ->
          Repo.transaction(fn ->
            Repo.update_all(from(x in Token, where: x.id == ^t.id), set: campos)
          end)
        end

      assert erro.postgres.constraint == restricao
    end
  end

  test "a cláusula da suspensão é registrada, e o select não a oferece" do
    assert "organizacao_suspensa" in ApiTokens.clausulas_registradas()
    refute "organizacao_suspensa" in ApiTokens.clausulas_de_revogacao()

    assert {"organizacao_suspensa", "organisation suspended"} in ApiTokens.rotulos_registrados()
  end
end
