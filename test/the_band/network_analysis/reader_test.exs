defmodule TheBand.NetworkAnalysis.ReaderTest do
  @moduledoc """
  A leitura pelo alcance, a cada chamada — feature 076, T017 (FR-002, FR-013, FR-015; A12, A22;
  R18; L38).

  ## As asserções que carregam este arquivo

  1. **A12**: `?network=assignmentx`, `?view=../../`, `?window=36500`, `?window=90;drop` e 10 000
     caracteres voltam ao padrão, **sem criar átomo** (`:erlang.system_info(:atom_count)` antes e
     depois);
  2. organização de outro tenant e id malformado dão o mesmo `{:error, :not_found}`;
  3. **A22**: o alcance perdido some na leitura seguinte — a concessão revogada tira os nomes;
  4. sem leitura, `{:ausente, :not_computed}`; mais velha que a maior janela, `{:ausente,
     :stale}`; nunca a de outra rede no lugar;
  5. pessoa apagada de EO depois do cálculo não aparece por id, nem para a administração (R18);
  6. o número de consultas é o mesmo com 5 e com 50 pessoas.

  **Defeitos a injetar**, um por vez: `String.to_atom/1` no parâmetro; guardar o alcance no
  primeiro `read`; uma consulta de nome por pessoa. Cada um reprova o seu caso.
  """
  use TheBand.DataCase, async: false

  alias TheBand.ContadorDeConsultas
  alias TheBand.NetworkAnalysis
  alias TheBand.NetworkAnalysis.Commands
  alias TheBand.NetworkAnalysis.Parameters
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

  setup do
    {:ok, _} = KnowledgeBase.load()
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    org = organization_fixture(tenant)
    %{tenant: tenant, admin: admin, org: org, parametros: Parameters.fetch!()}
  end

  defp pessoa(tenant, nome) do
    login = "#{String.downcase(nome)}-#{System.unique_integer([:positive])}"

    {:ok, p} =
      EO.upsert_person_from_source(
        tenant,
        source_attrs("U_#{login}", %{name: nome, login: login, account_type: "person"})
      )

    p
  end

  # Uma estrela: a primeira pessoa ligada a todas as outras, nas duas redes.
  defp calcular(ctx, pessoas, agora \\ DateTime.utc_now(:second)) do
    [centro | resto] = Enum.map(pessoas, & &1.id)
    arestas = for p <- resto, do: %{source: centro, target: p, weight: 1}

    entrada = %{
      edges: arestas,
      exclusions: %{},
      people_without_edges: 0,
      source_computed_at: nil,
      provenance: %{}
    }

    {:ok, _, _} =
      Commands.compute(ctx.tenant, ctx.org, agora, ctx.parametros, fn _, _, _ ->
        {:ok, entrada}
      end)
  end

  defp selecao(rede \\ "assignment"), do: %{network: rede, window: 90, view: "weighted"}

  defp nomes_na_visao({:ok, %{graph: {:ok, g}}}),
    do: for(%{kind: :person, name: n} <- g.nodes, do: n)

  defp nomes_na_visao(_), do: []

  test "A12: parâmetros fora da lista voltam ao padrão, sem criar átomo", ctx do
    padrao = NetworkAnalysis.selection(%{})
    assert padrao == %{network: "review", window: 90, view: "weighted"}

    longo = String.duplicate("a", 10_000)

    estranhos = [
      %{"network" => "assignmentx"},
      %{"view" => "../../"},
      %{"window" => "36500"},
      %{"window" => "90;drop"},
      %{"window" => "090"},
      %{"network" => longo},
      %{"network" => nil, "window" => 90}
    ]

    # Aquece: a primeira chamada carrega módulos e pode criar os átomos deles.
    _ = NetworkAnalysis.selection(%{"network" => "aquecimento"})
    antes = :erlang.system_info(:atom_count)

    for params <- estranhos do
      assert NetworkAnalysis.selection(params) == padrao
    end

    for i <- 1..50, do: NetworkAnalysis.selection(%{"network" => "rede#{i}#{ctx.tenant.id}"})

    assert :erlang.system_info(:atom_count) == antes

    assert NetworkAnalysis.selection(%{"network" => "assignment", "window" => "30"}).window == 30
    assert NetworkAnalysis.selection(%{"network" => "assignment"}).network == "assignment"
  end

  test "organização de outro tenant e id malformado dão o mesmo not_found", ctx do
    calcular(ctx, [pessoa(ctx.tenant, "Ana"), pessoa(ctx.tenant, "Bia")])
    assert {:ok, _} = NetworkAnalysis.read(ctx.tenant, ctx.admin, ctx.org.id, selecao())

    outro = tenant_fixture()
    org_de_outro = organization_fixture(outro)

    assert NetworkAnalysis.read(ctx.tenant, ctx.admin, org_de_outro.id, selecao()) ==
             {:error, :not_found}

    assert NetworkAnalysis.read(ctx.tenant, ctx.admin, "nao-e-uuid", selecao()) ==
             {:error, :not_found}

    assert NetworkAnalysis.read(ctx.tenant, ctx.admin, Ecto.UUID.generate(), selecao()) ==
             {:error, :not_found}
  end

  test "A22: a concessão revogada tira os nomes na leitura seguinte", ctx do
    [ana, bia] = [pessoa(ctx.tenant, "Anastacia"), pessoa(ctx.tenant, "Bianca")]
    calcular(ctx, [ana, bia])

    {:ok, membro} =
      Tenants.create_user(ctx.tenant, %{
        "email" => "m-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, concessao} =
      Tenants.grant_scope(ctx.tenant, membro.id, :organization, ctx.org.id, ctx.admin)

    {:ok, equipe} = EO.create_declared_team(ctx.tenant, "Delivery", ctx.admin.id)

    Repo.update_all(
      from(x in "eo_teams",
        where: x.id == type(^equipe.id, :binary_id),
        update: [set: [organization_id: type(^ctx.org.id, :binary_id)]]
      ),
      []
    )

    {:ok, papel} =
      EO.create_role(ctx.tenant, ctx.org.id, %{code: "dev", name: "Dev"}, ctx.admin.id)

    for p <- [ana, bia] do
      {:ok, _} =
        EO.allocate(ctx.tenant, %{
          person_id: p.id,
          team_id: equipe.id,
          organizational_role_id: papel.id,
          started_at: DateTime.add(DateTime.utc_now(:second), -86_400),
          declared_by_user_id: ctx.admin.id
        })
    end

    antes = NetworkAnalysis.read(ctx.tenant, membro, ctx.org.id, selecao())
    assert Enum.sort(nomes_na_visao(antes)) == ["Anastacia", "Bianca"]

    {:ok, _} = Tenants.revoke_scope(ctx.tenant, concessao.id, ctx.admin)

    depois = NetworkAnalysis.read(ctx.tenant, membro, ctx.org.id, selecao())
    assert {:ok, %{reach: :nenhum}} = depois
    assert nomes_na_visao(depois) == []
    refute inspect(depois) =~ "Anastacia"
  end

  test "sem leitura, not_computed; velha, stale; nunca a de outra rede", ctx do
    assert NetworkAnalysis.read(ctx.tenant, ctx.admin, ctx.org.id, selecao()) ==
             {:ausente, :not_computed}

    velho = DateTime.add(DateTime.utc_now(:second), -200 * 86_400)
    calcular(ctx, [pessoa(ctx.tenant, "Ana"), pessoa(ctx.tenant, "Bia")], velho)

    assert NetworkAnalysis.read(ctx.tenant, ctx.admin, ctx.org.id, selecao()) ==
             {:ausente, :stale}
  end

  test "R18: pessoa apagada de EO depois do cálculo não aparece por id", ctx do
    [ana, bia, caio] = for n <- ~w(Ana Bia Caio), do: pessoa(ctx.tenant, n)
    calcular(ctx, [ana, bia, caio])

    {1, _} = Repo.delete_all(from p in "eo_people", where: p.id == type(^caio.id, :binary_id))

    {:ok, visao} = NetworkAnalysis.read(ctx.tenant, ctx.admin, ctx.org.id, selecao())
    {:ok, g} = visao.graph

    assert Enum.sort(for %{kind: :person, id: id} <- g.nodes, do: id) ==
             Enum.sort([ana.id, bia.id])

    refute inspect(visao) =~ caio.id
  end

  test "número de consultas fixo com 5 e com 50 pessoas", ctx do
    contar = fn n ->
      Repo.delete_all(from(r in "network_analysis_readings"))
      calcular(ctx, for(i <- 1..n, do: pessoa(ctx.tenant, "P#{n}x#{i}")))

      ContadorDeConsultas.contar(fn ->
        {:ok, _} = NetworkAnalysis.read(ctx.tenant, ctx.admin, ctx.org.id, selecao())
      end)
    end

    cinco = contar.(5)
    cinquenta = contar.(50)
    assert cinco > 0
    assert cinquenta == cinco
  end
end
