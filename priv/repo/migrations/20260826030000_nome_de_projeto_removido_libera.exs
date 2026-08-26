defmodule TheBand.Repo.Migrations.NomeDeProjetoRemovidoLibera do
  @moduledoc """
  O nome de um projeto removido volta a ficar disponível — issue #509.

  ## O que a tela dizia

  Duas frases, na mesma página, ao mesmo tempo:

      No project registered yet.
      name: has already been taken

  As duas verdadeiras. Os projetos existiam, marcados como removidos, e o índice reservava
  os nomes deles para sempre. Não há "desremover" pela tela, então o nome ficava perdido.

  ## A causa, e o padrão que esta base já escreveu

  `unique_index(:spo_projects, [:tenant_id, :name])` era **total**. A migração do critério
  de início — feature 042 — evitou exatamente isto, e disse por quê:

  > O índice é parcial sobre `revoked_at IS NULL` porque o revogado precisa continuar
  > existindo, e um índice total impediria redeclarar.

  `spo_projects` tem a mesma forma: **remover marca, e nunca apaga**. O índice é que estava
  na forma errada.

  ## O que muda, e o que não muda

  Dois projetos **vigentes** com o mesmo nome continuam impossíveis — é a garantia que
  importa, e ela fica intacta.

  O que passa a ser possível é um vigente e um removido dividirem o nome. É o comportamento
  pedido: o histórico do removido continua inteiro, e o nome volta a circular.

  ## Por que não pode reprovar

  O índice novo é mais permissivo que o antigo. Tudo que satisfazia o total satisfaz o
  parcial, então nenhuma linha existente pode violá-lo.
  """
  use Ecto.Migration

  def up do
    drop unique_index(:spo_projects, [:tenant_id, :name], name: :spo_projects_name_index)

    create unique_index(:spo_projects, [:tenant_id, :name],
             where: "removed_at IS NULL",
             name: :spo_projects_name_index
           )
  end

  def down do
    drop unique_index(:spo_projects, [:tenant_id, :name], name: :spo_projects_name_index)

    # A volta PODE reprovar, e é correto que reprove: se um nome foi reusado depois de um
    # removido, o índice total não cabe mais. Desfazer teria que decidir qual dos dois
    # perde o nome, e essa decisão não é da migração.
    create unique_index(:spo_projects, [:tenant_id, :name], name: :spo_projects_name_index)
  end
end
