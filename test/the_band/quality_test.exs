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
  alias TheBand.Ontology.SEON.EO
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

  # ─────────────────────────────── feature 058, US1 — o recorte pela equipe ───

  describe "o recorte pela equipe é pela ABERTURA (058, T008)" do
    test "solicitação de quem saiu conta se aberta ANTES da saída, e não depois", ctx do
      %{equipe: equipe, pessoa: ana} = equipe_com_pessoa(ctx, "ana", ~U[2026-01-01 00:00:00Z])
      encerrar_vinculo(ctx, equipe, ana, ~U[2026-03-15 00:00:00Z])

      antes = da_pessoa(ctx, 101, ana, ~U[2026-03-10 10:00:00Z])
      depois = da_pessoa(ctx, 102, ana, ~U[2026-04-02 10:00:00Z])

      avaliacao(ctx, antes, %{external_submitted_at: ~U[2026-03-10 12:00:00Z]})
      avaliacao(ctx, depois, %{external_submitted_at: ~U[2026-04-02 12:00:00Z]})

      numeros =
        ctx.tenant |> Quality.team_time_to_first_review(equipe.id) |> Enum.map(& &1.numero)

      assert numeros == [101], """
      Vieram as solicitações #{inspect(numeros)}. O recorte é pela data de ABERTURA: a de
      04-02 foi aberta depois da saída e não é desta equipe, e a de 03-10 continua sendo
      (FR-002, SC-001).
      """
    end

    test "registrar OUTRA saída não altera o que já foi apresentado (SC-002)", ctx do
      %{equipe: equipe, pessoa: ana} = equipe_com_pessoa(ctx, "ana", ~U[2026-01-01 00:00:00Z])
      pr = da_pessoa(ctx, 110, ana, ~U[2026-02-10 10:00:00Z])
      avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-02-10 12:00:00Z]})

      antes = Quality.team_time_to_first_review(ctx.tenant, equipe.id)
      encerrar_vinculo(ctx, equipe, ana, ~U[2026-06-01 00:00:00Z])
      depois = Quality.team_time_to_first_review(ctx.tenant, equipe.id)

      assert antes == depois, """
      A lista mudou depois de registrar uma saída POSTERIOR à abertura. A vigência é
      avaliada contra a data do evento, e não contra hoje — senão o passado se reescreve
      a cada mudança de cadastro (SC-002).
      """
    end

    test "revisão de robô não encerra a contagem", ctx do
      %{equipe: equipe, pessoa: ana} = equipe_com_pessoa(ctx, "ana", ~U[2026-01-01 00:00:00Z])
      pr = da_pessoa(ctx, 120, ana, ~U[2026-02-01 10:00:00Z])

      avaliacao(ctx, pr, %{
        author_type: "Bot",
        author_login: "dependabot",
        external_submitted_at: ~U[2026-02-01 10:01:00Z]
      })

      avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-02-01 12:00:00Z]})

      [linha] = Quality.team_time_to_first_review(ctx.tenant, equipe.id)

      assert linha.estado == {:revisada, 2.0}, """
      O estado veio #{inspect(linha.estado)}. O robô revisou em um minuto e a pessoa em duas
      horas: contar o robô mediria o robô (FR-003).
      """
    end

    test "solicitação de quem nunca teve vínculo não conta para equipe nenhuma", ctx do
      %{equipe: equipe} = equipe_com_pessoa(ctx, "ana", ~U[2026-01-01 00:00:00Z])
      sem_vinculo = pessoa_qualquer(ctx, "forasteira")
      pr = da_pessoa(ctx, 130, sem_vinculo, ~U[2026-02-01 10:00:00Z])
      avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-02-01 12:00:00Z]})

      assert Quality.team_time_to_first_review(ctx.tenant, equipe.id) == []
    end

    test "outro tenant não recebe linha nenhuma (SC-010)", ctx do
      %{equipe: equipe, pessoa: ana} = equipe_com_pessoa(ctx, "ana", ~U[2026-01-01 00:00:00Z])
      pr = da_pessoa(ctx, 140, ana, ~U[2026-02-01 10:00:00Z])
      avaliacao(ctx, pr, %{external_submitted_at: ~U[2026-02-01 12:00:00Z]})

      {outro, _} = tenant_with_admin()

      assert Quality.team_time_to_first_review(outro, equipe.id) == []
      assert Quality.team_time_to_first_review_by_person(outro, equipe.id) == []
    end
  end

  describe "a espera em curso (058, T009)" do
    test "a revisada e a que ninguém revisou aparecem AS DUAS, com relatores distintos", ctx do
      %{equipe: equipe, pessoa: ana} = equipe_com_pessoa(ctx, "ana", ~U[2026-01-01 00:00:00Z])

      revisada = da_pessoa(ctx, 150, ana, DateTime.add(DateTime.utc_now(:second), -40, :day))

      avaliacao(ctx, revisada, %{
        external_submitted_at: DateTime.add(revisada.external_created_at, 2, :hour)
      })

      _sem_revisao = da_pessoa(ctx, 151, ana, DateTime.add(DateTime.utc_now(:second), -30, :day))

      linhas = Quality.team_time_to_first_review(ctx.tenant, equipe.id)
      estados = linhas |> Enum.sort_by(& &1.numero) |> Enum.map(& &1.estado)

      # `==`: com `=` o MatchError vem antes da mensagem, e quem lê às três da manhã
      # recebe um dump de estrutura em vez da frase (revisão de QA, PR #798).
      assert estados == [{:revisada, 2.0}, {:aguardando, 30}], """
      Os estados vieram #{inspect(estados)}. Omitir a que ninguém revisou faria a mediana
      MELHORAR quanto pior a equipe estivesse, e contá-la como zero afirmaria revisão
      instantânea (FR-004, SC-003).
      """
    end

    test "a mediana ignora as em curso, e é nil quando nenhuma foi revisada", ctx do
      %{equipe: equipe, pessoa: ana} = equipe_com_pessoa(ctx, "ana", ~U[2026-01-01 00:00:00Z])
      _sem_revisao = da_pessoa(ctx, 160, ana, DateTime.add(DateTime.utc_now(:second), -10, :day))

      esperas = Quality.team_time_to_first_review(ctx.tenant, equipe.id)

      assert [%{estado: {:aguardando, _}}] = esperas

      assert Quality.mediana_em_horas(esperas) == nil, """
      A mediana veio com valor sobre uma lista sem nenhuma espera encerrada. Zero afirmaria
      revisão instantânea; a ausência é dita com nil e a tela a nomeia.
      """
    end
  end

  describe "a mesma espera por pessoa (058, T010)" do
    test "cada pessoa vem com as suas, e a soma das listas é a lista da equipe", ctx do
      %{equipe: equipe, pessoa: ana, papel: papel} =
        equipe_com_pessoa(ctx, "ana", ~U[2026-01-01 00:00:00Z])

      bia = pessoa_qualquer(ctx, "bia")
      vincular_na_equipe(ctx, equipe, bia, papel, ~U[2026-01-01 00:00:00Z])

      pr_ana = da_pessoa(ctx, 170, ana, ~U[2026-02-01 10:00:00Z])
      avaliacao(ctx, pr_ana, %{external_submitted_at: ~U[2026-02-01 13:00:00Z]})

      pr_bia = da_pessoa(ctx, 171, bia, ~U[2026-02-02 10:00:00Z])
      avaliacao(ctx, pr_bia, %{external_submitted_at: ~U[2026-02-02 11:00:00Z]})

      por_pessoa = Quality.team_time_to_first_review_by_person(ctx.tenant, equipe.id)

      assert Enum.map(por_pessoa, & &1.autor_login) == ["ana", "bia"]
      assert [%{estado: {:revisada, 3.0}}] = Enum.at(por_pessoa, 0).esperas
      assert [%{estado: {:revisada, 1.0}}] = Enum.at(por_pessoa, 1).esperas

      da_equipe = Quality.team_time_to_first_review(ctx.tenant, equipe.id)

      assert por_pessoa |> Enum.flat_map(& &1.esperas) |> length() == length(da_equipe), """
      As duas leituras vieram de consultas diferentes. Elas têm de sair da MESMA — dois
      números com o mesmo rótulo e denominadores diferentes é a L67.
      """
    end
  end

  # Uma equipe, uma pessoa dentro dela desde `desde`. O papel existe porque
  # `allocate/2` o exige: vínculo sem papel não é vínculo declarado.
  defp equipe_com_pessoa(ctx, login, desde) do
    org = organization_fixture(ctx.tenant, "acme-#{System.unique_integer([:positive])}")
    {:ok, papel} = EO.create_role(ctx.tenant, org.id, %{code: "dev", name: "Dev"}, ctx.admin.id)
    {:ok, equipe} = EO.declare_structural_team(ctx.tenant, org.id, "Dados", ctx.admin.id)
    p = pessoa_qualquer(ctx, login)

    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: p.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        started_at: desde
      })

    %{equipe: equipe, pessoa: p, papel: papel, org: org}
  end

  # O papel vem por parâmetro, e não da listagem da organização: `list_organization_roles/2`
  # traz também os papéis do CATÁLOGO, que têm `id` nulo — vincular com um deles falha
  # com "can't be blank", que foi o que este teste encontrou.
  defp vincular_na_equipe(ctx, equipe, pessoa, papel, desde) do
    {:ok, _} =
      EO.allocate(ctx.tenant, %{
        person_id: pessoa.id,
        team_id: equipe.id,
        organizational_role_id: papel.id,
        started_at: desde
      })
  end

  # A saída é escrita direto na coluna: o que está sob teste é o RECORTE por
  # data, e não o caminho pelo qual a data chegou lá.
  defp encerrar_vinculo(ctx, equipe, pessoa, quando) do
    {1, _} =
      Repo.update_all(
        from(m in "eo_team_memberships",
          where:
            m.tenant_id == type(^ctx.tenant.id, :binary_id) and
              m.team_id == type(^equipe.id, :binary_id) and
              m.person_id == type(^pessoa.id, :binary_id)
        ),
        set: [ended_at: quando]
      )
  end

  defp pessoa_qualquer(ctx, login) do
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

  defp da_pessoa(ctx, numero, pessoa, aberta_em) do
    {:ok, pr} =
      ChangeCommands.record_change_request(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        number: numero,
        title: "solicitação #{numero}",
        state: "OPEN",
        external_created_at: aberta_em,
        author_login: pessoa.login,
        author_person_id: pessoa.id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "PR_#{numero}"
      })

    pr
  end
end
