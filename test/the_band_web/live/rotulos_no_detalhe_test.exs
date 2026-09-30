defmodule TheBandWeb.RotulosNoDetalheTest do
  @moduledoc """
  Os rótulos no detalhe da issue — issue #904, 065/US1, defeito D1 do registro de aceitação
  (`docs/sprints/032-rotulos-no-item/aceitacao.md`).

  O teste independente da US1 é *"os mesmos rótulos aparecem ao abrir cada item"*. O defeito
  medido: a lista mostrava `backend` (observado) **e** `Devops` (derivado do título), e o
  detalhe mostrava só `backend`, sem origem. O protótipo aprovado em 2026-09-29 está em
  `specs/065-rotulos-no-item/prototipo/`.

  O controle é a **marca** (classe de sólido e de hachura) e a **linha de origem escrita**, e
  não só o nome: o nome também aparecia antes, sem a origem.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest
  import TheBand.WorkItemsFixtures

  alias TheBand.Repo
  alias TheBand.WorkItems
  alias TheBand.WorkItems.Schemas.CollectedIssue

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()
    cenario = cenario_real(tenant)
    %{conn: log_in(conn, user), tenant: tenant, cenario: cenario}
  end

  defp com_titulo(issue, titulo) do
    Repo.update_all(from(i in CollectedIssue, where: i.id == ^issue.id), set: [title: titulo])
  end

  defp detalhe(ctx, issue) do
    {:ok, _live, html} = live(ctx.conn, ~p"/work/issues/#{issue.id}")
    html
  end

  # O trecho do campo `labels`, para as asserções não casarem texto de outro lugar da página.
  # O `<dt>` do `<.field>` tem espaços em volta do rótulo, e por isso o corte é por regex.
  defp campo_labels(html) do
    [_, depois] = Regex.split(~r/>\s*labels\s*<\/dt>/, html, parts: 2)
    depois |> then(&Regex.split(~r/>\s*milestone\s*<\/dt>/, &1, parts: 2)) |> hd()
  end

  test "o rótulo do campo e o derivado do título aparecem, cada um com a sua origem", ctx do
    issue = ctx.cenario.issues[1].pai
    com_titulo(issue, "[Devops] Subir o pipeline")

    {:ok, 1} =
      WorkItems.replace_labels(ctx.tenant, issue.id, [%{name: "backend", color: "0e8a16"}])

    campo = ctx |> detalhe(issue) |> campo_labels()

    # As duas marcas: sólido para o campo, hachura com contorno para o título.
    assert campo =~
             ~r/bg-success text-success-content[^>]*title="observed — set on the label field at the source"/s

    assert campo =~ "backend"

    assert campo =~
             ~r/text-info outline[^>]*title="derived — read from the bracketed prefix in the title"/s

    assert campo =~ "Devops"

    # A origem ESCRITA, uma linha por origem (decisão Q1).
    assert campo =~ "set on the label field at the source</span>"
    assert campo =~ "read from the bracketed prefix <code>[Devops]</code> in the title"

    # O cinza de antes não volta.
    refute campo =~ "badge-ghost"
  end

  test "sem o corte de três da lista: todos os rótulos do campo aparecem", ctx do
    issue = ctx.cenario.issues[1].pai

    {:ok, 5} =
      WorkItems.replace_labels(
        ctx.tenant,
        issue.id,
        for(n <- ~w(a b c d e), do: %{name: "r-#{n}", color: "111111"})
      )

    campo = ctx |> detalhe(issue) |> campo_labels()
    for n <- ~w(a b c d e), do: assert(campo =~ "r-#{n}")
    refute campo =~ "+2"
  end

  test "sem rótulo nenhum, a ausência diz de quem é cada metade (decisão Q3)", ctx do
    issue = ctx.cenario.issues[1].pai
    com_titulo(issue, "[Portal ADM] Atualizar valores")
    {:ok, 0} = WorkItems.replace_labels(ctx.tenant, issue.id, [])

    campo = ctx |> detalhe(issue) |> campo_labels()

    assert campo =~ "no label"
    assert campo =~ "none on the label field at the source, and no declared prefix in the title"
    # `[Portal ADM]` não está na lista declarada, e não vira rótulo (FR-004).
    refute campo =~ "Portal ADM</span>"
  end
end
