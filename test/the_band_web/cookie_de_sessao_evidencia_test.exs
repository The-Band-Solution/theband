defmodule TheBandWeb.CookieDeSessaoEvidenciaTest do
  @moduledoc """
  As afirmações da R1 do `research.md`, executadas em vez de argumentadas.

  Em 2026-09-12 escrevi na spec 064 — e num PR que já foi mergeado — que *"quem lê um dump se
  passa por qualquer sessão viva"*. Corrigi em 2026-09-13 depois de ler o caminho. Este
  arquivo existe porque leitura de código é o que me levou ao erro da primeira vez: aqui cada
  frase da correção vira um teste que passa ou falha.

  As quatro afirmações sob teste:

    1. o cookie de sessão é **assinado, não cifrado** — o conteúdo se lê sem chave nenhuma;
    2. ter o valor do banco **não basta**: sem a chave, a sessão forjada é recusada;
    3. ter o valor do banco **com** a chave **basta**: a sessão forjada é aceita — é a
       severidade real, e ela não é zero;
    4. o `session_token` **não gira no login**, que é o que impede resumi-lo como está.
  """

  use TheBandWeb.ConnCase, async: true

  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageVerifier
  alias TheBand.Tenants
  alias TheBand.Tenants.Auth

  @salt_de_assinatura "uG5K6D7b"
  @senha "senha-de-teste-longa"

  setup do
    {tenant, _admin} = tenant_with_admin()

    {:ok, user} =
      Tenants.create_user(tenant, %{
        "email" => "evidencia-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    # A senha é definida aqui porque o `session_token` só existe depois de a conta ter
    # passado por um ato que o gere — e é o token que estes testes medem.
    {:ok, user} = Tenants.set_password(tenant, user.id, @senha)

    {:ok, tenant: tenant, user: user}
  end

  # Monta o cookie EXATAMENTE como `Plug.Session.COOKIE.put/4` monta quando
  # `encryption_salt` é nil: `term_to_binary` e `MessageVerifier.sign/2`, com a chave
  # derivada por PBKDF2 (1000 iterações, 32 bytes, sha256 — os padrões do plug).
  defp cookie_forjado(dados, chave_base) do
    chave =
      KeyGenerator.generate(chave_base, @salt_de_assinatura,
        iterations: 1000,
        length: 32,
        digest: :sha256
      )

    dados
    |> :erlang.term_to_binary()
    |> MessageVerifier.sign(chave)
  end

  defp chave_real, do: Application.fetch_env!(:the_band, TheBandWeb.Endpoint)[:secret_key_base]

  defp com_cookie(conn, valor), do: put_req_header(conn, "cookie", "_the_band_key=#{valor}")

  describe "afirmação 1 — o cookie é ASSINADO, e não cifrado" do
    test "o conteúdo se lê sem chave nenhuma", %{user: user} do
      cookie =
        cookie_forjado(
          %{"user_id" => user.id, "session_token" => user.session_token},
          chave_real()
        )

      # `MessageVerifier.sign` produz "cabecalho.payload.assinatura" (plug_crypto
      # `hmac_sha2_sign/3`). O MEIO é Base64 do termo, **sem cifra nenhuma**: decodifica
      # com uma linha, sem chave, sem segredo.
      ["SFMyNTY", payload, _assinatura] = String.split(cookie, ".", parts: 3)
      {:ok, bruto} = Base.url_decode64(payload, padding: false)
      lido = Plug.Crypto.non_executable_binary_to_term(bruto, [:safe])

      # ISTO é o que "assinado, não cifrado" significa, e é verificável:
      assert lido["session_token"] == user.session_token
      assert lido["user_id"] == user.id
    end
  end

  describe "afirmação 2 — o valor do banco SOZINHO não abre sessão" do
    test "com a chave errada, a sessão forjada é recusada", %{conn: conn, user: user} do
      # Quem leu o dump tem exatamente isto: o `session_token` e o `user_id`. Nada mais.
      outra_chave = String.duplicate("x", 64)

      cookie =
        cookie_forjado(
          %{"user_id" => user.id, "session_token" => user.session_token},
          outra_chave
        )

      conn = conn |> com_cookie(cookie) |> get(~p"/people")

      # Devolvido à entrada: a assinatura não confere, e o Plug descarta a sessão inteira.
      assert redirected_to(conn) == ~p"/sign-in"
    end
  end

  describe "afirmação 3 — o valor do banco COM a chave abre" do
    test "a sessão forjada com a chave real é aceita", %{conn: conn, user: user} do
      cookie =
        cookie_forjado(
          %{"user_id" => user.id, "session_token" => user.session_token},
          chave_real()
        )

      conn = conn |> com_cookie(cookie) |> get(~p"/people")

      # NÃO foi devolvido à entrada. É a severidade real da FR-004: a coluna em claro é
      # metade de uma credencial, e a outra metade vive no ambiente.
      assert conn.status == 200
      assert conn.assigns.current_user.id == user.id
    end

    test "e o que a FR-004 quer: com o RESUMO no lugar do bruto, não abre", %{
      conn: conn,
      user: user
    } do
      # Isto ANTECIPA o desenho do plano. Hoje o banco guarda o bruto; depois guardará o
      # resumo. Quem ler o banco terá isto — e isto não serve nem com a chave real.
      resumo = :crypto.hash(:sha256, user.session_token) |> Base.encode16(case: :lower)

      cookie = cookie_forjado(%{"user_id" => user.id, "session_token" => resumo}, chave_real())

      conn = conn |> com_cookie(cookie) |> get(~p"/people")

      assert redirected_to(conn) == ~p"/sign-in"
    end
  end

  describe "afirmação 4 — o token NÃO gira no login" do
    test "duas entradas seguidas devolvem o mesmo token", %{user: user} do
      antes = user.session_token

      {:ok, primeira} = Auth.authenticate(user.email, @senha)
      {:ok, segunda} = Auth.authenticate(user.email, @senha)

      # É o que `auth.ex:190-192` diz por escrito, e o que impede resumir a coluna como
      # está: um login novo precisaria do BRUTO para pôr no cookie, e o banco teria o
      # resumo. Regenerar a cada login derrubaria as outras sessões.
      assert primeira.session_token == antes
      assert segunda.session_token == antes
    end

    test "mas a troca de senha gira — por isso a época precisa sobreviver ao plano",
         %{tenant: tenant, user: user} do
      antes = user.session_token

      {:ok, depois} = Tenants.set_password(tenant, user.id, "outra-senha-bem-longa")

      assert depois.session_token != antes
    end
  end
end
