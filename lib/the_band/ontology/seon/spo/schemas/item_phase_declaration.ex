defmodule TheBand.Ontology.SEON.SPO.Schemas.ItemPhaseDeclaration do
  @moduledoc """
  O que uma coluna do quadro significa, declarado pela organização — feature 066.

  ## Objeto social

  A mesma coluna significa coisas diferentes em organizações diferentes, e nenhuma está errada.
  `Done` num quadro é a entrega; noutro é "o robô fechou o cartão". A plataforma **não escolhe**
  — registra a escolha, com quem a fez e quando, como faz com o critério de início.

  ## A identidade é o `option_external_id`

  E não o nome. Renomear *Done* para *Concluído* no quadro não pode desfazer a decisão em
  silêncio. `option_name_at_declaration` guarda o nome de então, para a tela mostrar os dois
  quando divergirem — informação, não erro.

  ## `target_concept` é texto, e o conceito vive no YAML

  Princípio I. O changeset valida contra os destinos que
  `github.project_item_status` admite — quatro, e **nenhum deles é aceitação**: pela
  `sro.rule03`, aceitação decorre da avaliação dos critérios, e o quadro pode dizer que o
  trabalho terminou, não que o entregável passou.

  `nao_diz_fase` é destino como os outros: a recusa registrada tira a opção da lista de
  propostas, como a recusa "não é tipo" faz com os prefixos de área.

  ## Revogar marca, e nunca apaga
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TheBand.Ontology.KnowledgeBase

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @regra "github.project_item_status"

  schema "spo_item_phase_declarations" do
    field :tenant_id, :binary_id
    field :observed_project_id, :binary_id

    field :field_external_id, :string
    field :option_external_id, :string
    field :option_name_at_declaration, :string

    field :target_concept, :string

    field :declared_by_user_id, :binary_id
    field :declared_at, :utc_datetime
    field :revoked_by_user_id, :binary_id
    field :revoked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id observed_project_id field_external_id option_external_id
             option_name_at_declaration target_concept declared_by_user_id declared_at)a

  @doc """
  A declaração nasce vigente. `declared_at` e o autor são obrigatórios — uma declaração sem
  autor não tem a quem perguntar por que aquela coluna significa aquilo.
  """
  @spec declarar_changeset(t(), map()) :: Ecto.Changeset.t()
  def declarar_changeset(declaracao, attrs) do
    declaracao
    |> cast(attrs, @campos)
    |> validate_required(@campos)
    |> validate_inclusion(:target_concept, destinos_admitidos(),
      message: "não é um destino declarado em #{@regra}"
    )
    |> unique_constraint(
      [:tenant_id, :observed_project_id, :field_external_id, :option_external_id],
      name: :spo_fase_vigente_da_opcao_index,
      message: "esta coluna já tem declaração vigente"
    )
  end

  @doc "Revogar marca: grava quem e quando, e preserva o começo."
  @spec revogar_changeset(t(), map()) :: Ecto.Changeset.t()
  def revogar_changeset(declaracao, attrs) do
    declaracao
    |> cast(attrs, [:revoked_by_user_id, :revoked_at])
    |> validate_required([:revoked_by_user_id, :revoked_at])
  end

  @doc """
  Os destinos que a regra admite, lidos da base — nunca escritos aqui.

  Base ausente devolve lista vazia, e o changeset recusa **tudo**: é o comportamento certo, e
  ruidoso. Uma lista embutida como reserva faria a plataforma aceitar destino que ninguém
  declarou, justamente quando a base não está lá para dizer o contrário.
  """
  @spec destinos_admitidos() :: [String.t()]
  def destinos_admitidos do
    case KnowledgeBase.rule(@regra) do
      {:ok, %{"targets" => alvos}} when is_list(alvos) ->
        Enum.map(alvos, &Map.fetch!(&1, "id"))

      _ ->
        []
    end
  end

  @doc "O rótulo de um destino, como a regra o escreve. Destino desconhecido devolve ele mesmo."
  @spec rotulo(String.t()) :: String.t()
  def rotulo(destino) do
    with {:ok, %{"targets" => alvos}} <- KnowledgeBase.rule(@regra),
         %{"label" => rotulos} <- Enum.find(alvos, &(Map.get(&1, "id") == destino)) do
      Map.get(rotulos, "en") || Map.get(rotulos, "pt-BR") || destino
    else
      _ -> destino
    end
  end
end
