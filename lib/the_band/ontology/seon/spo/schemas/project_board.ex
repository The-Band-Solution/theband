defmodule TheBand.Ontology.SEON.SPO.Schemas.ProjectBoard do
  @moduledoc """
  O vínculo entre um projeto e um **quadro** observado — issue #367.

  ## Um projeto pode ter mais de um quadro

  Decisão da pessoa mantenedora, 2026-08-24. Ela desfaz a pergunta original da #367 — *"qual
  quadro é o quadro do projeto"* —, que partia de existir um. O Conecta Fapes tem quatro.

  Sem esta tabela, o projeto tinha **zero**: `spo_projects` ligava a organização, repositório,
  equipe e projeto-pai, e a quadro nenhum. A entrega lida só pelo quadro corrente parecia
  começar em abril de 2026, e dez meses sumiam.

  ## Quadro não é projeto, e os dois nomes colidem

  `observed_projects` é o **quadro** do Projects v2, coletado da origem. `spo_projects` é o
  **projeto** da SPO, declarado por pessoa. O GitHub chama o quadro de "project", e é daí que
  vem a confusão que este esquema recusa herdar.

  ## Declarado, e nunca observado

  A origem não diz a que projeto um quadro pertence. Inferir de nome — `Conecta Fapes -
  Delivery` "obviamente" é do Conecta Fapes — produziria agrupamento que ninguém decidiu, e
  erraria no dia em que dois projetos usassem prefixo parecido.

  Desfazer **marca**, com autor e data, e nunca apaga: a pergunta *"desde quando este quadro
  é deste projeto"* só tem resposta se o encerramento preservar o começo.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "spo_project_boards" do
    field :tenant_id, :binary_id
    field :project_id, :binary_id
    field :observed_project_id, :binary_id

    field :linked_by_user_id, :binary_id
    field :linked_at, :utc_datetime
    field :unlinked_by_user_id, :binary_id
    field :unlinked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(vinculo, attrs) do
    vinculo
    |> cast(attrs, [
      :tenant_id,
      :project_id,
      :observed_project_id,
      :linked_by_user_id,
      :linked_at,
      :unlinked_by_user_id,
      :unlinked_at
    ])
    |> validate_required([:tenant_id, :project_id, :observed_project_id, :linked_at])
    |> unique_constraint(:observed_project_id, name: :spo_project_boards_vigente_index)
  end
end
