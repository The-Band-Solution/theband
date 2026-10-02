defmodule TheBand.Platform.EpisodioNaoSeReescreveTest do
  @moduledoc """
  O episódio é um só por organização e não se reescreve — spec 070, T045 (O9, FR-006; quickstart
  §7). O banco recusa, e não o código: qualquer caminho que escreva na tabela passa por aqui.
  """
  use TheBand.DataCase, async: true

  import TheBand.OperadorFixtures

  alias TheBand.Platform.Suspension

  setup do
    {op, _} = operador_pronto()
    tenant = tenant_fixture()

    # A sequência legítima (estado e episódio juntos), e a conferência do trigger adiado de T044a
    # feita já: com um evento pendente, o PostgreSQL recusa o TRUNCATE antes de chegar ao trigger
    # que este teste mede.
    Repo.update_all(from(t in TheBand.Tenants.Tenant, where: t.id == ^tenant.id),
      set: [status: "suspended"]
    )

    aberto = abrir(tenant, op)
    Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")

    # E de volta ao adiado: a transação do sandbox é uma só, e o IMMEDIATE valeria até o fim dela.
    Repo.query!("SET CONSTRAINTS ALL DEFERRED")
    %{op: op, tenant: tenant, aberto: aberto}
  end

  defp abrir(tenant, op) do
    Repo.insert!(%Suspension{
      tenant_id: tenant.id,
      suspended_at: DateTime.utc_now(:second),
      suspended_by_operator_id: op.id,
      suspend_reason: "contract_ended"
    })
  end

  test "o segundo episódio aberto da mesma organização é recusado pelo índice", %{
    op: op,
    tenant: tenant
  } do
    erro = assert_raise Ecto.ConstraintError, fn -> abrir(tenant, op) end
    assert erro.constraint == "tenant_suspensions_aberto_index"
  end

  test "DELETE, TRUNCATE e UPDATE da abertura levantam", %{aberto: aberto} do
    for sql <- [
          {"DELETE FROM tenant_suspensions WHERE id = $1", [uuid(aberto)]},
          # CASCADE: sem ele, a FK de `api_access_tokens` (T047) recusa antes de o trigger rodar.
          {"TRUNCATE tenant_suspensions CASCADE", []},
          {"UPDATE tenant_suspensions SET suspend_reason = 'other' WHERE id = $1", [uuid(aberto)]}
        ] do
      {texto, params} = sql

      erro =
        assert_raise Postgrex.Error, fn ->
          Repo.transaction(fn -> Repo.query!(texto, params) end)
        end

      assert erro.postgres.code == :restrict_violation, texto
      assert erro.postgres.message =~ "tenant_suspensions", texto
    end

    assert Repo.get!(Suspension, aberto.id).suspend_reason == "contract_ended"
  end

  test "fechar o episódio passa, e o fechado não reabre nem se refecha", %{op: op, aberto: aberto} do
    fechar = fn ->
      Repo.update_all(from(t in TheBand.Tenants.Tenant, where: t.id == ^aberto.tenant_id),
        set: [status: "active"]
      )

      Repo.query!(
        """
        UPDATE tenant_suspensions
        SET reactivated_at = $2, reactivated_by_operator_id = $3, reactivate_reason = 'contract_resumed',
            reactivate_note = 'renovado', updated_at = $2
        WHERE id = $1
        """,
        [uuid(aberto), DateTime.utc_now(:second), uuid(op)]
      )
    end

    fechar.()
    fechado = Repo.get!(Suspension, aberto.id)
    assert fechado.reactivate_reason == "contract_resumed"

    erro = assert_raise Postgrex.Error, fn -> Repo.transaction(fechar) end
    assert erro.postgres.code == :restrict_violation

    erro =
      assert_raise Postgrex.Error, fn ->
        Repo.transaction(fn ->
          Repo.query!(
            "UPDATE tenant_suspensions SET reactivated_at = NULL, reactivated_by_operator_id = NULL, reactivate_reason = NULL, reactivate_note = NULL WHERE id = $1",
            [uuid(aberto)]
          )
        end)
      end

    assert erro.postgres.code == :restrict_violation
  end

  test "a reativação pela metade é recusada pelo CHECK", %{aberto: aberto} do
    erro =
      assert_raise Postgrex.Error, fn ->
        Repo.transaction(fn ->
          Repo.query!("UPDATE tenant_suspensions SET reactivated_at = now() WHERE id = $1", [
            uuid(aberto)
          ])
        end)
      end

    assert erro.postgres.constraint == "tenant_suspensions_reativacao_inteira"
  end

  defp uuid(%{id: id}), do: Ecto.UUID.dump!(id)
end
