defmodule TheBand.Ontology.SEON.EO.PersonTeamsTest do
  @moduledoc """
  O que a origem declara sobre a pessoa (T001, T002).

  ## O que a plataforma recusa afirmar

  São **88 evidências** de vínculo pessoa-equipe e **zero** vínculos materializados, porque o vínculo
  da ontologia exige papel e nenhum papel foi cadastrado. Estas consultas existem para a tela poder
  dizer as três coisas: o que a origem declarou, que a plataforma não promoveu, e **por quê**.
  """
  use TheBand.DataCase, async: true

  alias TheBand.Ontology.SEON.EO

  setup do
    tenant = tenant_fixture()
    org = organization_fixture(tenant, "acme")
    {:ok, pessoa} = pessoa(tenant, "ana")
    %{tenant: tenant, org: org, pessoa: pessoa}
  end

  describe "as equipes que a origem declara" do
    test "cada linha diz de qual organização a equipe é", ctx do
      outra_org = organization_fixture(ctx.tenant, "outra")
      core = equipe(ctx.tenant, ctx.org, "core")
      plataforma = equipe(ctx.tenant, outra_org, "plataforma")

      evidenciar(ctx.tenant, ctx.pessoa, core, "MEMBER")
      evidenciar(ctx.tenant, ctx.pessoa, plataforma, "MAINTAINER")

      linhas = EO.list_person_teams(ctx.tenant, ctx.pessoa.id)

      assert Enum.map(linhas, & &1.organization_login) |> Enum.sort() == ["acme", "outra"], """
      A consulta não disse de qual organização é cada equipe.

      Uma pessoa pode atravessar organizações — é a issue #82 —, e uma lista que não distinga somaria
      equipes de organizações diferentes como se fossem do mesmo lugar.
      """
    end

    test "nenhum campo devolvido se chama role", ctx do
      core = equipe(ctx.tenant, ctx.org, "core")
      evidenciar(ctx.tenant, ctx.pessoa, core, "MAINTAINER")

      [linha] = EO.list_person_teams(ctx.tenant, ctx.pessoa.id)

      refute Enum.any?(Map.keys(linha), &(&1 |> Atom.to_string() |> String.contains?("role"))),
             """
             Um campo se chama `role`, e `MAINTAINER` **não é papel**: é permissão na ferramenta.
             `sro.scrum_master` é papel do processo, e mapear um no outro é mapear por semelhança de nome —
             o que contamina toda medida derivada.

             Campos devolvidos: #{inspect(Map.keys(linha))}
             """

      assert linha.platform_access_level == "MAINTAINER"
    end

    test "a evidência não promovida vem marcada como não promovida", ctx do
      core = equipe(ctx.tenant, ctx.org, "core")
      evidenciar(ctx.tenant, ctx.pessoa, core, "MEMBER")

      assert [%{promoted?: false}] = EO.list_person_teams(ctx.tenant, ctx.pessoa.id)
    end

    test "o vínculo que saiu continua na lista, com a data", ctx do
      core = equipe(ctx.tenant, ctx.org, "core")
      evidenciar(ctx.tenant, ctx.pessoa, core, "MEMBER")
      marcar_ausente(ctx.tenant, ctx.pessoa, core)

      assert [linha] = EO.list_person_teams(ctx.tenant, ctx.pessoa.id)

      assert linha.no_longer_observed_at, """
      O vínculo que deixou de ser observado desapareceu da consulta.

      **Houve** vínculo, e ele não está presente — as duas coisas juntas. Omitir faria a pessoa
      parecer nunca ter estado na equipe, e é diferente de nunca ter havido.
      """
    end

    test "não devolve equipe de outro tenant", ctx do
      core = equipe(ctx.tenant, ctx.org, "core")
      evidenciar(ctx.tenant, ctx.pessoa, core, "MEMBER")
      outro = tenant_fixture()

      assert EO.list_person_teams(outro, ctx.pessoa.id) == []
    end
  end

  describe "a contagem de papéis" do
    test "é zero no estado de hoje", ctx do
      assert EO.count_roles(ctx.tenant) == 0, """
      No dado real são **zero** papéis cadastrados, e é por isso que as 88 evidências não foram
      promovidas. A tela usa este número para explicar a causa **com base no dado**, e não em texto
      fixo que envelheceria.
      """
    end

    test "conta por tenant", ctx do
      outro = tenant_fixture()
      papel(ctx.tenant, ctx.org, "scrum_master")

      assert EO.count_roles(ctx.tenant) == 1
      assert EO.count_roles(outro) == 0
    end
  end

  describe "buscar a pessoa" do
    test "devolve identidade e proveniência", ctx do
      assert {:ok, pessoa} = EO.fetch_person(ctx.tenant, ctx.pessoa.id)
      assert pessoa.login == "ana"
      assert pessoa.source_system == "github"
      assert pessoa.external_id == "U_ana"
      assert pessoa.collected_at
    end

    test "pessoa de outro tenant responde não encontrado", ctx do
      outro = tenant_fixture()

      assert {:error, :not_found} = EO.fetch_person(outro, ctx.pessoa.id), """
      A resposta precisa ser **não encontrado**, nunca "sem permissão": confirmar existência já é
      vazamento entre tenants.
      """
    end
  end

  # ------------------------------------------------------------------------ apoio

  defp pessoa(tenant, login) do
    EO.upsert_person_from_source(tenant, %{
      login: login,
      name: String.capitalize(login),
      account_type: "person",
      source_system: "github",
      source_instance: "https://github.com",
      external_id: "U_#{login}",
      collected_at: DateTime.utc_now(:second)
    })
  end

  defp equipe(tenant, org, slug) do
    {:ok, time} =
      EO.upsert_team_from_source(tenant, %{
        organization_id: org.id,
        name: String.capitalize(slug),
        slug: slug,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "T_#{slug}",
        collected_at: DateTime.utc_now(:second)
      })

    time
  end

  defp evidenciar(tenant, pessoa, time, nivel) do
    {:ok, _} =
      EO.record_team_membership_evidence(tenant, %{
        person_id: pessoa.id,
        team_id: time.id,
        person_external_id: pessoa.external_id,
        team_external_id: time.external_id,
        platform_access_level: nivel,
        source_system: "github",
        source_instance: "https://github.com",
        observed_at: DateTime.utc_now(:second),
        last_observed_at: DateTime.utc_now(:second)
      })
  end

  defp marcar_ausente(tenant, pessoa, time) do
    import Ecto.Query

    Repo.update_all(
      from(e in "eo_team_membership_evidence",
        where:
          e.tenant_id == type(^tenant.id, :binary_id) and
            e.person_id == type(^pessoa.id, :binary_id) and
            e.team_id == type(^time.id, :binary_id)
      ),
      set: [no_longer_observed_at: DateTime.utc_now(:second)]
    )
  end

  # Inserção direta, sem passar pelo comando — o teste quer a linha, não o fluxo. Desde a
  # issue #317 a linha exige `organization_id` e **uma origem**: catálogo ou pessoa. Aqui vale
  # o conceito da rede, porque `scrum_master` é justamente um dos quatro.
  defp papel(tenant, organization, code) do
    Repo.insert_all("eo_organizational_roles", [
      %{
        id: Ecto.UUID.bingenerate(),
        tenant_id: Ecto.UUID.dump!(tenant.id),
        organization_id: Ecto.UUID.dump!(organization.id),
        internal_id: code,
        record_version: 1,
        code: code,
        name: String.capitalize(code),
        catalog_concept_id: "sro.#{code}_role",
        inserted_at: DateTime.utc_now(:second),
        updated_at: DateTime.utc_now(:second)
      }
    ])
  end
end
