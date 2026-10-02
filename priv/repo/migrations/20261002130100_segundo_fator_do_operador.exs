defmodule TheBand.Repo.Migrations.SegundoFatorDoOperador do
  @moduledoc """
  O segundo fator TOTP do operador — spec 070, T020 (FR-016; `data-model.md` §1 e §1a).

  `totp_secret` é cifrado na aplicação (`TheBand.Encrypted.Binary`, Cloak), e por isso aqui é só
  `binary`. Entra na lista única da rotação da chave mestra (`TheBand.Rotacao`, #1052) pela T021.

  O cadastro tem três passos (emenda T012): o código de cadastro abre o passo 2, o código de guarda
  abre o passo 3, e `totp_confirmed_at` só é gravado no passo 3. Os `CHECK`s dizem em que passo cada
  coluna pode estar preenchida.
  """
  use Ecto.Migration

  def change do
    alter table(:platform_operators) do
      add :totp_secret, :binary
      add :totp_confirmed_at, :utc_datetime
      add :totp_last_used_step, :bigint
      add :second_factor_failures, :integer, null: false, default: 0
      add :enrollment_code_hash, :binary
      add :enrollment_code_expires_at, :utc_datetime
      add :ack_code_hash, :binary
      add :ack_code_expires_at, :utc_datetime
    end

    create constraint(:platform_operators, :platform_operators_codigo_de_cadastro_em_par,
             check: "(enrollment_code_hash IS NULL) = (enrollment_code_expires_at IS NULL)"
           )

    # Não há segundo fator confirmado sem segredo, nem sem senha.
    create constraint(:platform_operators, :platform_operators_confirmado_tem_segredo,
             check: "totp_confirmed_at IS NULL OR totp_secret IS NOT NULL"
           )

    create constraint(:platform_operators, :platform_operators_confirmado_tem_senha,
             check: "totp_confirmed_at IS NULL OR password_hash IS NOT NULL"
           )

    create constraint(:platform_operators, :platform_operators_falhas_nao_negativas,
             check: "second_factor_failures >= 0"
           )

    create constraint(:platform_operators, :platform_operators_codigo_de_guarda_em_par,
             check: "(ack_code_hash IS NULL) = (ack_code_expires_at IS NULL)"
           )

    # O código de guarda só existe entre os passos 2 e 3: o TOTP já foi conferido uma vez, o código
    # de cadastro já foi anulado, e o segundo fator ainda não vale. Fora disso, seria um passo 3
    # repetível, ou dois passos abertos ao mesmo tempo (data-model §1).
    create constraint(:platform_operators, :platform_operators_codigo_de_guarda_entre_os_passos,
             check:
               "ack_code_hash IS NULL OR (totp_confirmed_at IS NULL AND totp_secret IS NOT NULL " <>
                 "AND totp_last_used_step IS NOT NULL AND enrollment_code_hash IS NULL)"
           )

    create table(:platform_operator_recovery_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :operator_id, references(:platform_operators, type: :binary_id, on_delete: :restrict),
        null: false

      add :code_hash, :binary, null: false
      add :used_at, :utc_datetime
      add :invalidated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:platform_operator_recovery_codes, [:operator_id, :code_hash])

    create index(:platform_operator_recovery_codes, [:operator_id],
             where: "used_at IS NULL AND invalidated_at IS NULL",
             name: :platform_operator_recovery_codes_vigentes_index
           )

    # Usado OU invalidado, nunca os dois (seguranca-totp.md, T8).
    create constraint(:platform_operator_recovery_codes, :platform_operator_recovery_codes_um_fim,
             check: "used_at IS NULL OR invalidated_at IS NULL"
           )
  end
end
