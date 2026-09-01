defmodule TheBand.Ontology.SEON.EO.TeamMembershipTest do
  @moduledoc """
  Feature 055 — contrato em `specs/055-equipes-declaradas/contracts/equipes-declaradas.md`.

  **A violação vem primeiro, e aqui ela tem forma específica.** O defeito que esta
  feature pode introduzir não é recusar demais: é **apagar**. Um caso feliz que
  provasse "a saída foi registrada" passaria numa implementação que deleta a
  linha — e deletar é justamente a correção fácil, a que ninguém reclama.

  Por isso o primeiro describe mede o que o SC-003 exige: **o mesmo número, antes
  e depois**.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO

  @dia_1 ~U[2026-01-10 00:00:00Z]
  @dia_30 ~U[2026-01-30 00:00:00Z]
  @dia_60 ~U[2026-02-28 00:00:00Z]

  defp cenario do
    tenant = tenant_fixture()
    autor = user_fixture(tenant)
    org = organization_fixture(tenant)
    equipe = team_fixture(tenant, "T1", %{organization: org})

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, source_attrs("P1", %{name: "Ana", login: "ana"}))

    # O papel NÃO é opcional no vínculo, e é decisão do modelo: `eo.team_member`
    # é papel, não tipo — quem é membro desempenha ALGUM papel ali. Um vínculo
    # sem papel diria que a pessoa está na equipe sem dizer como.
    {:ok, papel} =
      EO.create_role(tenant, org.id, %{code: "dev", name: "Desenvolvedora"}, autor.id)

    %{tenant: tenant, autor: autor, equipe: equipe, pessoa: pessoa, papel: papel}
  end

  describe "registrar a saída NÃO apaga o passado (SC-003)" do
    test "o número do período anterior é o mesmo antes e depois da saída" do
      %{tenant: t, autor: a, equipe: e, pessoa: p, papel: papel} = cenario()

      {:ok, _} =
        EO.declare_team_membership(
          t,
          e.id,
          p.id,
          %{started_at: @dia_1, organizational_role_id: papel.id},
          a.id
        )

      antes = EO.count_team_members_at(t, e.id, @dia_30)
      assert antes == 1, "a pessoa deveria contar no dia 30, tendo entrado no dia 1"

      {:ok, _} = EO.record_team_departure(t, e.id, p.id, @dia_60, a.id)

      depois = EO.count_team_members_at(t, e.id, @dia_30)

      assert depois == antes,
             "registrar a saída mudou o passado: #{antes} virou #{depois}. " <>
               "É a diferença entre SAIR e SER APAGADO, e é o SC-003 reprovando."
    end

    test "depois da saída, a pessoa não conta mais no presente" do
      %{tenant: t, autor: a, equipe: e, pessoa: p, papel: papel} = cenario()

      {:ok, _} =
        EO.declare_team_membership(
          t,
          e.id,
          p.id,
          %{started_at: @dia_1, organizational_role_id: papel.id},
          a.id
        )

      {:ok, _} = EO.record_team_departure(t, e.id, p.id, @dia_30, a.id)

      assert EO.count_team_members_at(t, e.id, @dia_60) == 0
    end

    test "a linha continua existindo, com o período fechado" do
      %{tenant: t, autor: a, equipe: e, pessoa: p, papel: papel} = cenario()

      {:ok, _} =
        EO.declare_team_membership(
          t,
          e.id,
          p.id,
          %{started_at: @dia_1, organizational_role_id: papel.id},
          a.id
        )

      {:ok, vinculo} = EO.record_team_departure(t, e.id, p.id, @dia_30, a.id)

      assert vinculo.started_at == DateTime.truncate(@dia_1, :second)
      assert vinculo.ended_at == DateTime.truncate(@dia_30, :second)
      refute is_nil(vinculo.id)
    end
  end

  describe "o equívoco: nunca vigeu (FR-006)" do
    test "o vínculo invalidado não conta em período algum" do
      %{tenant: t, autor: a, equipe: e, pessoa: p, papel: papel} = cenario()

      {:ok, _} =
        EO.declare_team_membership(
          t,
          e.id,
          p.id,
          %{started_at: @dia_1, organizational_role_id: papel.id},
          a.id
        )

      assert EO.count_team_members_at(t, e.id, @dia_30) == 1

      {:ok, _} = EO.record_team_membership_mistake(t, e.id, p.id, "vinculada por engano", a.id)

      assert EO.count_team_members_at(t, e.id, @dia_30) == 0
      assert EO.count_team_members_at(t, e.id, @dia_60) == 0
    end

    test "o registro do equívoco permanece, com autor e razão" do
      %{tenant: t, autor: a, equipe: e, pessoa: p, papel: papel} = cenario()

      {:ok, _} =
        EO.declare_team_membership(
          t,
          e.id,
          p.id,
          %{started_at: @dia_1, organizational_role_id: papel.id},
          a.id
        )

      {:ok, v} = EO.record_team_membership_mistake(t, e.id, p.id, "homônima", a.id)

      refute is_nil(v.invalidated_at)
      assert v.invalidated_by_user_id == a.id
      assert v.invalidation_reason == "homônima"
    end

    test "depois do equívoco, vincular de novo é permitido" do
      # O equívoco tira o vínculo de circulação; ele não pode bloquear a
      # correção. Se bloquear, quem errou fica sem saída.
      %{tenant: t, autor: a, equipe: e, pessoa: p, papel: papel} = cenario()

      {:ok, _} =
        EO.declare_team_membership(
          t,
          e.id,
          p.id,
          %{started_at: @dia_1, organizational_role_id: papel.id},
          a.id
        )

      {:ok, _} = EO.record_team_membership_mistake(t, e.id, p.id, "engano", a.id)

      assert {:ok, _} =
               EO.declare_team_membership(
                 t,
                 e.id,
                 p.id,
                 %{started_at: @dia_30, organizational_role_id: papel.id},
                 a.id
               )
    end
  end

  describe "um vínculo vigente por pessoa e equipe (FR-007)" do
    test "a segunda tentativa vigente é recusada, dizendo desde quando" do
      %{tenant: t, autor: a, equipe: e, pessoa: p, papel: papel} = cenario()

      {:ok, _} =
        EO.declare_team_membership(
          t,
          e.id,
          p.id,
          %{started_at: @dia_1, organizational_role_id: papel.id},
          a.id
        )

      assert {:error, motivo} =
               EO.declare_team_membership(
                 t,
                 e.id,
                 p.id,
                 %{started_at: @dia_30, organizational_role_id: papel.id},
                 a.id
               )

      assert motivo =~ "já"
    end

    test "depois de sair, vincular de novo cria um período novo" do
      %{tenant: t, autor: a, equipe: e, pessoa: p, papel: papel} = cenario()

      {:ok, _} =
        EO.declare_team_membership(
          t,
          e.id,
          p.id,
          %{started_at: @dia_1, organizational_role_id: papel.id},
          a.id
        )

      {:ok, _} = EO.record_team_departure(t, e.id, p.id, @dia_30, a.id)

      {:ok, _} =
        EO.declare_team_membership(
          t,
          e.id,
          p.id,
          %{started_at: @dia_60, organizational_role_id: papel.id},
          a.id
        )

      # Os dois períodos coexistem: dentro do primeiro ela estava, no intervalo
      # não, e dentro do segundo de novo.
      #
      # A DATA DA SAÍDA NÃO CONTA. O período é fechado no início e aberto no
      # fim — `[started_at, ended_at)` —, então no instante exato em que ela
      # saiu ela já não está. É convenção, e precisa ser a mesma em toda
      # consulta: com `>=` no lugar de `>`, alguém que entra numa equipe no dia
      # em que sai de outra contaria nas duas.
      assert EO.count_team_members_at(t, e.id, ~U[2026-01-20 00:00:00Z]) == 1
      assert EO.count_team_members_at(t, e.id, @dia_30) == 0
      assert EO.count_team_members_at(t, e.id, ~U[2026-02-10 00:00:00Z]) == 0
      assert EO.count_team_members_at(t, e.id, ~U[2026-03-10 00:00:00Z]) == 1
    end
  end
end
