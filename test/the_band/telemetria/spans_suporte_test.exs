defmodule TheBand.Telemetria.SpansSuporteTest do
  # Spec 074, T008. Um só processador simples no SDK, e o destino é global: síncrono.
  use ExUnit.Case, async: false

  alias TheBand.Spans
  alias TheBand.Tenants.AccessEvents

  test "um passo emitido chega ao processo do teste DEPOIS de passar pelo filtro de produção" do
    :ok = Spans.ligar()

    AccessEvents.passo(%{
      passo: :sair,
      desfecho: :falhou,
      motivo: :sessao_ja_nao_existia,
      tenant_id: nil,
      user_id: nil
    })

    [span] = Spans.do_passo(Spans.recebidos(), :sair)

    assert Spans.atributos(span)["failure.reason"] == "sessao_ja_nao_existia"

    # O filtro passou: o recurso é o reconstruído, com as três chaves, e não o que o SDK detectou
    # (que traz `process.*` e `telemetry.sdk.*`).
    [recurso | _] = Spans.recursos()

    assert Spans.chaves_do_recurso(recurso) ==
             ["deployment.environment", "service.name", "service.version"]
  end

  test "a função de suporte recusa um destino ligado sem o filtro" do
    :ok = :otel_simple_processor.set_exporter(:otel_exporter_pid, self())
    on_exit(&Spans.desligar/0)

    assert_raise RuntimeError, ~r/não é o filtro de produção/, fn ->
      Spans.conferir_o_filtro!()
    end
  end
end
