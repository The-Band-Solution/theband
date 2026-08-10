defmodule TheBand.Repo.Migrations.DropHandWrittenOrganizationColumns do
  @moduledoc """
  Remove as duas colunas escritas à mão contra a ADR 0004 D4 (achado F1, T006).

  `eo_people.organization_id` e `eo_teams.organization_id` **não existem no modelo
  derivado**. Foram acrescentadas na migração da feature 001 porque a relação não
  estava declarada em EO e declarar não bastaria — o derivador não gerava chave
  estrangeira a partir de associação. Escrever a coluna foi o atalho, e o resultado
  é o que se mede abaixo.

  ## Contagem antes de remover (T005, reconferida em 2026-08-10)

      tabela    | total | com organization_id
      ----------+-------+--------------------
      eo_people |    72 |                   0
      eo_teams  |    10 |                   0

  **Zero em 100% dos registros**, nas três organizações observadas. Nada é perdido.
  A reconferência não é formalidade: remover coluna com dado dentro é perda
  silenciosa, e a instrução era parar e transformar em decisão se a contagem não
  desse zero.

  ## Por que `eo_people.organization_id` não volta

  Não é só falta de lastro — é **semanticamente errada**. A mesma conta do GitHub
  aparece em mais de uma organização, e a pessoa é uma linha só porque a identidade
  é a Application Reference. Uma coluna simples alternaria de valor a cada coleta, e
  a última organização sincronizada apagaria a anterior.

  EO também não define relação direta pessoa↔organização, e não deve: o vínculo
  passaria por papel organizacional, que o GitHub não fornece. O caminho é
  pessoa → equipe → organização, declarado em `eo.cq02`.

  ## `eo_teams.organization_id` volta na migração seguinte

  Volta **derivada** — anulável, com `check_constraint` ligada ao discriminador,
  conforme a saída de `derive_information_model.py`. As duas migrações são separadas
  de propósito: esta registra que as colunas não tinham lastro, a próxima registra
  que a nova tem.
  """
  use Ecto.Migration

  def up do
    drop constraint(:eo_people, "eo_people_organization_id_fkey")
    alter table(:eo_people), do: remove(:organization_id)

    drop constraint(:eo_teams, "eo_teams_organization_id_fkey")
    alter table(:eo_teams), do: remove(:organization_id)
  end

  def down do
    # Recria como estava: anulável e sem restrição, que é o estado que a feature
    # 001 deixou. Reverter não reintroduz o dado, porque nunca houve dado.
    alter table(:eo_people) do
      add(
        :organization_id,
        references(:eo_organizations, type: :binary_id, on_delete: :nilify_all)
      )
    end

    alter table(:eo_teams) do
      add(
        :organization_id,
        references(:eo_organizations, type: :binary_id, on_delete: :nilify_all)
      )
    end
  end
end
