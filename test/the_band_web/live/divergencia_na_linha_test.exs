defmodule TheBandWeb.DivergenciaNaLinhaTest do
  @moduledoc """
  A divergência na linha da tabela — 065/US2, emendada em 2026-09-30 (issue #905). Protótipo
  aprovado em `specs/065-rotulos-no-item/prototipo/divergences-row.html`.

  Os dois lados são o **tipo declarado** e o **conceito derivado**. O rótulo não é um dos lados:
  é contexto, e fica na coluna dele. Cada linha diz o porquê e o lado seguido, pela mesma regra
  do cartão agregado.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Repo
  alias TheBand.WorkItems
  alias TheBand.WorkItems.Schemas.CollectedIssue
  alias TheBand.WorkItems.Schemas.IssuePromotion

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  # Faz a issue divergir, do jeito que a promoção grava: o tipo na origem, o conceito derivado e
  # o tipo da divergência.
  defp divergir(issue, tipo_na_origem, conceito, tipo_da_divergencia) do
    Repo.update_all(from(i in CollectedIssue, where: i.id == ^issue.id),
      set: [issue_type: tipo_na_origem]
    )

    Repo.update_all(from(p in IssuePromotion, where: p.collected_issue_id == ^issue.id),
      set: [
        derived_concept: conceito,
        divergence_kind: tipo_da_divergencia,
        # O banco exige o motivo junto do tipo (`issue_promotions_divergence_kind_needs_reason`).
        divergence_reason: "divergência montada pelo teste"
      ]
    )
  end

  # O bloco da divergência de uma linha, para as asserções não casarem texto de outra.
  defp bloco(html, numero) do
    [_, linha] = String.split(html, "issue ##{numero}", parts: 2)
    [_, depois] = String.split(linha, "≠ diverges · type and structure", parts: 2)
    depois |> String.split("</td>", parts: 2) |> hd()
  end

  test "user story sem partes: os dois lados, o porquê, e o lado seguido é o declarado", ctx do
    issue = ctx.cenario.issues[201].pai
    divergir(issue, "Feature", "sro.atomic_user_story", "user_story_without_parts")

    {:ok, 1} =
      WorkItems.replace_labels(ctx.tenant, issue.id, [%{name: "backend", color: "111111"}])

    {:ok, _live, html} = live(ctx.conn, ~p"/work")
    b = bloco(html, 201)

    assert b =~ "declared type · claim"
    assert b =~ "Feature"
    assert b =~ "derived concept · verdict"
    assert b =~ "why: no parts and no tasks are linked to it"
    assert b =~ "followed: the declared type"
    assert b =~ "concept kept, flagged as a signal"
    # O rótulo é contexto: não entra no bloco da divergência.
    refute b =~ "backend"
  end

  test "épico sem partes: o lado seguido é a estrutura, como no cartão", ctx do
    issue = ctx.cenario.issues[201].pai
    divergir(issue, "Epic", "sro.atomic_user_story", "epic_without_parts")

    {:ok, _live, html} = live(ctx.conn, ~p"/work")
    b = bloco(html, 201)

    assert b =~ "Epic"
    assert b =~ "why: typed Epic, and it has no parts"
    assert b =~ "followed: the structure"
    assert b =~ "concept decided by the axiom"
  end

  test "a página do repositório mostra o mesmo bloco", ctx do
    issue = ctx.cenario.issues[201].pai
    divergir(issue, "Feature", "sro.atomic_user_story", "user_story_without_parts")

    {:ok, _live, html} =
      live(ctx.conn, ~p"/work/repositories/#{ctx.cenario.observed_repository_id}")

    b = bloco(html, 201)

    assert b =~ "followed: the declared type"
    assert b =~ "why: no parts and no tasks are linked to it"
  end

  test "sem divergência nenhuma, o cartão diz que o tipo declarado e a estrutura concordam",
       ctx do
    Repo.update_all(from(p in IssuePromotion, where: p.tenant_id == ^ctx.tenant.id),
      set: [divergence_kind: nil, divergence_reason: nil]
    )

    {:ok, _live, html} = live(ctx.conn, ~p"/work")
    assert html =~ "None. Declared type and structure agree on every issue."
    refute html =~ "Label and structure agree"
  end
end
