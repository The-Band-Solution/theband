defmodule TheBand.Repo.Migrations.AddOrganizationAccountToReviewNetworkReadings do
  @moduledoc """
  O motivo `organization_account` na leitura da rede de revisão — feature 076, T027
  (`specs/076-analise-de-rede/data-model.md` §4; A7 da revisão semântica 2, decidida em
  2026-10-04, T002).

  `review.network.edge` versão 2 exclui também a conta declarada como da organização. A coluna
  é **anulável e sem `default`**: as leituras gravadas pela versão 1 não avaliaram o motivo, e
  a contagem delas é nula, e nunca zero. Um `default: 0` faria toda leitura antiga afirmar que
  nenhuma revisão envolveu conta da organização, o que ninguém mediu.

  Aditiva: o rollback tira a coluna e a restrição.
  """
  use Ecto.Migration

  def change do
    alter table(:review_network_readings) do
      add :excluded_organization_account, :integer
    end

    create constraint(
             :review_network_readings,
             :review_network_readings_organization_account_non_negative,
             check: "excluded_organization_account is null or excluded_organization_account >= 0"
           )
  end
end
