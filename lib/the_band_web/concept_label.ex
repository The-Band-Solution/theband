defmodule TheBandWeb.ConceptLabel do
  @moduledoc """
  Como o identificador de um conceito, uma lacuna, uma recusa e uma divergência aparecem na
  tela — **em inglês**.

  Existe porque as telas mostram os mesmos conceitos, e com a lista repetida em cada uma
  `sro.epic` viraria "epic" numa e "Epic" na outra; quem lê concluiria serem coisas
  diferentes.

  ## A interface fala inglês; o código e a documentação falam português

  Decisão deliberada, declarada no `AGENTS.md`: o público da interface não é o público do
  código. Misturar os dois exigiria traduzir a constituição — reescrita que ninguém pediu.

  ## O que este módulo não faz

  **Não decide conceito.** Traduzir é exibição; decidir é `TheBand.WorkItems.Routing`. Uma
  função aqui que inferisse conceito a partir do texto seria a inferência por semelhança de
  nome que o princípio I proíbe, escondida na camada de apresentação.

  Identificador sem tradução é devolvido **como está** — nunca vazio. Um conceito novo na
  base aparece com o identificador técnico até alguém traduzi-lo, e isso é melhor que
  desaparecer da tela.
  """

  @conceitos [
    {"sro.epic", "epic"},
    {"sro.atomic_user_story", "atomic user story"},
    {"sro.intended_scrum_development_task", "intended task"},
    {"osdef.defect", "defect"}
  ]

  @motivos %{
    "type_absent" => "no type at the source",
    "type_unknown" => "unknown type",
    "sub_issues_unavailable" => "sub-issues unavailable"
  }

  @fontes %{
    "declared_type" => "declared type",
    "title" => "title pattern",
    "structure" => "decomposition structure"
  }

  @confiancas %{"high" => "high", "medium" => "medium", "low" => "low"}

  # Os dois primeiros são **axioma aplicado** — a plataforma mudou o conceito e diz por quê.
  # Os dois seguintes são **sinal**: o conceito foi mantido, porque nenhum axioma proíbe o
  # caso. A diferença é o que o tipo torna consultável, e a frase sozinha escondia.
  @divergencias %{
    "epic_without_parts" => "labelled epic, and it has no parts",
    "composition_makes_epic" => "composition makes it an epic",
    "task_with_parts" => "task with collected parts",
    "user_story_without_parts" => "user story with no parts or tasks",
    "label_vs_structure" => "label and structure disagree"
  }

  @recusas %{
    "cycle" => "decomposition cycle",
    "out_of_scope" => "part outside the observed scope"
  }

  # **Seis textos, e nenhum deles é cor.** A lista do repositório mostra a relação em 4 529
  # linhas, e quem não distingue cor precisa distinguir os casos — WCAG 1.4.1, e a gramática da
  # evidência é normativa em `docs/design-system.md`.
  #
  # O texto da violação é **curto** de propósito: a formulação inteira do axioma está em
  # `Axioms.explicacao/1`, que o detalhe da issue mostra. Numa célula de tabela, duas linhas de
  # explicação em 293 linhas afogariam a própria lista.
  @relacoes %{
    atendimento: "attends",
    composicao: "composes",
    violacao: "attends — and this parent is an epic, which violates sro.rule07",
    nao_nomeada: "part of — the ontology network does not name this relation",
    pai_sem_conceito: "part of — the parent has no concept",
    filha_sem_conceito: "part of — this issue has no concept, so the relation is undecided"
  }

  @doc "Os conceitos na ordem em que as telas os apresentam."
  @spec conceitos() :: [{String.t(), String.t()}]
  def conceitos, do: @conceitos

  @doc """
  O texto da relação de decomposição, como a lista de issues a mostra.

  A decisão de **qual** relação é vem de `TheBand.WorkItems.Axioms.relacao/2`; aqui só o texto.
  """
  @spec relacao(
          :atendimento
          | :composicao
          | :nao_nomeada
          | :filha_sem_conceito
          | :pai_sem_conceito
          | {:violacao, atom()}
        ) :: String.t()
  def relacao({:violacao, _forma}), do: @relacoes.violacao
  def relacao(relacao) when is_atom(relacao), do: Map.fetch!(@relacoes, relacao)

  @doc "O rótulo do conceito, ou o próprio identificador quando não há tradução."
  @spec rotulo(String.t() | nil) :: String.t() | nil
  def rotulo(nil), do: nil

  def rotulo(conceito) do
    Enum.find_value(@conceitos, conceito, fn {id, rotulo} -> id == conceito && rotulo end)
  end

  @doc "O motivo da lacuna, por extenso."
  @spec motivo(String.t() | nil) :: String.t() | nil
  def motivo(nil), do: nil
  def motivo(motivo), do: Map.get(@motivos, motivo, motivo)

  @doc """
  Como uma issue **sem conceito** aparece: `undefined`, com o motivo ao lado.

  ## Por que não é um conceito da ontologia

  `undefined` **não existe** na base de conhecimento, e não deve existir. Ela não é uma coisa
  que a issue é — é o estado de a plataforma ainda não saber o que ela é. Criar
  `sro.undefined` faria a ausência de conhecimento virar conhecimento: as issues entrariam em
  contagens de conceito, e "3 451 undefined" seria lido como um tipo de trabalho que o time
  faz.

  ## Por que então nomear

  Porque sem nome elas aparecem como um traço e somem da leitura. Nomear a lacuna é o que
  permite alguém agir sobre ela — e a ação é a tela de regras de mapeamento, nunca uma
  promoção inventada.
  """
  @spec indefinida(String.t() | nil, String.t() | nil) :: String.t()
  def indefinida(motivo, detalhe) do
    caso =
      case {motivo, detalhe} do
        {"type_unknown", nil} -> "unknown type"
        {"type_unknown", tipo} -> "type #{tipo} has no rule"
        {"type_absent", _} -> "no type at the source"
        {nil, _} -> "no promotion recorded"
        {outro, _} -> motivo(outro)
      end

    "undefined — #{caso}"
  end

  @doc "De onde veio a evidência, por extenso."
  @spec fonte(String.t() | nil) :: String.t()
  def fonte(nil), do: "provenance not recorded"
  def fonte(fonte), do: Map.get(@fontes, fonte, fonte)

  @doc """
  Quanto a plataforma confia na decisão — **nível, nunca número**.

  Um número seria inventado, e viraria meta: alguém o otimizaria escrevendo regras mais
  amplas, e a medida deixaria de medir.
  """
  @spec confianca(String.t() | nil) :: String.t() | nil
  def confianca(nil), do: nil
  def confianca(nivel), do: Map.get(@confiancas, nivel, nivel)

  @doc "O tipo da divergência, por extenso."
  @spec divergencia(String.t() | nil) :: String.t() | nil
  def divergencia(nil), do: nil
  def divergencia(tipo), do: Map.get(@divergencias, tipo, tipo)

  @doc "Se a divergência **mudou** o conceito, ou é sinal com o conceito mantido."
  @spec divergencia_mudou_conceito?(String.t() | nil) :: boolean()
  def divergencia_mudou_conceito?(tipo),
    do: tipo in ["epic_without_parts", "composition_makes_epic"]

  @doc "O motivo da recusa de vínculo, por extenso."
  @spec recusa(String.t() | nil) :: String.t() | nil
  def recusa(nil), do: nil
  def recusa(motivo), do: Map.get(@recusas, motivo, motivo)
end
