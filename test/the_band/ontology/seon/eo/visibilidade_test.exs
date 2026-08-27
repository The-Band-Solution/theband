defmodule TheBand.Ontology.SEON.EO.VisibilidadeTest do
  @moduledoc """
  Quem vê o painel de trabalho de quem — issue #369, `FR-012`.

  ## O que este arquivo protege

  A regra decide **acesso**, e o erro dela cai para o lado que ninguém reclama: quem recebe
  o painel de outra pessoa não abre chamado avisando. Por isso as asserções negativas — o
  que a regra RECUSA — são tão importantes quanto as positivas.

  ## As asserções que carregam este arquivo

  1. **sem elo, nem o próprio painel.** A conta que ninguém declarou não sabe sequer quem
     é, e abrir "até alguém declarar" é o comportamento que a #369 existe para acabar;
  2. **liderança não vem do nome do papel.** Um papel chamado `Tech Leader` sem concessão
     declarada não alcança ninguém;
  3. **o alcance para na equipe.** Quem lidera a equipe A não vê a equipe B, ainda que as
     duas sejam da mesma organização — para isso existe o escopo `organization`;
  4. **vínculo encerrado não alcança, dos dois lados.** Quem saiu deixou de liderar, e quem
     saiu deixou de ser liderado;
  5. **o motivo do NÃO é distinguível.** "Não declararam quem você é" e "ninguém foi
     declarado líder" têm remédios diferentes, e a tela precisa dizer qual é — `FR-012g`.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Tenants

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
        Map.merge(source_attrs("U_#{login}"), %{name: login, login: login, account_type: "person"})
      )

    p
  end

  defp conta(ctx, pessoa) do
    {:ok, u} =
      Tenants.create_user(ctx.tenant, %{
        "email" => "#{pessoa.login}-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, ligada} = Tenants.declare_person(ctx.tenant, u.id, pessoa.id, ctx.admin.id)
    ligada
  end

  defp equipe(ctx, nome, organization_id \\ nil) do
    {:ok, t} = EO.create_declared_team(ctx.tenant, nome, ctx.admin.id)

    # `create_declared_team/3` não recebe organização; a equipe declarada nasce sem. O
    # escopo `organization` da visibilidade sobe por ela, então o teste a preenche.
    if organization_id do
      Repo.update_all(
        from(x in "eo_teams",
          where: x.id == type(^t.id, :binary_id),
          update: [set: [organization_id: type(^organization_id, :binary_id)]]
        ),
        []
      )
    end

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
        ended_at: Keyword.get(opts, :ended_at),
        declared_by_user_id: ctx.admin.id
      })

    m
  end

  describe "sem o elo da conta" do
    test "não alcança nem o próprio painel, e o motivo diz por quê", ctx do
      p = pessoa(ctx, "ana")

      {:ok, sem_elo} =
        Tenants.create_user(ctx.tenant, %{"email" => "x@y.test", "role" => "member"})

      assert {:nao, :conta_sem_pessoa_declarada} = EO.pode_ver(ctx.tenant, sem_elo, p.id), """
      A conta sem elo alcançou um painel, ou o motivo não distinguiu o bloqueio.

      Sem saber quem a conta é, nem o painel dela própria é alcançável. E o motivo importa:
      "não declararam quem você é" tem remédio diferente de "ninguém foi declarado líder",
      e a tela precisa mandar quem lê para o lugar certo — FR-012g.
      """
    end
  end

  describe "a própria pessoa" do
    test "vê o próprio painel", ctx do
      p = pessoa(ctx, "ana")
      c = conta(ctx, p)

      assert {:ok, :propria_pessoa} = EO.pode_ver(ctx.tenant, c, p.id)
    end

    test "e não vê o de outra pessoa sem concessão nenhuma", ctx do
      a = pessoa(ctx, "ana")
      b = pessoa(ctx, "bia")
      c = conta(ctx, a)

      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, b.id)
    end
  end

  describe "o líder da equipe" do
    test "papel com nome de líder mas SEM concessão não alcança ninguém", ctx do
      lider = pessoa(ctx, "lider")
      membro = pessoa(ctx, "membro")
      c = conta(ctx, lider)
      eq = equipe(ctx, "Delivery", ctx.org.id)
      tl = papel(ctx, "tech_leader", "Tech Leader")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, lider, eq, tl)
      aloca(ctx, membro, eq, dev)

      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, membro.id), """
      Um papel chamado `Tech Leader` alcançou o painel sem concessão declarada.

      `Tech Leader` parece liderança e `Coordenador` também, e a mesma organização pode ter
      um `Tech Lead` que é senioridade técnica e não chefia ninguém. Conceder por padrão de
      nome erra para o lado que ninguém reclama — FR-012e.
      """
    end

    # Papel SEM concessão nenhuma não prova o filtro de escopo: o join não acha linha, e
    # em branco ele passa por qualquer defeito. O caso que prova é o papel que TEM
    # concessão, mas de OUTRO escopo — aí a linha existe, e só o filtro a separa.
    test "concessão de escopo `organization` não vale como liderança de equipe", ctx do
      lider = pessoa(ctx, "lider")
      de_outra_equipe = pessoa(ctx, "outra")
      c = conta(ctx, lider)
      a = equipe(ctx, "Delivery", ctx.org.id)
      b = equipe(ctx, "Discovery", ctx.org.id)
      tl = papel(ctx, "tech_leader", "Tech Leader")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, lider, a, tl)
      aloca(ctx, de_outra_equipe, b, dev)

      # Declarada, mas para o OUTRO escopo. Se o filtro de escopo sumir, esta linha vira
      # liderança de equipe — e o `Tech Leader` da Delivery passa a ver a Discovery.
      {:ok, _} = EO.declare_grant(ctx.tenant, tl.id, "organization", ctx.admin.id)

      assert {:ok, :responsavel_da_organizacao} = EO.pode_ver(ctx.tenant, c, de_outra_equipe.id)

      {:ok, 1} = EO.revoke_grant(ctx.tenant, tl.id, "organization", ctx.admin.id)
      {:ok, _} = EO.declare_grant(ctx.tenant, dev.id, "organization", ctx.admin.id)

      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, de_outra_equipe.id), """
      Uma concessão de escopo `organization` num papel que a pessoa NÃO tem alcançou o
      painel, ou o escopo declarado num papel foi lido como o outro escopo.

      Os dois escopos respondem perguntas diferentes: liderar a equipe não é responder pela
      organização, e o inverso também não.
      """
    end

    # O buraco que só aparece com equipe SEM organização.
    #
    # Mesma equipe implica mesma organização, então tirar o filtro `scope == "team"` quase
    # nunca concede o que o escopo `organization` já não concederia — e por isso a injeção
    # passava. A exceção é a equipe declarada sem organização: `create_declared_team/3` cria
    # assim, e `NULL = NULL` não é verdadeiro em SQL, então a checagem por organização falha
    # ali. Sem o filtro de escopo, a checagem por equipe passaria — e concederia acesso que
    # nenhuma concessão de equipe autorizou.
    test "concessão de `organization` não abre equipe sem organização", ctx do
      chefe = pessoa(ctx, "chefe")
      colega = pessoa(ctx, "colega")
      c = conta(ctx, chefe)
      solta = equipe(ctx, "Sem organização")
      resp = papel(ctx, "responsavel", "Responsável")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, chefe, solta, resp)
      aloca(ctx, colega, solta, dev)

      {:ok, _} = EO.declare_grant(ctx.tenant, resp.id, "organization", ctx.admin.id)

      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, colega.id), """
      Uma concessão de escopo `organization` abriu uma equipe que não tem organização.

      Responder por organização nenhuma não é responder por essa equipe, e liderança de
      equipe é OUTRA declaração. Concede-se o que foi declarado, e nunca o que sobrou.
      """
    end

    test "com a concessão declarada, alcança quem está na mesma equipe", ctx do
      lider = pessoa(ctx, "lider")
      membro = pessoa(ctx, "membro")
      c = conta(ctx, lider)
      eq = equipe(ctx, "Delivery", ctx.org.id)
      tl = papel(ctx, "tech_leader", "Tech Leader")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, lider, eq, tl)
      aloca(ctx, membro, eq, dev)

      {:ok, _} = EO.declare_grant(ctx.tenant, tl.id, "team", ctx.admin.id)

      assert {:ok, :lidera_a_equipe} = EO.pode_ver(ctx.tenant, c, membro.id)
    end

    test "não alcança outra equipe da mesma organização", ctx do
      lider = pessoa(ctx, "lider")
      de_fora = pessoa(ctx, "defora")
      c = conta(ctx, lider)
      a = equipe(ctx, "Delivery", ctx.org.id)
      b = equipe(ctx, "Discovery", ctx.org.id)
      tl = papel(ctx, "tech_leader", "Tech Leader")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, lider, a, tl)
      aloca(ctx, de_fora, b, dev)

      {:ok, _} = EO.declare_grant(ctx.tenant, tl.id, "team", ctx.admin.id)

      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, de_fora.id), """
      O escopo `team` alcançou outra equipe.

      Liderar a Delivery não é responder pela organização inteira. Quem responde pela
      organização recebe o escopo `organization`, e é outra declaração.
      """
    end

    test "vínculo encerrado do líder não alcança mais", ctx do
      lider = pessoa(ctx, "lider")
      membro = pessoa(ctx, "membro")
      c = conta(ctx, lider)
      eq = equipe(ctx, "Delivery", ctx.org.id)
      tl = papel(ctx, "tech_leader", "Tech Leader")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, lider, eq, tl, ended_at: DateTime.utc_now(:second))
      aloca(ctx, membro, eq, dev)
      {:ok, _} = EO.declare_grant(ctx.tenant, tl.id, "team", ctx.admin.id)

      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, membro.id), """
      Quem saiu da equipe continuou liderando.

      `ended_at` preenchido é história, e não permissão. O painel da 023 mostra o vínculo
      encerrado porque ele existiu; a visibilidade lê só o vigente.
      """
    end

    test "vínculo encerrado do liderado também não é alcançado", ctx do
      lider = pessoa(ctx, "lider")
      saiu = pessoa(ctx, "saiu")
      c = conta(ctx, lider)
      eq = equipe(ctx, "Delivery", ctx.org.id)
      tl = papel(ctx, "tech_leader", "Tech Leader")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, lider, eq, tl)
      aloca(ctx, saiu, eq, dev, ended_at: DateTime.utc_now(:second))
      {:ok, _} = EO.declare_grant(ctx.tenant, tl.id, "team", ctx.admin.id)

      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, saiu.id)
    end

    test "revogar a concessão fecha o alcance de volta", ctx do
      lider = pessoa(ctx, "lider")
      membro = pessoa(ctx, "membro")
      c = conta(ctx, lider)
      eq = equipe(ctx, "Delivery", ctx.org.id)
      tl = papel(ctx, "tech_leader", "Tech Leader")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, lider, eq, tl)
      aloca(ctx, membro, eq, dev)
      {:ok, _} = EO.declare_grant(ctx.tenant, tl.id, "team", ctx.admin.id)
      assert {:ok, :lidera_a_equipe} = EO.pode_ver(ctx.tenant, c, membro.id)

      assert {:ok, 1} = EO.revoke_grant(ctx.tenant, tl.id, "team", ctx.admin.id)
      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, membro.id)
    end
  end

  describe "o responsável da organização" do
    test "alcança outra equipe da MESMA organização", ctx do
      chefe = pessoa(ctx, "chefe")
      de_outra = pessoa(ctx, "outra")
      c = conta(ctx, chefe)
      a = equipe(ctx, "Diretoria", ctx.org.id)
      b = equipe(ctx, "Delivery", ctx.org.id)
      resp = papel(ctx, "responsavel", "Responsável")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, chefe, a, resp)
      aloca(ctx, de_outra, b, dev)

      {:ok, _} = EO.declare_grant(ctx.tenant, resp.id, "organization", ctx.admin.id)

      assert {:ok, :responsavel_da_organizacao} = EO.pode_ver(ctx.tenant, c, de_outra.id)
    end

    test "NÃO alcança equipe de outra organização", ctx do
      chefe = pessoa(ctx, "chefe")
      de_fora = pessoa(ctx, "defora")
      c = conta(ctx, chefe)
      outra_org = organization_fixture(ctx.tenant, "outra-org")

      a = equipe(ctx, "Diretoria", ctx.org.id)
      b = equipe(ctx, "De fora", outra_org.id)
      resp = papel(ctx, "responsavel", "Responsável")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, chefe, a, resp)
      aloca(ctx, de_fora, b, dev)
      {:ok, _} = EO.declare_grant(ctx.tenant, resp.id, "organization", ctx.admin.id)

      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, de_fora.id), """
      O escopo `organization` atravessou para outra organização.

      O tenant tem três organizações que não compartilham vocabulário nem chefia. Responder
      pela Acme não é responder pela outra — é o mesmo defeito de escopo da issue #446.
      """
    end
  end

  describe "a cobertura, dita como lacuna" do
    test "zero concessões significa que ninguém vê além do próprio painel", ctx do
      assert %{team: 0, organization: 0} = EO.grant_coverage(ctx.tenant)

      tl = papel(ctx, "tech_leader", "Tech Leader")
      {:ok, _} = EO.declare_grant(ctx.tenant, tl.id, "team", ctx.admin.id)

      assert %{team: 1, organization: 0} = EO.grant_coverage(ctx.tenant)
    end

    test "um papel pode ter os dois escopos", ctx do
      resp = papel(ctx, "responsavel", "Responsável")
      {:ok, _} = EO.declare_grant(ctx.tenant, resp.id, "team", ctx.admin.id)
      {:ok, _} = EO.declare_grant(ctx.tenant, resp.id, "organization", ctx.admin.id)

      escopos = EO.grants_by_role(ctx.tenant) |> Map.fetch!(resp.id)

      assert Enum.sort(escopos) == ["organization", "team"], """
      Declarar o segundo escopo retirou o primeiro.

      Quem responde pela organização também lidera a própria equipe. O índice é sobre
      (papel, escopo), e não sobre o papel: os dois valem juntos.
      """
    end

    test "declarar o mesmo escopo duas vezes é recusado", ctx do
      tl = papel(ctx, "tech_leader", "Tech Leader")
      {:ok, _} = EO.declare_grant(ctx.tenant, tl.id, "team", ctx.admin.id)

      assert {:error, %Ecto.Changeset{}} =
               EO.declare_grant(ctx.tenant, tl.id, "team", ctx.admin.id)
    end

    test "escopo que a ontologia não define é recusado", ctx do
      tl = papel(ctx, "tech_leader", "Tech Leader")

      assert {:error, %Ecto.Changeset{}} =
               EO.declare_grant(ctx.tenant, tl.id, "tudo", ctx.admin.id)
    end
  end

  describe "o admin da plataforma" do
    test "vê todos os painéis, mesmo sem elo declarado", ctx do
      p = pessoa(ctx, "ana")

      # `ctx.admin` não tem elo: quem administra a plataforma não precisa ser nenhuma das
      # pessoas observadas.
      assert Tenants.person_of_user(ctx.admin) == :not_declared

      assert {:ok, :admin_da_plataforma} = EO.pode_ver(ctx.tenant, ctx.admin, p.id), """
      O admin não alcançou o painel.

      Decisão da pessoa mantenedora em 2026-08-27: admin vê tudo. É o `users.role` — quem
      conecta ferramenta e gerencia credencial —, e ele passa mesmo sem elo.
      """
    end

    test "o motivo mais específico prevalece sobre `admin`", ctx do
      p = pessoa(ctx, "ana")
      {:ok, _} = Tenants.declare_person(ctx.tenant, ctx.admin.id, p.id, ctx.admin.id)
      {:ok, admin} = Tenants.fetch_user(ctx.admin.id)

      assert {:ok, :propria_pessoa} = EO.pode_ver(ctx.tenant, admin, p.id), """
      O motivo veio como `admin` para quem é a própria pessoa.

      Seria verdade e resposta errada: a tela mostraria "você vê porque administra a
      plataforma" a quem está olhando o próprio painel.
      """
    end

    test "o admin de OUTRO tenant não alcança pessoa daqui", ctx do
      p = pessoa(ctx, "ana")
      outro = tenant_fixture()
      admin_deles = user_fixture(outro)

      assert {:nao, :conta_sem_pessoa_declarada} = EO.pode_ver(outro, admin_deles, p.id), """
      Um admin de outro tenant alcançou uma pessoa daqui.

      Os outros ramos conferem o tenant por tabela — as consultas de equipe e organização
      filtram, e `person_of_user/1` também. O ramo do admin curto-circuita antes de
      qualquer consulta, e sem a conferência explícita ele passa.

      A tela nunca chega aí, porque `fetch_person/2` recusa antes. Mas uma função que
      decide acesso não pode depender de quem a chama ter conferido.
      """
    end
  end

  describe "a fronteira do tenant" do
    test "a concessão de outro tenant não alcança nada daqui", ctx do
      lider = pessoa(ctx, "lider")
      membro = pessoa(ctx, "membro")
      c = conta(ctx, lider)
      eq = equipe(ctx, "Delivery", ctx.org.id)
      tl = papel(ctx, "tech_leader", "Tech Leader")
      dev = papel(ctx, "developer_role", "Developer Role")

      aloca(ctx, lider, eq, tl)
      aloca(ctx, membro, eq, dev)

      outro = tenant_fixture()
      admin2 = user_fixture(outro)
      org2 = organization_fixture(outro, "deles")

      {:ok, tl2} =
        EO.create_role(outro, org2.id, %{code: "tech_leader", name: "Tech Leader"}, admin2.id)

      {:ok, _} = EO.declare_grant(outro, tl2.id, "team", admin2.id)

      assert {:nao, :sem_alcance_declarado} = EO.pode_ver(ctx.tenant, c, membro.id), """
      Uma concessão declarada em outro tenant abriu o painel aqui.

      Consulta sem filtro de tenant é bug de segurança — princípio V —, e aqui o que vaza é
      acesso a painel.
      """

      assert %{team: 0} = EO.grant_coverage(ctx.tenant)
    end
  end
end
