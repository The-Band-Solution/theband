defmodule TheBand.ChangesTest do
  @moduledoc """
  A leitura das mudanças — feature 032.

  ## As asserções que carregam este arquivo

  1. **autoria é plural**: um commit com dois autores devolve dois, e a co-autoria é
     distinguível da autoria principal (`is_primary`);
  2. as três leituras da pessoa **nunca são somadas** — abrir, integrar e commitar são
     atos distintos, e a mesma pessoa pode fazer os três no mesmo PR;
  3. o vínculo com issue é o que a origem reconheceu, e sumir dele **marca**, nunca apaga;
  4. os commits de uma solicitação custam **duas** consultas, com um ou com vinte.
  """
  use TheBand.DataCase, async: false

  import TheBand.WorkItemsFixtures
  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]

  alias TheBand.Changes
  alias TheBand.Changes.Commands
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    %{
      tenant: tenant,
      admin: admin,
      repo_id: cenario.observed_repository_id,
      cenario: cenario
    }
  end

  defp pessoa(tenant, login) do
    {:ok, p} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: String.upcase(login),
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{}
      })

    p
  end

  defp solicitacao(ctx, numero, attrs \\ %{}) do
    {:ok, cr} =
      Commands.record_change_request(
        ctx.tenant,
        Map.merge(
          %{
            observed_repository_id: ctx.repo_id,
            number: numero,
            title: "mudança #{numero}",
            state: "MERGED",
            source_branch: "feature-#{numero}",
            target_branch: "main",
            external_created_at: ~U[2026-06-01 10:00:00Z],
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "PR_#{numero}"
          },
          attrs
        )
      )

    cr
  end

  defp commit(ctx, cr, sha, autores) do
    {:ok, c} =
      Commands.record_commit(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        change_request_id: cr && cr.id,
        sha: sha,
        message_headline: "commit #{sha}",
        external_committed_at: ~U[2026-06-01 11:00:00Z],
        source_system: "github",
        source_instance: "https://github.com",
        external_id: sha
      })

    :ok = Commands.replace_commit_authors(ctx.tenant, c.id, autores)
    c
  end

  test "autoria é plural, e a co-autoria é distinguível da autoria principal", ctx do
    ana = pessoa(ctx.tenant, "ana")
    bia = pessoa(ctx.tenant, "bia")
    cr = solicitacao(ctx, 1)

    commit(ctx, cr, "sha-a", [
      %{author_login: "ana", author_person_id: ana.id, author_name: "ANA", is_primary: true},
      %{author_login: "bia", author_person_id: bia.id, author_name: "BIA", is_primary: false}
    ])

    assert [c] = Changes.commits_of(ctx.tenant, cr.id)

    assert length(c.autores) == 2, """
    O commit devolveu #{length(c.autores)} autor(es).

    Todo commit deste repositório tem dois — quem escreveu e o agente, pelo trailer
    Co-Authored-By. Coletar um só atribuiria a mudança a uma pessoa quando o registro
    nomeia duas.
    """

    principal = Enum.find(c.autores, & &1.is_primary)
    coautor = Enum.find(c.autores, &(not &1.is_primary))

    assert principal.login == "ana"
    assert coautor.login == "bia", "a co-autoria virou autoria principal, ou sumiu"
  end

  test "as três leituras da pessoa não se somam — a mesma pessoa pode fazer os três", ctx do
    ana = pessoa(ctx.tenant, "ana")

    # Abriu E integrou o próprio PR: acontece no dado real, e é achado de processo.
    cr = solicitacao(ctx, 2, %{author_person_id: ana.id, merged_by_person_id: ana.id})
    commit(ctx, cr, "sha-b", [%{author_login: "ana", author_person_id: ana.id, is_primary: true}])

    mudancas = Changes.by_person(ctx.tenant, ana.id)

    assert length(mudancas.abertas) == 1
    assert length(mudancas.integradas) == 1
    assert length(mudancas.commits) == 1

    assert hd(mudancas.abertas).number == hd(mudancas.integradas).number, """
    A mesma solicitação apareceu em listas diferentes.

    Abrir e integrar são atos distintos, e a mesma pessoa fazendo os dois é o que mostra
    que ninguém revisou. Somar as três leituras produziria "3 contribuições" onde houve
    uma mudança.
    """
  end

  test "o co-autor aparece nos commits dele mesmo sem ter aberto solicitação", ctx do
    ana = pessoa(ctx.tenant, "ana")
    agente = pessoa(ctx.tenant, "agente")
    cr = solicitacao(ctx, 3, %{author_person_id: ana.id})

    commit(ctx, cr, "sha-c", [
      %{author_login: "ana", author_person_id: ana.id, is_primary: true},
      %{author_login: "agente", author_person_id: agente.id, is_primary: false}
    ])

    mudancas = Changes.by_person(ctx.tenant, agente.id)

    assert mudancas.abertas == []
    assert mudancas.integradas == []

    assert [c] = mudancas.commits, """
    Quem só participa como co-autor ficou invisível.

    É o mesmo defeito dos 24 no_assignment: a pessoa trabalha, e a plataforma não mostra.
    """

    refute c.is_primary, "a co-autoria foi apresentada como autoria principal"
  end

  test "o vínculo com issue segue a origem, e sumir dele marca — nunca apaga", ctx do
    cr = solicitacao(ctx, 4)
    %{pai: issue} = ctx.cenario.issues[3]

    :ok = Commands.replace_attended_issues(ctx.tenant, cr.id, [issue.id])
    assert [i] = Changes.attended_issues(ctx.tenant, cr.id)
    assert i.id == issue.id

    # A closing keyword foi removida do PR: o vínculo sai da leitura...
    :ok = Commands.replace_attended_issues(ctx.tenant, cr.id, [])
    assert Changes.attended_issues(ctx.tenant, cr.id) == []

    # ...e continua no banco, marcado.
    assert Repo.aggregate(
             from(v in "change_request_issues",
               where: v.collected_change_request_id == type(^cr.id, :binary_id)
             ),
             :count
           ) == 1,
           "a marca virou DELETE — marca nunca apaga"
  end

  test "os commits de uma solicitação custam duas consultas, com um ou com vinte", ctx do
    ana = pessoa(ctx.tenant, "ana")
    cr = solicitacao(ctx, 5)

    for n <- 1..20 do
      commit(ctx, cr, "sha-#{n}", [
        %{author_login: "ana", author_person_id: ana.id, is_primary: true}
      ])
    end

    consultas =
      TheBand.ContadorDeConsultas.contar(fn -> Changes.commits_of(ctx.tenant, cr.id) end)

    assert consultas == 2, """
    Vinte commits custaram #{consultas} consultas.

    São duas, sempre: os commits, e os autores em lote. Uma consulta de autores por
    commit é o defeito das 135 por render da feature 007 numa roupa nova — e commits com
    dois autores são o caso comum aqui.
    """
  end

  test "solicitação de outro tenant devolve not_found, nunca o registro", ctx do
    cr = solicitacao(ctx, 6)
    {outro_tenant, _} = tenant_with_admin()

    assert {:error, :not_found} = Changes.get(outro_tenant, cr.id)
    assert {:ok, _} = Changes.get(ctx.tenant, cr.id)
  end
end
