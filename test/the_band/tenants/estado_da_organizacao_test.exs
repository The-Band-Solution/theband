defmodule TheBand.Tenants.EstadoDaOrganizacaoTest do
  @moduledoc """
  O estado da organização é restrito — spec 070, T013, achado O10.

  Era texto livre e castável: qualquer chamador de `Tenant.changeset/2` mudava o estado sem
  episódio, e um valor com a caixa errada entrava sem ninguém perceber.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant

  setup do
    {:ok, tenant} =
      Tenants.create_tenant(%{
        "name" => "Org",
        "slug" => "org-#{System.unique_integer([:positive])}"
      })

    %{tenant: tenant}
  end

  test "o changeset não muda o estado: :status não é castável", %{tenant: tenant} do
    {:ok, depois} = tenant |> Tenant.changeset(%{"status" => "suspended"}) |> Repo.update()

    assert depois.status == "active"
    assert Repo.get!(Tenant, tenant.id).status == "active"
  end

  test "criar já suspensa pelo changeset não pega: nasce ativa" do
    {:ok, t} =
      Tenants.create_tenant(%{
        "name" => "Org2",
        "slug" => "org2-#{System.unique_integer([:positive])}",
        "status" => "suspended"
      })

    assert t.status == "active"
  end

  test "um estado fora da lista é recusado pelo banco", %{tenant: tenant} do
    assert_raise Postgrex.Error, ~r/tenants_status_valido/, fn ->
      Repo.update_all(from(t in Tenant, where: t.id == ^tenant.id), set: [status: "Suspended"])
    end
  end

  # A conferência que o `up` da migração roda antes de criar a constraint. Chamada direto, porque
  # o migrator não convive com o sandbox; a constraint é retirada na transação do teste, e o
  # rollback a devolve.
  test "a migração levanta, com a contagem, quando há estado fora da lista" do
    modulo = TheBand.Repo.Migrations.EstadoDaOrganizacaoValido

    unless Code.ensure_loaded?(modulo),
      do:
        Code.require_file("priv/repo/migrations/20261002120000_estado_da_organizacao_valido.exs")

    assert :ok = modulo.conferir_estados!(Repo)

    # O trigger adiado da 070 (T044a) deixa um evento pendente a cada escrita em `tenants`, e o
    # PostgreSQL recusa `ALTER TABLE` com evento pendente. Conferir agora os esvazia.
    Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")
    Repo.query!("SET CONSTRAINTS ALL DEFERRED")
    Repo.query!("ALTER TABLE tenants DROP CONSTRAINT tenants_status_valido")

    {:ok, _} =
      Tenants.create_tenant(%{
        "name" => "Org3",
        "slug" => "org3-#{System.unique_integer([:positive])}"
      })

    Repo.query!("UPDATE tenants SET status = 'x' WHERE slug LIKE 'org3-%'")

    erro = assert_raise RuntimeError, fn -> modulo.conferir_estados!(Repo) end
    assert erro.message =~ ~r/^1 organização\(ões\) com estado fora/
  end
end
