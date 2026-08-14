defmodule TheBand.EditarCredenciaisTest do
  @moduledoc """
  O que é ajustável numa ferramenta conectada — US3 da feature 003, issue #104.

  A feature tem tanto de recusa quanto de permissão: renomear e remover existem, e alterar
  tipo, instância ou organização **não** — são a identidade da ferramenta. A recusa da
  última credencial ativa é da mesma família: sem ela, remover a única credencial pararia a
  coleta sem que ninguém tivesse encerrado a observação, e a plataforma continuaria
  afirmando que observa uma organização que não observa mais.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Sources

  setup :verify_on_exit!

  defp conecta(tenant, org, secret) do
    expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
      {:ok,
       %{status: 200, body: %{"login" => "conta"}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
    end)

    {:ok, %{tool: tool, credential: credential}} =
      Sources.connect_tool(tenant, %{
        "tool_type" => "github",
        "instance_url" => "https://github.com",
        "organization_login" => org,
        "label" => "primeira",
        "secret" => secret
      })

    {tool, credential}
  end

  defp acrescenta(tenant, tool, label, secret) do
    expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
      {:ok,
       %{status: 200, body: %{"login" => "conta"}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
    end)

    {:ok, credential} =
      Sources.add_credential(tenant, tool, %{"label" => label, "secret" => secret})

    credential
  end

  describe "renomear (FR-015)" do
    test "muda o rótulo e não toca em mais nada" do
      tenant = tenant_fixture()
      {tool, credential} = conecta(tenant, "acme", "token-um")

      assert {:ok, renomeada} = Sources.rename_credential(tenant, credential.id, "conta de CI")
      assert renomeada.label == "conta de CI"

      # O que a ferramenta afirmou quando validou continua valendo: renomear não é revalidar.
      depois = Sources.active_credential(tool)
      assert depois.label == "conta de CI"
      assert depois.scopes == credential.scopes
      assert depois.validated_at == credential.validated_at
      assert depois.last_four == credential.last_four

      # E o segredo continua lá, legível — renomear não pode destruí-lo por descuido.
      assert {:ok, "token-um"} = Sources.fetch_secret(depois)
    end

    test "rótulo em branco é recusado, e o anterior permanece" do
      tenant = tenant_fixture()
      {tool, credential} = conecta(tenant, "acme", "token-um")

      assert {:error, :blank_label} = Sources.rename_credential(tenant, credential.id, "   ")
      assert Sources.active_credential(tool).label == "primeira"
    end

    test "credencial de outro tenant é não encontrada, nunca renomeada (FR-025)" do
      dono = tenant_fixture()
      outro = tenant_fixture()
      {tool, credential} = conecta(dono, "acme", "token-um")

      assert {:error, :not_found} = Sources.rename_credential(outro, credential.id, "invadida")
      assert Sources.active_credential(tool).label == "primeira"
    end

    test "id que não é UUID devolve não encontrado, e não levanta" do
      tenant = tenant_fixture()

      assert {:error, :not_found} = Sources.rename_credential(tenant, "não-é-uuid", "x")
    end
  end

  describe "remover (FR-016, FR-017)" do
    test "com outra ativa, remove e o segredo deixa de existir" do
      tenant = tenant_fixture()
      {tool, primeira} = conecta(tenant, "acme", "token-um")
      _segunda = acrescenta(tenant, tool, "segunda", "token-dois")

      assert {:ok, removida} = Sources.destroy_credential(tenant, primeira.id)
      assert removida.id == primeira.id

      {:ok, tool} = Sources.fetch_connected_tool(tenant, tool.id)
      assert [restante] = tool.credentials
      assert restante.label == "segunda"

      # Destruída é diferente de desativada: não existe mais linha alguma.
      assert {:error, :not_found} = Sources.rename_credential(tenant, primeira.id, "fantasma")
    end

    test "a última ativa é recusada, e a mensagem nomeia o caminho" do
      tenant = tenant_fixture()
      {tool, credential} = conecta(tenant, "acme", "token-um")

      assert {:error, :last_active_credential} = Sources.destroy_credential(tenant, credential.id)

      # E ela continua lá, funcionando — a recusa não pode ter meio-efeito.
      assert Sources.active_credential(tool).id == credential.id
      assert {:ok, "token-um"} = Sources.fetch_secret(Sources.active_credential(tool))
    end

    test "inativa pode ser removida mesmo sendo a única" do
      tenant = tenant_fixture()
      {tool, credential} = conecta(tenant, "acme", "token-um")
      {:ok, _} = Sources.set_credential_active(credential, false)

      assert {:ok, _} = Sources.destroy_credential(tenant, credential.id)

      {:ok, tool} = Sources.fetch_connected_tool(tenant, tool.id)
      assert tool.credentials == []
    end

    test "credencial de outro tenant é não encontrada (FR-025)" do
      dono = tenant_fixture()
      outro = tenant_fixture()
      {tool, primeira} = conecta(dono, "acme", "token-um")
      _segunda = acrescenta(dono, tool, "segunda", "token-dois")

      assert {:error, :not_found} = Sources.destroy_credential(outro, primeira.id)

      {:ok, tool} = Sources.fetch_connected_tool(dono, tool.id)
      assert length(tool.credentials) == 2
    end
  end

  describe "corrigir o cadastro enquanto nada foi coletado" do
    test "ferramenta recém-cadastrada é corrigível" do
      tenant = tenant_fixture()
      {tool, _} = conecta(tenant, "acme-errado", "token-um")

      assert Sources.identity_editable?(tenant, tool)

      assert {:ok, corrigida} =
               Sources.correct_identity(tenant, tool.id, %{"organization_login" => "acme"})

      assert corrigida.organization_login == "acme"
      # A credencial não é tocada: corrigir o cadastro não é reconectar.
      assert {:ok, "token-um"} = Sources.fetch_secret(Sources.active_credential(tool))
    end

    test "o campo não informado permanece" do
      tenant = tenant_fixture()
      {tool, _} = conecta(tenant, "acme", "token-um")

      assert {:ok, corrigida} =
               Sources.correct_identity(tenant, tool.id, %{"organization_login" => "outra"})

      assert corrigida.instance_url == "https://github.com"
      assert corrigida.tool_type == "github"
    end

    test "uma sincronização registrada fecha a janela" do
      tenant = tenant_fixture()
      {tool, _} = conecta(tenant, "acme", "token-um")

      {:ok, _sync} = TheBand.Ingestion.start_sync(tenant, tool)

      refute Sources.identity_editable?(tenant, tool)

      assert {:error, :already_observed} =
               Sources.correct_identity(tenant, tool.id, %{"organization_login" => "tarde-demais"})

      {:ok, intacta} = Sources.fetch_connected_tool(tenant, tool.id)
      assert intacta.organization_login == "acme"
    end

    test "dado da organização fecha a janela, mesmo sem sincronização registrada" do
      tenant = tenant_fixture()
      {tool, _} = conecta(tenant, "acme", "token-um")

      organizacao = organization_fixture(tenant, "acme")
      _equipe = team_fixture(tenant, "T_a", %{organization: organizacao})

      refute Sources.identity_editable?(tenant, tool), """
      A medida não pode depender só de `syncs`: dado gravado por outro caminho — importação,
      coleta anterior de uma ferramenta que foi removida — também deixa proveniência para
      órfã. O teto é o dado, não o registro da execução.
      """

      assert {:error, :already_observed} =
               Sources.correct_identity(tenant, tool.id, %{"organization_login" => "outra"})
    end

    test "ferramenta de outro tenant é não encontrada" do
      dono = tenant_fixture()
      outro = tenant_fixture()
      {tool, _} = conecta(dono, "acme", "token-um")

      assert {:error, :not_found} =
               Sources.correct_identity(outro, tool.id, %{"organization_login" => "invadida"})
    end
  end

  describe "limpar o estado de atenção (FR-018)" do
    test "a ferramenta volta a ser ativa" do
      tenant = tenant_fixture()
      {tool, _credential} = conecta(tenant, "acme", "token-um")

      {:ok, _} = Sources.mark_needs_attention(tool, "credencial ilegível")
      {:ok, marcada} = Sources.fetch_connected_tool(tenant, tool.id)
      assert Sources.situacao(marcada) == :needs_attention

      {:ok, _} = Sources.clear_needs_attention(marcada)

      {:ok, limpa} = Sources.fetch_connected_tool(tenant, tool.id)
      assert Sources.situacao(limpa) == :active
      refute limpa.needs_attention_reason
    end
  end
end
