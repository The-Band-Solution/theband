defmodule TheBand.Telemetria.SemBackendTest do
  @moduledoc """
  Sem backend, entrar e sair seguem iguais — spec 074, T020; SC-004; FR-008; research R13.

  O SDK é reiniciado com a configuração de **produção** — o `otel_batch_processor` com o filtro
  e o exportador OTLP de verdade — apontando para dois coletores quebrados: uma porta fechada
  (conexão recusada) e um coletor que aceita a conexão e nunca responde (o caso pior: quem
  esperasse por ele esperaria o tempo todo). Dez entradas e dez saídas pela web, cada uma
  respondendo como sempre e dentro do limiar.

  Não leva a tag `:integration`, ao contrário do que a tarefa dizia: `test_helper.exs` exclui a
  tag e `mix gates` não a inclui, então um teste marcado assim nunca rodaria em lugar nenhum.
  Ele roda em segundos, sem rede de fora — os dois coletores são sockets locais.
  """
  use TheBandWeb.ConnCase, async: false

  alias TheBand.Telemetria.Contadores
  alias TheBand.Telemetria.Exportador
  alias TheBand.Tenants

  @senha "senha-sem-backend-comprida-1"
  @vezes 10
  # Uma entrada no ambiente de teste leva dezenas de ms. 2 s é folga larga para o runner do CI e
  # ainda muito abaixo do tempo que um exportador síncrono esperaria pelo coletor mudo.
  @limiar_ms 2_000

  setup do
    {tenant, _admin} = tenant_with_admin()

    {:ok, user} =
      Tenants.create_user(tenant, %{
        "email" => "sem-backend-#{System.unique_integer([:positive])}@example.test",
        "role" => "member"
      })

    {:ok, user} = Tenants.set_password(tenant, user.id, @senha)
    %{user: user}
  end

  defp porta_fechada do
    {:ok, s} = :gen_tcp.listen(0, [:binary, ip: {127, 0, 0, 1}])
    {:ok, porta} = :inet.port(s)
    :ok = :gen_tcp.close(s)
    porta
  end

  # Aceita conexões e não responde nunca.
  defp coletor_mudo do
    {:ok, escuta} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, porta} = :inet.port(escuta)
    dono = spawn(fn -> aceitar(escuta, []) end)
    :ok = :gen_tcp.controlling_process(escuta, dono)
    on_exit(fn -> Process.exit(dono, :kill) end)
    porta
  end

  defp aceitar(escuta, abertas) do
    case :gen_tcp.accept(escuta) do
      {:ok, s} -> aceitar(escuta, [s | abertas])
      _ -> :ok
    end
  end

  # O SDK de produção: processador em lote, o filtro, e o OTLP/HTTP para `porta`. O exportador
  # vai em `traces_exporter`, e não dentro do processador: `traces_exporter` vence a opção do
  # processador, e o `:none` do teste deixaria o lote sem exportador nenhum — medido, foi o que
  # tornou a primeira versão deste teste vazia.
  defp sdk_de_producao(porta) do
    Application.put_env(:opentelemetry, :processors, [{:otel_batch_processor, %{}}])

    Application.put_env(
      :opentelemetry,
      :traces_exporter,
      {Exportador,
       %{
         destino:
           {:opentelemetry_exporter,
            %{protocol: :http_protobuf, endpoints: ["http://127.0.0.1:#{porta}"]}},
         ambiente: "teste_sem_backend"
       }}
    )

    reiniciar_o_sdk()

    on_exit(fn ->
      Application.put_env(:opentelemetry, :processors, [{:otel_simple_processor, %{}}])
      Application.put_env(:opentelemetry, :traces_exporter, :none)
      reiniciar_o_sdk()
    end)

    exportador_no_caminho!()
  end

  # A guarda do cenário: o filtro está no processador que está de pé. Sem ela, um exportador
  # `:undefined` faria a medida passar sobre nada.
  defp exportador_no_caminho! do
    processador =
      Enum.find([:otel_batch_processor_global, :otel_simple_processor_global], &Process.whereis/1)

    {_estado, dados} = :sys.get_state(processador)
    assert {Exportador, _} = elem(dados, 1), "o filtro não está no caminho de #{processador}"
    :ok
  end

  defp reiniciar_o_sdk do
    :ok = Application.stop(:opentelemetry)
    {:ok, _} = Application.ensure_all_started(:opentelemetry)
  end

  defp medir(fun) do
    {us, conn} = :timer.tc(fun)
    {div(us, 1000), conn}
  end

  defp entrar_e_sair(user) do
    for _ <- 1..@vezes do
      {ms_entrar, dentro} =
        medir(fn ->
          post(build_conn(), ~p"/session", %{"identifier" => user.email, "password" => @senha})
        end)

      assert redirected_to(dentro) == ~p"/people"
      assert ms_entrar < @limiar_ms, "a entrada esperou #{ms_entrar} ms pelo backend"

      {ms_sair, fora} = medir(fn -> dentro |> recycle() |> delete(~p"/session") end)
      assert redirected_to(fora) == ~p"/sign-in"
      assert ms_sair < @limiar_ms, "a saída esperou #{ms_sair} ms pelo backend"
    end
  end

  test "com o coletor recusando conexão, dez entradas e dez saídas funcionam", ctx do
    sdk_de_producao(porta_fechada())
    antes = Contadores.valor(:passo_emitido, nil)

    entrar_e_sair(ctx.user)

    # Os passos foram emitidos: o handler está no caminho, e a medida não é sobre nada.
    assert Contadores.valor(:passo_emitido, nil) - antes >= 2 * @vezes

    # E a exportação foi tentada e falhou — contada, e não silenciosa (FR-008).
    falhas_antes = Contadores.valor(:exportacao_falhou, :todos)
    :otel_tracer_provider.force_flush()
    assert esperar(fn -> Contadores.valor(:exportacao_falhou, :todos) > falhas_antes end)
  end

  defp esperar(condicao, tentativas \\ 50) do
    cond do
      condicao.() ->
        true

      tentativas == 0 ->
        false

      true ->
        receive do
        after
          100 -> esperar(condicao, tentativas - 1)
        end
    end
  end

  test "com o coletor mudo, que aceita e não responde, a pessoa não espera", ctx do
    sdk_de_producao(coletor_mudo())
    antes = Contadores.valor(:passo_emitido, nil)

    entrar_e_sair(ctx.user)

    assert Contadores.valor(:passo_emitido, nil) - antes >= 2 * @vezes
  end
end
