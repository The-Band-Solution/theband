defmodule TheBand.Ontology.SEON.EO.ColetaNaoApagaDeclaracaoTest do
  @moduledoc """
  A coleta marca a evidência, e **não toca no vínculo declarado** (T011, FR-014).

  ## O pior resultado possível desta feature

  O vínculo é declaração humana: nenhuma origem observada fornece papel organizacional. A
  evidência é observação: a origem mostrou a pessoa na equipe.

  Quando a origem para de mostrar, `mark_evidence_no_longer_observed/3` marca a evidência. Se
  ela marcasse — ou apagasse — o vínculo junto, **uma coleta apagaria uma declaração humana**,
  e a plataforma perderia o que nenhuma origem forneceu.

  ## Por que a asserção é a contagem

  "O vínculo existe" passaria mesmo se a coleta tivesse apagado **outro**. O que distingue o
  comportamento certo do defeito é o número antes e depois.

  ## E por que encerrar automaticamente também estaria errado

  Gravar `ended_at` quando a evidência some seria a plataforma afirmando que a pessoa **deixou
  o papel**. O que ela sabe é que a origem **parou de mostrar a participação** — e a segunda
  não implica a primeira. Alguém pode continuar sendo Scrum Master de um time cujo registro no
  GitHub foi apagado.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.SEON.EO

  setup do
    tenant = tenant_fixture()
    # A organização vem ANTES do papel: desde a issue #317 o papel pertence a uma, e a ordem
    # de criação passou a importar.
    organizacao = organization_fixture(tenant, "acme")
    user = user_fixture(tenant)

    {:ok, papel} =
      EO.create_role(tenant, organizacao.id, %{code: "developer", name: "Desenvolvedor"}, user.id)

    equipe = team_fixture(tenant, "T_a", %{organization: organizacao})

    {:ok, pessoa} =
      EO.upsert_person_from_source(tenant, source_attrs("U_1", %{name: "Alguém"}))

    {:ok, evidencia} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        person_external_id: "U_1",
        team_external_id: "T_a",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    {:ok, vinculo} =
      EO.allocate(tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        evidence_id: evidencia.id
      })

    %{
      tenant: tenant,
      organizacao: organizacao,
      evidencia: evidencia,
      vinculo: vinculo,
      pessoa: pessoa
    }
  end

  test "a coleta marca a evidência e o vínculo continua vigente", ctx do
    antes = EO.count_memberships(ctx.tenant)

    # A coleta seguinte não viu a pessoa na equipe: a evidência é marcada.
    {:ok, _} =
      EO.mark_evidence_no_longer_observed(
        ctx.tenant,
        ctx.organizacao.id,
        DateTime.add(DateTime.utc_now(:second), 60, :second)
      )

    assert recarregar_evidencia(ctx).no_longer_observed_at, """
    A evidência tinha de ser marcada — é o comportamento da feature 002, e ele não muda.
    """

    assert EO.count_memberships(ctx.tenant) == antes, """
    **A asserção que importa.** A contagem de vínculos é idêntica antes e depois.

    "O vínculo existe" passaria mesmo se a coleta tivesse apagado outro; o número é o que
    distingue o comportamento certo do defeito.
    """

    {:ok, intacto} = EO.fetch_membership(ctx.tenant, ctx.vinculo.id)

    refute intacto.ended_at, """
    O vínculo foi **encerrado** pela coleta.

    Gravar `ended_at` aqui seria a plataforma afirmando que a pessoa deixou o papel. O que ela
    sabe é que a origem parou de mostrar a participação — e a segunda coisa não implica a
    primeira.
    """
  end

  test "a evidência que volta a ser observada não muda o vínculo", ctx do
    {:ok, _} =
      EO.mark_evidence_no_longer_observed(
        ctx.tenant,
        ctx.organizacao.id,
        DateTime.add(DateTime.utc_now(:second), 60, :second)
      )

    antes = EO.fetch_membership(ctx.tenant, ctx.vinculo.id)

    # A origem volta a mostrar: a coleta reobserva.
    {:ok, _} =
      EO.record_team_membership_evidence(ctx.tenant, %{
        person_id: ctx.pessoa.id,
        team_id: ctx.evidencia.team_id,
        person_external_id: "U_1",
        team_external_id: "T_a",
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second)
      })

    assert EO.fetch_membership(ctx.tenant, ctx.vinculo.id) == antes, """
    O vínculo nunca soube que a evidência sumiu, e não pode saber que ela voltou. As duas
    coisas vivem em tabelas separadas de propósito.
    """
  end

  test "encerrar o vínculo não apaga a evidência", ctx do
    {:ok, _} = EO.end_allocation(ctx.tenant, ctx.vinculo.id, DateTime.utc_now(:second))

    assert recarregar_evidencia(ctx), """
    Encerrar uma declaração humana não pode apagar a observação que a originou — ela continua
    sendo o que a origem mostrou.
    """
  end

  defp recarregar_evidencia(ctx) do
    Repo.get!(TheBand.Ontology.SEON.EO.Schemas.TeamMembershipEvidence, ctx.evidencia.id)
  end
end
