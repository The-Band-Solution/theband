defmodule TheBand.Tenants.PessoasAlcancadasConcedidaTest do
  @moduledoc """
  O alcance por concessão — feature 076, T015 (DS1 (b); R11; `contracts/fronteiras.md`).

  ## As asserções que carregam este arquivo

  1. a conta que só tem vínculo de equipe alcança o colega pela `/2` e **não** pela `/3`;
  2. com concessão de equipe, alcança pelas duas;
  3. a própria pessoa entra sempre na `/3`;
  4. a administração deste tenant é `:todas`; a de **outro** tenant, não.

  Dois tenants povoados; o colega de T2 nunca aparece.

  **Defeito a injetar**: aceitar `origin: :derived_team` na `/3`; o caso do vínculo reprova.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs("U_#{login}", %{name: login, login: login, account_type: "person"})
      )

    p
  end

  defp conta(tenant, admin, pessoa) do
    {:ok, u} =
      Tenants.create_user(tenant, %{
        "email" => "#{pessoa.login}-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, ligada} = Tenants.declare_person(tenant, u.id, pessoa.id, admin.id)
    ligada
  end

  defp cenario(tenant) do
    admin = user_fixture(tenant)
    org = organization_fixture(tenant, "acme-#{System.unique_integer([:positive])}")
    {:ok, equipe} = EO.create_declared_team(tenant, "Delivery", admin.id)
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)

    ana = pessoa(tenant, "ana#{System.unique_integer([:positive])}")
    bia = pessoa(tenant, "bia#{System.unique_integer([:positive])}")
    caio = pessoa(tenant, "caio#{System.unique_integer([:positive])}")

    for p <- [ana, bia] do
      {:ok, _} =
        EO.allocate(tenant, %{
          person_id: p.id,
          team_id: equipe.id,
          organizational_role_id: papel.id,
          started_at: DateTime.add(DateTime.utc_now(:second), -86_400),
          declared_by_user_id: admin.id
        })
    end

    %{admin: admin, equipe: equipe, ana: ana, bia: bia, caio: caio}
  end

  setup do
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    %{t1: t1, t2: t2, c1: cenario(t1), c2: cenario(t2)}
  end

  test "só com vínculo de equipe: alcança o colega pela /2 e não pela /3", ctx do
    conta_ana = conta(ctx.t1, ctx.c1.admin, ctx.c1.ana)

    assert {:algumas, pela_2} = Tenants.pessoas_alcancadas(ctx.t1, conta_ana)

    assert MapSet.member?(pela_2, ctx.c1.bia.id),
           "a /2 não mediu o vínculo: o refute abaixo não provaria nada"

    assert {:algumas, pela_3} = Tenants.pessoas_alcancadas(ctx.t1, conta_ana, origem: :concedida)
    refute MapSet.member?(pela_3, ctx.c1.bia.id)
    assert MapSet.member?(pela_3, ctx.c1.ana.id), "a própria pessoa entra sempre"
    refute MapSet.member?(pela_3, ctx.c2.bia.id)
  end

  test "com concessão de equipe, alcança pelas duas", ctx do
    conta_caio = conta(ctx.t1, ctx.c1.admin, ctx.c1.caio)
    {:ok, _} = Tenants.grant_scope(ctx.t1, conta_caio.id, :team, ctx.c1.equipe.id, ctx.c1.admin)

    for alcance <- [
          Tenants.pessoas_alcancadas(ctx.t1, conta_caio),
          Tenants.pessoas_alcancadas(ctx.t1, conta_caio, origem: :concedida)
        ] do
      assert {:algumas, ids} = alcance
      assert MapSet.member?(ids, ctx.c1.ana.id)
      assert MapSet.member?(ids, ctx.c1.bia.id)
      refute MapSet.member?(ids, ctx.c2.ana.id)
    end
  end

  test "administração deste tenant é :todas; a de outro tenant, não", ctx do
    assert Tenants.pessoas_alcancadas(ctx.t1, ctx.c1.admin, origem: :concedida) == :todas
    refute Tenants.pessoas_alcancadas(ctx.t1, ctx.c2.admin, origem: :concedida) == :todas
  end
end
