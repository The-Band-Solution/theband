defmodule TheBand.Repo.Migrations.CommitsTruncatedIsTold do
  @moduledoc """
  Truncamento nunca é silencioso — nem no resumo da coleta, nem na tela.

  Medido na primeira coleta real (2026-08-18): **509 das 5.032 solicitações** têm mais
  commits do que a página traz. Sem estes dois campos, a tela mostraria cinquenta como se
  fossem todos — e "cinquenta commits" e "os cinquenta primeiros de duzentos" afirmam
  coisas diferentes sobre o mesmo trabalho.
  """
  use Ecto.Migration

  def change do
    alter table(:collected_change_requests) do
      # Quantos a origem diz que existem, contra quantos foram coletados.
      add :commits_total, :integer
      add :commits_collected, :integer
    end
  end
end
