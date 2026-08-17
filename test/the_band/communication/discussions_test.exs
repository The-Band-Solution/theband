defmodule TheBand.Communication.DiscussionsTest do
  @moduledoc """
  A leitura da comunicação — feature 030, SC-004 e as regras da CMO.

  ## As asserções que carregam este arquivo

  1. comentário não mais observado sai da discussão, e a marca fica no banco;
  2. participação conta **atos de comentar**, nunca tarefas — e agrega por issue;
  3. `last_act_for_issues/2` resolve N issues em **uma** consulta (SC-004);
  4. issue ausente do mapa é ausência de discussão coletada — nunca zero implícito.
  """
  use TheBand.DataCase, async: false

  import TheBandWeb.ConnCase, only: [tenant_with_admin: 0]
  import TheBand.WorkItemsFixtures

  alias TheBand.Communication.{Commands, Discussions}
  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO

  setup do
    {:ok, _} = KnowledgeBase.load()
    {tenant, admin} = tenant_with_admin()
    cenario = cenario_real(tenant)

    %{tenant: tenant, admin: admin, repo_id: cenario.observed_repository_id, cenario: cenario}
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
        payload: %{}
      })

    p
  end

  defp issue(ctx, numero) do
    {:ok, i} =
      TheBand.WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.repo_id,
        number: numero,
        title: "issue #{numero}",
        state: "OPEN",
        issue_type: "Task",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_#{numero}"
      })

    i
  end

  defp comentar(ctx, issue, pessoa, quando, extra \\ %{}) do
    {:ok, c} =
      Commands.record_comment(
        ctx.tenant,
        Map.merge(
          %{
            collected_issue_id: issue.id,
            body: "texto",
            author_login: pessoa && pessoa.login,
            author_person_id: pessoa && pessoa.id,
            external_published_at: quando,
            source_system: "github",
            source_instance: "https://github.com",
            external_id: "C_#{issue.number}_#{DateTime.to_unix(quando, :microsecond)}"
          },
          extra
        )
      )

    c
  end

  test "a discussão vem em ordem, e o não-observado sai dela sem ser apagado", ctx do
    ana = pessoa(ctx.tenant, "ana")
    i = issue(ctx, 9001)

    comentar(ctx, i, ana, ~U[2026-06-01 10:00:00Z])
    comentar(ctx, i, ana, ~U[2026-07-01 10:00:00Z])

    assert [primeiro, segundo] = Discussions.for_issue(ctx.tenant, i.id)
    assert DateTime.compare(primeiro.published_at, segundo.published_at) == :lt

    # Apagado na origem: a página completa trouxe SÓ o segundo de volta.
    sobrevivente =
      TheBand.Repo.one!(
        from c in "collected_issue_comments",
          where: c.id == type(^segundo.id, :binary_id),
          select: c.external_id
      )

    assert 1 = Commands.mark_unobserved_comments(ctx.tenant, i.id, [sobrevivente])

    assert [restante] = Discussions.for_issue(ctx.tenant, i.id),
           "a marca não tirou o apagado da discussão, ou tirou os dois"

    assert restante.id == segundo.id

    assert TheBand.Repo.aggregate(
             from(c in "collected_issue_comments",
               where: c.collected_issue_id == type(^i.id, :binary_id)
             ),
             :count
           ) == 2,
           "a marca virou DELETE — marca nunca apaga"
  end

  test "a participação agrega por issue e conta ATOS, com primeiro e último", ctx do
    ana = pessoa(ctx.tenant, "ana")
    bia = pessoa(ctx.tenant, "bia")
    i1 = issue(ctx, 9002)
    i2 = issue(ctx, 9003)

    comentar(ctx, i1, ana, ~U[2026-05-01 10:00:00Z])
    comentar(ctx, i1, ana, ~U[2026-06-01 10:00:00Z])
    comentar(ctx, i2, ana, ~U[2026-07-01 10:00:00Z])
    comentar(ctx, i1, bia, ~U[2026-06-15 10:00:00Z])

    participacao = Discussions.participation_of(ctx.tenant, ana.id)

    assert length(participacao) == 2, "duas issues viraram uma linha, ou apareceram três"

    linha_i1 = Enum.find(participacao, &(&1.number == 9002))
    assert linha_i1.atos == 2, "os atos de bia entraram na conta de ana, ou a agregação perdeu um"
    assert linha_i1.primeiro == ~U[2026-05-01 10:00:00Z]
    assert linha_i1.ultimo == ~U[2026-06-01 10:00:00Z]

    # Mais recente primeiro: quem lê quer saber onde a conversa está agora.
    assert hd(participacao).number == 9003
  end

  test "SC-004: o último ato de N issues sai em UMA consulta", ctx do
    ana = pessoa(ctx.tenant, "ana")

    issues =
      for n <- 9100..9107 do
        i = issue(ctx, n)
        comentar(ctx, i, ana, ~U[2026-06-01 10:00:00Z])
        i
      end

    ids = Enum.map(issues, & &1.id)
    sem_discussao = issue(ctx, 9200)

    consultas =
      TheBand.ContadorDeConsultas.contar(fn ->
        Discussions.last_act_for_issues(ctx.tenant, ids)
      end)

    assert consultas == 1, """
    O último ato de 8 issues custou #{consultas} consultas.

    SC-004: é uma consulta agregada para N issues. Uma por issue é o defeito das 135
    consultas por render da feature 007, numa roupa nova.
    """

    mapa = Discussions.last_act_for_issues(ctx.tenant, ids ++ [sem_discussao.id])

    refute Map.has_key?(mapa, sem_discussao.id),
           """
           A issue sem discussão veio no mapa com zero.

           Ausência do mapa é o que permite quem chama distinguir "sem conversa" de
           "coleta não passou" — zero implícito apagaria a distinção.
           """
  end

  test "a discussão custa uma consulta, com um comentário ou com vinte", ctx do
    ana = pessoa(ctx.tenant, "ana")
    i = issue(ctx, 9400)

    for n <- 1..20 do
      comentar(ctx, i, ana, DateTime.add(~U[2026-06-01 10:00:00Z], n, :day))
    end

    consultas =
      TheBand.ContadorDeConsultas.contar(fn -> Discussions.for_issue(ctx.tenant, i.id) end)

    assert consultas == 1, """
    Vinte comentários custaram #{consultas} consultas.

    A discussão é uma consulta, sempre. É o que sustenta o teto de 40 do render do
    detalhe da issue — se aqui crescer, lá cresce também.
    """
  end

  test "autor sem pessoa coletada participa da discussão, mas não da participação", ctx do
    i = issue(ctx, 9300)
    comentar(ctx, i, nil, ~U[2026-06-01 10:00:00Z], %{author_login: "quem-saiu"})

    assert [c] = Discussions.for_issue(ctx.tenant, i.id)
    assert c.author_login == "quem-saiu"
    assert is_nil(c.author_person_id), "vínculo com pessoa foi inventado"
  end
end
