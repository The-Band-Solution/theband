defmodule TheBand.Repo.Migrations.CreateToolObservationEvents do
  @moduledoc """
  As transições de observação de uma ferramenta, append-only (T003, FR-014).

  ## Por que evento e não coluna

  ADR 0004 D7: eventos são append-only, e situações não são materializadas. Encerrar e
  retomar **ocorreram**, num instante, por alguém — são eventos. "Está observada" é
  situação, e sai do último evento.

  Um par de colunas `encerrada_em` / `retomada_em` guardaria **um** ciclo. Encerrar e
  reconectar no mesmo dia produz três transições, e o segundo encerramento sobrescreveria
  o primeiro: o registro passaria a afirmar uma transição onde houve três.

  ## Sem `updated_at`, de propósito

  Evento não é atualizado. Se um encerramento foi registrado errado, a correção é um
  evento novo — atualizar reescreveria o passado, que é o que a D7 proíbe. Ter a coluna
  convidaria a isso.

  ## `impact` guarda o que foi contado no instante

  Não o que uma consulta de hoje devolveria. As duas coisas divergem: uma coleta posterior
  muda os números. O que interessa no registro é o que a pessoa viu antes de confirmar.

  ## Nenhuma coluna é removida nesta feature

  Nem `connected_tools.status`, que materializa uma situação e é dívida da feature 001.
  Unificar as duas coisas é trabalho próprio; fazê-lo aqui misturaria a correção de um
  defeito antigo com a entrega de uma feature.
  """
  use Ecto.Migration

  def up do
    create table(:tool_observation_events, primary_key: false) do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))

      add(:tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false)

      add(
        :connected_tool_id,
        references(:connected_tools, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:event, :string, null: false)
      add(:occurred_at, :utc_datetime, null: false)

      # Anulável de propósito: uma retomada pode vir de processo, e inventar um autor
      # seria pior que declarar que não há.
      add(:actor_user_id, references(:users, type: :binary_id, on_delete: :nilify_all))

      add(:reason, :text)
      add(:impact, :map)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # A derivação sempre pede o último evento de uma ferramenta.
    create index(:tool_observation_events, [:tenant_id, :connected_tool_id, :occurred_at])

    # A restrição vive no banco porque é o que vale quando a escrita não passa pelo
    # changeset — script, console, correção manual.
    create constraint(
             :tool_observation_events,
             :tool_observation_events_event_check,
             check: "event IN ('ended', 'resumed')"
           )
  end

  def down do
    drop table(:tool_observation_events)
  end
end
