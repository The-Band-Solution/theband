defmodule TheBandWeb.CookieSecureTest do
  @moduledoc """
  O cookie de sessão sai com `Secure` em produção — issue #1008, achado S15 da avaliação
  `specs/064-segredo-em-repouso/seguranca-us2.md`.

  Produção não roda no teste. O que se mede são as duas metades: a configuração de produção
  **liga** a opção, e o endpoint **lê** essa configuração. Sem a segunda, a primeira seria um
  valor que ninguém usa, que é a forma do `tenants.status` que ninguém lia (H3).
  """
  use TheBandWeb.ConnCase, async: true

  test "a configuração de produção liga o Secure" do
    prod = Config.Reader.read!("config/config.exs", env: :prod)
    assert get_in(prod, [:the_band, :cookie_de_sessao_seguro]) == true
  end

  test "e as outras configurações não ligam, porque ali não há HTTPS" do
    for env <- [:dev, :test] do
      config = Config.Reader.read!("config/config.exs", env: env)
      refute get_in(config, [:the_band, :cookie_de_sessao_seguro])
    end
  end

  test "o endpoint compila a opção a partir da configuração, e não de um valor fixo" do
    assert Keyword.fetch!(TheBandWeb.Endpoint.session_options(), :secure) ==
             Application.get_env(:the_band, :cookie_de_sessao_seguro, false)

    fonte = File.read!("lib/the_band_web/endpoint.ex")
    assert fonte =~ "Application.compile_env(:the_band, :cookie_de_sessao_seguro, false)"
  end

  test "a entrada de verdade põe o cookie pelo endpoint, com a opção compilada", %{conn: conn} do
    {tenant, _admin} = tenant_with_admin()

    {:ok, user} =
      TheBand.Tenants.create_user(tenant, %{
        "email" => "secure-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, _} = TheBand.Tenants.set_password(tenant, user.id, "uma-senha-longa-o-bastante")

    conn =
      post(conn, ~p"/session", %{
        "identifier" => user.email,
        "password" => "uma-senha-longa-o-bastante"
      })

    # O cookie existe: sem isto, a flag abaixo seria lida de `nil` e o teste passaria sem medir.
    assert %{value: _} = cookie = conn.resp_cookies["_the_band_key"]

    # No teste a configuração é `false`, e a flag segue a configuração: é a mesma opção que em
    # produção sai `true`.
    assert Map.get(cookie, :secure, false) ==
             Keyword.fetch!(TheBandWeb.Endpoint.session_options(), :secure)
  end
end
