defmodule TheBand.WorkItems.TeamWorkTest do
  @moduledoc """
  O trabalho da equipe, recortado pelo vínculo — feature 057, US2/US3/US5.

  As asserções que carregam este arquivo:

  1. **FR-002/SC-002**: a vigência é avaliada contra a data DO EVENTO, e não
     contra hoje — registrar uma saída não muda nenhuma semana anterior a ela;
  2. **FR-008/R4**: `DISTINCT` na issue — item de dois responsáveis da mesma
     equipe conta UMA vez para a equipe, e duas nas linhas por pessoa;
  3. **FR-026a**: a linha de base existe, e sem ela o burn mediria menos
     trabalho aberto do que existe;
  4. **FR-021**: pessoa sem tarefa vem com lista vazia, nunca ausente do mapa;
  5. **FR-016**: período vazio dentro da janela aparece com zero; fora dela, não
     aparece;
  6. **SC-011**: nada atravessa a fronteira do tenant.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Ontology.SEON.EO
  alias TheBand.Repo
  alias TheBand.WorkItems
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  setup do
    {tenant, admin} = tenant_with_admin()
    {:ok, equipe} = EO.create_declared_team(tenant, "Plataforma", admin.id)
    cenario = cenario_real(tenant)

    {:ok, papel} =
      EO.create_role(tenant, cenario.organization.id, %{code: "dev", name: "Dev"}, admin.id)

    %{
      tenant: tenant,
      admin: admin,
      equipe: equipe,
      org: cenario.organization,
      papel: papel,
      repo_id: cenario.observed_repository_id
    }
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: login,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => login}
      })

    p
  end

  defp vincular(ctx, pessoa, opts) do
    {:ok, v} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: ctx.equipe.id,
        organizational_role_id: ctx.papel.id,
        started_at: opts[:desde],
        ended_at: opts[:ate]
      })

    v
  end

  # Grava a issue direto: o caminho de coleta exige payload completo e o que
  # importa aqui são as duas datas e a designação.
  defp issue(ctx, externo, designados, opts) do
    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 100_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "issue #{externo}",
        state: if(opts[:fechada], do: "CLOSED", else: "OPEN"),
        external_created_at: opts[:criada],
        external_closed_at: opts[:fechada],
        collected_at: DateTime.utc_now(:second)
      })

    for d <- designados do
      Repo.insert!(%IssueAssignee{
        tenant_id: ctx.tenant.id,
        collected_issue_id: i.id,
        login: d.login,
        person_id: d.id
      })
    end

    i
  end

  defp dias(n), do: DateTime.utc_now(:second) |> DateTime.add(n, :day)

  describe "a vigência é avaliada contra a data do evento" do
    test "SC-002: registrar uma saída hoje não muda nenhuma semana anterior", ctx do
      ana = pessoa(ctx.tenant, "ana")
      vincular(ctx, ana, desde: dias(-200))
      issue(ctx, "1", [ana], criada: dias(-40), fechada: dias(-35))
      issue(ctx, "2", [ana], criada: dias(-20), fechada: dias(-15))

      opts = [desde: dias(-56), ate: dias(0)]
      antes = WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :semana, opts)

      {:ok, _} =
        EO.record_team_departure(
          ctx.tenant,
          ctx.equipe.id,
          ana.id,
          DateTime.utc_now(:second),
          ctx.admin.id
        )

      depois = WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :semana, opts)

      assert antes == depois,
             "a saída de hoje reescreveu semanas passadas — a vigência está sendo avaliada contra hoje, e não contra a data do evento"
    end

    test "FR-002: o que a pessoa fez depois de sair não conta para a equipe", ctx do
      ana = pessoa(ctx.tenant, "ana")
      vincular(ctx, ana, desde: dias(-200), ate: dias(-30))

      issue(ctx, "dentro", [ana], criada: dias(-50), fechada: dias(-45))
      issue(ctx, "fora", [ana], criada: dias(-20), fechada: dias(-10))

      serie =
        WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :semana,
          desde: dias(-56),
          ate: dias(0)
        )

      assert Enum.sum(Enum.map(serie, & &1.criadas)) == 1
      assert Enum.sum(Enum.map(serie, & &1.fechadas)) == 1
    end

    test "FR-006a: vínculo sem data de início conta, e não some em silêncio", ctx do
      ana = pessoa(ctx.tenant, "ana")
      vincular(ctx, ana, desde: nil)
      issue(ctx, "1", [ana], criada: dias(-10), fechada: dias(-5))

      serie =
        WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :semana,
          desde: dias(-56),
          ate: dias(0)
        )

      assert Enum.sum(Enum.map(serie, & &1.criadas)) == 1
    end
  end

  describe "a equipe conta uma vez o que a pessoa conta duas" do
    test "FR-008/R4: item de dois responsáveis da mesma equipe é UM item da equipe", ctx do
      ana = pessoa(ctx.tenant, "ana")
      bia = pessoa(ctx.tenant, "bia")
      vincular(ctx, ana, desde: dias(-200))
      vincular(ctx, bia, desde: dias(-200))

      issue(ctx, "compartilhada", [ana, bia], criada: dias(-10), fechada: nil)

      serie =
        WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :semana,
          desde: dias(-56),
          ate: dias(0)
        )

      assert Enum.sum(Enum.map(serie, & &1.criadas)) == 1,
             "sem DISTINCT a equipe contaria a mesma issue uma vez por responsável"

      por_pessoa = WorkItems.team_open_tasks_by_person(ctx.tenant, ctx.equipe.id, dias(0))

      assert por_pessoa |> Map.values() |> List.flatten() |> length() == 2,
             "por pessoa a mesma issue aparece para cada uma — de propósito, e é por isso que as linhas não somam"

      assert WorkItems.team_open_at(ctx.tenant, ctx.equipe.id, dias(0)) == 1
    end
  end

  describe "a linha de base do burn" do
    test "FR-026a: itens abertos antes da janela entram na contagem de aberto", ctx do
      ana = pessoa(ctx.tenant, "ana")
      vincular(ctx, ana, desde: dias(-400))

      for n <- 1..12, do: issue(ctx, "velha#{n}", [ana], criada: dias(-300), fechada: nil)

      inicio = dias(-56)

      assert WorkItems.team_open_at(ctx.tenant, ctx.equipe.id, inicio) == 12,
             "sem a linha de base o burn partiria de zero e o gráfico afirmaria menos trabalho aberto do que existe"
    end

    test "item já fechado antes da janela não entra na linha de base", ctx do
      ana = pessoa(ctx.tenant, "ana")
      vincular(ctx, ana, desde: dias(-400))
      issue(ctx, "fechada", [ana], criada: dias(-300), fechada: dias(-200))

      assert WorkItems.team_open_at(ctx.tenant, ctx.equipe.id, dias(-56)) == 0
    end
  end

  describe "ausência é nomeada" do
    test "FR-021: pessoa sem tarefa vem com lista vazia, nunca ausente do mapa", ctx do
      ana = pessoa(ctx.tenant, "ana")
      bia = pessoa(ctx.tenant, "bia")
      vincular(ctx, ana, desde: dias(-200))
      vincular(ctx, bia, desde: dias(-200))
      issue(ctx, "1", [ana], criada: dias(-10), fechada: nil)

      mapa = WorkItems.team_open_tasks_by_person(ctx.tenant, ctx.equipe.id, dias(0))

      assert Map.has_key?(mapa, bia.id), "chave ausente diria que a pessoa não é da equipe"
      assert mapa[bia.id] == []
      assert length(mapa[ana.id]) == 1
    end

    test "FR-020: a marca de parada olha a abertura do item, não a atribuição", ctx do
      ana = pessoa(ctx.tenant, "ana")
      vincular(ctx, ana, desde: dias(-200))
      issue(ctx, "velha", [ana], criada: dias(-91), fechada: nil)
      issue(ctx, "nova", [ana], criada: dias(-89), fechada: nil)

      tarefas = WorkItems.team_open_tasks_by_person(ctx.tenant, ctx.equipe.id, dias(0))[ana.id]
      por_id = Map.new(tarefas, &{&1.external_id, &1})

      assert por_id["velha"].parada?
      refute por_id["nova"].parada?
    end

    test "FR-016: período vazio dentro da janela aparece com zero", ctx do
      ana = pessoa(ctx.tenant, "ana")
      vincular(ctx, ana, desde: dias(-200))
      issue(ctx, "1", [ana], criada: dias(-3), fechada: nil)

      serie =
        WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :semana,
          desde: dias(-56),
          ate: dias(0)
        )

      assert length(serie) >= 8, "as semanas vazias da janela precisam aparecer"
      assert Enum.any?(serie, &(&1.criadas == 0 and &1.fechadas == 0))
    end
  end

  describe "a linha da subequipe" do
    test "FR-012: sem trabalho é dito, e não é zero", ctx do
      ana = pessoa(ctx.tenant, "ana")
      vincular(ctx, ana, desde: dias(-200))

      vazia = WorkItems.team_snapshot(ctx.tenant, ctx.equipe.id, dias(0), [])
      assert vazia.sem_trabalho?
      assert vazia.membros == 1

      issue(ctx, "1", [ana], criada: dias(-10), fechada: nil)
      com = WorkItems.team_snapshot(ctx.tenant, ctx.equipe.id, dias(0), [])
      refute com.sem_trabalho?
      assert com.abertas == 1
    end

    test "FR-008: a linha não tem campo de total", ctx do
      linha = WorkItems.team_snapshot(ctx.tenant, ctx.equipe.id, dias(0), [])

      refute Map.has_key?(linha, :total)
      refute Map.has_key?(linha, :soma)
    end
  end

  describe "isolamento entre tenants" do
    test "SC-011: nenhuma consulta devolve dado do outro tenant", ctx do
      ana = pessoa(ctx.tenant, "ana")
      vincular(ctx, ana, desde: dias(-200))
      issue(ctx, "minha", [ana], criada: dias(-10), fechada: nil)

      {outro, outro_admin} = tenant_with_admin()
      {:ok, outra_equipe} = EO.create_declared_team(outro, "Plataforma", outro_admin.id)

      assert WorkItems.team_open_at(outro, outra_equipe.id, dias(0)) == 0
      assert WorkItems.team_open_tasks_by_person(outro, outra_equipe.id, dias(0)) == %{}

      serie =
        WorkItems.team_state_changes_by_period(outro, outra_equipe.id, :semana,
          desde: dias(-56),
          ate: dias(0)
        )

      assert Enum.sum(Enum.map(serie, & &1.criadas)) == 0
    end
  end
end
