defmodule TheBand.Repo.Migrations.RenameSectorsToOrganizationalUnits do
  @moduledoc """
  `eo_sectors` passa a se chamar `eo_organizational_units`.

  Acompanha a renomeação de `eo.sector` para `eo.organizational_unit` na base de
  conhecimento. O esquema **não** foi editado à mão: a saída de
  `derive_information_model.py --ontology eo` passou a produzir este nome, e a
  migração apenas aplica ao banco o que a derivação já diz (ADR 0004, D4).

  Renomeação pura: nenhum dado é transformado, nenhuma coluna muda. A tabela está
  vazia — o GitHub não fornece unidade organizacional —, então nem migração de
  dados nem janela de indisponibilidade são necessárias.

  O `role_mixin` que hoje se chama `eo.organizational_part` continua sem tabela:
  é não-sortal e é achatado pela transformação, antes e depois da renomeação.
  """

  use Ecto.Migration

  def change do
    rename table(:eo_sectors), to: table(:eo_organizational_units)
  end
end
