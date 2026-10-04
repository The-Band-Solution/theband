defmodule TheBand.WorkItems.AssignmentPairsTest do
  @moduledoc """
  Os pares de designação com o tenant em cada tabela da junção — feature 076, T023 (FR-009;
  research.md R12; cenários A1 e A2 de `seguranca.md`).

  - **A1**: T1 e T2 com issues e responsáveis nas mesmas datas; uma linha de `issue_assignees` de
    T2 apontando, à mão, para a issue de T1 (a FK é simples e permite). Nenhuma pessoa de T2
    aparece, e os pares de T1 são exatamente os de T1;
  - **A2**: organizações A e B no mesmo tenant; a leitura de A não traz issue só de B.

  Cada `refute` vem depois de um `assert` de que a consulta trouxe pares.
  """
  use TheBand.DataCase, async: true

  import TheBand.ReviewNetworkFixtures

  alias TheBand.WorkItems
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssueAssignee

  defp dias_atras(n), do: DateTime.add(DateTime.utc_now(:second), -n * 86_400, :second)

  defp issue(tenant, repo, autor, designados, aberta_em, extra \\ %{}) do
    {:ok, issue} =
      WorkItems.record_collected_issue(
        tenant,
        Map.merge(
          %{
            observed_repository_id: repo,
            number: System.unique_integer([:positive]),
            title: "t",
            state: "OPEN",
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "I_#{System.unique_integer([:positive])}",
            external_created_at: aberta_em,
            author_login: autor && "login-de-#{autor.name}",
            author_person_id: autor && autor.id,
            author_account_type: "person"
          },
          extra
        )
      )

    {:ok, _} =
      WorkItems.replace_assignees(
        tenant,
        issue.id,
        Enum.map(designados, fn p ->
          %{login: "login-de-#{p.name}", person_id: p.id, account_type: "person"}
        end)
      )

    issue
  end

  defp pares(tenant, repos, desde \\ dias_atras(180)),
    do: WorkItems.assignment_pairs(tenant, repos, since: desde)

  setup do
    t1 = tenant_fixture()
    t2 = tenant_fixture()
    a = organizacao_com_repositorio(t1)
    b = organizacao_com_repositorio(t1)
    de_t2 = organizacao_com_repositorio(t2)

    ana = pessoa(t1, "Ana")
    bia = pessoa(t1, "Bia")
    caio = pessoa(t1, "Caio")
    zeca = pessoa(t2, "Zeca De Outro Tenant")
    vera = pessoa(t2, "Vera De Outro Tenant")

    i1 = issue(t1, a.observed_repository_id, ana, [bia, caio], dias_atras(10))
    i2 = issue(t1, a.observed_repository_id, ana, [], dias_atras(20))
    so_de_b = issue(t1, b.observed_repository_id, caio, [ana], dias_atras(10))
    de_t2_issue = issue(t2, de_t2.observed_repository_id, zeca, [vera], dias_atras(10))

    # A1: a issue de T2 apontando, à mão, para o repositório observado de T1 (a FK é simples).
    _cruzada_de_t2 = issue(t2, a.observed_repository_id, zeca, [vera], dias_atras(10))

    # A1: a linha de T2 apontando, à mão, para a issue de T1.
    {:ok, _} =
      %IssueAssignee{}
      |> IssueAssignee.changeset(%{
        tenant_id: t2.id,
        collected_issue_id: i1.id,
        login: "intrusa",
        person_id: vera.id,
        account_type: "person"
      })
      |> Repo.insert()

    %{
      t1: t1,
      t2: t2,
      a: a,
      b: b,
      ana: ana,
      bia: bia,
      caio: caio,
      zeca: zeca,
      vera: vera,
      i1: i1,
      i2: i2,
      so_de_b: so_de_b,
      de_t2_issue: de_t2_issue
    }
  end

  test "A1: só os pares de T1, e nenhuma pessoa de T2", ctx do
    lidos = pares(ctx.t1, [ctx.a.observed_repository_id])

    esperado =
      MapSet.new([
        {ctx.i1.id, true, ctx.ana.id, ctx.bia.id},
        {ctx.i1.id, true, ctx.ana.id, ctx.caio.id},
        {ctx.i2.id, false, ctx.ana.id, nil}
      ])

    # A consulta trouxe pares: o que vem depois não passa por estar vazio.
    assert length(lidos) == 3

    assert MapSet.new(
             lidos,
             &{&1.collected_issue_id, &1.assigned, &1.author_person_id, &1.assignee_person_id}
           ) ==
             esperado

    ids = Enum.flat_map(lidos, &[&1.author_person_id, &1.assignee_person_id])
    refute ctx.vera.id in ids
    refute ctx.zeca.id in ids
  end

  test "a pessoa de outro tenant vira nil, e nunca nó", ctx do
    # A issue de T1 com autor e responsável de T2, à mão.
    cruzada =
      issue(ctx.t1, ctx.a.observed_repository_id, nil, [], dias_atras(5), %{
        author_person_id: ctx.zeca.id
      })

    {:ok, _} =
      %IssueAssignee{}
      |> IssueAssignee.changeset(%{
        tenant_id: ctx.t1.id,
        collected_issue_id: cruzada.id,
        login: "x",
        person_id: ctx.vera.id
      })
      |> Repo.insert()

    [par] =
      Enum.filter(
        pares(ctx.t1, [ctx.a.observed_repository_id]),
        &(&1.collected_issue_id == cruzada.id)
      )

    assert par.assigned
    assert par.author_person_id == nil
    assert par.assignee_person_id == nil
  end

  test "A2: a leitura de A não traz issue só de B", ctx do
    lidos = pares(ctx.t1, [ctx.a.observed_repository_id])
    assert lidos != []
    refute ctx.so_de_b.id in Enum.map(lidos, & &1.collected_issue_id)

    # E a de B, sozinha, só traz a dela.
    assert [%{collected_issue_id: id}] = pares(ctx.t1, [ctx.b.observed_repository_id])
    assert id == ctx.so_de_b.id
  end

  test "só responsável vigente, só issue vigente, e só a partir do instante", ctx do
    Repo.update_all(
      from(x in IssueAssignee,
        where: x.collected_issue_id == ^ctx.i1.id and x.person_id == ^ctx.caio.id
      ),
      set: [no_longer_observed_at: DateTime.utc_now(:second)]
    )

    Repo.update_all(from(x in CollectedIssue, where: x.id == ^ctx.i2.id),
      set: [no_longer_observed_at: DateTime.utc_now(:second)]
    )

    lidos = pares(ctx.t1, [ctx.a.observed_repository_id])
    assert Enum.map(lidos, & &1.assignee_person_id) == [ctx.bia.id]

    # i1 foi aberta há 10 dias: fora de uma janela de 5.
    assert pares(ctx.t1, [ctx.a.observed_repository_id], dias_atras(5)) == []
  end

  test "nenhum login sai da consulta", ctx do
    lidos = pares(ctx.t1, [ctx.a.observed_repository_id])
    assert lidos != []
    refute inspect(lidos) =~ "login-de-"
    refute inspect(lidos) =~ "intrusa"
  end
end
