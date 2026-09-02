defmodule TheBand.Ontology.SEON.EO.TeamCompositionTest do
  @moduledoc """
  Feature 055, US3 — equipe dentro de equipe.

  **O ciclo de comprimento 3 vem antes do de comprimento 2, e é de propósito.**
  O caso do vizinho direto — `A⊂B` e depois `B⊂A` — passa em implementação
  ingênua, que só olha se o par inverso existe. Só o caminho longo prova que a
  detecção percorre o grafo.

  Ciclo não é preciosismo: com ele, qualquer agregação pela hierarquia — a soma
  de competências que a #397 pede — **não termina**.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO

  defp cenario do
    tenant = tenant_fixture()
    autor = user_fixture(tenant)
    org = organization_fixture(tenant)

    equipes =
      for nome <- ~w(A B C D) do
        {:ok, e} = EO.declare_structural_team(tenant, org.id, "Equipe #{nome}", autor.id)
        {nome, e}
      end
      |> Map.new()

    %{tenant: tenant, autor: autor, org: org, e: equipes}
  end

  describe "o ciclo é recusado (FR-009)" do
    test "comprimento 3: A⊂B, B⊂C, e C⊂A é recusado" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      {:ok, _} = EO.compose_teams(t, e["B"].id, e["C"].id, a.id)

      assert {:error, motivo} = EO.compose_teams(t, e["C"].id, e["A"].id, a.id)

      # A recusa NOMEIA o caminho. "Fecharia ciclo" manda a pessoa procurar;
      # dizer por onde resolve.
      assert motivo =~ "Equipe A"
      assert motivo =~ "Equipe B"
    end

    test "comprimento 4, para o caso longo não passar por acaso" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      {:ok, _} = EO.compose_teams(t, e["B"].id, e["C"].id, a.id)
      {:ok, _} = EO.compose_teams(t, e["C"].id, e["D"].id, a.id)

      assert {:error, _} = EO.compose_teams(t, e["D"].id, e["A"].id, a.id)
    end

    test "comprimento 2: A⊂B e B⊂A" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert {:error, _} = EO.compose_teams(t, e["B"].id, e["A"].id, a.id)
    end

    test "a equipe dentro de si mesma" do
      %{tenant: t, autor: a, e: e} = cenario()

      assert {:error, _} = EO.compose_teams(t, e["A"].id, e["A"].id, a.id)
    end
  end

  describe "compor e descompor (FR-008)" do
    test "a composição vale, com autor e início" do
      %{tenant: t, autor: a, e: e} = cenario()

      assert {:ok, c} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)

      assert c.part_team_id == e["A"].id
      assert c.whole_team_id == e["B"].id
      assert c.declared_by_user_id == a.id
      assert is_nil(c.ended_at)
    end

    test "a mesma composição duas vezes é recusada" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert {:error, motivo} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert motivo =~ "já"
    end

    test "descompor mantém a equipe, e o histórico" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert {:ok, c} = EO.decompose_teams(t, e["A"].id, e["B"].id, a.id)

      refute is_nil(c.ended_at)
      assert c.ended_by_user_id == a.id
      # A equipe continua existindo — a composição terminou, ela não.
      assert EO.count_teams(t) == 4
    end

    test "depois de descompor, compor de novo é permitido" do
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      {:ok, _} = EO.decompose_teams(t, e["A"].id, e["B"].id, a.id)

      assert {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
    end

    test "uma equipe pode compor DUAS mães ao mesmo tempo" do
      # A cardinalidade é muitos-para-muitos de propósito: a estrutura real não é
      # árvore, e a mesma célula pode compor duas frentes.
      %{tenant: t, autor: a, e: e} = cenario()

      {:ok, _} = EO.compose_teams(t, e["A"].id, e["B"].id, a.id)
      assert {:ok, _} = EO.compose_teams(t, e["A"].id, e["C"].id, a.id)
    end
  end
end
