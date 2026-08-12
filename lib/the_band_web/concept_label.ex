defmodule TheBandWeb.ConceptLabel do
  @moduledoc """
  Como o identificador de um conceito e o motivo de uma lacuna aparecem para quem lê.

  Existe porque três telas mostram os mesmos conceitos — trabalho, detalhe da issue e
  repositório. Com a lista repetida em cada uma, `sro.epic` viraria "épico" numa tela e
  "epic" na outra, e quem lê concluiria serem coisas diferentes.

  ## O que este módulo não faz

  **Não decide conceito.** Traduzir é exibição; decidir é `TheBand.WorkItems.Routing`.
  Uma função aqui que inferisse conceito a partir do texto seria a inferência por
  semelhança de nome que o princípio I proíbe, escondida na camada de apresentação.

  Identificador sem tradução é devolvido **como está** — nunca vazio. Um conceito novo na
  base de conhecimento aparece com o identificador técnico até alguém traduzi-lo, e isso
  é melhor que desaparecer da tela.
  """

  @conceitos [
    {"sro.epic", "épico"},
    {"sro.atomic_user_story", "user story atômica"},
    {"sro.intended_scrum_development_task", "tarefa pretendida"},
    {"osdef.defect", "defeito"}
  ]

  @doc """
  Como uma issue **sem conceito** aparece: `indefinida`, com o motivo ao lado.

  ## Por que não é um conceito da ontologia

  `indefinida` **não existe** na base de conhecimento, e não deve existir. Ela não é uma
  coisa que a issue é — é o estado de a plataforma ainda não saber o que ela é. Criar
  `sro.undefined` faria a ausência de conhecimento virar conhecimento: as issues entrariam
  em contagens de conceito, e "3360 indefinidas" seria lido como um tipo de trabalho que o
  time faz.

  É a distinção entre lacuna e fato, e a plataforma existe para preservá-la.

  ## Por que então nomear

  Porque sem nome elas aparecem como um traço e somem da leitura. Nomear a lacuna é o que
  permite alguém agir sobre ela — e a ação é a tela de regras de mapeamento, não uma
  promoção inventada.
  """
  @spec indefinida(String.t() | nil, String.t() | nil) :: String.t()
  def indefinida(motivo, detalhe) do
    caso =
      case {motivo, detalhe} do
        {"type_unknown", nil} -> "tipo desconhecido"
        {"type_unknown", tipo} -> "tipo #{tipo} sem regra"
        {"type_absent", _} -> "sem tipo na origem"
        {nil, _} -> "sem promoção registrada"
        {outro, _} -> motivo(outro)
      end

    "indefinida — #{caso}"
  end

  @motivos %{
    "type_absent" => "sem tipo na origem",
    "type_unknown" => "tipo desconhecido",
    "sub_issues_unavailable" => "sub-issues indisponíveis"
  }

  @recusas %{
    "cycle" => "ciclo de decomposição",
    "out_of_scope" => "parte fora do escopo observado"
  }

  @doc "Os conceitos na ordem em que as telas os apresentam."
  @spec conceitos() :: [{String.t(), String.t()}]
  def conceitos, do: @conceitos

  @doc "O rótulo do conceito, ou o próprio identificador quando não há tradução."
  @spec rotulo(String.t() | nil) :: String.t() | nil
  def rotulo(nil), do: nil

  def rotulo(conceito) do
    Enum.find_value(@conceitos, conceito, fn {id, rotulo} -> id == conceito && rotulo end)
  end

  @doc "O motivo da lacuna em português, ou o próprio motivo quando não há tradução."
  @spec motivo(String.t() | nil) :: String.t() | nil
  def motivo(nil), do: nil
  def motivo(motivo), do: Map.get(@motivos, motivo, motivo)

  @doc "O motivo da recusa de vínculo em português."
  @spec recusa(String.t() | nil) :: String.t() | nil
  def recusa(nil), do: nil
  def recusa(motivo), do: Map.get(@recusas, motivo, motivo)
end
