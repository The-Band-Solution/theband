defmodule TheBand.Ontology.SEON.SPO.Schemas.EventConceptDeclaration do
  @moduledoc """
  O que um evento da timeline materializa, declarado pela organização — feature 066.

  ## Prevalece sobre o padrão da casa

  `github.timeline_event_vocabulary` declara o conceito que a casa adota para cada evento.
  Esta tabela guarda a discordância da organização — e ela é legítima: *entrar num quadro*
  não é trabalho executado aqui, mas numa casa onde o cartão só entra quando alguém o pega,
  é. A plataforma não arbitra; registra quem decidiu e quando.

  ## `nao_nomeado` é destino, não ausência

  Registrar que a rede não nomeia um evento é diferente de nunca ter decidido. A primeira é
  decisão consultável; a segunda é lacuna.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TheBand.Ontology.KnowledgeBase

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @regra "github.timeline_event_vocabulary"

  schema "spo_event_concept_declarations" do
    field :tenant_id, :binary_id
    field :event_type, :string
    field :target_concept, :string

    field :declared_by_user_id, :binary_id
    field :declared_at, :utc_datetime
    field :revoked_by_user_id, :binary_id
    field :revoked_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @campos ~w(tenant_id event_type target_concept declared_by_user_id declared_at)a

  @spec declarar_changeset(t(), map()) :: Ecto.Changeset.t()
  def declarar_changeset(declaracao, attrs) do
    declaracao
    |> cast(attrs, @campos)
    |> validate_required(@campos)
    |> validate_inclusion(:target_concept, conceitos_admitidos(),
      message: "não é um conceito admitido em #{@regra}"
    )
    |> unique_constraint([:tenant_id, :event_type],
      name: :spo_conceito_vigente_do_evento_index,
      message: "este evento já tem declaração vigente"
    )
  end

  @spec revogar_changeset(t(), map()) :: Ecto.Changeset.t()
  def revogar_changeset(declaracao, attrs) do
    declaracao
    |> cast(attrs, [:revoked_by_user_id, :revoked_at])
    |> validate_required([:revoked_by_user_id, :revoked_at])
  end

  @doc """
  Os conceitos que a organização pode escolher, lidos da regra — nunca escritos aqui.

  A lista é curta de propósito: oferecer os conceitos todos da rede faria a escolha virar
  busca, e escolher errado é pior do que não escolher.
  """
  @spec conceitos_admitidos() :: [String.t()]
  def conceitos_admitidos do
    case KnowledgeBase.rule(@regra) do
      {:ok, %{"admissible_concepts" => cs}} when is_list(cs) ->
        Enum.map(cs, &Map.fetch!(&1, "id"))

      _ ->
        []
    end
  end

  @doc "O rótulo de um conceito admitido, como a regra o escreve."
  @spec rotulo(String.t()) :: String.t()
  def rotulo(conceito) do
    with {:ok, %{"admissible_concepts" => cs}} <- KnowledgeBase.rule(@regra),
         %{"label" => rotulos} <- Enum.find(cs, &(Map.get(&1, "id") == conceito)) do
      Map.get(rotulos, "en") || Map.get(rotulos, "pt-BR") || conceito
    else
      _ -> conceito
    end
  end
end
