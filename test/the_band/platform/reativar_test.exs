defmodule TheBand.Platform.ReativarTest do
  @moduledoc """
  Reativar uma organização sem devolver nada — spec 070, T050 (FR-005, FR-006, FR-013, FR-015).
  """
  use TheBand.DataCase, async: false

  import ExUnit.CaptureLog
  import TheBand.SuspensaoFixtures

  alias TheBand.Platform
  alias TheBand.Platform.Suspension
  alias TheBand.Tenants.Schemas.{ApiAccessToken, UserSession}
  alias TheBand.Tenants.Sessions, as: SessoesDasOrganizacoes
  alias TheBand.Tenants.Tenant

  setup do
    {op, sessao} = sessao_de_operador()
    Map.merge(organizacao_povoada(), %{op: op, sessao: sessao})
  end

  defp ato(fun) do
    {r, _} = with_log(fun)
    refute tem_tenant?(r), "o retorno carrega %Tenant{} (D1-d)"
    r
  end

  defp suspender(ctx, razao \\ "contract_ended", nota \\ nil),
    do:
      ato(fn -> Platform.suspender(ctx.sessao, ctx.tenant.slug, %{reason: razao, note: nota}) end)

  defp reativar(ctx, razao \\ "contract_resumed", nota \\ nil),
    do:
      ato(fn -> Platform.reativar(ctx.sessao, ctx.tenant.slug, %{reason: razao, note: nota}) end)

  test "o episódio fecha com autor, instante e razão; volta a active; nenhum token volta", ctx do
    {:ok, aberto} = suspender(ctx)
    assert {:ok, %Suspension{} = fechado} = reativar(ctx, "contract_resumed", "renovado")

    assert fechado.id == aberto.id
    assert fechado.reactivated_by_operator_id == ctx.op.id and fechado.reactivated_at

    assert fechado.reactivate_reason == "contract_resumed" and
             fechado.reactivate_note == "renovado"

    assert Repo.get!(Tenant, ctx.tenant.id).status == "active"
    assert Repo.get!(ApiAccessToken, ctx.token.id).revoked_at

    Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")
  end

  test "a reativação encerra de novo a sessão aberta durante a suspensão (O8, FR-015)", ctx do
    {:ok, _} = suspender(ctx)
    # A entrada que leu `active` antes da suspensão e gravou depois dela.
    {:ok, {da_corrida, _}} = SessoesDasOrganizacoes.abrir(ctx.admin)

    Phoenix.PubSub.subscribe(TheBand.PubSub, "sessao:" <> da_corrida.id)
    {:ok, _} = reativar(ctx)

    assert Repo.get!(UserSession, da_corrida.id).ended_at
    assert_received :sessao_encerrada
  end

  test ":nao_suspensa numa organização ativa", ctx do
    assert reativar(ctx) == {:error, :nao_suspensa}
  end

  test ":sem_episodio_aberto quando o estado é suspended sem episódio (o trigger desligado)",
       ctx do
    # Só possível porque o sandbox não faz COMMIT: fora dele, T044a recusa este estado.
    Repo.update_all(from(t in Tenant, where: t.id == ^ctx.tenant.id), set: [status: "suspended"])
    assert reativar(ctx) == {:error, :sem_episodio_aberto}
    assert Repo.get!(Tenant, ctx.tenant.id).status == "suspended"
  end

  test "investigation_closed_no_compromise só contra suspected_compromise", ctx do
    {:ok, _} = suspender(ctx)

    assert {:error, %Ecto.Changeset{}} = reativar(ctx, "investigation_closed_no_compromise")
    assert Repo.get!(Tenant, ctx.tenant.id).status == "suspended"

    {:ok, _} = reativar(ctx)
    {:ok, _} = suspender(ctx, "suspected_compromise", "credencial vazada")
    assert {:ok, _} = reativar(ctx, "investigation_closed_no_compromise")
  end

  test "other exige nota ao reativar", ctx do
    {:ok, _} = suspender(ctx)
    assert {:error, %Ecto.Changeset{}} = reativar(ctx, "other", nil)
    assert {:ok, _} = reativar(ctx, "other", "motivo escrito")
  end

  test "o evento da reativação vai ao log", ctx do
    {:ok, _} = suspender(ctx)

    log =
      capture_log(fn ->
        Platform.reativar(ctx.sessao, ctx.tenant.slug, %{reason: "contract_resumed", note: nil})
      end)

    assert log =~ "ato=:organizacao_reativada" and log =~ "tokens=0"
  end
end
