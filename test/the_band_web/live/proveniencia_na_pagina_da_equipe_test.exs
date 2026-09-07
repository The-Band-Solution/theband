defmodule TheBandWeb.ProvenienciaNaPaginaDaEquipeTest do
  @moduledoc """
  A proveniência da equipe mora na página dela, e não na lista — 2026-09-06.

  Pedido da pessoa mantenedora ao avaliar a tela: origem, identificador na origem e data de
  coleta saem das colunas de `/teams` e passam a aparecer em `/teams/:id`. O dado não muda;
  muda onde ele é lido.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    org = organization_fixture(tenant, "acme")

    team =
      team_fixture(tenant, "T_kwDOCqjXps4A4YOn", %{
        name: "DADOS",
        slug: "dados",
        organization: org,
        collected_at: ~U[2026-09-04 04:00:50Z],
        last_observed_at: ~U[2026-09-06 22:54:26Z]
      })

    %{conn: log_in(conn, user), tenant: tenant, team: team}
  end

  test "a lista NÃO mostra origem, identificador na origem nem data de coleta", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/teams")

    assert html =~ "DADOS"

    refute html =~ "identifier at source", """
    A coluna voltou à lista. Ela dizia, em cinquenta linhas, o que ninguém compara entre
    equipes — um id opaco — e foi movida para a página da equipe em 2026-09-06.
    """

    refute html =~ "T_kwDOCqjXps4A4YOn", "o identificador na origem é da página da equipe"
    refute html =~ "collected at", "a data de coleta é da página da equipe"
  end

  test "a página da equipe mostra a proveniência inteira", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/teams/#{ctx.team.id}")

    assert html =~ "identifier at source"

    assert html =~ "T_kwDOCqjXps4A4YOn",
           "o identificador na origem, que saiu da lista, tem de estar aqui"

    # O valor exibido é o do REGISTRO, e não o que a fixture pediu: a escrita pela origem
    # decide `collected_at`, e a página mostra o que está gravado.
    gravada = TheBand.Repo.get!(TheBand.Ontology.SEON.EO.Schemas.Team, ctx.team.id)
    assert html =~ "collected at"

    trecho = html |> String.split("collected at") |> Enum.at(1, "") |> String.slice(0, 160)

    # HEEx renderiza DateTime em ISO 8601 (`2026-09-04T04:00:50Z`), e não como `to_string/1`.
    assert html =~ DateTime.to_iso8601(gravada.collected_at), """
    O registro tem collected_at=#{gravada.collected_at}; a página mostra, depois do rótulo:
    #{inspect(trecho)}
    """

    assert html =~ "github", "a origem é nomeada, e não só o identificador"
  end
end
