defmodule TheBand.Telemetria.HandlerResilienteTest do
  # Spec 074, T010 — o handler que traduz sem sumir (FR-008; seguranca.md, S11; ADR 0005, S5).
  # Mexe no handler global do `:telemetry`: síncrono.
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias TheBand.Telemetria.Contadores
  alias TheBand.Telemetria.Jornada
  alias TheBand.Tenants.AccessEvents

  @sentinela "SENTINELA-HANDLER-77a1"

  setup do
    on_exit(fn ->
      :telemetry.detach(Jornada.id())
      :ok = Jornada.anexar()
    end)
  end

  defp anexar_com(emitir) do
    :telemetry.detach(Jornada.id())

    :ok =
      :telemetry.attach(Jornada.id(), Jornada.evento(), &Jornada.handle_event/4, %{emitir: emitir})
  end

  defp um_passo do
    AccessEvents.passo(%{
      passo: :sair,
      desfecho: :falhou,
      motivo: :sessao_ja_nao_existia,
      tenant_id: nil,
      user_id: nil
    })
  end

  for {kind, falha} <- [
        error: quote(do: fn _ -> raise ArgumentError, @sentinela end),
        exit: quote(do: fn _ -> exit({:sentinela, @sentinela}) end),
        throw: quote(do: fn _ -> throw({:sentinela, @sentinela}) end)
      ] do
    test "um handler que falha com #{kind} continua anexado, conta a falha e loga só o tipo" do
      anexar_com(unquote(falha))
      antes = Contadores.valor(:handler_falhou, unquote(kind))

      log = capture_log(fn -> assert um_passo() == :ok end)

      assert Jornada.anexado?(), "o :telemetry desanexou o handler depois de um #{unquote(kind)}"
      assert Contadores.valor(:handler_falhou, unquote(kind)) == antes + 1
      assert log =~ "o handler falhou (#{unquote(kind)}"
      refute log =~ @sentinela
    end
  end

  test "com o handler desanexado, a conferência periódica loga erro" do
    :telemetry.detach(Jornada.id())
    refute Jornada.anexado?()

    log = capture_log(fn -> TheBandWeb.Telemetry.conferir_a_telemetria() end)

    assert log =~ "[error]"
    assert log =~ "NÃO está anexado"
  end

  test "com o handler anexado, a conferência periódica não acusa desanexo" do
    assert Jornada.anexado?()
    log = capture_log(fn -> TheBandWeb.Telemetry.conferir_a_telemetria() end)
    refute log =~ "NÃO está anexado"
  end
end
