defmodule TheBand.DonoDoTokenTest do
  @moduledoc """
  O login do dono do token é gravado, consultado e descoberto — ADR 0007, decisão 1.

  A cota do GitHub é do usuário, não do token. Sem saber de quem é cada credencial, nada
  no modelo consegue dizer quais ferramentas competem pelas mesmas 5 000 requisições por
  hora — e o login vinha em toda validação e era descartado em três lugares.
  """
  use TheBand.DataCase, async: false

  import Mox

  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  setup :verify_on_exit!

  defp resposta_do_user(login) do
    {:ok, %{status: 200, body: %{"login" => login}, headers: %{"x-oauth-scopes" => ["read:org"]}}}
  end

  defp ferramenta(tenant, org) do
    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: org
      })
      |> Repo.insert()

    tool
  end

  defp credencial(tenant, tool, secret, dono, extra \\ %{}) do
    {:ok, credential} =
      %ToolCredential{}
      |> ToolCredential.changeset(
        Map.merge(
          %{
            tenant_id: tenant.id,
            connected_tool_id: tool.id,
            label: "principal",
            secret: secret,
            last_four: ToolCredential.last_four(secret),
            validated_at: DateTime.utc_now(:second),
            owner_login: dono
          },
          extra
        )
      )
      |> Repo.insert()

    credential
  end

  describe "o login do dono é gravado ao validar (ADR 0007, decisão 1)" do
    test "conectar a ferramenta grava o login que a origem devolveu" do
      tenant = tenant_fixture()
      stub(TheBand.GitHubHTTPMock, :get, fn _url, _token -> resposta_do_user("octocat") end)

      assert {:ok, %{credential: credential}} =
               Sources.connect_tool(tenant, %{
                 "tool_type" => "github",
                 "instance_url" => "https://github.com",
                 "organization_login" => "acme",
                 "secret" => "ghp_token_da_acme_0001"
               })

      assert credential.owner_login == "octocat",
             "o login veio em `verify_credential` e foi descartado; sem ele, a plataforma " <>
               "não sabe quais ferramentas dividem a cota"

      assert Repo.get!(ToolCredential, credential.id).owner_login == "octocat",
             "o dono precisa estar na linha, não só na struct devolvida"
    end

    test "acrescentar credencial a uma ferramenta grava o login dela" do
      tenant = tenant_fixture()
      tool = ferramenta(tenant, "acme")
      stub(TheBand.GitHubHTTPMock, :get, fn _url, _token -> resposta_do_user("hubot") end)

      assert {:ok, credential} =
               Sources.add_credential(tenant, tool, %{
                 "secret" => "ghp_token_do_hubot_0002",
                 "label" => "conta de CI"
               })

      assert credential.owner_login == "hubot",
             "a segunda credencial pode ser de outro usuário; é isso que decide se a " <>
               "ferramenta ganhou cota nova ou só um token a mais do mesmo saldo"
    end

    test "a projeção sem segredo carrega o dono — é o que a tela lê" do
      tenant = tenant_fixture()
      stub(TheBand.GitHubHTTPMock, :get, fn _url, _token -> resposta_do_user("octocat") end)

      {:ok, _} =
        Sources.connect_tool(tenant, %{
          "tool_type" => "github",
          "instance_url" => "https://github.com",
          "organization_login" => "acme",
          "secret" => "ghp_token_da_acme_0001"
        })

      [%ConnectedTool{credentials: [sem_segredo]}] = Sources.list_connected_tools(tenant)

      assert sem_segredo.owner_login == "octocat",
             "`credenciais_sem_segredo/0` seleciona campo a campo; se o dono não entrar " <>
               "na lista, a tela mostra o token sem dono mesmo com o dado gravado"
    end
  end

  describe "credenciais_com_mesmo_dono/1" do
    test "dois donos iguais em duas ferramentas: o dono e as duas ferramentas" do
      tenant = tenant_fixture()
      acme = ferramenta(tenant, "acme")
      labs = ferramenta(tenant, "acme-labs")
      credencial(tenant, acme, "ghp_a_0001", "octocat")
      credencial(tenant, labs, "ghp_b_0002", "octocat")

      resultado = Sources.credenciais_com_mesmo_dono(tenant)

      assert Map.keys(resultado) == ["octocat"],
             "octocat aparece em duas ferramentas: as duas dividem as mesmas 5 000/hora"

      assert Enum.map(resultado["octocat"], & &1.id) == [acme.id, labs.id],
             "as ferramentas vêm ordenadas por tipo, instância e organização"
    end

    test "donos diferentes, dono nulo, credencial inativa e outro tenant ficam de fora" do
      tenant = tenant_fixture()
      outro_tenant = tenant_fixture("outro")
      acme = ferramenta(tenant, "acme")
      labs = ferramenta(tenant, "acme-labs")
      sem_dono = ferramenta(tenant, "sem-dono")
      desligada = ferramenta(tenant, "desligada")
      alheia = ferramenta(outro_tenant, "alheia")

      credencial(tenant, acme, "ghp_a_0001", "octocat")
      credencial(tenant, labs, "ghp_b_0002", "hubot")
      credencial(tenant, sem_dono, "ghp_c_0003", nil)
      credencial(tenant, desligada, "ghp_d_0004", "octocat", %{active: false})
      credencial(outro_tenant, alheia, "ghp_e_0005", "octocat")

      assert Sources.credenciais_com_mesmo_dono(tenant) == %{},
             "um dono com uma ferramenta só não divide nada; nulo não afirma dono; " <>
               "credencial inativa não gasta cota; e outro tenant não entra na conta deste"
    end

    test "duas credenciais do mesmo dono na mesma ferramenta não contam como duas" do
      tenant = tenant_fixture()
      acme = ferramenta(tenant, "acme")
      credencial(tenant, acme, "ghp_a_0001", "octocat")
      credencial(tenant, acme, "ghp_a_0002", "octocat", %{label: "segunda"})

      assert Sources.credenciais_com_mesmo_dono(tenant) == %{},
             "a ferramenta conta uma vez por dono: dois tokens do mesmo usuário na mesma " <>
               "ferramenta não dividem cota com ninguém de fora"
    end
  end

  describe "descobrir_dono/1" do
    @segredo "ghp_dono_ainda_desconhecido_0001"

    test "com o dono desconhecido, abre o segredo, pergunta à origem e grava" do
      tenant = tenant_fixture()
      tool = ferramenta(tenant, "acme")
      credencial(tenant, tool, @segredo, nil)

      # A struct que o job recebe vem da projeção sem segredo — o segredo tem de ser
      # buscado pelo id, e não lido da struct.
      [%ConnectedTool{credentials: [sem_segredo]}] = Sources.list_connected_tools(tenant)
      assert is_nil(sem_segredo.owner_login)

      expect(TheBand.GitHubHTTPMock, :get, fn url, token ->
        assert String.ends_with?(url, "/user"), "o dono do token é quem `/user` devolve"

        assert token == @segredo,
               "a chamada tem de ir com o segredo decifrado — é ele que identifica o dono"

        resposta_do_user("octocat")
      end)

      assert {:ok, %ToolCredential{owner_login: "octocat"}} = Sources.descobrir_dono(sem_segredo)

      assert Repo.get!(ToolCredential, sem_segredo.id).owner_login == "octocat",
             "descobrir sem gravar obrigaria a perguntar de novo a cada coleta"
    end

    test "com o dono já conhecido, devolve a credencial e não toca na origem" do
      tenant = tenant_fixture()
      tool = ferramenta(tenant, "acme")
      credential = credencial(tenant, tool, @segredo, "octocat")

      expect(TheBand.GitHubHTTPMock, :get, 0, fn _url, _token -> resposta_do_user("x") end)

      assert {:ok, ^credential} = Sources.descobrir_dono(credential),
             "uma chamada a `/user` por coleta gastaria cota para descobrir o que já se sabe"
    end

    test "origem recusa: o erro volta e o dono continua desconhecido" do
      tenant = tenant_fixture()
      tool = ferramenta(tenant, "acme")
      credential = credencial(tenant, tool, @segredo, nil)

      expect(TheBand.GitHubHTTPMock, :get, fn _url, _token ->
        {:ok, %{status: 401, body: %{}, headers: %{}}}
      end)

      assert {:error, :unauthorized} = Sources.descobrir_dono(credential),
             "a recusa é da origem e tem de chegar a quem chamou — não virar dono nulo em silêncio"

      assert is_nil(Repo.get!(ToolCredential, credential.id).owner_login),
             "nada foi gravado: a recusa não é um dono"
    end
  end
end
