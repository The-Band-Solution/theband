defmodule TheBand.Ontology.SEON.EO.Schemas.TeamComposition do
  @moduledoc """
  Uma equipe faz parte de outra — `eo.team_part_of_team`, feature 055.

  ## Por que tabela, e não uma coluna em `eo_teams`

  Uma coluna `parent_team_id` não carrega **quem declarou** nem **quando**, o que
  a torna a versão booleana do relator — o antipadrão nomeado em `AGENTS.md`
  §7.7. E amarra a uma composição por equipe, quando a relação declarada na
  ontologia é **muitos-para-muitos**: a estrutura real não é árvore, e a mesma
  célula pode compor duas frentes ao mesmo tempo.

  ## O período é da RELAÇÃO, não das equipes

  Descompor encerra a composição e **não toca nas equipes**. Uma equipe que
  deixou de ser parte de outra continua existindo, com o histórico dela intacto.

  ## O ciclo não vive aqui

  Índice não vê caminho. A recusa de ciclo é da aplicação, e está em
  `EO.Commands.compose_teams/4` — com a razão escrita lá.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "eo_team_compositions" do
    field :tenant_id, :binary_id

    field :part_team_id, :binary_id
    field :whole_team_id, :binary_id

    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    field :declared_by_user_id, :binary_id
    field :ended_by_user_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(composicao, attrs) do
    composicao
    |> cast(attrs, [
      :tenant_id,
      :part_team_id,
      :whole_team_id,
      :started_at,
      :ended_at,
      :declared_by_user_id,
      :ended_by_user_id
    ])
    |> validate_required([:tenant_id, :part_team_id, :whole_team_id, :started_at])
    |> unique_constraint([:tenant_id, :part_team_id, :whole_team_id],
      name: :eo_composicao_vigente_de_equipe_index
    )
  end
end
