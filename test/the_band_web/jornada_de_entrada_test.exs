defmodule TheBandWeb.JornadaDeEntradaTest do
  @moduledoc """
  O correlator da jornada de entrar — spec 074, T013; FR-011; seguranca.md, S5.

  Nasce no servidor, no `GET /sign-in`; mora na sessão assinada; é lido **só** dela pelo
  `POST /session`, nunca dos parâmetros; e morre na tentativa, com qualquer desfecho. O que sai
  é lido depois do filtro de produção (`TheBand.Spans`).
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Spans
  alias TheBand.Tenants

  @senha "SENTINELA-SENHA-correlator-5e2a"

  setup %{conn: conn} do
    :ok = Spans.ligar()
    {tenant, _admin} = tenant_with_admin()

    {:ok, member} =
      Tenants.create_user(tenant, %{
        "email" => "jornada-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, member} = Tenants.set_password(tenant, member.id, @senha)
    Spans.recebidos(0)

    %{conn: conn, member: member}
  end

  defp correlator, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

  defp journey_id_exportado do
    assert [span] = Spans.do_passo(Spans.recebidos(), :entrar_com_senha)
    Spans.atributos(span)["journey.id"]
  end

  test "o POST exporta o correlator da SESSÃO, e não o dos parâmetros", ctx do
    da_sessao = correlator()
    dos_parametros = correlator()

    ctx.conn
    |> init_test_session(%{jornada_id: da_sessao})
    |> post(~p"/session", %{
      "identifier" => ctx.member.email,
      "password" => "errada-#{@senha}",
      "journey_id" => dos_parametros,
      "jornada_id" => dos_parametros
    })

    assert journey_id_exportado() == da_sessao
  end

  test "depois de entrar, a sessão autenticada não tem o correlator", ctx do
    conn =
      ctx.conn
      |> init_test_session(%{jornada_id: correlator()})
      |> post(~p"/session", %{"identifier" => ctx.member.email, "password" => @senha})

    assert redirected_to(conn) == ~p"/people", "a guarda do cenário: a entrada foi aceita"
    assert get_session(conn, :jornada_id) == nil
  end

  test "depois de uma recusa, a sessão também não tem o correlator", ctx do
    conn =
      ctx.conn
      |> init_test_session(%{jornada_id: correlator()})
      |> post(~p"/session", %{"identifier" => ctx.member.email, "password" => "errada-#{@senha}"})

    assert redirected_to(conn) == ~p"/sign-in", "a guarda do cenário: a entrada foi recusada"
    assert get_session(conn, :jornada_id) == nil
  end

  test "cada GET /sign-in dá um correlator novo, de 16 bytes em base64url", ctx do
    primeiro = get(ctx.conn, ~p"/sign-in")
    segundo = get(recycle(primeiro), ~p"/sign-in")

    a = get_session(primeiro, :jornada_id)
    b = get_session(segundo, :jornada_id)

    assert is_binary(a) and is_binary(b)
    assert a != b
    assert {:ok, <<_::binary-size(16)>>} = Base.url_decode64(a, padding: false)
  end

  test "o POST /session não ganha correlator novo no caminho", ctx do
    conn =
      post(ctx.conn, ~p"/session", %{"identifier" => ctx.member.email, "password" => @senha})

    assert get_session(conn, :jornada_id) == nil
    assert journey_id_exportado() == nil
  end
end
