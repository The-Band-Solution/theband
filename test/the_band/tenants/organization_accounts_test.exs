defmodule TheBand.Tenants.OrganizationAccountsTest do
  @moduledoc """
  Declarar e revogar a conta da organização — feature 076, T025 (FR-007; research.md R14; R8 da
  segurança; cenário A20).

  Dois tenants. Só a administração **deste** tenant declara; a pessoa com elo vigente e a pessoa
  da própria conta são recusadas; pessoa de outro tenant, inexistente e id malformado dão o mesmo
  `:not_found`; a marca sobrevive a uma coleta que reescreve `eo_people.account_type`; e cada ato,
  inclusive a recusa, deixa evento com quem agiu.
  """
  use TheBand.DataCase, async: true

  import ExUnit.CaptureLog
  import TheBand.ReviewNetworkFixtures

  alias TheBand.Tenants

  setup do
    tenant = tenant_fixture()
    outro = tenant_fixture()
    admin = user_fixture(tenant, "admin")
    membro = user_fixture(tenant, "member")
    admin_de_fora = user_fixture(outro, "admin")

    leds = pessoa(tenant, "LEDS")
    ana = pessoa(tenant, "Ana")
    de_fora = pessoa(outro, "De Outro Tenant")

    %{
      tenant: tenant,
      outro: outro,
      admin: admin,
      membro: membro,
      admin_de_fora: admin_de_fora,
      leds: leds,
      ana: ana,
      de_fora: de_fora
    }
  end

  test "a administração declara, a lista diz quem e quando, e a revogação tira", ctx do
    assert {:ok, d} =
             Tenants.declare_organization_account(
               ctx.tenant,
               ctx.leds.id,
               " the org account ",
               ctx.admin
             )

    assert d.reason == "the org account"
    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new([ctx.leds.id])
    assert Tenants.organization_account_ids(ctx.outro) == MapSet.new()

    assert {:ok, [linha]} = Tenants.list_organization_accounts(ctx.tenant, ctx.admin)
    assert linha.person_id == ctx.leds.id
    assert linha.person_name == "LEDS"
    assert linha.declared_by == (ctx.admin.name || ctx.admin.email)
    assert %DateTime{} = linha.declared_at

    assert {:ok, revogada} = Tenants.revoke_organization_account(ctx.tenant, d.id, ctx.admin)
    assert revogada.revoked_by_user_id == ctx.admin.id
    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new()
    assert {:error, :not_found} = Tenants.revoke_organization_account(ctx.tenant, d.id, ctx.admin)
  end

  test "membro e administração de outro tenant são recusados, e nada muda", ctx do
    assert {:error, :not_admin} =
             Tenants.declare_organization_account(ctx.tenant, ctx.leds.id, "x", ctx.membro)

    assert {:error, :not_admin} =
             Tenants.declare_organization_account(ctx.tenant, ctx.leds.id, "x", ctx.admin_de_fora)

    assert {:error, :not_admin} = Tenants.list_organization_accounts(ctx.tenant, ctx.membro)
    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new()

    {:ok, d} = Tenants.declare_organization_account(ctx.tenant, ctx.leds.id, "x", ctx.admin)

    assert {:error, :not_admin} =
             Tenants.revoke_organization_account(ctx.tenant, d.id, ctx.membro)

    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new([ctx.leds.id])
  end

  test "outro tenant, inexistente e id malformado dão o mesmo :not_found", ctx do
    for id <- [ctx.de_fora.id, Ecto.UUID.generate(), "abc", nil] do
      assert {:error, :not_found} =
               Tenants.declare_organization_account(ctx.tenant, id, "x", ctx.admin)
    end

    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new()
  end

  test "pessoa com elo vigente e a pessoa da própria conta são recusadas", ctx do
    {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.membro.id, ctx.ana.id, ctx.admin.id)

    assert {:error, :linked_to_platform_account} =
             Tenants.declare_organization_account(ctx.tenant, ctx.ana.id, "x", ctx.admin)

    {:ok, admin} = Tenants.declare_person(ctx.tenant, ctx.admin.id, ctx.leds.id, ctx.admin.id)

    assert {:error, :own_person} =
             Tenants.declare_organization_account(ctx.tenant, ctx.leds.id, "x", admin)

    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new()
  end

  test "motivo vazio é recusado", ctx do
    assert {:error, %Ecto.Changeset{}} =
             Tenants.declare_organization_account(ctx.tenant, ctx.leds.id, "   ", ctx.admin)
  end

  test "a marca sobrevive a uma coleta que reescreve account_type (A20)", ctx do
    {:ok, _} = Tenants.declare_organization_account(ctx.tenant, ctx.leds.id, "x", ctx.admin)

    # A coleta de EO reescreve o tipo a cada passada; a declaração não mora lá.
    Repo.query!("update eo_people set account_type = 'person' where id = $1", [
      Ecto.UUID.dump!(ctx.leds.id)
    ])

    assert Tenants.organization_account_ids(ctx.tenant) == MapSet.new([ctx.leds.id])

    {:ok, %{rows: [[tipo]]}} =
      Repo.query("select account_type from eo_people where id = $1", [
        Ecto.UUID.dump!(ctx.leds.id)
      ])

    assert tipo == "person"
  end

  test "declarar e recusar deixam evento com quem agiu", ctx do
    log =
      capture_log(fn ->
        {:ok, _} = Tenants.declare_organization_account(ctx.tenant, ctx.leds.id, "x", ctx.admin)

        {:error, :not_admin} =
          Tenants.declare_organization_account(ctx.tenant, ctx.ana.id, "x", ctx.membro)
      end)

    assert log =~ "ato=:conta_da_organizacao_declarada"
    assert log =~ ~s(actor_user_id="#{ctx.admin.id}")
    assert log =~ ~s(person_id="#{ctx.leds.id}" resultado=:ok)
    assert log =~ ~s(actor_user_id="#{ctx.membro.id}")
    assert log =~ "resultado=:not_admin"
  end
end
