defmodule TheBand.Repo.Migrations.AutomationEventsEmMicrossegundo do
  @moduledoc """
  O relógio dos eventos de automação passa a microssegundo — emenda de 2026-08-16.

  Com resolução de segundo, ligar e desligar no mesmo segundo empatam, e o estado — que é
  derivado do **último** evento — passa a depender de qual linha o banco devolve primeiro.
  O empate ficou latente até a migração seguinte mudar o plano da consulta, e aí dois testes
  reprovaram dizendo a verdade: a ordem nunca esteve garantida.

  É a mesma família do defeito do recorte na mesma data: timestamp de segundo empatando onde
  a ordem importa. Para ato humano, microssegundo não empata.
  """

  use Ecto.Migration

  def change do
    alter table(:profile_automation_events) do
      modify :occurred_at, :utc_datetime_usec, from: :utc_datetime
      modify :inserted_at, :utc_datetime_usec, from: :utc_datetime
    end
  end
end
