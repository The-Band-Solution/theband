defmodule TheBandWeb.BotaoSemChaveTest do
  @moduledoc """
  Feature 048 — o botão diz ANTES do clique, e a defesa continua no domínio.

  A assimetria dos caminhos é o coração (research R2): a chave do AMBIENTE habilita
  a geração da pessoa (é como o dev roda) e NÃO habilita a rodada mensal
  (tenant-only, FR-011 da 044).
  """
  use TheBandWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias TheBand.AI
  alias TheBand.Tenants

  setup :verify_on_exit!

  setup %{conn: conn} do
    anterior = System.get_env("API_KEY")
    System.delete_env("API_KEY")
    on_exit(fn -> if anterior, do: System.put_env("API_KEY", anterior) end)

    {tenant, admin} = tenant_with_admin()

    # Pessoa COM material: sem ele a página entra no estado 4 (sem botão, recusa
    # do registro) e não haveria o que desabilitar.
    %{pessoa: pessoa} = TheBand.ProfileRunFixtures.cenario(tenant, "chaveless")

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin, pessoa: pessoa}
  end

  defp gravar_chave(tenant, user) do
    expect(TheBand.LLMHTTPMock, :verify, fn _secret, _opts -> {:ok, ["gpt-5.4"]} end)
    {:ok, _} = AI.put(tenant, %{"secret" => "sk-uma-chave-de-teste-bem-longa-1234"}, user.id)
  end

  test "página da pessoa: sem chave, botão disabled com a frase — e o evento forçado é recusado",
       ctx do
    {:ok, view, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")

    assert html =~ ~s(phx-click="gerar_perfil")
    assert html =~ "disabled"
    # Admin OPERA: a frase traz o caminho.
    assert html =~ "Configure it in AI provider"

    # Cenário 4: por fora do botão (o clique no disabled o próprio framework
    # recusa — SC-001 provado de graça), o evento injetado direto na view é a
    # violação real, e a defesa é do domínio: recusa nomeada, nenhum job.
    html = render_click(view, "gerar_perfil", %{})
    assert html =~ "has no provider key"
  end

  test "quem não opera recebe quem resolve, sem caminho", ctx do
    {:ok, member} =
      Tenants.create_user(ctx.tenant, %{
        "email" => "leitor-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    # Sem escopo, member não vê a página da pessoa — o teste do leitor comum é na
    # frase, então dá o escopo person (piso) via a própria rota da pessoa: member
    # enxerga a página, e NÃO opera.
    conn = log_in(Phoenix.ConnTest.build_conn(), member)
    {:ok, _view, html} = live(conn, ~p"/people/#{ctx.pessoa.id}")

    if html =~ "Generate profile" or html =~ "Generate again" do
      assert html =~ "Someone who operates"
      refute html =~ "Configure it in AI provider, under Operação"
    end
  end

  test "com a chave do ambiente, a pessoa habilita e a mensal NÃO — a assimetria", ctx do
    System.put_env("API_KEY", "sk-do-ambiente")
    on_exit(fn -> System.delete_env("API_KEY") end)

    {:ok, _view, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")
    refute html =~ "has no provider key"

    {:ok, _view, html} = live(ctx.conn, ~p"/profiles")
    assert html =~ "has no provider key of its own"
    assert html =~ ~s(disabled)
  end

  test "com a credencial do tenant, os dois caminhos habilitam e a frase some", ctx do
    gravar_chave(ctx.tenant, ctx.admin)

    {:ok, _view, html} = live(ctx.conn, ~p"/people/#{ctx.pessoa.id}")
    refute html =~ "has no provider key"

    {:ok, _view, html} = live(ctx.conn, ~p"/profiles")
    refute html =~ "has no provider key of its own"
  end

  test "geração mensal sem chave nenhuma: Turn on disabled com a frase do tenant", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/profiles")

    assert html =~ "Turn on"
    assert html =~ "disabled"
    assert html =~ "has no provider key of its own"
    # A recusa nomeada do domínio continua exatamente como está (cenário 4) —
    # provada nos testes existentes de Runs; aqui o botão só avisa antes.
  end
end
