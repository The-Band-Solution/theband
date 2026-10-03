defmodule TheBand.ReviewNetwork.ReadingConstraintsTest do
  @moduledoc """
  As restrições do banco da leitura vigente — feature 073, T005 (R7 da segurança).

  1. a FK composta recusa a linha com a organização de um tenant e o `tenant_id` de outro;
  2. o índice único recusa a segunda leitura da mesma `(tenant, organização, janela)`.

  O teste grava pelo schema, e não pela API do módulo, de propósito: o que se prova aqui é o
  **banco**, a barreira que vale mesmo quando o código de cima erra.
  """
  use TheBand.DataCase, async: true

  alias TheBand.ReviewNetwork.Schemas.Reading

  defp attrs(tenant, organization, extra \\ %{}) do
    Map.merge(
      %{
        tenant_id: tenant.id,
        organization_id: organization.id,
        window_days: 90,
        window_start: ~U[2026-07-05 12:00:00Z],
        window_end: ~U[2026-10-03 12:00:00Z],
        computed_at: ~U[2026-10-03 12:00:01Z],
        edges: [],
        people: [],
        reviews_in_network: 0,
        excluded_self_reviews: 0,
        excluded_bot_or_app: 0,
        excluded_unlinked: 0,
        knowledge_versions: %{}
      },
      extra
    )
  end

  defp gravar(attrs), do: %Reading{} |> Reading.changeset(attrs) |> Repo.insert()

  test "a organização de um tenant com o tenant_id de outro é recusada pelo banco" do
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    org_de_t1 = organization_fixture(t1)

    # Controle: no próprio tenant, grava.
    assert {:ok, _} = gravar(attrs(t1, org_de_t1))

    assert {:error, changeset} = gravar(attrs(t2, org_de_t1))
    assert %{organization_id: [_]} = errors_on(changeset)
  end

  test "uma só leitura vigente por tenant, organização e janela" do
    tenant = tenant_fixture()
    org = organization_fixture(tenant)

    assert {:ok, _} = gravar(attrs(tenant, org))
    assert {:ok, _} = gravar(attrs(tenant, org, %{window_days: 30}))

    assert {:error, changeset} = gravar(attrs(tenant, org))
    assert %{tenant_id: [_]} = errors_on(changeset)
  end

  test "a janela que termina antes de começar é recusada pelo banco" do
    tenant = tenant_fixture()
    org = organization_fixture(tenant)

    assert {:error, changeset} =
             gravar(attrs(tenant, org, %{window_end: ~U[2026-07-01 00:00:00Z]}))

    assert %{window_end: [_]} = errors_on(changeset)
  end
end
