defmodule TheBand.Repo.Migrations.CreateBranches do
  @moduledoc """
  As linhas de desenvolvimento — `cmpo.branch`, issue #440.

  ## O que a API acrescenta ao que já sabíamos

  As solicitações coletadas já mencionam **2.461 branches de origem** distintas e 107 de
  destino, como texto nas colunas `source_branch` e `target_branch`. Os repositórios do
  piloto, porém, têm 6, 63 e 47 branches **vivas** — porque branch mergeada é apagada.

  Ou seja: o histórico que a plataforma já tem é mais rico que a API. O que os `refs`
  acrescentam é o **estado agora**, e é isso que responde a pergunta que o histórico não
  responde: *que linha de desenvolvimento está aberta, e há quanto tempo ninguém a toca.*

  ## Branch apagada não ganha registro, e isso é ausência nomeada

  Esta tabela guarda o que existe na origem. Uma branch que já foi mergeada e apagada
  **existiu** — está no `source_branch` da solicitação —, e não tem linha aqui. A tela
  precisa dizer isso com essas palavras: a solicitação aponta para um nome, e o nome pode
  não ter entidade.

  Inventar uma entidade para a branch apagada seria afirmar que ela existe.

  ## `head_committed_at` é o que mede abandono

  O instante do último commit da branch. Sem ele a plataforma sabe que a branch existe e não
  sabe se alguém trabalha nela — e "existe" sozinho não distingue trabalho em curso de
  trabalho esquecido.
  """
  use Ecto.Migration

  def change do
    create table(:cmpo_branches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :observed_repository_id,
          references(:observed_repositories, type: :binary_id, on_delete: :delete_all),
          null: false

      add :name, :string, null: false

      # O commit na ponta, e quando ele foi feito. É o que separa branch em uso de branch
      # esquecida — sem a data, "existe" não diz nada sobre atividade.
      add :head_sha, :string
      add :head_committed_at, :utc_datetime

      # Configuração da ferramenta, não distinção ontológica — a limitação do mapeamento é
      # explícita. Fica porque descreve política, e política é o que se compara com o que
      # de fato aconteceu.
      add :is_default, :boolean, null: false, default: false
      add :is_protected, :boolean, null: false, default: false

      add :source_system, :string, null: false
      add :source_instance, :string, null: false
      add :external_id, :string, null: false
      add :raw_payload, :map

      add :collected_at, :utc_datetime, null: false
      add :last_observed_at, :utc_datetime
      # Branch apagada é MARCADA, nunca removida: ela existiu, e o check-in que aconteceu
      # nela continua sendo fato sobre o processo.
      add :no_longer_observed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:cmpo_branches, [:tenant_id, :external_id])
    create unique_index(:cmpo_branches, [:observed_repository_id, :name])
    create index(:cmpo_branches, [:head_committed_at])

    alter table(:observed_repositories) do
      add :branches_collected_at, :utc_datetime
      # O total da ORIGEM: truncamento nunca silencioso, como em `commits_total`.
      add :branches_total, :integer
    end
  end
end
