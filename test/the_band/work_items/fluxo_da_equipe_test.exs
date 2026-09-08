defmodule TheBand.WorkItems.FluxoDaEquipeTest do
  @moduledoc """
  O fluxo da equipe nas três granulações — feature 060, US9: FR-061, FR-062 e FR-078.

  ## A asserção que carrega este arquivo

  **Reagrupar não muda o que se mediu.** FR-061 diz: trocar a granulação **mantendo a janela**
  reagrupa os mesmos itens, e a soma de abertos e a de fechados na janela é **igual** nas
  três. É a propriedade que separa um seletor de granulação de um seletor de medida — e a que
  falha em silêncio, porque um gráfico por mês com números errados continua parecendo um
  gráfico por mês.

  A propriedade é da AGREGAÇÃO, e é por isso que se prova aqui e não na tela. A tela oferece
  janela padrão **por** granulação (FR-078: 8 semanas, 12 meses, todos os anos coletados), e
  janelas diferentes têm somas diferentes de propósito. Provar a igualdade sobre a mesma
  janela é o que garante que a diferença, quando aparece, veio da janela e não da conta.

  ## O que este arquivo NÃO cobre

  A tela. A janela no título, o seletor no endereço e a definição de *prometido* junto do
  título são de `test/the_band_web/live/`. Aqui é só a medida.
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

    ana = pessoa(tenant, "ana-#{System.unique_integer([:positive])}")

    {:ok, _} =
      EO.allocate(tenant, %{
        person_id: ana.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        declared_by_user_id: admin.id,
        started_at: dias(-900)
      })

    %{tenant: tenant, equipe: equipe, ana: ana, repo_id: cenario.observed_repository_id}
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

  defp issue(ctx, externo, opts) do
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

    Repo.insert!(%IssueAssignee{
      tenant_id: ctx.tenant.id,
      collected_issue_id: i.id,
      login: ctx.ana.login,
      person_id: ctx.ana.id
    })

    i
  end

  defp dias(n), do: DateTime.utc_now(:second) |> DateTime.add(n, :day)

  defp somas(serie) do
    %{
      criadas: Enum.sum(Enum.map(serie, & &1.criadas)),
      fechadas: Enum.sum(Enum.map(serie, & &1.fechadas))
    }
  end

  describe "reagrupar a mesma janela não muda a medida (FR-061)" do
    test "a soma de abertos e de fechados é igual em semana, mês e ano", ctx do
      # Uma janela de dois anos, com itens espalhados por meses e anos diferentes — para que
      # as três granulações produzam números de PERÍODOS bem diferentes e, ainda assim, as
      # mesmas somas.
      issue(ctx, "a", criada: dias(-700), fechada: dias(-690))
      issue(ctx, "b", criada: dias(-400), fechada: dias(-380))
      issue(ctx, "c", criada: dias(-200), fechada: dias(-100))
      issue(ctx, "d", criada: dias(-40), fechada: dias(-10))
      issue(ctx, "e", criada: dias(-20), fechada: nil)
      issue(ctx, "f", criada: dias(-5), fechada: nil)

      # A MESMA janela nas três. É a condição da FR-061 — "mantendo a janela".
      opts = [desde: dias(-730), ate: dias(0)]

      por_semana =
        WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :semana, opts)

      por_mes = WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :mes, opts)
      por_ano = WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :ano, opts)

      assert somas(por_semana) == %{criadas: 6, fechadas: 4},
             "a série semanal não achou os seis itens da janela"

      assert somas(por_mes) == somas(por_semana),
             "agrupar por mês mudou a MEDIDA, e não só o agrupamento"

      assert somas(por_ano) == somas(por_semana),
             "agrupar por ano mudou a MEDIDA, e não só o agrupamento"
    end

    test "o número de períodos muda, e é isso que a granulação faz", ctx do
      issue(ctx, "a", criada: dias(-400), fechada: dias(-390))
      issue(ctx, "b", criada: dias(-10), fechada: dias(-5))

      opts = [desde: dias(-730), ate: dias(0)]

      semanas = WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :semana, opts)
      meses = WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :mes, opts)
      anos = WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :ano, opts)

      # Sem esta asserção o teste acima passaria com uma implementação que ignorasse a
      # granulação por completo e devolvesse sempre a série semanal.
      assert length(semanas) > length(meses), "semana e mês devolveram a mesma quantidade"
      assert length(meses) > length(anos), "mês e ano devolveram a mesma quantidade"
      assert length(anos) in [2, 3], "dois anos de janela dão dois ou três anos-calendário"
    end

    test "período vazio DENTRO da janela aparece com zero, e não é omitido", ctx do
      # Um item só, há muito tempo: os meses do meio não têm nada.
      issue(ctx, "a", criada: dias(-700), fechada: dias(-690))

      serie =
        WorkItems.team_state_changes_by_period(ctx.tenant, ctx.equipe.id, :mes,
          desde: dias(-730),
          ate: dias(0)
        )

      vazios = Enum.filter(serie, &(&1.criadas == 0 and &1.fechadas == 0))

      assert length(vazios) > 20, """
      Mês sem trabalho tem de aparecer com zero. Omiti-lo faria o gráfico encostar dois
      períodos distantes um no outro, e a leitura seria de continuidade onde houve pausa.
      """

      assert somas(serie).criadas == 1
    end
  end

  describe "a janela padrão da granulação ano precisa do banco (FR-078)" do
    test "primeira_atividade devolve a abertura mais antiga da equipe", ctx do
      issue(ctx, "velha", criada: dias(-700), fechada: dias(-690))
      issue(ctx, "nova", criada: dias(-10), fechada: nil)

      primeira = WorkItems.team_first_activity(ctx.tenant, ctx.equipe.id)

      refute is_nil(primeira)

      assert DateTime.diff(primeira, dias(-700), :day) == 0,
             "a janela de 'todos os anos coletados' partiria da data errada"
    end

    test "equipe sem item nenhum devolve nil, que é diferente de hoje", ctx do
      assert WorkItems.team_first_activity(ctx.tenant, ctx.equipe.id) == nil, """
      `nil` é a resposta certa, e a tela a distingue de uma data: sem item coletado não há
      janela a mostrar, e devolver hoje faria a tela desenhar um eixo de um dia como se fosse
      o histórico da equipe.
      """
    end

    test "não atravessa a fronteira do tenant", ctx do
      issue(ctx, "minha", criada: dias(-100), fechada: nil)

      {vizinho, admin_vizinho} = tenant_with_admin()
      {:ok, equipe_vizinha} = EO.create_declared_team(vizinho, "Plataforma", admin_vizinho.id)

      assert WorkItems.team_first_activity(vizinho, equipe_vizinha.id) == nil

      assert WorkItems.team_first_activity(ctx.tenant, equipe_vizinha.id) == nil,
             "o id de outro tenant devolveu dado deste"
    end
  end
end
