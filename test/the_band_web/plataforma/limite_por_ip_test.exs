defmodule TheBandWeb.Plataforma.LimitePorIpTest do
  @moduledoc """
  O limite por origem nas quatro portas públicas do operador — spec 077, T009; a tarefa #1106
  (070/T043). FR-001..FR-004; seguranca.md, L7, L9; Q5, Q19, e o `Feita quando` da #1106: a
  décima primeira falha de uma origem é recusada com a recusa única; outra origem continua
  entrando; um `X-Forwarded-For` forjado pelo cliente não muda a origem contada.

  Síncrono: um dos testes troca `config :the_band, :origem`, que é global.
  """
  use TheBandWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import TheBand.OperadorFixtures

  alias TheBand.Origem
  alias TheBand.Origem.Configuracao
  alias TheBand.Segredo

  @limite 10
  @senha senha_do_operador()

  defp de(ip, cabecalhos \\ []) do
    Enum.reduce(cabecalhos, %{build_conn() | remote_ip: ip}, fn {k, v}, c ->
      put_req_header(c, k, v)
    end)
  end

  defp entrar(conn, email, senha, segundo_fator),
    do:
      post(conn, ~p"/platform/session", %{
        "email" => email,
        "password" => senha,
        "second_factor_token" => segundo_fator
      })

  defp inexistente, do: "ninguem-#{System.unique_integer([:positive])}@example.org"

  defp esgotar(ip, cabecalhos \\ []),
    do: for(_ <- 1..@limite, do: entrar(de(ip, cabecalhos), inexistente(), "errada", "000000"))

  # A página sem o que muda a cada resposta por natureza: os tokens de CSRF.
  defp pagina(conn) do
    corpo =
      conn.resp_body
      |> String.replace(
        ~r/content="[^"]+" name="csrf-token"|name="csrf-token" content="[^"]+"/,
        ""
      )
      |> String.replace(~r/name="_csrf_token" value="[^"]+"/, "")

    cabecalhos =
      conn.resp_headers
      |> Enum.reject(fn {k, _} -> k in ["set-cookie", "x-request-id"] end)
      |> Enum.sort()

    {conn.status, cabecalhos, corpo}
  end

  defp contar_hashes(fun) do
    eu = self()
    ref = make_ref()

    :telemetry.attach(
      {__MODULE__, ref},
      [:the_band, :platform, :custo_do_hash],
      fn _, _, _, _ ->
        send(eu, {ref, :hash})
      end,
      nil
    )

    resultado = capture_log(fun)
    :telemetry.detach({__MODULE__, ref})
    {resultado, contar(ref, 0)}
  end

  defp contar(ref, n) do
    receive do
      {^ref, :hash} -> contar(ref, n + 1)
    after
      0 -> n
    end
  end

  setup do
    {op, segredo} = operador_pronto()
    %{op: op, segredo: segredo}
  end

  test "a 11.ª falha em /platform/session é a mesma página, e nem a credencial certa entra",
       ctx do
    ip = {192, 0, 2, 31}

    capture_log(fn ->
      decima = esgotar(ip) |> List.last()
      email = "mesmo-#{System.unique_integer([:positive])}@example.org"
      comum = entrar(de({192, 0, 2, 39}), email, "errada", "000000")
      pelo_limite = entrar(de(ip), email, "errada", "000000")

      assert decima.status == 422
      assert pagina(pelo_limite) == pagina(comum)

      certa = entrar(de(ip), ctx.op.email, @senha, Segredo.expor(totp(ctx.segredo)))
      assert html_response(certa, 422) =~ "Not signed in."
      refute Map.has_key?(certa.resp_cookies, "_the_band_operator")
    end)
  end

  test "outra origem continua entrando", ctx do
    capture_log(fn -> esgotar({192, 0, 2, 32}) end)

    conn = entrar(de({192, 0, 2, 33}), ctx.op.email, @senha, Segredo.expor(totp(ctx.segredo)))
    assert redirected_to(conn) == ~p"/platform/organizations"
  end

  test "as quatro portas dividem o balde, e cada uma recusa com a sua recusa" do
    ip = {192, 0, 2, 34}
    r = pelo_caminho_real(:concedido)

    capture_log(fn ->
      esgotar(ip)

      definicao =
        post(de(ip), ~p"/platform/setup", %{
          "email" => r.email,
          "setup_token" => Segredo.expor(r.definicao),
          "password" => @senha,
          "password_confirmation" => @senha
        })

      assert html_response(definicao, 422) =~ "The email or setup code was not accepted."

      segundo =
        post(de(ip), ~p"/platform/setup/second-factor", %{
          "email" => r.email,
          "enrollment_token" => "qualquer",
          "second_factor_token" => "000000"
        })

      assert html_response(segundo, 422) =~ "Authenticator not confirmed."

      codigos =
        post(de(ip), ~p"/platform/setup/recovery-codes", %{
          "email" => r.email,
          "acknowledgement_token" => "qualquer",
          "codes_stored" => "true"
        })

      assert html_response(codigos, 422) =~ "Setup not finished."

      # O código de definição NÃO foi gasto pela recusa por limite: de outra origem, vale.
      outra =
        post(de({192, 0, 2, 35}), ~p"/platform/setup", %{
          "email" => r.email,
          "setup_token" => Segredo.expor(r.definicao),
          "password" => @senha,
          "password_confirmation" => @senha
        })

      assert html_response(outra, 200) =~ "This secret is shown once."
    end)
  end

  test "Q5 — a recusa por limite não paga custo de hash, e a comum paga", ctx do
    ip = {192, 0, 2, 36}
    capture_log(fn -> esgotar(ip) end)

    {_, comum} = contar_hashes(fn -> entrar(de({192, 0, 2, 37}), inexistente(), "x", "0") end)
    assert comum >= 1

    {_, pelo_limite} =
      contar_hashes(fn ->
        entrar(de(ip), ctx.op.email, @senha, Segredo.expor(totp(ctx.segredo)))
      end)

    assert pelo_limite == 0
  end

  test "Q19 — confirmação diferente no limite: a recusa de sempre, e o contador não sobe" do
    ip = {192, 0, 2, 38}
    chave = Origem.de_endereco(ip, :socket).chave
    capture_log(fn -> esgotar(ip) end)
    antes = :ets.match_object(:limite_por_origem, {{:operador, chave, :_}, :_})

    conn =
      post(de(ip), ~p"/platform/setup", %{
        "email" => inexistente(),
        "setup_token" => "qualquer",
        "password" => @senha,
        "password_confirmation" => @senha <> "-outra"
      })

    assert html_response(conn, 422) =~ "The two passwords do not match."
    assert :ets.match_object(:limite_por_origem, {{:operador, chave, :_}, :_}) == antes
  end

  test "com a origem pelo socket, um X-Forwarded-For forjado não muda a origem contada", ctx do
    ip = {192, 0, 2, 40}

    capture_log(fn ->
      esgotar(ip, [
        {"x-forwarded-for", "203.0.113.#{System.unique_integer([:positive]) |> rem(250)}"}
      ])

      forjado =
        entrar(
          de(ip, [{"x-forwarded-for", "203.0.113.200"}]),
          ctx.op.email,
          @senha,
          Segredo.expor(totp(ctx.segredo))
        )

      assert html_response(forjado, 422) =~ "Not signed in."
    end)
  end

  describe "com a origem pelo proxy" do
    setup do
      antes = Application.get_env(:the_band, :origem)
      on_exit(fn -> Application.put_env(:the_band, :origem, antes) end)

      Application.put_env(
        :the_band,
        :origem,
        Configuracao.ler!(%{
          "THE_BAND_ORIGEM" => "proxy",
          "THE_BAND_ORIGEM_CABECALHO" => "x-forwarded-for",
          "THE_BAND_ORIGEM_PROXIES" => "10.0.1.0/24"
        })
      )

      :ok
    end

    test "o valor forjado à esquerda muda a cada tentativa, e a origem contada é a do proxy",
         ctx do
      proxy = {10, 0, 1, 5}

      capture_log(fn ->
        for i <- 1..@limite do
          entrar(
            de(proxy, [{"x-forwarded-for", "203.0.113.#{i}, 198.51.100.9"}]),
            inexistente(),
            "errada",
            "000000"
          )
        end

        conn =
          entrar(
            de(proxy, [{"x-forwarded-for", "203.0.113.99, 198.51.100.9"}]),
            ctx.op.email,
            @senha,
            Segredo.expor(totp(ctx.segredo))
          )

        assert html_response(conn, 422) =~ "Not signed in."

        outro =
          entrar(
            de(proxy, [{"x-forwarded-for", "203.0.113.99, 198.51.100.10"}]),
            ctx.op.email,
            @senha,
            Segredo.expor(totp(ctx.segredo))
          )

        assert redirected_to(outro) == ~p"/platform/organizations"
      end)
    end
  end
end
