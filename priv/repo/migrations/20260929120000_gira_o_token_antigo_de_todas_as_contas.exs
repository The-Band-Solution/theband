defmodule TheBand.Repo.Migrations.GiraOTokenAntigoDeTodasAsContas do
  @moduledoc """
  Gira `users.session_token` de **toda** conta — feature 064, T012, decisão P1 de 2026-09-28.

  ## Por que girar uma coluna que ninguém mais lê

  Desde a T013, que vai **no mesmo deploy**, a sessão é lida só de `user_sessions`. Esta coluna
  fica até a T014, numa release seguinte, e é por isso que ela é girada aqui: se o código for
  revertido, o código antigo volta a lê-la. Girada, nenhum valor que já esteve num backup volta
  a casar com nada, e todo cookie existente é recusado também pelo código antigo.

  **Toda conta, inclusive as que tinham a coluna nula.** No código antigo, coluna nula aceita
  um cookie que traga só `user_id` (achado S4). Um rollback reabriria isso em cada conta sem
  valor.

  **As sessões vivas não são migradas** (P1). Cada pessoa entra de novo uma vez, e a nota da
  release diz isso. Migrá-las faria continuar valendo o valor bruto que está em toda cópia
  tirada até aqui (achado S7).

  ## O valor

  SQL puro, sem parâmetro nem laço em Elixir, para nada do valor passar pelo log do migrador
  (achado S11). `gen_random_uuid()` é do núcleo do Postgres desde a 13, e usa o gerador forte.
  Dois deles, sem hífens, dão 64 caracteres hexadecimais e 244 bits aleatórios. O formato
  difere do de `User.novo_token/0` de propósito: é um valor que nenhum cookie pode ter.

  ## O `down`

  Não há volta. O valor anterior não é guardado em lugar nenhum, que é a razão de a migração
  existir. O `down` é explícito e não faz nada, e diz isso.
  """
  use Ecto.Migration

  def up, do: execute(sql_up())

  @doc false
  # Pública para o teste executar o mesmo SQL dentro do sandbox, sem rodar o migrador.
  def sql_up do
    "UPDATE users SET session_token = replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')"
  end

  def down do
    # Nada a desfazer: o valor anterior foi descartado de propósito. Voltar a T013 funciona com
    # a coluna girada. Cada pessoa entra de novo, e nenhum cookie antigo vale.
    :ok
  end
end
