defmodule TheBand.NetworkAnalysis.ReadingConstraintsTest do
  @moduledoc """
  As restrições do banco da leitura da análise de rede — feature 076, T009 (`data-model.md` §1).

  ## As asserções que carregam este arquivo

  1. a FK composta recusa a linha com a organização de um tenant e o `tenant_id` de outro;
  2. o índice único recusa a segunda leitura da mesma `(tenant, organização, rede, janela)`, e
     aceita a outra rede na mesma janela (A21 no banco);
  3. `network = 'collab'` é recusado **pelo banco**: o changeset não confere a lista.

  Cada recusa tem o controle positivo ao lado, no próprio tenant. Grava pelo schema, e não pela API
  do módulo, de propósito: o que se prova é o banco, a barreira que vale mesmo quando o código de
  cima erra.

  **Defeito a injetar**: FK simples em `organization_id` na migração; o caso da FK composta
  reprova.
  """
  use TheBand.DataCase, async: true

  alias TheBand.NetworkAnalysis.Schemas.Reading

  defp attrs(tenant, organization, extra \\ %{}) do
    Map.merge(
      %{
        tenant_id: tenant.id,
        organization_id: organization.id,
        network: "assignment",
        window_days: 90,
        window_start: ~U[2026-07-06 12:00:00Z],
        window_end: ~U[2026-10-04 12:00:00Z],
        computed_at: ~U[2026-10-04 12:00:01Z],
        checked_at: ~U[2026-10-04 12:00:01Z],
        fingerprint: "0" |> String.duplicate(64),
        edges: [],
        exclusions: %{},
        people_without_edges: nil,
        nodes: [],
        communities: [],
        measures: %{},
        provenance: %{}
      },
      extra
    )
  end

  defp gravar(attrs), do: %Reading{} |> Reading.changeset(attrs) |> Repo.insert()

  test "a organização de um tenant com o tenant_id de outro é recusada pelo banco" do
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    org_de_t1 = organization_fixture(t1)

    assert {:ok, _} = gravar(attrs(t1, org_de_t1))

    assert {:error, changeset} = gravar(attrs(t2, org_de_t1, %{window_days: 30}))
    assert %{organization_id: [_]} = errors_on(changeset)
  end

  test "uma só leitura vigente por tenant, organização, rede e janela" do
    tenant = tenant_fixture()
    org = organization_fixture(tenant)

    assert {:ok, _} = gravar(attrs(tenant, org))
    # A outra rede na mesma janela convive: é o que impede a designação de apagar a revisão.
    assert {:ok, _} = gravar(attrs(tenant, org, %{network: "review"}))

    assert {:error, changeset} = gravar(attrs(tenant, org))
    assert %{tenant_id: [_]} = errors_on(changeset)
  end

  test "rede fora da lista é recusada pelo banco" do
    tenant = tenant_fixture()
    org = organization_fixture(tenant)

    assert {:ok, _} = gravar(attrs(tenant, org, %{network: "review"}))

    assert {:error, changeset} = gravar(attrs(tenant, org, %{network: "collab"}))
    assert %{network: [_]} = errors_on(changeset)
  end

  test "checked_at antes de computed_at, e contagem negativa, são recusados" do
    tenant = tenant_fixture()
    org = organization_fixture(tenant)

    assert {:error, cs} = gravar(attrs(tenant, org, %{checked_at: ~U[2026-10-04 12:00:00Z]}))
    assert %{checked_at: [_]} = errors_on(cs)

    assert {:error, cs} = gravar(attrs(tenant, org, %{people_without_edges: -1}))
    assert %{people_without_edges: [_]} = errors_on(cs)
  end
end
