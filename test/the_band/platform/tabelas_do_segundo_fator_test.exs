defmodule TheBand.Platform.TabelasDoSegundoFatorTest do
  @moduledoc """
  As colunas e a tabela do segundo fator — spec 070, T020 (FR-016; `data-model.md` §1 e §1a).
  Por SQL, porque os schemas são a T021: o que se prova aqui é o banco.
  """
  use TheBand.DataCase, async: true

  defp operador(extra \\ "") do
    %{rows: [[id]]} =
      Repo.query!(
        "INSERT INTO platform_operators (id, email, name, inserted_at, updated_at#{extra}) " <>
          "VALUES (gen_random_uuid(), $1, 'Op', now(), now()" <>
          if(extra == "", do: "", else: ", " <> valores(extra)) <> ") RETURNING id",
        ["op-#{System.unique_integer([:positive])}@example.org"]
      )

    id
  end

  defp valores(", totp_confirmed_at, password_hash"), do: "now(), 'hash'"

  defp valores(
         ", totp_secret, totp_last_used_step, password_hash, totp_confirmed_at, ack_code_hash, ack_code_expires_at"
       ),
       do: "'\\x01'::bytea, 1, 'hash', now(), '\\x02'::bytea, now()"

  test "segundo fator confirmado sem segredo é recusado pelo banco" do
    assert_raise Postgrex.Error, ~r/platform_operators_confirmado_tem_segredo/, fn ->
      operador(", totp_confirmed_at, password_hash")
    end
  end

  test "código de guarda com o segundo fator já confirmado é recusado pelo banco" do
    assert_raise Postgrex.Error, ~r/platform_operators_codigo_de_guarda_entre_os_passos/, fn ->
      operador(
        ", totp_secret, totp_last_used_step, password_hash, totp_confirmed_at, ack_code_hash, ack_code_expires_at"
      )
    end
  end

  test "o mesmo código de recuperação duas vezes para o mesmo operador é recusado" do
    op = operador()

    inserir = fn ->
      Repo.query!(
        "INSERT INTO platform_operator_recovery_codes (id, operator_id, code_hash, inserted_at) " <>
          "VALUES (gen_random_uuid(), $1, '\\x0a'::bytea, now())",
        [op]
      )
    end

    inserir.()

    assert_raise Postgrex.Error,
                 ~r/platform_operator_recovery_codes_operator_id_code_hash/,
                 inserir
  end
end
