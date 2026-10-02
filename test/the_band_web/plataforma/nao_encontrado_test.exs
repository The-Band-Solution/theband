defmodule TheBandWeb.Plataforma.NaoEncontradoTest do
  @moduledoc """
  O `404` de rota de operador é o de qualquer caminho — spec 070, T037 (A12; cenário 10 de
  `seguranca-autenticacao.md`). Se diferissem, comparar as duas respostas diria a quem varre quais
  caminhos de `/platform` são rotas de verdade.
  """
  use TheBandWeb.ConnCase, async: true

  @cabecalhos_de_seguranca ~w(content-security-policy x-frame-options x-content-type-options
                              referrer-policy cache-control x-permitted-cross-domain-policies)

  for caminho <- ["/platform/nao-existe", "/platform", "/platform/organizations/x/outra-coisa"] do
    @caminho caminho

    test "GET /platform/organizations anônimo e GET #{caminho}: mesmo status, cabeçalhos e corpo" do
      rota = get(build_conn(), ~p"/platform/organizations")
      nenhuma = get(build_conn(), @caminho)

      assert rota.status == 404 and nenhuma.status == 404
      assert cabecalhos(rota) == cabecalhos(nenhuma)
      assert nomes_dos_cabecalhos(rota) == nomes_dos_cabecalhos(nenhuma)
      assert sem_variaveis(rota) == sem_variaveis(nenhuma)
    end
  end

  defp cabecalhos(conn), do: for(h <- @cabecalhos_de_seguranca, do: {h, get_resp_header(conn, h)})

  defp nomes_dos_cabecalhos(conn),
    do:
      conn.resp_headers
      |> Enum.map(&elem(&1, 0))
      |> Enum.reject(&(&1 == "x-request-id"))
      |> Enum.sort()

  # O `csrf-token` muda a cada resposta, e o caminho aparece no corpo da página de erro por design
  # (`ErrorHTML`, "The address … matches no page"). Fora os dois, o corpo é o mesmo.
  defp sem_variaveis(conn) do
    conn.resp_body
    |> String.replace(~r/name="csrf-token" content="[^"]*"/, "")
    |> String.replace(conn.request_path, "")
  end
end
