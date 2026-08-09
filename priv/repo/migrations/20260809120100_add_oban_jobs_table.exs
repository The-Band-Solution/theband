defmodule TheBand.Repo.Migrations.AddObanJobsTable do
  @moduledoc """
  Oban cobre sincronização, paginação, retries e reprocessamento.

  É o que ocupa, neste monólito, o papel da camada de comunicação interna
  descrita na tese — sem broker externo (AGENTS.md §1.1).
  """

  use Ecto.Migration

  def up, do: Oban.Migration.up(version: 12)

  def down, do: Oban.Migration.down(version: 1)
end
