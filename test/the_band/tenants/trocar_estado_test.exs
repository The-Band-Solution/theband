defmodule TheBand.Tenants.TrocarEstadoTest do
  @moduledoc """
  Trocar o estado da organização dentro de um `Multi` — spec 070, T046a (O10; achados D1, D1-c, O5).
  """
  use TheBand.DataCase, async: true

  alias Ecto.Multi
  alias TheBand.Tenants
  alias TheBand.Tenants.Tenant

  defp trocar(tenant, de, para, multi \\ Multi.new()),
    do: multi |> Tenants.trocar_estado_no_multi(:estado, tenant, de, para) |> Repo.transaction()

  defp estado(t), do: Repo.get!(Tenant, t.id).status

  test "active → suspended muda o estado" do
    t = tenant_fixture()
    assert {:ok, %{estado: %Tenant{status: "suspended"}}} = trocar(t, "active", "suspended")
    assert estado(t) == "suspended"
  end

  test "a segunda vez devolve :estado_mudou, e não muda nada" do
    t = tenant_fixture()
    {:ok, _} = trocar(t, "active", "suspended")
    antes = Repo.get!(Tenant, t.id).updated_at

    assert {:error, :estado, :estado_mudou, _} = trocar(t, "active", "suspended")
    assert Repo.get!(Tenant, t.id).updated_at == antes
  end

  test "id inexistente devolve :not_found" do
    fantasma = %Tenant{id: Ecto.UUID.generate()}
    assert {:error, :estado, :not_found, _} = trocar(fantasma, "active", "suspended")
  end

  test "com um passo seguinte que falha, o estado volta: a troca é da transação de quem chama" do
    t = tenant_fixture()

    multi =
      Multi.new()
      |> Tenants.trocar_estado_no_multi(:estado, t, "active", "suspended")
      |> Multi.run(:seguinte, fn _, _ -> {:error, :falhou} end)

    assert {:error, :seguinte, :falhou, _} = Repo.transaction(multi)
    assert estado(t) == "active"
  end

  test "um par fora dos dois é defeito de quem chama, e não caso de negócio" do
    t = tenant_fixture()

    assert_raise FunctionClauseError, fn ->
      Tenants.trocar_estado_no_multi(Multi.new(), :estado, t, "active", "active")
    end
  end

  # O5: quando esta tarefa fecha, `Suspensions` ainda não a chama. Afirma-se que nenhum chamador
  # fora de `TheBand.Platform.Suspensions` existe em `lib/`; o "pelo menos um" é de T049.
  test "nenhum chamador fora de TheBand.Platform.Suspensions" do
    {:ok, xref} =
      :xref.start(:"xref_#{System.unique_integer([:positive])}", xref_mode: :functions)

    chamadores =
      try do
        ebin = :the_band |> :code.lib_dir() |> Path.join("ebin") |> to_charlist()
        {:ok, _} = :xref.add_directory(xref, ebin, warnings: false)

        {:ok, mods} =
          :xref.q(xref, ~c"(Mod) (E || 'Elixir.TheBand.Tenants':trocar_estado_no_multi/5)")

        mods |> Enum.map(&elem(&1, 0)) |> Enum.reject(&(&1 == TheBand.Tenants))
      after
        :xref.stop(xref)
      end

    assert Enum.reject(chamadores, &(&1 == TheBand.Platform.Suspensions)) == []
  end
end
