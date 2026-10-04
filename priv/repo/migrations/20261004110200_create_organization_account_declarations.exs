defmodule TheBand.Repo.Migrations.CreateOrganizationAccountDeclarations do
  @moduledoc """
  A conta da organização, declarada pela administração — feature 076, T025
  (`specs/076-analise-de-rede/data-model.md` §2; research.md R14; R8 da segurança; A20).

  A origem apresenta a conta da organização (o caso `LEDS` da referência) como `User`: nada no
  payload a distingue de uma pessoa. Por isso o reconhecimento é por **declaração**, e não por
  inferência, e a declaração é um relator com autoria e revogação, como `access_scope_grants`.
  **Nunca** em `eo_people.account_type`, que a coleta reescreve a cada passada.

  ## As restrições

  - **FK composta `(person_id, tenant_id)`** → `eo_people(id, tenant_id)`: sem ela, nada impede a
    declaração de um tenant apontar para a pessoa de outro. O índice único `eo_people(id,
    tenant_id)` nasce aqui, como o de `eo_organizations` nasceu na 073;
  - **uma declaração vigente por pessoa** (índice único parcial, `revoked_at is null`);
  - **motivo obrigatório e não vazio**;
  - **`revoked_at >= declared_at`**;
  - quem declarou e quem revogou com `on_delete: :nilify_all`: apagar a conta não apaga o fato de
    a declaração ter existido.

  A revogação preenche `revoked_at`; a linha nunca é apagada. Declarar de novo cria linha nova.
  """
  use Ecto.Migration

  def change do
    create unique_index(:eo_people, [:id, :tenant_id], name: :eo_people_id_tenant_id_index)

    create table(:organization_account_declarations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all), null: false

      add :person_id,
          references(:eo_people,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            on_delete: :delete_all
          ),
          null: false

      add :reason, :text, null: false

      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :declared_at, :utc_datetime, null: false
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organization_account_declarations, [:tenant_id, :person_id],
             where: "revoked_at is null",
             name: :organization_account_declarations_vigente_index
           )

    create constraint(
             :organization_account_declarations,
             :organization_account_declarations_reason_present, check: "length(trim(reason)) > 0")

    create constraint(
             :organization_account_declarations,
             :organization_account_declarations_revoked_after,
             check: "revoked_at is null or revoked_at >= declared_at"
           )
  end
end
