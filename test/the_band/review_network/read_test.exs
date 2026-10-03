defmodule TheBand.ReviewNetwork.ReadTest do
  @moduledoc """
  A leitura recortada pelo alcance recalculado a cada chamada — feature 073, T016 e T023
  (`contracts/review-network.md`, `read/4`; R3, R10 da segurança).

  ## As asserções que carregam este arquivo (violação primeiro)

  1. **A8**: janela fora da lista é recusada no domínio, e nenhum átomo nasce;
  2. **A3**: organização de outro tenant e inexistente dão o mesmo `{:error, :not_found}`;
  3. **A13**: a conta que perde o vínculo deixa de ver os colegas na leitura seguinte;
  4. **A4 no domínio**: a conta de alcance parcial não recebe o nome de quem não alcança;
  5. a lista sai em ordem de nome, e por nada mais (FR-018a);
  6. **L38**: o número de consultas não cresce com a rede;
  7. **Q3**: a coleta de mudanças mais nova que a leitura é dita, e a de outra organização não.

  `async: false` porque o contador de consultas é global.
  """
  use TheBand.DataCase, async: false

  import TheBand.ReviewNetworkFixtures

  alias TheBand.ContadorDeConsultas
  alias TheBand.Ontology.SEON.EO
  alias TheBand.ReviewNetwork.Commands
  alias TheBand.ReviewNetwork.Reader
  alias TheBand.Tenants

  @agora ~U[2026-10-03 12:00:00Z]

  defp dias_atras(n), do: DateTime.add(@agora, -n * 86_400, :second)

  defp revisar(tenant, repo, revisor, autor, vezes) do
    for i <- 1..vezes do
      cr = solicitacao(tenant, repo, autor, dias_atras(20 + i))
      revisao(tenant, cr, revisor, dias_atras(19 + i))
    end
  end

  # Ana (de fora) revisa 6 de Bia; Ciro revisa 3 de Bia; Bia revisa 2 de Ciro.
  # Lia é a conta comum, colega de Bia e Ciro na equipe X.
  setup do
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    org = organizacao_com_repositorio(tenant)
    repo = org.observed_repository_id

    # A ordem dos nomes não é nem a crescente nem a decrescente das medidas: ordenar por medida,
    # em qualquer sentido, troca a lista.
    ana = pessoa(tenant, "Zuleica Ana")
    bia = pessoa(tenant, "Bia")
    ciro = pessoa(tenant, "Abel Ciro")
    lia = pessoa(tenant, "Lia")

    revisar(tenant, repo, ana, bia, 6)
    revisar(tenant, repo, ciro, bia, 3)
    revisar(tenant, repo, bia, ciro, 2)
    {:ok, _} = Commands.compute(tenant, org.organization, @agora, parametros())

    {:ok, equipe} = EO.create_declared_team(tenant, "X", admin.id)

    {:ok, papel} =
      EO.create_role(tenant, org.organization.id, %{code: "dev", name: "Dev"}, admin.id)

    for p <- [lia, bia, ciro] do
      {:ok, _} =
        EO.declare_team_membership(
          tenant,
          equipe.id,
          p.id,
          %{organizational_role_id: papel.id},
          admin.id
        )
    end

    {:ok, conta} =
      Tenants.create_user(tenant, %{
        "email" => "lia-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, conta} = Tenants.declare_person(tenant, conta.id, lia.id, admin.id)

    %{
      tenant: tenant,
      admin: admin,
      conta: conta,
      org: org,
      equipe: equipe,
      ana: ana,
      bia: bia,
      ciro: ciro,
      lia: lia
    }
  end

  defp ler(ctx, user, janela \\ 90, org_id \\ nil),
    do: Reader.read(ctx.tenant, user, org_id || ctx.org.organization.id, janela, parametros())

  describe "A8 — a janela" do
    test "fora da lista é recusada no domínio, e nenhum átomo nasce", ctx do
      assert {:ok, %{window_days: 90}} = ler(ctx, ctx.admin, 90)
      assert {:ok, %{window_days: 30}} = ler(ctx, ctx.admin, "30")

      atomos = :erlang.system_info(:atom_count)

      for janela <- ["36500", "-1", "90; drop", "abc", nil, "090", " 90", 36_500, 0, 90.0] do
        assert ler(ctx, ctx.admin, janela) == {:error, :janela_invalida}, inspect(janela)
      end

      assert :erlang.system_info(:atom_count) == atomos
    end
  end

  describe "A3 — a organização" do
    test "de outro tenant e inexistente dão o mesmo não encontrado", ctx do
      outro = tenant_fixture()
      org_de_fora = organizacao_com_repositorio(outro)

      assert {:ok, _} = ler(ctx, ctx.admin)

      de_outro_tenant = ler(ctx, ctx.admin, 90, org_de_fora.organization.id)
      inexistente = ler(ctx, ctx.admin, 90, Ecto.UUID.generate())

      assert de_outro_tenant == {:error, :not_found}
      assert inexistente == de_outro_tenant
    end

    test "organização sem leitura é :nao_calculada, e nunca a de outra janela", ctx do
      sem = organizacao_com_repositorio(ctx.tenant)
      assert ler(ctx, ctx.admin, 90, sem.organization.id) == {:ausente, :nao_calculada}
    end
  end

  describe "o alcance" do
    test "quem administra lê a rede inteira, sem nome na concentração", ctx do
      {:ok, v} = ler(ctx, ctx.admin)

      assert v.reach == :total
      assert v.reviews == 11
      assert {:ok, [%{k: 1, value: {:ok, %{reviews: 6, of: 11}}} | _]} = v.concentration
      assert Enum.map(v.people, & &1.name) == ["Abel Ciro", "Bia", "Zuleica Ana"]
    end

    test "A4 no domínio: a conta de alcance parcial não recebe o nome de quem não alcança", ctx do
      {:ok, v} = ler(ctx, ctx.conta)

      assert v.reach == :parcial
      assert Enum.map(v.people, & &1.name) == ["Abel Ciro", "Bia"]
      # Só Ciro→Bia (3) e Bia→Ciro (2): abaixo da amostra mínima.
      assert v.reviews == 5
      assert v.concentration == {:ausente, {:abaixo_da_amostra_minima, 10}}
      assert v.exclusions == {:recortado, :regra}

      bia = Enum.find(v.people, &(&1.name == "Bia"))
      # O total dela é o verdadeiro: 9 solicitações revisadas, por 2 pessoas.
      assert bia.received == {:ok, %{change_requests: 9, people: 2}}
      assert bia.pairs_outside_reach? == true

      refute inspect(v) =~ "Zuleica"
      refute inspect(v) =~ ctx.ana.id
    end

    test "A13: quem perde o vínculo deixa de ver os colegas na leitura seguinte", ctx do
      {:ok, antes} = ler(ctx, ctx.conta)
      assert Enum.any?(antes.people, &(&1.name == "Bia"))

      {:ok, _} =
        EO.record_team_departure(
          ctx.tenant,
          ctx.equipe.id,
          ctx.lia.id,
          DateTime.add(DateTime.utc_now(:second), -60, :second),
          ctx.admin.id
        )

      {:ok, depois} = ler(ctx, ctx.conta, "90")
      assert depois.people == []
      refute inspect(depois) =~ "Bia"
    end
  end

  test "a lista sai em ordem de nome, e não na de nenhuma medida", ctx do
    {:ok, v} = ler(ctx, ctx.admin)

    feitas =
      Enum.map(v.people, fn
        %{given: {:ok, %{reviews: n}}} -> n
        _ -> 0
      end)

    assert Enum.map(v.people, & &1.name) == ["Abel Ciro", "Bia", "Zuleica Ana"]
    assert feitas == [3, 2, 6]
  end

  test "L38: o número de consultas não cresce com a rede", ctx do
    leitura = fn -> {:ok, _} = ler(ctx, ctx.admin) end
    com_poucas = ContadorDeConsultas.contar(leitura)

    repo = ctx.org.observed_repository_id

    for i <- 1..45 do
      revisar(ctx.tenant, repo, pessoa(ctx.tenant, "R#{i}"), pessoa(ctx.tenant, "A#{i}"), 1)
    end

    {:ok, _} = Commands.compute(ctx.tenant, ctx.org.organization, @agora, parametros())
    {:ok, v} = leitura.()
    assert length(v.people) > 50

    assert ContadorDeConsultas.contar(leitura) == com_poucas
  end

  describe "Q3 — a coleta mais nova que a leitura" do
    test "o corte posterior ao cálculo é dito; o anterior e o de outra organização, não", ctx do
      assert {:ok, %{newer_collection: :nenhuma}} = ler(ctx, ctx.admin)

      outra = organizacao_com_repositorio(ctx.tenant)
      marcar_coleta(outra.observed_repository_id, DateTime.add(@agora, 3600, :second))
      assert {:ok, %{newer_collection: :nenhuma}} = ler(ctx, ctx.admin)

      marcar_coleta(ctx.org.observed_repository_id, DateTime.add(@agora, -3600, :second))
      assert {:ok, %{newer_collection: :nenhuma}} = ler(ctx, ctx.admin)

      depois = DateTime.add(@agora, 3600, :second)
      marcar_coleta(ctx.org.observed_repository_id, depois)
      assert {:ok, %{newer_collection: {:em, ^depois}}} = ler(ctx, ctx.admin)
    end
  end

  # A coleta grava `changes_collected_at` ao fim da passada; o teste escreve direto, porque o que
  # se prova é a leitura do registro, e não a coleta.
  defp marcar_coleta(observed_repository_id, quando) do
    Repo.update_all(
      from(r in "observed_repositories",
        where: r.id == type(^observed_repository_id, :binary_id)
      ),
      set: [changes_collected_at: quando]
    )
  end
end
