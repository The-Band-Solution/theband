defmodule TheBand.QualityTest do
  @moduledoc """
  As avaliações de artefato — feature 039, issue #440.

  ## As asserções que carregam este arquivo

  1. **bot nunca é somado a pessoa**, e o motivo é a medida: se a primeira "revisão" foi um
     robô, o tempo até a primeira revisão humana continua correndo;
  2. **rascunho não conta como revisão** — vem sem `submittedAt`, existe, e a medida o
     exclui;
  3. o tempo até a primeira revisão é o `min` das **humanas submetidas**, e solicitação sem
     nenhuma **não aparece** — devolvê-la com zero afirmaria revisão instantânea;
  4. **nenhuma função afirma conformidade**: `APPROVED` é ausência de bloqueio, e o estado
     fica cru;
  5. sumir da origem **marca**, nunca apaga — e marcar só acontece com página completa.
  """
  use TheBand.DataCase, async: false

  import Ecto.Query
  import TheBand.WorkItemsFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Changes.Commands, as: ChangeCommands
  alias TheBand.Quality
  alias TheBand.Quality.Commands

  setup do
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{tenant: tenant, admin: admin, repo_id: cenario.observed_repository_id}
  end

  defp solicitacao(ctx, numero, aberta_em) do
    {:ok, pr} =
      ChangeCommands.record_change_request(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        number: numero,
        title: "solicitação #{numero}",
        state: "OPEN",
        external_created_at: aberta_em,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_#{numero}"
      })

    pr
  end

  defp avaliacao(ctx, pr, attrs) do
    {:ok, a} =
      Commands.record_evaluation(
        ctx.tenant,
        Map.merge(
          %{
            collected_change_request_id: pr.id,
            state: "APPROVED",
            author_login: "revisora",
            author_type: "User",
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "PRR_#{System.unique_integer([:positive])}"
          },
          attrs
        )
      )

    a
  end

  describe "bot e pessoa" do
    test "o tempo até a primeira revisão ignora o bot", ctx do
      abertura = ~U[2026-08-01 10:00:00Z]
      pr = solicitacao(ctx, 1, abertura)

      # O robô "revisa" um minuto depois; a pessoa, duas horas depois.
      avaliacao(ctx, pr, %{
        author_type: "Bot",
        author_login: "dependabot",
        external_submitted_at: ~U[2026-08-01 10:01:00Z]
      })

      avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-08-01 12:00:00Z]})

      assert [%{seconds: segundos}] = Quality.time_to_first_review(ctx.tenant)

      # Duas horas, e não um minuto. Se o bot contasse, a medida diria que a organização
      # revisa em 60 segundos.
      assert segundos == 7200
    end

    test "o resumo separa avaliada por pessoa, só por bot, e sem avaliação", ctx do
      por_pessoa = solicitacao(ctx, 10, ~U[2026-08-01 10:00:00Z])
      avaliacao(ctx, por_pessoa, %{external_submitted_at: ~U[2026-08-01 11:00:00Z]})
      :ok = Commands.record_reviews_total(ctx.tenant, por_pessoa.id, 1)

      so_bot = solicitacao(ctx, 11, ~U[2026-08-01 10:00:00Z])

      avaliacao(ctx, so_bot, %{
        author_type: "Bot",
        external_submitted_at: ~U[2026-08-01 10:01:00Z]
      })

      :ok = Commands.record_reviews_total(ctx.tenant, so_bot.id, 1)

      sem = solicitacao(ctx, 12, ~U[2026-08-01 10:00:00Z])
      :ok = Commands.record_reviews_total(ctx.tenant, sem.id, 0)

      # E uma que nunca foi medida: nulo é desconhecido, nunca zero.
      solicitacao(ctx, 13, ~U[2026-08-01 10:00:00Z])

      resumo = Quality.resumo(ctx.tenant)

      assert resumo.avaliadas_por_pessoa == 1
      assert resumo.so_por_bot == 1
      assert resumo.sem_avaliacao == 1
      assert resumo.nao_medido == 1
    end

    test "o bot aparece na lista de revisores sem pessoa, e não é fundido", ctx do
      pr = solicitacao(ctx, 20, ~U[2026-08-01 10:00:00Z])
      avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-08-01 11:00:00Z]})

      avaliacao(ctx, pr, %{
        author_type: "Bot",
        author_login: "dependabot",
        external_submitted_at: ~U[2026-08-01 11:05:00Z]
      })

      revisores = Quality.by_reviewer(ctx.tenant)

      assert length(revisores) == 2
      bot = Enum.find(revisores, &(&1.author_type == "Bot"))
      # Forçar uma pessoa para o robô inventaria participação que não existe.
      assert bot.person_id == nil
    end
  end

  describe "o rascunho" do
    test "review não submetida existe e não entra na medida", ctx do
      pr = solicitacao(ctx, 30, ~U[2026-08-01 10:00:00Z])
      avaliacao(ctx, pr, %{state: "PENDING", external_submitted_at: nil})

      # Ela existe na leitura da solicitação...
      assert [%{state: "PENDING", submitted_at: nil}] =
               Quality.for_change_request(ctx.tenant, pr.id)

      # ...e não produz tempo até a primeira revisão, porque não houve revisão.
      assert Quality.time_to_first_review(ctx.tenant) == []
      # Nem conta como revisor.
      assert Quality.by_reviewer(ctx.tenant) == []
    end
  end

  describe "o estado fica cru" do
    test "APPROVED é preservado como a origem disse, sem virar conformidade", ctx do
      pr = solicitacao(ctx, 40, ~U[2026-08-01 10:00:00Z])
      avaliacao(ctx, pr, %{state: "APPROVED", external_submitted_at: ~U[2026-08-01 11:00:00Z]})

      avaliacao(ctx, pr, %{
        state: "CHANGES_REQUESTED",
        external_submitted_at: ~U[2026-08-01 12:00:00Z]
      })

      estados = Quality.for_change_request(ctx.tenant, pr.id) |> Enum.map(& &1.state)

      assert estados == ["APPROVED", "CHANGES_REQUESTED"]

      # E o revisor tem as duas contagens separadas — aprovar não apaga ter pedido mudança.
      assert [%{approved: 1, changes_requested: 1}] = Quality.by_reviewer(ctx.tenant)
    end
  end

  describe "sumir da origem" do
    test "marca em vez de apagar, e o marcado sai da leitura", ctx do
      pr = solicitacao(ctx, 50, ~U[2026-08-01 10:00:00Z])
      a1 = avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-08-01 11:00:00Z]})
      _a2 = avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-08-01 12:00:00Z]})

      # Segunda passada observa só a primeira.
      marcadas = Commands.mark_unobserved(ctx.tenant, pr.id, [a1.external_id])

      assert marcadas == 1
      assert [%{id: _}] = Quality.for_change_request(ctx.tenant, pr.id)

      # E a linha continua no banco: marcar nunca apaga.
      assert Repo.one(
               from a in "collected_artifact_evaluations",
                 where:
                   a.tenant_id == type(^ctx.tenant.id, :binary_id) and
                     not is_nil(a.no_longer_observed_at),
                 select: count(a.id)
             ) == 1
    end

    test "conjunto vazio marca todas — solicitação que perdeu as reviews", ctx do
      pr = solicitacao(ctx, 60, ~U[2026-08-01 10:00:00Z])
      avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-08-01 11:00:00Z]})

      assert Commands.mark_unobserved(ctx.tenant, pr.id, []) == 1
      assert Quality.for_change_request(ctx.tenant, pr.id) == []
    end
  end

  describe "o isolamento por tenant" do
    test "outro tenant não enxerga avaliação nenhuma", ctx do
      pr = solicitacao(ctx, 70, ~U[2026-08-01 10:00:00Z])
      avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-08-01 11:00:00Z]})

      {outro, _} = tenant_with_admin()

      assert Quality.for_change_request(outro, pr.id) == []
      assert Quality.by_reviewer(outro) == []
      assert Quality.time_to_first_review(outro) == []
    end
  end
end
