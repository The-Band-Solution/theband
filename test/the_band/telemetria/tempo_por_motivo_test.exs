defmodule TheBand.Telemetria.TempoPorMotivoTest do
  @moduledoc """
  O tempo da emissão não distingue os motivos — spec 074, T015; FR-009; research R9;
  seguranca.md, S4.

  A 045 e a #1047 gastaram trabalho para igualar o tempo de toda recusa da entrada. A telemetria
  não pode desfazê-lo: o passo é emitido na mesma requisição, e se ele custasse mais num motivo —
  uma consulta só quando há conta, por exemplo — o tempo da resposta voltaria a dizer qual foi.

  Mede-se a emissão como a entrada a faz — com a conta nos motivos que a levam (D1) e sem ela no
  identificador que não resolve —, atravessando o handler e o filtro de produção. A mediana de
  cada motivo não pode passar 0,25 ms da de outro.

  **O limiar era 2 ms (research R9) e foi medido insuficiente em 2026-10-03.** A emissão inteira
  custa ~0,1 ms por motivo, e as medianas divergem ~20 µs. Com o defeito que este teste existe
  para pegar — uma consulta no handler só quando há conta —, os motivos com conta subiram para
  0,5–2,8 ms e o sem conta ficou em 0,13 ms: a divergência passou de 2 ms numa rodada e ficou
  abaixo noutra. Um limiar que deixa o defeito passar metade das vezes não é guarda. 0,25 ms é
  quase 15 vezes a divergência medida sem defeito (~17 µs), e metade da menor medida com ele
  (503 µs, em quatro rodadas).
  """
  use TheBand.DataCase, async: false

  alias TheBand.Spans
  alias TheBand.Tenants.AccessEvents

  @amostras 50
  @limiar_us 250

  # Os seis motivos da entrada, e se a conta vai no passo (FR-004, D1).
  @motivos [
    senha_errada: :com_conta,
    identificador_nao_resolveu: :sem_conta,
    conta_sem_senha: :com_conta,
    conta_desativada: :com_conta,
    organizacao_suspensa: :com_conta,
    em_espera: :com_conta
  ]

  setup do
    :ok = Spans.ligar()
    tenant = tenant_fixture()
    user = user_fixture(tenant)
    %{tenant: tenant, user: user}
  end

  defp emitir(motivo, conta, ctx) do
    {tenant_id, user_id} =
      if conta == :com_conta, do: {ctx.tenant.id, ctx.user.id}, else: {nil, nil}

    AccessEvents.passo(%{
      passo: :entrar_com_senha,
      desfecho: :falhou,
      motivo: motivo,
      tenant_id: tenant_id,
      user_id: user_id,
      jornada_id: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
    })
  end

  defp mediana(lista) do
    ordenada = Enum.sort(lista)
    Enum.at(ordenada, div(length(ordenada), 2))
  end

  test "a diferença entre as medianas dos seis motivos fica abaixo de 0,25 ms", ctx do
    # Aquecimento: a primeira emissão carrega módulos e cria a tabela do tracer.
    for {motivo, conta} <- @motivos, do: emitir(motivo, conta, ctx)

    medianas =
      for {motivo, conta} <- @motivos, into: %{} do
        tempos =
          for _ <- 1..@amostras do
            {us, :ok} = :timer.tc(fn -> emitir(motivo, conta, ctx) end)
            us
          end

        {motivo, mediana(tempos)}
      end

    # A guarda do cenário: os passos chegaram ao destino, depois do filtro. Sem ela, um handler
    # desanexado mediria o custo de nada, igual em todo motivo, e o teste passaria.
    chegaram = Spans.do_passo(Spans.recebidos(), :entrar_com_senha)
    assert length(chegaram) >= length(@motivos) * @amostras

    {min, max} = medianas |> Map.values() |> Enum.min_max()

    assert max - min < @limiar_us,
           "as medianas por motivo divergem #{max - min} µs: #{inspect(medianas)}"
  end
end
