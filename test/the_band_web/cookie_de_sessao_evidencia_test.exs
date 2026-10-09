defmodule TheBandWeb.CookieDeSessaoEvidenciaTest do
  @moduledoc """
  As afirmações da R1 do `research.md`, executadas em vez de argumentadas.

  Em 2026-09-12 escrevi na spec 064 — e num PR que já foi mergeado — que *"quem lê um dump se
  passa por qualquer sessão viva"*. Corrigi em 2026-09-13 depois de ler o caminho. Este
  arquivo existe porque leitura de código é o que me levou ao erro da primeira vez: aqui cada
  frase da correção vira um teste que passa ou falha.

  **Reescrito na T013 (2026-09-29).** A afirmação 3 media a severidade: com o valor do banco e a
  chave real, a sessão forjada **era aceita**. Agora ela mede a correção: o que o banco guarda,
  mesmo com a chave real, **não abre**. E tem o par positivo, sem o qual o "não abre" não
  mediria nada: o bruto, com a mesma chave, abre.

    1. o cookie de sessão é **assinado, não cifrado** — o conteúdo se lê sem chave nenhuma;
    2. sem a chave, nem o bruto abre sessão;
    3. com a chave real, **o que o banco guarda não abre**; o bruto, que só o cookie tem, abre;
    4. cada entrada abre uma sessão **nova**, com token próprio, e não derruba as outras.
  """

  use TheBandWeb.ConnCase, async: true

  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageVerifier
  import Ecto.Query, only: [from: 2]

  alias TheBand.Repo
  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.UserSession

  @salt_de_assinatura "uG5K6D7b"
  @senha "senha-de-teste-longa"

  setup do
    {tenant, _admin} = tenant_with_admin()

    {:ok, user} =
      Tenants.create_user(tenant, %{
        "email" => "evidencia-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    # A senha é definida aqui para a entrada de verdade poder abrir a sessão.
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

  # O que um dump de `user_sessions` entrega: o id e o resumo. Nada mais.
  defp do_banco(user) do
    Repo.one!(
      from(s in UserSession,
        where: s.user_id == ^user.id and is_nil(s.ended_at),
        order_by: [desc: s.inserted_at],
        limit: 1
      )
    )
  end

  # Abre a sessão pela entrada de verdade, e devolve o que o cookie leva.
  defp entrar(user) do
    conn = post(build_conn(), ~p"/session", %{"identifier" => user.email, "password" => @senha})
    {get_session(conn, "session_id"), get_session(conn, "session_secret")}
  end

  describe "afirmação 1 — o cookie é ASSINADO, e não cifrado" do
    test "o conteúdo se lê sem chave nenhuma", %{user: user} do
      {id, bruto} = entrar(user)
      cookie = cookie_forjado(%{"session_id" => id, "session_secret" => bruto}, chave_real())

      # `MessageVerifier.sign` produz "cabecalho.payload.assinatura" (plug_crypto
      # `hmac_sha2_sign/3`). O MEIO é Base64 do termo, **sem cifra nenhuma**.
      ["SFMyNTY", payload, _assinatura] = String.split(cookie, ".", parts: 3)
      {:ok, termo} = Base.url_decode64(payload, padding: false)
      lido = Plug.Crypto.non_executable_binary_to_term(termo, [:safe])

      assert lido["session_secret"] == bruto
      assert lido["session_id"] == id
    end
  end

  describe "afirmação 2 — sem a chave, nem o bruto abre" do
    test "com a chave errada, a sessão forjada é recusada", %{conn: conn, user: user} do
      {id, bruto} = entrar(user)

      cookie =
        cookie_forjado(
          %{"session_id" => id, "session_secret" => bruto},
          String.duplicate("x", 64)
        )

      conn = conn |> com_cookie(cookie) |> get(~p"/people")
      assert redirected_to(conn) == ~p"/sign-in"
    end
  end

  describe "afirmação 3 — com a chave real, o que o BANCO guarda não abre" do
    test "o id e o resumo, lidos do banco, com a chave real: recusado", %{conn: conn, user: user} do
      entrar(user)
      linha = do_banco(user)

      # Quem leu o dump tem isto, nas duas formas em que o resumo pode ser escrito.
      for resumo <- [linha.token_hash, Base.encode16(linha.token_hash, case: :lower)] do
        cookie =
          cookie_forjado(%{"session_id" => linha.id, "session_secret" => resumo}, chave_real())

        conn = conn |> recycle() |> com_cookie(cookie) |> get(~p"/people")
        assert redirected_to(conn) == ~p"/sign-in"
      end

      # E o cookie do formato antigo, com o que `users.session_token` guardava: também não.
      # A coluna antiga ainda existe até a T014b, e a plataforma não a escreve desde a T014a. O
      # valor vem por SQL, como o dump de um banco anterior o traria.
      antigo = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      Repo.query!("UPDATE users SET session_token = $1 WHERE id = $2", [
        antigo,
        Ecto.UUID.dump!(user.id)
      ])

      cookie =
        cookie_forjado(%{"user_id" => user.id, "session_token" => antigo}, chave_real())

      assert redirected_to(conn |> recycle() |> com_cookie(cookie) |> get(~p"/people")) ==
               ~p"/sign-in"
    end

    test "o par positivo: o bruto, com a mesma chave, abre", %{conn: conn, user: user} do
      {id, bruto} = entrar(user)
      cookie = cookie_forjado(%{"session_id" => id, "session_secret" => bruto}, chave_real())

      conn = conn |> com_cookie(cookie) |> get(~p"/people")

      # Sem este, a recusa acima passaria também numa conferência que recusasse tudo.
      assert conn.status == 200
      assert conn.assigns.current_user.id == user.id
    end
  end

  describe "afirmação 4 — cada entrada abre uma sessão nova" do
    test "duas entradas, dois tokens, e as duas valem", %{user: user} do
      {id_a, bruto_a} = entrar(user)
      {id_b, bruto_b} = entrar(user)

      refute id_a == id_b
      refute bruto_a == bruto_b

      for {id, bruto} <- [{id_a, bruto_a}, {id_b, bruto_b}] do
        cookie = cookie_forjado(%{"session_id" => id, "session_secret" => bruto}, chave_real())
        assert build_conn() |> com_cookie(cookie) |> get(~p"/people") |> Map.get(:status) == 200
      end
    end
  end
end
