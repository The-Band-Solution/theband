defmodule TheBand.TenantsCadastroTest do
  @moduledoc """
  Feature 051, T002/T003 — contrato `contas-e-elo.md`.

  A violação primeiro (L03): e-mail duplicado não cria NADA — nem conta, nem
  senha; o cadastro é uma transação. E a leitura estreita do conflito devolve a
  dona do elo vigente, nunca a de outro tenant.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0, tenant_with_admin: 1]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.User

  setup do
    {tenant, admin} = tenant_with_admin()
    %{tenant: tenant, admin: admin}
  end

  defp contas(tenant_id),
    do: Repo.aggregate(from(u in User, where: u.tenant_id == ^tenant_id), :count)

  defp pessoa(tenant, login) do
    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: String.capitalize(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second)
      })

    pessoa
  end

  describe "cadastrar_conta/3 — tudo ou nada" do
    test "a violação: e-mail duplicado não cria nada", ctx do
      antes = contas(ctx.tenant.id)

      assert {:error, %Ecto.Changeset{} = cs} =
               Tenants.cadastrar_conta(
                 ctx.tenant,
                 %{"name" => "Duplicada", "email" => ctx.admin.email},
                 ctx.admin
               )

      assert {"has already been taken", _} = cs.errors[:email]
      assert contas(ctx.tenant.id) == antes
    end

    test "o feliz: conta nasce COM a temporária, e ela autentica com troca forçada", ctx do
      assert {:ok, {user, temporaria}} =
               Tenants.cadastrar_conta(
                 ctx.tenant,
                 %{"name" => "Nova Pessoa", "email" => "nova@example.test"},
                 ctx.admin
               )

      assert user.must_change_password
      assert is_binary(temporaria) and byte_size(temporaria) >= 12

      # A temporária autentica — o mesmo contrato da 045.
      assert {:ok, autenticada} = Tenants.authenticate("nova@example.test", temporaria)
      assert autenticada.id == user.id
      assert autenticada.must_change_password
    end
  end

  describe "user_of_person/2 — a leitura estreita do conflito" do
    test "devolve a dona do elo vigente; nil sem elo; e some quando revogado", ctx do
      alvo = pessoa(ctx.tenant, "alvo")
      assert Tenants.user_of_person(ctx.tenant, alvo.id) == nil

      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, alvo.id, ctx.admin.id)
      assert %User{id: id} = Tenants.user_of_person(ctx.tenant, alvo.id)
      assert id == ctx.admin.id

      {:ok, _} = Tenants.revoke_person(ctx.tenant, ctx.admin.id, ctx.admin.id)
      assert Tenants.user_of_person(ctx.tenant, alvo.id) == nil
    end

    test "a violação entre tenants: a pessoa de um não nomeia conta do outro", ctx do
      alvo = pessoa(ctx.tenant, "da-casa")
      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, alvo.id, ctx.admin.id)

      {outro, _} = tenant_with_admin("outro")
      assert Tenants.user_of_person(outro, alvo.id) == nil
    end
  end
end
