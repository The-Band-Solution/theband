defmodule TheBand.WorkItems.Rotulos do
  @moduledoc """
  Os rótulos de um item de trabalho, e de onde cada um veio.

  Um rótulo chega por duas vias, e elas **não têm a mesma força**:

    * **do campo de rótulo da origem** — alguém clicou. É observação direta;
    * **do prefixo entre colchetes do título** — convenção de escrita. Ninguém prometeu que
      um colchete significa alguma coisa.

  A tela as distingue pelo preenchimento (`DESIGN.md`: sólido para observado, hachurado para
  derivado), e este módulo as distingue pelo campo `origem`. Achatar as duas num tipo só
  entregaria à tela a decisão de qual é qual — e ela não tem como saber.

  ## Quais prefixos qualificam, e por que exatamente esses

  Só os que `TheBand.Mapping.prefixos_recusados_como_tipo/0` devolve — a lista que a base de
  conhecimento mantém para **recusar** aqueles prefixos como *tipo*, porque eles dizem *quem*
  faz ou *em que área*, não *o que* a issue é.

  Essa é a definição de caracterização, e é o que torna a recusa reaproveitável: o mesmo corte
  que decide o que **não** é tipo decide o que **é** rótulo. Medido em 2026-09-13: 1 519
  issues carregam um desses prefixos, e nenhuma delas tinha essa caracterização consultável.

  `[TASK]`, `[FEATURE]`, `[BUG]` e os outros prefixos de **tipo** ficam de fora — o catálogo
  os roteia como tipo, e mostrá-los como rótulo faria o mesmo texto significar duas coisas na
  mesma tela.

  ## O que este módulo NÃO faz

    * **não deduplica** — `backend` do campo e `Back-end` do título aparecem os dois. Juntá-los
      exigiria decidir que são a mesma coisa, e isso é interpretação;
    * **não normaliza grafia** — `[Back-end]` vira `Back-end`, nunca `backend`;
    * **não interpreta** — `prioridade:alta` é texto, e não preenche campo nenhum;
    * **não promove** — o rótulo nunca vira conceito. Um rótulo `bug` não faz a issue um
      defeito: a classificação vem do fato estrutural, e o rótulo é a intenção declarada.
  """

  alias TheBand.Mapping

  @type origem :: :campo | :titulo
  @type t :: %{texto: String.t(), origem: origem()}

  @doc """
  Os rótulos de um item, na ordem em que a tela os mostra: primeiro os do campo, depois os do
  título.

  A ordem é **declarada**, e não incidental: os do campo vêm primeiro porque são a evidência
  mais forte, e quem lê da esquerda para a direita encontra primeiro o que alguém afirmou de
  propósito.

  `nomes_do_campo` é o que a consulta agregou — `nil` quando não há nenhum, porque
  `array_agg` sobre conjunto vazio devolve nulo e a consulta não disfarça isso.

  Devolve lista vazia quando não há rótulo de origem nenhuma. Quem escreve a ausência em
  palavras é a tela (FR-010); aqui ela é só a lista vazia.
  """
  @spec de(nil | [String.t()], nil | String.t()) :: [t()]
  def de(nomes_do_campo, titulo) do
    do_campo = for nome <- nomes_do_campo || [], do: %{texto: nome, origem: :campo}

    case prefixo_reconhecido(titulo) do
      nil -> do_campo
      prefixo -> do_campo ++ [%{texto: prefixo, origem: :titulo}]
    end
  end

  @doc """
  O prefixo entre colchetes do início do título, **se** ele estiver na lista declarada.

  Devolve `nil` para título sem colchete, e também para colchete que ninguém declarou —
  `[Portal ADM]` tem 68 issues e não está na lista, então não vira rótulo. Aceitar qualquer
  colchete transformaria erro de digitação em caracterização, e 248 das 500 issues deste
  repositório têm título livre.

  O texto sai **sem** os colchetes e com a grafia original: `[Back-end]` vira `"Back-end"`.
  """
  @spec prefixo_reconhecido(nil | String.t()) :: String.t() | nil
  def prefixo_reconhecido(nil), do: nil

  def prefixo_reconhecido(titulo) when is_binary(titulo) do
    Enum.find_value(Mapping.prefixos_recusados_como_tipo(), fn declarado ->
      # O catálogo guarda o texto COM os colchetes — `"[Devops]"` —, e é assim que ele
      # compara com o título em `Catalog.not_type_patterns/2`. Comparar do mesmo jeito aqui
      # é o que mantém as duas leituras concordando sobre o que é o mesmo prefixo.
      if String.starts_with?(titulo, declarado) do
        String.trim(declarado, "[") |> String.trim("]")
      end
    end)
  end
end
