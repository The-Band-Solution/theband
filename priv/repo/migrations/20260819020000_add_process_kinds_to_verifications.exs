defmodule TheBand.Repo.Migrations.AddProcessKindsToVerifications do
  @moduledoc """
  O tipo de processo que a execução materializou — feature 037, corrigido pelo dado real.

  A primeira versão assumia que toda execução do Actions é integração contínua. Medido em
  2026-08-18 nas 1.051 execuções do primeiro repositório: as cinco mais frequentes são
  `Sync to GitLab`, `Deploy Docs to GitHub Pages`, `Deploy Backoffice and Front-office`,
  `Project 43 Sprint Rollover` e `Release ConectaFapes` — entrega, implantação e
  automação de quadro. **Nenhuma integra código.**

  Array, e não coluna única, porque o fluxo do GitHub Pages tem um job `build` e um
  `deploy` na mesma execução: ela é integração E implantação, e guardar só uma perderia
  metade do que aconteceu.

  Array vazio é **ausência nomeada**: a rede não tem conceito para automação de quadro, e
  dizer isso é mais honesto do que forçá-la a caber num conceito de verificação.
  """
  use Ecto.Migration

  def change do
    alter table(:collected_verifications) do
      add :process_kinds, {:array, :string}, null: false, default: []
    end

    # O índice é GIN porque a pergunta da tela é "quais execuções SÃO integração
    # contínua" — contenção em array, e não igualdade.
    create index(:collected_verifications, [:process_kinds], using: :gin)
  end
end
