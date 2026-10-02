defmodule TheBand.Platform.EventosDosAtosTest do
  @moduledoc """
  Os atos de plataforma no log — spec 070, T055 (FR-010, O14; quickstart §9).
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.SuspensaoFixtures

  alias TheBand.Platform
  alias TheBand.Platform.{Grant, SuspensionReasons}

  setup do
    {op, sessao} = sessao_de_operador()
    Map.merge(organizacao_povoada(), %{op: op, sessao: sessao})
  end

  test "suspender e reativar: operator_id, o tenant de A, o episódio e as contagens; a nota não",
       ctx do
    log =
      capture_log(fn ->
        {:ok, ep} =
          Platform.suspender(ctx.sessao, ctx.tenant.slug, %{
            reason: "suspected_compromise",
            note: "nota-secreta-que-nao-vai-ao-log"
          })

        send(self(), {:ep, ep})

        {:ok, _} =
          Platform.reativar(ctx.sessao, ctx.tenant.slug, %{reason: "contract_resumed", note: nil})
      end)

    assert_received {:ep, ep}
    [suspensa] = Regex.scan(~r/.*ato=:organizacao_suspensa.*/, log) |> List.flatten()
    assert suspensa =~ ~s(tenant_id="#{ctx.tenant.id}")
    assert suspensa =~ ~s(operator_id="#{ctx.op.id}")
    assert suspensa =~ ~s(episodio_id="#{ep.id}")
    assert suspensa =~ "sessoes=2" and suspensa =~ "tokens=1"
    assert log =~ "ato=:organizacao_reativada"
    refute log =~ "nota-secreta-que-nao-vai-ao-log"
  end

  test "cada motivo de recusa produz uma linha de operador ato recusado com ele", ctx do
    casos = [
      {:not_found, fn -> Platform.suspender(ctx.sessao, "nao-existe", %{reason: "other"}) end},
      {:razao_invalida,
       fn -> Platform.suspender(ctx.sessao, ctx.tenant.slug, %{reason: "x"}) end},
      {:nao_suspensa,
       fn -> Platform.reativar(ctx.sessao, ctx.tenant.slug, %{reason: "contract_resumed"}) end},
      {:ja_suspensa,
       fn ->
         Platform.suspender(ctx.sessao, ctx.tenant.slug, %{reason: "contract_ended"})
         Platform.suspender(ctx.sessao, ctx.tenant.slug, %{reason: "contract_ended"})
       end},
      {:sem_episodio_aberto,
       fn ->
         outra = TheBand.DataCase.tenant_fixture()

         Repo.update_all(from(t in TheBand.Tenants.Tenant, where: t.id == ^outra.id),
           set: [status: "suspended"]
         )

         Platform.reativar(ctx.sessao, outra.slug, %{reason: "contract_resumed"})
       end},
      {:vocabulario_nao_declarado,
       fn ->
         Application.put_env(:the_band, SuspensionReasons, regra: "platform.nao_existe")
         r = Platform.suspender(ctx.sessao, ctx.tenant.slug, %{reason: "other"})
         Application.delete_env(:the_band, SuspensionReasons)
         r
       end},
      {:nao_autorizado,
       fn ->
         Repo.update_all(from(g in Grant, where: g.operator_id == ^ctx.op.id),
           set: [
             revoked_at: DateTime.utc_now(:second),
             revoked_via: "release_command",
             revoked_by_declared: "x"
           ]
         )

         Platform.suspender(ctx.sessao, ctx.tenant.slug, %{reason: "other", note: "n"})
       end}
    ]

    for {motivo, fun} <- casos do
      log = capture_log(fun)
      assert log =~ "operador ato recusado", inspect(motivo)
      assert log =~ "motivo=#{inspect(motivo)}", inspect(motivo)
      assert log =~ ~s(operator_id="#{ctx.op.id}"), inspect(motivo)
    end
  end
end
