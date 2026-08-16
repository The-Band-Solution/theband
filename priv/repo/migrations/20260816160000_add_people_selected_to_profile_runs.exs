defmodule TheBand.Repo.Migrations.AddPeopleSelectedToProfileRuns do
  @moduledoc """
  O denominador da barra de progresso — emenda de 2026-08-16 à feature 027.

  Quantas pessoas a rodada decidiu percorrer, gravado pelo worker no momento da seleção.
  O numerador é a contagem de entradas, que continua derivada; isto é o tamanho do plano,
  conhecido antes de qualquer desfecho existir.

  `nil` nas rodadas antigas significa "não medido" — a tela mostra progresso indeterminado,
  nunca zero, porque zero diria "nada a fazer" onde a verdade é "não sabemos o total".
  """

  use Ecto.Migration

  def change do
    alter table(:profile_runs) do
      add :people_selected, :integer
    end

    create constraint(:profile_runs, :profile_runs_people_selected_nao_negativo,
             check: "people_selected IS NULL OR people_selected >= 0"
           )
  end
end
