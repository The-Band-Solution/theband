defmodule TheBandWeb.Plataforma.ListaDeOrganizacoesTest do
  @moduledoc """
  A lista de organizações do operador — spec 070, T040 (FR-007; US2, cenário 2).
  """
  use TheBandWeb.ConnCase, async: true

  import TheBand.OperadorFixtures

  alias TheBand.Ontology.SEON.EO

  defp pessoa(tenant, nome) do
    login = "p#{System.unique_integer([:positive])}"

    {:ok, _} =
      EO.upsert_person_from_source(tenant, %{
        login: login,
        name: nome,
        account_type: "person",
        source_system: "github",
        source_instance: "https://github.com",
        source_endpoint: "/users/#{login}",
        external_id: "U_#{login}",
        collected_at: DateTime.utc_now(:second),
        payload: %{"login" => login}
      })

    login
  end

  test "o operador vê nome, slug e estado de todas, e nada de domínio", %{conn: conn} do
    a = tenant_fixture()
    b = tenant_fixture()
    login_a = pessoa(a, "Pessoa Visivel Em A")
    login_b = pessoa(b, "Pessoa Visivel Em B")
    {op, _} = operador_pronto(name: "Rui Operador")

    html = conn |> log_in_operador(op) |> get(~p"/platform/organizations") |> html_response(200)

    for t <- [a, b] do
      assert html =~ t.name
      assert html =~ t.slug
    end

    assert html =~ "active"
    assert html =~ "Rui Operador"
    # D5: a linha que diz o que o operador não vê.
    assert html =~ ~r/You do not see its\s+people, teams, work or numbers\./

    for proibido <- ["Pessoa Visivel Em A", "Pessoa Visivel Em B", login_a, login_b],
        do: refute(html =~ proibido)
  end

  test "sem episódio, a última suspensão é escrita como ausência, e não em branco nem travessão",
       %{conn: conn} do
    tenant_fixture()
    {op, _} = operador_pronto()

    html = conn |> log_in_operador(op) |> get(~p"/platform/organizations") |> html_response(200)

    assert html =~ "never suspended"
    refute html =~ "—"
    assert html =~ ~s(data-label="last suspended")
  end
end
