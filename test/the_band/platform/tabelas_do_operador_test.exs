defmodule TheBand.Platform.TabelasDoOperadorTest do
  @moduledoc """
  As tabelas do operador da plataforma — spec 070, T018 (`data-model.md` §1, §2 e §3).

  Escreve por SQL, e não por schema: os schemas são a T021. O que se prova aqui é o banco.
  """
  use TheBand.DataCase, async: true

  defp operador(email \\ nil) do
    email = email || "op-#{System.unique_integer([:positive])}@example.org"

    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO platform_operators (id, email, name, inserted_at, updated_at) " <>
          "VALUES (gen_random_uuid(), $1, 'Op', now(), now()) RETURNING id",
        [email]
      )

    id
  end

  defp conceder(operator_id) do
    Repo.query!(
      "INSERT INTO platform_operator_grants (id, operator_id, granted_at, granted_via, " <>
        "granted_by_declared, email_at_grant, inserted_at) " <>
        "VALUES (gen_random_uuid(), $1, now(), 'release_command', 'quem rodou', 'op@x', now()) " <>
        "RETURNING id",
      [operator_id]
    )
  end

  test "as três tabelas existem sem tenant_id" do
    for tabela <- ~w(platform_operators platform_operator_grants platform_operator_sessions) do
      %{rows: colunas} =
        Repo.query!(
          "SELECT column_name FROM information_schema.columns WHERE table_name = $1",
          [tabela]
        )

      assert colunas != [], "#{tabela} não existe"
      refute ["tenant_id"] in colunas, "#{tabela} tem tenant_id"
    end
  end

  test "o índice parcial recusa a segunda concessão vigente do mesmo operador" do
    op = operador()
    conceder(op)

    assert_raise Postgrex.Error, ~r/platform_operator_grants_vigente_index/, fn ->
      conceder(op)
    end
  end

  test "o e-mail é único sem diferenciar maiúsculas" do
    operador("Mesmo@Example.org")

    assert_raise Postgrex.Error, ~r/platform_operators_email_index/, fn ->
      operador("mesmo@example.org")
    end
  end
end
