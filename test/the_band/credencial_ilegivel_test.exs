defmodule TheBand.CredencialIlegivelTest do
  @moduledoc """
  A credencial cifrada por uma chave mestra que não existe mais.

  O caso é real e datado: em 2026-08-13 a chave de desenvolvimento foi trocada, e as duas
  credenciais gravadas com a anterior passaram a ser ilegíveis. O `Ecto.Type` levantava
  `ArgumentError` ao **carregar** o campo, e isso derrubava `/tools` e `/syncs` — inclusive
  a tela que oferece o conserto.

  O caso é montado escrevendo o texto cifrado direto na coluna, com um rótulo de cipher que
  nenhuma chave configurada tem. É a forma exata do dado real: `<<1, 16>>`, dezesseis bytes
  de rótulo, e o restante cifrado.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Sources.ToolCredential

  setup :verify_on_exit!

  # Um valor com a forma certa e o rótulo de uma chave que não está configurada. Cifrar de
  # verdade com outra chave daria o mesmo resultado por um caminho mais longo: o Cloak
  # escolhe o cipher **pelo rótulo**, e nenhum responde por este.
  defp secret_de_chave_desconhecida do
    <<1, 16>> <> "AES.GCM.deadbeef" <> :crypto.strong_rand_bytes(60)
  end

  defp ferramenta_com_credencial_ilegivel(tenant) do
    expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
      {:ok,
       %{
         status: 200,
         body: %{"login" => "conta"},
         headers: %{"x-oauth-scopes" => ["read:org"]}
       }}
    end)

    {:ok, %{tool: tool, credential: credential}} =
      Sources.connect_tool(tenant, %{
        "tool_type" => "github",
        "instance_url" => "https://github.com",
        "organization_login" => "org-ilegivel",
        "secret" => "token-que-vai-ficar-ilegivel"
      })

    # A troca de chave, encenada: o texto cifrado continua lá, íntegro, e nenhuma chave
    # configurada responde pelo rótulo dele.
    #
    # **SQL cru, e não `update_all`.** O `update_all` passa pelo tipo do campo, que cifra o
    # que recebe — o caso montado assim fica legível pela chave atual, e o teste passa
    # provando o contrário do que diz. Custou uma execução vermelha para aparecer.
    Repo.query!(
      "update tool_credentials set secret = $1 where id = $2",
      [secret_de_chave_desconhecida(), Ecto.UUID.dump!(credential.id)]
    )

    {tool, credential}
  end

  describe "as telas não carregam o segredo" do
    test "list_connected_tools devolve a ferramenta em vez de levantar" do
      tenant = tenant_fixture()
      {_tool, _credential} = ferramenta_com_credencial_ilegivel(tenant)

      assert [tool] = Sources.list_connected_tools(tenant)
      assert [credencial] = tool.credentials

      # O que a tela mostra continua inteiro...
      assert credencial.label
      assert credencial.last_four
      assert credencial.active
      assert "read:org" in credencial.scopes

      # ...e o segredo nem foi buscado. `nil` aqui é ausência de carga, não decifragem
      # que falhou em silêncio — a distinção importa, e o teste seguinte é quem a prova.
      assert credencial.secret == nil
    end

    test "fetch_connected_tool também não levanta" do
      tenant = tenant_fixture()
      {tool, _credential} = ferramenta_com_credencial_ilegivel(tenant)

      assert {:ok, carregada} = Sources.fetch_connected_tool(tenant, tool.id)
      assert [_credencial] = carregada.credentials
    end

    test "active_credential escolhe sem abrir" do
      tenant = tenant_fixture()
      {tool, credential} = ferramenta_com_credencial_ilegivel(tenant)

      assert %ToolCredential{id: id, secret: nil} = Sources.active_credential(tool)
      assert id == credential.id
    end
  end

  describe "abrir a credencial diz que não dá" do
    test "fetch_secret devolve {:error, :unreadable}, e não levanta" do
      tenant = tenant_fixture()
      {tool, _credential} = ferramenta_com_credencial_ilegivel(tenant)

      credencial = Sources.active_credential(tool)

      assert {:error, :unreadable} = Sources.fetch_secret(credencial)
    end

    test "credencial legível continua sendo lida — o teste anterior não prova nada sozinho" do
      tenant = tenant_fixture()

      expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok,
         %{status: 200, body: %{"login" => "conta"}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
      end)

      {:ok, %{tool: tool}} =
        Sources.connect_tool(tenant, %{
          "tool_type" => "github",
          "instance_url" => "https://github.com",
          "organization_login" => "org-legivel",
          "secret" => "token-legivel"
        })

      credencial = Sources.active_credential(tool)

      assert {:ok, "token-legivel"} = Sources.fetch_secret(credencial)
    end
  end
end
