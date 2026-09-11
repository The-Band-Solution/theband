defmodule TheBandWeb.VersionControllerTest do
  @moduledoc """
  `GET /version` — a rota que transforma *"entregou"* em *"entregou, e se conferiu"*.

  Ela existe por um achado: em toda release desta base foi preciso escrever à mão que o
  webhook do Dokploy responder `deployed successfully` **não prova** que o container subiu a
  versão publicada. A produção puxa `latest`, que responde *"o que foi publicado por último"*
  e não *"o que está rodando"* (H7).
  """
  use TheBandWeb.ConnCase, async: true

  test "devolve a versão do mix.exs, em texto puro", %{conn: conn} do
    conn = get(conn, ~p"/version")

    assert response(conn, 200) == Mix.Project.config()[:version], """
    A CD compara esta resposta com a versão que acabou de publicar, num passo de shell. Se a
    rota devolvesse JSON, ou a versão com quebra de linha, a comparação falharia sempre — e um
    delivery correto pareceria um delivery quebrado.
    """

    assert ["text/plain" <> _] = get_resp_header(conn, "content-type")
  end

  test "NÃO exige sessão — o consumidor roda antes de haver uma", %{conn: conn} do
    assert conn |> get(~p"/version") |> response(200) != ""

    refute conn |> get(~p"/version") |> redirected_to_sign_in?(), """
    A versão já é pública na tag git, no registro da release e no nome da imagem. Exigir
    sessão esconderia de quem opera o que qualquer pessoa lê no repositório — e quebraria a
    CD, que pergunta antes de existir sessão.
    """
  end

  test "NÃO diz mais do que a versão", %{conn: conn} do
    corpo = conn |> get(~p"/version") |> response(200)

    refute corpo =~ ~r/[{}\[\]]/, "nada de estrutura: a forma existe para ser comparada"

    assert String.length(corpo) < 32, """
    Ambiente, host, commit ou estado do banco seriam superfície nova por conveniência de
    depuração. A pergunta que originou a rota tem uma resposta só.
    """
  end

  defp redirected_to_sign_in?(conn), do: conn.status in 301..399
end
