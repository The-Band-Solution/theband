defmodule TheBand.Tenants.PasswordEpochTest do
  @moduledoc """
  A época da senha — feature 064, T010.

  Ela sobe em **toda** definição de senha, pelos cinco chamadores de `User.senha_changeset/3`,
  e não sobe na entrada. O reinício por quem administra vem primeiro: é a ferramenta de expulsar
  uma conta comprometida, e se a época não subir ali, a sessão do invasor sobrevive.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Repo
  alias TheBand.Tenants.Auth
  alias TheBand.Tenants.Bootstrap
  alias TheBand.Tenants.User
  alias TheBandWeb.ConnCase

  @senha "uma-senha-longa-o-bastante"

  defp epoca(%User{id: id}), do: Repo.get!(User, id).password_epoch

  defp conta do
    {tenant, admin} = ConnCase.tenant_with_admin()

    {:ok, {user, _temporaria}} =
      Auth.cadastrar_conta(
        tenant,
        %{
          "email" => "epoca-#{System.unique_integer([:positive])}@example.test",
          "role" => "member"
        },
        admin
      )

    {tenant, admin, user}
  end

  test "o reinício por quem administra sobe a época" do
    {tenant, admin, user} = conta()
    antes = epoca(user)

    {:ok, _} = Auth.reset_password(tenant, user.id, admin.id)
    assert epoca(user) == antes + 1
  end

  test "o cadastro com temporária nasce com a época 1" do
    # A conta é inserida com 0, e a temporária é a primeira definição de senha.
    {_tenant, _admin, user} = conta()
    assert epoca(user) == 1
  end

  test "a primeira definição pela própria pessoa sobe a época" do
    {tenant, _admin, user} = conta()
    antes = epoca(user)

    {:ok, _} = Auth.set_password(tenant, user.id, @senha)
    assert epoca(user) == antes + 1
  end

  test "a troca pela própria pessoa sobe a época" do
    {tenant, _admin, user} = conta()
    {:ok, _} = Auth.set_password(tenant, user.id, @senha)
    antes = epoca(user)

    {:ok, _} = Auth.change_password(tenant, user.id, @senha, @senha <> "-nova")
    assert epoca(user) == antes + 1
  end

  test "a primeira conta, criada pelo ambiente, nasce com a época 1" do
    ambiente = fn
      "THE_BAND_TENANT_NOME" -> "Época"
      "THE_BAND_TENANT_SLUG" -> "epoca-#{System.unique_integer([:positive])}"
      "THE_BAND_ADMIN_EMAIL" -> "primeira-epoca@example.test"
      "THE_BAND_ADMIN_SENHA" -> @senha
      _ -> nil
    end

    {:ok, :criada, %{email: email}} = Bootstrap.criar_primeira_conta(ambiente)
    assert Repo.get_by!(User, email: email).password_epoch == 1
  end

  test "entrar não sobe a época" do
    {tenant, _admin, user} = conta()
    {:ok, _} = Auth.set_password(tenant, user.id, @senha)
    antes = epoca(user)

    {:ok, _} = Auth.authenticate(user.email, @senha, origem: TheBand.OrigemDeTeste.nova())
    assert epoca(user) == antes
  end

  test "o incremento é atômico: a struct velha não faz a época voltar" do
    # Duas definições a partir da MESMA struct lida — a forma de duas requisições
    # simultâneas. Com `struct.password_epoch + 1`, as duas gravariam o mesmo valor.
    {_tenant, _admin, user} = conta()
    lida = Repo.get!(User, user.id)
    antes = lida.password_epoch

    {:ok, _} = lida |> User.senha_changeset(%{password: @senha}) |> Repo.update()
    {:ok, _} = lida |> User.senha_changeset(%{password: @senha <> "!"}) |> Repo.update()

    assert epoca(user) == antes + 2
  end
end
