defmodule TheBand.Ontology.SEON.EO.SaidaDeclaradaTest do
  @moduledoc """
  A saída declarada — feature 060, T014: FR-019, FR-021, FR-022, FR-023, FR-026 e FR-027.

  Quatro afirmações que a versão anterior de `record_team_departure/5` não sustentava:

  1. **alcança o par, não um papel.** FR-018 permite dois papéis vigentes ao mesmo tempo, e a
     versão anterior usava `Repo.one` — que **levantaria** diante deles em vez de encerrar os
     dois. O teste com dois papéis é o que prova a diferença;
  2. **grava quem e quando.** O `actor_id` chegava e era descartado, e sem ele fim declarado e
     fim constatado pela coleta ficam indistinguíveis (FR-022);
  3. **a coleta não desfaz a saída** enquanto a origem continuar mostrando a pessoa (FR-026).
     A guarda da coleta só reconhecia papel, autor de declaração e equívoco — nunca o autor da
     saída —, então numa saída sobre vínculo **observado** a coleta seguinte criava outro
     vínculo, e quem declarou via a pessoa voltar sozinha à equipe;
  4. **retorno é vínculo novo** (FR-027). Sem esta exceção a guarda de (3) seria permanente, e
     quem saísse e voltasse nunca mais teria vínculo observado.
  """
  use TheBand.DataCase, async: true

  import Ecto.Query

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Repo

  @dia_1 ~U[2026-01-01 00:00:00Z]
  @dia_30 ~U[2026-01-30 00:00:00Z]
  @dia_60 ~U[2026-03-01 00:00:00Z]

  setup do
    tenant = tenant_fixture()
    autor = user_fixture(tenant)
    org = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_plataforma", %{organization: org, name: "PLATAFORMA"})

    {:ok, ana} =
      EO.upsert_person_from_source(tenant, source_attrs("U_ana", %{name: "Ana", login: "ana"}))

    {:ok, dev} = EO.create_role(tenant, org.id, %{code: "dev", name: "Desenvolvedora"}, autor.id)

    {:ok, sm} = EO.create_role(tenant, org.id, %{code: "sm", name: "Scrum Master"}, autor.id)

    %{tenant: tenant, autor: autor, org: org, equipe: equipe, ana: ana, dev: dev, sm: sm}
  end

  defp declarar(ctx, papel, desde \\ @dia_1) do
    {:ok, vinculo} =
      EO.allocate(ctx.tenant, %{
        person_id: ctx.ana.id,
        team_id: ctx.equipe.id,
        organizational_role_id: papel.id,
        declared_by_user_id: ctx.autor.id,
        started_at: desde
      })

    vinculo
  end

  defp vinculos(ctx) do
    Repo.all(
      from m in TeamMembership,
        where: m.tenant_id == ^ctx.tenant.id and m.team_id == ^ctx.equipe.id,
        order_by: m.inserted_at
    )
  end

  defp observar(ctx, quando) do
    EO.record_team_membership_evidence(ctx.tenant, %{
      person_id: ctx.ana.id,
      team_id: ctx.equipe.id,
      person_external_id: ctx.ana.external_id,
      team_external_id: ctx.equipe.external_id,
      platform_access_level: "MEMBER",
      source_system: "github",
      source_instance: "https://github.com",
      observed_at: quando
    })
  end

  describe "a saída alcança TODOS os vínculos vigentes do par (FR-018, FR-019)" do
    test "quem tem dois papéis vigentes sai numa chamada, e os dois ficam encerrados", ctx do
      declarar(ctx, ctx.dev)
      declarar(ctx, ctx.sm)

      assert length(vinculos(ctx)) == 2, "o índice parcial permite dois papéis vigentes"

      # É AQUI que a versão anterior levantava: `vigente/3` usa `Repo.one`, e com dois
      # vigentes o resultado não era uma recusa — era a tela caindo.
      assert {:ok, 2} =
               EO.record_team_departure(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 @dia_30,
                 ctx.autor.id
               )

      for vinculo <- vinculos(ctx) do
        assert vinculo.ended_at == @dia_30,
               "o papel #{vinculo.organizational_role_id} ficou aberto"

        assert vinculo.ended_by_user_id == ctx.autor.id
        refute is_nil(vinculo.end_declared_at)
      end

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, @dia_60) == 0
    end

    test "o número de um período anterior à saída é o mesmo antes e depois (SC-001)", ctx do
      declarar(ctx, ctx.dev)
      declarar(ctx, ctx.sm)

      antes = EO.count_team_members_at(ctx.tenant, ctx.equipe.id, ~U[2026-01-15 00:00:00Z])

      {:ok, 2} =
        EO.record_team_departure(ctx.tenant, ctx.equipe.id, ctx.ana.id, @dia_30, ctx.autor.id)

      depois = EO.count_team_members_at(ctx.tenant, ctx.equipe.id, ~U[2026-01-15 00:00:00Z])

      assert antes == depois, "a saída reescreveu o passado"
    end
  end

  describe "as recusas têm nome, e nenhuma é sucesso silencioso" do
    test "par sem vínculo vigente é erro, e nunca {:ok, 0}", ctx do
      assert {:error, motivo} =
               EO.record_team_departure(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 @dia_30,
                 ctx.autor.id
               )

      assert motivo =~ "não tem vínculo vigente"
    end

    test "data no futuro é recusada", ctx do
      declarar(ctx, ctx.dev)
      amanha = DateTime.add(DateTime.utc_now(), 86_400, :second)

      assert {:error, motivo} =
               EO.record_team_departure(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 amanha,
                 ctx.autor.id
               )

      assert motivo =~ "futuro"
      assert [vinculo] = vinculos(ctx)
      assert is_nil(vinculo.ended_at), "a recusa gravou o fim mesmo assim"
    end

    test "saída sem autor é recusada — fim sem autor é indistinguível de fim constatado", ctx do
      declarar(ctx, ctx.dev)

      assert {:error, motivo} =
               EO.record_team_departure(ctx.tenant, ctx.equipe.id, ctx.ana.id, @dia_30, nil)

      assert motivo =~ "quem a declarou"
      assert [vinculo] = vinculos(ctx)
      assert is_nil(vinculo.ended_at)
    end

    test "a segunda saída não reescreve a data da primeira (FR-023)", ctx do
      declarar(ctx, ctx.dev)

      {:ok, 1} =
        EO.record_team_departure(ctx.tenant, ctx.equipe.id, ctx.ana.id, @dia_30, ctx.autor.id)

      assert {:error, _} =
               EO.record_team_departure(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 ~U[2026-02-15 00:00:00Z],
                 ctx.autor.id
               )

      assert [vinculo] = vinculos(ctx)
      assert vinculo.ended_at == @dia_30, "a segunda tentativa reescreveu a primeira data"
    end
  end

  describe "o equívoco alcança o par pelo mesmo motivo da saída (FR-024, FR-025)" do
    # Vive neste arquivo, e não no `team_membership_test.exs`, porque o que se prova é a MESMA
    # decisão: saída e equívoco são afirmações sobre a pessoa NA EQUIPE, e o cenário de dois
    # papéis vigentes que as distingue está montado aqui.

    test "quem tem dois papéis vigentes é invalidado nos dois numa chamada", ctx do
      declarar(ctx, ctx.dev)
      declarar(ctx, ctx.sm)

      assert {:ok, 2} =
               EO.record_team_membership_mistake(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 "homônima — é outra Ana",
                 ctx.autor.id
               )

      for vinculo <- vinculos(ctx) do
        refute is_nil(vinculo.invalidated_at), "um dos papéis ficou vigente depois do equívoco"
        assert vinculo.invalidated_by_user_id == ctx.autor.id
        assert vinculo.invalidation_reason == "homônima — é outra Ana"
      end
    end

    test "o invalidado não conta em data ALGUMA, nem antes do reconhecimento", ctx do
      declarar(ctx, ctx.dev, @dia_1)
      declarar(ctx, ctx.sm, @dia_1)

      # UMA pessoa, com dois papéis. A contagem é de PESSOAS: `count(m.id)` daria 2 aqui, e
      # foi assim que o defeito apareceu — a função promete "quantas pessoas".
      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, ~U[2026-01-15 00:00:00Z]) == 1

      # E a lista traz a pessoa UMA vez, pelo mesmo motivo.
      assert [uma] = EO.team_members_at(ctx.tenant, ctx.equipe.id, ~U[2026-01-15 00:00:00Z])
      assert uma.person_id == ctx.ana.id

      {:ok, 2} =
        EO.record_team_membership_mistake(
          ctx.tenant,
          ctx.equipe.id,
          ctx.ana.id,
          "engano",
          ctx.autor.id
        )

      # Depois: zero, e em TODA data. É a diferença com a saída — a saída fecha um período que
      # existiu; o equívoco diz que ele nunca existiu.
      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, ~U[2026-01-15 00:00:00Z]) == 0,
             "o equívoco tem de sair da medida também nas datas anteriores ao reconhecimento"

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, @dia_60) == 0
    end

    test "razão vazia continua recusada, e sem autor também", ctx do
      declarar(ctx, ctx.dev)

      assert {:error, razao} =
               EO.record_team_membership_mistake(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 "",
                 ctx.autor.id
               )

      assert razao =~ "razão escrita"

      assert {:error, autor} =
               EO.record_team_membership_mistake(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 "engano",
                 nil
               )

      assert autor =~ "quem o registrou"

      assert [vinculo] = vinculos(ctx)
      assert is_nil(vinculo.invalidated_at), "uma das recusas gravou o equívoco mesmo assim"
    end

    test "par sem vínculo vigente é erro nomeado, e nunca {:ok, 0}", ctx do
      assert {:error, motivo} =
               EO.record_team_membership_mistake(
                 ctx.tenant,
                 ctx.equipe.id,
                 ctx.ana.id,
                 "engano",
                 ctx.autor.id
               )

      assert motivo =~ "não tem vínculo vigente"
    end
  end

  describe "a coleta não desfaz a saída declarada (FR-026, FR-027)" do
    test "depois da saída, a coleta NÃO recria o vínculo enquanto a origem seguir mostrando",
         ctx do
      {:ok, _evidencia} = observar(ctx, ~U[2026-02-01 00:00:00Z])
      assert [observado] = vinculos(ctx)
      assert is_nil(observado.organizational_role_id), "é vínculo observado"

      {:ok, 1} =
        EO.record_team_departure(ctx.tenant, ctx.equipe.id, ctx.ana.id, @dia_30, ctx.autor.id)

      # A origem continua listando a pessoa. Sem `ended_by_user_id` na guarda, esta coleta
      # criava um segundo vínculo e a saída era desfeita sem ninguém pedir.
      {:ok, _} = observar(ctx, ~U[2026-02-02 00:00:00Z])

      assert [so_o_encerrado] = vinculos(ctx), "a coleta recriou o vínculo por cima da saída"
      assert so_o_encerrado.id == observado.id
      assert so_o_encerrado.ended_at == @dia_30
    end

    test "depois de ausência constatada E reobservação, nasce vínculo NOVO — é retorno", ctx do
      {:ok, _} = observar(ctx, ~U[2026-02-01 00:00:00Z])
      assert [primeiro] = vinculos(ctx)

      {:ok, 1} =
        EO.record_team_departure(ctx.tenant, ctx.equipe.id, ctx.ana.id, @dia_30, ctx.autor.id)

      # A origem deixou de mostrar a pessoa: a coleta seguinte não a viu, e a ausência é
      # constatada. É este passo que separa "continuação" de "retorno".
      {:ok, 1} =
        EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.org.id, DateTime.utc_now(:second))

      # E a origem volta a mostrá-la.
      {:ok, _} = observar(ctx, DateTime.utc_now(:second))

      vinculos = vinculos(ctx)
      assert length(vinculos) == 2, "o retorno não gerou vínculo novo"

      antigo = Enum.find(vinculos, &(&1.id == primeiro.id))
      novo = Enum.find(vinculos, &(&1.id != primeiro.id))

      assert antigo.ended_at == @dia_30, "o período antigo perdeu o seu fim"
      assert antigo.ended_by_user_id == ctx.autor.id
      assert is_nil(novo.ended_at), "o vínculo do retorno tem de estar vigente"
      assert is_nil(novo.ended_by_user_id)
      assert is_nil(novo.organizational_role_id), "o retorno é observado: papel ausente"
    end
  end
end
