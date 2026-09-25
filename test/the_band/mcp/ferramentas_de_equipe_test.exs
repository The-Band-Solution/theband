defmodule TheBand.MCP.FerramentasDeEquipeTest do
  @moduledoc """
  As quatro ferramentas, com dado de verdade — feature 062, T010 a T013, e o SC-001.

  Cada ferramenta é chamada **pelo caminho único** (`Ferramentas.chamar/4`), e não direto: é
  assim que um agente a alcança, e é o caminho que carrega a equipe e aplica o veredito.

  A equipe tem duas pessoas: `ana`, com duas tarefas abertas (uma parada, uma recente) e três
  solicitações de mudança (uma revisada em uma hora, duas esperando), e `beto`, sem nada. É o
  mínimo que faz cada ressalva da feature aparecer:

  - T011: `beto` **não** aparece em `by_person`, e `totals.members` o conta;
  - T012: as duas medianas saem **separadas**, e divergem: horas contra dias;
  - T013: a parada de um repositório sem comentário coletado é `not_collected`, e não
    `silence`.
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import TheBand.WorkItemsFixtures, only: [cenario_real: 1]
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.MCP.Ferramentas
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.Quality.Commands, as: QualityCommands
  alias TheBand.Repo
  alias TheBand.WorkItems.Schemas.{CollectedIssue, IssueAssignee}

  setup do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    org = cenario.organization
    {:ok, papel} = EO.create_role(tenant, org.id, %{code: "dev", name: "Dev"}, admin.id)
    {:ok, equipe} = EO.declare_structural_team(tenant, org.id, "Dados", admin.id)

    ctx = %{tenant: tenant, admin: admin, equipe: equipe, repo_id: cenario.observed_repository_id}

    ana = pessoa(ctx, "ana")
    beto = pessoa(ctx, "beto")
    for p <- [ana, beto], do: vincular(ctx, p, papel)

    parada = issue(ctx, "I_parada", ana, dias(-120))
    recente = issue(ctx, "I_recente", ana, dias(-5))

    revisada = solicitacao(ctx, 1, ana, dias(-10))
    avaliacao(ctx, revisada, DateTime.add(revisada.external_created_at, 3600, :second))
    solicitacao(ctx, 2, ana, dias(-20))
    solicitacao(ctx, 3, ana, dias(-30))

    Map.merge(ctx, %{ana: ana, beto: beto, parada: parada, recente: recente})
  end

  defp chamar(ctx, nome),
    do:
      Ferramentas.chamar(ctx.tenant, ctx.admin, nome, %{"team_id" => ctx.equipe.id}, %{
        token_public_id: "tb_teste"
      })

  describe "T010 — team_roster" do
    test "as duas pessoas, com a origem no vínculo, e os três números sem total", ctx do
      r = chamar(ctx, "team_roster")

      assert r.state == "checked"
      assert r.value.people |> Enum.map(& &1.login) |> Enum.sort() == ["ana", "beto"]

      for p <- r.value.people, v <- p.memberships do
        assert v.origin in ["observed", "declared"], "origin fora da casa: #{inspect(v.origin)}"
      end

      assert r.value.totals == %{current: 2, left: 0, mistakes: 0}
      refute Map.has_key?(r.value.totals, :total)
      assert r.value.truncated == false
    end
  end

  describe "T011 — team_open_work" do
    test "quem não tem tarefa aberta não vira linha com zero, e é contado nos membros", ctx do
      r = chamar(ctx, "team_open_work")

      pessoas = Enum.map(r.value.by_person, & &1.person_id)
      assert ctx.ana.id in pessoas
      refute ctx.beto.id in pessoas, "beto não tem tarefa aberta, e apareceu com uma linha"

      assert r.value.totals.members == 2, "beto tem de ser contado nos membros"
      assert r.value.totals.open == 2
    end

    test "cada tarefa traz a idade em dias e a marca de parada", ctx do
      [%{tasks: tarefas}] = chamar(ctx, "team_open_work").value.by_person
      por_id = Map.new(tarefas, &{&1.issue_id, &1})

      assert por_id[ctx.parada.id].stale == true
      assert por_id[ctx.parada.id].open_for_days >= 119
      assert por_id[ctx.recente.id].stale == false
    end
  end

  describe "T012 — team_review_wait" do
    test "as duas leituras saem separadas, e divergem: horas contra dias", ctx do
      r = chamar(ctx, "team_review_wait")

      assert r.value.reviewed.count == 1
      assert_in_delta r.value.reviewed.median_hours, 1.0, 0.01
      assert r.value.waiting.count == 2
      assert r.value.waiting.median_days >= 20

      refute Map.has_key?(r.value, :median),
             "uma mediana só diria o que a feature existe para não dizer"

      assert r.window.days == 56
      assert r.origin == "derived"
      assert r.measurement_id == "review.time_to_first_review.duration"
    end
  end

  describe "T013 — team_stale_work" do
    test "o corte em dias viaja junto, e a regra traz a versão", ctx do
      r = chamar(ctx, "team_stale_work")

      assert r.value.stale == 1
      assert r.value.open == 2
      assert r.value.stale_after_days == 90
      assert r.rule == %{id: "profile.thresholds", version: 1}
    end

    test "repositório sem coleta de comentários dá not_collected, e não silence", ctx do
      [item] = chamar(ctx, "team_stale_work").value.items

      assert item.issue_id == ctx.parada.id
      assert item.conversation == "not_collected"
      assert item.acts == 0

      # A guarda: coletados os comentários, e sem ato nenhum, o mesmo item é silêncio.
      Repo.update_all(
        from(o in "observed_repositories", where: o.id == type(^ctx.repo_id, :binary_id)),
        set: [comments_collected_at: DateTime.utc_now(:second)]
      )

      [depois] = chamar(ctx, "team_stale_work").value.items
      assert depois.conversation == "silence"
    end
  end

  describe "SC-001 — toda ferramenta registrada devolve o envelope inteiro" do
    test "os nove campos, e as ressalvas lidas da base", ctx do
      campos = ~w(value composition window origin rule measurement_id limitations
                 misinterpretations collected_at)a

      respostas = for f <- Ferramentas.listar(), do: {f.nome, chamar(ctx, f.nome)}

      for {nome, r} <- respostas do
        assert r.state == "checked", "#{nome} não respondeu"

        for campo <- campos do
          assert Map.has_key?(r, campo), "#{nome} não traz #{campo}"
        end

        assert [_ | _] = r.limitations, "#{nome} saiu sem limitations"
      end

      # Guarda contra o teste que passa sem ler a base: ao menos uma traz interpretações
      # erradas declaradas, e elas são as da base.
      com_interpretacoes =
        for {nome, r} <- respostas, r.misinterpretations != [], do: {nome, r}

      assert com_interpretacoes != [], "nenhuma ferramenta trouxe misinterpretations"

      for {_nome, r} <- com_interpretacoes do
        {:ok, medida} = KnowledgeBase.measurement(r.measurement_id)
        assert r.misinterpretations == medida["misinterpretations"]
      end
    end
  end

  # ------------------------------------------------------------------ o cenário

  defp dias(n), do: DateTime.utc_now(:second) |> DateTime.add(n, :day)

  defp pessoa(ctx, login) do
    {:ok, p} =
      EO.upsert_person_from_source(ctx.tenant, %{
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

  defp vincular(ctx, pessoa, papel) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: ctx.equipe.id,
        organizational_role_id: papel.id,
        declared_by_user_id: ctx.admin.id,
        started_at: dias(-365)
      })
  end

  defp issue(ctx, externo, designada, criada) do
    {:ok, i} =
      Repo.insert(%CollectedIssue{
        tenant_id: ctx.tenant.id,
        observed_repository_id: ctx.repo_id,
        external_id: externo,
        number: :erlang.phash2(externo, 100_000),
        source_system: "github",
        source_instance: "https://github.com",
        title: "issue #{externo}",
        state: "OPEN",
        external_created_at: criada,
        collected_at: DateTime.utc_now(:second)
      })

    Repo.insert!(%IssueAssignee{
      tenant_id: ctx.tenant.id,
      collected_issue_id: i.id,
      login: designada.login,
      person_id: designada.id
    })

    i
  end

  defp solicitacao(ctx, numero, autor, aberta_em) do
    {:ok, pr} =
      ChangeCommands.record_change_request(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        number: numero,
        title: "solicitação #{numero}",
        state: "OPEN",
        external_created_at: aberta_em,
        author_login: autor.login,
        author_person_id: autor.id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_#{numero}"
      })

    pr
  end

  defp avaliacao(ctx, pr, quando) do
    {:ok, _} =
      QualityCommands.record_evaluation(ctx.tenant, %{
        collected_change_request_id: pr.id,
        state: "APPROVED",
        author_login: "revisora",
        author_type: "User",
        external_submitted_at: quando,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PRR_#{System.unique_integer([:positive])}"
      })
  end
end
