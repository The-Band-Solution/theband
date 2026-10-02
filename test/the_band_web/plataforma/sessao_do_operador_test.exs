defmodule TheBandWeb.Plataforma.SessaoDoOperadorTest do
  @moduledoc """
  O cookie próprio da sessão do operador — spec 070, T035 (FR-011; research R3.2).
  """
  use TheBandWeb.ConnCase, async: true

  import TheBand.OperadorFixtures

  alias TheBandWeb.Plataforma.SessaoDoOperador

  test "o set-cookie da entrada tem os atributos: cifrado, http_only, SameSite=Strict, Path=/platform, max-age de 8 h",
       %{conn: conn} do
    {op, _} = operador_pronto()

    conn =
      conn
      |> Map.put(:secret_key_base, TheBandWeb.Endpoint.config(:secret_key_base))
      |> SessaoDoOperador.abrir(op)
      |> Plug.Conn.send_resp(200, "")

    [cookie] = get_resp_header(conn, "set-cookie")

    assert cookie =~ ~r/^_the_band_operator=/
    assert cookie =~ "path=/platform"
    assert cookie =~ "HttpOnly"
    assert cookie =~ "SameSite=Strict"
    assert cookie =~ "max-age=28800"
    # Cifrado: o id da sessão não aparece em claro.
    refute cookie =~ op.id
  end

  test "conferir lê o cookie que abrir gravou, e recusa sem ele", %{conn: conn} do
    {op, _} = operador_pronto()
    chave = TheBandWeb.Endpoint.config(:secret_key_base)

    gravado =
      conn
      |> Map.put(:secret_key_base, chave)
      |> SessaoDoOperador.abrir(op)

    %{value: valor} = gravado.resp_cookies["_the_band_operator"]

    lido =
      build_conn()
      |> Map.put(:secret_key_base, chave)
      |> Plug.Test.put_req_cookie("_the_band_operator", valor)

    assert {:ok, _sessao, %{id: id}} = SessaoDoOperador.conferir(lido)
    assert id == op.id

    assert {:error, :sem_sessao, nil} =
             build_conn() |> Map.put(:secret_key_base, chave) |> SessaoDoOperador.conferir()
  end

  # A memória "guarda que lê código reprova a prosa": o código, sem os comentários.
  test "TheBandWeb.Sessao, o leitor da sessão das organizações, não menciona o cookie do operador" do
    codigo =
      "lib/the_band_web/sessao.ex"
      |> File.read!()
      |> String.split("\n")
      |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
      |> Enum.join("\n")

    refute codigo =~ "_the_band_operator"
  end
end
