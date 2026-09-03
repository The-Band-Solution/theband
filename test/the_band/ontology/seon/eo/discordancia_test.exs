defmodule TheBand.Ontology.SEON.EO.DiscordanciaTest do
  @moduledoc """
  Feature 055, T014 — `membership_disagreements/2` (FR-012).

  A tela é testada em `TheBandWeb.DuasAfirmacoesTest`. Aqui está o que a tela não
  alcança: o isolamento entre tenants, a agregação por pessoa, e os dois casos
  que **não** são discordância.

  ## O que o teste do isolamento prova, e o que ele NÃO prova

  Medido por injeção, e não presumido. `eo_teams.id` é UUID **único entre
  tenants**, então filtrar por `team_id` já isola sozinho. Consequência:

  - remover **só** o `tenant_id` da consulta externa: os 8 testes continuam
    passando;
  - remover **só** o da subconsulta dos declarados: idem;
  - remover **os dois**: `membership_disagreements(tenant_a, equipe_do_b)` passa a
    devolver a linha do tenant B, e o segundo teste reprova.

  Os dois filtros são, portanto, **defesa em profundidade** — e nenhum teste pode
  distinguí-los individualmente enquanto o id da equipe for único. Escrever aqui
  que este arquivo "prova o isolamento" seria afirmar mais do que ele mede.

  Eles ficam porque a consulta que depende do id ser único adquire um
  pré-requisito que nada declara: bastaria uma equipe endereçada por id de origem
  para o filtro voltar a ser a única coisa entre um tenant e o dado do outro.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.SEON.EO

  setup do
    %{a: cenario("acme"), b: cenario("outra")}
  end

  describe "isolamento entre tenants" do
    test "a discordância de um tenant não aparece no outro", ctx do
      # A mesma forma dos dois lados, com nomes iguais: se a consulta esquecer o
      # tenant, o resultado ainda parece certo em contagem.
      discorda(ctx.a)
      discorda(ctx.b)

      [so_uma] = EO.membership_disagreements(ctx.a.tenant, ctx.a.equipe.id)
      assert so_uma.person_id == ctx.a.pessoa.id
      refute so_uma.person_id == ctx.b.pessoa.id

      [outra] = EO.membership_disagreements(ctx.b.tenant, ctx.b.equipe.id)
      assert outra.person_id == ctx.b.pessoa.id
    end

    test "a equipe de mesmo nome no outro tenant não traz linha nenhuma", ctx do
      discorda(ctx.b)

      assert EO.membership_disagreements(ctx.a.tenant, ctx.b.equipe.id) == []
    end
  end

  describe "a agregação por pessoa" do
    test "vínculo encerrado ao lado de um vigente NÃO é discordância", ctx do
      c = ctx.a
      {:ok, encerrado} = aloca(c, c.papel)
      {:ok, _} = EO.end_allocation(c.tenant, encerrado.id, ontem())

      {:ok, outro_papel} =
        EO.create_role(c.tenant, c.org.id, %{code: "sm", name: "Scrum Master"}, c.user.id)

      {:ok, _vigente} = aloca(c, outro_papel)

      # Juntar evidência com vínculo linha a linha devolveria a linha encerrada
      # como discordância, enquanto a vigente concorda com a coleta.
      assert EO.membership_disagreements(c.tenant, c.equipe.id) == []
    end

    test "dois vínculos, os dois encerrados, é discordância uma vez só", ctx do
      c = ctx.a
      {:ok, um} = aloca(c, c.papel)
      {:ok, _} = EO.end_allocation(c.tenant, um.id, ontem())

      {:ok, outro_papel} =
        EO.create_role(c.tenant, c.org.id, %{code: "sm", name: "Scrum Master"}, c.user.id)

      {:ok, dois} = aloca(c, outro_papel)
      {:ok, _} = EO.end_allocation(c.tenant, dois.id, ontem())

      # Uma pessoa, uma linha. Duas linhas fariam quem conta a lista medir
      # vínculos em vez de gente.
      assert [uma] = EO.membership_disagreements(c.tenant, c.equipe.id)
      assert uma.person_id == c.pessoa.id
      refute uma.declarado.vigente?
    end
  end

  describe "o vínculo invalidado" do
    test "o equívoco conta como 'não está', e discorda da coleta que mostra", ctx do
      c = ctx.a
      {:ok, _} = aloca(c, c.papel)

      {:ok, _} =
        EO.record_team_membership_mistake(
          c.tenant,
          c.equipe.id,
          c.pessoa.id,
          "equipe errada",
          c.user.id
        )

      assert [d] = EO.membership_disagreements(c.tenant, c.equipe.id)

      # `equivoco?` distingue "nunca esteve" de "saiu": registrar o engano é
      # afirmação MAIS forte que a saída, e não ausência de afirmação.
      assert d.declarado.equivoco?
      refute d.declarado.vigente?
      assert d.observado.presente?
    end

    test "um papel encerrado ao lado de um invalidado NÃO é equívoco", ctx do
      c = ctx.a

      # Pertenceu como desenvolvedora e saiu; o vínculo de Scrum Master foi um
      # engano. Dizer "nunca esteve" seria falso — ela esteve, no primeiro papel.
      {:ok, encerrado} = aloca(c, c.papel)
      {:ok, _} = EO.end_allocation(c.tenant, encerrado.id, ontem())

      {:ok, outro_papel} =
        EO.create_role(c.tenant, c.org.id, %{code: "sm", name: "Scrum Master"}, c.user.id)

      {:ok, _} = aloca(c, outro_papel)

      {:ok, _} =
        EO.record_team_membership_mistake(
          c.tenant,
          c.equipe.id,
          c.pessoa.id,
          "papel errado",
          c.user.id
        )

      assert [d] = EO.membership_disagreements(c.tenant, c.equipe.id)

      # A discordância existe — a coleta mostra, e nenhuma declaração está vigente.
      # O que ela NÃO é: equívoco.
      refute d.declarado.vigente?

      refute d.declarado.equivoco?,
             "marcou como equívoco quem teve papel encerrado — a tela diria 'nunca esteve', e é falso"
    end
  end

  describe "o que NÃO é discordância" do
    test "as duas concordando devolvem lista vazia", ctx do
      c = ctx.a
      {:ok, _} = aloca(c, c.papel)

      assert EO.membership_disagreements(c.tenant, c.equipe.id) == []
    end

    test "evidência sem vínculo nenhum não é discordância", ctx do
      # A coleta afirma; a declaração não afirmou nada. Isso sai por
      # `pending_evidence/2` — discordância exige AS DUAS terem falado.
      assert EO.membership_disagreements(ctx.a.tenant, ctx.a.equipe.id) == []
    end

    test "vínculo sem evidência nenhuma não é discordância", ctx do
      c = ctx.a

      {:ok, outra_pessoa} =
        EO.upsert_person_from_source(c.tenant, source_attrs("U_9", %{name: "Sem coleta"}))

      {:ok, _} =
        EO.allocate(c.tenant, %{
          person_id: outra_pessoa.id,
          team_id: c.equipe.id,
          organizational_role_id: c.papel.id
        })

      # A origem nunca mostrou esta pessoa, e ausência de evidência não é
      # afirmação de ausência.
      assert EO.membership_disagreements(c.tenant, c.equipe.id) == []
    end
  end

  # Um tenant inteiro, com os nomes iguais nos dois para que o teste do
  # isolamento não passe por acidente de nomenclatura.
  defp cenario(login) do
    tenant = tenant_fixture()
    org = organization_fixture(tenant, login)
    user = user_fixture(tenant)

    {:ok, papel} =
      EO.create_role(tenant, org.id, %{code: "developer", name: "Desenvolvedor"}, user.id)

    equipe = team_fixture(tenant, "T_a", %{organization: org})

    {:ok, pessoa} = EO.upsert_person_from_source(tenant, source_attrs("U_1", %{name: "Ana"}))

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

    %{
      tenant: tenant,
      org: org,
      user: user,
      papel: papel,
      equipe: equipe,
      pessoa: pessoa,
      evidencia: evidencia
    }
  end

  defp discorda(c) do
    {:ok, vinculo} = aloca(c, c.papel)
    {:ok, _} = EO.end_allocation(c.tenant, vinculo.id, ontem())
    :ok
  end

  defp aloca(c, papel) do
    EO.allocate(c.tenant, %{
      person_id: c.pessoa.id,
      team_id: c.equipe.id,
      organizational_role_id: papel.id,
      declared_by_user_id: c.user.id
    })
  end

  defp ontem, do: DateTime.add(DateTime.utc_now(:second), -1, :day)
end
