defmodule TheBand.Repo.Migrations.CreateActivityStartCriteria do
  @moduledoc """
  O critério de início, declarado pela organização — issue #370.

  ## O que estava travado

  A `FR-007` da feature 022 diz que a plataforma **não escolhe sozinha** qual evento marca o
  início de um trabalho. Sem essa escolha, três medidas não existem: `flow.throughput`,
  `flow.wip.count` e o cycle time por pessoa.

  A saída não é a plataforma passar a escolher — é a organização declarar, e a declaração
  virar dado com proveniência.

  ## Alvo polimórfico, e o que ele custa

  `project_id` **ou** `observed_project_id`, exatamente um preenchido.

  Duas tabelas seriam mais legíveis, e poriam a regra de precedência em **dois lugares**: a
  escala quadro → projeto → nulo precisa comparar declarações de níveis diferentes numa
  consulta só, e com duas tabelas toda leitura viraria `UNION` com a regra duplicada. Esta
  base já pagou três vezes por regra escrita duas vezes.

  O custo é real: a constraint `exactly-one-of` é mais frágil que uma chave estrangeira
  obrigatória, e quem lê a tabela precisa saber qual coluna olhar.

  ## O quadro é `observed_projects`, e não `spo_projects`

  Os dois nomes colidem porque o GitHub chama o quadro de "project". `observed_projects` é o
  Projects v2 **coletado**; `spo_projects` é o projeto da SPO, **declarado**. O `@moduledoc`
  do schema repete isso, porque quem ler `project_id` numa das duas precisa saber qual é.

  ## `event_type` fica cru, sem enum

  A origem nomeia os eventos — `ProjectV2ItemStatusChangedEvent`, `AssignedEvent`. Congelar a
  lista num enum faria a plataforma recusar um evento novo do GitHub como se fosse erro.

  A restrição ao que é coletado acontece na **tela** (`FR-012`), que é validação de interface
  e não de esquema.

  ## Um vigente por alvo, e o índice é parcial

  Dois critérios vigentes para o mesmo projeto seriam duas respostas para a mesma pergunta.

  O índice é parcial sobre `revoked_at IS NULL` porque o revogado precisa continuar existindo
  — a `FR-010` manda preservar quem declarou antes, e um índice total impediria redeclarar.
  """
  use Ecto.Migration

  def change do
    create table(:spo_activity_start_criteria, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      # Exatamente um dos dois. A `CHECK` abaixo é quem garante.
      add :project_id, references(:spo_projects, type: :uuid, on_delete: :delete_all)

      add :observed_project_id,
          references(:observed_projects, type: :uuid, on_delete: :delete_all)

      # Cru, como a origem nomeia. Sem enum: evento novo do GitHub não é erro.
      add :event_type, :string, null: false

      add :declared_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :declared_at, :utc_datetime, null: false

      # Revogar MARCA, e nunca apaga: a pergunta "desde quando este critério vale" só tem
      # resposta se o encerramento preservar o começo.
      add :revoked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create constraint(:spo_activity_start_criteria, :criterio_tem_um_alvo_so,
             check: "num_nonnulls(project_id, observed_project_id) = 1"
           )

    # Parciais sobre os vigentes: o revogado continua existindo, e um índice total impediria
    # redeclarar depois de revogar.
    create unique_index(:spo_activity_start_criteria, [:tenant_id, :project_id],
             where: "revoked_at IS NULL AND project_id IS NOT NULL",
             name: :spo_activity_start_criteria_projeto_vigente_index
           )

    create unique_index(:spo_activity_start_criteria, [:tenant_id, :observed_project_id],
             where: "revoked_at IS NULL AND observed_project_id IS NOT NULL",
             name: :spo_activity_start_criteria_quadro_vigente_index
           )
  end
end
