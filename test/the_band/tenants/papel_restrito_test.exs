defmodule TheBand.Tenants.PapelRestritoTest do
  @moduledoc """
  O papel da conta é restrito — spec 072, T001 (FR-006; S4 e S7 de `seguranca.md`).
  """
  use TheBand.DataCase, async: false

  alias TheBand.Tenants
  alias TheBand.Tenants.User

  setup do
    tenant = tenant_fixture()
    %{tenant: tenant, admin: user_fixture(tenant)}
  end

  test "o cadastro pela tela cria member, mesmo com \"role\" => \"admin\" nos atributos", ctx do
    {:ok, {user, _temporaria}} =
      Tenants.cadastrar_conta(
        ctx.tenant,
        %{
          "email" => "nova-#{System.unique_integer([:positive])}@example.test",
          "role" => "admin"
        },
        ctx.admin
      )

    assert Repo.get!(User, user.id).role == "member"
  end

  test "o changeset não muda o papel de uma conta existente", ctx do
    {:ok, depois} = ctx.admin |> User.changeset(%{"role" => "member"}) |> Repo.update()
    assert depois.role == "admin"
  end

  test "um papel fora da lista é recusado pelo banco", ctx do
    erro =
      assert_raise Postgrex.Error, fn ->
        Repo.update_all(from(u in User, where: u.id == ^ctx.admin.id), set: [role: "Admin"])
      end

    assert erro.postgres.constraint == "users_role_valido"
  end

  test "a migração levanta, com a contagem, quando há papel fora da lista", ctx do
    modulo = TheBand.Repo.Migrations.PapelValido

    unless Code.ensure_loaded?(modulo),
      do: Code.require_file("priv/repo/migrations/20261003100000_papel_valido.exs")

    assert :ok = modulo.conferir_papeis!(Repo)
    Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")
    Repo.query!("SET CONSTRAINTS ALL DEFERRED")
    Repo.query!("ALTER TABLE users DROP CONSTRAINT users_role_valido")
    Repo.update_all(from(u in User, where: u.id == ^ctx.admin.id), set: [role: "x"])

    erro = assert_raise RuntimeError, fn -> modulo.conferir_papeis!(Repo) end
    assert erro.message =~ ~r/^1 conta\(s\) com papel fora/
  end
end
