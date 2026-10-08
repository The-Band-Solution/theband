defmodule TheBandWeb.LimitePorOrigemNaEntradaTest do
  @moduledoc """
  O limite por origem em `POST /session` — spec 077, T008; o defeito #1229 (FR-001..FR-004,
  FR-010, FR-013; SC-001, SC-002, SC-004, SC-005; seguranca.md, Q1, Q2, Q3, Q5, Q6, Q20, Q22).

  Síncrono: lê os spans da 074 (`TheBand.Spans`), que são globais. Endereços de documentação.
  """
  use TheBandWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]

  alias TheBand.Origem
  alias TheBand.OrigemDeTeste
  alias TheBand.Spans
  alias TheBand.Tenants
  alias TheBand.Tenants.Schemas.UserSession

  @senha "senha-do-limite-comprida-1"
  @limite 10

  setup do
    :ok = Spans.ligar()
    {tenant, _admin} = tenant_with_admin()

    {:ok, user} =
      Tenants.create_user(tenant, %{
        "email" => "limite-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, user} = Tenants.set_password(tenant, user.id, @senha)
    Spans.recebidos(0)
    %{user: user}
  end

  defp tentar(ip, identificador, senha) do
    post(%{build_conn() | remote_ip: ip}, ~p"/session", %{
      "identifier" => identificador,
      "password" => senha
    })
  end

  defp inexistente, do: "ninguem-#{System.unique_integer([:positive])}@example.test"

  defp esgotar(ip), do: for(_ <- 1..@limite, do: tentar(ip, inexistente(), @senha))

  # O que a recusa diz, sem o que muda a cada resposta por natureza: o cookie de sessão (assinado,
  # com o correlator apagado) e o id da requisição.
  defp resposta(conn) do
    cabecalhos =
      conn.resp_headers
      |> Enum.reject(fn {k, _} -> k in ["set-cookie", "x-request-id"] end)
      |> Enum.sort()

    {conn.status, cabecalhos, Phoenix.Flash.get(conn.assigns.flash, :error), conn.resp_body}
  end

  # Conta, NA REQUISIÇÃO, os hashes da entrada e as consultas à tabela de contas.
  defp contar(fun) do
    eu = self()
    ref = make_ref()

    :telemetry.attach_many(
      {__MODULE__, ref},
      [[:the_band, :tenants, :custo_do_hash], [:the_band, :repo, :query]],
      fn evento, _, meta, _ -> send(eu, {ref, evento, meta}) end,
      nil
    )

    resultado = fun.()
    :telemetry.detach({__MODULE__, ref})
    eventos = coletar(ref, [])

    {resultado,
     %{
       hashes: Enum.count(eventos, fn {e, _} -> e == [:the_band, :tenants, :custo_do_hash] end),
       contas:
         Enum.count(eventos, fn {e, m} ->
           e == [:the_band, :repo, :query] and m[:source] == "users"
         end)
     }}
  end

  defp coletar(ref, acc) do
    receive do
      {^ref, e, m} -> coletar(ref, [{e, m} | acc])
    after
      0 -> acc
    end
  end

  test "Q1 — a 11.ª falha de uma origem é a mesma resposta da 10.ª, e o passo diz limite_por_origem" do
    ip = {192, 0, 2, 11}
    tentativas = esgotar(ip)
    decima = List.last(tentativas)
    Spans.recebidos(0)

    decima_primeira = tentar(ip, inexistente(), @senha)

    assert redirected_to(decima) == ~p"/sign-in"
    assert resposta(decima_primeira) == resposta(decima)

    assert [span] = Spans.do_passo(Spans.recebidos(), :entrar_com_senha)
    atributos = Spans.atributos(span)
    assert atributos["outcome"] == "falhou"
    assert atributos["failure.reason"] == "limite_por_origem"
    refute Map.has_key?(atributos, "user.ref")
    refute Map.has_key?(atributos, "tenant.id")
  end

  test "Q2 — a senha CERTA no limite recebe a mesma recusa, e a conta não entra nem muda", ctx do
    ip = {192, 0, 2, 12}
    esgotar(ip)
    antes = Repo.get!(Tenants.User, ctx.user.id)

    conn = tentar(ip, ctx.user.email, @senha)

    assert redirected_to(conn) == ~p"/sign-in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Credenciais inválidas."
    refute get_session(conn, "session_id")

    assert Repo.aggregate(from(s in UserSession, where: s.user_id == ^ctx.user.id), :count) == 0
    depois = Repo.get!(Tenants.User, ctx.user.id)
    assert depois.failed_attempts == antes.failed_attempts
    assert depois.last_failed_at == antes.last_failed_at
  end

  test "Q3 — com uma origem no limite, outra origem entra", ctx do
    ip = {192, 0, 2, 13}
    esgotar(ip)

    assert redirected_to(tentar({192, 0, 2, 14}, ctx.user.email, @senha)) == ~p"/people"
    assert redirected_to(tentar(ip, ctx.user.email, @senha)) == ~p"/sign-in"
  end

  test "Q5 — a recusa por limite não paga hash nem lê a tabela de contas" do
    ip = {192, 0, 2, 15}
    esgotar(ip)

    # A medida mede: a recusa comum paga o hash e lê contas.
    {_, comum} = contar(fn -> tentar({192, 0, 2, 16}, inexistente(), @senha) end)
    assert comum.hashes == 1
    assert comum.contas >= 1

    {_, pelo_limite} = contar(fn -> tentar(ip, inexistente(), @senha) end)
    assert pelo_limite == %{hashes: 0, contas: 0}
  end

  test "Q6 — a recusa por limite não põe a conta de ninguém em espera", ctx do
    ip = {192, 0, 2, 17}

    {:error, :invalid_credentials} =
      Tenants.authenticate(ctx.user.email, "errada-e-comprida-1", origem: OrigemDeTeste.nova())

    esgotar(ip)
    antes = Repo.get!(Tenants.User, ctx.user.id).failed_attempts
    assert antes == 1

    for _ <- 1..5, do: tentar(ip, ctx.user.email, "errada-e-comprida-1")

    assert Repo.get!(Tenants.User, ctx.user.id).failed_attempts == antes
  end

  test "Q20 — POST sem token de CSRF não conta na origem" do
    ip = {192, 0, 2, 18}
    chave = Origem.de_endereco(ip, :socket).chave

    for _ <- 1..3 do
      assert_error_sent 403, fn ->
        %{build_conn() | remote_ip: ip}
        |> put_private(:plug_skip_csrf_protection, false)
        |> post(~p"/session", %{"identifier" => inexistente(), "password" => @senha})
      end
    end

    assert :ets.match_object(:limite_por_origem, {{:contas, chave, :_}, :_}) == []
  end

  test "Q22 — o endereço não chega à telemetria" do
    ip = {198, 51, 100, 23}
    esgotar(ip)
    Spans.recebidos(0)

    tentar(ip, inexistente(), @senha)
    spans = Spans.recebidos()

    assert [_] = Spans.do_passo(spans, :entrar_com_senha)

    assert Spans.sentinelas_encontradas([spans, Spans.recursos()], ["198.51.100.23", "198.51.100"]) ==
             []
  end
end
