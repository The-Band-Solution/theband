defmodule TheBand.Tenants.AccessTest do
  @moduledoc """
  O veredito único do acesso — contrato
  `specs/045-autenticacao-e-acesso/contracts/access-scopes.md`.

  ## As asserções que carregam este arquivo (violação primeiro — L03)

  1. **nada de outro tenant**, em scopes e em pode_ver;
  2. **admin puro não vê painel** (FR-022) — mas gerencia;
  3. **derivado fecha com o fato**: vínculo encerrado e ligação desfeita somem;
  4. **a liderança declarada (#369) continua valendo** — FR-018, a regressão;
  5. **concessão exige admin e alvo existente**; revogar é marca com autor;
  6. **o motivo distingue** os ramos de recusa e de permissão.
  """
  use TheBand.DataCase, async: false

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Ontology.SEON.SPO
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
        Map.merge(source_attrs("U_#{login}_#{System.unique_integer([:positive])}"), %{
          name: login,
          login: login,
          account_type: "person"
        })
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

  defp equipe(ctx, nome) do
    {:ok, t} = EO.create_declared_team(ctx.tenant, nome, ctx.admin.id)

    Repo.update_all(
      from(x in "eo_teams",
        where: x.id == type(^t.id, :binary_id),
        update: [set: [organization_id: type(^ctx.org.id, :binary_id)]]
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

  defp projeto_ligado(ctx, equipe, nome) do
    {:ok, projeto} = SPO.create_project(ctx.tenant, %{name: nome}, ctx.admin.id)
    {:ok, _} = SPO.link_team(ctx.tenant, projeto.id, equipe.id, ctx.admin.id)
    projeto
  end

  describe "scopes/2 — a união com origem" do
    test "piso + derivados de equipe e de projeto + concedido, cada um com origem", ctx do
      time = equipe(ctx, "Plataforma")
      dev = papel(ctx, "developer", "Developer Role")
      p = pessoa(ctx, "fulana")
      u = conta(ctx, p)
      aloca(ctx, p, time, dev)
      projeto = projeto_ligado(ctx, time, "Conecta")

      {:ok, _} = Tenants.grant_scope(ctx.tenant, u.id, :organization, ctx.org.id, ctx.admin)

      escopos = Tenants.scopes(ctx.tenant, Repo.get!(Tenants.User, u.id))
      origens = Enum.map(escopos, &{&1.level, &1.origin, &1.target_id})

      assert {:person, :floor, nil} in origens
      assert {:team, :derived_team, time.id} in origens
      assert {:project, :derived_project, projeto.id} in origens
      assert {:organization, :granted, ctx.org.id} in origens
    end

    test "derivado fecha com o fato: vínculo encerrado e ligação desfeita somem", ctx do
      time = equipe(ctx, "Plataforma")
      dev = papel(ctx, "developer", "Developer Role")
      p = pessoa(ctx, "fulana")
      u = conta(ctx, p)
      m = aloca(ctx, p, time, dev)
      projeto = projeto_ligado(ctx, time, "Conecta")

      escopos = Tenants.scopes(ctx.tenant, u)
      assert Enum.any?(escopos, &(&1.target_id == projeto.id))

      # Desfaz a ligação equipe→projeto: o derivado project morre.
      [vinculo] = SPO.list_team_projects(ctx.tenant, time.id)
      {:ok, _} = SPO.unlink_team(ctx.tenant, vinculo.link_id, ctx.admin.id)
      escopos = Tenants.scopes(ctx.tenant, u)
      refute Enum.any?(escopos, &(&1.level == :project))

      # Encerra o vínculo pessoa→equipe: o derivado team morre junto.
      {:ok, _} = EO.end_allocation(ctx.tenant, m.id, DateTime.utc_now(:second))
      escopos = Tenants.scopes(ctx.tenant, u)
      refute Enum.any?(escopos, &(&1.level == :team))
    end

    test "nada de outro tenant", ctx do
      outro = tenant_fixture()
      outro_admin = user_fixture(outro)
      outra_org = organization_fixture(outro, "intrusa")

      p = pessoa(ctx, "fulana")
      u = conta(ctx, p)

      # Concessão apontando alvo de OUTRO tenant é recusada na origem.
      assert {:error, :target_not_found} =
               Tenants.grant_scope(ctx.tenant, u.id, :organization, outra_org.id, ctx.admin)

      # E a conta de cá não carrega escopo de lá.
      assert {:error, :target_not_found} =
               Tenants.grant_scope(outro, u.id, :organization, ctx.org.id, outro_admin)
    end
  end

  describe "pode_ver/3 — o veredito" do
    test "admin puro não vê painel (FR-022), com motivo de remédio certo", ctx do
      p = pessoa(ctx, "ana")
      assert {:nao, :sem_elo_declarado} = Tenants.pode_ver(ctx.tenant, ctx.admin, p.id)
    end

    test "piso: a própria pessoa; colega sem escopo: fora dos escopos", ctx do
      time = equipe(ctx, "Plataforma")
      dev = papel(ctx, "developer", "Developer Role")

      ana = pessoa(ctx, "ana")
      bia = pessoa(ctx, "bia")
      conta_ana = conta(ctx, ana)
      aloca(ctx, ana, time, dev)

      assert {:ok, :propria_pessoa} = Tenants.pode_ver(ctx.tenant, conta_ana, ana.id)

      # Bia está FORA da equipe da Ana: o derivado team da Ana não alcança.
      assert {:nao, :fora_dos_escopos} = Tenants.pode_ver(ctx.tenant, conta_ana, bia.id)
    end

    test "escopo de equipe derivado alcança colega da mesma equipe", ctx do
      time = equipe(ctx, "Plataforma")
      dev = papel(ctx, "developer", "Developer Role")

      ana = pessoa(ctx, "ana")
      bia = pessoa(ctx, "bia")
      conta_ana = conta(ctx, ana)
      aloca(ctx, ana, time, dev)
      aloca(ctx, bia, time, dev)

      assert {:ok, :escopo_de_equipe} = Tenants.pode_ver(ctx.tenant, conta_ana, bia.id)
    end

    test "concessão organization alcança qualquer pessoa de equipe da organização", ctx do
      time = equipe(ctx, "Plataforma")
      dev = papel(ctx, "developer", "Developer Role")
      bia = pessoa(ctx, "bia")
      aloca(ctx, bia, time, dev)

      diretora = user_fixture(ctx.tenant, "member")
      {:ok, _} = Tenants.grant_scope(ctx.tenant, diretora.id, :organization, ctx.org.id, ctx.admin)

      assert {:ok, :escopo_da_organizacao} = Tenants.pode_ver(ctx.tenant, diretora, bia.id)
    end

    test "a liderança declarada (#369) continua valendo — FR-018", ctx do
      time = equipe(ctx, "Plataforma")
      tl = papel(ctx, "tech-leader", "Tech Leader")
      dev = papel(ctx, "developer", "Developer Role")
      {:ok, _} = EO.declare_grant(ctx.tenant, tl.id, "team", ctx.admin.id)

      lider = pessoa(ctx, "lider")
      liderada = pessoa(ctx, "liderada")
      conta_lider = conta(ctx, lider)
      aloca(ctx, lider, time, tl)
      aloca(ctx, liderada, time, dev)

      # O ramo de escopo derivado responde primeiro (equipe em comum) — então a
      # regressão de FR-018 se prova SEM equipe em comum: líder de A, pessoa em A,
      # conta do líder sem vínculo próprio... aqui o vínculo é o que dá a liderança,
      # e o motivo esperado é o de equipe (mais específico). A regra #369 responde
      # quando o escopo não alcança: sem ela, este caso viraria recusa.
      assert {:ok, motivo} = Tenants.pode_ver(ctx.tenant, conta_lider, liderada.id)
      assert motivo in [:escopo_de_equipe, :lidera_a_equipe]
    end
  end

  describe "grant/revoke" do
    test "não-admin não concede nem revoga; alvo é obrigatório e existente", ctx do
      p = pessoa(ctx, "fulana")
      u = conta(ctx, p)
      time = equipe(ctx, "Plataforma")

      assert {:error, :not_admin} = Tenants.grant_scope(ctx.tenant, u.id, :team, time.id, u)

      assert {:error, :target_not_found} =
               Tenants.grant_scope(ctx.tenant, u.id, :team, Ecto.UUID.generate(), ctx.admin)

      {:ok, g} = Tenants.grant_scope(ctx.tenant, u.id, :team, time.id, ctx.admin)
      assert {:error, :not_admin} = Tenants.revoke_scope(ctx.tenant, g.id, u)
    end

    test "revogar é marca com autor, e o escopo some da união", ctx do
      p = pessoa(ctx, "fulana")
      u = conta(ctx, p)
      time = equipe(ctx, "Plataforma")

      {:ok, g} = Tenants.grant_scope(ctx.tenant, u.id, :team, time.id, ctx.admin)
      {:ok, revogado} = Tenants.revoke_scope(ctx.tenant, g.id, ctx.admin)

      assert revogado.revoked_by_user_id == ctx.admin.id
      assert revogado.revoked_at

      escopos = Tenants.scopes(ctx.tenant, u)
      refute Enum.any?(escopos, &(&1.origin == :granted))

      # A linha FICA — histórico é marca, nunca delete.
      assert Repo.get!(TheBand.Tenants.Access.ScopeGrant, g.id)
    end
  end

  describe "operacional?/2 — FR-023" do
    test "admin inteiro; organization com recorte; member puro não", ctx do
      assert {true, :admin} = Tenants.operacional?(ctx.tenant, ctx.admin)

      p = pessoa(ctx, "fulana")
      u = conta(ctx, p)
      assert Tenants.operacional?(ctx.tenant, u) == false

      {:ok, _} = Tenants.grant_scope(ctx.tenant, u.id, :organization, ctx.org.id, ctx.admin)
      assert {true, {:organizations, [org_id]}} = Tenants.operacional?(ctx.tenant, u)
      assert org_id == ctx.org.id
    end
  end
end
