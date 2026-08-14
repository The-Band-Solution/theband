defmodule TheBandWeb.EditarFerramentaTest do
  @moduledoc """
  A tela de ferramentas oferece o que é ajustável, e diz o que não é — US3 da feature 003,
  issue #104.

  O teto desta tela é dado pelo que ela **não** faz: não edita organização nem instância, e
  não apaga a ferramenta. As duas recusas estão escritas na spec com o motivo, e uma tela
  que as oferecesse contradiria o contrato da feature 001.
  """
  use TheBandWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TheBand.Repo
  alias TheBand.Sources
  alias TheBand.Sources.ConnectedTool
  alias TheBand.Sources.ToolCredential

  @segredo "ghp_segredo_que_nao_pode_vazar_1234"

  defp credencial(tenant, tool, label, secret) do
    {:ok, credential} =
      %ToolCredential{}
      |> ToolCredential.changeset(%{
        tenant_id: tenant.id,
        connected_tool_id: tool.id,
        label: label,
        secret: secret,
        last_four: ToolCredential.last_four(secret),
        validated_at: DateTime.utc_now(:second)
      })
      |> Repo.insert()

    credential
  end

  setup %{conn: conn} do
    {tenant, user} = tenant_with_admin()

    {:ok, tool} =
      %ConnectedTool{}
      |> ConnectedTool.changeset(%{
        tenant_id: tenant.id,
        tool_type: "github",
        instance_url: "https://github.com",
        organization_login: "acme"
      })
      |> Repo.insert()

    primeira = credencial(tenant, tool, "principal", @segredo)

    %{conn: log_in(conn, user), tenant: tenant, tool: tool, primeira: primeira}
  end

  describe "renomear pela tela (FR-015)" do
    test "o rótulo muda, e o segredo não aparece em momento algum", ctx do
      {:ok, live, html} = live(ctx.conn, ~p"/tools")
      refute html =~ @segredo

      html = live |> element("button", "renomear") |> render_click()
      refute html =~ @segredo

      html =
        live
        |> form("form[phx-submit=rename_credential]", %{"label" => "conta de CI"})
        |> render_submit()

      assert html =~ "conta de CI"
      refute html =~ @segredo

      assert Sources.active_credential(ctx.tool).label == "conta de CI"
    end

    test "rótulo em branco é dito, e o anterior permanece", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/tools")
      live |> element("button", "renomear") |> render_click()

      html =
        live
        |> form("form[phx-submit=rename_credential]", %{"label" => "  "})
        |> render_submit()

      assert html =~ "cannot be empty"
      assert Sources.active_credential(ctx.tool).label == "principal"
    end
  end

  describe "remover pela tela (FR-016, FR-017)" do
    test "a última ativa é recusada, e a tela nomeia encerrar como o caminho", ctx do
      {:ok, live, _html} = live(ctx.conn, ~p"/tools")

      html = live |> element("button", "remover") |> render_click()

      assert html =~ "only active credential"
      assert html =~ "end the observation"

      # Recusar não pode ter meio-efeito: ela continua lá, e legível.
      credencial = Sources.active_credential(ctx.tool)
      assert credencial.id == ctx.primeira.id
      assert {:ok, @segredo} = Sources.fetch_secret(credencial)
    end

    test "com outra ativa, remover destrói o segredo", ctx do
      _segunda = credencial(ctx.tenant, ctx.tool, "segunda", "ghp_outro_segredo_4321")

      {:ok, live, _html} = live(ctx.conn, ~p"/tools")

      html =
        live
        |> element(~s(button[phx-value-id="#{ctx.primeira.id}"][phx-click="destroy_credential"]))
        |> render_click()

      assert html =~ "destroyed"

      {:ok, tool} = Sources.fetch_connected_tool(ctx.tenant, ctx.tool.id)
      assert [restante] = tool.credentials
      assert restante.label == "segunda"
    end
  end

  describe "limpar o estado de atenção (FR-018)" do
    test "o botão só existe quando há atenção, e limpá-lo devolve a ferramenta a ativa", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/tools")

      refute html =~ "limpar o estado de atenção", """
      Botão que aparece sempre não distingue a ferramenta que precisa de atenção da que não
      precisa — e a distinção é o que a FR-022 exige da tela.
      """

      {:ok, _} = Sources.mark_needs_attention(ctx.tool, "credencial ilegível")

      {:ok, live, html} = live(ctx.conn, ~p"/tools")
      assert html =~ "limpar o estado de atenção"
      assert html =~ "credencial ilegível"

      html = live |> element("button", "limpar o estado de atenção") |> render_click()

      assert html =~ "Attention state cleared"

      {:ok, tool} = Sources.fetch_connected_tool(ctx.tenant, ctx.tool.id)
      assert Sources.situacao(tool) == :active
    end
  end

  describe "o que a tela recusa (FR-019, FR-020)" do
    test "não há campo para organização nem instância, e o motivo está escrito", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/tools")

      assert html =~ "são a identidade dela", """
      A FR-020 exige a explicação **no lugar onde alguém procuraria editar** — não numa
      documentação que quem está na tela não vai abrir.
      """

      assert html =~ "encerrar a observação"

      refute html =~ ~s(name="organization_login" value="acme"), """
      Um campo preenchido com a organização é um convite a editá-la. A ausência do campo é a
      recusa da FR-019; o parágrafo é o porquê.
      """
    end
  end
end
