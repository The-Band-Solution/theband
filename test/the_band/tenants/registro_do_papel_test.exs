defmodule TheBand.Tenants.RegistroDoPapelTest do
  @moduledoc """
  O registro das mudanças de papel, garantido no banco — spec 072, T002 e T003 (FR-005, SC-002;
  S6 de `seguranca.md`). O sandbox nunca faz `COMMIT`, e cada caso força a conferência do trigger
  adiado com `SET CONSTRAINTS ALL IMMEDIATE`. A asserção é sobre `postgres.constraint`, e não só
  sobre a classe do erro (G3 da 070).
  """
  # Síncrono: o TRUNCATE … CASCADE pede ACCESS EXCLUSIVE, e travaria os testes assíncronos.
  use TheBand.DataCase, async: false

  alias TheBand.Tenants.Schemas.AccountRoleChange
  alias TheBand.Tenants.User

  setup do
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    membro = user_fixture(tenant, "member")
    %{tenant: tenant, admin: admin, membro: membro}
  end

  defp episodio(ctx, de, para) do
    Repo.insert!(%AccountRoleChange{
      tenant_id: ctx.tenant.id,
      user_id: ctx.membro.id,
      changed_by_user_id: ctx.admin.id,
      from_role: de,
      to_role: para
    })
  end

  defp mudar_papel(ctx, para),
    do: Repo.update_all(from(u in User, where: u.id == ^ctx.membro.id), set: [role: para])

  defp conferir!(fun) do
    Repo.transaction(fn ->
      fun.()
      Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")
    end)
  end

  describe "somente-acréscimo (T002)" do
    test "DELETE, UPDATE e TRUNCATE levantam", ctx do
      ep = episodio(ctx, "member", "admin")
      Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")
      Repo.query!("SET CONSTRAINTS ALL DEFERRED")

      for sql <- [
            "DELETE FROM account_role_changes WHERE id = '#{ep.id}'",
            "UPDATE account_role_changes SET note = 'x' WHERE id = '#{ep.id}'",
            "TRUNCATE account_role_changes CASCADE"
          ] do
        erro = assert_raise Postgrex.Error, fn -> Repo.transaction(fn -> Repo.query!(sql) end) end
        assert erro.postgres.code == :restrict_violation, sql
      end

      assert Repo.get!(AccountRoleChange, ep.id).note == nil
    end

    test "o papel de chegada igual ao de partida é recusado", ctx do
      erro = assert_raise Ecto.ConstraintError, fn -> episodio(ctx, "member", "member") end
      assert erro.constraint == "account_role_changes_papeis_validos"
    end
  end

  describe "o papel só muda com episódio (T003)" do
    test "update_all do papel, sem episódio, é recusado no COMMIT", ctx do
      erro = assert_raise Postgrex.Error, fn -> conferir!(fn -> mudar_papel(ctx, "admin") end) end
      assert erro.postgres.constraint == "users_papel_tem_episodio"
    end

    test "a sequência legítima, o papel e o episódio na mesma transação, passa", ctx do
      assert {:ok, _} =
               conferir!(fn ->
                 mudar_papel(ctx, "admin")
                 episodio(ctx, "member", "admin")
               end)
    end

    # "Um episódio de outra transação não vale" não se mede aqui: no sandbox, os savepoints
    # compartilham o `txid` da transação de cima, e as duas escritas seriam da mesma. A ligação pelo
    # `txid` vale fora dele, no `COMMIT` real.
  end
end
