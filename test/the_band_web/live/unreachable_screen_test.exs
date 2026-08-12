defmodule TheBandWeb.UnreachableScreenTest do
  @moduledoc """
  A lista diz desde quando não se alcança, e por quê (T009).

  `unreachable` sozinho lê como abandono — e **era verdade** até a feature 009: o repositório
  marcado era filtrado antes da fase que limparia a marca.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Ontology.KnowledgeBase
  alias TheBand.Ontology.SEON.CMPO

  @motivo_real "the tool refused the query: Something went wrong while executing your query on " <>
                 "2026-08-12T12:32:30Z. Please include `6D2F:110188:1CD8DB0:1D79ED0:6A7C67D3` " <>
                 "when reporting this issue."

  setup %{conn: conn} do
    {:ok, _} = KnowledgeBase.load()
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  test "a linha diz desde quando e o motivo", ctx do
    {:ok, _} =
      CMPO.mark_inaccessible(ctx.tenant, ctx.cenario.observed_repository_id, @motivo_real)

    {:ok, _live, html} = live(ctx.conn, ~p"/work")

    assert html =~ "unreachable since", """
    A linha diz apenas `unreachable`, e quem lê não sabe se é de agora ou de dez dias — nem se a
    plataforma ainda tenta. Até a feature 009 ela não tentava, e a leitura estava certa.
    """

    assert html =~ "Something went wrong", """
    O motivo precisa aparecer: é ele que diz se alguém age. DNS que não resolveu se cura
    tentando de novo; credencial revogada, não — e é a distinção que custou 899 issues (L29).
    """
  end

  test "o motivo é truncado na exibição, com o texto completo no title", ctx do
    {:ok, _} =
      CMPO.mark_inaccessible(ctx.tenant, ctx.cenario.observed_repository_id, @motivo_real)

    {:ok, _live, html} = live(ctx.conn, ~p"/work")

    assert html =~ "…", """
    O motivo real tem #{String.length(@motivo_real)} caracteres. Sem truncar, ele domina a linha
    numa tabela de 135 repositórios.
    """

    assert html =~ ~s(title="#{@motivo_real}") or html =~ "6D2F", """
    O texto completo precisa continuar alcançável — truncar na tela não é esconder.
    """
  end

  test "a frase sobre tentar de novo aparece uma vez, não uma por linha", ctx do
    {:ok, _} = CMPO.mark_inaccessible(ctx.tenant, ctx.cenario.observed_repository_id, "falhou")

    {:ok, _live, html} = live(ctx.conn, ~p"/work")

    ocorrencias =
      html |> String.split("tries again on every collection") |> length() |> Kernel.-(1)

    assert ocorrencias == 1, """
    A frase apareceu #{ocorrencias} vezes.

    Ela entra **uma** vez, no cabeçalho da seção: repetir por linha gastaria a atenção que o
    motivo de cada repositório precisa ter — e no dado real seriam 39 repetições.
    """
  end

  test "sem repositório inacessível, a frase não aparece", ctx do
    {:ok, _live, html} = live(ctx.conn, ~p"/work")

    refute html =~ "tries again on every collection", """
    A frase apareceu sem haver repositório inacessível. Um aviso permanente sobre um problema que
    não existe treina quem lê a ignorá-lo.
    """
  end

  test "o estado continua legível com a cor removida", ctx do
    {:ok, _} = CMPO.mark_inaccessible(ctx.tenant, ctx.cenario.observed_repository_id, "falhou")

    {:ok, _live, html} = live(ctx.conn, ~p"/work")

    sem_cor = String.replace(html, ~r/class="[^"]*"/, "")

    assert sem_cor =~ "unreachable since", """
    O estado desapareceu quando as classes foram removidas, o que significa que ele estava
    carregado por cor. O design system exige texto — WCAG 1.4.1.
    """
  end
end
