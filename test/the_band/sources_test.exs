defmodule TheBand.SourcesTest do
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Sources
  alias TheBand.Sources.ToolCredential

  setup :verify_on_exit!

  describe "conectar ferramenta (FR-006)" do
    test "credencial válida com escopo suficiente conecta e grava" do
      tenant = tenant_fixture()

      expect(TheBand.GitHubHTTPMock, :get, fn _url, "token-valido" ->
        {:ok,
         %{
           status: 200,
           body: %{"login" => "conta"},
           headers: %{"x-oauth-scopes" => ["read:org, repo"]}
         }}
      end)

      assert {:ok, %{tool: tool, credential: credential}} =
               Sources.connect_tool(tenant, %{
                 "tool_type" => "github",
                 "instance_url" => "https://github.com",
                 "organization_login" => "org",
                 "secret" => "token-valido"
               })

      assert tool.status == "active"
      assert credential.validated_at
      assert "read:org" in credential.scopes
    end

    test "credencial recusada não grava nada" do
      tenant = tenant_fixture()

      expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok, %{status: 401, body: %{}, headers: %{}}}
      end)

      assert {:error, :unauthorized} =
               Sources.connect_tool(tenant, %{
                 "tool_type" => "github",
                 "instance_url" => "https://github.com",
                 "organization_login" => "org",
                 "secret" => "token-ruim"
               })

      assert Sources.list_connected_tools(tenant) == []
    end

    test "escopo insuficiente recusa nomeando o que falta, e não grava" do
      tenant = tenant_fixture()

      expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok,
         %{status: 200, body: %{"login" => "conta"}, headers: %{"x-oauth-scopes" => ["repo"]}}}
      end)

      assert {:error, {:missing_scopes, ["read:org"]}} =
               Sources.connect_tool(tenant, %{
                 "tool_type" => "github",
                 "instance_url" => "https://github.com",
                 "organization_login" => "org",
                 "secret" => "token-curto"
               })

      assert Sources.list_connected_tools(tenant) == []
    end
  end

  describe "identidade da ferramenta conectada" do
    setup do
      stub(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok,
         %{status: 200, body: %{"login" => "c"}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
      end)

      :ok
    end

    test "a mesma organização cliente observa várias organizações na mesma instância" do
      tenant = tenant_fixture()

      for org <- ~w(acme acme-labs) do
        assert {:ok, _} =
                 Sources.connect_tool(tenant, %{
                   "tool_type" => "github",
                   "instance_url" => "https://github.com",
                   "organization_login" => org,
                   "secret" => "t"
                 })
      end

      observadas =
        tenant
        |> Sources.list_connected_tools()
        |> Enum.map(& &1.organization_login)
        |> Enum.sort()

      assert observadas == ["acme", "acme-labs"]
    end

    test "reconectar a mesma organização não duplica a ferramenta, e acrescenta a credencial" do
      tenant = tenant_fixture()

      attrs = %{
        "tool_type" => "github",
        "instance_url" => "https://github.com",
        "organization_login" => "acme",
        "secret" => "t"
      }

      assert {:ok, _} = Sources.connect_tool(tenant, attrs)
      assert {:ok, _} = Sources.connect_tool(tenant, Map.put(attrs, "label", "segunda conta"))

      assert [tool] = Sources.list_connected_tools(tenant)
      # FR-004 — credenciais coexistem, porque enxergam conjuntos diferentes.
      assert length(tool.credentials) == 2
    end
  end

  describe "segredo da credencial (FR-007, FR-008)" do
    test "inspect não expõe o segredo" do
      credential = %ToolCredential{secret: "ghp_supersecreto", last_four: "reto"}
      texto = inspect(credential)

      refute texto =~ "ghp_supersecreto"
      assert texto =~ "last_four"
    end

    test "a máscara mostra só os quatro últimos caracteres" do
      credential = %ToolCredential{last_four: "abcd"}
      mascara = ToolCredential.masked(credential)

      assert String.ends_with?(mascara, "abcd")
      refute mascara =~ "ghp"
    end

    test "last_four extrai os quatro últimos, e não quebra em entrada curta" do
      assert ToolCredential.last_four("ghp_1234567890") == "7890"
      assert ToolCredential.last_four("ab") == "????"
    end
  end

  describe "independência entre credenciais (AC4 da US1)" do
    setup do
      stub(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok,
         %{status: 200, body: %{"login" => "c"}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
      end)

      tenant = tenant_fixture()

      {:ok, %{tool: tool, credential: primeira}} =
        Sources.connect_tool(tenant, %{
          "tool_type" => "github",
          "instance_url" => "https://github.com",
          "organization_login" => "acme",
          "label" => "primeira conta",
          "secret" => "token-um"
        })

      {:ok, segunda} =
        Sources.add_credential(tenant, tool, %{
          "label" => "segunda conta",
          "secret" => "token-dois"
        })

      %{tenant: tenant, tool: tool, primeira: primeira, segunda: segunda}
    end

    test "desativar a credencial em uso faz a coleta passar a usar a outra", %{
      tool: tool,
      primeira: primeira,
      segunda: segunda
    } do
      em_uso = Sources.active_credential(tool)
      assert em_uso.id in [primeira.id, segunda.id]

      {:ok, _} = Sources.set_credential_active(em_uso, false)

      outra = Sources.active_credential(tool)
      assert outra.id != em_uso.id
      assert outra.active
    end

    test "reativar devolve a credencial à escolha", %{tool: tool} do
      em_uso = Sources.active_credential(tool)
      {:ok, desativada} = Sources.set_credential_active(em_uso, false)
      {:ok, _} = Sources.set_credential_active(desativada, true)

      assert Sources.active_credential(tool).id == em_uso.id
    end

    test "sem nenhuma ativa, a sincronização é recusada com motivo legível", %{
      tenant: tenant,
      tool: tool,
      primeira: primeira,
      segunda: segunda
    } do
      {:ok, _} = Sources.set_credential_active(primeira, false)
      {:ok, _} = Sources.set_credential_active(segunda, false)

      assert is_nil(Sources.active_credential(tool))
      # Recusada, não silenciosamente adiada.
      assert {:error, :no_active_credential} = TheBand.Ingestion.start_sync(tenant, tool)
    end

    test "a escolha é determinística: mesmo estado, mesma credencial", %{tool: tool} do
      # Duas credenciais cadastradas no mesmo segundo empatam em validated_at. Sem
      # desempate, o banco resolveria na ordem que quisesse, e a mesma
      # sincronização traria dados diferentes sem nada ter mudado na origem.
      escolhas = for _ <- 1..20, do: Sources.active_credential(tool).id

      assert length(Enum.uniq(escolhas)) == 1
    end

    test "desativar uma não afeta o estado da outra", %{primeira: primeira, segunda: segunda} do
      {:ok, _} = Sources.set_credential_active(primeira, false)

      recarregada = Repo.get!(TheBand.Sources.ToolCredential, segunda.id)
      assert recarregada.active
    end
  end

  describe "ferramenta que precisa de atenção (FR-009)" do
    test "marcar uma não afeta as outras do tenant" do
      tenant = tenant_fixture()

      stub(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok,
         %{status: 200, body: %{"login" => "c"}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
      end)

      {:ok, %{tool: uma}} =
        Sources.connect_tool(tenant, %{
          "tool_type" => "github",
          "instance_url" => "https://github.com",
          "organization_login" => "org-a",
          "secret" => "t1"
        })

      {:ok, %{tool: outra}} =
        Sources.connect_tool(tenant, %{
          "tool_type" => "github",
          "instance_url" => "https://git.interno.example",
          "organization_login" => "org-b",
          "secret" => "t2"
        })

      {:ok, marcada} = Sources.mark_needs_attention(uma, "credencial expirou")

      assert marcada.status == "needs_attention"
      assert marcada.needs_attention_since
      assert marcada.needs_attention_reason == "credencial expirou"

      recarregada = Enum.find(Sources.list_connected_tools(tenant), &(&1.id == outra.id))
      assert recarregada.status == "active"
    end
  end
end
