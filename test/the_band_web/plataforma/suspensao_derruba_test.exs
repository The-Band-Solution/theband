defmodule TheBandWeb.Plataforma.SuspensaoDerrubaTest do
  @moduledoc """
  Suspender derruba sessões e tokens, e reativar não devolve nada — spec 070, T051 (o teste
  independente da US1; SC-001; quickstart §4). Pelas telas: o operador suspende e reativa por
  `POST`, e o cookie e o token de antes são enviados como o navegador e o cliente os enviariam.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Tenants

  defp membro(tenant) do
    {:ok, u} =
      Tenants.create_user(tenant, %{
        "email" => "m-#{System.unique_integer([:positive])}@example.test",
        "role" => "admin"
      })

    {:ok, _t, valor} = Tenants.create_api_token(tenant, u, %{label: "painel"}, u)
    %{cookie: log_in(build_conn(), u), token: valor, user: u}
  end

  defp tela(%{cookie: c}), do: get(c, ~p"/people")

  defp abertas(%{user: u}),
    do:
      TheBand.Repo.all(
        from(s in TheBand.Tenants.Schemas.UserSession,
          where: s.user_id == ^u.id and is_nil(s.ended_at)
        )
      )

  defp api(%{token: v}),
    do: build_conn() |> put_req_header("authorization", "Bearer " <> v) |> get("/api/v1/people")

  defp ato(op_conn, tenant, ato, razao) do
    capture_log(fn ->
      r =
        post(op_conn, "/platform/organizations/#{tenant.slug}/#{ato}", %{
          "reason" => razao,
          "confirm_slug" => tenant.slug
        })

      send(self(), {:ato, r.status})
    end)

    assert_received {:ato, 302}
  end

  test "o cookie e o token de antes caem na suspensão e continuam caídos na reativação; B fica" do
    {op, _} = operador_pronto()
    a = tenant_fixture()
    b = tenant_fixture()
    de_a = membro(a)
    de_b = membro(b)
    op_conn = log_in_operador(build_conn(), op)

    # Antes: os dois entram.
    assert html_response(tela(de_a), 200)
    assert api(de_a).status == 200

    ato(op_conn, a, "suspension", "contract_ended")

    # A sessão TERMINOU, e não só é recusada. O domínio já recusa organização suspensa (N5), e a
    # reativação encerra de novo: só o cookie não distinguiria a suspensão que encerra da que não
    # encerra (medido: com o passo `:sessoes` retirado, as duas asserções do cookie passavam).
    assert abertas(de_a) == []
    assert redirected_to(tela(de_a)) == ~p"/sign-in"
    assert api(de_a).status == 401

    ato(op_conn, a, "reactivation", "contract_resumed")
    assert redirected_to(tela(de_a)) == ~p"/sign-in"
    assert api(de_a).status == 401

    # B nunca caiu: a sessão e o token dela são mais de zero, e valem.
    assert html_response(tela(de_b), 200)
    assert api(de_b).status == 200
  end
end
