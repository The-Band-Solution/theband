defmodule TheBand.Repo.Migrations.DeclaracaoDeFasePorColuna do
  @moduledoc """
  O que cada coluna do quadro significa — feature 066.

  ## O problema, medido

  Quadro 43 da `leds-conectafapes`, 2026-09-14: **459 cartões em `Done`, dos quais 294 com a
  issue ABERTA** na origem; 41 fechadas cujo `Status` não é `Done`. Os dois workflows que
  ligariam quadro e issue — *Auto-close issue* e *Item closed* — estão **desligados**. Quadro e
  issue foram desconectados de propósito.

  Hoje a plataforma define concluído como **issue fechada**, em toda medida. Para essa
  organização, toda medida de entrega subconta. E a correção não é escolher por ela: é
  registrar a escolha dela.

  ## Objeto social, como o critério de início

  A mesma coluna significa coisas diferentes em organizações diferentes, e nenhuma está errada.
  A plataforma registra a escolha, com quem a fez e quando — o mesmo desenho de
  `spo_activity_start_criteria` (042) e `spo_activity_deadline_criteria` (#368).

  ## A identidade é o `optionId`, e não o nome

  Opções são renomeáveis no quadro. Se a identidade fosse o nome, renomear *Done* para
  *Concluído* desfaria a decisão em silêncio. O nome no momento da declaração fica guardado
  para a tela mostrar quando divergir do atual — que é informação, não erro.

  ## Sem enum no `target_concept`

  O conceito vive no YAML (`github.project_item_status`, princípio I). Congelar a lista no banco
  faria a plataforma recusar um destino novo da rede como se fosse erro de escrita. O changeset
  valida contra a regra declarada.

  ## Revogar marca

  Índice parcial sobre os vigentes: revogar preserva o começo, e redeclarar continua possível.
  A pergunta *"desde quando esta coluna significa isto"* só tem resposta assim.
  """
  use Ecto.Migration

  def change do
    create table(:spo_item_phase_declarations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :observed_project_id,
          references(:observed_projects, type: :uuid, on_delete: :delete_all),
          null: false

      # O campo na origem: um quadro pode ter mais de um campo de seleção única, e
      # `Status` não é nome reservado.
      add :field_external_id, :string, null: false

      # A identidade da opção, e o nome que ela tinha quando alguém decidiu.
      add :option_external_id, :string, null: false
      add :option_name_at_declaration, :string, null: false

      # O id do conceito na rede, ou `nao_diz_fase` — a recusa registrada (FR-022).
      add :target_concept, :string, null: false

      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :declared_at, :utc_datetime, null: false
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Uma declaração vigente por opção. Sobre os vigentes, para que revogar preserve o
    # começo — o mesmo índice parcial da 042 e do prazo.
    create unique_index(
             :spo_item_phase_declarations,
             [:tenant_id, :observed_project_id, :field_external_id, :option_external_id],
             where: "revoked_at IS NULL",
             name: :spo_fase_vigente_da_opcao_index
           )

    # A leitura da tela e a do item partem do quadro.
    create index(:spo_item_phase_declarations, [:tenant_id, :observed_project_id])
  end
end
