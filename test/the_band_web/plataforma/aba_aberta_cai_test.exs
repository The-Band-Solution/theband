defmodule TheBandWeb.Plataforma.AbaAbertaCaiTest do
  @moduledoc """
  A aba aberta cai junto com a suspensão — spec 070, T053 (cenários 5 e 6 de
  `seguranca-autenticacao.md`; A2). O `200` do HTTP não diz o que o socket faz (lição L85).

  O ato é chamado direto, por `Platform.suspender/3`: o aviso depois do `commit` vive no contexto, e
  o controller só o chama (achado O4).
  """
  use TheBandWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import TheBand.SuspensaoFixtures

  alias TheBand.Platform
  alias TheBand.Tenants

  defp aba(tenant) do
    {:ok, u} =
      Tenants.create_user(tenant, %{
        "email" => "a-#{System.unique_integer([:positive])}@example.test",
        "role" => "admin"
      })

    {:ok, view, _} = build_conn() |> log_in(u) |> live(~p"/people")
    view
  end

  defp evento(view), do: render_change(view, "buscar", %{"q" => "", "tabela" => "people"})

  test "suspender A leva a aba de A à entrada, o evento seguinte não executa, e B continua" do
    {_op, sessao_op} = sessao_de_operador()
    a = tenant_fixture()
    b = tenant_fixture()
    aba_a = aba(a)
    aba_b = aba(b)

    capture_log(fn ->
      {:ok, _} = Platform.suspender(sessao_op, a.slug, %{reason: "contract_ended"})
    end)

    assert_redirect(aba_a, "/sign-in")
    catch_exit(evento(aba_a))

    assert evento(aba_b) =~ "people"
  end
end
