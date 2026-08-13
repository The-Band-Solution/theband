defmodule TheBandWeb.TrabalhouNaoEMembroTest do
  @moduledoc """
  A organização derivada do trabalho, dita sem afirmar pertencimento (feature 015, T006).

  ## As duas cadeias, e por que a tela as separa

  `pessoa → equipe → organização` sustenta **"é membro"**. Quem saiu antes de a plataforma existir
  nunca esteve numa equipe, e apareceria com zero organizações — falso de outra maneira, porque
  trabalhou lá.

  `pessoa → issue → repositório → organização` sustenta **"trabalhou"**, e é observada de ponta a
  ponta.

  Somar as duas faria "quem é da organização" responder com gente que ninguém admitiu.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.EO
  alias TheBand.WorkItems

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  test "quem só trabalhou aparece com a organização e com a evidência", ctx do
    pessoa = pessoa_que_so_trabalhou(ctx)

    {:ok, _live, html} = live(ctx.conn, ~p"/people/#{pessoa.id}")

    assert html =~ "worked at"
    assert html =~ "derived from work in 1 repository"

    # A afirmação que a tela **faz** é "trabalhou, e aqui está a evidência". A que ela **não** pode
    # fazer é a de pertencimento — que na tela tem texto próprio, usado só para quem tem equipe.
    assert html =~ "not a declared membership"

    refute html =~ "observed through team membership", """
    A tela afirmou pertencimento para quem só trabalhou.

    O GitHub não declara pertencimento de quem saiu, e a plataforma não pode afirmar o que não
    observou — a evidência é a issue, e ela sustenta "trabalhou", não "pertence".
    """
  end

  test "quem é membro continua aparecendo por equipe, e não duas vezes", ctx do
    %{pessoa: pessoa} = membro_com_trabalho(ctx)

    {:ok, _live, html} = live(ctx.conn, ~p"/people/#{pessoa.id}")

    assert html =~ "observed through team membership"

    refute html =~ "derived from work in", """
    A mesma organização apareceu nas duas listas.

    Quem já aparece por equipe não precisa aparecer de novo por trabalho — e ver o mesmo nome duas
    vezes convida a somar.
    """
  end

  defp pessoa_que_so_trabalhou(ctx) do
    {:ok, pessoa} =
      EO.upsert_person_from_source(ctx.tenant, %{
        name: "Sofia",
        login: "sofialctv",
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "U_sofia",
        collected_at: DateTime.utc_now(:second),
        last_observed_at: DateTime.utc_now(:second)
      })

    {:ok, _} =
      WorkItems.record_collected_issue(ctx.tenant, %{
        observed_repository_id: ctx.cenario.observed_repository_id,
        number: 9_400,
        title: "issue de quem saiu",
        state: "OPEN",
        issue_type: "Task",
        author_login: pessoa.login,
        author_person_id: pessoa.id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "I_9400"
      })

    pessoa
  end

  defp membro_com_trabalho(ctx) do
    pessoa = pessoa_que_so_trabalhou(ctx)

    {:ok, equipe} =
      EO.upsert_team_from_source(ctx.tenant, %{
        name: "equipe",
        slug: "equipe",
        type: "organizational_team",
        organization_external_id: ctx.cenario.organization.external_id,
        source_system: "github",
        source_instance: "https://github.com",
        external_id: "T_1",
        collected_at: DateTime.utc_now(:second)
      })

    {:ok, _} =
      EO.record_team_membership_evidence(ctx.tenant, %{
        team_id: equipe.id,
        person_id: pessoa.id,
        platform_access_level: "MEMBER",
        source_system: "github",
        source_instance: "https://github.com",
        person_external_id: "U_sofia",
        team_external_id: "T_1",
        collected_at: DateTime.utc_now(:second),
        observed_at: DateTime.utc_now(:second)
      })

    %{pessoa: pessoa, equipe: equipe}
  end
end
