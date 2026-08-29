defmodule TheBandWeb.ChaveDoModeloTest do
  @moduledoc """
  A tela `/ai` — a chave do provedor de modelo desta organização.

  ## As três asserções que carregam este arquivo

  1. **o segredo nunca aparece** — nem depois de gravado, nem no formulário. Só os quatro
     últimos, que existem para distinguir uma chave da outra;
  2. **os três estados dizem coisas diferentes** — gravada, herdada do ambiente e inexistente
     pedem ações diferentes de quem lê, e a herdada é a que engana: ela funciona, e é
     compartilhada por toda a instalação;
  3. **toda recusa diz que nada foi gravado** — sem isso, quem lê fica sem saber se a chave
     anterior sobreviveu à tentativa.
  """
  use TheBandWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias TheBand.AI
  alias TheBand.Tenants

  setup :verify_on_exit!

  @chave "sk-uma-chave-de-teste-com-mais-de-vinte-caracteres-9876"

  setup %{conn: conn} do
    anterior = System.get_env("API_KEY")
    System.delete_env("API_KEY")

    on_exit(fn ->
      # Restauração SIMÉTRICA: sem isto, um put_env dentro de teste vaza para a
      # suíte inteira quando `anterior` é nil — foi o flake que derrubou o CI do
      # #596 e deixou o do #594 verde por sorte de seed (2026-08-29).
      if anterior, do: System.put_env("API_KEY", anterior), else: System.delete_env("API_KEY")
    end)

    {tenant, admin} = tenant_with_admin()

    %{conn: log_in(conn, admin), tenant: tenant, admin: admin}
  end

  defp aceita(modelos \\ ["gpt-5.4", "gpt-5.4-mini"]) do
    expect(TheBand.LLMHTTPMock, :verify, fn _secret, _opts -> {:ok, modelos} end)
  end

  defp salvar(live, params) do
    live |> form("#ai-credential", params) |> render_submit()
  end

  describe "quem alcança a tela" do
    test "perfil member não alcança", %{conn: conn, tenant: tenant} do
      {:ok, member} =
        Tenants.create_user(tenant, %{"email" => "member@example.test", "role" => "member"})

      assert {:error, {:redirect, %{to: "/people"}}} = live(log_in(conn, member), ~p"/ai")
    end
  end

  describe "os três estados da chave" do
    test "sem chave alguma, a ausência é nomeada e diz o que deixa de funcionar", ctx do
      {:ok, _live, html} = live(ctx.conn, ~p"/ai")

      assert html =~ "No key saved"
      assert html =~ "profile generation cannot run"
    end

    test "chave do ambiente é dita como da instalação, e não da organização", ctx do
      System.put_env("API_KEY", "sk-do-ambiente-abcd")

      {:ok, _live, html} = live(ctx.conn, ~p"/ai")

      assert html =~ "server environment"
      assert html =~ "abcd"
      # A frase que separa este estado de &quot;configurado&quot;: a conta é da instalação.
      assert html =~ "every organisation on"
      assert html =~ "another&#39;s bill"
    end

    test "chave gravada aparece mascarada, e o segredo não está no HTML", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave})

      {:ok, _live, html} = live(ctx.conn, ~p"/ai")

      assert html =~ "saved for this organisation"
      assert html =~ "••••9876"
      refute html =~ @chave
    end
  end

  describe "gravar pela tela" do
    test "a chave é conferida antes de gravar, e some do HTML depois", ctx do
      aceita()

      {:ok, live, _} = live(ctx.conn, ~p"/ai")
      html = salvar(live, %{"secret" => @chave, "default_model" => "gpt-5.4"})

      assert html =~ "checked against the provider and saved"
      assert html =~ "••••9876"
      assert html =~ "gpt-5.4"
      refute html =~ @chave
      assert {:ok, _} = AI.fetch(ctx.tenant)
    end

    test "sem modelo escolhido, a tela diz que vale o padrão do provedor", ctx do
      aceita()

      {:ok, live, _} = live(ctx.conn, ~p"/ai")
      html = salvar(live, %{"secret" => @chave, "default_model" => ""})

      assert html =~ "the provider default, because none was chosen"
    end
  end

  describe "as recusas, e cada uma pede uma coisa diferente" do
    test "chave recusada manda gerar outra, e diz que nada foi gravado", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o ->
        {:error, {:rejeitada, "HTTP 401 — Incorrect API key provided"}}
      end)

      {:ok, live, _} = live(ctx.conn, ~p"/ai")
      html = salvar(live, %{"secret" => @chave, "default_model" => ""})

      assert html =~ "refused the key"
      assert html =~ "Nothing was saved"
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "provedor inalcançável não manda gerar outra chave", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o ->
        {:error, {:indisponivel, "connection refused"}}
      end)

      {:ok, live, _} = live(ctx.conn, ~p"/ai")
      html = salvar(live, %{"secret" => @chave, "default_model" => ""})

      assert html =~ "Could not reach the provider"
      # A diferença que este ramo existe para carregar: a chave pode estar certa.
      assert html =~ "may well be valid"
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "chave sem modelo algum é recusada antes de virar falha do job de fundo", ctx do
      expect(TheBand.LLMHTTPMock, :verify, fn _s, _o ->
        {:error, {:sem_modelos, "the provider accepted the key and listed no model"}}
      end)

      {:ok, live, _} = live(ctx.conn, ~p"/ai")
      html = salvar(live, %{"secret" => @chave, "default_model" => ""})

      assert html =~ "listed no model"
      assert html =~ "an hour later and for somebody else"
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end

    test "modelo que a conta não alcança é recusado com a lista do que ela alcança", ctx do
      aceita(["gpt-5.4-mini"])

      {:ok, live, _} = live(ctx.conn, ~p"/ai")
      html = salvar(live, %{"secret" => @chave, "default_model" => "gpt-4o"})

      assert html =~ "does not reach the model gpt-4o"
      assert html =~ "gpt-5.4-mini"
      assert html =~ "Nothing was saved"
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end
  end

  describe "remover" do
    test "o segredo some, e a tela volta a dizer que a geração não roda", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave})

      {:ok, live, _} = live(ctx.conn, ~p"/ai")
      html = live |> element("button", "remove the key") |> render_click()

      assert html =~ "Key removed"
      assert html =~ "No key saved"
      assert {:error, :not_found} = AI.fetch(ctx.tenant)
    end
  end

  describe "isolamento entre organizações" do
    test "a chave de uma organização não aparece na tela da outra", ctx do
      aceita()
      {:ok, _} = AI.put(ctx.tenant, %{"secret" => @chave})

      {_outro, admin_do_outro} = tenant_with_admin("outro")

      {:ok, _live, html} = live(log_in(build_conn(), admin_do_outro), ~p"/ai")

      assert html =~ "No key saved"
      refute html =~ "••••9876"
      refute html =~ @chave
    end
  end
end
