defmodule TheBand.Tenants.AtorRelidoTest do
  @moduledoc """
  Os atos de administração conferem o ator relido no banco — spec 072, T008 (FR-002a; S1).

  O papel fica congelado no `mount` do LiveView. Cada caso chama o ato com a struct de um
  administrador que **já foi rebaixado**, como a aba aberta dele faria, e prova a recusa e que
  nada mudou. `Access.grant/5` e `revoke/3` recusam com `:not_admin`, que já era o contrato delas;
  os demais, com `:nao_autorizado`.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants
  alias TheBand.Tenants.Access.ScopeGrant
  alias TheBand.Tenants.Schemas.ApiAccessToken
  alias TheBand.Tenants.User

  setup do
    {tenant, a} = tenant_with_admin()
    b = conta(tenant, "admin")
    m = conta(tenant, "member")
    org = organization_fixture(tenant)

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, %{
        login: "p#{System.unique_integer([:positive])}",
        name: "Pessoa",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_#{System.unique_integer([:positive])}",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, grant} = Tenants.grant_scope(tenant, m.id, :organization, org.id, a)
    {:ok, token, _} = Tenants.create_api_token(tenant, m, %{label: "do membro"}, a)
    {:ok, _} = Tenants.declare_person(tenant, m.id, pessoa.id, a.id)

    # A struct de B é a de antes do rebaixamento: `role: "admin"`, como a tela a guardou.
    {:ok, _} = Tenants.demote_user(tenant, b.id, a)
    rebaixado = b

    %{
      tenant: tenant,
      a: a,
      b: rebaixado,
      m: Repo.get!(User, m.id),
      org: org,
      pessoa: pessoa,
      grant: grant,
      token: token
    }
  end

  defp conta(tenant, papel) do
    {:ok, u} =
      Tenants.create_user(tenant, %{
        "email" => "r-#{System.unique_integer([:positive])}@example.test",
        "role" => papel
      })

    u
  end

  defp foto(ctx) do
    {
      Repo.aggregate(where(User, tenant_id: ^ctx.tenant.id), :count),
      Repo.get!(User, ctx.m.id),
      Repo.aggregate(where(ScopeGrant, tenant_id: ^ctx.tenant.id), :count),
      Repo.get!(ScopeGrant, ctx.grant.id).revoked_at,
      Repo.aggregate(where(ApiAccessToken, tenant_id: ^ctx.tenant.id), :count),
      Repo.get!(ApiAccessToken, ctx.token.id).revoked_at
    }
  end

  test "a struct guardada ainda diz admin: é a premissa de cada caso", ctx do
    assert ctx.b.role == "admin"
    assert Repo.get!(User, ctx.b.id).role == "member"
  end

  test "cadastrar_conta", ctx do
    antes = foto(ctx)
    attrs = %{"email" => "nova@example.test", "name" => "Nova"}
    assert Tenants.cadastrar_conta(ctx.tenant, attrs, ctx.b) == {:error, :nao_autorizado}
    assert foto(ctx) == antes
  end

  test "reset_password", ctx do
    antes = foto(ctx)
    assert Tenants.reset_password(ctx.tenant, ctx.m.id, ctx.b.id) == {:error, :nao_autorizado}
    assert foto(ctx) == antes
  end

  test "enable_user", ctx do
    {:ok, _} =
      Tenants.disable_user(ctx.tenant, ctx.m.id, ctx.a.id, %{"reason" => "left_the_organisation"})

    antes = foto(ctx)

    assert Tenants.enable_user(ctx.tenant, ctx.m.id, ctx.b.id, %{
             "reason" => "returned_to_the_organisation"
           }) == {:error, :nao_autorizado}

    assert foto(ctx) == antes
  end

  test "disable_user, pelo guarda do papel", ctx do
    antes = foto(ctx)

    assert Tenants.disable_user(ctx.tenant, ctx.m.id, ctx.b.id, %{
             "reason" => "left_the_organisation"
           }) == {:error, :nao_autorizado}

    assert foto(ctx) == antes
  end

  test "declare_person", ctx do
    antes = foto(ctx)

    assert Tenants.declare_person(ctx.tenant, ctx.b.id, ctx.pessoa.id, ctx.b.id) ==
             {:error, :nao_autorizado}

    assert foto(ctx) == antes
  end

  test "revoke_person", ctx do
    antes = foto(ctx)
    assert Tenants.revoke_person(ctx.tenant, ctx.m.id, ctx.b.id) == {:error, :nao_autorizado}
    assert foto(ctx) == antes
  end

  test "grant_scope", ctx do
    antes = foto(ctx)

    assert Tenants.grant_scope(ctx.tenant, ctx.b.id, :organization, ctx.org.id, ctx.b) ==
             {:error, :not_admin}

    assert foto(ctx) == antes
  end

  test "revoke_scope", ctx do
    antes = foto(ctx)
    assert Tenants.revoke_scope(ctx.tenant, ctx.grant.id, ctx.b) == {:error, :not_admin}
    assert foto(ctx) == antes
  end

  test "create_api_token para outra conta — o caminho de S1", ctx do
    antes = foto(ctx)

    assert Tenants.create_api_token(ctx.tenant, ctx.a, %{label: "como o admin"}, ctx.b) ==
             {:error, :nao_autorizado}

    assert foto(ctx) == antes
  end

  test "create_api_token para a própria conta não é ato de administração", ctx do
    assert {:ok, _, _} = Tenants.create_api_token(ctx.tenant, ctx.b, %{label: "meu"}, ctx.b)
  end

  test "revoke_api_token", ctx do
    antes = foto(ctx)

    assert Tenants.revoke_api_token(ctx.tenant, ctx.token.id, ctx.b, %{
             revocation_clause: "no_longer_needed"
           }) == {:error, :nao_autorizado}

    assert foto(ctx) == antes
  end
end
