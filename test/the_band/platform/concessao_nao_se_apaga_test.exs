defmodule TheBand.Platform.ConcessaoNaoSeApagaTest do
  @moduledoc """
  A concessão de operador não se apaga nem se reescreve — spec 070, T019 (FR-002, A13; cenário 11
  de `seguranca-autenticacao.md`).

  A única alteração aceita é a revogação de uma concessão vigente, coluna a coluna.
  """
  use TheBand.DataCase, async: true

  setup do
    %{rows: [[op]]} =
      Repo.query!(
        "INSERT INTO platform_operators (id, email, name, inserted_at, updated_at) " <>
          "VALUES (gen_random_uuid(), $1, 'Op', now(), now()) RETURNING id",
        ["op-#{System.unique_integer([:positive])}@example.org"]
      )

    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO platform_operator_grants (id, operator_id, granted_at, granted_via, " <>
          "granted_by_declared, email_at_grant, inserted_at) " <>
          "VALUES (gen_random_uuid(), $1, now(), 'release_command', 'quem rodou', 'op@x', now()) " <>
          "RETURNING id",
        [op]
      )

    %{id: id}
  end

  @revogar "revoked_at = now(), revoked_via = 'release_command', revoked_by_declared = 'quem revogou'"

  test "DELETE é recusado", %{id: id} do
    assert_raise Postgrex.Error, ~r/somente-acréscimo/, fn ->
      Repo.query!("DELETE FROM platform_operator_grants WHERE id = $1", [id])
    end
  end

  test "TRUNCATE é recusado" do
    assert_raise Postgrex.Error, ~r/somente-acréscimo/, fn ->
      Repo.query!("TRUNCATE platform_operator_grants CASCADE")
    end
  end

  test "revogar E reescrever quem concedeu é recusado", %{id: id} do
    assert_raise Postgrex.Error, ~r/só a revogação/, fn ->
      Repo.query!(
        "UPDATE platform_operator_grants SET #{@revogar}, granted_by_declared = 'outra pessoa' " <>
          "WHERE id = $1",
        [id]
      )
    end
  end

  test "só revogar passa, e revogar de novo é recusado", %{id: id} do
    %{num_rows: 1} =
      Repo.query!("UPDATE platform_operator_grants SET #{@revogar} WHERE id = $1", [id])

    assert_raise Postgrex.Error, ~r/só a revogação/, fn ->
      Repo.query!("UPDATE platform_operator_grants SET revoke_note = 'x' WHERE id = $1", [id])
    end
  end
end
