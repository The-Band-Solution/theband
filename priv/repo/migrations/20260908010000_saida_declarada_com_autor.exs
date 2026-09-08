defmodule TheBand.Repo.Migrations.SaidaDeclaradaComAutor do
  @moduledoc """
  Quem registrou a saída, quando registrou, e quando a declaração foi feita — feature 060,
  FR-010, FR-015, FR-021 e FR-022.

  ## O que faltava

  `record_team_departure/5` recebia `actor_id` e **o ignorava** (`commands.ex:110`): gravava
  só `ended_at`. O resultado é que **fim declarado e fim constatado pela coleta ficavam
  indistinguíveis** — os dois são uma data e nada mais.

  E são coisas diferentes na tela: "saiu em 20 de agosto, declarado por Paulo" é uma
  afirmação da organização; "a origem deixou de mostrar esta pessoa em 6 de setembro" é uma
  constatação da plataforma, e a data ali é **quando a plataforma parou de ver**, não quando
  a pessoa saiu. FR-022 exige dizer qual é qual.

  ## Por que TRÊS colunas, e não duas

  `ended_at` é a data **da saída** — informada por quem declara, e pode ser retroativa.
  `end_declared_at` é o instante **do registro**. Colapsá-las faria "saiu em março, declarado
  em setembro" virar "saiu em setembro", e todo número já apresentado para o período anterior
  mudaria — que é exatamente o que o SC-001 proíbe.

  `declared_at` é a terceira, e responde o "em D" de *"declarado por X em D"*. Hoje não há
  onde guardá-lo: `inserted_at` serve para o vínculo declarado do zero, mas o vínculo
  **observado que foi completado** com um papel tem o instante da declaração no `updated_at`
  — e a próxima escrita o apaga.

  ## As duas CHECKs

  Autor e instante andam juntos, e só existem sobre um fim que existe. A garantia é do
  **banco**, e não só do changeset: o changeset protege a tela; a CHECK protege a migração,
  o `update_all` e o script avulso. É o mesmo desenho de `eo_equivoco_do_vinculo_completo`,
  que a feature 055 criou pela mesma razão.

  ## O que o backfill NÃO faz

  Não inventa autor para os fins que já existem. Eles **não têm** autor, e isso é verdade:
  foram constatados pela coleta, ou declarados por um comando que não guardava quem. A tela
  diz "author not recorded" em vez de atribuir a alguém — inventar seria pior que a lacuna.
  """
  use Ecto.Migration

  def up do
    alter table(:eo_team_memberships) do
      add :declared_at, :utc_datetime
      add :ended_by_user_id, references(:users, type: :uuid, on_delete: :restrict)
      add :end_declared_at, :utc_datetime
    end

    flush()

    # O BACKFILL VEM ANTES DAS CHECKS, e a ordem não é estilo.
    #
    # `CREATE CONSTRAINT` valida as linhas que já existem, no instante da criação. Com a
    # ordem invertida, esta migração passava em banco vazio — e reprovava em qualquer banco
    # com vínculo declarado, que é todo banco real:
    #
    #     ** (Postgrex.Error) ERROR 23514 (check_violation)
    #        table: eo_team_memberships
    #        constraint: eo_declaracao_tem_autor
    #
    # Foi assim que apareceu: a suíte, que roda contra banco criado do zero, ficou verde, e
    # o `mix ecto.migrate` do banco de desenvolvimento (90 vínculos) parou na hora.
    #
    # O vínculo declarado que já existe ganha a data que ele sempre teve: a da própria
    # criação. Não é chute — a declaração aconteceu quando a linha nasceu.
    execute """
    UPDATE eo_team_memberships
       SET declared_at = inserted_at
     WHERE declared_by_user_id IS NOT NULL AND declared_at IS NULL
    """

    flush()

    create constraint(
             :eo_team_memberships,
             :eo_saida_declarada_completa,
             check: """
             (ended_by_user_id IS NULL AND end_declared_at IS NULL)
             OR (ended_by_user_id IS NOT NULL AND end_declared_at IS NOT NULL AND ended_at IS NOT NULL)
             """
           )

    create constraint(
             :eo_team_memberships,
             :eo_declaracao_tem_autor,
             check: """
             (declared_by_user_id IS NULL AND declared_at IS NULL)
             OR (declared_by_user_id IS NOT NULL AND declared_at IS NOT NULL)
             """
           )
  end

  def down do
    drop constraint(:eo_team_memberships, :eo_declaracao_tem_autor)
    drop constraint(:eo_team_memberships, :eo_saida_declarada_completa)

    alter table(:eo_team_memberships) do
      remove :end_declared_at
      remove :ended_by_user_id
      remove :declared_at
    end
  end
end
