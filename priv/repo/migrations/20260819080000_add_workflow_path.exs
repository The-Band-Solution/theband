defmodule TheBand.Repo.Migrations.AddWorkflowPath do
  @moduledoc """
  O arquivo que define o workflow — issue #440.

  ## Por que a coluna, e o que ela conserta

  O antipadrão `ci.ap01.monolithic_job` é propriedade do **script**, não da execução: um job
  que faz build e deploy juntos é assim em toda execução daquele fluxo. Hoje
  `Verification.monolithic_jobs/1` agrupa por **nome de job**, que é um proxy — dois
  repositórios com um job chamado `build` viram a mesma linha.

  `workflow_run.path` é o caminho do arquivo, como `.github/workflows/ci.yml`. Medido em
  2026-08-19: **104 definições distintas** explicam 15.375 execuções. Com o caminho, a máxima
  aponta o arquivo a corrigir em vez do nome do job.

  ## Está no payload preservado, e por isso o backfill é local

  Todas as 15.375 execuções já têm `path` no `raw_payload` — é a mesma alavanca que resolveu o
  #438 em cinco segundos. Nenhuma requisição nova.

  ## O que ela NÃO é

  Não é identidade do workflow. O GitHub tem `workflow_id` para isso, e o caminho muda quando
  alguém renomeia o arquivo. A coluna serve para **nomear o que corrigir**, e a identidade
  continua sendo o `external_id` da execução.
  """
  use Ecto.Migration

  def change do
    alter table(:collected_verifications) do
      add :workflow_path, :string
    end

    # A pergunta do antipadrão é "quais arquivos de workflow agrupam processos", e ela agrupa
    # por este caminho.
    create index(:collected_verifications, [:workflow_path])
  end
end
