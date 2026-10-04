defmodule TheBandWeb.AbrirAEntradaTest do
  @moduledoc """
  A abertura da entrada conta uma vez — spec 074, T014; research R5; FR-011.

  O `mount` do LiveView roda duas vezes: na renderização estática e na conexão. Só a conexão
  conta, e por isso o robô que não roda JavaScript não conta como abertura. O passo leva o
  correlator que o plug `JornadaDeEntrada` pôs na sessão, e nada da pessoa — ela ainda não é
  ninguém.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Spans

  setup do
    :ok = Spans.ligar()
    Spans.recebidos(0)
    :ok
  end

  test "uma visita com o LiveView conectado produz UMA abertura, com o correlator da sessão",
       %{conn: conn} do
    conn = get(conn, ~p"/sign-in")
    correlator = get_session(conn, :jornada_id)
    {:ok, _view, _html} = live(conn)

    assert [span] = Spans.do_passo(Spans.recebidos(), :abrir_a_entrada)
    atributos = Spans.atributos(span)

    assert atributos["outcome"] == "concluiu"
    assert atributos["journey.id"] == correlator
    refute Map.has_key?(atributos, "failure.reason")
    refute Map.has_key?(atributos, "user.ref")
    refute Map.has_key?(atributos, "tenant.id")
  end

  test "a renderização estática sozinha não produz abertura nenhuma", %{conn: conn} do
    conn = get(conn, ~p"/sign-in")

    assert html_response(conn, 200) =~ ~s(name="password"), "a guarda do cenário: a tela abriu"
    assert Spans.do_passo(Spans.recebidos(), :abrir_a_entrada) == []
  end
end
