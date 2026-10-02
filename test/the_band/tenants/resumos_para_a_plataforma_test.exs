defmodule TheBand.Tenants.ResumosParaAPlataformaTest do
  @moduledoc """
  As leituras de `tenants` para a área do operador — spec 070, T038a (FR-007; achados D1 e D1-b).
  """
  use TheBand.DataCase, async: true

  alias TheBand.Tenants

  @chaves [:id, :name, :slug, :status]

  setup do
    %{a: tenant_fixture(), b: tenant_fixture()}
  end

  test "cada resumo tem exatamente id, name, slug e status, e as duas organizações estão lá",
       %{a: a, b: b} do
    resumos = Tenants.resumos_para_a_plataforma()

    for t <- [a, b] do
      resumo = Enum.find(resumos, &(&1.id == t.id))
      assert resumo == %{id: t.id, name: t.name, slug: t.slug, status: t.status}
    end

    assert Enum.all?(resumos, &(&1 |> Map.keys() |> Enum.sort() == @chaves))
    assert Enum.map(resumos, & &1.name) == Enum.sort(Enum.map(resumos, & &1.name))
  end

  test "pelo slug: o mesmo resumo, e :not_found para o que não existe", %{a: a} do
    assert {:ok, %{id: id} = resumo} = Tenants.resumo_para_a_plataforma(a.slug)
    assert id == a.id and resumo |> Map.keys() |> Enum.sort() == @chaves

    assert Tenants.resumo_para_a_plataforma("nao-existe-#{System.unique_integer()}") ==
             {:error, :not_found}
  end

  test "o SQL das duas cita, de tenants, só as quatro colunas, sem junção", %{a: a} do
    consultas =
      capturar(fn ->
        Tenants.resumos_para_a_plataforma()
        Tenants.resumo_para_a_plataforma(a.slug)
      end)

    assert length(consultas) == 2, "a captura não mediu as duas consultas"

    for sql <- consultas do
      [colunas] = Regex.run(~r/^SELECT (.*?) FROM "tenants"/, sql, capture: :all_but_first)

      assert colunas |> String.split(", ") |> Enum.sort() ==
               ~w(t0."id" t0."name" t0."slug" t0."status")

      refute sql =~ "JOIN"
      refute sql =~ "count("
    end
  end

  # D1-b: a leitura não recebe tenant, porque é o escopo da plataforma. Pelo `:xref` do Erlang sobre
  # os `.beam` compilados: `mix xref callers` só aceita módulo, e o `:xref` vê a chamada de verdade,
  # inclusive por alias, e não lê comentário.
  test "nenhum chamador das duas fora de TheBand.Platform em lib/" do
    chamadores =
      for f <- [{:resumos_para_a_plataforma, 0}, {:resumo_para_a_plataforma, 1}],
          modulo <- chamadores(TheBand.Tenants, f),
          uniq: true,
          do: modulo

    assert TheBand.Platform.Suspensions in chamadores,
           "o xref não achou o chamador que existe: a medição não mediu"

    fora =
      Enum.reject(chamadores, &(&1 |> Module.split() |> Enum.take(2) == ["TheBand", "Platform"]))

    assert fora == []
  end

  defp chamadores(modulo, {funcao, aridade}) do
    {:ok, xref} =
      :xref.start(:"xref_#{System.unique_integer([:positive])}", xref_mode: :functions)

    try do
      ebin = :the_band |> :code.lib_dir() |> Path.join("ebin") |> to_charlist()
      {:ok, _} = :xref.add_directory(xref, ebin, warnings: false)
      consulta = ~c"(Mod) (E || '#{:erlang.atom_to_list(modulo)}':#{funcao}/#{aridade})"
      {:ok, mods} = :xref.q(xref, consulta)
      mods |> Enum.map(&elem(&1, 0)) |> Enum.reject(&(&1 == modulo))
    after
      :xref.stop(xref)
    end
  end

  defp capturar(fun) do
    ref = make_ref()
    eu = self()
    id = {__MODULE__, ref}

    :telemetry.attach(
      id,
      [:the_band, :repo, :query],
      fn _e, _m, %{query: sql}, _ ->
        if self() == eu and sql =~ ~s(FROM "tenants"), do: send(eu, {ref, sql})
      end,
      nil
    )

    fun.()
    :telemetry.detach(id)
    coletar(ref, [])
  end

  defp coletar(ref, acc) do
    receive do
      {^ref, sql} -> coletar(ref, [sql | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
