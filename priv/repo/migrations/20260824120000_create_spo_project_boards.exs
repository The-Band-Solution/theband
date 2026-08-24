defmodule TheBand.Repo.Migrations.CreateSpoProjectBoards do
  @moduledoc """
  O projeto e seus quadros — issue #367, pergunta 1.

  ## A decisão que criou esta tabela

  *"Um projeto **pode** ter mais de um quadro"* — pessoa mantenedora, 2026-08-24.

  A pergunta original da #367 era "qual quadro é o quadro do projeto", e ela partia de uma
  suposição que a resposta desfez: a de que existe **um**. Não existe. O Conecta Fapes tem
  quatro — `Conecta Fapes` (938 itens), `Conecta Fapes - Delivery` (730), `- Teste` (34) e
  `- Discovery` (30) — e os quatro são dele.

  ## O que a ausência desta tabela custava

  `spo_projects` tinha chave estrangeira para organização, repositório, equipe e projeto-pai.
  **Para quadro, nenhuma.** Um projeto tinha *zero* quadros, e não um: o vínculo não existia
  em forma alguma.

  Consequência medida: lida só pelo quadro corrente, a entrega do Conecta Fapes parecia
  começar em abril de 2026. Dez meses e centenas de issues sumiam — e ninguém precisava ter
  errado nada, porque não havia onde declarar que os dois quadros são do mesmo projeto.

  Com a associação, os dez meses voltam **sem declarar sucessão nenhuma**. A sucessão era um
  contorno para a falta desta tabela.

  ## Por que muitos-para-muitos, e não uma coluna no quadro

  Uma coluna `project_id` em `observed_projects` seria mais simples e afirmaria que o quadro
  pertence a **um** projeto. Não é o que o dado diz: um quadro de plataforma pode servir a
  mais de um projeto, e a plataforma não tem como saber que não serve.

  E `observed_projects` é tabela de **coleta** — o que a origem entregou. O vínculo é
  **declaração**, feita por uma pessoa. Misturar os dois poria decisão humana numa linha que
  a próxima sincronização reescreve.

  ## Desfazer marca, e nunca apaga

  Mesma forma de `spo_project_repositories`: `linked_by_user_id`, `linked_at`,
  `unlinked_by_user_id`, `unlinked_at`. Tirar um quadro do projeto preserva os dois
  registros, com autor — porque a pergunta *"desde quando este quadro é deste projeto"* só
  tem resposta se o encerramento não apagar o começo.

  O índice único é **parcial sobre os vigentes**: sem isso, um quadro que saiu do projeto
  nunca poderia voltar.
  """
  use Ecto.Migration

  def change do
    create table(:spo_project_boards, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :project_id, references(:spo_projects, type: :uuid, on_delete: :delete_all), null: false

      # O quadro observado — `observed_projects` é o Projects v2 da origem, não o projeto.
      # Os dois nomes colidem em português e o esquema mantém a distinção: `spo_projects` é
      # o projeto da SPO, declarado; `observed_projects` é o quadro, coletado.
      add :observed_project_id,
          references(:observed_projects, type: :uuid, on_delete: :delete_all),
          null: false

      add :linked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :linked_at, :utc_datetime, null: false

      add :unlinked_by_user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :unlinked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Parcial sobre os vigentes: o vínculo encerrado continua existindo, e um índice sobre
    # todas as linhas impediria reassociar um quadro que já saiu.
    create unique_index(
             :spo_project_boards,
             [:tenant_id, :project_id, :observed_project_id],
             where: "unlinked_at IS NULL",
             name: :spo_project_boards_vigente_index
           )

    # A pergunta inversa — "de que projetos é este quadro" — é a que a tela do quadro faz.
    create index(:spo_project_boards, [:tenant_id, :observed_project_id],
             name: :spo_project_boards_quadro_index
           )
  end
end
