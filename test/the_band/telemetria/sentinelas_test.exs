defmodule TheBand.Telemetria.SentinelasTest do
  @moduledoc """
  Nada do que a pessoa digita ou carrega sai no traço — spec 074, T018; SC-002; FR-005;
  seguranca.md, S1 e S15, cenário T1.

  A jornada é percorrida como a pessoa a percorre — abrir a entrada, errar, entrar, sair, voltar
  com um cookie adulterado — com uma **sentinela em todo campo de credencial**: a senha tentada,
  a senha certa, o identificador digitado, o e-mail da conta e o segredo do cookie. O que chega
  ao destino, depois do filtro de produção, é varrido inteiro — nome, atributos, eventos, status,
  links e recurso —, em claro, em Base64 e em `inspect`.

  **Antes de qualquer `refute`, o `assert` de que chegaram spans dos quatro passos**: sem ele, um
  handler desanexado faria a varredura passar sobre nada.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Spans
  alias TheBand.Tenants

  @senha "SENTINELA-SENHA-9b2e7f"
  @senha_tentada "SENTINELA-TENTADA-4c1d8a"
  @identificador "SENTINELA-IDENT-6e3f0b@example.test"
  @segredo_forjado "SENTINELA-COOKIE-2a7c5d"
  @recurso "SENTINELA-RECURSO-8d4e1f"

  @passos [:abrir_a_entrada, :entrar_com_senha, :sair, :sessao_derrubada]

  setup do
    :ok = Spans.ligar()
    {tenant, _admin} = tenant_with_admin()

    {:ok, user} =
      Tenants.create_user(tenant, %{
        "email" => "SENTINELA-EMAIL-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, user} = Tenants.set_password(tenant, user.id, @senha)
    Spans.recebidos(0)
    %{user: user}
  end

  # A jornada inteira, e devolve as sentinelas que ela fez circular — inclusive o segredo do
  # cookie verdadeiro, que só existe depois de entrar.
  defp percorrer(user) do
    # abrir a entrada, com o LiveView conectado
    aberta = get(build_conn(), ~p"/sign-in")
    {:ok, _view, _html} = live(aberta)

    # errar a senha, e tentar um identificador que não existe
    post(recycle(aberta), ~p"/session", %{
      "identifier" => user.email,
      "password" => @senha_tentada
    })

    post(build_conn(), ~p"/session", %{"identifier" => @identificador, "password" => @senha})

    # entrar e sair
    dentro =
      post(recycle(aberta), ~p"/session", %{"identifier" => user.email, "password" => @senha})

    segredo = get_session(dentro, "session_secret")
    assert is_binary(segredo), "a guarda do cenário: a entrada foi aceita"
    delete(recycle(dentro), ~p"/session")

    # voltar com o cookie adulterado: a queda
    build_conn()
    |> init_test_session(%{
      "session_id" => get_session(dentro, "session_id"),
      "session_secret" => @segredo_forjado
    })
    |> get(~p"/version")

    [@senha, @senha_tentada, @identificador, @segredo_forjado, user.email, segredo]
  end

  test "os quatro passos chegam, e nenhuma sentinela em lugar nenhum do que saiu", ctx do
    sentinelas = percorrer(ctx.user)

    spans = Spans.recebidos()
    :ok = Spans.assert_passos!(spans, @passos)

    assert Spans.sentinelas_encontradas([spans, Spans.recursos()], sentinelas) == []
  end

  describe "com OTEL_RESOURCE_ATTRIBUTES no ambiente quando o SDK sobe" do
    # O `runtime.exs` apaga as `OTEL_*` antes do boot; este caso prova a camada seguinte — o
    # recurso reconstruído pelo filtro — com a variável presente na subida do SDK, que é o que
    # aconteceria se o apagamento falhasse.
    setup do
      System.put_env("OTEL_RESOURCE_ATTRIBUTES", "sentinela=#{@recurso}")
      reiniciar_o_sdk()

      on_exit(fn ->
        System.delete_env("OTEL_RESOURCE_ATTRIBUTES")
        reiniciar_o_sdk()
      end)

      :ok = Spans.ligar()
      Spans.recebidos(0)
      :ok
    end

    test "o recurso que sai não leva a sentinela", ctx do
      assert Enum.any?(detectado(), &String.contains?(&1, @recurso)),
             "a guarda do cenário: o SDK detectou a sentinela no recurso dele"

      sentinelas = percorrer(ctx.user)
      spans = Spans.recebidos()
      :ok = Spans.assert_passos!(spans, @passos)

      assert Spans.sentinelas_encontradas([spans, Spans.recursos()], [@recurso | sentinelas]) ==
               []
    end
  end

  defp reiniciar_o_sdk do
    :ok = Application.stop(:opentelemetry)
    {:ok, _} = Application.ensure_all_started(:opentelemetry)
    :ok
  end

  # Os valores do recurso que o SDK detectou, para a guarda do cenário.
  defp detectado do
    :otel_tracer_provider.resource()
    |> :otel_resource.attributes()
    |> :otel_attributes.map()
    |> Map.values()
    |> Enum.map(&to_string/1)
  end
end
