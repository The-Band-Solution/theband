defmodule TheBand.Repo.Migrations.MakeObservationEventsOrdered do
  @moduledoc """
  Dá precisão de microssegundo a `inserted_at`, para que dois eventos do mesmo segundo
  tenham ordem definida.

  ## O defeito, e ele já tinha acontecido antes

  `occurred_at` e `inserted_at` eram `timestamp(0)`. Encerrar e retomar no mesmo segundo
  — o caso normal num teste, e possível na interface — produzia empate, e o banco
  resolvia na ordem que quisesse. O estado derivado do "último evento" passava a
  depender de acidente do plano de execução.

  É a mesma classe do defeito de escolha de credencial corrigido no sprint 001: dois
  registros gravados no mesmo segundo empatavam em `validated_at`, e a solução foi
  acrescentar desempate determinístico.

  `occurred_at` continua em segundos: é quando a coisa **ocorreu**, e segundo basta para
  isso. `inserted_at` é a ordem de gravação, e é ela que desempata.
  """
  use Ecto.Migration

  def up do
    alter table(:tool_observation_events) do
      modify(:inserted_at, :utc_datetime_usec, null: false)
    end
  end

  def down do
    alter table(:tool_observation_events) do
      modify(:inserted_at, :utc_datetime, null: false)
    end
  end
end
