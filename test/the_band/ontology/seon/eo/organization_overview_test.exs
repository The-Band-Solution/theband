defmodule TheBand.Ontology.SEON.EO.OrganizationOverviewTest do
  @moduledoc """
  A leitura agregada da organização — feature 046, US3, contrato
  `specs/046-menu-por-entidades/contracts/eo-organization-overview.md`.

  ## As asserções que carregam este arquivo

  1. **nada de outro tenant** — a violação, não o caminho feliz (lição L03): o
     resultado de um tenant povoado não contém organização, equipe nem pessoa do
     outro;
  2. **responsável é concessão declarada**, nunca nome de papel: papel sem grant
     de escopo `organization` não responde por ninguém (regra #369);
  3. **vínculo encerrado não responde** — `ended_at` fecha a responsabilidade;
  4. **organização vazia não some**: entra com as listas vazias, e é a tela quem
     nomeia a ausência;
  5. **equipe que deixou de ser observada sai das listas** — marca, nunca apaga,
     e a leitura respeita a marca.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.SEON.EO

  setup do
    tenant = tenant_fixture()
    admin = user_fixture(tenant)
    org = organization_fixture(tenant, "acme")

    %{tenant: tenant, admin: admin, org: org}
  end

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(
        ctx.tenant,
        Map.merge(source_attrs("U_#{login}"), %{
          name: login,
          login: login,
          account_type: "person"
        })
      )

    p
  end

  defp equipe(ctx, nome, organization_id) do
    {:ok, t} = EO.create_declared_team(ctx.tenant, nome, ctx.admin.id)

    # A equipe declarada nasce sem organização; o agregado agrupa por ela, então o
    # teste a preenche — mesmo expediente do teste de visibilidade.
    Repo.update_all(
      from(x in "eo_teams",
        where: x.id == type(^t.id, :binary_id),
        update: [set: [organization_id: type(^organization_id, :binary_id)]]
      ),
      []
    )

    t
  end

  defp papel(ctx, code, name) do
    {:ok, r} = EO.create_role(ctx.tenant, ctx.org.id, %{code: code, name: name}, ctx.admin.id)
    r
  end

  defp aloca(ctx, pessoa, equipe, papel, opts \\ []) do
    {:ok, m} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        started_at: Keyword.get(opts, :started_at, DateTime.utc_now(:second)),
        ended_at: Keyword.get(opts, :ended_at)
      })

    m
  end

  test "agrega equipes e responsáveis por organização, e nada do outro tenant", ctx do
    equipe_a = equipe(ctx, "Plataforma", ctx.org.id)
    responsavel = pessoa(ctx, "diretora")
    dev = pessoa(ctx, "dev")

    papel_resp = papel(ctx, "org-lead", "Organization Lead")
    papel_dev = papel(ctx, "developer", "Developer Role")

    {:ok, _} = EO.declare_grant(ctx.tenant, papel_resp.id, "organization", ctx.admin.id)

    aloca(ctx, responsavel, equipe_a, papel_resp)
    aloca(ctx, dev, equipe_a, papel_dev)

    # O outro tenant, povoado de propósito: a violação é o que se testa (L03).
    outro = tenant_fixture()
    outro_admin = user_fixture(outro)
    outra_org = organization_fixture(outro, "intrusa")
    {:ok, outra_equipe} = EO.create_declared_team(outro, "Intrusos", outro_admin.id)

    Repo.update_all(
      from(x in "eo_teams",
        where: x.id == type(^outra_equipe.id, :binary_id),
        update: [set: [organization_id: type(^outra_org.id, :binary_id)]]
      ),
      []
    )

    [entrada] = EO.organization_overview(ctx.tenant)

    assert entrada.organization.id == ctx.org.id
    assert Enum.map(entrada.teams, & &1.name) == ["Plataforma"]

    assert [%{person: p, role_name: "Organization Lead"}] = entrada.responsibles
    assert p.id == responsavel.id

    # A violação: nada do outro tenant vaza para cá.
    nomes = Enum.map(entrada.teams, & &1.name)
    refute "Intrusos" in nomes

    refute Enum.any?(entrada.responsibles, &(&1.person.login == "dev")),
           "papel sem concessão de escopo organization virou responsável"

    [entrada_do_outro] = EO.organization_overview(outro)
    assert entrada_do_outro.organization.id == outra_org.id
    assert entrada_do_outro.responsibles == []
  end

  test "vínculo encerrado não responde pela organização", ctx do
    equipe_a = equipe(ctx, "Plataforma", ctx.org.id)
    ex_responsavel = pessoa(ctx, "saiu")
    papel_resp = papel(ctx, "org-lead", "Organization Lead")
    {:ok, _} = EO.declare_grant(ctx.tenant, papel_resp.id, "organization", ctx.admin.id)

    inicio = DateTime.add(DateTime.utc_now(:second), -60, :day)
    fim = DateTime.add(DateTime.utc_now(:second), -1, :day)
    aloca(ctx, ex_responsavel, equipe_a, papel_resp, started_at: inicio, ended_at: fim)

    [entrada] = EO.organization_overview(ctx.tenant)
    assert entrada.responsibles == []
  end

  test "organização sem equipe nem responsável não some — entra vazia", ctx do
    [entrada] = EO.organization_overview(ctx.tenant)

    assert entrada.organization.id == ctx.org.id
    assert entrada.teams == []
    assert entrada.responsibles == []
  end

  test "equipe que deixou de ser observada sai da lista", ctx do
    equipe_a = equipe(ctx, "Extinta", ctx.org.id)

    Repo.update_all(
      from(x in "eo_teams",
        where: x.id == type(^equipe_a.id, :binary_id),
        update: [set: [no_longer_observed_at: ^DateTime.utc_now(:second)]]
      ),
      []
    )

    [entrada] = EO.organization_overview(ctx.tenant)
    assert entrada.teams == []
  end
end
