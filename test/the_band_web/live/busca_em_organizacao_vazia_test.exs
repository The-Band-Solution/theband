defmodule TheBandWeb.BuscaEmOrganizacaoVaziaTest do
  @moduledoc """
  Buscar em `/people` numa organização sem pessoas não derruba a tela — issue #1041.

  `empty_message/3` não tinha a cláusula de busca preenchida, sem filtro de organização e
  sem pessoa coletada. Digitar qualquer coisa levantava `FunctionClauseError`.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "a busca numa organização vazia diz que nenhuma coleta trouxe pessoas", %{conn: conn} do
    {_tenant, admin} = tenant_with_admin()
    {:ok, view, _html} = conn |> log_in(admin) |> live(~p"/people")

    render_change(view, "buscar", %{"q" => "ana", "tabela" => "people"})

    assert render(view) =~ "No sync has brought people yet."
  end
end
