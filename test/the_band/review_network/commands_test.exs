defmodule TheBand.ReviewNetwork.CommandsTest do
  @moduledoc """
  O cálculo e a substituição das leituras — feature 073, T014 (FR-010 a FR-012; R3, R7).

  ## As asserções que carregam este arquivo

  1. **A12**: calcular duas vezes deixa **uma** linha por janela, com ids novos, e nenhum nome nem
     login no JSON;
  2. o invariante: pares da janela = revisões na rede + as três exclusões, contado à parte;
  3. **SC-005**: o mesmo `now` dez vezes dá dez leituras iguais, exceto `id` e `inserted_at`;
  4. nada de outro tenant nem de outra organização entra (A1, A3 no cálculo);
  5. as janelas são aninhadas: o par de 100 dias atrás está em 180 e não em 90.
  """
  use TheBand.DataCase, async: true

  import TheBand.ReviewNetworkFixtures

  alias TheBand.ReviewNetwork.Commands
  alias TheBand.ReviewNetwork.Schemas.Reading

  @agora ~U[2026-10-03 12:00:00Z]

  defp dias_atras(n), do: DateTime.add(@agora, -n * 86_400, :second)

  defp cenario(tenant) do
    org = organizacao_com_repositorio(tenant)
    ana = pessoa(tenant, "Ana")
    bia = pessoa(tenant, "Bia")
    caio = pessoa(tenant, "Caio")
    robo = pessoa(tenant, "Robo", "bot")
    repo = org.observed_repository_id

    cr1 = solicitacao(tenant, repo, bia, dias_atras(20))
    cr2 = solicitacao(tenant, repo, bia, dias_atras(100))
    cr3 = solicitacao(tenant, repo, ana, dias_atras(10))
    _cr_caio = solicitacao(tenant, repo, caio, dias_atras(5))

    revisao(tenant, cr1, ana, dias_atras(19))
    revisao(tenant, cr1, ana, dias_atras(18), %{state: "COMMENTED"})
    revisao(tenant, cr2, ana, dias_atras(99))
    revisao(tenant, cr3, ana, dias_atras(9))
    revisao(tenant, cr3, robo, dias_atras(9))
    revisao(tenant, cr1, {:login, "prestador", "User"}, dias_atras(18))
    revisao(tenant, cr1, nil, dias_atras(18))
    revisao(tenant, cr3, bia, dias_atras(8))

    %{org: org, ana: ana, bia: bia, caio: caio}
  end

  defp leituras(tenant, org) do
    Repo.all(
      from r in Reading,
        where: r.tenant_id == ^tenant.id and r.organization_id == ^org.id,
        order_by: r.window_days
    )
  end

  test "A12: duas vezes deixa uma linha por janela, com ids novos, e nenhum nome no JSON" do
    tenant = tenant_fixture()
    c = cenario(tenant)

    {:ok, primeiro} = Commands.compute(tenant, c.org.organization, @agora, parametros())
    ids1 = Enum.map(leituras(tenant, c.org.organization), & &1.id)
    assert length(ids1) == 3

    {:ok, _} = Commands.compute(tenant, c.org.organization, @agora, parametros())
    linhas = leituras(tenant, c.org.organization)

    assert Enum.map(linhas, & &1.window_days) == [30, 90, 180]
    assert MapSet.disjoint?(MapSet.new(ids1), MapSet.new(Enum.map(linhas, & &1.id)))
    assert Enum.map(primeiro.readings, & &1.window_days) == [30, 90, 180]

    json = inspect(Enum.map(linhas, &{&1.edges, &1.people}))
    assert json =~ c.ana.id
    refute json =~ "Ana"
    refute json =~ c.ana.login
    refute json =~ "prestador"
  end

  test "o invariante e as exclusões por motivo, contados à parte" do
    tenant = tenant_fixture()
    c = cenario(tenant)

    {:ok, %{readings: rs}} = Commands.compute(tenant, c.org.organization, @agora, parametros())
    j90 = Enum.find(rs, &(&1.window_days == 90))

    # Na janela de 90 dias, à mão: pares (conta, solicitação) enviados nela —
    #   ana×cr1, ana×cr3, robo×cr3, prestador×cr1, apagada×cr1, bia×cr3 = 6.
    #   ana→bia (cr1) e bia→ana (cr3) e ana×cr3 é auto-revisão: 2 na rede.
    assert j90.reviews == 2
    assert j90.excluded == %{self_reviews: 1, bot_or_app: 1, unlinked: 2}
    assert j90.reviews + 1 + 1 + 2 == 6

    # A de 180 dias pega também ana×cr2, de 99 dias atrás.
    assert Enum.find(rs, &(&1.window_days == 180)).reviews == 3
    # A de 30 é a mesma de 90 aqui: nada entre 30 e 90 dias.
    assert Enum.find(rs, &(&1.window_days == 30)).reviews == 2
  end

  test "Caio abriu e ninguém revisou: está na lista, com recebidas nulas, e não 0" do
    tenant = tenant_fixture()
    c = cenario(tenant)

    {:ok, _} = Commands.compute(tenant, c.org.organization, @agora, parametros())
    j90 = Enum.find(leituras(tenant, c.org.organization), &(&1.window_days == 90))

    assert %{"id" => _, "received_change_requests" => nil} =
             Enum.find(j90.people, &(&1["id"] == c.caio.id))

    assert %{"received_change_requests" => 1} = Enum.find(j90.people, &(&1["id"] == c.bia.id))
  end

  test "SC-005: o mesmo now dez vezes dá a mesma leitura, exceto id e inserted_at" do
    tenant = tenant_fixture()
    c = cenario(tenant)

    leituras_sem_id =
      for _ <- 1..10 do
        {:ok, _} = Commands.compute(tenant, c.org.organization, @agora, parametros())

        leituras(tenant, c.org.organization)
        |> Enum.map(&Map.drop(Map.from_struct(&1), [:id, :inserted_at, :__meta__]))
      end

    assert leituras_sem_id |> Enum.uniq() |> length() == 1
  end

  test "nada de outro tenant nem de outra organização entra" do
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    c1 = cenario(t1)
    c2 = cenario(t2)
    outra_org = cenario(t1)

    {:ok, _} = Commands.compute(t1, c1.org.organization, @agora, parametros())
    texto = inspect(Enum.map(leituras(t1, c1.org.organization), &{&1.edges, &1.people}))

    assert texto =~ c1.ana.id
    refute texto =~ c2.ana.id
    refute texto =~ outra_org.ana.id
    assert leituras(t2, c2.org.organization) == []
  end
end
