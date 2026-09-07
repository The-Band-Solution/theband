defmodule TheBand.Ontology.SEON.EO.VinculoObservadoTest do
  @moduledoc """
  O vínculo OBSERVADO — decisão da pessoa mantenedora em 2026-09-06 (specs 055 e 058, emenda).

  ## O que a medida mostrou

  A coleta trazia as 8 equipes do GitHub da `leds-conectafapes` com 59 evidências de vínculo
  (49 pessoas), batendo com a origem. Pela regra da 055, evidência não era vínculo até alguém
  confirmar com papel; ninguém confirmou; as 8 equipes tinham ZERO vínculos vigentes, toda
  medida por equipe saía vazia, e 838 das 1 077 solicitações dos últimos 56 dias (78%) eram de
  autores só com evidência pendente — fora de toda medida por equipe.

  ## O que passa a valer

  A participação que a origem mostra vira `eo.team_membership` na coleta, com o papel
  declaradamente ausente. Quem administra declara o papel depois, **no mesmo vínculo**. Quando
  a origem deixa de mostrar a pessoa, o vínculo observado é encerrado; o declarado não é
  tocado (FR-012: as duas afirmações, lado a lado).
  """
  use TheBand.DataCase, async: true

  alias TheBand.Mapping.Antipatterns
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.EO.Schemas.TeamMembership
  alias TheBand.Repo

  setup do
    tenant = tenant_fixture()
    org = organization_fixture(tenant, "acme")
    equipe = team_fixture(tenant, "T_plataforma", %{organization: org, name: "PLATAFORMA"})

    {:ok, ana} =
      EO.upsert_person_from_source(tenant, source_attrs("U_ana", %{name: "Ana", login: "ana"}))

    admin = user_fixture(tenant)

    %{tenant: tenant, org: org, equipe: equipe, ana: ana, admin: admin}
  end

  defp observar(ctx, pessoa, quando \\ DateTime.utc_now(:second)) do
    EO.record_team_membership_evidence(ctx.tenant, %{
      person_id: pessoa.id,
      team_id: ctx.equipe.id,
      person_external_id: pessoa.external_id,
      team_external_id: ctx.equipe.external_id,
      platform_access_level: "MEMBER",
      source_system: "github",
      source_instance: "https://github.com",
      observed_at: quando
    })
  end

  defp vinculos(ctx) do
    Repo.all(
      from m in TeamMembership,
        where: m.tenant_id == ^ctx.tenant.id and m.team_id == ^ctx.equipe.id,
        order_by: m.inserted_at
    )
  end

  describe "a participação observada vira vínculo na coleta" do
    test "uma evidência nova cria UM vínculo vigente sem papel, e a pessoa conta como membro",
         ctx do
      {:ok, evidencia} = observar(ctx, ctx.ana)

      assert [vinculo] = vinculos(ctx)
      assert is_nil(vinculo.organizational_role_id), "papel declaradamente ausente"
      assert is_nil(vinculo.declared_by_user_id), "ninguém declarou: é observado"
      assert is_nil(vinculo.started_at), "a origem não diz desde quando — e nunca é `observed_at`"
      assert is_nil(vinculo.ended_at)

      assert evidencia.promoted_membership_id == vinculo.id,
             "a evidência aponta para o vínculo que a materializou"

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, DateTime.utc_now()) == 1, """
      A pessoa que a origem mostra na equipe não contou como membro. É o estado que deixou
      8 equipes com zero membros e 78% das solicitações fora de toda medida em 2026-09-06.
      """

      assert EO.count_memberships_pending_role(ctx.tenant, team_id: ctx.equipe.id) == 1,
             "o que fica pendente é o PAPEL, e a contagem diz isso"
    end

    test "reobservar a mesma pessoa não duplica o vínculo", ctx do
      {:ok, primeira} = observar(ctx, ctx.ana)
      {:ok, segunda} = observar(ctx, ctx.ana)

      assert [_um_so] = vinculos(ctx)
      assert primeira.promoted_membership_id == segunda.promoted_membership_id
    end

    test "duas pessoas, dois vínculos — e a equipe deixa de ser 'sem nenhum vínculo vigente'",
         ctx do
      {:ok, bia} =
        EO.upsert_person_from_source(
          ctx.tenant,
          source_attrs("U_bia", %{name: "Bia", login: "bia"})
        )

      {:ok, _} = observar(ctx, ctx.ana)
      {:ok, _} = observar(ctx, bia)

      achados = Antipatterns.detect_structural_for_team(ctx.tenant, ctx.equipe.id)

      refute Enum.any?(achados, &(&1.id == "structure.ap02.team_with_no_members")), """
      A equipe tem duas pessoas observadas na origem e a tela dizia "sem nenhum vínculo
      vigente". Era verdade pela regra antiga, e era a frase que fazia a tela da equipe
      PLATAFORMA (19 pessoas) parecer vazia.
      """
    end
  end

  describe "a ausência na origem encerra o vínculo observado — e só ele" do
    test "quem sumiu da origem tem o vínculo ENCERRADO, não apagado; o passado não muda", ctx do
      antes = DateTime.add(DateTime.utc_now(:second), -3600, :second)
      {:ok, _} = observar(ctx, ctx.ana, antes)

      # A coleta seguinte começa agora e não vê a Ana: tudo observado antes dela é ausência.
      inicio_da_coleta = DateTime.utc_now(:second)
      {:ok, 1} = EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.org.id, inicio_da_coleta)

      assert [vinculo] = vinculos(ctx)
      assert vinculo.ended_at, "encerrado no instante da ausência"

      assert EO.count_team_members_at(
               ctx.tenant,
               ctx.equipe.id,
               DateTime.add(inicio_da_coleta, 60)
             ) == 0

      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, DateTime.add(antes, 60)) == 1,
             """
             Registrar a saída mudou o passado (SC-002 da 055). Antes da ausência a pessoa estava;
             encerrar grava a data e não reescreve o que já foi.
             """
    end

    test "o vínculo DECLARADO não é tocado pela ausência — as duas afirmações convivem", ctx do
      antes = DateTime.add(DateTime.utc_now(:second), -3600, :second)
      {:ok, evidencia} = observar(ctx, ctx.ana, antes)

      {:ok, declarado} =
        EO.promote_evidence(
          ctx.tenant,
          evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.admin.id
        )

      {:ok, 1} =
        EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.org.id, DateTime.utc_now(:second))

      assert Repo.get!(TeamMembership, declarado.id).ended_at == nil, """
      A coleta encerrou um vínculo que a organização DECLAROU. A declaração é da organização;
      coleta e declaração discordando é o que a tela mostra lado a lado (055, FR-012) — e não
      o que a coleta resolve sozinha.
      """
    end

    test "quem saiu e voltou ganha vínculo novo; o antigo fica encerrado", ctx do
      antes = DateTime.add(DateTime.utc_now(:second), -3600, :second)
      {:ok, _} = observar(ctx, ctx.ana, antes)

      {:ok, 1} =
        EO.mark_evidence_no_longer_observed(ctx.tenant, ctx.org.id, DateTime.utc_now(:second))

      {:ok, _} = observar(ctx, ctx.ana)

      assert [encerrado, vigente] = vinculos(ctx)
      assert encerrado.ended_at
      assert is_nil(vigente.ended_at)
      assert EO.count_team_members_at(ctx.tenant, ctx.equipe.id, DateTime.utc_now()) == 1
    end
  end

  describe "declarar o papel é sobre o MESMO vínculo" do
    test "promote_evidence preenche papel e autor no vínculo observado, sem criar outro", ctx do
      {:ok, evidencia} = observar(ctx, ctx.ana)
      [observado] = vinculos(ctx)

      {:ok, declarado} =
        EO.promote_evidence(
          ctx.tenant,
          evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.admin.id
        )

      assert declarado.id == observado.id, """
      Declarar o papel criou um segundo vínculo em vez de completar o observado. Dois vínculos
      vigentes para a mesma pessoa na mesma equipe é o que faria a contagem de membros dobrar.
      """

      assert declarado.organizational_role_id
      assert declarado.declared_by_user_id == ctx.admin.id
      assert [_um_so] = vinculos(ctx)
      assert EO.count_memberships_pending_role(ctx.tenant, team_id: ctx.equipe.id) == 0
      assert EO.pending_evidence(ctx.tenant, ctx.equipe.id) == [], "nada mais espera declaração"
    end

    test "declarar de novo é recusado: o papel já foi declarado", ctx do
      {:ok, evidencia} = observar(ctx, ctx.ana)

      {:ok, _} =
        EO.promote_evidence(
          ctx.tenant,
          evidencia.id,
          {:catalogo, "sro.developer_role"},
          ctx.admin.id
        )

      assert {:error, :already_promoted} =
               EO.promote_evidence(
                 ctx.tenant,
                 evidencia.id,
                 {:catalogo, "sro.developer_role"},
                 ctx.admin.id
               )
    end

    test "a declaração exige papel: vínculo declarado sem papel é recusado pelo changeset", ctx do
      changeset =
        TeamMembership.changeset(%TeamMembership{}, %{
          tenant_id: ctx.tenant.id,
          internal_id: "declared_x",
          person_id: ctx.ana.id,
          team_id: ctx.equipe.id,
          declared_by_user_id: ctx.admin.id,
          organizational_role_id: nil
        })

      refute changeset.valid?,
             "declaração sem papel é a alocação incompleta que a ontologia recusa"
    end
  end
end
