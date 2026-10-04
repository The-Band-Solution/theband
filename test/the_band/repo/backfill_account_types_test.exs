defmodule TheBand.Repo.BackfillAccountTypesTest do
  @moduledoc """
  O preenchimento do tipo da conta das issues já coletadas — feature 076, T022
  (`data-model.md` §3; research.md R13).

  Roda o SQL da migração `BackfillIssueAccountTypes` sobre dois tenants. O mesmo `external_id`
  existe nos dois, e só o primeiro tem payload: o segundo **não** pode receber o tipo do payload do
  primeiro. E a regra em SQL tem de dar o que `Mapper.account_type/1` dá para os mesmos nós.
  """
  use TheBand.DataCase, async: true

  import TheBand.ReviewNetworkFixtures

  alias TheBand.Ingestion.Sync
  alias TheBand.RawData
  alias TheBand.SemanticIntegration.Mapper
  alias TheBand.WorkItems
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  Code.require_file("priv/repo/migrations/20261004110100_backfill_issue_account_types.exs")
  @migracao TheBand.Repo.Migrations.BackfillIssueAccountTypes

  @robo %{"__typename" => "Bot", "id" => "B_1", "login" => "renovate-sem-sufixo"}
  @app %{"__typename" => "App", "id" => "A_1", "login" => "um-app"}
  @pessoa %{"__typename" => "User", "id" => "U_1", "login" => "ana"}
  @sufixo %{"__typename" => "User", "id" => "U_2", "login" => "algo[bot]"}

  defp issue(tenant, repo, external_id, autor_login, designados) do
    {:ok, issue} =
      WorkItems.record_collected_issue(tenant, %{
        observed_repository_id: repo,
        number: System.unique_integer([:positive]),
        title: "t",
        state: "OPEN",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: external_id,
        external_created_at: DateTime.utc_now(:second),
        author_login: autor_login
      })

    {:ok, _} =
      WorkItems.replace_assignees(
        tenant,
        issue.id,
        Enum.map(designados, &%{login: &1, person_id: nil})
      )

    issue
  end

  # O payload bruto exige a sincronização que o trouxe.
  defp sincronizacao(tenant, tool) do
    {:ok, sync} =
      %Sync{}
      |> Sync.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        status: "completed",
        started_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    sync
  end

  defp payload({tenant, sync}, external_id, autor, designados, quando) do
    {:ok, _} =
      RawData.store(%{
        tenant_id: tenant.id,
        sync_id: sync.id,
        raw_entity_type: "github.issue",
        external_id: external_id,
        payload: %{
          "id" => external_id,
          "author" => autor,
          "assignees" => %{"nodes" => designados}
        },
        mapping_id: "github.issue.user_story.to.sro.atomic_user_story",
        mapping_version: 2,
        source_system: "github",
        source_instance: "https://github.com",
        collected_at: quando
      })
  end

  defp preencher do
    Repo.query!(@migracao.sql_autores())
    Repo.query!(@migracao.sql_responsaveis())
  end

  test "o tipo vem do payload mais recente do MESMO tenant, e o outro tenant fica nulo" do
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    o1 = organizacao_com_repositorio(t1)
    r1 = o1.observed_repository_id
    r2 = organizacao_com_repositorio(t2).observed_repository_id
    s1 = {t1, sincronizacao(t1, o1.tool)}

    i1 = issue(t1, r1, "I_mesmo", "renovate-sem-sufixo", ["ana", "um-app"])
    i2 = issue(t2, r2, "I_mesmo", "renovate-sem-sufixo", ["ana", "um-app"])
    sem_payload = issue(t1, r1, "I_sem_payload", "x", ["y"])

    antigo = DateTime.add(DateTime.utc_now(:second), -3600, :second)
    payload(s1, "I_mesmo", @pessoa, [], antigo)
    payload(s1, "I_mesmo", @robo, [@pessoa, @app], DateTime.utc_now(:second))

    preencher()

    # O mais recente do mesmo tenant decidiu.
    assert Repo.get!(CollectedIssue, i1.id).author_account_type == "bot"

    assert tipos(i1) == %{"ana" => "person", "um-app" => "app"}

    # O outro tenant, com o mesmo external_id e sem payload próprio, continua sem tipo.
    assert Repo.get!(CollectedIssue, i2.id).author_account_type == nil
    assert tipos(i2) == %{"ana" => nil, "um-app" => nil}

    # Sem payload nenhum: nulo, e nunca "person".
    assert Repo.get!(CollectedIssue, sem_payload.id).author_account_type == nil
    assert tipos(sem_payload) == %{"y" => nil}
  end

  test "a regra em SQL dá o mesmo que Mapper.account_type/1" do
    t = tenant_fixture()
    o = organizacao_com_repositorio(t)
    r = o.observed_repository_id
    s = {t, sincronizacao(t, o.tool)}

    for {no, i} <- Enum.with_index([@robo, @app, @pessoa, @sufixo]) do
      id = "I_regra_#{i}"
      criada = issue(t, r, id, no["login"], [])
      payload(s, id, no, [], DateTime.utc_now(:second))
      preencher()
      assert Repo.get!(CollectedIssue, criada.id).author_account_type == Mapper.account_type(no)
    end
  end

  test "autor nulo no payload continua nulo" do
    t = tenant_fixture()
    o = organizacao_com_repositorio(t)
    r = o.observed_repository_id
    s = {t, sincronizacao(t, o.tool)}
    criada = issue(t, r, "I_apagado", nil, [])
    payload(s, "I_apagado", nil, [], DateTime.utc_now(:second))
    preencher()
    assert Repo.get!(CollectedIssue, criada.id).author_account_type == nil
  end

  defp tipos(issue) do
    Repo.all(from a in IssueAssignee, where: a.collected_issue_id == ^issue.id)
    |> Map.new(&{&1.login, &1.account_type})
  end
end
