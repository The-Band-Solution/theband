defmodule TheBand.Tenants.TrocarEstadoTest do
  @moduledoc """
  Trocar o estado da organização dentro da transação de quem chama — spec 070, T046a (O10;
  achados D1, D1-c, O5).
  """
  use TheBand.DataCase, async: true

  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant

  defp trocar(tenant, de, para),
    do: Repo.transaction(fn -> Tenants.trocar_estado(tenant, de, para) end)

  defp estado(t), do: Repo.get!(Tenant, t.id).status

  test "active → suspended muda o estado" do
    t = tenant_fixture()
    assert {:ok, {:ok, %Tenant{status: "suspended"}}} = trocar(t, "active", "suspended")
    assert estado(t) == "suspended"
  end

  test "a segunda vez devolve :estado_mudou, e não muda nada" do
    t = tenant_fixture()
    {:ok, {:ok, _}} = trocar(t, "active", "suspended")
    antes = Repo.get!(Tenant, t.id).updated_at

    assert {:ok, {:error, :estado_mudou}} = trocar(t, "active", "suspended")
    assert Repo.get!(Tenant, t.id).updated_at == antes
  end

  test "id inexistente devolve :not_found" do
    fantasma = %Tenant{id: Ecto.UUID.generate()}
    assert {:ok, {:error, :not_found}} = trocar(fantasma, "active", "suspended")
  end

  test "com um passo seguinte que falha, o estado volta: a troca é da transação de quem chama" do
    t = tenant_fixture()

    assert {:error, :falhou} =
             Repo.transaction(fn ->
               {:ok, _} = Tenants.trocar_estado(t, "active", "suspended")
               Repo.rollback(:falhou)
             end)

    assert estado(t) == "active"
  end

  # D1-c: a troca nunca se confirma sozinha. Fora de uma transação, levanta.
  test "fora de uma transação, a troca levanta, e nada muda" do
    t = tenant_fixture()

    assert_raise ArgumentError, ~r/só existe dentro da transação/, fn ->
      Tenants.trocar_estado(t, "active", "suspended")
    end

    assert estado(t) == "active"
  end

  test "um par fora dos dois é defeito de quem chama, e não caso de negócio" do
    t = tenant_fixture()

    assert_raise FunctionClauseError, fn ->
      Repo.transaction(fn -> Tenants.trocar_estado(t, "active", "active") end)
    end
  end

  # O5: o chamador é só `TheBand.Platform.Suspensions`; o "pelo menos um" está em suspender_test.
  test "nenhum chamador fora de TheBand.Platform.Suspensions" do
    {:ok, xref} =
      :xref.start(:"xref_#{System.unique_integer([:positive])}", xref_mode: :functions)

    chamadores =
      try do
        ebin = :the_band |> :code.lib_dir() |> Path.join("ebin") |> to_charlist()
        {:ok, _} = :xref.add_directory(xref, ebin, warnings: false)
        {:ok, mods} = :xref.q(xref, ~c"(Mod) (E || 'Elixir.TheBand.Tenants':trocar_estado/3)")
        mods |> Enum.map(&elem(&1, 0)) |> Enum.reject(&(&1 == TheBand.Tenants))
      after
        :xref.stop(xref)
      end

    assert Enum.reject(chamadores, &(&1 == TheBand.Platform.Suspensions)) == []
  end
end
